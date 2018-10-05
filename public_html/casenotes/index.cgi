#!/usr/bin/perl

# $Id: index.cgi 2196 2015-08-22 12:51:51Z rhaney $

BEGIN {
    use lib $ENV{'PERL5LIB'};
}

use strict;
use Common qw (
	$templateDir
	doTemplate
	dumpVar
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
use CGI::Carp qw (fatalsToBrowser);

checkLoggedIn();

my $info = new CGI;

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

my %data;
$data{'casenum'} = $params{'ucn'};

createTab("Flags and Notes", "/casenotes/index.cgi?ucn=" . $params{'ucn'} . "&div=" . $params{'div'}, 1, 1, "cases");
my $session = getSession();

if ($data{'casenum'} =~ /(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)/) {
	# It's a banner-type casenum, without dashes.  Convert it.
	$data{'casenum'} = sprintf("%04d-%s-%06d", $1, $2, $3);
}

$data{'lev'} = $params{'lev'};
$data{'division'} = $params{'div'};

$data{'wfCount'} = $wfcount;
$data{'active'} = "cases";
$data{'tabs'} = $session->get('tabs');

print $info->header;

doTemplate(\%data, "$templateDir/top", "header.tt", 1);
doTemplate(\%data,"$templateDir/casenotes","index.tt",1);