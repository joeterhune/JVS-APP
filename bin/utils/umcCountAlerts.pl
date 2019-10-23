#!/usr/bin/perl -w

BEGIN {
	use lib "$ENV{'JVS_PERL5LIB'}";
}

use strict;

use Common qw (
	dumpVar
	doTemplate
	sendMessage
	$templateDir
);

use DB_Functions qw (
	dbConnect
	getData
);

# Get a listing of all of the UMC divisions with a designated email address

my $dbh = dbConnect('calendars');

$dbh->do('use umc');

my @divs;
my $query = qq {
	select
		umc_div,
		max_days_out,
		admin_email
	from
		umc_divs
	where
		admin_email is not null
		and admin_email <> ''
};

getData(\@divs, $query, $dbh);

foreach my $div (@divs) {
	# Get counts of the existing sessions out the max_days_out number of days
	$query = qq {
		select
	        umc_session_id as SessionID,
	        umc_div as DivisionID,
	        DATE_FORMAT(umc_date,'%m/%d/%Y') as SessionDate,
	        TIME_FORMAT(umc_start_time,'%h:%i %p') as StartTime,
	        TIME_FORMAT(umc_end_time,'%h:%i %p') as EndTime,
			umc_date as ISO_date,
			max_slots as MaxSlots,
	        slots_remaining as Remaining
	    from
	        umc_sessions
	    where
	        umc_date >= CURRENT_DATE()
	        and umc_date <= DATE_ADD(CURRENT_DATE(), INTERVAL ? day)
	        and umc_div = ?
	};

	my %sessions;
	getData(\%sessions, $query, $dbh, {valref => [$div->{'max_days_out'}, $div->{'umc_div'}], hashkey => "SessionID", flatten => 1});
	
	$query = qq {
		select
			us.umc_session_id as SessionID,
			count(ue.umc_conf_num) as ExemptCount
		from
			umc_sessions us left outer join umc_events ue on (
				us.umc_session_id = ue.umc_session_id
				and ue.umc_motion_type in (
					select
						motion_type
					from
						umc_exempt_motions
					where
						umc_div = ?
						)
			)
		where
			us.umc_date >= CURRENT_DATE()
			and us.umc_date <= DATE_ADD(CURRENT_DATE(), INTERVAL ? day)
			and ue.canceled_date is null
		group by
			SessionID
	};
	my %exemptions;
	getData(\%exemptions, $query, $dbh, {valref => [$div->{'umc_div'}, $div->{'max_days_out'}], hashkey => "SessionID", flatten => 1});
	
	$query = qq {
		select
			us.umc_session_id as SessionID,
			count(ue.umc_conf_num) as TotalCount
		from
			umc_sessions us left outer join umc_events ue on us.umc_session_id = ue.umc_session_id
		where
			umc_div = ?
			and us.umc_date >= CURRENT_DATE()
			and us.umc_date <= DATE_ADD(CURRENT_DATE(), INTERVAL ? day)
			and ue.canceled_date is null
		group by
			SessionID
	};
	my %totals;
	getData(\%totals, $query, $dbh, {valref => [$div->{'umc_div'}, $div->{'max_days_out'}], hashkey => "SessionID", flatten => 1});
	
	foreach my $key (keys %sessions) {
		$sessions{$key}->{'ExemptCount'} = $exemptions{$key}->{'ExemptCount'};
		$sessions{$key}->{'TotalCount'} = $totals{$key}->{'TotalCount'};
	}
	
	my $subject = sprintf ("Division %s UMC Availability in Next %d Days", $div->{'umc_div'}, $div->{'max_days_out'});

	my $totalAvail = 0;
	my @temp;
	foreach my $key (keys %sessions) {
		push(@temp, $sessions{$key});
		$totalAvail += $sessions{$key}->{'Remaining'};
	}
	# @temp is now an unsorted array of the sessions
	
	my @sorted = sort {$a->{'ISO_date'} cmp $b->{'ISO_date'}} @temp;
	
	my %data;
	$data{'sessions'} = \@sorted;
	$data{'remaining'} = $totalAvail;
	$data{'days_out'} = $div->{'max_days_out'};
	$data{'division'} = $div->{'umc_div'};

	my $body = doTemplate(\%data, "$templateDir/utils", "umcCountAlerts.tt", 0);
	
	my %recip = (
		'email_addr' => $div->{'admin_email'}
	);
	
	my %sender = (
		'fullname' => 'Web Help',
		'email_addr' => 'webhelp@jud12.flcourts.org'
	);
	
	sendMessage([\%recip], \%sender, undef, $subject, $body, undef, 0, 0);
}
