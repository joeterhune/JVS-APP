#!/usr/bin/perl -w
#
# bannerview.cgi - Banner Case Viewing Function
#

# location of PBSO.pm file - can't make relative in case juvenile

BEGIN {
	use lib "$ENV{'PERL5LIB'}";
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
    getShowcaseDb
    getUser
);

use Casenotes qw (
    getFlags
	getNotes
);

use Date::Calc qw(:all);
use Cwd;
use CGI::Carp qw(fatalsToBrowser);

use Showcase qw (
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
    getParties_civil
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
use XML::Simple;
use EService qw(
	getAttorneyAddresses
	getProSeAddresses
);
use Switch;

# Toggle eService on and off.
our $useEservice = 1;







sub doit {
    my $info=new CGI;

	my $icmsuser = getUser();
	
############### Added 11/6/2018 jmt security from conf 
	my $conf = XMLin("$ENV{'APP_ROOT'}/conf/ICMS.xml");
	my $secGroup = $conf->{'ldapConfig'}->{'securegroup'};
	my $sealedGroup = $conf->{'ldapConfig'}->{'sealedgroup'};
	my $sealedProbateGroup = $conf->{'ldapConfig'}->{'sealedprobategroup'};
	my $sealedAppealsGroup = $conf->{'ldapConfig'}->{'sealedappealsgroup'};
	my $sealedJuvGroup = $conf->{'ldapConfig'}->{'sealedjuvgroup'};
	my $odpsgroup = $conf->{'ldapConfig'}->{'odpsgroup'};
	my $icmsuser = $info->remote_user;
	
    my $ldap = ldapConnect();
    my $secretuser = inGroup($icmsuser,$secGroup,$ldap);
    my $sealeduser = inGroup($icmsuser,$sealedGroup,$ldap);
    my $jsealeduser = inGroup($icmsuser,$sealedJuvGroup,$ldap);
    my $odpuser = inGroup($icmsuser,$odpsgroup,$ldap);    my $psealeduser = 1; #inGroup($icmsuser,'CAD-ICMS-SEALED-PROBATE',$ldap);

	print $info->header({-expires => 0, -type => 'text/html'});
    my $caseid = $info->param('caseid');

	if(!defined($caseid) || ($caseid eq "")){
		my $caseNo = getSCCaseNumber($ucn);
		$caseid = getCaseID($caseNo);
		$ucn = $caseNo;
	}
    
    #$ucn =~ s/^50//g;
    $ucn =~ s/^50-//g;
    $ucn = "50-" . $ucn;
	
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
	$data{'notesuser'} = inGroup(getUser(), 'CAD-ICMS-NOTES', $ldap);
	$data{'showTif'} = inGroup(getUser(), 'CAD-ICMS-TIF', $ldap);
	$data{'odpuser'} = $odpuser;
	my $caseid = $info->param("caseid");
	$data{'caseid'} = $caseid;

	# UCN should be of format YYYY-CF-NNNNNN-A
	# banner case # YYYYCFNNNNNNAXX
	my $casenum=$ucn;
	#$casenum =~ s/-//g;
    $data{'casenum'} = $casenum;

	# don't look at sealed records!
	my $query = qq {
        SELECT
            CaseType,
            CourtType as CourtCode,
            DivisionID,
			Sealed,
            CaseNumber,
            CaseID
        from
            $schema.vCase
        where
            CaseID = ?
	};

	my $caseinfo = getDataOne($query,$dbh,[$caseid]);
	
	if(($caseinfo->{'Sealed'} eq 'Y') && (!$sealeduser)) {
		if (!($jsealeduser && inArray(['CJ','DP'], $caseinfo->{'CourtCode'})) 
			&& !($psealeduser && inArray(['GA','CP','MH'], $caseinfo->{'CourtCode'}))) {
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
	$data{'propertyAddress'} = getPropertyAddress($caseid,$dbh);
	
    # Ok, the user has access to the case.
    $data{'parties'} = [];
    $data{'attorneys'} = [];
    getParties_civil($caseid, $dbh, $data{'parties'}, $data{'attorneys'}, $casenum);

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
			CaseStatus,
			CaseStatus as Status,
			CONVERT(varchar,FileDate,101) as FileDate,
			CaseType,
			CaseStyle as CaseTypeDesc
		FROM
			$schema.vCase
		WHERE
			CaseID = ?
	};

	my $casesummary = getDataOne($query,$dbh,[$caseid]);

	$query = qq {
		SELECT
			CONVERT(varchar,MAX(EffectiveDate),101) as LastEventDate
		FROM
			$schema.vDocket
		WHERE
			CaseID = ?
	};

	my $activity = getDataOne($query,$dbh,[$caseid]);
	$casesummary->{'LastActivity'} = $activity->{'LastEventDate'};

    $caseinfo->{'CaseAge'} = getage($casesummary->{'FileDate'});
	escapeFields($casesummary);

    foreach my $key (keys %{$casesummary}) {
        $caseinfo->{$key} = $casesummary->{$key};
    }

	$data{'fees'} = {};
	getFees($caseid,$dbh,$data{'fees'});

	$data{'flags'} = [];
	$data{'casenotes'} = [];
	my $cnconn = dbConnect("icms");
	getFlags($ucn,$cnconn,$data{'flags'});
	getNotes($ucn,$cnconn,$data{'casenotes'});

	$cnconn->disconnect;

	$data{'linkedCases'} = [];
	getLinkedCases($caseid,$dbh,$data{'linkedCases'},$schema);

	$data{'events'} = [];
	getEvents($caseid, $dbh, $data{'events'}); 

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
		getWarrants($caseid, $dbh, $data{'warrants'});
		$data{'charges'} = [];
		getCharges($caseid, $dbh, $data{'charges'});
	}

    doTemplate(\%data,"$templateDir/casedetails","scCivilCaseDetails.tt",1);

	$dbh->disconnect;
}


#
# MAIN PROGRAM
#

doit();
