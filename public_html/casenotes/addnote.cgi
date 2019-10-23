#!/usr/bin/perl

BEGIN {
	use lib "$ENV{'JVS_PERL5LIB'}";
}

use strict;
use Common qw (
	$templateDir
	doTemplate
	dumpVar
	today
    returnJson
    createTab
    getUser
    getSession
    checkLoggedIn
);
use DB_Functions qw (
	dbConnect
	getData
	getSubscribedQueues
	getSharedQueues
	getQueues
);
use CGI;

checkLoggedIn();

my $info = new CGI;

my $user = getUser();
my $dbh = dbConnect("icms");

my @myqueues = ($user);
my @sharedqueues;

getSubscribedQueues($user, $dbh, \@myqueues);
getSharedQueues($user, $dbh, \@sharedqueues);
my @allqueues = (@myqueues, @sharedqueues);
my %queueItems;

my $wfcount = getQueues(\%queueItems, \@allqueues, $dbh);

my %params = $info->Vars;

createTab("Flags and Notes", "/casenotes/addnote.cgi?ucn=" . $params{'ucn'}, 1, 1, "cases");
my $session = getSession();

my %data;
$data{'casenum'} = $params{'ucn'};
$data{'division'} = $params{'division'};
$data{'user'} = getUser();
$data{'today'} = today();
$data{'wfCount'} = $wfcount;
$data{'active'} = "cases";
$data{'tabs'} = $session->get('tabs');

print $info->header;

doTemplate(\%data, "$templateDir/top", "header.tt", 1);
doTemplate(\%data,"$templateDir/casenotes","addnote.tt",1)