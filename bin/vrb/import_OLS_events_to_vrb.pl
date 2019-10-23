#!/usr/bin/perl -w

BEGIN {
	use lib "$ENV{'JVS_PERL5LIB'}";
}

use strict;
use Common qw (
    dumpVar
	ISO_date
	today
);
use DB_Functions qw (
    dbConnect
    getData
    getDbSchema
    doQuery
);
use Calendars qw (
    $OLS_SOURCE_ID
    getVRBEvents
    sortExternalEvents
    vrbCompareAndUpdate
	getOLSDivs
	getOLSEvents
);

use XML::Simple;

use Getopt::Long;

my $vrb;
my $startDate;
GetOptions("d=s" => \$vrb, "s=s" => \$startDate);
if (!defined($vrb)) {
	$vrb = "vrb2";
}

if (!defined($startDate)) {
	$startDate = ISO_date(today());
}


my $SRC_ID = $OLS_SOURCE_ID;

my @olsDivs;
getOLSDivs(\@olsDivs);

my $dbh = dbConnect("ols");

my %events;

foreach my $div (@olsDivs) {
	my $olsDb = sprintf("%sevent", lc($div));
	$dbh->do("use $olsDb");
	
	my @events;
	getOLSEvents($dbh, \@events, 'all', $startDate, '2099-12-31', $div);
	foreach my $event (@events) {
		$event->{'Date'} = ISO_date($event->{'SchedDate'});
	}
	$events{$div} = \@events;
}

my %sorted;
sortExternalEvents(\%sorted, \%events);

$dbh->disconnect;

my $vdbh = dbConnect($vrb);

my %existing;
getVRBEvents(\%existing,$SRC_ID,$vdbh);

my %vrbSorted;
sortExternalEvents(\%vrbSorted,\%existing);

# Now that we have the existing records from VRB and the "official" records from the
# import source, do the work.
vrbCompareAndUpdate(\%vrbSorted,\%sorted,$SRC_ID,$vdbh);
