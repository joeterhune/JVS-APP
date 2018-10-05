#!/usr/bin/perl

BEGIN {
	use lib "/usr/local/icms/bin";
}

use strict;
use CGI qw (fatalsToBrowser);
use Common qw (
	dumpVar
	doTemplate
	$templateDir
);
use DB_Functions qw (
	doQuery
	dbConnect
	getDataOne
);

use Casenotes qw (
	updateSummaries
);

my $info = new CGI;

print $info->header();

my %params = $info->Vars;
my @clearFlags = $info->param('seq');

if (!scalar(@clearFlags)) {
	print "No notes were selected to delete.";
	exit;
}

my $inString = join(",", @clearFlags);

my $query = qq {
	delete from
		flags
	where
		idnum in ($inString)
};

my $dbh = dbConnect("icms");
my $cleared = doQuery($query,$dbh);

updateSummaries($params{'ucn'}, $dbh);

$dbh->disconnect;

my %data;

if (defined($params{'lev'})) {
	$data{'lev'} = $params{'lev'};
} else {
	$data{'lev'} = 5;
}

$data{'cleared'} = $cleared;

doTemplate(\%data,"$templateDir/casenotes","delflag2.tt",1)