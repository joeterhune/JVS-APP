#!/usr/bin/perl

BEGIN {
	use lib "$ENV{'PERL5LIB'}";
}

use strict;
use DB_Functions qw (
	dbConnect
	doQuery
	getData
);
use Calendars qw (
	writeCal
);

use CGI;

my $info = new CGI;

my %params = $info->Vars;

my @keepdivs;

# Get a listing of all of the affected sched_divs so the calendars can be a
my $dbh = dbConnect("events");

my $query = qq {
	select
		distinct(sched_div)
	from
		events
	where
		event_id in ($params{'delvals'})
};
getData(\@keepdivs, $query,$dbh);

$query = qq {
	delete from
		events
	where
		event_id in ($params{'delvals'})
};

doQuery($query,$dbh);

# Write the calendar(s) for the division(s)
foreach my $div (@keepdivs) {
	writeCal($div->{'sched_div'},$dbh);
}

$dbh->disconnect;

my $redirect = sprintf("showCal.cgi?divs=%s", $params{'divs'});

my $dateStr;
if (defined($params{'startdate'})) {
	$dateStr = sprintf("&amp;startdate=%s&amp;enddate=%s", $params{'startdate'}, $params{'enddate'});
} else {
	$dateStr = sprintf("&amp;date=%s", $params{'date'});
}

$redirect .= $dateStr;

print $info->redirect($redirect);

exit;
