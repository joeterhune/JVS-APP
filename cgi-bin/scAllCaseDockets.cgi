#!/usr/bin/perl -w

BEGIN {
	use lib $ENV{'PERL5LIB'};
}

use strict;
use Common qw (
	dumpVar
	doTemplate
	$templateDir
    returnJson
    createTab
    getUser
    getSession
    checkLoggedIn
);
use DB_Functions qw (
	dbConnect
	getData
	getDbSchema
	getSubscribedQueues
	getSharedQueues
	getQueues
);
use Showcase qw(
	$db
	getDockets
);

use CGI;

my $info = new CGI;

checkLoggedIn();

my %params = $info->Vars;

my $user = getUser();
my $fdbh = dbConnect("icms");
	
my @myqueues = ($user);
my @sharedqueues;
	
getSubscribedQueues($user, $fdbh, \@myqueues);
getSharedQueues($user, $fdbh, \@sharedqueues);
my @allqueues = (@myqueues, @sharedqueues);
my %queueItems;
	
my $wfcount = getQueues(\%queueItems, \@allqueues, $fdbh);

createTab($params{'casenum'}, "/cgi-bin/search.cgi?name=" . $params{'casenum'}, 1, 1, "cases",
{ 
	"name" => "All Case Docket Listing",
	"active" => 1,
	"close" => 1,
	"href" => "/cgi-bin/case/scAllCaseDockets.cgi?casenums=" . $params{'casenums'} . "&caseids=" . $params{'caseids'} . "&casenum=" . $params{'casenum'},
	"parent" => $params{'casenum'}
});

my $session = getSession();
my $caseid = $params{'caseid'};

my %data;
$data{'CaseNumber'} = $params{'casenum'};

# The listing of case numbers will be passed in as a comma-separated string.  Split it up
my @otherCases = split(",", $params{'casenums'});

my $dbh = dbConnect($db);
my $schema = getDbSchema($db);

$data{'dockets'} = {};
getDockets(\@otherCases, $dbh, $data{'dockets'}, $schema, $caseid);

$data{'wfCount'} = $wfcount;
$data{'active'} = "cases";
$data{'tabs'} = $session->get('tabs');
	
print $info->header;
doTemplate(\%data, $templateDir, "casedetails/scAllCaseDockets.tt", 1);

