#!/usr/bin/perl

BEGIN {
	use lib "/usr/local/icms/bin";
}

use strict;
use Common qw (
	doTemplate
	$templateDir
	dumpVar
);

use DB_Functions qw (
	dbConnect
	doQuery
);

use Casenotes qw (
	updateSummaries
);

use CGI;

my $info = new CGI;

print $info->header();

my %params = $info->Vars;
my @clearNotes = $info->param('seq');

if (!scalar(@clearNotes)) {
	print "No notes were selected to delete.";
	exit;
}

my $inString = join(",", @clearNotes);

my $query = qq {
	delete from
		casenotes
	where
		seq in ($inString)
};

my $dbh = dbConnect("icms");
my $cleared = doQuery($query,$dbh);

updateSummaries($params{'ucn'}, $dbh);

$dbh->disconnect;

my %data;
$data{'cleared'} = $cleared;

if (defined($params{'lev'})) {
	$data{'lev'} = $params{'lev'};
} else {
	$data{'lev'} = 5;
}

doTemplate(\%data, "$templateDir/casenotes","delnote2.tt",1);