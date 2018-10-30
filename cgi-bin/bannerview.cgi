#!/usr/bin/perl -w
#
# bannerview.cgi - Banner Case Viewing Function
#

# location of PBSO.pm file - can't make relative in case juvenile

BEGIN {
	use lib $ENV{'PERL5LIB'};
};

use strict;
use DBI;
use CGI;
use ICMS;
use Common qw (
    inArray
	dumpVar
	escapeFields
	buildName
    $templateDir
    doTemplate
);

use Casenotes qw (
    getFlags
	getNotes
);

use Date::Calc qw(:all);
use Cwd;
use CGI::Carp qw(fatalsToBrowser);

use Banner qw (
	$otherCaseMax
	buildPhone
	lookupMailingAddress
	buildAddress
	getFees
	getLinkedCases
	getWarrants
	getCharges
    getOLSEvents
	getEvents
	getDockets
	getOtherCases
	getPropertyAddress
    getParties
    casenumtoucn
    getjudgename
    getjudgedivfromdiv
);

use DB_Functions qw (
	dbConnect
	doQuery
	getData
	getDataOne
	inGroup
	ldapConnect
);

use EService qw(
	getAttorneyAddresses
	getProSeAddresses
);
use Switch;

# Toggle eService on and off.
our $useEservice = 1;







sub doit {
    my $info=new CGI;

	my $icmsuser = $info->remote_user;
	
    my $ldap = ldapConnect();
    my $secretuser = inGroup($icmsuser,'CAD-ICMS-SEC',$ldap);
    my $sealeduser = inGroup($icmsuser,'CAD-ICMS-SEALED',$ldap);
    my $jsealeduser = inGroup($icmsuser,'CAD-ICMS-SEALED-JUV',$ldap);
    my $odpuser = inGroup($icmsuser,'CAD-ICMS-ODPS',$ldap);

	print $info->header({-expires => 0, -type => 'text/html'});
    my $ucn=uc(clean($info->param("ucn")));
    
    $ucn =~ s/^50//g;
	
    my $referer_host = (split("\/",$ENV{'HTTP_REFERER'}))[2];
    
    my $lev=clean($info->param("lev"));
    
    if ($lev eq "") {
        if ($referer_host ne $ENV{'HTTP_HOST'}) {
            $lev = 0;
        } else {
            $lev=3;
        }
    }

    my %data;
    $data{'lev'} = $lev;
    $data{'backlev'} = $lev - 1;
    $data{'nextlev'} = $lev + 1;
    $data{'ucn'} = $ucn;
	$data{'notesuser'} = inGroup($info->remote_user(), 'CAD-ICMS-NOTES', $ldap);
	$data{'showTif'} = inGroup($info->remote_user(), 'CAD-ICMS-TIF', $ldap);
	$data{'odpuser'} = $odpuser;

	# UCN should be of format YYYY-CF-NNNNNN-A
	# banner case # YYYYCFNNNNNNAXX
	my $casenum=$ucn;
	$casenum =~ s/-//g;
    $data{'casenum'} = $casenum;

	my $dbh = dbConnect("wpb-banner-prod");
	doQuery("alter session set nls_date_format='MM/DD/YYYY'",$dbh);

    # don't look at sealed records!
	my $query = qq {
        select
            cdbcase_ctyp_code as "CaseType",
            cdbcase_cort_code as "CourtCode",
            cdbcase_division_id as "DivisionID",
			CASE cdbcase_sealed_ind
				WHEN '3' THEN 'Y'
				ELSE 'N'
			END as "Sealed",
            cdbcase_id as "CaseNumber"
        from
            cdbcase
        where
            cdbcase_id = ?
	};

	my $caseinfo = getDataOne($query,$dbh,[$casenum]);
	
	if(($caseinfo->{'Sealed'} eq 'Y') && (!$sealeduser)) {
		if (!($jsealeduser && inArray(['CJ','DP'],$caseinfo->{'CaseType'}))) {
            $dbh->disconnect;
            $data{'denyReason'} = "sealed";
            doTemplate(\%data,$templateDir,"noAccess.tt",1);
            exit;
		}
	}

	# don't let users that don't have access to secret cases see them.
    if(!$secretuser){
		if(inArray(['AD','AJ','CJ','DP','TE','TP','TB'], $caseinfo->{'CaseType'})) {
            $dbh->disconnect;
            $data{'denyReason'} = "restricted";
			print "<br/>Case number $ucn is a restricted case.  No information can be provided.\n";
			exit(1);
		}
	}

	# Get property addresses
	$data{'propertyAddress'} = getPropertyAddress($casenum,$dbh);
	
    # Ok, the user has access to the case.
    $data{'parties'} = [];
    $data{'attorneys'} = [];
    getParties($casenum, $dbh, $data{'parties'}, $data{'attorneys'});

#	if (!scalar(@{$data{'parties'}})) {
#        print "<br/>No information was found for case number $ucn.\n";
#		$dbh->disconnect;
#        exit(1);
#	}

    $data{'caseinfo'} = $caseinfo;

	# set criminal flag based on cort code
	my $crimflag = 0;
	if(inArray(['CJ'], $caseinfo->{'CourtCode'})) {
		$crimflag=1;
	}

	# get judge and division information
	my($div,$judge);

	$data{'judge'} = getjudgedivfromdiv($caseinfo->{'DivisionID'},$dbh);

	$query = qq {
		select
			SRS_STATUS_CODE('$casenum') as "CaseStatus",
			cdbcase_dtyp_code_status as "Status",
			cdbcase_init_filing as "FileDate",
			ctvctyp_code as "CaseType",
			ctvctyp_desc as "CaseTypeDesc"
		from
			cdbcase,
			ctvctyp
		where
			cdbcase_id = ?
			and cdbcase_ctyp_code=ctvctyp_code
	};

	my $casesummary = getDataOne($query,$dbh,[$casenum]);

	$query = qq {
		select
			max(cdrdoct_filing_date) as "LastEventDate"
		from
			cdrdoct
		where
			cdrdoct_case_id = ?
	};

	my $activity = getDataOne($query,$dbh,[$casenum]);
	$casesummary->{'LastActivity'} = $activity->{'LastEventDate'};

    $caseinfo->{'CaseAge'} = getage($casesummary->{'FileDate'});
	escapeFields($casesummary);

    foreach my $key (keys %{$casesummary}) {
        $caseinfo->{$key} = $casesummary->{$key};
    }

	$data{'fees'} = {};
	getFees($casenum,$dbh,$data{'fees'});

	$data{'flags'} = [];
	$data{'casenotes'} = [];
	my $cnconn = dbConnect("icms");
	getFlags($ucn,$cnconn,$data{'flags'});
	getNotes($ucn,$cnconn,$data{'casenotes'});

	$cnconn->disconnect;

	$data{'linkedCases'} = [];
	getLinkedCases($casenum, $lev, $dbh, $data{'linkedCases'});

	$data{'events'} = [];
	getEvents($casenum, $dbh, $data{'events'});

    # Get OLS events for those divisions that participate
    my $jdbh = dbConnect("judge-divs");
    $query = qq {
        select
            d.division_id,
            c.courthouse_abbr
        from
            divisions d,
            courthouses c
        where
            division_id = ?
            and has_ols = 1
            and d.courthouse_id = c.courthouse_id
    };
    my $hasols = getDataOne($query,$jdbh,[$caseinfo->{'DivisionID'}]);
    $jdbh->disconnect;

    if (defined($hasols)) {
        $data{'olsevents'} = [];
        getOLSEvents($casenum, $dbh, $data{'olsevents'}, $caseinfo->{'DivisionID'}, $hasols->{'courthouse_abbr'});
    }

	#$data{'dockets'} = [];
	#getDockets($casenum, $dbh, $data{'dockets'});

	if ($casenum=~/DP|CJ|DR/i) {
		$data{'showCrim'} = 1;
		$data{'warrants'} = [];
		getWarrants($casenum, $dbh, $data{'warrants'});
		$data{'charges'} = [];
		getCharges($casenum, $dbh, $data{'charges'});
	}

    doTemplate(\%data,"$templateDir/casedetails","bannerCaseDetails.tt",1);

	$dbh->disconnect;
}


#
# MAIN PROGRAM
#

doit();
