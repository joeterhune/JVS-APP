#!/usr/bin/perl

BEGIN {
	use lib "$ENV{'PERL5LIB'}";
};

use strict;
use DB_Functions qw(
	dbConnect
	getData
    getDivJudges
	getDataOne
);
use Calendars qw (
	getOLSJudges
	getOLSEvents
	getOLSDivs
	getCaseStyles
);
use Common qw (
	today
	dumpVar
	inArray
	transferFile
	$tmpDir
);

use File::Temp;
use XML::Simple;
use Date::Manip;

my %ftpConfig = (
	'ftpHost' => 'cocftp.clerk.local',
	'ftpDir' => 'courtscheduling',
	'ftpUser' => 'cadmin',
	'ftpPass' => 'cadmin/01'
);

# Don't buffer output.
$| = 1;

my $numberOfDays = 5;

my $start = &UnixDate("today","%Y-%m-%d");
my $end = &UnixDate(&DateCalc($start,"+$numberOfDays business days"),"%Y-%m-%d");
my $dbh = dbConnect("calendars");

# A listing of Judges/Divisions (keyed on the division) that will be used in cases where
# there is no OLS
my %divJudges;

getDivJudges(\%divJudges);

my @divs = sort keys (%divJudges);

my @olsDivs;
$dbh->do("use judge_divs");
getOLSDivs(\@olsDivs,$dbh);

my @keep;

foreach my $div (@olsDivs) {
	my $dbname = lc($div) . "event";

	my @events;
	my %caseStyles;
	my @judges;
	
	eval {
		$dbh->do("use $dbname");
	};

	if (!$@) {
		getOLSEvents($dbh,\@events,'all',$start,$end,$div);
        getCaseStyles($div,\%caseStyles);
		getOLSJudges($dbh,\@judges);
	} else {
		next;
	}

	foreach my $event (@events) {
		next if ($event->{'Canceled'} eq 'Y');
		my %temp;
		$temp{'CourtEventDate'} = $event->{'SchedDate'};
		$temp{'CourtEventTime'} = $event->{'SchedTime'};
		$temp{'CourtEventType'} = $event->{'HearingType'};
		$temp{'CaseNumber'} = sprintf("50%s",$event->{'CaseNumber'});
        $temp{'CaseNumber'} =~ s/-//g;
		if (defined($event->{'CaseStyle'})) {
			$temp{'CaseStyle'} = $event->{'CaseStyle'};
		} else {
			$temp{'CaseStyle'} = $caseStyles{$event->{'CaseNumber'}};
		}
		# Temporary until we start doing other divisions
		$temp{'DivisionName'} = "$div";
		$temp{'Location'} = $divJudges{$div}->{'Location'};

		# Assign the correct judge to the event:#

		my $judgeFound = 0;
		foreach my $judge (@judges) {
			next if ($judge->{'JudgeID'} != $event->{'JudgeID'});
			$temp{'JudgeName'} = $judge->{'FullName'};
			$judgeFound = 1;
			last;
		}

		if (!$judgeFound) {
			$temp{'JudgeName'} = $divJudges{$div};
		}

		push(@keep,\%temp);
	}
}

# Now get County Civil cases that have
my $bdbh = dbConnect("wpb-banner-prod");
my @bannerCivil;
getBannerCivilEvents($bdbh,\@bannerCivil,$start,$end);

foreach my $event (@bannerCivil) {
    next if ($event->{'Canceled'} eq 'Y');
    my %temp;
    $event->{'FirstName'} =~ s/^JUDGE\s?//g;
    $temp{'JudgeName'} = sprintf ("%s, %s", $event->{'LastName'}, $event->{'FirstName'});
    $temp{'CourtEventDate'} = $event->{'SchedDate'};
    $temp{'CourtEventTime'} = $event->{'SchedTime'};
    $temp{'CourtEventType'} = $event->{'HearingType'};
    $temp{'CaseNumber'} = $event->{'CaseNumber'};
    $temp{'DivisionName'} = $event->{'DivisionID'};
    if (defined($event->{'CaseStyle'})) {
        $temp{'CaseStyle'} = $event->{'CaseStyle'};
    }
    if ($event->{'CaseNumber'} =~ /^50/) {
        $temp{'CaseNumber'} = $event->{'CaseNumber'};
    } else {
        $temp{'CaseNumber'} = sprintf("50%s", $event->{'CaseNumber'});
    }
    $temp{'Location'} = $divJudges{$event->{'DivisionID'}}->{'Location'};
    
    push (@keep, \%temp);
}


my $xs = XML::Simple->new(
						  RootName => 'ArrayOfCourtAdminEvent',
						  NoAttr => 1,
						  XMLDecl => 1
						  );

my $fh = File::Temp->new(
						 DIR => $tmpDir,
						 UNLINK => 0
						 );
my $fname = $fh->filename;

my $xml = $xs->XMLout(
					  {CourtAdminEvent => \@keep},
					  OutputFile => $fh
					  );

close $fh;

my @now = localtime(time);

my $targetFile = sprintf("$tmpDir/outagefeed-%04d%02d%02d.xml", $now[5]+1900, $now[4]+1, $now[3]);

rename $fname, $targetFile;

transferFile($targetFile,\%ftpConfig, 1);

exit;

sub getBannerCivilEvents {
	my $dbh = shift;
	my $caseref = shift;
	
	my $startDate = shift;
	my $endDate = shift;
    
    my $query = qq {
        select
            csrcsev_case_id as "CaseNumber",
            ctrevnt_desc as "HearingType",
            csrcsev_sched_date as "SchedDate",
            to_char(to_date('1970-01-01 ' || csrcsev_start_time, 'YYYY-MM-DD HH24:MI:SS'),'HH:MI AM') as "SchedTime",
            csrcsev_judge_pidm as "JudgeID",
            spriden_last_name as "LastName",
            spriden_first_name as "FirstName",
            spriden_mi as "MiddleName",
            cdbcase_division_id as "DivisionID",
            cdbcase_desc as "CaseStyle",
			csrcsev_csev_seq as "Sequence"
        from
            csrcsev,
            ctrevnt,
            spriden,
            cdbcase
        where
            csrcsev_evnt_code=ctrevnt_code
            and csrcsev_case_id = cdbcase_id
            and spriden_pidm = csrcsev_judge_pidm
            and spriden_change_ind is null
            and csrcsev_sched_date > to_date(?,'YY-MM-DD')
            and csrcsev_sched_date < to_date(?,'YY-MM-DD')
        order by
            csrcsev_sched_date desc
    };
	
	my $tempRef = [];
    getData($tempRef, $query, $dbh, {valref => [$startDate, $endDate]});
	
	foreach my $event (@{$tempRef}) {
		# Find out if the event is canceled
		$query = qq {
			select
				cdrdoct_csev_seq
			from
				cdrdoct
			where
				cdrdoct_dtyp_code = 'EVCAN'
				and cdrdoct_csev_seq = ?
				and cdrdoct_case_id = ?
		};
		
		my $canc = getDataOne($query,$dbh,[$event->{'Sequence'}, $event->{'CaseNumber'}]);
		if (!defined($canc)) {
			push(@{$caseref}, $event);
		}
	}
}
