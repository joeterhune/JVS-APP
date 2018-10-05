#!/usr/bin/perl -w

# Script to check connections to various DBs (Banner, Showcase and PBSO)
# and run a very simple query on each.

BEGIN {
	use lib "/usr/local/icms/bin";	
};

use strict;
use ICMS;
use Common qw(
	dumpVar
);
use Time::HiRes qw (
	gettimeofday
	tv_interval
);

my $TIMEOUT = 10;

my $showcaseQuery = qq {
	select
		CaseNumber
	from
		vCase with(nolock)
	where
		-- Arbitrary case number
		CaseNumber='50-2003-TR-139663-AXXX-MB'
};

my $pbsoQuery = qq {
	select
		distinct InmateId,
		BookingId
	from
		vw_PBSOQueryBookingInfo
	where
		CaseNumber='2012018938'
};

checkDatabase($showcaseQuery,"showcase-prod");
checkDatabase($pbsoQuery,"pbso2");

sub checkDatabase {
	my $query = shift;
	my $dbname = shift;
	
	print "Checking database '$dbname'...\n";	
	
	my $startTime = [gettimeofday];
	
	my @results;
	eval {
		local $SIG{ALRM} = sub { die "timeout\n" };
		alarm $TIMEOUT;
		
		my $dbh = dbconnect($dbname);
		print "\tConnected...\n";
		sqlHashArray($query,$dbh,\@results);
		print "\tQuery successful.\n";
		
		$dbh->disconnect();
		alarm 0;
	};

	my $endTime = [gettimeofday];
	
	if ($@) {
		if ($@ eq 'timeout') {
			print "WARNING: System '$dbname' timed out ($TIMEOUT seconds) before query was completed.\n\n";
		}
		return;
	}
	
	my $elapsed = tv_interval $startTime, $endTime;
	
	print "Elapsed time to connect and query '$dbname': $elapsed seconds.\n\n"
}

