#!/usr/bin/perl -w

BEGIN {
    use lib "$ENV{'JVS_PERL5LIB'}";
}

use strict;
use Common qw (
    getArrayPieces
);
use DB_Functions qw (
    dbConnect
    getData
    getDataOne
    doQuery
    getDbSchema
);
use Showcase qw (
    $db
);
use POSIX qw (
    strftime
);

use VRB qw (
    processEvents
    getShowcaseEvents
    getLastImport
    updateLastImport
);

use Getopt::Long;

my $vrb = "rich-vrb";

GetOptions("d=s" => \$vrb);

my $vdbh = dbConnect($vrb);
doQuery("set foreign_key_checks=0", $vdbh);

my $sdbh = dbConnect($db);
my $schema = getDbSchema($db);

my $count = 0;
my $perQuery = 1000;

# To keep track of which PIDMs we've seen so we don't insert/update multiple times on the run
my %seenPIDMs;
my %seenDockets;
my %seenEvents;

# Find the time of the last imports (if any)
my $lastImport = getLastImport('case_events', $vdbh);

my $now = strftime "%Y-%m-%d %H:%M:%S", localtime;

$vdbh->begin_work;

my $showcaseEvents = {};
getShowcaseEvents($showcaseEvents, $sdbh, $schema, undef, $lastImport);
processEvents($showcaseEvents, \%seenDockets, $vdbh);

updateLastImport('case_events',$now, $vdbh);

$vdbh->commit();
