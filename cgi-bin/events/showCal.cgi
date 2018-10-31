#!/usr/bin/perl

BEGIN {
    use lib "$ENV{'PERL5LIB'}";
}

use strict;
use Common qw (
    dumpVar
    doTemplate
	$templateDir
	US_date
);
use DB_Functions qw (
    dbConnect
    getData
);
use CGI qw (fatalsToBrowser);

my $info = new CGI;

print $info->header();

my %params = $info->Vars;

my %data = %params;

my $divs = $params{'divs'};
my @divs = split(/,/, $divs);

my $query = qq {
	select
		event_id as EventID,
		casenum as CaseNumber,
		case_div as DivisionID,
		case_style as CaseStyle,
		event_title as Title,
		date_format(event_date, '%m/%d/%Y') as EventDate,
		date_format(start_time, '%h:%m %p') as StartTime,
		date_format(end_time, '%h:%m %p') as EndTime,
		event_notes as Notes,
		date_format(created_timestamp,'%m/%d/%Y') as ScheduledDate,
		event_location as Location
	from
		events
	where
		1
};
if ($divs ne "AllDivs") {
	my @temp;
	foreach my $div (@divs) {
		push(@temp, "'$div'");
	}
	my $divStr = join(",", @temp);
	$query .= qq {
		and sched_div in ($divStr)
	}
}

my $varRef = [];

my $title = "Calendar for Divison " . join(", ", @divs) . " for ";

if (defined($params{'startdate'})) {
	# Range of dates
	push(@{$varRef}, $params{'startdate'});
	push(@{$varRef}, $params{'enddate'});
	$query .= qq {
			and event_date >= ?
			and event_date <= ?
	};
	
	$title .= sprintf ("%s - %s", US_date($params{'startdate'}), US_date($params{'enddate'}));
} elsif (defined($params{'casenum'})) {
	push(@{$varRef}, $params{'casenum'});
	$query .= qq {
		and casenum = ?
	};
	$title .= "case number $params{'casenum'}";
} else {
	push(@{$varRef}, $params{'date'});
	
	$query .= qq {
			and event_date = ?
	};
	
	$title .= US_date($params{'date'});
}

my @events;
my $dbh = dbConnect("events");
getData(\@events,$query,$dbh,{valref => $varRef});
foreach my $event (@events) {
	if ($event->{'CaseNumber'} =~ /(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)/) {
		$event->{'CaseNumber'} = sprintf("%04d-%s-%06d", $1, $2, $3);
	}
}

$dbh->disconnect();

$data{'events'} = \@events;
$data{'title'} = $title;

my $templateFile = "showCal.tt";
if ($data{'printCal'}) {
	$templateFile = "printCal.tt";
}

doTemplate(\%data,"$templateDir/events", $templateFile, 1);

exit;