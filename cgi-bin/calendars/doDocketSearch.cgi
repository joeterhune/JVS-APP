#!/usr/bin/perl -w

BEGIN {
    use lib "$ENV{'PERL5LIB'}";
}

use strict;

use Common qw (
    dumpVar
    doTemplate
    ISO_date
    inArray
    $templateDir
    returnJson
    createTab
);

use DB_Functions qw (
    dbConnect
    getData
    getDbSchema
    $DEFAULT_SCHEMA
);

use Showcase qw (
    $db
);

use CGI;

my $info = new CGI;

my %params = $info->Vars;

my $dbh = dbConnect($db);
my $schema = getDbSchema($db);

my @args;

my $href = "/cgi-bin/case/calendars/trafficDocket.cgi";
my $count = 0;

foreach my $p (keys %params){
	$params{$p} =~ s/#/%23/g;
	if($count < 1){
		$href .= "?" . $p . "=" . $params{$p};
	}
	else{
		$href .= "&" . $p . "=" . $params{$p};
	}
	$count++;
}

# Do we have just a date specified, or a time AND date?
my $whereClause;
if ((defined($params{'starttime'})) && ($params{'starttime'} ne '')) {
    my $startstr = sprintf ("%s %s", $params{'day'}, $params{'starttime'});
    if ((defined($params{'endtime'})) && ($params{'endtime'} ne '')) {
        my $endstr = sprintf("%s %s", $params{'day'}, $params{'endtime'});
        $whereClause .= "CourtEventDate >= ? and CourtEventdate <= ?";
        push(@args, $startstr, $endstr);
    } else {
        $whereClause .= "CourtEventDate = ?";
        push (@args, $startstr);
    }
} else {
    $whereClause = "CONVERT(date,CourtEventDate) = ?";
    push (@args, $params{'day'});
}

# How about a courtroom?
if ((defined($params{'courtroom'})) && ($params{'courtroom'} ne '')) {
	$params{'courtroom'} =~ s/%23/#/g;
    $whereClause .= " and CourtRoom = ?";
    push(@args, $params{'courtroom'});
}

# Judge?
if ((defined($params{'judge'})) && ($params{'judge'} ne '')) {
    $whereClause .= " and JudgeName = ?";
    push(@args, $params{'judge'});
}

createTab("Traffic Docket", $href, 1, 1, "calendars");

my $query = qq {
    select
        vce.CaseNumber,
        vce.UCN,
        CONVERT(varchar(10),vce.CourtEventDate,120) as CourtEventDate,
        vce.CourtEventCode,
        vce.CourtEventType,
        vce.CourtLocation,
        vce.CourtRoom,
        vce.CourtType,
        vce.CourtEventID,
        CONVERT(varchar,CAST(vce.CourtEventDate as time),100) as CourtEventTime,
        CASE
            WHEN InCourtProcessingStartTime is null THEN 'Pending'
            WHEN InCourtProcessingEndTime is null THEN 'InProcess'
            ELSE 'Processed'
        END as ICPStatus,
        CaseID
    from
        $schema.vCourtEvent vce with(nolock)
    where
        $whereClause
        and Cancelled IN ('N', 'No')
};

my %result;
my %data;
$data{'events'} = [];

getData($data{'events'}, $query, $dbh, {valref => \@args});


# Now get the current ICP statuses of these cases. Build a listing of CourtEventIDs
my @eventids;
foreach my $event (@{$data{'events'}}) {
    push(@eventids, $event->{'CourtEventID'});
    $event->{'ICPClass'} = $event->{'ICPStatus'};
    $event->{'ICPClass'} =~ s/-//g;
    if ($event->{'CourtEventTime'} =~ /(\d{1,2})(:)(\d\d)(\w*)/) {
        $event->{'CourtEventTime'} = sprintf ("%s:%s %s", $1, $3, $4);
    }
    
}

# Are we showing traffic cases?  Need to show additional information, if so.
my $isTraffic = 0;
foreach my $event (@{$data{'events'}}) {
    if (inArray(['TR','IN'], $event->{'CourtType'})) {
        $isTraffic = 1;
        last;
    }
}

if ($isTraffic) {
    # Need to gather more information for each case. Build a listing of the case numbers
    my @calCases;
    foreach my $event (@{$data{'events'}}) {
        my $casenum = $event->{'CaseNumber'};
        if (!inArray(\@calCases, "'$casenum'")) {
            push(@calCases, "'$casenum'");
        }
    }
    
    my %attys;
    getAttorneyNames(\@calCases, \%attys, $dbh, $schema);
    
    # Now march through the event list and attach these attorneys to appropriate cases/events.
    # Much faster to do it this way, after a single query, than to do a bunch of different queries.
    foreach my $casenum (keys %attys) {
        foreach my $event (@{$data{'events'}}) {
            next if ($casenum ne $event->{'CaseNumber'});
            # Create an array ref for this hearing's attorneys
            if (!defined($event->{'Attorneys'})) {
                $event->{'Attorneys'} = [];
            }
            foreach my $attorney (@{$attys{$casenum}}) {
                push (@{$event->{'Attorneys'}}, $attorney->{'AttorneyName'});
            }
        }
    }
    
    my %defendants;
    getDeftNames(\@calCases, \%defendants, $dbh, $schema);

    # Do the same thing we did with attorneys
    foreach my $casenum (keys %defendants) {
        foreach my $event (@{$data{'events'}}) {
            next if ($casenum ne $event->{'CaseNumber'});
            $event->{'Defendant'} = $defendants{$casenum}->{'DefendantName'};
            $event->{'DefendantDOB'} = $defendants{$casenum}->{'DOB'};
        }
    }
    
    my %charges;
    
    getCaseCharges(\@calCases, \%charges, $dbh, $schema);
    
    # Do the same thing we did with witnesses
    foreach my $casenum (keys %charges) {
        foreach my $event (@{$data{'events'}}) {
            next if ($casenum ne $event->{'CaseNumber'});
            # Create an array ref for this hearing's charges
            if (!defined($event->{'Charges'})) {
                $event->{'Charges'} = [];
            }
            foreach my $charge (@{$charges{$casenum}}) {
                push (@{$event->{'Charges'}}, $charge);
            }
            $event->{'OfficerLastName'} = $event->{'Charges'}->[0]->{'Citation'}->[0]->{'OfficerLastName'};
            $event->{'OfficerFirstName'} = $event->{'Charges'}->[0]->{'Citation'}->[0]->{'OfficerFirstName'};
            $event->{'OfficerMiddleName'} = $event->{'Charges'}->[0]->{'Citation'}->[0]->{'OfficerMiddleName'};
                
            $event->{'OfficerName'} = "";
            if (defined($event->{'OfficerLastName'})) {
                if (defined($event->{'OfficerFirstName'})) {
                    if (defined($event->{'OfficerMiddleName'})) {
                        $event->{'OfficerName'} = sprintf ("%s, %s %s", $event->{'OfficerLastName'},
                                                           $event->{'OfficerFirstName'},
                                                           $event->{'OfficerMiddleName'});
                    } else {
                        $event->{'OfficerName'} = sprintf ("%s, %s", $event->{'OfficerLastName'},
                                                           $event->{'OfficerFirstName'});
                    }
                } else {
                    $event->{'OfficeName'} = $event->{'OfficerLastName'};
                }
            }
            
            use Time::Piece;
            my $chargeDate = $event->{'Charges'}->[0]->{'ChargeDate'};
            my $dob = $event->{'DefendantDOB'};
            
            if(($chargeDate ne "") && ($dob ne "")){
	            my $format = '%b %d %Y %H:%M:%S:000%p';
	            
	            my @cPieces = split / /, $chargeDate;
	            my $cYear = $cPieces[2]; 
	            my @dPieces = split / /, $dob;
	            my $dYear = $dPieces[2]; 
	            my $diff;
	            my $ageAtOffense;
	            
	            if(($cYear > 1902) && ($dYear > 1902)){
					$diff = Time::Piece->strptime($chargeDate, $format)
					         - Time::Piece->strptime($dob, $format);
					$ageAtOffense = $diff / 31536000; # seconds to years
		            
		            if(($chargeDate ne "") && ($ageAtOffense < 18)){
		            	$event->{'Minor'} = "Y";
		            }
		            else{
		            	$event->{'Minor'} = "N";
		            }
	            }
	            else{
	            	$event->{'Minor'} = "N";
	            }
            }
            else{
            	$event->{'Minor'} = "N";
            }
            
            if (($event->{'Charges'}->[0]->{'Citation'}->[0]->{'AggressiveDriving'} eq 'Y') &&
                ($event->{'Charges'}->[0]->{'Citation'}->[0]->{'Both'} eq 'Y')) {
                $event->{'RowClass'} = "aggressive-cdl"
            } elsif ($event->{'Charges'}->[0]->{'Citation'}->[0]->{'AggressiveDriving'} eq 'Y') {
                $event->{'RowClass'} = "aggressive";
            } elsif ($event->{'Charges'}->[0]->{'Citation'}->[0]->{'CommercialDL'} eq 'Y') {
                $event->{'RowClass'} = "cdl";
            }	
            elsif($event->{'Minor'} eq 'Y'){
            	$event->{'RowClass'} = "minor";
            }
            else {
                $event->{'RowClass'} = "normal";
            }
                
            if (defined($event->{'Charges'}->[0]->{'Citation'}->[0]->{'Variance'})) {
                my $variance = $event->{'Charges'}->[0]->{'Citation'}->[0]->{'Variance'};
                
                if ((6 <= $variance) && ($variance <= 9)) {
                    $event->{'SpeedClass'} = "plus6";
                } elsif ((10 <= $variance) && ($variance <= 14)) {
                    $event->{'SpeedClass'} = "plus10";
                } elsif ((15 <= $variance) && ($variance <= 19)) {
                    $event->{'SpeedClass'} = "plus15";
                } elsif ((20 <= $variance) && ($variance <= 29)) {
                    $event->{'SpeedClass'} = "plus20";
                } elsif (30 <= $variance) {
                    $event->{'SpeedClass'} = "plus30";
                } else {
                    $event->{'SpeedClass'} = "normal";
                }
            }
        }
    }
    
    # Get the last hearing notice for each case
    my %hearingNotices;
    getHearingNotices(\@calCases, \%hearingNotices, $dbh, $schema);
    
    # Get the affidavit of defense for each case (if there is one)
    my %aodfs;
    getAffidavitsOfDefense(\@calCases, \%aodfs, $dbh, $schema);
    
    foreach my $event (@{$data{'events'}}) {
        my $casenum = $event->{'CaseNumber'};
        if (defined($hearingNotices{$casenum})) {
            $event->{'LastNOH'} = $hearingNotices{$casenum}->[0];
        } else {
            $event->{'LastNOH'} = {};
        }
        
        if (defined($aodfs{$casenum})) {
            $event->{'AODF'} = $aodfs{$casenum}->[0];
        } else {
            $event->{'AODF'} = {};
        }
    }
    
    my %witnesses;
    getWitnessNames(\@calCases, \%witnesses, $dbh, $schema);
    
    # Do the same thing we did with attorneys
    foreach my $casenum (keys %witnesses) {
        foreach my $event(@{$data{'events'}}) {
            next if ($casenum ne $event->{'CaseNumber'});
            # Create an array ref for this hearing's witnesses
            if (!defined($event->{'Witnesses'})) {
                $event->{'Witnesses'} = [];
            }
            foreach my $witness (@{$witnesses{$casenum}}) {
            	$event->{'OfficerLastName'} =~ s/\*//g;
                if ((defined($event->{'OfficerLastName'})) &&
                    ($witness->{'LastName'} =~ /^$event->{'OfficerLastName'}$/i)) {
                    if ((defined($event->{'OfficerFirstName'})) &&
                        ((defined($witness->{'FirstName'})) &&
                         ($witness->{'FirstName'} =~ /^$event->{'OfficerFirstName'}$/i))) {
                        # Both first and last names are defined for both and both match
                        next;
                    } elsif ((!(defined($witness->{'FirstName'}))) || ($witness->{'FirstName'} eq "")){
                        # No first name specified for LEO, so assume matches witness
                        next;
                    }
                }
                    
                my $witnessname = "";
                if (defined($witness->{'FirstName'})) { 
                    if (defined($witness->{'MiddleName'})) {
                        $witnessname = sprintf("%s, %s %s", $witness->{'LastName'}, $witness->{'FirstName'},
                                               $witness->{'MiddleName'});    
                    } else {
                        $witnessname = sprintf("%s, %s", $witness->{'LastName'}, $witness->{'FirstName'});
                    }
                } else {
                    $witnessname = $witness->{'LastName'};
                }
                push (@{$event->{'Witnesses'}}, $witnessname);   
            }
        }
    }
    
    $result{'status'} = 'Success';
    $result{'html'} = doTemplate(\%data, "$templateDir/calendars", "trafficDocket.tt", 0);
    returnJson(\%result);
    exit;
}

$result{'status'} = 'Success';
$result{'html'} = doTemplate(\%data, "$templateDir/calendars", "crimDocket.tt", 0);
returnJson(\%result);
exit;


sub getAttorneyNames {
    my $caselist = shift;  # Array of quoted case numbers (so they can be joined)
    my $attyref = shift; # Must be a hash ref!
    my $dbh = shift;
    my $schema = shift;
    
    my $caseStr = join(",", @{$caselist});
    
    my $query = qq {
        select
            CaseNumber,
            AttorneyName
        from
            $schema.vAttorney with(nolock)
        where
            CaseNumber in ($caseStr)
    };
    
    getData($attyref, $query, $dbh, {hashkey => "CaseNumber"});
};


sub getWitnessNames {
    my $caselist = shift;  # Array of quoted case numbers (so they can be joined)
    my $witnessref = shift; # Must be a hash ref!
    my $dbh = shift;
    my $schema = shift;
    
    my $caseStr = join(",", @{$caselist});
    
    my $query = qq {
        select
            CaseNumber,
            LastName,
            FirstName,
            MiddleName
        from
            $schema.vParty with(nolock)
        where
            CaseNumber in ($caseStr)
            and PartyTypeDescription = 'WITNESS'
    };
    
    getData($witnessref, $query, $dbh, {hashkey => "CaseNumber"});
};


sub getDeftNames {
    my $caselist = shift;  # Array of quoted case numbers (so they can be joined)
    my $deftref = shift; # Must be a hash ref!
    my $dbh = shift;
    my $schema = shift;
    
    my $caseStr = join(",", @{$caselist});
    
    my $query = qq {
        select
            CaseNumber,
            (ISNULL(LastName,'')) + ', ' + (ISNULL(FirstName,'')) + ' ' + (ISNULL(MiddleName,'')) as DefendantName,
            DOB
        from
            $schema.vParty with(nolock)
        where
            CaseNumber in ($caseStr)
            and PartyTypeDescription = 'DEFENDANT'
    };
    
    getData($deftref, $query, $dbh, {hashkey => "CaseNumber", flatten => 1});
};



sub getCaseCharges {
    my $caselist = shift;
    my $chargeRef = shift;
    my $dbh = shift;
    my $schema = shift;
    
    my $caseStr = join(",", @{$caselist});
    
    my $query = qq {
        select
            CaseNumber,
            CourtStatuteDescription,
            CourtStatuteNumber,
            CitationNumber,
            ChargeDate
        from
            $schema.vCharge with(nolock)
        where
            CaseNumber in ($caseStr)
            and CitationNumber is not null
        order by
            ChargeCount asc
    };
    
    getData($chargeRef,$query,$dbh,{hashkey => "CaseNumber"});
    
    my %citations;
    $query = qq {
        select
            CitationNumber,
            AggressiveDriving,
            CommercialDL,
            Crash,
            CASE ActualSpeed
                WHEN 0 THEN null
                ELSE ActualSpeed
            END as ActualSpeed,
            CASE PostedSpeed
                WHEN 0 THEN null
                ELSE PostedSpeed
            END as PostedSpeed,
            CASE PostedSpeed
                WHEN 0 THEN null
                ELSE (ActualSpeed - PostedSpeed)
            END as Variance,
            OfficerLastName,
            OfficerFirstName,
            OfficerMiddleName
        from
            $schema.vCitation with(nolock)
        where
            CaseNumber in ($caseStr)
    };
    getData(\%citations, $query, $dbh, {hashkey => "CitationNumber"});
    
    # Now join the citation information to the charge
    foreach my $citation (keys %citations) {
        foreach my $casenum (keys %{$chargeRef}) {
            foreach my $charge (@{$chargeRef->{$casenum}}) {
                next if ((!defined($charge->{'CitationNumber'})) || ($charge->{'CitationNumber'} ne $citation));
                $charge->{'Citation'} = $citations{$citation};
                last;
            }
        }
    }
}


sub getHearingNotices {
    my $caselist = shift;
    my $hearingRef = shift;
    my $dbh = shift;
    my $schema = shift;
    
    my $caseStr = join(",", @{$caselist});
    
    my $query = qq {
        select
            CaseNumber,
            ObjectID,
            CONVERT(varchar(10),EffectiveDate,101) as EffectiveDate
        from
            $schema.vDocket with(nolock)
        where
            CaseNumber in ($caseStr)
            and DocketCode = 'NOH'
        order by
            EffectiveDate desc
    };
    
    getData($hearingRef,$query,$dbh,{hashkey => "CaseNumber"});
}

sub getAffidavitsOfDefense {
    my $caselist = shift;
    my $aodfRef = shift;
    my $dbh = shift;
    my $schema = shift;
    
    my $caseStr = join(",", @{$caselist});
    
    my $query = qq {
        select
            CaseNumber,
            ObjectID,
            CONVERT(varchar(10),EffectiveDate,101) as EffectiveDate
        from
            $schema.vDocket with(nolock)
        where
            CaseNumber in ($caseStr)
            and DocketCode IN ('AODF', 'AODF1')
        order by
            EffectiveDate desc
    };
    
    getData($aodfRef,$query,$dbh,{hashkey => "CaseNumber"});
}
