#!/usr/bin/perl

BEGIN {
	use lib "$ENV{'JVS_PERL5LIB'}";
}

use strict;
use Common qw (
	dumpVar
	doTemplate
	$templateDir
	inArray
	ISO_date
    returnJson
    checkLoggedIn
    getUser
    getSession
    createTab
);

use DB_Functions qw (
	dbConnect
	getData
	doQuery
    log_this
    getSubscribedQueues
	getSharedQueues
	getQueues
);

use Casenotes qw (
    calcExpire
	updateSummaries
);

use Date::Calc qw(
	Today
	Add_Delta_YM
	Add_Delta_Days
);

use Switch;

use CGI qw (fatalsToBrowser);

checkLoggedIn();

my $info = new CGI;

my %params = $info->Vars;

my @flagTypes = $info->param('flagtype');

my $expiration = calcExpire(\%params);

my $dbh = dbConnect("icms");
my $user = getUser();

my @myqueues = ($user);
my @sharedqueues;

getSubscribedQueues($user, $dbh, \@myqueues);
getSharedQueues($user, $dbh, \@sharedqueues);
my @allqueues = (@myqueues, @sharedqueues);
my %queueItems;

my $wfcount = getQueues(\%queueItems, \@allqueues, $dbh);

createTab("Flags and Notes", "/casenotes/flag.cgi?ucn=" . $params{'casenum'}, 1, 1, "cases");
my $session = getSession();

# Now set new flags; skip if the flag is already set.
my $skipped = 0;
my $added = 0;

$params{'dateval'} = ISO_date($params{'dateval'});

my $querycase = $params{'casenum'};
if ($querycase =~ /(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)/) {
    $querycase = sprintf("%04d-%s-%06d", $1, $2, $3);
}

foreach my $flag (@flagTypes) {
	my $query = qq {
		insert into
			flags (
				casenum,
				flagtype,
				userid,
				date,
				division,
				active,
				expires
			)
		values (
			?,?,?,?,?,1,?
		)
	};
	my @vals = ($querycase, $flag, getUser(), $params{'dateval'}, $params{'division'}, $expiration);
	doQuery($query,$dbh,\@vals);
	$added++;
    my $logMsg = sprintf("User %s added flag type %d to case %s", getUser(), $flag, $querycase);
    log_this('JVS','flagsnotes',$logMsg, $ENV{'REMOTE_ADDR'}, $dbh);
}

updateSummaries($params{'casenum'}, $dbh);

$dbh->disconnect;

my %data;
$data{'added'} = $added;
$data{'lev'} = $params{'lev'};
$data{'status'} = "Success";
$data{'ucn'} = $params{'casenum'};
$data{'wfCount'} = $wfcount;
$data{'active'} = "cases";
$data{'tabs'} = $session->get('tabs');

print $info->header;

doTemplate(\%data, "$templateDir/top", "header.tt", 1);
doTemplate(\%data, "$templateDir/casenotes", "flag2.tt", 1);

