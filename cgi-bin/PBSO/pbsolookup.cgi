#!/usr/bin/perl -w

BEGIN {
    use lib "$ENV{'PERL5LIB'}";
}

use strict;
use Common qw (
    doTemplate
    returnJson
    $templateDir
    createTab
    getUser
    checkLoggedIn
    getSession
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

my $cdbh = dbConnect("icms");

my $user = getUser();

my @myqueues = ($user);
my @sharedqueues;

createTab("PBSO Search", "/cgi-bin/case/PBSO/pbsolookup.cgi", 1, 1, "index");
my $session = getSession();

getSubscribedQueues($user, $cdbh, \@myqueues);
getSharedQueues($user, $cdbh, \@sharedqueues);
my @allqueues = (@myqueues, @sharedqueues);
my %queueItems;

my $wfcount = getQueues(\%queueItems, \@allqueues, $cdbh);

my %params = $info->Vars;
my %data;
$data{'wfCount'} = $wfcount;
$data{'active'} = "index";
$data{'tabs'} = $session->get('tabs');

print $info->header;
doTemplate(\%data, "$templateDir/top", "header.tt", 1);
doTemplate(undef, "$templateDir/PBSO", "pbsolookup.tt", 1);