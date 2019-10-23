package Reports;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    getVrbEventsByCaseList
    getLastDocketFromList
    buildNoHearings
    buildCAJuryCaseList
    buildLOS
    buildContested
);

use Common qw(
    dumpVar
    getArrayPieces
    convertCaseNumber
    sanitizeCaseNumber
    getShowcaseDb
);

use DB_Functions qw (
    dbConnect
    getData
    doQuery
    getDbSchema
);

use ICMS;

our $dbName = getShowcaseDb();
our $schema = getDbSchema($dbName);

sub buildContested {
    my $caselist = shift;
    my $contested = shift;
    my $uncontested = shift;
    my $dbh = shift;
    
    # Get the cases from the list that have Mediation Reports
    my %mediation;
    getLastDocketFromList($caselist, ['MRPT'],\%mediation,"showcase",$dbh);
    
    my @mediated;
    foreach my $case (keys %mediation) {
        push(@mediated,$mediation{$case}->{'CaseNumber'});
    }
    
    # And the cases from the mediated list that have agreements
    my %agreement;
    getLastDocketFromList(\@mediated, ['AGR','AGOR'], \%agreement, "showcase", $dbh);
    
    # Ok, now go through the original case list.  If there is an AGR, then the case is uncontested;
    # otherwise, it's contested.
    foreach my $case (@{$caselist}) {
        #my $checkCase = convertCaseNumber($case);
        my $checkCase = $case;
        if (!defined($agreement{$checkCase})) {
            $contested->{$checkCase} = 1;
        } else {
            $uncontested->{$checkCase} = 1;
        }
    }
}



sub buildLOS {
    my $caselist = shift;
    my $los = shift;
    my $dbh = shift;
    
    my %summonses;
    my %later;
    
    my $count = 0;
    my $perQuery = 1000;
    while ($count < scalar(@{$caselist})) {
        my @temp;
        getArrayPieces($caselist, $count, $perQuery, \@temp, 1);
    
        my $inString = join(",", @temp);
    
        my $query = qq {
            SELECT
                cd.DocketCode,
                CONVERT(VARCHAR(10), cd.EffectiveDate, 101) AS EffectiveDate,
                cd.CaseNumber
            FROM
                $schema.vDocket cd
            INNER JOIN $schema.vCase cc
                ON cd.CaseID = cc.CaseID
                AND cc.CaseNumber in ($inString)
            where
                cd.EffectiveDate <= DATEADD(day, -120, GETDATE())
                AND cd.DocketCode = 'SMIS'
            ORDER BY
                cd.EffectiveDate desc
        };

        getData(\%summonses, $query, $dbh, {hashkey => "CaseNumber", flatten => 1});
    
        $count +=  $perQuery;
    }
    
    my @queryCases = keys(%summonses);
    
    $count = 0;
    while ($count < scalar(@queryCases)) {
        my @temp;
        getArrayPieces(\@queryCases, $count, $perQuery, \@temp, 1);
        
        my $inString = join(",", @temp);
        
        my $query = qq{
            SELECT
                DocketCode,
                CONVERT(VARCHAR(10), EffectiveDate, 101) AS EffectiveDate,
                CaseNumber
            FROM
                $schema.vDocket
            WHERE
                CaseNumber in ($inString)
                AND DocketCode not in ('SMIS','NSRTN','ODS','SVNRE')
            order by
                EffectiveDate desc
        };
        
        getData(\%later, $query, $dbh, {hashkey => "CaseNumber", flatten => 1});
        
        $count += $perQuery;
    }
    
    foreach my $case (@queryCases) {
        #print "$case,$summonses{$case}->{'EffectiveDate'},$summonses{$case}->{'DocketCode'},$later{$case}->{'EffectiveDate'},$later{$case}->{'DocketCode'}\n";
        if (!defined($later{$case})) {
            $los->{convertCaseNumber($case)} = 1;
        } else {
            if ($later{$case}->{'EffectiveDate'} le $summonses{$case}->{'EffectiveDate'}) {
                $los->{convertCaseNumber($case)} = 1;
            }
        }
    }
}

sub getVrbEventsByCaseList {
    my $caseList = shift;
    my $eventRef = shift;
    my $past = shift;
    my $startDate = shift;
    
    my $count = 0;
    my $perQuery = 100;
    
    # Transform the $caseList to the @cases array, just changing the Banner 
    my @cases;
    foreach my $casenum (@{$caseList}) {
        push(@cases, convertCaseNumber($casenum));
    }
    
    my @cases_vrb;
    foreach my $casenum (@{$caseList}) {
        push(@cases_vrb, convertCaseNumber($casenum, 1));
    }
    
    if (!defined($past)) {
        $past = 0;
    }
    
    if (!defined($startDate)) {
        $startDate = "NOW()";
    }
    
    my $dateStr;
    
    if ($past) {
        $dateStr = qq{and start_date < $startDate};
    } else {
        $dateStr = qq{and start_date >= $startDate};
    }
    
    my $dbh = dbConnect("vrb2");
    
    my %events;
    
    while ($count < scalar(@cases)) {
        my @temp;
        getArrayPieces(\@cases, $count, $perQuery, \@temp, 1);
        my $inString = join(",", @temp);
        
        my @temp_vrb;
        getArrayPieces(\@cases_vrb, $count, $perQuery, \@temp_vrb, 1);
        my $inString_vrb = join(",", @temp_vrb);
        
        my $query = qq {
            select
                ec.case_num as CaseNumber,
                ec.event_id as EventID,
                DATE_FORMAT(e.start_date,'%m/%d/%Y') as EventDate,
                DATE_FORMAT(e.start_date,'%Y-%m-%d') as ISODate,
                e.event_name as EventType
            from
                event_cases ec
                    left outer join events e on (ec.event_id = e.event_id)
            where
                ( case_num in ($inString) OR case_num IN ($inString_vrb))
                $dateStr
            order by
                start_date desc
        };
        
        getData(\%events, $query, $dbh, {hashkey => 'CaseNumber', 'flatten' => 1});
        
        $count += $perQuery;
    }
    
    foreach my $casenum (@cases) {
        my $checkCase = convertCaseNumber($casenum);
        my $checkCase_vrb = convertCaseNumber($casenum, 1);
        if (defined($events{$checkCase})) {
            $eventRef->{$casenum} = $events{$checkCase};
        }
        elsif (defined($events{$checkCase_vrb})) {
            $eventRef->{$casenum} = $events{$checkCase_vrb};
        }
    }
}


sub getLastDocketFromList {
    # Given a list of docket codes and a list of cases, get the most recent docket from the list for each case.
    # The list of docket codes should be an unquoted array of possible codes (such a @MOTIONS) and the resulting
    # list will contain the last one to match any of the target codes
    my $caseList = shift;       # Unquoted list of case numbers
    my $docketList = shift;     # UNqquoted list of docket codes
    my $docketRef = shift;      # A hash ref
    my $dbType = shift;         # showcase or banner
    my $dbh = shift;
    my $schema = shift;
    
    if (!defined($dbh)) {
        my $dbName = getShowcaseDb();
        $dbh = dbConnect($dbName);
    }
    
    if (!defined($schema)) {
        my $dbName = getShowcaseDb();
        $schema = getDbSchema($dbName);
    }
    
    # First, sanitize the case numbers into an array
    my @cases;
    foreach my $casenum (@{$caseList}) {
        push(@cases, convertCaseNumber($casenum));
    }
    
    # Then build a quoted array of the docket codes and build a SQL string with them
    my @dockets;
    getArrayPieces($docketList,0,1000,\@dockets,1);
    
    my $inDocket = join(",",@dockets);
    
    my $count = 0;
    my $perQuery = 1000;
    
    my %dockets;
    
    while ($count < scalar(@cases)) {
        my @temp;
        getArrayPieces(\@cases, $count, $perQuery, \@temp, 1);
        
        my $query;

        my $inCase = join(",", @temp);
        
        $query = qq {
            select
                DocketCode,
                CONVERT(char(10),EffectiveDate,120) as EffectiveDate,
                CaseNumber,
                UCN
            from
                $schema.vDocket with(nolock)
            where
                DocketCode in ($inDocket)
                and CaseNumber in ($inCase)
            order by
                EffectiveDate desc
        };
        getData(\%dockets, $query, $dbh, {hashkey => 'UCN', flatten => 1});
        
        $count += $perQuery;
    }
    
    foreach my $casenum (@cases) {
        my $checkCase = $casenum;
        $checkCase =~ s/-//g;
        if (defined($dockets{$checkCase})) {
            $docketRef->{$casenum} = $dockets{$checkCase};
        }
    } 
}

sub buildNoHearings {
	my $justcases = shift;
	my $motionNoEvent = shift;
    my $MSGS = shift;
	
	my %lastDockets;
    
    if ($MSGS) {
        print "Querying last dockets from case list...\n";
    }
    
    #my $firstCase = $justcases->[0];
    my $dbType = "showcase";
    
	getLastDocketFromList($justcases, \@MOTIONS, \%lastDockets, $dbType);
	
    if ($MSGS) {
        print "Done querying last dockets from case list...\n";
    }
    
	my $earliest = "9999-99-99";
	
	foreach my $case (keys %lastDockets) {
		# Find the earliest of all of the dockets in %lastDockets
		if ($lastDockets{$case}->{'EffectiveDate'} lt $earliest) {
			$earliest = $lastDockets{$case}->{'EffectiveDate'};
		}
	}

    if ($MSGS) {
        print "Querying VRB events from case list...\n";
    }

	my %events;
	# Find the events for the cases after $earliest (not after now - we need to be sure to catch events before today)
	getVrbEventsByCaseList($justcases,\%events, undef, $earliest);
	
	foreach my $case (keys %lastDockets) {
	    if (!defined($events{$case})) {
	        # No event at all for this case after the earliest date
            $motionNoEvent->{$case} = 1;
	        next;
	    }
    
	    # Ok, there's an event - is if after the date of the docket?
	    my $docketDate = $lastDockets{$case}->{'EffectiveDate'};
	    my $evtDate = $events{$case}->{'ISODate'};
    
	    
		if ($docketDate gt $evtDate) {
		    # The motion is after the last event.
            $motionNoEvent->{$case} = 1;
		}
	}
    
    if ($MSGS) {
        print "Done querying VRB events from case list...\n";
    }
}


sub buildCAJuryCaseList {
    my $caselist = shift;
    my $juryCaseList = shift;   # A hash ref
    my $dbh = shift;
    
    if (!defined($dbh)) {
        #$dbh = dbConnect("showcase-rpt");
        my $dbName = getShowcaseDb();
        $dbh = dbConnect($dbName);
    }
    
    my $docketlist = ['OSJT'];  # Order Setting Jury Trial
    
    my %juryTrials;
    
    my @cacases;
    # Only check CA cases - UFC and Circuit Civil don't apply here
    foreach my $case (@{$caselist}) {
        if ($case =~ /CA/) {
            push(@cacases, $case);
        }
    }
    
    if (scalar(@cacases)) {
        getLastDocketFromList(\@cacases, $docketlist, \%juryTrials, "showcase", $dbh);
    }
    
    foreach my $case (keys %juryTrials) {
        $juryCaseList->{$case} = 1;
    }
    
    return scalar(keys %{$juryCaseList});
}

1;
