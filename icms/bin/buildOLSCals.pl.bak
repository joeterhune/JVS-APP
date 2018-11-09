#!/usr/bin/perl

BEGIN {
    use lib "$ENV{'PERL5LIB'}";
}

use strict;
use Common qw (
    dumpVar
    doTemplate
    $templateDir
);
use DB_Functions qw (
    dbConnect
    getData
    doQuery
);
use File::Temp qw(tempfile);
use Net::SCP qw (scp);
use Date::Calc qw (
    Add_Delta_DHMS
);
use Getopt::Long;

my @targetHosts = ("151.132.51.80","151.132.50.80");
my $scpUser = "root";

my @OLSDivs;

GetOptions("d=s" => \@OLSDivs);

if (!scalar(@OLSDivs)) {
    my $jdbh = dbConnect("judge-divs");
    my $query = qq {
        select
            division_id
        from
            divisions
        where
            has_ols = 1
    };
    my @rows;
    getData(\@rows, $query, $jdbh);
    $jdbh->disconnect;
    foreach my $row (@rows) {
        push(@OLSDivs, $row->{'division_id'});
    }
}

my $calDir = "/var/www/html/webcals";

my $sequenceFile = "/usr/local/icms/etc/calSequence.txt";

my $sequence;

if (!-f $sequenceFile) {
    $sequence = 1;
} else {
    open(SEQUENCE, $sequenceFile);
    my $seq = <SEQUENCE>;
    close SEQUENCE;
    chomp $seq;
    $sequence = $seq;
}

# Now write the new sequence value
$sequence++;
open(SEQUENCE, ">$sequenceFile");
print SEQUENCE $sequence;
close SEQUENCE;

my $dbh = dbConnect('calendars');

my @now = localtime(time);
my $datestr = sprintf("%04d%02d%02d", $now[5]+1900, $now[4]+1, $now[3]);
my $timestr = sprintf("%02d%02d%02d", $now[2], $now[1], $now[0]);

chdir($calDir) ||
    die "Unable to chdir to '$calDir': $!\n\n";

foreach my $div (@OLSDivs) {
    my @events;
    
    if ($div eq 'AW') {
        print "Rebuilding calendar for division AW...\n";
        rebuildCalendar($div,$dbh);
    }
    
    print "Creating calendar for division $div...\n";
    getEvents(\@events, $div, $dbh);
    #dumpVar($events[0]);
    #exit;
    getUMC(\@events, $div, $dbh);
    my %data;
    $data{'events'} = \@events;
    $data{'timestr'} = $timestr;
    $data{'datestr'} = $datestr;
    $data{'division'} = $div;
    $data{'sequence'} = $sequence;
    
    # Create the text for the file
    my $calText = doTemplate(\%data,"$templateDir/calendars","ols_ical.tt",0);
    
    # Create a temporary file
    my ($fh, $filename) = tempfile (DIR => $calDir, UNLINK => 1);
    
    if (!defined($fh)) {
        warn "There was an error creating the file for division $div: $!\n\n";
        next;
    }
    
    print $fh $calText;
    close $fh;
    
    # Now remove the existing file and rename the new file
    my $calFileName = "cal_div_$div.ics";
    
    rename $filename, $calFileName;
    chmod 0755, $calFileName;
    
    foreach my $target (@targetHosts) {
        my $targetFile = sprintf ("/var/www/html/scheduling/div%s/calDiv%s1.ics", lc($div), $div);
        my $scp = Net::SCP->new($target, $scpUser);
        $scp->put($calFileName, $targetFile);
        $targetFile = sprintf("/var/www/html/scheduling/div%s/data/divcs.txt", lc($div), $div);
        my $srcFile = sprintf("/var/www/Sarasota/civ/div%s/divcs.txt", uc($div));
        $scp->put($srcFile, $targetFile);
        $scp->quit;
    }
}

print "\n\nDone!!\n\n";


sub rebuildCalendar {
    # A necessary evil for AW
    my $div = shift;
    my $dbh = shift;
    
    my $db = sprintf("%sevent", lc($div));
    $dbh->do("use $db");
    
    print "Gathering information...\n";
    my $query = qq {
        select
            judge_code as JudgeID,
            upper(judge_firstname) as FirstName,
            upper(judge_lastname) as LastName,
            title as Title
        from
            judge
        order by
            judge_code
    };
    my %judges;
    getData(\%judges, $query, $dbh, {hashkey => 'JudgeID', flatten => 1});
    
    $query = qq {
        select
            s_type as SessionType,
            s_moredesc as SessionDescription,
            s_block_size as BlockSize
        from
            sessiontype
    };
    my %sessionTypes;
    getData(\%sessionTypes,$query,$dbh, {hashkey => 'SessionType', flatten => 1});
    
    # Now get all of the sessions from this date on
    $query = qq {
        select
            av_judge as JudgeID,
            av_date as SessionDate,
            av_time as SessionTime,
            av_type as SessionType,
            av_mins_per_session as SessionLength
        from
            bavailability
        where
            av_date >= CURRENT_DATE()
            and av_active > 0
        order by
            JudgeID
    };
    my %sessions;
    getData(\%sessions, $query, $dbh, {hashkey => 'JudgeID'});
    
    # OK, %sessions is a hash keyed on the Judge ID.
    #Each element is an array of that Judge's hearings
    # This will be one transaction.
    print "Starting transaction...\n";
    $dbh->{AutoCommit} = 0;
    
    # First, delete all of the existing calendar records.
    $query = qq {
        delete from
            calendar
    };
    
    doQuery($query, $dbh);
    
    # And now loop through the judges and their sessions, building each.
    foreach my $judgeid (keys %sessions) {
        # Build the Judge's name
        my $judgeName = sprintf("%s %s, %s", $judges{$judgeid}->{'Title'},
                                $judges{$judgeid}->{'LastName'},
                                $judges{$judgeid}->{'FirstName'});
    
        my $sessionRef = $sessions{$judgeid};
    
        foreach my $session (@{$sessionRef}) {
            my $blockSize = $sessionTypes{$session->{'SessionType'}}->{'BlockSize'};
    
            # Arguments for the query
            my @args = ($session->{'JudgeID'},
                        $session->{'SessionDate'}, $session->{'SessionTime'});
            my $sessQuery = qq {
                select
                    r_conf_num as ConfNum,
                    r_lf_name as LawFirm,
                    r_attny_name as AttorneyName,
                    cn_desc as CaseStyle,
                    cn_casenumber as CaseNumber,
                    r_created_by as CreatedBy,
                    DATE(r_created) as CreatedDate,
                    r_num_blocks as BlockCount,
                    r_motion_title as MotionTitle
                from
                    brequest r,
                    bcasenumber cn
                where
                    r_judge = ?
                    and r_status = 'req'
                    and r_date = ?
                    and r_time = ?
                    and r.r_conf_num = cn.cn_conf_num
                    and cn_active_cancelled = 1
                order by
                    CaseNumber
            };
    
            my @hearings;
            getData(\@hearings, $sessQuery, $dbh, {valref => \@args});
    
            # Don't write a 0-hearing block.
            next if (!scalar(@hearings));
    
            my $description = sprintf ("%d Scheduled Hearings: \\n", scalar(@hearings));
    
            foreach my $hearing (@hearings) {
                $hearing->{'CaseNumber'} =~ s/-//g;
                my $hearingString = sprintf ("%s - %s - %s - %s (%s) - %s", $hearing->{'CaseNumber'}, $hearing->{'CaseStyle'},
                                             $hearing->{'LawFirm'}, $hearing->{'CreatedBy'}, $hearing->{'CreatedDate'},
                                             $hearing->{'ConfNum'});
    
                if ((defined $blockSize) && ($blockSize > 0)) {
                    # It's a Special Set
                    my $minutes = $blockSize * $hearing->{'BlockCount'};
                    $hearingString .= sprintf ("- %s - %s - %d minutes", $hearing->{'MotionTitle'}, $hearing->{'AttorneyName'},
                                               $minutes);
                }
    
                $hearingString .= "\\n";
    
                $description .= $hearingString;
            }
    
            my $sessTitle = sprintf ("%s for %s with %d scheduled hearings",
                                     $sessionTypes{$session->{'SessionType'}}->{'SessionDescription'}, $judgeName,
                                     scalar(@hearings));
    
            $session->{'EndTime'} = addMinutes($session->{'SessionTime'},$session->{'SessionLength'});
    
            my $query = qq {
                insert into
                    calendar
                    (
                        title,
                        description,
                        startDate,
                        endDate,
                        startTime,
                        endTime,
                        cal_judge,
                        conf_num
                    )
                    values
                    (
                        ?,
                        ?,
                        ?,
                        ?,
                        ?,
                        ?,
                        ?,
                        ''
                    )
            };
            my @sessArgs = ($sessTitle,$description,$session->{'SessionDate'}, $session->{'SessionDate'},
                            $session->{'SessionTime'}, $session->{'EndTime'}, $judgeid);
            doQuery($query, $dbh, \@sessArgs);
        }
    }
    # All done?  Commit.
    print "Committing...\n";
    $dbh->commit;
    # Turn AC back on.
    $dbh->{AutoCommit} = 1;
}


sub addMinutes {
	my $startTime = shift;
	my $minutes = shift;

	# These are arbitrary - not needed except by the module
	my $year = 1970;
	my $month = 1;
	my $day = 1;

	my ($hour, $minute, $second) = split(":", $startTime);

	my ($nyear, $nmonth, $nday, $nhour, $nmin, $nsec) = Add_Delta_DHMS($year, $month, $day, $hour, $minute, $second,
																	   0, 0, $minutes, 0);
	my $string = sprintf("%02d:%02d:%02d", $nhour, $nmin, $nsec);
	return $string;
}



sub getEvents {
    my $eventRef = shift;
    my $div = shift;
    my $dbh = shift;
    
    my $query = qq {
        select
            id as EventID,
            title as EventTitle,
            DATE_FORMAT(startDate,'%Y%m%d') AS StartDate,
            DATE_FORMAT(endDate,'%Y%m%d') AS EndDate,
            description as EventDescription,
            TIME_FORMAT(startTime,'%H%i%s') AS StartTime,
            TIME_FORMAT(endTime,'%H%i%s') AS EndTime,
            cal_judge as JudgeID
        from
            calendar
    };
    
    if ($div eq "AW") {
        $query .= qq {
            where
                startDate >= CURRENT_DATE();
        }
    }
    
    my $db = sprintf("%sevent", lc($div));
    $dbh->do("use $db");
    
    getData($eventRef,$query,$dbh);
}


sub getUMC {
    # UMC doesn't have a calendars table.  Build the UMC calendar directly
    # from the UMC sessions and events tables.
    my $eventRef = shift;
    my $div = shift;
    my $dbh = shift;
    
    # get a listing of the non-canceled events, starting with today.
    my %umc_events;
    
    my $query = qq {
        select
            u.umc_session_id as SessionID,
            DATE_FORMAT(u.umc_date,'%Y%m%d') as StartDate,
            DATE_FORMAT(u.umc_date,'%Y%m%d') as EndDate,
            TIME_FORMAT(u.umc_start_time,'%H%i%s') as StartTime,
            TIME_FORMAT(u.umc_end_time,'%H%i%s') as EndTime,
            ue.casenum as CaseNumber,
            ue.case_style as CaseStyle,
            ue.umc_conf_num as ConfNum,
            ol.lawfirm_name as SchedulingFirmName,
            em.email_addr as SchedulerEmail,
            DATE_FORMAT(ue.scheduled_date,'%Y-%m-%d') as ScheduledDate
        from
            umc.umc_sessions u left outer join umc.umc_events ue on
                (u.umc_session_id = ue.umc_session_id),
            olscheduling.law_firms ol,
            olscheduling.users ou left outer join olscheduling.email_addresses em on
                (ou.login_id = em.email_addr_id)
        where
            u.umc_div = ?
            and umc_date >= CURRENT_DATE()
            and ue.sched_lawfirm_id = ol.lawfirm_id
            and ou.user_id = ue.sched_user_id
            and ue.canceled_date is null
    };
    getData(\%umc_events,$query,$dbh,{valref => [$div], hashkey => "SessionID"});
    
    foreach my $id (keys %umc_events) {
        my $events = $umc_events{$id};
        my $eventCount = scalar(@{$events});
        my %newEvent;
        my $first = $events->[0];
        $newEvent{'EventDescription'} = "$eventCount Scheduled Hearings: \\n";
        $newEvent{'StartDate'} = $first->{'StartDate'};
        $newEvent{'EndDate'} = $first->{'EndDate'};
        $newEvent{'StartTime'} = $first->{'StartTime'};
        $newEvent{'EndTime'} = $first->{'EndTime'};
        # Need this to build the event UID.  9999 should be sage
        $newEvent{'JudgeID'} = 9999;
        $newEvent{'EventTitle'} = sprintf("Uniform Motion Calendar with %i scheduled hearings", $eventCount);
        foreach my $event (@{$events}) {
            my $eventStr = sprintf("%s - %s - %s - %s (%s) - %s\\n", $event->{'CaseNumber'}, $event->{'CaseStyle'},
                                   $event->{'SchedulingFirmName'}, $event->{'SchedulerEmail'},
                                   $event->{'ScheduledDate'}, $event->{'ConfNum'});
            $newEvent{'EventDescription'} .= $eventStr;
        }
        push(@{$eventRef}, \%newEvent);
    }
}