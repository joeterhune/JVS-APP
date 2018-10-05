package Showcase::Reports;
use strict;
use warnings;

use Date::Calc qw(:all Month_to_Text);

use ICMS;

use DB_Functions qw (
	getData
    getDbSchema
	dbConnect
	getDataOne
	doQuery
);

use Common qw (
	inArray
	dumpVar
	getAge
	timeStamp
	getArrayPieces
	getShowcaseDb
);

use Showcase qw (
	lookupMailingAddress
);

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT_OK = qw(
	buildCaseList
	buildLastDocket
	buildLastActivity
	buildEvents
	buildPartyList
);

my $dbName = getShowcaseDb();
my $schema = getDbSchema($dbName);
my $dbh = dbConnect($dbName);

my $DEBUG = 0;

my($evy,$evm,$evd)=Add_Delta_Days((Today()),-10);
my $EVTDATE=sprintf("%04d-%02d-%02d",$evy,$evm,$evd);

sub buildPartyList {
	my $partylist = shift;
	my $outpath = shift;
	my $justcases = shift;
    my $ndbh = shift;
	my $caseRef = shift;
    
    if (!defined($ndbh)) {
		return;
    }

    my(%thisparties,%nocaseparties,$query);
	
	print "getting rawparties - query started at ".timeStamp()." \n";
	
	my $casecount = scalar(@{$justcases});
	print "Starting to get parties.  There are $casecount cases...\n";
		
	my $count = 0;
	my $perquery = 1000;
		
	# Keep a listing of addresses, so we don't look up the same address
	# multiple times
	my %addresses;	
		
	while ($count <= scalar(@{$justcases})) {
		my @temp;
		getArrayPieces($justcases, $count, $perquery, \@temp,1);
		
		my %rawparties;
		getAllParties(\%rawparties,$ndbh,\@temp);
		
		foreach my $p (keys %rawparties) {
			my $seq = 1;
			# $p is a reference to all parties on the case
			foreach my $party (keys (%{$rawparties{$p}})) {
				my $thisParty = $rawparties{$p}->{$party};
				my $pidm = $thisParty->{'PartyID'};
				#if (!exists($addresses{$party})) {
				#	lookupMailingAddress(\%addresses,$pidm,$ndbh,undef,$party);
				#	if (!defined($addresses{$party})) {
				#		$addresses{$party} = {};
				#		$addresses{$party}->{'StreetAddress'} = '';
				#		$addresses{$party}->{'City'} = '';
				#		$addresses{$party}->{'State'} = '';
				#		$addresses{$party}->{'Zip'} = '';
				#	}
				#}
				#$thisParty->{'StreetAddress'} = $addresses{$party}->{'Address1'};
				#if(defined($addresses{$party}->{'Address2'})){
				#	$thisParty->{'StreetAddress'} .= " " . $addresses{$party}->{'Address2'};
				#}
				#$thisParty->{'City'} = $addresses{$party}->{'City'};
				#$thisParty->{'State'} = $addresses{$party}->{'State'};
				#$thisParty->{'Zip'} = $addresses{$party}->{'Zip'};
				#$thisParty->{'AddrDate'} = '';
				#$thisParty->{'AreaCode'} = $addresses{$party}->{'AreaCode'};
				#$thisParty->{'PhoneNumber'} = $addresses{$party}->{'PhoneNumber'};
				#
				#my $partyRec = sprintf("%s~%s~%s~%s~%s~%s~%s~%s~%s~%s~%s~%s~%s~%s~%s",
				#					   $thisParty->{'CaseNumber'},
				#					   $seq,
				#					   $thisParty->{'PartyType'},
				#					   $thisParty->{'LastName'},
				#					   ((defined($thisParty->{'FirstName'})) ? $thisParty->{'FirstName'} : ''),
				#					   ((defined($thisParty->{'MiddleName'})) ? $thisParty->{'MiddleName'} : ''),
				#					   $thisParty->{'PartyID'},
				#					   ((defined($thisParty->{'AssocWith'})) ? $thisParty->{'AssocWith'} : ''),
				#					   ((defined($thisParty->{'StreetAddress'})) ? $thisParty->{'StreetAddress'} : ''),
				#					   ((defined($thisParty->{'City'})) ? $thisParty->{'City'} : ''),
				#					   ((defined($thisParty->{'State'})) ? $thisParty->{'State'} : ''),
				#					   ((defined($thisParty->{'Zip'})) ? $thisParty->{'Zip'} : ''),
				#					   ((defined($thisParty->{'AddrDate'})) ? $thisParty->{'AddrDate'} : '1970-01-01'),
				#					   ((defined($thisParty->{'AreaCode'})) ? $thisParty->{'AreaCode'} : ''),
				#					   ((defined($thisParty->{'PhoneNumber'})) ? $thisParty->{'PhoneNumber'} : '')
				#);
				
				my $partyRec = sprintf("%s~%s~%s~%s~%s~%s~%s~%s~%s",
									   $thisParty->{'CaseNumber'},
									   $seq,
									   $thisParty->{'PartyType'},
									   $thisParty->{'LastName'},
									   ((defined($thisParty->{'FirstName'})) ? $thisParty->{'FirstName'} : ''),
									   ((defined($thisParty->{'MiddleName'})) ? $thisParty->{'MiddleName'} : ''),
									   $thisParty->{'PartyID'},
									   ((defined($thisParty->{'AssocWith'})) ? $thisParty->{'AssocWith'} : ''),
									   $thisParty->{'PartyTypeDescription'}
				);
					
				my $key = sprintf("%s;%s", $thisParty->{'CaseNumber'}, $seq);
				$partylist->{$key}=$partyRec;
				if (defined($caseRef) && (defined($caseRef->{$thisParty->{'CaseNumber'}}))) {
					# The case list was passed in as an argument - newer code.  Attach the parties to the case, in an
					# array of hash refs
					if (!defined($caseRef->{$thisParty->{'CaseNumber'}}->{'Parties'})) {
						$caseRef->{$thisParty->{'CaseNumber'}}->{'Parties'} = [];
					}
					push(@{$caseRef->{$thisParty->{'CaseNumber'}}->{'Parties'}}, $thisParty);
				}
				
				$seq++;
			}
		}
		
		$count += $perquery;
	}
	
    print "done processing all cases in caselist.  built partylist hash ".timeStamp()."\n";
    my $s=keys %{$partylist};
    print "size of partylist is $s \n";
    
    writehash("$outpath/partylist.txt",$partylist);
}


sub getAllParties {
    my $partyRef = shift;
    my $dbh = shift;
    my $caselist = shift;
    
    my $inString = join(",", @{$caselist});
    
    # get the parties for this case and save
    my $query = qq {
        SELECT
            c.CaseNumber,
            p.PartyType,
            p.LastName,
            p.FirstName,
            p.MiddleName,
            p.PersonID as PartyID,
            p.Discharged,
            p.Active,
            a.BarNumber as AssocWith,
            CONVERT(varchar(10),p.DOB,101) as DOB,
			p.PhoneNo AS PhoneNumber,
			CASE
               WHEN p.PartyTypeDescription = 'PLAINTIFF/PETITIONER'
                  THEN 1
               WHEN p.PartyType = 'PLT'
                  THEN 1
               WHEN p.PartyType = 'PET'
                  THEN 1
               WHEN p.PartyType = 'CHILD'
                  THEN 1
               WHEN p.PartyType = 'CHLD'
                  THEN 1
               WHEN p.PartyType = 'FTH'
                  THEN 2
               WHEN p.PartyType = 'FATHER'
                  THEN 2
               WHEN p.PartyTypeDescription = 'DEFENDANT/RESPONDENT'
                  THEN 2
               WHEN p.PartyType = 'DFT'
                  THEN 2   
               WHEN p.PartyType = 'RESP'
                  THEN 2
               WHEN p.PartyType = 'MTH'
                  THEN 3
               WHEN p.PartyType = 'MOTHER'
                  THEN 3
               ELSE 4
            END as PartyOrder,
            p.PartyTypeDescription
        FROM
            $schema.vAllParties p
        INNER JOIN $schema.vCase c
			ON p.CaseID = c.CaseID
        LEFT OUTER JOIN $schema.vAttorney a
            ON p.CaseID = a.CaseID
            AND p.PartyType = a.Represented_PartyType  
            AND p.PersonID = a.Represented_PersonID
        WHERE
            c.CaseNumber in ($inString)
            AND p.PartyType NOT IN ('JUDG')
		ORDER BY PartyOrder
    };
	
	my %allParties;
	getData(\%allParties,$query,$dbh,{hashkey => "CaseNumber"});
	
	foreach my $case (keys %allParties) {
		my $caseparties = $allParties{$case};
		# Create a hash ref for the case, which will be populated with
		# parties, keyed on the party ID
		$partyRef->{$case} = {};
        
		foreach my $party (@{$caseparties}) {
            if ($party->{'Active'} eq 'No' || (defined($party->{'Discharged'}) && ($party->{'Discharged'} eq '1'))) {
                # Don't add inactive attorneys
                next if ($party->{'PartyType'} eq "ATTY");
            }
            
			my $partyid = $party->{'PartyID'};
			$partyRef->{$case}->{$partyid} = $party;
		}
	}
}


sub buildCaseList {
	my $caseRef = shift;
	my $casetypes = shift;
	my $srsRef = shift;
	my $outpath = shift;
	my $dbh = shift;
	
	print "Building Case List\n";
	
	my $query = qq {
		select
			CaseNumber,
			CaseStyle,
			DivisionID,
			CourtType,
			CONVERT(varchar,FileDate,101) as FileDate,
			CaseType
		from
			$schema.vCase
		where
			CourtType in $casetypes
			AND Sealed = 'N'
	};
	
	my %rawcase;
	getData(\%rawcase,$query,$dbh,{hashkey => "CaseNumber", flatten => 1});
	
	my %t;
	foreach my $casenum (keys %rawcase) {
		if(defined $srsRef->{$casenum}) {
			$rawcase{$casenum}->{'CaseStatus'} = $srsRef->{$casenum};
			$t{$casenum}=$rawcase{$casenum};
			
		}
	}
	
	%rawcase = %t;
	
	my $nodiv = 0;
	
	open(NODIV_FILE,">$outpath/nodiv_cases.txt") ||
		warn ("Couldn't create '$outpath/nodiv_cases.txt': $!\n\n");
		
	foreach my $casenum (sort keys %{$srsRef}) {
		next if (!defined($rawcase{$casenum}));
		if ((!defined ($rawcase{$casenum}->{'DivisionID'})) ||
			($rawcase{$casenum}->{'DivisionID'} eq "")) {
			$nodiv++;
			print NODIV_FILE "$casenum\n";
			next;
		}
		$caseRef->{$casenum} = $rawcase{$casenum};
	}
	print "$nodiv Cases with No Division!\n";
	close NODIV_FILE;
}


sub buildLastDocket {
	my $caseRef = shift;
	my $casetypes = shift;
	my $dbh = shift;
	
	my $query = qq {
		select
			c.CaseNumber,
			a.EffectiveDate as FilingDate,
			a.DocketCode as DocketType
		FROM
			$schema.vDocket a
            INNER JOIN $schema.vCase b
                ON b.CaseID = a.CaseID
		WHERE
			CourtType in $casetypes
			AND EffectiveDate =(
				SELECT
					MAX(c.EffectiveDate)
				from
					$schema.vDocket c
				WHERE
					c.CaseID = a.CaseID
			)
	};
	
	my %rawlastdocket;
	getData(\%rawlastdocket,$query,$dbh,{hashkey => "CaseNumber", flatten => 1});
	
	foreach my $casenum (keys %rawlastdocket) {
		if (defined ($caseRef->{$casenum})) {
			$caseRef->{$casenum}->{'LastDocket'} = $rawlastdocket{$casenum};
		}
	}
}


# Now, uses cdrdoct_filing_date rather than cdrdoct_activity_date as the last activity date.
sub buildLastActivity {
	my $caseRef = shift;
	my $casetypes = shift;
	my $dbh = shift;
	
	my $query = qq {
		select
			c.CaseNumber,
			a.EffectiveDate as FileDate
		FROM
			$schema.vDocket a
            INNER JOIN $schema.vCase b
                ON b.CaseID = a.CaseID
		WHERE
			CourtType in $casetypes
			AND EffectiveDate =(
				SELECT
					MAX(c.EffectiveDate)
				from
					$schema.vDocket c
				WHERE
					c.CaseID = a.CaseID
			)
	};
	
    my %rawlastactivity;
	getData(\%rawlastactivity,$query,$dbh,{hashkey => "CaseNumber", flatten => 1});
	
	foreach my $casenum (keys %rawlastactivity) {
		if (defined ($caseRef->{$casenum})) {
	         $caseRef->{$casenum}->{'LastActivityDate'} = $rawlastactivity{$casenum}->{'FileDate'};
		}
	}
}


sub buildEvents {
	my $caseRef = shift;
	my $casetypes = shift;
    my $dbh = shift;
    
	my $query = qq {
		SELECT
			c.CaseNumber,
			a.CourtEventCode as EventCode,
			a.CourtEventDate as EventDate
		from
			$schema.vCourtEvent a
            INNER JOIN $schema.vCase c
            ON c.CaseID = e.CaseID
		where
			a.CourtEventDate >= to_date(?,'YYYY-MM-DD')
			and CourtType in $casetypes
			and a.CourtEventDate=(
				select
					max(c.CourtEventDate)
				from
					$schema.vCourtEvent c
				where
					c.CaseID = a.CaseID
			)
		order by
			c.CaseNumber
	};
	
	my %events;
	getData(\%events,$query,$dbh,{valref => [$EVTDATE], hashkey => "CaseNumber", flatten => 1});
	
	foreach my $casenum (keys %{$caseRef}) {
		if (defined($events{$casenum})) {
			$caseRef->{$casenum}->{'LastEvent'} = $events{$casenum};
		}
	}
}


1;
