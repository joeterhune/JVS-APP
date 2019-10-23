#!/usr/bin/perl -w

BEGIN {
	use lib "$ENV{'JVS_PERL5LIB'}";
}

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use DB_Functions qw (
	dbConnect
	getData
);

my $info = new CGI;

my $params = $info->Vars;

if ((!defined($params->{'division'})) || (!defined($params->{'date'})) ||
	(!defined($params->{'starttime'})) || (!defined($params->{'endtime'}))) {
	print $info->header('text/plain');
	print "Incorrect parameters specified.";
	exit;
}

my $startTime = sprintf("%s %s", $params->{'date'}, $params->{'starttime'});
my $endTime = sprintf("%s %s", $params->{'date'}, $params->{'endtime'});

my $dbh = dbConnect("easycal");

my $query = qq {
	select
		count(*) as HearingCount
	from
		hearings
	where
		division = '$params->{division}'
	and (
		((hearing_start_time >= '$startTime') and (hearing_start_time < '$endTime'))
		or ((hearing_end_time > '$startTime') and (hearing_end_time <= '$endTime'))
		or ((hearing_start_time <= '$startTime') and (hearing_end_time >= '$endTime'))
	)
};

my @results;

getData(\@results,$query,$dbh);

print $info->header();

print $results[0]->{'HearingCount'};
exit;
