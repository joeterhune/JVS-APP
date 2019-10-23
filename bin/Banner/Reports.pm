package Banner::Reports;
use strict;
use warnings;

use Date::Calc qw(:all Month_to_Text);

use ICMS;

use DB_Functions qw (
	getData
);

use Common qw (
	inArray
	dumpVar
	getAge
	timeStamp
	getArrayPieces
);

use Banner qw (
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
			# $p is a reference to all parties on the case
			foreach my $party (keys (%{$rawparties{$p}})) {
				my $thisParty = $rawparties{$p}->{$party};
				my $pidm = $thisParty->{'PIDM'};
				if (!exists($addresses{$party})) {
					lookupMailingAddress(\%addresses,$pidm,$ndbh,undef,$party);
					if (!defined($addresses{$party})) {
						$addresses{$party} = {};
						$addresses{$party}->{'StreetAddress'} = '';
						$addresses{$party}->{'City'} = '';
						$addresses{$party}->{'State'} = '';
						$addresses{$party}->{'Zip'} = '';
					}
				}
				$thisParty->{'StreetAddress'} = $addresses{$party}->{'StreetAddress'};
				$thisParty->{'City'} = $addresses{$party}->{'City'};
				$thisParty->{'State'} = $addresses{$party}->{'State'};
				$thisParty->{'Zip'} = $addresses{$party}->{'Zip'};
				$thisParty->{'AddrDate'} = $addresses{$party}->{'AddrDate'};
				$thisParty->{'AreaCode'} = $addresses{$party}->{'AreaCode'};
				$thisParty->{'PhoneNumber'} = $addresses{$party}->{'PhoneNumber'};
				
				my $partyRec = sprintf("%s~%s~%s~%s~%s~%s~%s~%s~%s~%s~%s~%s~%s~%s~%s",
									   $thisParty->{'CaseNumber'},
									   $thisParty->{'Seq'},
									   $thisParty->{'PartyType'},
									   $thisParty->{'LastName'},
									   ((defined($thisParty->{'FirstName'})) ? $thisParty->{'FirstName'} : ''),
									   ((defined($thisParty->{'MiddleName'})) ? $thisParty->{'MiddleName'} : ''),
									   $thisParty->{'PartyID'},
									   ((defined($thisParty->{'AssocWith'})) ? $thisParty->{'AssocWith'} : ''),
									   ((defined($thisParty->{'StreetAddress'})) ? $thisParty->{'StreetAddress'} : ''),
									   ((defined($thisParty->{'City'})) ? $thisParty->{'City'} : ''),
									   ((defined($thisParty->{'State'})) ? $thisParty->{'State'} : ''),
									   ((defined($thisParty->{'Zip'})) ? $thisParty->{'Zip'} : ''),
									   ((defined($thisParty->{'AddrDate'})) ? $thisParty->{'AddrDate'} : '1970-01-01'),
									   ((defined($thisParty->{'AreaCode'})) ? $thisParty->{'AreaCode'} : ''),
									   ((defined($thisParty->{'PhoneNumber'})) ? $thisParty->{'PhoneNumber'} : '')
				);
					
				my $key = sprintf("%s;%s", $thisParty->{'CaseNumber'}, $thisParty->{'Seq'});
				$partylist->{$key}=$partyRec;
				if (defined($caseRef) && (defined($caseRef->{$thisParty->{'CaseNumber'}}))) {
					# The case list was passed in as an argument - newer code.  Attach the parties to the case, in an
					# array of hash refs
					if (!defined($caseRef->{$thisParty->{'CaseNumber'}}->{'Parties'})) {
						$caseRef->{$thisParty->{'CaseNumber'}}->{'Parties'} = [];
					}
					push(@{$caseRef->{$thisParty->{'CaseNumber'}}->{'Parties'}}, $thisParty);
				}
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
        select
            cdrcpty_case_id as "CaseNumber",
            cdrcpty_seq_no as "Seq",
            cdrcpty_ptyp_code as "PartyType",
            spriden_last_name as "LastName",
            NVL(spriden_first_name,' ') as "FirstName",
            NVL(spriden_mi,' ') as "MiddleName",
            spriden_id as "PartyID",
            cdrcpty_pidm as "PIDM",
            cdrcpty_assoc_with as "AssocWith",
            to_char(spbpers_birth_date,'MM/DD/YYYY') as "DOB",
            cdrcpty_end_date as "EndDate"
        from
            cdrcpty,
            spriden left outer join spbpers on spriden_pidm = spbpers_pidm,
            cdbcase
        where
            cdbcase_id in ($inString)
            and cdbcase_id = cdrcpty_case_id
            and cdrcpty_pidm=spriden_pidm
            and spriden_change_ind is null
            and cdrcpty_ptyp_code not in ('JUDG')
    };
	
	my %allParties;
	getData(\%allParties,$query,$dbh,{hashkey => "CaseNumber"});
	
	foreach my $case (keys %allParties) {
		my $caseparties = $allParties{$case};
		# Create a hash ref for the case, which will be populated with
		# parties, keyed on the party ID
		$partyRef->{$case} = {};
        
		foreach my $party (@{$caseparties}) {
            if (defined($party->{'EndDate'})) {
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
			cdbcase_id as "CaseNumber",
			cdbcase_desc as "CaseStyle",
			cdbcase_division_id as "DivisionID",
			cdbcase_cort_code as "CourtType",
			cdbcase_init_filing as "FileDate",
			cdbcase_ctyp_code as "CaseType"
		from
			cdbcase
		where
			cdbcase_cort_code in $casetypes
			and cdbcase_sealed_ind <> 3
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
			a.cdrdoct_case_id as "CaseNumber",
			a.cdrdoct_filing_date as "FilingDate",
			a.cdrdoct_dtyp_code as "DocketType"
		from
			cdrdoct a,
			cdbcase b
		where
			cdrdoct_case_id=cdbcase_id
			and cdbcase_cort_code in $casetypes
			and a.cdrdoct_filing_date=(
				select
					max(c.cdrdoct_filing_date)
				from
					cdrdoct c
				where
					c.cdrdoct_case_id=a.cdrdoct_case_id
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
			a.cdrdoct_case_id as "CaseNumber",
			a.cdrdoct_filing_date as "FileDate"
		from
			cdrdoct a,
			cdbcase b
		where
			cdrdoct_case_id=cdbcase_id
			and cdbcase_cort_code in $casetypes
			and a.cdrdoct_filing_date = (
				select
					max(c.cdrdoct_filing_date)
				from
					cdrdoct c
				where
					c.cdrdoct_case_id = a.cdrdoct_case_id
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
		select
			c.cdbcase_id as "CaseNumber",
			a.csrcsev_evnt_code as "EventCode",
			a.csrcsev_sched_date as "EventDate"
		from
			csrcsev a,
			cdbcase c
		where
			a.csrcsev_case_id = c.cdbcase_id
			and a.csrcsev_sched_date >= to_date(?,'YYYY-MM-DD')
			and cdbcase_cort_code in $casetypes
			and a.csrcsev_sched_date=(
				select
					max(c.csrcsev_sched_date)
				from
					csrcsev c
				where
					c.csrcsev_case_id=a.csrcsev_case_id
			)
		order by
			cdbcase_id
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
