#!/usr/bin/perl -w

BEGIN {
	use lib "/usr/local/icms/bin";
};

use strict;
use ICMS;

use Common qw (
    dumpVar
    doTemplate
    $templateDir
    sanitizeCaseNumber
    getConfig
    inArray
    getSystemType
    returnJson
    getShowcaseDb
    createTab
    getUser
    getSession
    checkLoggedIn
);

use EService qw (
    getAllAddresses
    getPortalAddresses
    getRefileDocs
    getAgencyAddresses
);

use DB_Functions qw (
    dbConnect
    doQuery
    getDataOne
    ldapLookup
    getData
    getDocketCodes
    eFileInfo
    getCaseInfo
    getDivsLDAP
    $CAD_OU
    getSubscribedQueues
	getSharedQueues
	getQueues
	getFilingAccounts
	getDocData
	getEmergencyQueues
);

use Showcase qw{
	getCaseID
	getSCCaseNumber
};

use JSON;

use CGI;
use CGI::Carp qw(fatalsToBrowser);

checkLoggedIn();

my $info = new CGI;
my %params = $info->Vars;

my @recipients;

my $esdbh = dbConnect("eservice");
my $jdbh = dbConnect("judge-divs");
my $dbh = dbConnect(getShowcaseDb());

my $ucn = $params{'case'};
my $doc_id;
my $docData;
my $session = getSession();

my $markEmergency = 0;
if(defined($params{'fromWF'}) && ($params{'fromWF'} eq '1')){
	$doc_id = $params{'docid'};
	$docData = getDocData($doc_id);
	$ucn = $docData->{'ucn'};
	
	if(defined($docData->{'filing_id'})){
		$params{'filingid'} = $docData->{'filing_id'};
	}
	
	my @eQueues = getEmergencyQueues();
	
	if(scalar(@eQueues)){
		foreach my $eQueue (@eQueues){
			if($eQueue->{'queue_name'} eq $docData->{'queue'}){
				$markEmergency = 1;
			}
		}
	}
}

my $casenum = sanitizeCaseNumber($ucn);

#$casenum =~ s/-//g;
my $caseid = $params{'caseid'};
$casenum = getSCCaseNumber($casenum);

if(!defined($caseid)){
	$caseid = getCaseID($casenum);
}

my $showOnly;
if(!defined($params{'showOnly'})){
	$showOnly = 0;
}
else{
	$showOnly = 1;
}

my $user = getUser();

my $href;

if(defined($params{'fromWF'}) && ($params{'fromWF'} eq '1')){
	$href .= "/cgi-bin/case/eservice/eService.cgi?fromWF=1&efileCheck=1&clerkFile=1&ucn=" . $ucn . "&docid=" . $doc_id;
}
else{
	$href = "/cgi-bin/case/eservice/eService.cgi?case=" . $casenum . "&caseid=" . $caseid . "&showOnly=" . $showOnly;
}

createTab($casenum, "/cgi-bin/case/search.cgi?name=" . $casenum, 1, 1, "cases",
{ 
	"name" => "e-Service",
	"active" => 1,
	"close" => 1,
	"href" => $href,
	"parent" => $casenum
});
$session = getSession();

my $fdbh = dbConnect("icms");

my @myqueues = ($user);
my @sharedqueues;

getSubscribedQueues($user, $fdbh, \@myqueues);
getSharedQueues($user, $fdbh, \@sharedqueues);
my @allqueues = (@myqueues, @sharedqueues);
my %queueItems;

my $wfcount = getQueues(\%queueItems, \@allqueues, $fdbh);

my $caseinfo = getCaseInfo($casenum, $dbh, $caseid);

my $query;

my $division = $caseinfo->{'DivisionID'};
if (!defined($division)) {
    # No division?  See if we can find it in AD for the user
    my @divs;
    getDivsLDAP(\@divs, $user);
    $division = $divs[0];
}

my $ldapFilter = "(|(mail=CAD-Division$division*\@pbcgov.org)(mail=CAD-CaseManager$division*\@pbcgov.org))";
my $ldapBase = "ou=CAD,ou=$CAD_OU,dc=PBCGOV,dc=ORG";
my @ldapFields = (
	"displayName",
	"mail",
	"telephoneNumber"
);

my %types = (
             'Circuit Civil' => 'circuit_civil',
             'Foreclosure' => 'circuit_civil',
             'Felony' => 'circuit_criminal',
             'Family' => 'family',
             'Juvenile Dependency' => 'dependency',
             'Probate' => 'probate',
             'County Civil' => 'county_civil',
             'Misdemeanor' => 'county_criminal',
             'Juvenile Delinquency' => 'delinquency',
             'Criminal Traffic' => 'criminal_traffic'
);

my @senderTmp;
ldapLookup(\@senderTmp,$ldapFilter,undef,\@ldapFields,$ldapBase);

my %data;

my @senders;

my @mag_email_temp;
my $mag_email_query = qq {
	select
		'' AS telephoneNumber,
    	email_address AS mail,
    	display_name AS displayName
    from
        magistrate_emails
    where
    	user_id = ?
    and
    	active = 1
};
getData(\@mag_email_temp, $mag_email_query, $jdbh, {valref => [$user]});

if(scalar(@mag_email_temp) > 0){
	foreach my $email (@mag_email_temp){
		push(@senders, $email);
	}
}

# Try to get the ones that ONLY match this division
foreach my $sender (@senderTmp) {
	#if($division ne "AY" && ($division ne "AC") && (scalar(@mag_email_temp) eq 0)){
	if($division ne "AY" && ($division ne "AC")){
	    if (($sender->{'mail'} =~ /^CAD-Division$division-(.*)@/i) ||
	        ($sender->{'mail'} =~ /^CAD-Division$division@/i) ||
	        ($sender->{'mail'} =~ /^CAD-CaseManager$division@/i)){
	        push(@senders, $sender);
	    }
    }
}

if($division eq "AC"){
	my %newSender;
	$newSender{'telephoneNumber'} = "";
	$newSender{'mail'} = "CriminalAppeals\@pbcgov.org";
	$newSender{'displayName'} = "Criminal Appeals";
    push(@senders, \%newSender);
}
elsif($division eq "AY"){
	my %newSender;
	$newSender{'telephoneNumber'} = "";
	$newSender{'mail'} = "CivilAppeals\@pbcgov.org";
	$newSender{'displayName'} = "Civil Appeals";
    push(@senders, \%newSender);
}

my $efInfo;

my $pdbh;

$data{'order_label'} = "Generated Order";
$data{'supp_docs'} = [];

if(defined($params{'fromWF'}) && ($params{'fromWF'} eq '1')){
	$params{'doc_id'} = $docData->{'docid'};
	$data{'doc_id'} = $params{'doc_id'};
	$params{'doc_title'} = $docData->{'title'};
	
	#Need to regenerate PDF first... 
	my $orderResp = `/usr/bin/php /var/www/html/case/orders/genpdf.php -e Y -d $params{'doc_id'} -u "$casenum"`;
	my $orderJSON = decode_json($orderResp);
	$params{'pdf'} = $orderJSON->{'filename'};
	
	my $odbh = dbConnect("ols");
	my $suppQuery = qq{
		SELECT 
		CASE WHEN jvs_doc = 1
			THEN file
		ELSE jvs_file_path
		END AS file,
		document_title,
		order_merge
		FROM olscheduling.supporting_documents
		WHERE workflow_id = ?
		AND efile_attach = 1
	};
	
	my @suppDocsRes;
	getData(\@suppDocsRes, $suppQuery, $odbh, {valref => [$docData->{'docid'}]});
	
	my @suppDocs;
	my $pdfList = $params{'pdf'};
	if(scalar(@suppDocsRes)){
		foreach my $sd (@suppDocsRes) {
			if($sd->{'order_merge'} eq '1'){
				$data{'order_label'} = "Combined Order";
			}
			else{
				push(@suppDocs, $sd);
			}
		}
		
		$data{'supp_docs'} = \@suppDocs;
	}

}

if ((!defined($params{'pdf'})) || (defined($params{'canEfile'}) && ($params{'canEfile'}))) {
    $pdbh = dbConnect("portal_info");
    $efInfo = eFileInfo($user, $pdbh);
    $pdbh->disconnect;
    $data{'clerkFile'} = (defined($efInfo));
    if ($data{'clerkFile'}) {
        $data{'eFileInfo'} = $efInfo;
    }
}

my $refile = 0;

my %docketCodes;
my @docketCodes;
    
getDocketCodes(\@docketCodes, $caseinfo, $pdbh, $efInfo->{'portal_user_type_name'});
foreach my $dcode (@docketCodes) {
	$docketCodes{$dcode->{'docket_desc'}} = $dcode;
}

my $json = JSON->new->allow_nonref;
$data{'docketCodes'} = $json->encode(\@docketCodes);
if (!defined($params{'showOnly'})) {
    if (defined($params{'pdf'})) {
        # Entry point is from form generation.
        $data{'gennedPdf'} = $params{'pdf'};
        $data{'doc_title'} = $params{'doc_title'};
        
        my $icmsdbh = dbConnect("icms");
		my $query = qq {
						SELECT CASE 
							WHEN form_name IS NULL
							THEN title
						 	ELSE form_name
						 END AS form_name,
						CASE 
							WHEN efiling_document_description IS NULL
							THEN 'ORDER'
						 	ELSE efiling_document_description
						END AS order_type,
						CASE 
							WHEN file_group IS NULL
							THEN 'Judiciary'
						 	ELSE file_group
						END AS file_group,
						CASE 
							WHEN docket_desc IS NULL
							THEN 'ORDER'
						 	ELSE docket_desc
						END AS docket_desc
						FROM workflow w
						LEFT OUTER JOIN forms f
						ON w.form_id = f.form_id
						LEFT OUTER JOIN portal_info.order_type_map o
						ON efiling_document_description =  o.docket_desc
						WHERE doc_id = $params{'doc_id'}
				};
		my $doc_row = getDataOne($query, $icmsdbh);
        
        $data{'genPortalDesc'} = $doc_row->{'order_type'};
        $data{'genDocketGroup'} = $doc_row->{'file_group'};
        $data{'genDocketDesc'} = $doc_row->{'docket_desc'};        
        $data{'genFormName'} = $doc_row->{'form_name'};
        $data{'clerkFile'} = 1;
        $data{'doc_id'} = $params{'doc_id'};
    }
}

if (defined($params{'filingid'})) {
    $refile = 1;
    $data{'filingid'} = $params{'filingid'};
    $data{'refiles'} = [];
    $data{'origDate'} = "";
    getRefileDocs($data{'filingid'}, $data{'refiles'}, \$data{'origDate'}, \%docketCodes, $user);
}

$data{'systemType'} = getSystemType();

$data{'UCN'} = $caseinfo->{'CaseNumber'};

#LK - Taking this out 3/1/16
#if (scalar(@senders)) {
	getAllAddresses($casenum,\@recipients,$esdbh,$caseid);
    
    if ($caseinfo->{'CaseNumber'} =~ /^50/) {
        $ucn = $caseinfo->{'CaseNumber'};
        $ucn =~ s/-//g;
    } 
    
    $data{'addl_recips'} = [];
    
    # Build an array of suppressed addresses, for comparison against the portal addresses
    my @suppressed;
    my @temp;
    $query = qq {
        select
            email_addr
        from
            suppress_emails
        where
            casenum = ?
    };
    getData(\@temp, $query, $esdbh, {valref => [$caseinfo->{'CaseNumber'}]});
    foreach my $addr (@temp) {
        push(@suppressed, $addr->{'email_addr'});
    }
    
    my @portalAddresses;
    if (defined($ucn)) {
        # Get the "extended case ID" from Banner
        getPortalAddresses($ucn, \@portalAddresses);
        
        # Now, for each of these, scroll through the local service list to ensure that it isn't duplicated there.
        # If it isn't, push it onto the $data{'addl_recips'} array
        foreach my $addr (@portalAddresses) {
            $addr->{'from_portal'} = 1;
            $addr->{'agency'} = 0;
            $addr->{'fullname'} = $addr->{'fullname'};
            # Is this address suppressed?
            if (inArray(\@suppressed, $addr->{'email_addr'}, 0)) {
                $addr->{'isSuppressed'} = 1;
            }
            
            my $exists = 0;
            foreach my $recip (@recipients) {
                # Ensure addresses are compared with matching case
                if (lc($addr->{'email_addr'}) eq lc($recip->{'email_addr'})) {
                    # Found it in the @recipients array
                    $exists = 1;
                    last;
                }
            }
            if (!$exists) {
                # It wasn't found in either group.  Add it to the addl_recips
                # Mark that it's from the portal, so the interface can know
                push(@{$data{'addl_recips'}}, $addr);
            }
        }
    }
    
    # Are there any agency addresses?
    my @agencyAddrs;
    getAgencyAddresses($caseinfo->{'CaseNumber'}, \@agencyAddrs, $esdbh, $caseid);
    
    if (scalar(@agencyAddrs)) {
    	foreach my $address (@agencyAddrs) {
            $address->{'from_portal'} = 0;
            $address->{'agency'} = 1;
            # Check to be sure it isn't defined in the list already
            # First, check the @recipients
            my $exists = 0;
            foreach my $recip (@recipients) {
                if (lc($address->{'email_addr'}) eq lc($recip->{'email_addr'})) {
                    $exists = 1;
                    # Found a duplicate? Clean up and remove it from the reuse_emails table
                    $query = qq {
                        delete from
                            reuse_emails
                        where
                            casenum = ?
                            and email_addr = ?
                    };
                    doQuery($query, $esdbh, [$caseinfo->{'CaseNumber'}, $address->{'email_addr'}]);
                    last;
                }
            }
            
            # And then the portal addresses
            foreach my $recip (@portalAddresses) {
                if (lc($address->{'email_addr'}) eq lc($recip->{'email_addr'})) {
                    $exists = 1;
                    # Found a duplicate? Clean up and remove it from the reuse_emails table
                    $query = qq {
                        delete from
                            reuse_emails
                        where
                            casenum = ?
                            and email_addr = ?
                    };
                    doQuery($query, $esdbh, [$caseinfo->{'CaseNumber'}, $address->{'email_addr'}]);
                    last;
                }
            }
            
            # Still doesn't exist?  Put it onto the array.
            if (!$exists) {
                push(@{$data{'addl_recips'}}, $address);
            }
    	}
    }
    
    # Look up any stored "additional" addresses
    my @addl;
    $query = qq {
        select
        	email_addr,
            0 as from_portal
        from
            reuse_emails
        where
            casenum = ?
    };
    getData(\@addl, $query, $esdbh, {valref => [$caseinfo->{'CaseNumber'}]});

    if (scalar(@addl)) {
    	foreach my $address (@addl) {
            $address->{'from_portal'} = 0;
            $address->{'agency'} = 0;
            # Check to be sure it isn't defined in the list already
            # First, check the @recipients
            my $exists = 0;
            foreach my $recip (@recipients) {
                if (lc($address->{'email_addr'}) eq lc($recip->{'email_addr'})) {
                    $exists = 1;
                    # Found a duplicate? Clean up and remove it from the reuse_emails table
                    $query = qq {
                        delete from
                            reuse_emails
                        where
                            casenum = ?
                            and email_addr = ?
                    };
                    doQuery($query, $esdbh, [$caseinfo->{'CaseNumber'}, $address->{'email_addr'}]);
                    last;
                }
            }
            
            # And then the portal addresses
            foreach my $recip (@portalAddresses) {
                if (lc($address->{'email_addr'}) eq lc($recip->{'email_addr'})) {
                    $exists = 1;
                    # Found a duplicate? Clean up and remove it from the reuse_emails table
                    $query = qq {
                        delete from
                            reuse_emails
                        where
                            casenum = ?
                            and email_addr = ?
                    };
                    doQuery($query, $esdbh, [$caseinfo->{'CaseNumber'}, $address->{'email_addr'}]);
                    last;
                }
            }
            
            # Still doesn't exist?  Put it onto the array.
            if (!$exists) {
                push(@{$data{'addl_recips'}}, $address);
            }
    	}
    }
    
    my @finalRecipEmails;
    my @finalRecipients;
    foreach my $recip (@recipients) {
    	my $lc_email = lc($recip->{'email_addr'});
    	
    	if(!inArray(\@finalRecipEmails, $lc_email)){
    		push(@finalRecipEmails, $lc_email);
    		push(@finalRecipients, $recip);
    	}
    }
    
    @recipients = @finalRecipients;
    
	# Format the case number

	$data{'title'} = "E-Service - Case Number $caseinfo->{'CaseNumber'}";
	$data{'recipients'} = \@recipients;
	$data{'senders'} = \@senders;
	$data{'casenum'} = $caseinfo->{'CaseNumber'};
	$data{'caseinfo'} = $caseinfo;
#} else {
#	$data{'title'} = "No Senders Found!";
#	$data{'division'} = $division;
#}


$data{'subject'} = "SERVICE OF COURT DOCUMENT CASE No.: $ucn";
if (defined($data{'filingid'})) {
    $data{'subject'} .= " - REVISED DOCUMENTS";
}

$pdbh = dbConnect("portal_info");
my $accounts = getFilingAccounts($user, $pdbh);
$data{'efiling_accounts'} = $accounts;

my $templateFile;
if ((defined($params{'showOnly'}) && ($params{'showOnly'}))) {
    $data{'title'} = "E-Service Addresses - Case Number $caseinfo->{'CaseNumber'}";
    $data{'CaseStyle'} = $caseinfo->{'CaseStyle'};
    # For this purpose, we only an array of email addresses - no delineation of source.
    $data{'serviceAddresses'} = [];
    my @temp;
    my @addrs;
    foreach my $addr (@{$data{'recipients'}}) {
        if (!inArray(\@addrs, lc($addr->{'email_addr'}))) {
            push(@addrs, lc($addr->{'email_addr'}));
            if($addr->{'FromShowcase'} eq '1'){
            	$addr->{'class'} = "fromSc";
            }
            else{
            	$addr->{'class'} = "localSvc";
            }
            push(@temp, $addr);
        }
    }
    foreach my $addr (@{$data{'addl_recips'}}) {
        if (!$addr->{'isSuppressed'}) {
            if (!inArray(\@addrs, lc($addr->{'email_addr'}))) {
                push(@addrs, lc($addr->{'email_addr'}));
                if($addr->{'agency'} eq '1'){
            		$addr->{'class'} = "agency";
	            }
	            else{
	            	$addr->{'class'} = ($addr->{'from_portal'}) ? "portal" : "addlAddr";
	            }
                push(@temp, $addr);
            }
        }
    }
    
    foreach my $addr (sort {lc($a->{'email_addr'}) cmp lc($b->{'email_addr'})} @temp) {
        push(@{$data{'serviceAddresses'}}, $addr);
    }
    
    $templateFile = "showSvcList.tt";
} else {
    $templateFile = "eservice-form.tt";
}

if(defined $params{'efileCheck'}){
	$data{'efileCheck'} = 1;
}
else{
	$data{'efileCheck'} = 0;
}

$data{'markEmergency'} = $markEmergency;

print $info->header;

$data{'wfCount'} = $wfcount;
$data{'active'} = "cases";
$data{'tabs'} = $session->get('tabs');

doTemplate(\%data, "$templateDir/top", "header.tt", 1);
doTemplate(\%data,"$templateDir/eservice",$templateFile,1);