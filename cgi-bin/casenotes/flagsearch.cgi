#!/usr/bin/perl

BEGIN {
    use lib $ENV{'PERL5LIB'};
}

use strict;
use Common qw(
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
    inGroup
    getSubscribedQueues
	getSharedQueues
	getQueues
);

checkLoggedIn();

use CGI qw(:standard);

my $info = new CGI;
my $user = getUser();

my %params = $info->Vars;

my $fdbh = dbConnect("icms");

my @myqueues = ($user);
my @sharedqueues;

my $url = "/cgi-bin/case/casenotes/flagsearch.cgi";
my $count = 0;
foreach my $p(keys %params){
	if($count < 1){
		$url .= "?" . $p . "=" . $params{$p};
	}
	else{
		$url .= "&" . $p . "=" . $params{$p};
	}
	$count++;
}

createTab("Flagged Case Report", $url, 1, 1, "cases");
my $session = getSession();

getSubscribedQueues($user, $fdbh, \@myqueues);
getSharedQueues($user, $fdbh, \@sharedqueues);
my @allqueues = (@myqueues, @sharedqueues);
my %queueItems;

my $wfcount = getQueues(\%queueItems, \@allqueues, $fdbh);

my $flagtypes = $params{'flagType'};

my %data;

$data{'division'} = $params{'division'};
$data{'flagTypes'} = $flagtypes;
if (defined($params{'startDate'})) {
	$data{'startDate'} = $params{'startDate'};
	$data{'endDate'} = $params{'endDate'};
} else {
	$data{'allDates'} = 1;
}
if (defined($params{'activeCases'})) {
	$data{'activeCases'} = 1;
}

$data{'wfCount'} = $wfcount;
$data{'active'} = "cases";
$data{'tabs'} = $session->get('tabs');

print $info->header;
doTemplate(\%data, "$templateDir/top", "header.tt", 1);
doTemplate(\%data,"$templateDir/casenotes","flagsearch.tt",1);