#!/usr/bin/perl

BEGIN {
    use lib "$ENV{'JVS_PERL5LIB'}";
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
    ldapLookup
    getSubscribedQueues
	getSharedQueues
	getQueues
);

checkLoggedIn();

use CGI;

my $info = new CGI;

my %params = $info->Vars;

my $user = getUser();
my $cdbh = dbConnect("icms");

my @myqueues = ($user);
my @sharedqueues;

getSubscribedQueues($user, $cdbh, \@myqueues);
getSharedQueues($user, $cdbh, \@sharedqueues);
my @allqueues = (@myqueues, @sharedqueues);
my %queueItems;

createTab("My E-Filing Status", "/cgi-bin/eservice/showFilings.cgi", 1, 1, "index");
my $session = getSession();

my $wfcount = getQueues(\%queueItems, \@allqueues, $cdbh);

my $ldapFilter = "(sAMAccountName=$user)";

my $userInfo = [];

ldapLookup($userInfo, $ldapFilter, undef, ['displayName','givenName','sn']);

my %data;

$data{'userInfo'} = $userInfo->[0];

$data{'wfCount'} = $wfcount;
$data{'active'} = "index";
$data{'tabs'} = $session->get('tabs');

print $info->header;
doTemplate(\%data, "$templateDir/top", "header.tt", 1);
doTemplate(\%data, $templateDir, "eservice/showFilings.tt", 1);