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
    inGroup
    getSubscribedQueues
	getSharedQueues
	getQueues
);

use Casenotes qw (
    getFlagTypes
);

checkLoggedIn();

use CGI;

my $info = new CGI;

my $user = getUser();
if (!inGroup($user, "CAD-ICMS-NOTES")) {
    print "You do not have rights to use this function.\n";
    exit;
}

my $fdbh = dbConnect("icms");

my @myqueues = ($user);
my @sharedqueues;

createTab("Bulk Case Notes", "/cgi-bin/case/casenotes/bulknote.cgi", 1, 1, "index");
my $session = getSession();

getSubscribedQueues($user, $fdbh, \@myqueues);
getSharedQueues($user, $fdbh, \@sharedqueues);
my @allqueues = (@myqueues, @sharedqueues);
my %queueItems;

my $wfcount = getQueues(\%queueItems, \@allqueues, $fdbh);


my %params = $info->Vars;

my %data;

$data{'title'} = "Bulk Case Notes";

$data{'wfCount'} = $wfcount;
$data{'active'} = "index";
$data{'tabs'} = $session->get('tabs');

print $info->header;
doTemplate(\%data, "$templateDir/top", "header.tt", 1);
doTemplate(\%data, "$templateDir/casenotes", "bulkNotes.tt", 1);