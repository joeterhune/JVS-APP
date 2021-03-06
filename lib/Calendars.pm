package Calendars;

BEGIN {
	use lib "$ENV{'JVS_PERL5LIB'}";
};

use strict;
use warnings;

use Common qw(
    today
    dumpVar
    US_date
    getArrayPieces
    sanitizeCaseNumber
    inArray
    ISO_date
	returnJson
	getShowcaseDb
);

use DB_Functions qw (
    dbConnect
    doQuery
    getData
    getDataOne
    $DEFAULT_SCHEMA
    lastInsert
    getDbSchema
);

use PBSO2 qw (
    getMugshotWithJacketId
);

our $db = getShowcaseDb();
our $scdbh = dbConnect($db);
our $schema = getDbSchema($db);

use File::Temp;

use POSIX qw (
    strftime
);

use XML::Simple;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    %caseTypes
    %divMaps
    @MONTHS
    vrbCompareAndUpdate
    getFirstAppearance
    getOLSEvents
    getDivType
    getVRBEvents
    getVRBCalendar
    getOLSJudges
    getJudges
    getMagistrates
    getMediators
    getScEvents
    getBannerEvents
    getOLSDivs
    sortExternalEvents
    $SC_SOURCE_ID
    $BANNER_SOURCE_ID
    $OLS_SOURCE_ID
    getMagistrateCalendar
    getMediatorCalendar
    getExParteCalendar
    getMentalHealthCalendar
);

use Data::ICal;
use Data::ICal::Entry::Event;
use Date::ICal;

# Source numbers to be used for importing into VRB (these match the import_sources table
# in the VRB2 database)
our $SC_SOURCE_ID = 2;
our $BANNER_SOURCE_ID = 3;
our $OLS_SOURCE_ID = 4;


our %divMaps = (
    "AA" => "Main",
    "AB" => "Main",
    "AD" => "Main",
    "AE" => "Main",
    "AF" => "Main",
    "AG" => "Main",
    "AH" => "Main",
    "AI" => "Main",
    "AJ" => "Main",
    "AN" => "Main",
    "AO" => "Main",
    "AW" => "Main",
    "FA" => "Main",
    "FB" => "Main",
    "FC" => "Main",
    "FD" => "Main",
    "FH" => "North",
    "FI" => "North",
    "FJ" => "North",
    "FW" => "West",
    "FT" => "South",
    "FV" => "South",
    "FX" => "South",
    "FY" => "South",
    "FZ" => "South",
    "IB" => "Main",
    "IC" => "Main",
    "IX" => "South",
    "IY" => "South",
    "IZ" => "South",
    "IH" => "North",
    "II" => "North",
    "RA" => "West",
    "RB" => "Main",
    "RD" => "South",
    "RE" => "Main",
    "RF" => "Main",
    "RH" => "North",
    "RJ" => "Main",
    "RL" => "Main",
    "RS" => "South",
);

our %caseTypes = (
    "A*" => ["CA","AP"],
    "F*" => ["DA","DR"],
    "I*" => ["CP","MH","GA","WO"],
    "J*" => ["CJ","DP","DR","WO"],
    "R*" => ["CC","SC"]
);

our @MONTHS = (
    { 'monthnum' => 1, 'monthname' => 'Jan'},
    { 'monthnum' => 2, 'monthname' => 'Feb'},
    { 'monthnum' => 3, 'monthname' => 'Mar'},
    { 'monthnum' => 4, 'monthname' => 'Apr'},
    { 'monthnum' => 5, 'monthname' => 'May'},
    { 'monthnum' => 6, 'monthname' => 'Jun'},
    { 'monthnum' => 7, 'monthname' => 'Jul'},
    { 'monthnum' => 8, 'monthname' => 'Aug'},
    { 'monthnum' => 9, 'monthname' => 'Sep'},
    { 'monthnum' => 10, 'monthname' => 'Oct'},
    { 'monthnum' => 11, 'monthname' => 'Nov'},
    { 'monthnum' => 12, 'monthname' => 'Dec'}
);

our $easyCalDir = "/var/www/html/webcals";

sub getCaseStyles {
	my $division = shift;
	my $caseref = shift;

	$division = uc($division);
	my $divcs = "/var/www/html/Palm/civ/div".$division."/divcs.txt";

	open (DIVCS, $divcs);
	while (my $line = <DIVCS>) {
		chomp $line;
		my ($case,$style) = split(/\`/,$line);
		$case = "58".$case;
		$caseref->{$case} = $style;
	}
	close DIVCS;
}


sub getOLSEvents {
    # This will populate $dateref
    my $dbh = shift;
    my $dateref = shift;
    my $judgeid = shift;
    my $startDate = shift;
    my $endDate = shift;
    my $division = shift;
    
    $division = uc($division);
    
    my $judgeSel="";
    if ($judgeid ne 'all') {
        $judgeSel = "and r_judge = $judgeid";
    }
    
    my $query;
    if ($division eq "AW") {
        $query = qq {
            select
                b.r_lf_name as LawFirm,
                b.r_conf_num as ConfNum,
                b.r_attny_name as AttorneyName,
                b.r_attny_phone as AttorneyPhone,
                null as AttorneyEmail,
                null as ContactName,
                null as ContactPhone,
                b.r_created_by as ContactEmail,
                CASE s_type
                    WHEN 'S5' then b.r_motion_title
                    ELSE ' '
                END as MotionType,
                CASE s_type
                    WHEN 'S5' THEN TIME_FORMAT(DATE_ADD(CONCAT(b.r_date, ' ', b.r_time), INTERVAL (b.r_num_blocks * s.s_block_size) MINUTE), "%H:%i")
                    ELSE TIME_FORMAT(DATE_ADD(CONCAT(b.r_date, ' ', b.r_time), INTERVAL ba.av_mins_per_session MINUTE), "%H:%i")
                END as EndTime,
                CASE WHEN b.cancel_reason is null
                    THEN ''
                    else b.cancel_reason
                END as CancelReason,
                DATE_FORMAT(b.r_date,"%Y-%m-%d") as Date,
                DATE_FORMAT(b.r_date,"%m/%d/%Y") as SchedDate,
                DATE_FORMAT(b.r_date,"%Y-%m-%d") as ISODate,
                TIME_FORMAT(b.r_time, "%h:%i %p") as SchedTime,
                TIME_FORMAT(b.r_time, "%H:%i") as StartTime,
                b.r_judge as JudgeID,
                s.s_description as HearingType,
                s.s_description as CourtEventType,
                bcn.cn_casenumber as CaseNumber,
                UPPER(CONCAT(j.judge_lastname, ', JUDGE ', j.judge_firstname)) as JudgeName,
                CASE bcn.cn_active_cancelled
                    WHEN 0 THEN 'Y'
                    ELSE 'N'
                END as Canceled,
                bcn.cn_active_cancelled as Active,
                cs.case_style as CaseStyle,
                CASE s_type
                    WHEN ('S5') THEN (b.r_num_blocks * s.s_block_size)
                    WHEN ('R5') THEN 'N/A'
                    ELSE br.allotted_time
                END as TimeAllotted
            from
                brequest b left outer join bavailability ba on (b.r_judge = ba.av_judge) and (b.r_date = ba.av_date) and (b.r_time = ba.av_time) and (b.r_type = ba.av_type),
                sessiontype s,
                bcasenumber bcn left outer join bulk_hearings_allotted_times br on (bcn.cn_casenumber = br.case_num) and (bcn.cn_conf_num = br.conf_num)
                    left outer join olscheduling.case_styles cs on cs.casenum = SUBSTRING(bcn.cn_casenumber,3),
                judge j
            where
                b.r_date between '$startDate' and '$endDate'
                and b.r_type=s.s_type
                and bcn.cn_conf_num=b.r_conf_num
                and b.r_judge = j.judge_code
                $judgeSel
            order by
                JudgeID,
                r_date,
                r_time,
                LawFirm
        };
    } else {
        $query = qq {
            select
                s.sch_lf_name as LawFirm,
                s.sch_attny_name as AttorneyName,
                s.sch_attny_phone as AttorneyPhone,
                s.sch_attny_email as AttorneyEmail,
                s.sch_contact_name as ContactName,
                s.sch_contact_phone as ContactPhone,
                s.sch_contact_email as ContactEmail,
                s.sch_conf_num as ConfNum,
                a.av_id as SlotID,
                CASE
                    WHEN m.m_type='O' then m.m_othertitle
                    ELSE pm.m_title
                END as MotionType,
                CASE WHEN s.cancel_reason is null
                    THEN ''
                    else s.cancel_reason
                END as CancelReason,
                TIME_FORMAT(DATE_ADD(CONCAT(s.sch_date, ' ', s.sch_time), INTERVAL (s.sch_num_blocks * h.h_block_size) MINUTE), "%H:%i") as EndTime,
                (s.sch_num_blocks * h.h_block_size) as TimeAllotted,
                DATE_FORMAT(s.sch_date,"%Y-%m-%d") as Date,
                DATE_FORMAT(s.sch_date,"%m/%d/%Y") as SchedDate,
                DATE_FORMAT(s.sch_date,"%Y-%m-%d") as ISODate,
                TIME_FORMAT(s.sch_time, "%h:%i %p") as SchedTime,
                TIME_FORMAT(s.sch_time, "%H:%i") as StartTime,
                s.sch_judge as JudgeID,
                s.sch_judge as JudgeIdentifier,
                h.h_description as HearingType,
                h.h_description as CourtEventType,
                c.cn_casenumber as CaseNumber,
                UPPER(CONCAT(j.judge_lastname, ', JUDGE ', j.judge_firstname)) as JudgeName,
                CASE s.sch_active_cancelled
                    WHEN 0 THEN 'Y'
                    ELSE 'N'
                END as Canceled,
                s.sch_active_cancelled as Active,
                cs.case_style as CaseStyle
            from
                scheduling s left outer join motions m on (m.m_conf_num = s.sch_conf_num)
                    left outer join availability a on (s.sch_conf_num = a.av_conf_num)
                    left outer join predefmotions pm on (pm.m_type = m.m_type),
                hearingtype h,
                casenumber c left outer join olscheduling.case_styles cs on cs.casenum = SUBSTRING(c.cn_casenumber,3),
                judge j
            where
                s.sch_date between '$startDate' and '$endDate'
                and s.sch_type=h.h_type
                and c.cn_conf_num=s.sch_conf_num
                and s.sch_judge = j.judge_code
            order by
                JudgeID,
                s.sch_date,
                s.sch_time,
                LawFirm
        };
    }
    
    getData($dateref,$query,$dbh);
    
    # And add ICMS-type case numbers
    foreach my $event (@{$dateref}) {
        my $ucn = $event->{'CaseNumber'};
        $event->{'DivisionID'} = $division;
        $event->{'EventName'} = $event->{'CourtEventType'};
        $event->{'CaseNumber'} = sanitizeCaseNumber($event->{'CaseNumber'});
        $event->{'UCN'} = $ucn;
        if ($event->{'Canceled'} eq 'Y') {
            $event->{'RowClass'} = "canceled";
        } else {
            $event->{'RowClass'} = "";
        }
        if (!defined($event->{'CaseStyle'})) {
            my $stripucn = $ucn;
            $stripucn =~ s/-//g;
            # If a case is not open, it won't have a style in this data, so we need to get it from SC
            my $query = qq {
                select
                    CaseStyle
                from
                    $schema.vCase
                where
                    CaseNumber = ?
            };
            my $style = getDataOne($query, $scdbh, [$ucn]);
            if (defined($style)) {
                $event->{'CaseStyle'} = $style->{'CaseStyle'};
            }
        }
    }
}


sub getScEvents {
	# This will populate $dateref
	my $dbh = shift;
	my $dateref = shift;
	my $startDate = shift;
	my $endDate = shift;
	my $division = shift;
	my $schema = shift;
	
	if (!defined($schema)) {
		$schema = $DEFAULT_SCHEMA;
	}
    
    my $divList;
    # Allow multiple divs to be sent, separated by commas; split it up and build the divList string
    $division =~ s/\s+//g;
    my @divs = split(",", $division);
    my @temp;
    foreach my $div (@divs) {
        push(@temp, "'$div'");
    }
    $divList = join(",", @temp);

	my $startStr = sprintf("%s 00:00:00", $startDate);
	my $endStr = sprintf("%s 23:59:59", $endDate);

	my $query = qq {
		select
			ve.CaseNumber as CaseNumber,
			ve.DivisionCode,
			CONVERT(varchar(10),ve.CourtEventDate,101) as EventDate,
			CONVERT(varchar,CAST(CourtEventDate as time),100) as CourtEventTime,
			ve.CourtEventCode,
			ve.CourtEventType,
			ve.CourtLocation,
			ve.CourtRoom,
			CASE ve.Cancelled
				WHEN 'Yes' THEN 'Y'
				ELSE 'N'
			END as Canceled,
			CONVERT(varchar(10),ve.CreateDate,101) as DocketDate,
			ve.CourtEventNotes,
			vc.CaseStyle
		from
		    $schema.vCourtEvent ve with(nolock),
			$schema.vCase vc
		where
		    CourtEventDate between ? and ?
			and DivisionCode in ($divList)
			and ve.CaseNumber = vc.CaseNumber
		order by
		    CourtEventDate desc
    };

	getData($dateref, $query, $dbh, {valref => [$startStr, $endStr]});

	foreach my $event (@{$dateref}) {
		$event->{'CaseNumber'} =~ s/^58-//g;
		if ($event->{'CourtEventCode'} eq 'VOP') {
			$event->{'RowClass'} = 'vop';
		}

		if ((!defined($event->{'CourtEventNotes'})) || ($event->{'CourtEventNotes'} eq '')){
			$event->{'CourtEventNotes'} = '&nbsp;';
		}

		if ($event->{'Canceled'} eq 'Y') {
			if (defined($event->{'RowClass'})) {
				$event->{'RowClass'} .= ' canceled';
			} else {
				$event->{'RowClass'} = 'canceled';
			}
		}
	}
}



sub getFirstAppearance {
	# This will populate $eventRef
	my $dbh = shift;
	my $eventRef = shift;
	my $startDate = shift;
	my $endDate = shift;
	my $division = shift;
	my $schema = shift;
	
	if (!defined($schema)) {
		$schema = $DEFAULT_SCHEMA;
	}
    
    my $startStr = sprintf("%s 00:00:00", $startDate);
	my $endStr = sprintf("%s 23:59:59", $endDate);
    
    my $divList;
    # Allow multiple divs to be sent, separated by commas; split it up and build the divList string
    $division =~ s/\s+//g;
    my @divs = split("[,-]", $division);
    my @temp;
    foreach my $div (@divs) {
        push(@temp, "'$div'");
    }
    $divList = join(",", @temp);
    
    # What courthouse is this?
	my $jdbh = dbConnect("judge-divs");
	
	my $chQuery = qq {
		select
			courthouse_abbr as CourthouseAbbr
		from
			divisions d
				left outer join courthouses ch on (d.courthouse_id = ch.courthouse_id)
		where
			division_id = ?
	};
	my $chname = getDataOne($chQuery, $jdbh, [$divs[0]]);
	
	my $chabbr = $chname->{'CourthouseAbbr'};

	my $query = qq {
		select
			ve.CaseNumber as CaseNumber,
			ve.DivisionCode,
			CONVERT(varchar(10),ve.CourtEventDate,101) as StartDate,
			CONVERT(varchar,CAST(CourtEventDate as time),100) as StartTime,
			ve.CourtEventCode as EventCode,
			ve.CourtEventType as EventType,
			ve.CourtLocation,
			ve.CourtRoom,
			CASE ve.Cancelled
				WHEN 'Yes' THEN 'Y'
				ELSE 'N'
			END as isCanceled,
			CONVERT(varchar(10),ve.CreateDate,101) as DocketDate,
			ve.CourtEventNotes as EventNotes,
			vc.CaseStyle
		from
		    $schema.vCourtEvent ve with(nolock),
			$schema.vCase vc
		where
		    CourtEventDate between ? and ?
            and CourtLocation = ?
			and DivisionCode in ($divList,'FAP')
			and ve.CaseNumber = vc.CaseNumber
		order by
		    CourtEventDate desc
    };
    
	getData($eventRef, $query, $dbh, {valref => [$startStr, $endStr, $chabbr]});
    
	foreach my $event (@{$eventRef}) {
		$event->{'CaseNumber'} = sanitizeCaseNumber($event->{'CaseNumber'});
        $event->{'ICMSLink'} = sprintf('<a href="/cgi-bin/search.cgi?name=%s">%s</a>', $event->{'CaseNumber'}, $event->{'CaseNumber'});
        $event->{'NAMELink'} = sprintf('<a href="/cgi-bin/relatedSearch.cgi?ucn=%s">%s</a>', $event->{'CaseNumber'}, $event->{'CaseStyle'});
        
		if ($event->{'CourtEventCode'} eq 'VOP') {
			$event->{'RowClass'} = 'vop';
		}

		if ((!defined($event->{'CourtEventNotes'})) || ($event->{'CourtEventNotes'} eq '')){
			$event->{'CourtEventNotes'} = '&nbsp;';
		}

		if ($event->{'isCanceled'} eq 'Y') {
			if (defined($event->{'RowClass'})) {
				$event->{'RowClass'} .= ' canceled';
			} else {
				$event->{'RowClass'} = 'canceled';
			}
		}
        
        $query = qq {
            select
                CourtStatuteDescription
            from
                $schema.vCharge ch with(nolock)
            where
                ch.CaseNumber = ?
		};
        $event->{'Charges'} = [];
        my @chargeTemp;
        getData(\@chargeTemp, $query, $dbh, {valref => [$event->{'CaseNumber'}]});
        foreach my $charge (@chargeTemp) {
            push(@{$event->{'Charges'}}, $charge->{'CourtStatuteDescription'});
        }
	}
    
}

sub getOLSJudges {
	# This is the preferred way to build a list of Judges
	my $dbh = shift;
	my $judgeref = shift;
	my $div = shift;
	my $args;

	my $query = qq {
		select
			judge_code as JudgeID,
			judge_firstname as FirstName,
			judge_middlename as MiddleName,
			judge_lastname as LastName,
			judge_suffix as Suffix
		from
			judge 
	};
	
	$query .= qq {
		where title = 'Judge'
	};
	
	if($div eq 'PIP' || ($div eq 'SBPIP')){
		$query .= qq {	
			and
				division = '$div'
		};
	} 
	elsif($div ne 'AW' && ($div ne 'S4CL')){
		$query .= qq {	
			and
				division LIKE '%$div%'
		};
	}
	
	$query .= qq {
		order by
			LastName
	};

	getData($judgeref,$query,$dbh);

	# We have the listing of raw data; add a name display field
	foreach my $judge (@{$judgeref}) {
		# Because there's one in every crowd...
		if ($judge->{'FirstName'} eq "Courtroom") {
			$judge->{'FullName'} = "Senior Judge ($judge->{'FirstName'} $judge->{'LastName'})";
			next;
		}

		$judge->{'FullName'} = $judge->{LastName};
		if ((defined($judge->{'Suffix'})) && ($judge->{'Suffix'} ne '')) {
			$judge->{'FullName'} .= " " . $judge->{'Suffix'};
		}
		$judge->{'FullName'} .= ", " . $judge->{'FirstName'};
		if ((defined($judge->{'MiddleName'})) && ($judge->{'MiddleName'} ne '')) {
			$judge->{'FullName'} .= " " . $judge->{'MiddleName'};
		}
	}
}

sub getJudges {
	# Get the listing of the judges for the division from Showcase
	my $dbh = shift;
	my $judgeref = shift;
	my $div = shift;

	my $query = qq {
		select
			first_name as FirstName,
			middle_name as MiddleName,
			last_name as LastName
		from
			judges j,
			judge_divisions jd
		where
			jd.division_id = ?
			and j.judge_id = jd.judge_id
	};

	getData($judgeref, $query, $dbh, {valref => [$div]});

	foreach my $judge (@{$judgeref}) {
		$judge->{'FirstName'} =~ s/^JUDGE\s*//g;
		$judge->{'FullName'} = $judge->{LastName};

		$judge->{'FullName'} .= ", " . $judge->{'FirstName'};
		if ((defined($judge->{'MiddleName'})) && ($judge->{'MiddleName'} ne '')) {
			$judge->{'FullName'} .= " " . $judge->{'MiddleName'};
		}
	}
}

sub getMagistrates {
	# Get the listing of the magistrates for the division from Showcase
	my $dbh = shift;
	my $magref = shift;
	my $div = shift;

	my $query = qq {
		select
			first_name as FirstName,
			middle_name as MiddleName,
			last_name as LastName,
			suffix as Suffix
		from
			magistrates m
		where
			( 
				division = ?
				or 
					juv_cal_divisions LIKE '%$div%'
			)
	};

	getData($magref, $query, $dbh, {valref => [$div]});

	foreach my $mag (@{$magref}) {
		$mag->{'FirstName'} =~ s/^MAGISTRATE\s*//g;
		
		if ((defined($mag->{'Suffix'})) && ($mag->{'Suffix'} ne '')) {
			$mag->{'FullName'} = $mag->{'LastName'} . ", " . $mag->{'Suffix'};
		}
		else{
			$mag->{'FullName'} = $mag->{'LastName'}
		}

		$mag->{'FullName'} .= ", " . $mag->{'FirstName'};
		if ((defined($mag->{'MiddleName'})) && ($mag->{'MiddleName'} ne '')) {
			$mag->{'FullName'} .= " " . $mag->{'MiddleName'};
		}
	}
}

sub getMediators {
	# Get the listing of the mediators for the division from Showcase
	my $dbh = shift;
	my $medref = shift;
	my $mediator_id = shift;
	
	$mediator_id =~ s/-/,/g;
	my @tempRef;

	if($mediator_id ne "ALL" && ($mediator_id ne "all")){
		my $query = qq {
			SELECT 
				full_name,
				last_name,
				first_name,
				mediator_id
			FROM
				mediation_scheduling.mediators m
			WHERE
				mediator_id IN ( $mediator_id )
			ORDER BY
				last_name, first_name
			LIMIT 1
		};
		
		getData($medref, $query, $dbh);
		
		my @mFirst = split(/-/, $medref->[0]->{'first_name'});
		my $actFirst = $mFirst[1]; 
		$actFirst =~ s/^\s+|\s+$//g;
		$medref->[0]->{'FullName'} = $actFirst . " " . $medref->[0]->{'last_name'};
	}
	else{
		my $query = qq {
			SELECT
				full_name,
				first_name,
				last_name,
				mediator_id
			FROM
				mediation_scheduling.mediators m
			WHERE
				active = 1
			ORDER BY
				last_name, first_name
		};
		
		getData(\@tempRef, $query, $dbh);
	}

	my $count = 0;
	my @medNames;
	foreach my $med (@tempRef) {
		my @mFirst = split(/-/, $med->{'first_name'});
		my $actFirst = $mFirst[1]; 
		$actFirst =~ s/^\s+|\s+$//g;
		my $full_name = $actFirst . " " . $med->{'last_name'};
		
		if (!grep(/^$full_name$/, @medNames)){
			my %m;
			$m{'FullName'} = $full_name;
			$m{'JudgeID'} = $med->{'mediator_id'};
			
			push(@{$medref}, \%m);
			push(@medNames, $full_name);
		}
		else{
			foreach my $ms (@{$medref}) {
				if($ms->{'FullName'} eq $full_name){
					my $curVal = $ms->{'JudgeID'};
					$ms->{'JudgeID'} = $curVal . "-" . $med->{'mediator_id'};
				}
		   }
		}
		
		$count++;
	}
}

sub getOLSDivs {
	my $arrayRef = shift;
	my $dbh = shift;
	
	if (!defined($dbh)) {
		$dbh = dbConnect("judge-divs");
	}
	
	my $query = qq {
		select
			division_id
		from
			divisions
		where
			has_ols = 1
	};
	my @temp;
	getData(\@temp, $query, $dbh);
	
	foreach my $div (@temp) {
		push (@{$arrayRef}, $div->{'division_id'});
	}
}


sub getDivType {
	my $div = shift;
	my $dbh = shift;

	if (!defined($div)) {
		return undef;
	}

	if (!defined($dbh)) {
		$dbh = dbConnect("judge-divs");
	}

	my $query = qq {
		select
			division_type,
			IFNULL(has_ols,0) as has_ols
		from
			divisions
		where
			division_id = ?
	};
	my $divInfo = getDataOne($query,$dbh,[$div]);

	if (!defined($divInfo)) {
		return undef;
	}

	my $type = $divInfo->{'division_type'};
	my $ols = $divInfo->{'has_ols'};

	if ($type =~ /Felony|Misdemeanor|VA|Mental Health/) {
		return ("crim",$ols);
	} elsif ($type =~ /Family|Civil|Foreclosure/) {
		return ("civ", $ols);
	} elsif ($type =~ /Juvenile/) {
		return ("juv", $ols)
	} elsif ($type =~ /Probate/) {
		return ("pro", $ols);
	} else {
		return undef;
	}
}

sub getVRBEvents {
	my $eventRef = shift;
	my $externalType = shift;
	my $dbh = shift;

	if (!defined ($dbh)) {
		return;
	}

    my $query = qq {
        select
            e.event_id as VRBEvent,
            DATE(e.start_date) as Date,
            DATE_FORMAT(start_date,'%H:%i') as StartTime,
            DATE_FORMAT(e.end_date,'%H:%i') as EndTime,
            e.event_name as EventName,
            e.division as DivisionID,
            e.judge_name as JudgeName,
            e.event_type as CourtEventType,
            c.case_num as CaseNumber,
            c.case_style as CaseStyle,
            c.motion as MotionType,
            e.canceled as Canceled,
            e.cancel_reason as CancelReason,
            c.ols_conf_num as ConfNum
        from
            events e left outer join event_cases c on e.event_id = c.event_id
        where
            e.import_source_id = ?
            and DATE(e.start_date) >= CURDATE()
        order by
            start_date
    };
    getData($eventRef,$query,$dbh,{valref => [$externalType], hashkey => 'DivisionID'});
}


sub getVRBCalendar {
    my $eventRef = shift;
    my $judgeid = shift;
    my $startDate = shift;
    my $endDate = shift;
    my $division = shift;
    my $dbh = shift;
    my $isOls = shift;
    my $divType = shift;
    
	my $configXml = $ENV{'JVS_ROOT'} . "/conf/ICMS.xml";
	my $config = XMLin($configXml);
	
	# Get the actual name of the DB used for calendars - defaults to olscheduling
	my $olsdb = "olscheduling";
	if (defined($config->{'dbConfig'}->{'calendars'}->{'dbName'})) {
		$olsdb = $config->{'dbConfig'}->{'calendars'}->{'dbName'};
	}
	
    # Return without doing anything if $startDate or $division are undef
    if (!defined($startDate)) {
        return;
    }
    
    if (!defined($division)) {
        return;
    }
    
    # If $endDate is undef, set it to the start
    if (!defined($endDate)) {
        $endDate = $startDate;
    }
    
    # Default DB is vrb2
    if (!defined($dbh)) {
        $dbh = dbConnect("vrb2");
    }
    
    #OLS uses is_scheduled
    if (!defined($isOls)) {
        $isOls = 0;
    }
    
    my $query = qq {
        select
            e.event_id as VRBEventID,
            ec.event_cases_id AS VRBEventCasesID,
            CASE et.event_type_desc
                WHEN 'Other' then e.event_name
                ELSE et.event_type_desc
            END as EventType,
            et.event_type_code as EventCode,
            e.division as Division,
            e.judge_name as JudgeName,
            e.ols_judge_id as OLSJudgeID,
            DATE_FORMAT(DATE(e.start_date), '%m/%d/%Y') as StartDate,
            DATE_FORMAT(DATE(e.start_date), '%Y-%m-%d') as ISODate,
            DATE_FORMAT(DATE(e.end_date) , '%m/%d/%Y') as EndDate,
            TIME_FORMAT(TIME(e.start_date), '%H:%i') as StartTime,
            TIME_FORMAT(TIME(e.end_date), '%H:%i') as EndTime,
            ec.case_num as CaseNumber,
            ec.case_style as CaseStyle,
            IFNULL(ec.event_notes,'&nbsp;') as EventNotes,
            CASE ec.is_sensitive
                WHEN 1 THEN 'Y'
                ELSE 'N'
            END as isSensitive,
            CASE ec.is_sealed
                WHEN 1 THEN 'Y'
                ELSE 'N'
            END as isSealed,
            CASE 
                WHEN e.canceled = 1 THEN 'Y'
                WHEN ec.canceled = 1 THEN 'Y'
                ELSE 'N'
            END as isCanceled,
            i.import_source_name as ImportSourceName,
            IFNULL(ec.ols_conf_num,'N/A') as OLSConfNum,
            CASE 
            	WHEN ec.lawfirm_name IS NOT NULL AND ec.lawfirm_name <> ''
            		THEN ec.lawfirm_name
            	WHEN lf.lawfirm_name IS NOT NULL
            		THEN lf.lawfirm_name
            	ELSE
            		'&nbsp;'
            END AS LawFirm,
            CASE 
            	WHEN ec.attorney_name IS NOT NULL AND ec.attorney_name <> ''
            		THEN ec.attorney_name
            	WHEN u.bar_num IS NOT NULL
            		THEN CONCAT(IFNULL(u.first_name, ""), " ", IFNULL(u.middle_name, ""), " ", IFNULL(u.last_name, ""), " ", IFNULL(u.suffix, ""))
            	ELSE
            		'&nbsp;'
            END AS AttorneyName,
            CASE 
            	WHEN ec.attorney_phone IS NOT NULL AND ec.attorney_phone <> ''
            		THEN ec.attorney_phone
            	WHEN u.bar_num IS NOT NULL
            		THEN CONCAT(IFNULL(u.bus_area_code, ""), IFNULL(u.bus_phone, ""))
            	ELSE
            		'&nbsp;'
            END AS AttorneyPhone,
             CASE 
            	WHEN ec.attorney_email IS NOT NULL AND ec.attorney_email <> ''
            		THEN ec.attorney_email
            	WHEN u.bar_num IS NOT NULL AND ea.email_addr IS NOT NULL
            		THEN ea.email_addr
            	ELSE
            		'&nbsp;'
            END AS AttorneyEmail,
            CASE 
            	WHEN ec.contact_name IS NOT NULL AND ec.contact_name <> ''
            		THEN ec.contact_name
            	WHEN u.first_name IS NOT NULL
            		THEN CONCAT(IFNULL(u.first_name, ""), " ", IFNULL(u.middle_name, ""), " ", IFNULL(u.last_name, ""), " ", IFNULL(u.suffix, ""))
            	ELSE
            		'&nbsp;'
            END AS ContactName,
           CASE 
            	WHEN ec.contact_phone IS NOT NULL AND ec.contact_phone <> ''
            		THEN ec.contact_phone
            	WHEN u.bus_area_code IS NOT NULL
            		THEN CONCAT(IFNULL(u.bus_area_code, ""), IFNULL(u.bus_phone, ""))
            	ELSE
            		'&nbsp;'
            END AS ContactPhone,
            CASE 
            	WHEN ec.contact_email IS NOT NULL AND ec.contact_email <> ''
            		THEN ec.contact_email
            	WHEN ea.email_addr IS NOT NULL
            		THEN ea.email_addr
            	ELSE
            		'&nbsp;'
            END AS ContactEmail,
            CASE
            	WHEN a.allotted_time IS NOT NULL
                	THEN a.allotted_time
                WHEN (time_allotted is null or time_allotted = 0) 
                	THEN 'N/A'
                ELSE ec.time_allotted
            END as TimeAllotted,
            ec.motion,
            e.ex_parte_flag
        from
            events e left outer join event_cases ec on (e.event_id = ec.event_id)
                left outer join event_types et on (e.event_type_id = et.event_type_id)
                left outer join import_sources i on (e.import_source_id = i.import_source_id)
                left outer join olscheduling.bulk_hearings_allotted_times a on (ec.ols_conf_num = a.conf_num and ( ec.case_num = a.case_num or CONCAT('58', ec.case_num) = a.case_num ))
                left outer join olscheduling.law_firms lf on (ec.sched_lawfirm_id = lf.lawfirm_id)
                left outer join olscheduling.users u on (ec.sched_user_id = u.user_id)
                left outer join olscheduling.email_addresses ea on (u.login_id = ea.email_addr_id)
        where
            DATE(e.start_date) BETWEEN ? and ?
            and e.division = ?
            -- and e.is_private = 0
            and i.import_source_name <> 'Banner'
    };
    
    my @args = ($startDate, $endDate, $division);
    if ((defined($judgeid)) && ($judgeid ne 'all')) {
        $query .= qq {
            and (e.ols_judge_id = ? or e.ols_judge_id is null)
        };
        push(@args,$judgeid);
    }
    
    if($isOls eq "1"){
    	$query .= qq { AND ( is_scheduled = 1 OR ec.event_cases_id IS NOT NULL ) };
    }
    
    #@todo This needs to be updated whenever we go live with non-civil OLS 
    if($division =~ m/^R/g || ($division eq "WD") || ($division =~ m/^F/g) || ($division eq "WE") || ($division =~ m/^I/g)){
    	$query .= qq { 
    		UNION
	    		select
	            e.event_id as VRBEventID,
	            ec.event_cases_id AS VRBEventCasesID,
	            CASE et.event_type_desc
	                WHEN 'Other' then e.event_name
	                ELSE et.event_type_desc
	            END as EventType,
	            et.event_type_code as EventCode,
	            e.division as Division,
	            e.judge_name as JudgeName,
	            e.ols_judge_id as OLSJudgeID,
	            DATE_FORMAT(DATE(e.start_date), '%m/%d/%Y') as StartDate,
	            DATE_FORMAT(DATE(e.start_date), '%Y-%m-%d') as ISODate,
	            DATE_FORMAT(DATE(e.end_date) , '%m/%d/%Y') as EndDate,
	            TIME_FORMAT(TIME(e.start_date), '%H:%i') as StartTime,
	            TIME_FORMAT(TIME(e.end_date), '%H:%i') as EndTime,
	            ec.case_num as CaseNumber,
	            ec.case_style as CaseStyle,
	            IFNULL(ec.event_notes,'&nbsp;') as EventNotes,
	            CASE ec.is_sensitive
	                WHEN 1 THEN 'Y'
	                ELSE 'N'
	            END as isSensitive,
	            CASE ec.is_sealed
	                WHEN 1 THEN 'Y'
	                ELSE 'N'
	            END as isSealed,
	            CASE 
	                WHEN e.canceled = 1 THEN 'Y'
	                WHEN ec.canceled = 1 THEN 'Y'
	                ELSE 'N'
	            END as isCanceled,
	            i.import_source_name as ImportSourceName,
	            IFNULL(ec.ols_conf_num,'N/A') as OLSConfNum,
	            CASE 
	            	WHEN ec.lawfirm_name IS NOT NULL AND ec.lawfirm_name <> ''
	            		THEN ec.lawfirm_name
	            	WHEN lf.lawfirm_name IS NOT NULL
	            		THEN lf.lawfirm_name
	            	ELSE
	            		'&nbsp;'
	            END AS LawFirm,
	            CASE 
	            	WHEN ec.attorney_name IS NOT NULL AND ec.attorney_name <> ''
	            		THEN ec.attorney_name
	            	WHEN u.bar_num IS NOT NULL
	            		THEN CONCAT(IFNULL(u.first_name, ""), " ", IFNULL(u.middle_name, ""), " ", IFNULL(u.last_name, ""), " ", IFNULL(u.suffix, ""))
	            	ELSE
	            		'&nbsp;'
	            END AS AttorneyName,
	            CASE 
	            	WHEN ec.attorney_phone IS NOT NULL AND ec.attorney_phone <> ''
	            		THEN ec.attorney_phone
	            	WHEN u.bar_num IS NOT NULL
	            		THEN CONCAT(IFNULL(u.bus_area_code, ""), IFNULL(u.bus_phone, ""))
	            	ELSE
	            		'&nbsp;'
	            END AS AttorneyPhone,
	             CASE 
	            	WHEN ec.attorney_email IS NOT NULL AND ec.attorney_email <> ''
	            		THEN ec.attorney_email
	            	WHEN u.bar_num IS NOT NULL AND ea.email_addr IS NOT NULL
	            		THEN ea.email_addr
	            	ELSE
	            		'&nbsp;'
	            END AS AttorneyEmail,
		        CASE 
            		WHEN ec.contact_name IS NOT NULL AND ec.contact_name <> ''
            			THEN ec.contact_name
            		WHEN u.first_name IS NOT NULL
            			THEN CONCAT(IFNULL(u.first_name, ""), " ", IFNULL(u.middle_name, ""), " ", IFNULL(u.last_name, ""), " ", IFNULL(u.suffix, ""))
            		ELSE
            			'&nbsp;'
	            END AS ContactName,
	           CASE 
	            	WHEN ec.contact_phone IS NOT NULL AND ec.contact_phone <> ''
	            		THEN ec.contact_phone
	            	WHEN u.bus_area_code IS NOT NULL
	            		THEN CONCAT(IFNULL(u.bus_area_code, ""), IFNULL(u.bus_phone, ""))
	            	ELSE
	            		'&nbsp;'
	            END AS ContactPhone,
	            CASE 
	            	WHEN ec.contact_email IS NOT NULL AND ec.contact_email <> ''
	            		THEN ec.contact_email
	            	WHEN ea.email_addr IS NOT NULL
	            		THEN ea.email_addr
	            	ELSE
	            		'&nbsp;'
	            END AS ContactEmail,
	            CASE
	            	WHEN a.allotted_time IS NOT NULL
	                	THEN a.allotted_time
	                WHEN (time_allotted is null or time_allotted = 0) 
	                	THEN 'N/A'
	                ELSE ec.time_allotted
	            END as TimeAllotted,
	            ec.motion,
	            e.ex_parte_flag
	        from
	            events e left outer join event_cases ec on (e.event_id = ec.event_id)
	                left outer join event_types et on (e.event_type_id = et.event_type_id)
	                left outer join import_sources i on (e.import_source_id = i.import_source_id)
	                left outer join olscheduling.bulk_hearings_allotted_times a on (ec.ols_conf_num = a.conf_num and ( ec.case_num = a.case_num or CONCAT('50', ec.case_num) = a.case_num ))
	        		left outer join olscheduling.law_firms lf on (ec.sched_lawfirm_id = lf.lawfirm_id)
	                left outer join olscheduling.users u on (ec.sched_user_id = u.user_id)
	                left outer join olscheduling.email_addresses ea on (u.login_id = ea.email_addr_id)
	        where
	            DATE(e.start_date) BETWEEN ? and ?
	            and e.division = ?
	            -- and e.is_private = 0
	            and i.import_source_name <> 'Banner'
	            AND i.import_source_name <> 'OLS'
    	};
    	
    	push(@args, $startDate);
    	push(@args, $endDate);
    	push(@args, $division);
    }
    
    $query .= qq { ORDER BY StartDate };
    
    getData($eventRef,$query,$dbh,{valref => \@args});
    
    my @warTemp;
    my $caseString;
    foreach my $event (@{$eventRef}) {
    	$caseString .= "'" . $event->{'CaseNumber'} . "', ";
    }
    
    $caseString = substr $caseString, 0, -2;
    
    my $configXml = "$ENV{'JVS_ROOT'}/conf/ICMS.xml";
	my $config = XMLin($configXml);
	my $icms_db = $config->{'dbConfig'}->{'icms'}->{'dbName'};
	
	#my @cidTemp;
	#if($divType eq "crim"){
    #	# I don't like this but I don't have any other way to do it
    #	if($caseString ne ""){
    #		my $cidQuery = qq{
    #			SELECT
    #				CaseNumber,
	#                CountyID
	#            FROM
	#                $schema.vDefendant with(nolock)
	#            WHERE
	#                CaseNumber IN ($caseString)
    #		};
    #		
    #		getData(\@cidTemp, $cidQuery, $scdbh);
    #		
    #		my $warrQuery = qq{
	#		   	SELECT 
	#		   		CaseNumber,
	#		   		WarrantNumber
	#			FROM
	#				$schema.vWarrant with(nolock)
	#			where
	#				CaseNumber IN ($caseString)
	#				and Closed = 'N'
	#		};
	#		
	#		getData(\@warTemp, $warrQuery, $scdbh);
	#	
    #	}
   	#}
   	
   	#my @partyTemp;
   	# This is stupid too
    #if($caseString ne ""){
    #	my $partyQuery = qq{
    #		select
    #        DISTINCT p.PersonID,
    #        p.FirstName,
    #        p.MiddleName,
    #        p.LastName,
    #        p.PartyType,
    #        p.PartyTypeDescription,
    #        p.BarNumber,
    #        p.PersonID as PartyID,
    #        CASE
    #        	WHEN a.Represented_PersonID IS NOT NULL
	#			THEN AttorneyName
	#			ELSE 'Pro Se'
	#		END AS AttorneyName,
    #        p.CaseID,
    #        eMailAddress AS email_addr,
    #        p.CaseNumber
    #    from
    #        $schema.vAllParties p with(nolock)
    #    left outer join
    #    	$schema.vAttorney a with(nolock)
    #    	on p.CaseID = a.CaseID
	#		and p.PersonID = a.Represented_PersonID
    #    where
    #        p.CaseNumber IN ($caseString)
    #        and p.Active = 'Yes'
    #        and p.PartyType NOT IN ('JUDG', 'WIT', 'CHLD', 'DECD', 'ATTY', 'APD', 'PD', 'ASA')
    #        AND (p.Discharged IS NULL OR p.Discharged = 0)
    #        AND (p.CourtAction IS NULL OR p.CourtAction NOT LIKE '%Disposed%') 
   	#	};
    #	getData(\@partyTemp, $partyQuery, $scdbh);
    #}
    
    my @fdTemp;
    if($caseString ne ""){
    	my $fdQuery = qq{
    		SELECT
    			CaseNumber,
    			CONVERT(varchar,FileDate,101) as FileDate
	        FROM
	        	$schema.vCase with(nolock)
	        WHERE
	        	CaseNumber IN ($caseString)
    	};
    	
    	getData(\@fdTemp, $fdQuery, $scdbh);
    }
    
    foreach my $event (@{$eventRef}) {
    
    	if($divType eq "crim"){
    		#$event->{'CountyID'} = "";
	    	#if(scalar(@cidTemp)){
	    	#	foreach my $cid (@cidTemp){
	    	#		if($cid->{'CaseNumber'} eq $event->{'CaseNumber'} && ($cid->{'CountyID'} ne "")){
	    	#			$event->{'CountyID'} = $cid->{'CountyID'};
	    	#		}
	    	#	}
	    	#}
	    	
	    	#$event->{'InJail'} = 0;
	    	#if($event->{'CountyID'} ne ""){
	    	#	my $pbsoconn = dbConnect("pbso2");
	    	#	my $photoid;
	    	#	my $injail;
	    	#	($photoid, $injail) = getMugshotWithJacketId($event->{'CountyID'}, $pbsoconn);
	    		
	    	#	if($injail ne "No"){
	    	#		$event->{'InJail'} = 1;
	    	#	}
	    	#}
    	
    		$event->{'CPCA'} = sprintf('<a class="showRecord" data-casenum="%s">Image</a>&nbsp;&nbsp;&nbsp;<input type="checkbox" name="selectedCPCA" value="%s"/>', $event->{'CaseNumber'}, $event->{'CaseNumber'});
    	}
    	
    	#$event->{'OpenWarrants'} = 0;
    	#if(scalar(@warTemp)){
    	#	foreach my $war (@warTemp){
    	#		if($war->{'CaseNumber'} eq $event->{'CaseNumber'}){
    	#			$event->{'OpenWarrants'} = 1;
    	#		}
    	#	}
    	#} 

    	$event->{'FileDate'} = "";
    	if(scalar(@fdTemp)){
    		foreach my $fd (@fdTemp){
    			if($fd->{'CaseNumber'} eq $event->{'CaseNumber'}){
    				$event->{'FileDate'} = $fd->{'FileDate'};
    			}
    		}
    	} 
    	
    	my @partyTemp;
    	my $partyQuery = qq{
	   		select
	   			party_name,
	   			party_represents,
	   			party_phone
	   		from
	   			event_parties
	   		where
	   			event_id = ?
	   		and
	   			event_cases_id = ?
	   	};
	   	getData(\@partyTemp, $partyQuery, $dbh, {valref => [$event->{'VRBEventID'}, $event->{'VRBEventCasesID'}]});
	   	
    	$event->{'Attorneys'} = "<ul>";
    	if(scalar(@partyTemp)){
    		foreach my $p (@partyTemp){
    			$event->{'Attorneys'} .= "<li>";
    			$event->{'Attorneys'} .= $p->{'party_name'} . " (" . $p->{'party_represents'} . ")";
    			
    			if($p->{'party_phone'} ne ""){
    				$event->{'Attorneys'} .= "<br/>" . $p->{'party_phone'};
    			} 
    			
    			$event->{'Attorneys'} .= "</li>";
    		}
    	} 
    	$event->{'Attorneys'} .= "</ul>";
    	    
    	my $ec_motion = $event->{'motion'};
    	my $conf = $event->{'OLSConfNum'};
    	my $div = $event->{'Division'};
    	my $ex_parte_flag = $event->{'ex_parte_flag'};
    	
    	my @ems;
    	my $emQuery = qq{
    		SELECT m_type,
    			supp_doc_id,
    			m_othertitle
			FROM event_motions
			WHERE ols_conf_num = ?
		};
		
		getData(\@ems, $emQuery, $dbh, {valref => [$conf]});
		
		if(!scalar(@ems)){
			my $pdQuery = qq{
				SELECT m_title
				FROM olscheduling.predefmotions
				WHERE m_type = ?
				AND division = ?
			};
				
	    	my $pdRow = getDataOne($pdQuery, $dbh, [$ec_motion, $div]);
	    		
	    	if(defined($pdRow->{'m_title'})){
	    		$ec_motion = $pdRow->{'m_title'};
	    	}
	    	else{
	    		
	    		if(!$ex_parte_flag){
		    		my $umQuery = qq{
						SELECT motion_title
						FROM umc.umc_motion_types 
						WHERE motion_type = ?
						AND umc_div = ?
					};
						
			   		my $umRow = getDataOne($umQuery, $dbh, [$ec_motion, $div]);
			    		
			   		if(defined($umRow->{'motion_title'})){
			   			$ec_motion = $umRow->{'motion_title'};
			   		}
		   		}
		   		else{
		   			my $umQuery = qq{
						SELECT motion_title
						FROM umc.ex_parte_motion_types 
						WHERE motion_type = ?
						AND ex_parte_div = ?
					};
						
			   		my $umRow = getDataOne($umQuery, $dbh, [$ec_motion, $div]);
			    		
			   		if(defined($umRow->{'motion_title'})){
			   			$ec_motion = $umRow->{'motion_title'};
			   		}
		   		}
	    	}
		}
		else{
		
			foreach my $em (@ems) {
			
				my $pdQuery = qq{
					SELECT m_title
					FROM olscheduling.predefmotions
					WHERE m_type = ?
					AND division = ?
				};
				
	    		my $pdRow = getDataOne($pdQuery, $dbh, [$em->{'m_type'}, $div]);
	    		
	    		if(defined($pdRow->{'m_title'})){
	    			$em->{'Motion'} = $pdRow->{'m_title'};
	    		}
	    		else{
	    		
	    			if(!$ex_parte_flag){
		    			my $umQuery = qq{
							SELECT motion_title
							FROM umc.umc_motion_types 
							WHERE motion_type = ?
							AND umc_div = ?
						};
						
			    		my $umRow = getDataOne($umQuery, $dbh, [$em->{'m_type'}, $div]);
			    		
			    		if(defined($umRow->{'motion_title'})){
			    			$em->{'Motion'} = $umRow->{'motion_title'};
			    		}
		    		}
		    		else{
		    			my $umQuery = qq{
							SELECT motion_title
							FROM umc.ex_parte_motion_types 
							WHERE motion_type = ?
							AND ex_parte_div = ?
						};
						
			    		my $umRow = getDataOne($umQuery, $dbh, [$em->{'m_type'}, $div]);
			    		
			    		if(defined($umRow->{'motion_title'})){
			    			$em->{'Motion'} = $umRow->{'motion_title'};
			    		}
		    		}
	    		}
    		}
			
		}
		
		if(scalar(@ems)){
			foreach my $em (@ems) {
			
				if($em->{'Motion'} eq 'Other' && ($em->{'m_othertitle'} ne "")){
					$em->{'Motion'} = $em->{'m_othertitle'};
				}
			
				if($em->{'supp_doc_id'} != 0){
			    	my $fileQuery = qq{
			    		SELECT 
			    			document_title,
			    			file
			    		FROM 
			    			olscheduling.supporting_documents
			    		WHERE 
			    			supporting_doc_id = ?
			    	};
			    			
			    	my $supp_doc = getDataOne($fileQuery, $dbh, [$em->{'supp_doc_id'}]);
			    	if(defined($supp_doc)){
				    	$em->{'document_title'} = $supp_doc->{'document_title'};
				    	$em->{'file'} = $supp_doc->{'file'};
			    	}
		    	}
	    	}
		}
		
		my $ignoreThese;
		my $ignoreCount = 0;
		if(scalar(@ems)){
    		foreach my $em (@ems) {
    			if($em->{'supp_doc_id'} != 0){
    				if($ignoreCount > 0){
    					$ignoreThese .= ", ";
    				}
    				$ignoreThese .= $em->{'supp_doc_id'};
    				$ignoreCount++;
    			}
    		}
    	}
		
		my @fileRef;
    	my $fileQuery = qq{
    		SELECT 
    			document_title,
    			file
    		FROM 
    			olscheduling.supporting_documents
    		WHERE 
    			event_id = ?
    		AND 
    			event_cases_id = ? 
    	};
    	
    	if($ignoreThese){
    		$fileQuery .= " AND supporting_doc_id NOT IN ( " . $ignoreThese . " ) ";
    	}
    	
    	my @fileArgs = ($event->{'VRBEventID'}, $event->{'VRBEventCasesID'});
    	getData(\@fileRef, $fileQuery, $dbh, {valref => \@fileArgs});
    	
    	my @orderRef;
    	my $orderQuery = qq{
    		SELECT
    			doc_id,
    			title
    		FROM
    			$icms_db.workflow
    		WHERE
    			event_cases_id = ?
    	};
    	getData(\@orderRef, $orderQuery, $dbh, {valref => [$event->{'VRBEventCasesID'}]});
    	
    	$event->{'Motion'} = "<ul>";
    	
    	foreach my $order (@orderRef) {
        	$event->{'Motion'} .= sprintf('<li><a href="/orders/preview.php?fromWF=1&ucn=%s&docid=%s&isOrder=0">%s</a></li>', $event->{'CaseNumber'}, $order->{'doc_id'}, $order->{'title'});
        }
        
        if(scalar(@ems)){
    		foreach my $em (@ems) {
    			if(defined($em->{'file'})){
    				$event->{'Motion'} .= sprintf('<li><a href="%s" target="_blank">%s</a></li>', $config->{'olsURL'} . "/" . $em->{'file'}, $em->{'Motion'});
    			}
    			else{
    				$event->{'Motion'} .= sprintf('<li>%s</li>', $em->{'Motion'});
    			}
    		}
    	}
    	else{
    		if($ec_motion ne ""){
    			$event->{'Motion'} .= sprintf('<li>%s</li>', $ec_motion);
    		}
    		else{
    			#$event->{'Motion'} = "";
    		}
    	}
    
        $event->{'CaseNumber'} = sanitizeCaseNumber($event->{'CaseNumber'});
        
        foreach my $file (@fileRef) {
        	if($event->{'file'} ne $file->{'file'}){
        		$event->{'Motion'} .= sprintf('<li><a href="%s" target="_blank">%s</a></li>', $config->{'olsURL'} . "/" . $file->{'file'}, $file->{'document_title'});
        	}
        }
        
        $event->{'Motion'} .= "</ul>";
        
        my $warr = "";
        #if($event->{'OpenWarrants'}){
        # 	$warr = '<img src="/asterisk.png" alt="Open Warrants" /> ';
        #}
        #else{
       	#	$warr = "";
        #}
        
        my $inJail = "";
        #if($event->{'InJail'}){
        # 	$inJail = '<strong><span style="color:red">(In Jail)</span></strong>';
        #}
        #else{
        #	$inJail = "";
        #}
        
        $event->{'CaseStyle'} = sprintf('%s %s', $event->{'CaseStyle'}, $inJail);

        $event->{'ICMSLink'} = sprintf('%s<a href="/cgi-bin/search.cgi?name=%s">%s</a>', $warr, $event->{'CaseNumber'}, $event->{'CaseNumber'});
        $event->{'NAMELink'} = sprintf('<a href="/cgi-bin/relatedSearch.cgi?ucn=%s">%s</a>', $event->{'CaseNumber'}, $event->{'CaseStyle'});
        $event->{'AttorneyInfo'} = sprintf("%s<br/>%s<br/>%s<br>", $event->{'AttorneyName'}, $event->{'AttorneyPhone'}, $event->{'AttorneyEmail'});
        $event->{'ContactInfo'} = sprintf("%s<br/>%s<br/>%s<br>", $event->{'ContactName'}, $event->{'ContactPhone'}, $event->{'ContactEmail'});
    }
}

sub getMagistrateCalendar {
    my $eventRef = shift;
    my $startDate = shift;
    my $endDate = shift;
    my $division = shift;
    
    # Return without doing anything if $startDate or $division are undef
    if (!defined($startDate)) {
        return;
    }
    
    if (!defined($division)) {
        return;
    }
    
    # If $endDate is undef, set it to the start
    if (!defined($endDate)) {
        $endDate = $startDate;
    }

	my $configXml = $ENV{'JVS_ROOT'} . "/conf/ICMS.xml";
	my $config = XMLin($configXml);
	 
 	# Get the actual name of the DB used for calendars - defaults to olscheduling
	my $olsdb = "olscheduling";
	if (!defined($config->{'dbConfig'}->{'calendars'}->{'dbName'})) {
		$olsdb = $config->{'dbConfig'}->{'calendars'}->{'dbName'};
	}
    
    my $dbh = dbConnect("vrb2");

    my $query = qq {
        select
            e.event_id as VRBEventID,
            ec.event_cases_id AS VRBEventCasesID,
            CASE et.event_type_desc
                WHEN 'Other' then e.event_name
                ELSE et.event_type_desc
            END as EventType,
            et.event_type_code as EventCode,
            e.division as Division,
            e.judge_name as JudgeName,
            e.ols_judge_id as OLSJudgeID,
            DATE_FORMAT(DATE(e.start_date), '%m/%d/%Y') as StartDate,
            DATE_FORMAT(DATE(e.start_date), '%Y-%m-%d') as ISODate,
            DATE_FORMAT(DATE(e.end_date) , '%m/%d/%Y') as EndDate,
            TIME_FORMAT(TIME(e.start_date), '%H:%i') as StartTime,
            TIME_FORMAT(TIME(e.end_date), '%H:%i') as EndTime,
            ec.case_num as CaseNumber,
            ec.case_style as CaseStyle,
            IFNULL(ec.event_notes,'&nbsp;') as EventNotes,
            CASE ec.is_sensitive
                WHEN 1 THEN 'Y'
                ELSE 'N'
            END as isSensitive,
            CASE ec.is_sealed
                WHEN 1 THEN 'Y'
                ELSE 'N'
            END as isSealed,
            CASE 
                WHEN e.canceled = 1 THEN 'Y'
                WHEN ec.canceled = 1 THEN 'Y'
                ELSE 'N'
            END as isCanceled,
            i.import_source_name as ImportSourceName,
            IFNULL(ec.ols_conf_num,'N/A') as OLSConfNum,
            CASE 
            	WHEN ec.lawfirm_name IS NOT NULL AND ec.lawfirm_name <> ''
            		THEN ec.lawfirm_name
            	WHEN lf.lawfirm_name IS NOT NULL
            		THEN lf.lawfirm_name
            	ELSE
            		'&nbsp;'
            END AS LawFirm,
            CASE 
            	WHEN ec.attorney_name IS NOT NULL AND ec.attorney_name <> ''
            		THEN ec.attorney_name
            	WHEN u.bar_num IS NOT NULL
            		THEN CONCAT(IFNULL(u.first_name, ""), " ", IFNULL(u.middle_name, ""), " ", IFNULL(u.last_name, ""), " ", IFNULL(u.suffix, ""))
            	ELSE
            		'&nbsp;'
            END AS AttorneyName,
            CASE 
            	WHEN ec.attorney_phone IS NOT NULL AND ec.attorney_phone <> ''
            		THEN ec.attorney_phone
            	WHEN u.bar_num IS NOT NULL
            		THEN CONCAT(IFNULL(u.bus_area_code, ""), IFNULL(u.bus_phone, ""))
            	ELSE
            		'&nbsp;'
            END AS AttorneyPhone,
             CASE 
            	WHEN ec.attorney_email IS NOT NULL AND ec.attorney_email <> ''
            		THEN ec.attorney_email
            	WHEN ea.email_addr IS NOT NULL
            		THEN ea.email_addr
            	ELSE
            		'&nbsp;'
            END AS AttorneyEmail,
            CASE 
            	WHEN ec.contact_name IS NOT NULL AND ec.contact_name <> ''
            		THEN ec.contact_name
            	WHEN u.first_name IS NOT NULL
            		THEN CONCAT(IFNULL(u.first_name, ""), " ", IFNULL(u.middle_name, ""), " ", IFNULL(u.last_name, ""), " ", IFNULL(u.suffix, ""))
            	ELSE
            		'&nbsp;'
            END AS ContactName,
           CASE 
            	WHEN ec.contact_phone IS NOT NULL AND ec.contact_phone <> ''
            		THEN ec.contact_phone
            	WHEN u.bus_area_code IS NOT NULL
            		THEN CONCAT(IFNULL(u.bus_area_code, ""), IFNULL(u.bus_phone, ""))
            	ELSE
            		'&nbsp;'
            END AS ContactPhone,
            CASE 
            	WHEN ec.contact_email IS NOT NULL AND ec.contact_email <> ''
            		THEN ec.contact_email
            	WHEN ea.email_addr IS NOT NULL
            		THEN ea.email_addr
            	ELSE
            		'&nbsp;'
            END AS ContactEmail,
            CASE
            	WHEN a.allotted_time IS NOT NULL
                	THEN a.allotted_time
                WHEN (time_allotted is null or time_allotted = 0) 
                	THEN 'N/A'
                ELSE ec.time_allotted
            END as TimeAllotted,
            ec.motion,
            e.ex_parte_flag
        from
           events e left outer join event_cases ec on (e.event_id = ec.event_id)
	                left outer join event_types et on (e.event_type_id = et.event_type_id)
	                left outer join import_sources i on (e.import_source_id = i.import_source_id)
	                left outer join olscheduling.bulk_hearings_allotted_times a on (ec.ols_conf_num = a.conf_num and ( ec.case_num = a.case_num or CONCAT('58', ec.case_num) = a.case_num ))
        			left outer join olscheduling.law_firms lf on (ec.sched_lawfirm_id = lf.lawfirm_id)
	                left outer join olscheduling.users u on (ec.sched_user_id = u.user_id)
	                left outer join olscheduling.email_addresses ea on (u.login_id = ea.email_addr_id)
        where
        	e.division = ?
            AND DATE(e.start_date) BETWEEN ? and ?
            -- and e.is_private = 0
            and i.import_source_name <> 'Banner'
            AND ( e.is_scheduled = 1 OR ec.event_cases_id IS NOT NULL )
    };
    
    my @args = ($division, $startDate, $endDate);

    	$query .= qq { 
    		UNION
	    		select
	            e.event_id as VRBEventID,
	            ec.event_cases_id AS VRBEventCasesID,
	            CASE et.event_type_desc
	                WHEN 'Other' then e.event_name
	                ELSE et.event_type_desc
	            END as EventType,
	            et.event_type_code as EventCode,
	            e.division as Division,
	            e.judge_name as JudgeName,
	            e.ols_judge_id as OLSJudgeID,
	            DATE_FORMAT(DATE(e.start_date), '%m/%d/%Y') as StartDate,
	            DATE_FORMAT(DATE(e.start_date), '%Y-%m-%d') as ISODate,
	            DATE_FORMAT(DATE(e.end_date) , '%m/%d/%Y') as EndDate,
	            TIME_FORMAT(TIME(e.start_date), '%H:%i') as StartTime,
	            TIME_FORMAT(TIME(e.end_date), '%H:%i') as EndTime,
	            ec.case_num as CaseNumber,
	            ec.case_style as CaseStyle,
	            IFNULL(ec.event_notes,'&nbsp;') as EventNotes,
	            CASE ec.is_sensitive
	                WHEN 1 THEN 'Y'
	                ELSE 'N'
	            END as isSensitive,
	            CASE ec.is_sealed
	                WHEN 1 THEN 'Y'
	                ELSE 'N'
	            END as isSealed,
	            CASE 
	                WHEN e.canceled = 1 THEN 'Y'
	                WHEN ec.canceled = 1 THEN 'Y'
	                ELSE 'N'
	            END as isCanceled,
	            i.import_source_name as ImportSourceName,
	            IFNULL(ec.ols_conf_num,'N/A') as OLSConfNum,
	            CASE 
	            	WHEN ec.lawfirm_name IS NOT NULL AND ec.lawfirm_name <> ''
	            		THEN ec.lawfirm_name
	            	WHEN lf.lawfirm_name IS NOT NULL
	            		THEN lf.lawfirm_name
	            	ELSE
	            		'&nbsp;'
	            END AS LawFirm,
	            CASE 
	            	WHEN ec.attorney_name IS NOT NULL AND ec.attorney_name <> ''
	            		THEN ec.attorney_name
	            	WHEN u.bar_num IS NOT NULL
	            		THEN CONCAT(IFNULL(u.first_name, ""), " ", IFNULL(u.middle_name, ""), " ", IFNULL(u.last_name, ""), " ", IFNULL(u.suffix, ""))
	            	ELSE
	            		'&nbsp;'
	            END AS AttorneyName,
	            CASE 
	            	WHEN ec.attorney_phone IS NOT NULL AND ec.attorney_phone <> ''
	            		THEN ec.attorney_phone
	            	WHEN u.bar_num IS NOT NULL
	            		THEN CONCAT(IFNULL(u.bus_area_code, ""), IFNULL(u.bus_phone, ""))
	            	ELSE
	            		'&nbsp;'
	            END AS AttorneyPhone,
	             CASE 
	            	WHEN ec.attorney_email IS NOT NULL AND ec.attorney_email <> ''
	            		THEN ec.attorney_email
	            	WHEN ea.email_addr IS NOT NULL
	            		THEN ea.email_addr
	            	ELSE
	            		'&nbsp;'
	            END AS AttorneyEmail,
	            CASE 
	            	WHEN ec.contact_name IS NOT NULL AND ec.contact_name <> ''
	            		THEN ec.contact_name
	            	WHEN u.first_name IS NOT NULL
	            		THEN CONCAT(IFNULL(u.first_name, ""), " ", IFNULL(u.middle_name, ""), " ", IFNULL(u.last_name, ""), " ", IFNULL(u.suffix, ""))
	            	ELSE
	            		'&nbsp;'
	            END AS ContactName,
	           CASE 
	            	WHEN ec.contact_phone IS NOT NULL AND ec.contact_phone <> ''
	            		THEN ec.contact_phone
	            	WHEN u.bus_area_code IS NOT NULL
	            		THEN CONCAT(IFNULL(u.bus_area_code, ""), IFNULL(u.bus_phone, ""))
	            	ELSE
	            		'&nbsp;'
	            END AS ContactPhone,
	            CASE 
	            	WHEN ec.contact_email IS NOT NULL AND ec.contact_email <> ''
	            		THEN ec.contact_email
	            	WHEN ea.email_addr IS NOT NULL
	            		THEN ea.email_addr
	            	ELSE
	            		'&nbsp;'
	            END AS ContactEmail,
	            CASE
	            	WHEN a.allotted_time IS NOT NULL
	                	THEN a.allotted_time
	                WHEN (time_allotted is null or time_allotted = 0) 
	                	THEN 'N/A'
	                ELSE ec.time_allotted
	            END as TimeAllotted,
	            ec.motion,
	            e.ex_parte_flag
	        from
	            events e left outer join event_cases ec on (e.event_id = ec.event_id)
	                left outer join event_types et on (e.event_type_id = et.event_type_id)
	                left outer join import_sources i on (e.import_source_id = i.import_source_id)
	                left outer join olscheduling.bulk_hearings_allotted_times a on (ec.ols_conf_num = a.conf_num and ( ec.case_num = a.case_num or CONCAT('58', ec.case_num) = a.case_num ))
	        		left outer join olscheduling.law_firms lf on (ec.sched_lawfirm_id = lf.lawfirm_id)
	                left outer join olscheduling.users u on (ec.sched_user_id = u.user_id)
	                left outer join olscheduling.email_addresses ea on (u.login_id = ea.email_addr_id)
	                inner join judge_divs.magistrates m on (m.division = ? and e.division = m.juv_cal_divisions)
	        where
	            DATE(e.start_date) BETWEEN ? and ?
	            -- and e.is_private = 0
	            and i.import_source_name <> 'Banner'
	            AND i.import_source_name <> 'OLS'
	            
	    };
    	
    	push(@args, $division);
    	push(@args, $startDate);
    	push(@args, $endDate);
    
    $query .= qq { ORDER BY StartDate };
    
    getData($eventRef,$query,$dbh,{valref => \@args});
    
    my $configXml = "$ENV{'JVS_ROOT'}/conf/ICMS.xml";
	my $config = XMLin($configXml);
	my $icms_db = $config->{'dbConfig'}->{'icms'}->{'dbName'};
	
	my $caseString;
    foreach my $event (@{$eventRef}) {
    	$caseString .= "'" . $event->{'CaseNumber'} . "', ";
    }
	
	my @fdTemp;
    if($caseString ne ""){
    
    	$caseString = substr $caseString, 0, -2;
    
    	my $fdQuery = qq{
    		SELECT
    			CaseNumber,
    			CONVERT(varchar,FileDate,101) as FileDate,
    			DivisionID
	        FROM
	        	$schema.vCase with(nolock)
	        WHERE
	        	CaseNumber IN ($caseString)
    	};
    	
    	getData(\@fdTemp, $fdQuery, $scdbh);
    }
    
    foreach my $event (@{$eventRef}) {
    
    	$event->{'FileDate'} = "";
    	$event->{'DivisionID'} = "";
    	if(scalar(@fdTemp)){
    		foreach my $fd (@fdTemp){
    			if($fd->{'CaseNumber'} eq $event->{'CaseNumber'}){
    				$event->{'FileDate'} = $fd->{'FileDate'};
    				$event->{'DivisionID'} = $fd->{'DivisionID'};
    			}
    		}
    	} 
    
    	my @partyTemp;
    	my $partyQuery = qq{
	   		select
	   			party_name,
	   			party_represents,
	   			party_phone
	   		from
	   			event_parties
	   		where
	   			event_id = ?
	   		and
	   			event_cases_id = ?
	   	};
	   	getData(\@partyTemp, $partyQuery, $dbh, {valref => [$event->{'VRBEventID'}, $event->{'VRBEventCasesID'}]});
	   	
    	$event->{'Attorneys'} = "<ul>";
    	if(scalar(@partyTemp)){
    		foreach my $p (@partyTemp){
    			$event->{'Attorneys'} .= "<li>";
    			$event->{'Attorneys'} .= $p->{'party_name'} . " (" . $p->{'party_represents'} . ")";
    			
    			if($p->{'party_phone'} ne ""){
    				$event->{'Attorneys'} .= "<br/>" . $p->{'party_phone'};
    			} 
    			
    			$event->{'Attorneys'} .= "</li>";
    		}
    	} 
    	$event->{'Attorneys'} .= "</ul>";
    	
    	my $ec_motion = $event->{'motion'};
    	my $conf = $event->{'OLSConfNum'};
    	my $div = $event->{'Division'};
    	my $ex_parte_flag = $event->{'ex_parte_flag'};
    	
    	my @ems;
    	my $emQuery = qq{
    		SELECT m_type,
    			supp_doc_id,
    			m_othertitle
			FROM event_motions
			WHERE ols_conf_num = ?
		};
		
		getData(\@ems, $emQuery, $dbh, {valref => [$conf]});
		
		if(!scalar(@ems)){
			my $pdQuery = qq{
				SELECT m_title
				FROM olscheduling.predefmotions
				WHERE m_type = ?
				AND division = ?
			};
				
	    	my $pdRow = getDataOne($pdQuery, $dbh, [$ec_motion, $div]);
	    		
	    	if(defined($pdRow->{'m_title'})){
	    		$ec_motion = $pdRow->{'m_title'};
	    	}
	    	else{
	    		
	    		if(!$ex_parte_flag){
		    		my $umQuery = qq{
						SELECT motion_title
						FROM umc.umc_motion_types 
						WHERE motion_type = ?
						AND umc_div = ?
					};
						
			   		my $umRow = getDataOne($umQuery, $dbh, [$ec_motion, $div]);
			    		
			   		if(defined($umRow->{'motion_title'})){
			   			$ec_motion = $umRow->{'motion_title'};
			   		}
			   	}
			   	else{
			   		my $umQuery = qq{
						SELECT motion_title
						FROM umc.ex_parte_motion_types 
						WHERE motion_type = ?
						AND ex_parte_div = ?
					};
						
			   		my $umRow = getDataOne($umQuery, $dbh, [$ec_motion, $div]);
			    		
			   		if(defined($umRow->{'motion_title'})){
			   			$ec_motion = $umRow->{'motion_title'};
			   		}
			   	}
	    	}
		}
		else{
		
			foreach my $em (@ems) {
			
				my $pdQuery = qq{
					SELECT m_title
					FROM olscheduling.predefmotions
					WHERE m_type = ?
					AND division = ?
				};
				
	    		my $pdRow = getDataOne($pdQuery, $dbh, [$em->{'m_type'}, $div]);
	    		
	    		if(defined($pdRow->{'m_title'})){
	    			$em->{'Motion'} = $pdRow->{'m_title'};
	    		}
	    		else{
	    		
	    			if(!$ex_parte_flag){
		    			my $umQuery = qq{
							SELECT motion_title
							FROM umc.umc_motion_types 
							WHERE motion_type = ?
							AND umc_div = ?
						};
						
			    		my $umRow = getDataOne($umQuery, $dbh, [$em->{'m_type'}, $div]);
			    		
			    		if(defined($umRow->{'motion_title'})){
			    			$em->{'Motion'} = $umRow->{'motion_title'};
			    		}
		    		}
		    		else{
		    			my $umQuery = qq{
							SELECT motion_title
							FROM umc.ex_parte_motion_types 
							WHERE motion_type = ?
							AND ex_parte_div = ?
						};
						
			    		my $umRow = getDataOne($umQuery, $dbh, [$em->{'m_type'}, $div]);
			    		
			    		if(defined($umRow->{'motion_title'})){
			    			$em->{'Motion'} = $umRow->{'motion_title'};
			    		}
		    		}
	    		}
    		}
			
		}
		
		if(scalar(@ems)){
			foreach my $em (@ems) {
			
				if($em->{'Motion'} eq 'Other' && ($em->{'m_othertitle'} ne "")){
					$em->{'Motion'} = $em->{'m_othertitle'};
				}
			
				if($em->{'supp_doc_id'} != 0){
			    	my $fileQuery = qq{
			    		SELECT 
			    			document_title,
			    			file
			    		FROM 
			    			olscheduling.supporting_documents
			    		WHERE 
			    			supporting_doc_id = ?
			    	};
			    			
			    	my $supp_doc = getDataOne($fileQuery, $dbh, [$em->{'supp_doc_id'}]);
			    	if(defined($supp_doc)){
				    	$em->{'document_title'} = $supp_doc->{'document_title'};
				    	$em->{'file'} = $supp_doc->{'file'};
			    	}
		    	}
	    	}
		}
		
		my $ignoreThese;
		my $ignoreCount = 0;
		if(scalar(@ems)){
    		foreach my $em (@ems) {
    			if($em->{'supp_doc_id'} != 0){
    				if($ignoreCount > 0){
    					$ignoreThese .= ", ";
    				}
    				$ignoreThese .= $em->{'supp_doc_id'};
    				$ignoreCount++;
    			}
    		}
    	}
		
		my @fileRef;
    	my $fileQuery = qq{
    		SELECT 
    			document_title,
    			file
    		FROM 
    			olscheduling.supporting_documents
    		WHERE 
    			event_id = ?
    		AND 
    			event_cases_id = ? 
    	};
    	
    	if($ignoreThese){
    		$fileQuery .= " AND supporting_doc_id NOT IN ( " . $ignoreThese . " ) ";
    	}
    	
    	my @fileArgs = ($event->{'VRBEventID'}, $event->{'VRBEventCasesID'});
    	getData(\@fileRef, $fileQuery, $dbh, {valref => \@fileArgs});
    	
    	my @orderRef;
    	my $orderQuery = qq{
    		SELECT
    			doc_id,
    			title
    		FROM
    			$icms_db.workflow
    		WHERE
    			event_cases_id = ?
    	};
    	getData(\@orderRef, $orderQuery, $dbh, {valref => [$event->{'VRBEventCasesID'}]});
    	
    	$event->{'Motion'} = "<ul>";
    	
    	foreach my $order (@orderRef) {
        	$event->{'Motion'} .= sprintf('<li><a href="/orders/preview.php?fromWF=1&ucn=%s&docid=%s&isOrder=0">%s</a></li>', $event->{'CaseNumber'}, $order->{'doc_id'}, $order->{'title'});
        }
        
        if(scalar(@ems)){
    		foreach my $em (@ems) {
    			if(defined($em->{'file'})){
    				$event->{'Motion'} .= sprintf('<li><a href="%s" target="_blank">%s</a></li>', $config->{'olsURL'} . "/" . $em->{'file'}, $em->{'Motion'});
    			}
    			else{
    				$event->{'Motion'} .= sprintf('<li>%s</li>', $em->{'Motion'});
    			}
    		}
    	}
    	else{
    		if($ec_motion ne ""){
    			$event->{'Motion'} .= sprintf('<li>%s</li>', $ec_motion);
    		}
    		else{
    			$event->{'Motion'} = "";
    		}
    	}
    
        $event->{'CaseNumber'} = sanitizeCaseNumber($event->{'CaseNumber'});
        
        foreach my $file (@fileRef) {
        	if($event->{'file'} ne $file->{'file'}){
        		$event->{'Motion'} .= sprintf('<li><a href="%s" target="_blank">%s</a></li>', $config->{'olsURL'} . "/" . $file->{'file'}, $file->{'document_title'});
        	}
        }
        
        $event->{'Motion'} .= "</ul>";

        $event->{'ICMSLink'} = sprintf('<a href="/cgi-bin/search.cgi?name=%s">%s</a>', $event->{'CaseNumber'}, $event->{'CaseNumber'});
        $event->{'NAMELink'} = sprintf('<a href="/cgi-bin/relatedSearch.cgi?ucn=%s">%s</a>', $event->{'CaseNumber'}, $event->{'CaseStyle'});
        $event->{'AttorneyInfo'} = sprintf("%s<br/>%s<br/>%s<br>", $event->{'AttorneyName'}, $event->{'AttorneyPhone'}, $event->{'AttorneyEmail'});
        $event->{'ContactInfo'} = sprintf("%s<br/>%s<br/>%s<br>", $event->{'ContactName'}, $event->{'ContactPhone'}, $event->{'ContactEmail'});
    }
}

sub getMediatorCalendar {
    my $eventRef = shift;
    my $startDate = shift;
    my $endDate = shift;
    my $division = shift;
    
    $division =~ s/-/,/g;
    
    # Return without doing anything if $startDate or $division are undef
    if (!defined($startDate)) {
        return;
    }
    
    if (!defined($division)) {
        return;
    }
    
    # If $endDate is undef, set it to the start
    if (!defined($endDate)) {
        $endDate = $startDate;
    }
    
    my $dbh = dbConnect("vrb2");
    
    my $query = qq {
        select
            e.event_id as VRBEventID,
            ec.event_cases_id AS VRBEventCasesID,
            CASE et.event_type_desc
                WHEN 'Other' then e.event_name
                ELSE et.event_type_desc
            END as EventType,
            et.event_type_code as EventCode,
            e.division as Division,
            m.full_name as JudgeName,
            e.mediator_id as OLSJudgeID,
            DATE_FORMAT(DATE(e.start_date), '%m/%d/%Y') as StartDate,
            DATE_FORMAT(DATE(e.start_date), '%Y-%m-%d') as ISODate,
            DATE_FORMAT(DATE(e.end_date) , '%m/%d/%Y') as EndDate,
            TIME_FORMAT(TIME(e.start_date), '%H:%i') as StartTime,
            TIME_FORMAT(TIME(e.end_date), '%H:%i') as EndTime,
            ec.case_num as CaseNumber,
            ec.case_style as CaseStyle,
            IFNULL(ec.event_notes,'&nbsp;') as EventNotes,
            CASE ec.is_sensitive
                WHEN 1 THEN 'Y'
                ELSE 'N'
            END as isSensitive,
            CASE ec.is_sealed
                WHEN 1 THEN 'Y'
                ELSE 'N'
            END as isSealed,
            ec.event_notes as EventNotes,
            CASE 
                WHEN e.canceled = 1 THEN 'Y'
                WHEN ec.canceled = 1 THEN 'Y'
                ELSE 'N'
            END as isCanceled,
            i.import_source_name as ImportSourceName,
            IFNULL(ec.med_conf_num,'N/A') as OLSConfNum,
            IFNULL(ec.lawfirm_name,'&nbsp;') as LawFirm,
            IFNULL(ec.attorney_name,'&nbsp;') as AttorneyName,
            IFNULL(ec.contact_name,'&nbsp;') as ContactName,
            IFNULL(ec.contact_phone,'&nbsp;') as ContactPhone,
            IFNULL(ec.contact_email,'&nbsp;') as ContactEmail,
            l.room_number,
            CASE
            	WHEN m.court_types IN ('DP')
            		THEN 'N/A'
            	WHEN e.location = 'MB' AND WEEKDAY(e.start_date) IN (0, 2) AND e.med_observer_name IS NOT NULL 
            		THEN e.med_observer_name
            	WHEN e.location = 'MB' AND WEEKDAY(e.start_date) IN (0, 2) AND e.med_observer_name IS NULL 
            		THEN 'None'
            	WHEN e.location IN ('SB', 'NB') AND WEEKDAY(e.start_date) = 2 AND e.med_observer_name IS NOT NULL 
            		THEN e.med_observer_name
            	WHEN e.location IN ('SB', 'NB') AND WEEKDAY(e.start_date) = 2 AND e.med_observer_name IS NULL 
            		THEN 'None'
            	ELSE
            		'N/A'
            END as observer
        from
           events e left outer join event_cases ec on (e.event_id = ec.event_id)
	                left outer join event_types et on (e.event_type_id = et.event_type_id)
	                left outer join import_sources i on (e.import_source_id = i.import_source_id)
	                inner join mediation_scheduling.mediators m on (e.mediator_id = m.mediator_id)
	                inner join mediation_scheduling.locations l on (e.location = l.courthouse)
  		 where
            DATE(e.start_date) BETWEEN ? and ?
   };
   
   my @args;
   
   if($division ne 'all' && ($division ne 'ALL')){
   		$query .= qq { and e.mediator_id IN ( $division ) };
   		@args = ($startDate, $endDate);
   }
   else{
   		@args = ($startDate, $endDate);
   }
   
   $query .= qq {
            -- and e.is_private = 0
            and i.import_source_name <> 'Banner'
            AND ( e.is_scheduled = 1 OR ec.event_cases_id IS NOT NULL )
    };

    $query .= qq { ORDER BY StartDate };

    getData($eventRef,$query,$dbh,{valref => \@args});
    
    my @divTemp;
    my $caseString;
    foreach my $event (@{$eventRef}) {
    	$caseString .= "'" . $event->{'CaseNumber'} . "', ";
    }
    
    if($caseString ne ""){
	    $caseString = substr $caseString, 0, -2;
	    	
	    my $divQuery = qq{
		   	SELECT 
		   		CaseNumber,
		   		DivisionID
			FROM
				$schema.vCase with(nolock)
			WHERE
				CaseNumber IN ($caseString)
		};
		
		getData(\@divTemp, $divQuery, $scdbh);
	}
    
    my $configXml = "$ENV{'JVS_ROOT'}/conf/ICMS.xml";
	my $config = XMLin($configXml);
	my $icms_db = $config->{'dbConfig'}->{'icms'}->{'dbName'};
    
    foreach my $event (@{$eventRef}) {

    	if(scalar(@divTemp)){
    		foreach my $div (@divTemp){
    			if($div->{'CaseNumber'} eq $event->{'CaseNumber'}){
    				$event->{'DivisionID'} = $div->{'DivisionID'};
    			}
    		}
    	} 

        $event->{'ICMSLink'} = sprintf('<a href="/cgi-bin/search.cgi?name=%s">%s</a>', $event->{'CaseNumber'}, $event->{'CaseNumber'});
        $event->{'NAMELink'} = sprintf('<a href="/cgi-bin/relatedSearch.cgi?ucn=%s">%s</a>', $event->{'CaseNumber'}, $event->{'CaseStyle'});
        $event->{'AttorneyInfo'} = sprintf("%s<br/>%s<br/>", $event->{'AttorneyName'}, $event->{'LawFirm'});
        $event->{'ContactInfo'} = sprintf("%s<br/>%s<br/>%s<br>", $event->{'ContactName'}, $event->{'ContactPhone'}, $event->{'ContactEmail'});
    }
}

sub getExParteCalendar {
    my $eventRef = shift;
    my $startDate = shift;
    my $endDate = shift;
    my $division = shift;
    
    # Return without doing anything if $startDate or $division are undef
    if (!defined($startDate)) {
        return;
    }
    
    if (!defined($division)) {
        return;
    }
    
    # If $endDate is undef, set it to the start
    if (!defined($endDate)) {
        $endDate = $startDate;
    }
    
    my $dbh = dbConnect("vrb2");
    
    my $query = qq {
        select
            e.event_id as VRBEventID,
            ec.event_cases_id AS VRBEventCasesID,
            CASE et.event_type_desc
                WHEN 'Other' then e.event_name
                ELSE et.event_type_desc
            END as EventType,
            et.event_type_code as EventCode,
            e.division as Division,
            e.division as DivisionID,
            e.judge_name as JudgeName,
            e.ols_judge_id as OLSJudgeID,
            DATE_FORMAT(DATE(e.start_date), '%m/%d/%Y') as StartDate,
            DATE_FORMAT(DATE(e.start_date), '%Y-%m-%d') as ISODate,
            DATE_FORMAT(DATE(e.end_date) , '%m/%d/%Y') as EndDate,
            TIME_FORMAT(TIME(e.start_date), '%H:%i') as StartTime,
            TIME_FORMAT(TIME(e.end_date), '%H:%i') as EndTime,
            ec.case_num as CaseNumber,
            ec.case_style as CaseStyle,
            IFNULL(ec.event_notes,'&nbsp;') as EventNotes,
            CASE ec.is_sensitive
                WHEN 1 THEN 'Y'
                ELSE 'N'
            END as isSensitive,
            CASE ec.is_sealed
                WHEN 1 THEN 'Y'
                ELSE 'N'
            END as isSealed,
            ec.event_notes as EventNotes,
            CASE 
                WHEN e.canceled = 1 THEN 'Y'
                WHEN ec.canceled = 1 THEN 'Y'
                ELSE 'N'
            END as isCanceled,
            i.import_source_name as ImportSourceName,
            IFNULL(ec.ols_conf_num,'N/A') as OLSConfNum,
            CASE 
	            	WHEN ec.lawfirm_name IS NOT NULL AND ec.lawfirm_name <> ''
	            		THEN ec.lawfirm_name
	            	WHEN lf.lawfirm_name IS NOT NULL
	            		THEN lf.lawfirm_name
	            	ELSE
	            		'&nbsp;'
	            END AS LawFirm,
	            CASE 
	            	WHEN ec.attorney_name IS NOT NULL AND ec.attorney_name <> ''
	            		THEN ec.attorney_name
	            	WHEN u.bar_num IS NOT NULL
	            		THEN CONCAT(IFNULL(u.first_name, ""), " ", IFNULL(u.middle_name, ""), " ", IFNULL(u.last_name, ""), " ", IFNULL(u.suffix, ""))
	            	ELSE
	            		'&nbsp;'
	            END AS AttorneyName,
	            CASE 
	            	WHEN ec.attorney_phone IS NOT NULL AND ec.attorney_phone <> ''
	            		THEN ec.attorney_phone
	            	WHEN u.bar_num IS NOT NULL
	            		THEN CONCAT(IFNULL(u.bus_area_code, ""), IFNULL(u.bus_phone, ""))
	            	ELSE
	            		'&nbsp;'
	            END AS AttorneyPhone,
	             CASE 
	            	WHEN ec.attorney_email IS NOT NULL AND ec.attorney_email <> ''
	            		THEN ec.attorney_email
	            	WHEN u.bar_num IS NOT NULL AND ea.email_addr IS NOT NULL
	            		THEN ea.email_addr
	            	ELSE
	            		'&nbsp;'
	            END AS AttorneyEmail,
	            CASE 
	            	WHEN ec.contact_name IS NOT NULL AND ec.contact_name <> ''
	            		THEN ec.contact_name
	            	WHEN u.first_name IS NOT NULL
	            		THEN CONCAT(IFNULL(u.first_name, ""), " ", IFNULL(u.middle_name, ""), " ", IFNULL(u.last_name, ""), " ", IFNULL(u.suffix, ""))
	            	ELSE
	            		'&nbsp;'
	            END AS ContactName,
	           CASE 
	            	WHEN ec.contact_phone IS NOT NULL AND ec.contact_phone <> ''
	            		THEN ec.contact_phone
	            	WHEN u.bus_area_code IS NOT NULL
	            		THEN CONCAT(IFNULL(u.bus_area_code, ""), IFNULL(u.bus_phone, ""))
	            	ELSE
	            		'&nbsp;'
	            END AS ContactPhone,
	            CASE 
	            	WHEN ec.contact_email IS NOT NULL AND ec.contact_email <> ''
	            		THEN ec.contact_email
	            	WHEN ea.email_addr IS NOT NULL
	            		THEN ea.email_addr
	            	ELSE
	            		'&nbsp;'
	            END AS ContactEmail,
	            CASE
	            	WHEN a.allotted_time IS NOT NULL
	                	THEN a.allotted_time
	                WHEN (time_allotted is null or time_allotted = 0) 
	                	THEN 'N/A'
	                ELSE ec.time_allotted
	            END as TimeAllotted,
	            ec.motion,
	            e.ex_parte_flag
        from
           events e left outer join event_cases ec on (e.event_id = ec.event_id)
	                left outer join event_types et on (e.event_type_id = et.event_type_id)
	                left outer join import_sources i on (e.import_source_id = i.import_source_id)
	                left outer join olscheduling.bulk_hearings_allotted_times a on (ec.ols_conf_num = a.conf_num and ( ec.case_num = a.case_num or CONCAT('58', ec.case_num) = a.case_num ))
	                left outer join olscheduling.law_firms lf on (ec.sched_lawfirm_id = lf.lawfirm_id)
	                left outer join olscheduling.users u on (ec.sched_user_id = u.user_id)
	                left outer join olscheduling.email_addresses ea on (u.login_id = ea.email_addr_id)
  		 where
            DATE(e.start_date) BETWEEN ? and ?
   };
   
   my @args;
   
   if($division ne 'all' && ($division ne 'ALL')){
   		$query .= qq { and e.division = ? };
   		@args = ($startDate, $endDate, $division);
   }
   else{
   		@args = ($startDate, $endDate);
   }
   
   $query .= qq {
            -- and e.is_private = 0
            and i.import_source_name <> 'Banner'
            AND ( e.is_scheduled = 1 OR ec.event_cases_id IS NOT NULL )
            AND e.ex_parte_flag = 1
    };

    $query .= qq { ORDER BY StartDate };

    getData($eventRef,$query,$dbh,{valref => \@args});
    
    my $configXml = "$ENV{'JVS_ROOT'}/conf/ICMS.xml";
	my $config = XMLin($configXml);
	my $icms_db = $config->{'dbConfig'}->{'icms'}->{'dbName'};
	
	foreach my $event (@{$eventRef}) {
    	
    	my $ec_motion = $event->{'motion'};
    	my $conf = $event->{'OLSConfNum'};
    	my $div = $event->{'Division'};
    	my $ex_parte_flag = $event->{'ex_parte_flag'};
    	
    	my @ems;
    	my $emQuery = qq{
    		SELECT m_type,
    			supp_doc_id,
    			m_othertitle,
    			docket_number
			FROM event_motions
			WHERE ols_conf_num = ?
		};
		
		getData(\@ems, $emQuery, $dbh, {valref => [$conf]});
		
		if(!scalar(@ems)){
			my $pdQuery = qq{
				SELECT m_title
				FROM olscheduling.predefmotions
				WHERE m_type = ?
				AND division = ?
			};
				
	    	my $pdRow = getDataOne($pdQuery, $dbh, [$ec_motion, $div]);
	    		
	    	if(defined($pdRow->{'m_title'})){
	    		$ec_motion = $pdRow->{'m_title'};
	    	}
	    	else{
	    		
	    		if(!$ex_parte_flag){
		    		my $umQuery = qq{
						SELECT motion_title
						FROM umc.umc_motion_types 
						WHERE motion_type = ?
						AND umc_div = ?
					};
						
			   		my $umRow = getDataOne($umQuery, $dbh, [$ec_motion, $div]);
			    		
			   		if(defined($umRow->{'motion_title'})){
			   			$ec_motion = $umRow->{'motion_title'};
			   		}
			   	}
			   	else{
			   		my $umQuery = qq{
						SELECT motion_title
						FROM umc.ex_parte_motion_types 
						WHERE motion_type = ?
						AND ex_parte_div = ?
					};
						
			   		my $umRow = getDataOne($umQuery, $dbh, [$ec_motion, $div]);
			    		
			   		if(defined($umRow->{'motion_title'})){
			   			$ec_motion = $umRow->{'motion_title'};
			   		}
			   	}
	    	}
		}
		else{
		
			foreach my $em (@ems) {
			
				my $pdQuery = qq{
					SELECT m_title
					FROM olscheduling.predefmotions
					WHERE m_type = ?
					AND division = ?
				};
				
	    		my $pdRow = getDataOne($pdQuery, $dbh, [$em->{'m_type'}, $div]);
	    		
	    		if(defined($pdRow->{'m_title'})){
	    			$em->{'Motion'} = $pdRow->{'m_title'};
	    		}
	    		else{
	    		
	    			if(!$ex_parte_flag){
		    			my $umQuery = qq{
							SELECT motion_title
							FROM umc.umc_motion_types 
							WHERE motion_type = ?
							AND umc_div = ?
						};
						
			    		my $umRow = getDataOne($umQuery, $dbh, [$em->{'m_type'}, $div]);
			    		
			    		if(defined($umRow->{'motion_title'})){
			    			$em->{'Motion'} = $umRow->{'motion_title'};
			    		}
		    		}
		    		else{
		    			my $umQuery = qq{
							SELECT motion_title
							FROM umc.ex_parte_motion_types 
							WHERE motion_type = ?
							AND ex_parte_div = ?
						};
						
			    		my $umRow = getDataOne($umQuery, $dbh, [$em->{'m_type'}, $div]);
			    		
			    		if(defined($umRow->{'motion_title'})){
			    			$em->{'Motion'} = $umRow->{'motion_title'};
			    		}
		    		}
	    		}
    		}
			
		}
		
		if(scalar(@ems)){
			foreach my $em (@ems) {
			
				if($em->{'Motion'} eq 'Other' && ($em->{'m_othertitle'} ne "")){
					$em->{'Motion'} = $em->{'m_othertitle'};
				}
			
				if($em->{'supp_doc_id'} != 0){
			    	my $fileQuery = qq{
			    		SELECT 
			    			document_title,
			    			file
			    		FROM 
			    			olscheduling.supporting_documents
			    		WHERE 
			    			supporting_doc_id = ?
			    	};
			    			
			    	my $supp_doc = getDataOne($fileQuery, $dbh, [$em->{'supp_doc_id'}]);
			    	if(defined($supp_doc)){
				    	$em->{'document_title'} = $supp_doc->{'document_title'};
				    	$em->{'file'} = $supp_doc->{'file'};
			    	}
		    	}
	    	}
		}
		
		my $ignoreThese;
		my $ignoreCount = 0;
		if(scalar(@ems)){
    		foreach my $em (@ems) {
    			if($em->{'supp_doc_id'} != 0){
    				if($ignoreCount > 0){
    					$ignoreThese .= ", ";
    				}
    				$ignoreThese .= $em->{'supp_doc_id'};
    				$ignoreCount++;
    			}
    			
    			if(defined($em->{'docket_number'}) && ($em->{'docket_number'} ne "")){
    				$em->{'Motion'} .= "<br/>(Docket Number: " . $em->{'docket_number'} . ")";
    			}
    		}
    	}
		
		my @fileRef;
    	my $fileQuery = qq{
    		SELECT 
    			document_title,
    			file
    		FROM 
    			olscheduling.supporting_documents
    		WHERE 
    			event_id = ?
    		AND 
    			event_cases_id = ? 
    	};
    	
    	if($ignoreThese){
    		$fileQuery .= " AND supporting_doc_id NOT IN ( " . $ignoreThese . " ) ";
    	}
    	
    	my @fileArgs = ($event->{'VRBEventID'}, $event->{'VRBEventCasesID'});
    	getData(\@fileRef, $fileQuery, $dbh, {valref => \@fileArgs});
    	
    	my @orderRef;
    	my $orderQuery = qq{
    		SELECT
    			doc_id,
    			title
    		FROM
    			$icms_db.workflow
    		WHERE
    			event_cases_id = ?
    	};
    	getData(\@orderRef, $orderQuery, $dbh, {valref => [$event->{'VRBEventCasesID'}]});
    	
    	$event->{'Motion'} = "<ul>";
    	
    	foreach my $order (@orderRef) {
        	$event->{'Motion'} .= sprintf('<li><a href="/orders/preview.php?fromWF=1&ucn=%s&docid=%s&isOrder=0">%s</a></li>', $event->{'CaseNumber'}, $order->{'doc_id'}, $order->{'title'});
        }
        
        if(scalar(@ems)){
    		foreach my $em (@ems) {
    			if(defined($em->{'file'})){
    				$event->{'Motion'} .= sprintf('<li><a href="%s" target="_blank">%s</a></li>', $config->{'olsURL'} . "/" . $em->{'file'}, $em->{'Motion'});
    			}
    			else{
    				$event->{'Motion'} .= sprintf('<li>%s</li>', $em->{'Motion'});
    			}
    		}
    	}
    	else{
    		if($ec_motion ne ""){
    			$event->{'Motion'} .= sprintf('<li>%s</li>', $ec_motion);
    		}
    		else{
    			$event->{'Motion'} = "";
    		}
    	}
    
        $event->{'CaseNumber'} = sanitizeCaseNumber($event->{'CaseNumber'});
        
        foreach my $file (@fileRef) {
        	if($event->{'file'} ne $file->{'file'}){
        		$event->{'Motion'} .= sprintf('<li><a href="%s" target="_blank">%s</a></li>', $config->{'olsURL'} . "/" . $file->{'file'}, $file->{'document_title'});
        	}
        }
        
        $event->{'Motion'} .= "</ul>";

        $event->{'ICMSLink'} = sprintf('<a href="/cgi-bin/search.cgi?name=%s">%s</a>', $event->{'CaseNumber'}, $event->{'CaseNumber'});
        $event->{'NAMELink'} = sprintf('<a href="/cgi-bin/relatedSearch.cgi?ucn=%s">%s</a>', $event->{'CaseNumber'}, $event->{'CaseStyle'});
        $event->{'AttorneyInfo'} = sprintf("%s<br/>%s<br/>%s<br>", $event->{'AttorneyName'}, $event->{'AttorneyPhone'}, $event->{'AttorneyEmail'});
        $event->{'ContactInfo'} = sprintf("%s<br/>%s<br/>%s<br>", $event->{'ContactName'}, $event->{'ContactPhone'}, $event->{'ContactEmail'});
    }
}

sub getMentalHealthCalendar {
    my $eventRef = shift;
    my $startDate = shift;
    my $endDate = shift;
    my $division = shift;
    
    # Return without doing anything if $startDate or $division are undef
    if (!defined($startDate)) {
        return;
    }
    
    if (!defined($division)) {
        return;
    }
    
    # If $endDate is undef, set it to the start
    if (!defined($endDate)) {
        $endDate = $startDate;
    }
    
    my $dbh = dbConnect("vrb2");
    
    my $query = qq {
		select
	        e.event_id as VRBEventID,
	        ec.event_cases_id AS VRBEventCasesID,
	        CASE et.event_type_desc
	            WHEN 'Other' then e.event_name
	            ELSE et.event_type_desc
	        END as EventType,
	        et.event_type_code as EventCode,
	        e.division as Division,
	        e.judge_name as JudgeName,
	        e.ols_judge_id as OLSJudgeID,
	        DATE_FORMAT(DATE(e.start_date), '%m/%d/%Y') as StartDate,
	        DATE_FORMAT(DATE(e.start_date), '%Y-%m-%d') as ISODate,
	        DATE_FORMAT(DATE(e.end_date) , '%m/%d/%Y') as EndDate,
	        TIME_FORMAT(TIME(e.start_date), '%H:%i') as StartTime,
	        TIME_FORMAT(TIME(e.end_date), '%H:%i') as EndTime,
	        ec.case_num as CaseNumber,
	        ec.case_style as CaseStyle,
	        IFNULL(ec.event_notes,'&nbsp;') as EventNotes,
	        CASE ec.is_sensitive
	            WHEN 1 THEN 'Y'
	            ELSE 'N'
	        END as isSensitive,
	        CASE ec.is_sealed
	            WHEN 1 THEN 'Y'
	            ELSE 'N'
	        END as isSealed,
	        CASE 
	            WHEN e.canceled = 1 THEN 'Y'
	            WHEN ec.canceled = 1 THEN 'Y'
	            ELSE 'N'
	        END as isCanceled,
	        i.import_source_name as ImportSourceName,
	        IFNULL(ec.ols_conf_num,'N/A') as OLSConfNum,
	        CASE 
	         	WHEN ec.lawfirm_name IS NOT NULL AND ec.lawfirm_name <> ''
	           		THEN ec.lawfirm_name
	           	WHEN lf.lawfirm_name IS NOT NULL
	           		THEN lf.lawfirm_name
	           	ELSE
	           		'&nbsp;'
	        END AS LawFirm,
	        CASE 
	           	WHEN ec.attorney_name IS NOT NULL AND ec.attorney_name <> ''
	           		THEN ec.attorney_name
	           	WHEN u.bar_num IS NOT NULL
	           		THEN CONCAT(IFNULL(u.first_name, ""), " ", IFNULL(u.middle_name, ""), " ", IFNULL(u.last_name, ""), " ", IFNULL(u.suffix, ""))
	           	ELSE
	          		'&nbsp;'
	        END AS AttorneyName,
	        CASE 
	           	WHEN ec.attorney_phone IS NOT NULL AND ec.attorney_phone <> ''
	           		THEN ec.attorney_phone
	           	WHEN u.bar_num IS NOT NULL
	           		THEN CONCAT(IFNULL(u.bus_area_code, ""), IFNULL(u.bus_phone, ""))
	           	ELSE
	           		'&nbsp;'
	        END AS AttorneyPhone,
	        CASE 
	           	WHEN ec.attorney_email IS NOT NULL AND ec.attorney_email <> ''
	           		THEN ec.attorney_email
	           	WHEN u.bar_num IS NOT NULL AND ea.email_addr IS NOT NULL
	           		THEN ea.email_addr
	           	ELSE
	           		'&nbsp;'
	        END AS AttorneyEmail,
		    CASE 
            	WHEN ec.contact_name IS NOT NULL AND ec.contact_name <> ''
            		THEN ec.contact_name
            	WHEN u.first_name IS NOT NULL
            		THEN CONCAT(IFNULL(u.first_name, ""), " ", IFNULL(u.middle_name, ""), " ", IFNULL(u.last_name, ""), " ", IFNULL(u.suffix, ""))
            	ELSE
            		'&nbsp;'
	        END AS ContactName,
	        CASE 
	           	WHEN ec.contact_phone IS NOT NULL AND ec.contact_phone <> ''
	           		THEN ec.contact_phone
	           	WHEN u.bus_area_code IS NOT NULL
	           		THEN CONCAT(IFNULL(u.bus_area_code, ""), IFNULL(u.bus_phone, ""))
	           	ELSE
	           		'&nbsp;'
	        END AS ContactPhone,
	        CASE 
	           	WHEN ec.contact_email IS NOT NULL AND ec.contact_email <> ''
	           		THEN ec.contact_email
	           	WHEN ea.email_addr IS NOT NULL
	           		THEN ea.email_addr
	           	ELSE
	        		'&nbsp;'
	        END AS ContactEmail,
	        CASE
	           	WHEN a.allotted_time IS NOT NULL
	               	THEN a.allotted_time
	            WHEN (time_allotted is null or time_allotted = 0) 
	               	THEN 'N/A'
	            ELSE ec.time_allotted
	        END as TimeAllotted,
	        ec.motion,
	        e.ex_parte_flag
	        from
	            events e left outer join event_cases ec on (e.event_id = ec.event_id)
	            left outer join event_types et on (e.event_type_id = et.event_type_id)
	            left outer join import_sources i on (e.import_source_id = i.import_source_id)
	            left outer join olscheduling.bulk_hearings_allotted_times a on (ec.ols_conf_num = a.conf_num and ( ec.case_num = a.case_num or CONCAT('58', ec.case_num) = a.case_num ))
				left outer join olscheduling.law_firms lf on (ec.sched_lawfirm_id = lf.lawfirm_id)
	            left outer join olscheduling.users u on (ec.sched_user_id = u.user_id)
	            left outer join olscheduling.email_addresses ea on (u.login_id = ea.email_addr_id)
	        where
	            DATE(e.start_date) BETWEEN ? and ?
	};
	
	my @args;
	if($division ne 'all' && ($division ne 'ALL')){
   		$query .= qq { and e.division = ? };
   		@args = ($startDate, $endDate, $division);
    }
    else{
    	$query .= qq { and e.division IN ('IPHNB', 'IPHSB', 'MHNB', 'MHSB') };
		@args = ($startDate, $endDate);
    }
   
    $query .= qq {
	            -- and e.is_private = 0
	            and i.import_source_name <> 'Banner'
	            AND i.import_source_name <> 'OLS'
    };
    
    $query .= qq { ORDER BY StartDate };
    
    getData($eventRef,$query,$dbh,{valref => \@args});
    
    my @divTemp;
    my $caseString;
    foreach my $event (@{$eventRef}) {
    	$caseString .= "'" . $event->{'CaseNumber'} . "', ";
    }
    
    if($caseString ne ""){
	    $caseString = substr $caseString, 0, -2;
	    	
	    my $divQuery = qq{
		   	SELECT 
		   		CaseNumber,
		   		DivisionID
			FROM
				$schema.vCase with(nolock)
			WHERE
				CaseNumber IN ($caseString)
		};
		
		getData(\@divTemp, $divQuery, $scdbh);
	}
    
    foreach my $event (@{$eventRef}) {
    
    	if(scalar(@divTemp)){
    		foreach my $div (@divTemp){
    			if($div->{'CaseNumber'} eq $event->{'CaseNumber'}){
    				$event->{'DivisionID'} = $div->{'DivisionID'};
    			}
    		}
    	}
		
        $event->{'CaseNumber'} = sanitizeCaseNumber($event->{'CaseNumber'});
        $event->{'ICMSLink'} = sprintf('<a href="/cgi-bin/search.cgi?name=%s">%s</a>', $event->{'CaseNumber'}, $event->{'CaseNumber'});
        $event->{'NAMELink'} = sprintf('<a href="/cgi-bin/relatedSearch.cgi?ucn=%s">%s</a>', $event->{'CaseNumber'}, $event->{'CaseStyle'});
        $event->{'AttorneyInfo'} = sprintf("%s<br/>%s<br/>%s<br>", $event->{'AttorneyName'}, $event->{'AttorneyPhone'}, $event->{'AttorneyEmail'});
        $event->{'ContactInfo'} = sprintf("%s<br/>%s<br/>%s<br>", $event->{'ContactName'}, $event->{'ContactPhone'}, $event->{'ContactEmail'});
    }
}

sub sortExternalEvents {
	# Takes a hash of events (keyed on the division) and organizes them into a multi-level
	# hash, organized like this:
	#
	#  Division
	#  ----> Date
	#  --------> Start Time
	#  ------------> End Time
    #  ------------> JUDGE
	#  ----------------> Type
	#  --------------------> Case
	#
	# This will get them regardless of their source, into a uniform format that can be
	# insert into the VRB events tables
	my $sorted = shift;
	my $events = shift;
    
    my @validFields = (
        'CaseNumber',
        'CaseStyle',
        'MotionType',
        'Canceled',
        'ConfNum',
        'CancelReason',
        'AttorneyName',
        'AttorneyPhone',
        'AttorneyEmail',
        'ContactName',
        'ContactPhone',
        'ContactEmail',
        'LawFirm',
        'EventCode',
        'JudgeName',
        'JudgeID',
        'EventNotes',
        'TimeAllotted',
        'SlotID'
    );
    
	foreach my $division (sort keys %{$events}) {
        #next if ($division ne 'AA');
        #dumpVar($events->{$division});
        #exit;
        $sorted->{$division} = {};

		my $sortDiv = $sorted->{$division};

		my $noEventIds = 1;
		foreach my $event (@{$events->{$division}}) {
            #next if ($event->{'ConfNum'} ne 'DIVAA20141016130329');
        
			#next if (!defined($event->{'CourtEventType'}));
            next if (!defined($event->{'EventName'}));
			my $edate = $event->{'Date'};
			if (!defined($sortDiv->{$edate})) {
				$sortDiv->{$edate} = {};
			}
			my $sdate = $sortDiv->{$edate};
			my $etime = $event->{'StartTime'};
			if (!defined($sdate->{$etime})) {
				$sdate->{$etime} = {};
			}
			my $stime = $sdate->{$etime};
			
			next if (!defined($event->{'EndTime'}));
			next if (!defined($event->{'CaseStyle'}));
			
			my $eendtime = $event->{'EndTime'};
			if (!defined($stime->{$eendtime})) {
				$stime->{$eendtime} = {};
			}
			my $sendtime = $stime->{$eendtime};

            my $ejudge = $event->{'JudgeName'};
            
            if (!defined($ejudge)) {
                next;
            }
        
            #dumpVar($event);
            #exit;
            
            if (!defined($sendtime->{$ejudge})) {
                $sendtime->{$ejudge} = {};
            }
            my $sjudge = $sendtime->{$ejudge};
            
            
			#my $etype = $event->{'CourtEventType'};
            my $etype = $event->{'EventName'};
		
			if (!defined($sjudge->{$etype})) {
				$sjudge->{$etype} = {};
				$sjudge->{$etype}->{'events'} = [];
                $sjudge->{$etype}->{'EventCode'} = $event->{'EventCode'};
                $sjudge->{$etype}->{'OLSJudgeID'} = $event->{'JudgeID'};
                $sjudge->{$etype}->{'JudgeName'} = $event->{'JudgeName'};
                $sjudge->{$etype}->{'SlotID'} = $event->{'SlotID'};
				if (defined($event->{'VRBEvent'})) {
					$noEventIds = 0;
					$sjudge->{$etype}->{'events'} = {};
					$sjudge->{$etype}->{'events'}->{$event->{'VRBEvent'}} = [];
				}
			}

			my %caseEvent;
            foreach my $field (@validFields) {
                $caseEvent{$field} = $event->{$field};
            }

			if ($noEventIds) {
				push(@{$sjudge->{$etype}->{'events'}}, \%caseEvent);
			} else {
				push(@{$sjudge->{$etype}->{'events'}->{$event->{'VRBEvent'}}}, \%caseEvent);	
			}
		}
	}
}



sub vrbCompareAndUpdate {
    my $existing = shift;
    my $incoming = shift;
    my $import_source_id = shift;
    my $dbh = shift;
    
    # Get the listing of event types
    my %eventTypes;
    getVrbEventTypes(\%eventTypes, $dbh);
    
    # Ok, first walk through the existing entries in the VRB events table; if there are no corresponding
    # events in the $incoming hash, then we'll want to delete the record in VRB
    
    # Let's make this a transaction
    $dbh->{'AutoCommit'} = 0;
    
    my $query = qq {
        select
            import_source_name
        from
            import_sources
        where
            import_source_id = ?
    };
    
    my $isnInfo = getDataOne($query, $dbh, [$import_source_id]);
    if (!defined $isnInfo) {
        return;
    }
    my $isn = $isnInfo->{'import_source_name'};
    
    # Start a transaction
    $dbh->begin_work;
    foreach my $division (sort keys %{$existing}) {
        my $vdiv = $existing->{$division};
        foreach my $date (sort keys %{$vdiv}) {
            my $vdate = $vdiv->{$date};
            foreach my $stime (sort keys %{$vdate}) {
                my $vstime = $vdate->{$stime};
                foreach my $etime (sort keys %{$vstime}) {
                    my $vetime = $vstime->{$etime};
                    foreach my $jn (sort keys %{$vetime}) {
                        my $vjudge = $vetime->{$jn};
                    foreach my $type (sort keys %{$vjudge}) {
                        my $vevents = $vjudge->{$type};
                        foreach my $eventID (keys %{$vevents->{'events'}}) {
                            # Ok, we have worked our way down to the deepest level.  See if there are corresponding
                            # events in the imported data
                            my $match = $incoming->{$division}->{$date}->{$stime}->{$etime}->{$type};
                            if (defined($match)) {
                                my $events = $match->{'events'};
                                my $judge_name = $match->{'JudgeName'};
                                my $ols_judge_id = $match->{'OLSJudgeID'};
                                my $ols_slot_id = $match->{'SlotID'};
                                # First, delete the existing hearings for this event.
                                my $query = qq {
                                    delete from
                                        event_cases
                                    where
                                        event_id = ?
                                };
                                doQuery($query,$dbh,[$eventID]);
                                foreach my $event (@{$events}) {
                                    $query = qq {
                                        insert into
                                            event_cases (
                                                event_id,
                                                case_num,
                                                case_style,
                                                motion,
                                                event_notes,
                                                time_allotted,
                                                ols_conf_num,
                                                lawfirm_name,
                                                attorney_name,
                                                attorney_phone,
                                                attorney_email,
                                                contact_name,
                                                contact_phone,
                                                contact_email
                                            )
                                        values (
                                            ?,?,?,?,?,?,?,?,?,?,?,?,?,?
                                        )
                                    };
                                    doQuery($query,$dbh,[$eventID,$event->{'CaseNumber'}, $event->{'CaseStyle'}, $event->{'MotionType'},
                                                         $event->{'EventNotes'}, $event->{'TimeAllotted'}, $event->{'ConfNum'},
                                                         $event->{'LawFirm'}, $event->{'AttorneyName'}, $event->{'AttorneyPhone'},
                                                         $event->{'AttorneyEmail'}, $event->{'ContactName'}, $event->{'ContactPhone'},
                                                         $event->{'ContactEmail'}]);
                                }
                                
                                my $thisOne = $events->[0];
                                $thisOne->{'isCanceled'} = $thisOne->{'Canceled'} eq 'Y' ? 1 : 0;
                                
                                # And update the events table with the confirmation number
                                $query = qq {
                                    update
                                        events
                                    set
                                        canceled = ?,
                                        cancel_reason = ?,
                                        judge_name = ?,
                                        ols_judge_id = ?,
                                        ols_slot_id = ?
                                    where
                                        event_id = ?
                                };
                                doQuery($query, $dbh, [$thisOne->{'isCanceled'},$thisOne->{'CancelReason'}, $judge_name, $ols_judge_id, $ols_slot_id, $eventID]);
                                                
                                $match->{'imported'} = 1;
                            } else {
                                # No match.  Delete the event
                                # First, delete the event_cases.  There shouldn't be any, but just in case.
                                my $query = qq {
                                    delete from
                                        event_cases
                                    where
                                        event_id = ?
                                };
                                doQuery($query,$dbh,[$eventID]);
    
                                # And now delete the event
                                $query = qq {
                                    delete from
                                        events
                                    where
                                        event_id = ?
                                };
                                doQuery($query,$dbh,[$eventID]);
                            }
                        }
                    }
                }}
            }
        }
    }
    
    # Ok, now that we have compared existing rows, let's go through the imported rows to see if there are
    # any new events that need to be scheduled.
    foreach my $division (sort keys %{$incoming}) {
        my $idiv = $incoming->{$division};
        foreach my $date (sort keys %{$idiv}) {
            my $idate = $idiv->{$date};
            foreach my $stime (sort keys %{$idate}) {
                my $istime = $idate->{$stime};
                foreach my $etime (sort keys %{$istime}) {
                    my $ietime = $istime->{$etime};
                    foreach my $ejudge (sort keys %{$ietime}) {
                        my $iejudge = $ietime->{$ejudge};
                    foreach my $type (sort keys %{$iejudge}) {
                        my $ievents = $iejudge->{$type};
                        my $code = $ievents->{'EventCode'};
                        my $judge_name = $ievents->{'JudgeName'};
                        my $ols_judge_id = $ievents->{'OLSJudgeID'};
                        my $ols_slot_id = $ievents->{'SlotID'};
                        # Did we already deal with this one above?  Skip if so.
                        next if ((defined($ievents->{'imported'})) && ($ievents->{'imported'} = 1));
                        # Ok, this is one that doesn't have an existing event in the events table.  Make one.
                        my $events = $ievents->{'events'};
                        # Check to see if all of the event cases are canceled - if so, mark the event canceled
                        
                        my $canceled = 1;
                        
                        foreach my $event (@{$events}) {
                            if ($event->{'Canceled'} eq 'N') {
                                $canceled = 0;
                                last;
                            }
                        }
                        
                        #my $conf_num = $events->[0]->{'ConfNum'};
                        my $thisOne = $events->[0];
                        
                        my $event_type_id;
                        if (!defined($eventTypes{uc($type)})) {
                            # There's no event type ID defined.  Need to add one.
                            my $query = qq {
                                insert into
                                    event_types
                                    (
                                        event_type_desc,
                                        event_type_code
                                    )
                                    values
                                    (
                                        ?,?
                                    )
                            };
                            doQuery($query, $dbh, [uc($type),uc($code)]);
                            # Need the ID
                            $event_type_id = lastInsert($dbh);
                            $eventTypes{uc($type)} = {};
                            $eventTypes{uc($type)}->{'event_type_id'} = $event_type_id;;
                            $eventTypes{uc($type)}->{'EventType'} = uc($type);
                            print "Needed to add event type for '" . uc($type) . "'\n";
                        } else {
                            $event_type_id = $eventTypes{uc($type)}->{'event_type_id'};
                        }
                        
                        my $query = qq {
                            insert into
                                events (
                                    start_date,
                                    end_date,
                                    event_name,
                                    division,
                                    event_type,
                                    user_id,
                                    canceled,
                                    import_source_id,
                                    import_source_name,
                                    event_type_id,
                                    judge_name,
                                    ols_judge_id,
                                    ols_slot_id
                                )
                                values (
                                    ?,?,?,?,?,?,?,?,?,?,?,?,?
                                )
                        };
                        my @args = (
                            sprintf("%s %s", $date, $stime),
                            sprintf("%s %s", $date, $etime),
                            $type,
                            $division,
                            'other',
                            'importer',
                            $canceled,
                            $import_source_id,
                            $isn,
                            $event_type_id,
                            $judge_name,
                            $ols_judge_id,
                            $ols_slot_id
                        );
                        doQuery($query,$dbh,\@args);
                        # Get the event ID
                        
                        my $eventID = lastInsert($dbh);
    
                        # Ok, now we have the new event ID.  Insert the individual case events
                        foreach my $event (@{$events}) {
                            $query = qq {
                                insert into
                                    event_cases (
                                        event_id,
                                        case_num,
                                        case_style,
                                        motion,
                                        event_notes,
                                        time_allotted,
                                        ols_conf_num,
                                        lawfirm_name,
                                        attorney_name,
                                        attorney_phone,
                                        attorney_email,
                                        contact_name,
                                        contact_phone,
                                        contact_email
                                    )
                                    values (
                                        ?,?,?,?,?,?,?,?,?,?,?,?,?,?
                                    )
                            };
                            
                            doQuery($query,$dbh,[$eventID,$event->{'CaseNumber'}, $event->{'CaseStyle'}, $event->{'MotionType'},
                                                 $event->{'EventNotes'}, $event->{'TimeAllotted'}, $event->{'ConfNum'},
                                                 $event->{'LawFirm'}, $event->{'AttorneyName'}, $event->{'AttorneyPhone'},
                                                 $event->{'AttorneyEmail'}, $event->{'ContactName'}, $event->{'ContactPhone'},
                                                 $event->{'ContactEmail'}]);
                            
                        }
                    }
                }}
            }
        }
    }
    
    
    # Commit!
    $dbh->commit;
}


sub getVrbEventTypes {
	my $typeRef = shift;
	my $dbh = shift;
	
	my $query = qq {
		select
			UPPER(event_type_desc) as EventType,
			event_type_id
		from
			event_types
		order by
			event_type_desc
	};
	
	getData($typeRef, $query, $dbh, {hashkey => 'EventType', flatten => 1});
}

1;
