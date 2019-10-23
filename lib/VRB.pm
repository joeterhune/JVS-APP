package VRB;
use strict;
use warnings;

BEGIN {
    use lib "$ENV{'JVS_PERL5LIB'}";
}

require Exporter;

use Common qw (
    getArrayPieces
    ISO_date
    today
    dumpVar
);

use DB_Functions qw (
    doQuery
    getData
    getDataOne
    getDbSchema
);

use POSIX qw (
    strftime
);

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    processShowcaseParties
    processDockets
    processEvents
    getShowcaseDockets
    getShowcaseParties
    getShowcaseEvents
    getLastImport
    updateLastImport
);


sub processEvents {
    my $eventRef = shift;
    my $seenEvents = shift;
    my $dbh = shift;
    
    foreach my $casenumber (keys %{$eventRef}) {
        foreach my $event (@{$eventRef->{$casenumber}}) {
            my $eventCode = $event->{'EventCode'};
            next if (!defined($eventCode));
        
            if (!defined($seenEvents->{$eventCode})) {
                my $query = qq {
                    replace into
                        event_codes (
                            EventCode,
                            EventType
                        )
                        values (
                            ?,?
                        )
                };
                doQuery($query, $dbh, [$eventCode, $event->{'EventCode'}]);
                $seenEvents->{$eventCode} = 1;
            }
        }
        addCaseEvents($eventRef, $casenumber, $dbh);
    }
}

sub processDockets {
    my $docketRef = shift;
    my $seenDockets = shift;
    my $dbh = shift;
    
    foreach my $casenumber (keys %{$docketRef}) {
        
        foreach my $docket (@{$docketRef->{$casenumber}}) {
            my $docketCode = $docket->{'DocketCode'};
            
            if (!defined($seenDockets->{$docketCode})) {
                my $query = qq {
                    replace into
                        docket_codes (
                            DocketCode,
                            DocketType
                        )
                    values (
                        ?,?
                    )
                };
                doQuery($query, $dbh, [$docketCode, $docket->{'DocketType'}]);
                $seenDockets->{$docketCode} = 1;
            }
        }
        
        addCaseDockets($docketRef, $casenumber, $dbh);
    }
}

sub processShowcaseParties {
    my $partyRef = shift;
    my $seenPIDMs = shift;
    my $dbh = shift;
     
    foreach my $casenumber (keys %{$partyRef}) {
        foreach my $party (@{$partyRef->{$casenumber}}) {
            
            # First, insert the party into the parties table
            my $pidm = $party->{'PIDM'};
            if (!defined($pidm)) {
                # Wasn't defined.  Must be an attorney
                $pidm = $party->{'PartyID'};
                $party->{'PIDM'} = $pidm;
            }
            
            if (!defined($pidm)) {
                next;
            }
                  
            if (!defined($seenPIDMs->{$pidm})) {
                my $partyID;
                my $barNum;
                if ($party->{'PartyType'} eq 'ATTY') {
                    $partyID = undef;
                    $barNum = $party->{'BarNumber'};
                } else {
                    $barNum = undef;
                    $partyID = $party->{'PartyID'};
                }
            
                my @pidmArgs = (
                    $pidm,
                    $partyID,
                    $barNum,
                    $party->{'LastName'},
                    $party->{'FirstName'},
                    $party->{'MiddleName'},
                    $party->{'Suffix'},
                );
                
                my $pidmQuery = qq {
                    replace into
                        parties (
                            PIDM,
                            PartyID,
                            BarNumber,
                            LastName,
                            FirstName,
                            MiddleName,
                            Suffix
                        )
                        values (?,?,?,?,?,?,?)
                };
                doQuery($pidmQuery,$dbh,\@pidmArgs);
                
                $seenPIDMs->{$pidm} = 1;
            }
        }
        addCaseParties($partyRef, $casenumber, $dbh);
    }
    
}


sub addCaseParties {
    my $parties = shift;
    my $casenumber = shift;
    my $dbh = shift;
    
    my $caseParties = $parties->{$casenumber};
    
    if ($casenumber =~ /(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)/) {
        $casenumber = sprintf("%04d-%s-%06d", $1, $2, $3);
    }
    
    my $count = 0;
    my $perQuery = 100;
    
    while ($count < scalar(@{$caseParties})) {
        my @inserts;
        my @temp;
        
        getArrayPieces($caseParties, $count, $perQuery, \@temp);
        
        foreach my $caseParty (@temp) {
            next if ($caseParty->{'PIDM'} =~ /\D/);
            my $str = sprintf("('%s', %d, %d, %s,'%s')", $casenumber, $caseParty->{'PIDM'},
                              $caseParty->{'Sequence'},
                              defined($caseParty->{'Represents'}) ? $caseParty->{'Represents'} : 'null',
                              $caseParty->{'PartyType'});
            push(@inserts,$str);
        }
        
        my $insertString = join(",", @inserts);
        
        my $query = qq {
            replace into
                case_parties
            values
                $insertString
        };
        doQuery($query,$dbh);
    
        $count += $perQuery;
    }
}


sub addCaseDockets {
    my $dockets = shift;
    my $casenumber = shift;
    my $dbh = shift;
    
    my $caseDocs = $dockets->{$casenumber};
    
    if ($casenumber =~ /(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)/) {
        $casenumber = sprintf("%04d-%s-%06d", $1, $2, $3);
    }
    
    my $count = 0;
    my $perQuery = 100;
    
    while ($count < scalar(@{$caseDocs})) {
        my @inserts;
        my @temp;
        
        getArrayPieces($caseDocs, $count, $perQuery, \@temp);
        
        foreach my $caseDoc (@temp) {
            my $str = sprintf("('%s','%s','%s','%s', %d)", $casenumber, $caseDoc->{'DocketCode'},
                              ISO_date($caseDoc->{'EnteredDate'}), ISO_date($caseDoc->{'FileDate'}), $caseDoc->{'Sequence'});
            push(@inserts,$str);
        }
    
        my $insertString = join(",", @inserts);
        
        my $query = qq {
            replace into
                case_dockets
            values 
                $insertString
            
        };
        
        doQuery($query, $dbh);
        $count += $perQuery;
    }
}


sub addCaseEvents {
    my $events = shift;
    my $casenumber = shift;
    my $dbh = shift;
    
    my $caseEvents = $events->{$casenumber};
    
    if ($casenumber =~ /(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)/) {
        $casenumber = sprintf("%04d-%s-%06d", $1, $2, $3);
    }
    
    my $count = 0;
    my $perQuery = 100;
    
    while ($count < scalar(@{$caseEvents})) {
        my @inserts;
        my @temp;
        
        getArrayPieces($caseEvents, $count, $perQuery, \@temp);
        
        foreach my $caseEvent (@temp) {
            if (!defined($caseEvent->{'EventDate'})) {
                next;
            }
    
            if (!defined($caseEvent->{'StartTime'})) {
                next;
            }
            
            my ($time, $merid) = split(/\s+/, $caseEvent->{'StartTime'});
            
            my ($hour, $min, $junk) = split(":", $time, 3);
            if ((defined($merid)) && ($merid =~ /PM/i)) {
                $hour += 12;
                if ($hour == 24) {
                    $hour = 0;
                }
            }
            my $evtdate = sprintf("%s %02d:%02d", ISO_date($caseEvent->{'EventDate'}), $hour, $min);
            
            my $str = sprintf("('%s','%s','%s')", $casenumber, $caseEvent->{'EventCode'}, $evtdate);
            push(@inserts,$str);
        }
    
        my $insertString = join(",", @inserts);
        
        my $query = qq {
            replace into
                case_events
            values 
                $insertString
            
        };
        
        doQuery($query, $dbh);
        $count += $perQuery;
    }
}

sub getShowcaseDockets {
    my $docketRef = shift;
    my $dbh = shift;
    my $schema = shift;
    my $caseList = shift;
    my $lastDate = shift;
    
    my $ldString = "";
    
    if (defined($lastDate)) {
        my $now = strftime "%Y-%m-%d %H:%M:%S", localtime;
        $ldString = qq (
            and d.EnteredDate between '$lastDate' and '$now'
        );
    }
    
    my $caseString = "";
    
    if (defined($caseList)) {
        my $inString = join(",", @{$caseList});
        $caseString = sprintf ("and CaseNumber in (%s)", $inString);
    }
    
    my $query = qq {
        select
            d.DocketCode,
            t.DocketDescription as DocketType,
            CONVERT(varchar(10),d.EffectiveDate,120) as FileDate,
            CONVERT(varchar(10),d.EnteredDate,120) as EnteredDate,
            CaseNumber,
            SeqPos as Sequence
        from
            $schema.tblDocketCode t left outer join $schema.tblDocket d on (t.DocketCodeID = d.DocketCodeID) left outer join $schema.tblCase c on (d.CaseID = c.CaseID)
        where
            1=1 $caseString
            $ldString
        order by
            CaseNumber
    };
    
    getData($docketRef, $query, $dbh, {hashkey => 'CaseNumber'});
}

sub getShowcaseParties {
    my $partyRef = shift;
    my $dbh = shift;
    my $schema = shift;
    my $caseList = shift;
    my $lastDate = shift;
    
    my $ldString = "";
    
    if (defined($lastDate)) {
        $ldString = qq (
            and CreateDate >= '$lastDate'
        );
    }
    
    my $caseString = "";
    
    if (defined($caseList)) {
        my $inString = join(",", @{$caseList});
        $caseString = sprintf ("and CaseNumber in (%s)", $inString);
    }
    
    my $query = qq {
        select
            PersonID as PIDM,
            BarNumber as PartyID,
            LastName,
            FirstName,
            MiddleName,
            NameSuffixCode as Suffix,
            CaseNumber,
            PartyType,
            CASE PartyType WHEN
                'DFT' then 1
                ELSE 2
            END as Sequence,
            CASE PartyType WHEN
                'ATTY' then 1
                ELSE null
            END as Represents
        from
            $schema.vAllParties with(nolock)
        where
            PartyType in ('DFT','ATTY') $caseString
            $ldString
    };
    
    getData($partyRef, $query, $dbh, {hashkey => 'CaseNumber'});
}


sub getShowcaseEvents {
    my $eventRef = shift;
    my $dbh = shift;
    my $schema = shift;
    my $caseList = shift;
    my $lastDate = shift;
    
    my $ldString = "";
    
    if (defined($lastDate)) {
        my $now = strftime "%Y-%m-%d %H:%M:%S", localtime;
        $ldString = qq (
            and CreateDate between '$lastDate' and '$now'
        );
    }
    
    my $caseString = "";
    
    if (defined($caseList)) {
        my $inString = join(",", @{$caseList});
        $caseString = sprintf ("and CaseNumber in (%s)", $inString);
    }
    
    my $query = qq {
        select
            CaseNumber,
            SeqPos as Sequence,
            CourtEventCode as EventCode,
            CourtEventType as EventDescription,
            CONVERT(varchar(10),CourtEventDate, 120) as EventDate,
            CourtRoom as EventRoom,
            CAST(CourtEventDate as time) as StartTime,
            CourtRoom as Location
        from
            $schema.vCourtEvent with(nolock)
        where
            1=1 $caseString
            $ldString
        order by
            CaseNumber
    };
    
    getData($eventRef, $query, $dbh, {hashkey => "CaseNumber"});
}


sub getLastImport {
    my $type = shift;
    my $dbh = shift;
    
    my $query = qq {
        select
            import_time
        from
            last_imports
        where
            import_type = ?
    };
    
    my $last = getDataOne($query, $dbh, [$type]);
    
    if (defined($last)) {
        return $last->{'import_time'};
    }
    return undef;
}

sub updateLastImport {
    my $type = shift;
    my $time = shift;
    my $dbh = shift;
    
    my $query = qq {
        replace into
            last_imports (
                import_type,
                import_time
            )
        values (
            ?,?
        )
    };
    
    doQuery($query, $dbh, [$type, $time]);
}

1;
