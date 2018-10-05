#!/usr/bin/perl -w

BEGIN {
	use lib "$ENV{'DOCUMENT_ROOT'}/../lib";
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
	getSubscribedQueues
	getSharedQueues
	getQueues
);

checkLoggedIn();

use CGI;

my $info = new CGI;

my %params = $info->Vars;

my %data;

my $cdbh = dbConnect("icms");
my $jdbh = dbConnect("judge-divs");

my $user = getUser();

my @myqueues = ($user);
my @sharedqueues;

createTab("Flagged Case Search", "/cgi-bin/case/casenotes/flaggedCaseSearch.cgi", 1, 1, "index");
my $session = getSession();

getSubscribedQueues($user, $cdbh, \@myqueues);
getSharedQueues($user, $cdbh, \@sharedqueues);
my @allqueues = (@myqueues, @sharedqueues);
my %queueItems;

my $wfcount = getQueues(\%queueItems, \@allqueues, $cdbh);

my $query = qq {
	select
		flagtype,
		dscr
	from
		flagtypes
	order by
		dscr
};

$data{'flagtypes'} = [];
getData($data{'flagtypes'}, $query, $cdbh);
$data{'showCount'} = (scalar(@{$data{'flagtypes'}}) > 25) ? 15 : scalar(@{$data{'flagtypes'}});

$query = qq {
	select
		division_id
	from
		divisions
	where
		show_icms_list = 1
};
$data{'divisions'} = [];
getData($data{'divisions'}, $query, $jdbh);


$data{'wfCount'} = $wfcount;
$data{'active'} = "index";
$data{'tabs'} = $session->get('tabs');

print $info->header;

doTemplate(\%data, "$templateDir/top", "header.tt", 1);
doTemplate(\%data, "$templateDir/casenotes", "flaggedCaseSearch.tt", 1);