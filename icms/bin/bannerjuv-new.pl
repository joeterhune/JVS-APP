#!/usr/bin/perl -w
#

BEGIN {	
	use lib "$ENV{'PERL5LIB'}";
}

use strict;
use ICMS;
use SRS qw (
	buildSRSList
);
use Casenotes qw (
	mergeNotesAndFlags
	updateCaseNotes
	buildNotes
);
use DB_Functions qw (
	dbConnect
	getData
	getDataOne
	doQuery
);
use Banner::Reports qw (
	buildCaseList
	buildLastDocket
	buildLastActivity
	buildEvents
	buildPartyList
);
use Common qw (
	dumpVar
	inArray
	ISO_date
	getAge
	timeStamp
);
use Banner qw (
	casenumtoucn
);

my $DEBUG=0;  # will read txt files if set to 1
my $MSGS=1;   # will spit out diag msgs if set to 1

my $divPartyTypes = "'JUDG','CHLD','PET'";

# No output buffering
$| = 1;

my $outpath;
my $outpath2;
my $webpath;
my $county="Palm";
my %srsstatus; # just status of cases we're interested in
my %caselist; # set in buildcaselist

my %partylist;
#my %style;

my $reopencodes=",RO,ROCJ,RODP,";

my %flags;
my %merged;	# merged notes and flags
my $icmsdb='ok'; # status of icms database when run - 'ok' or 'bad'

my @casetypes = ('CJ','DP');
my $casetypes="('CJ','DP')";


#
# get list of child's dobs for report
#
sub builddobs {
	# Gets a listing of the DOB for all children on the case, but keeps just the DOB for the
	# first child
	my $caseRef = shift;
	my $dbh = shift;

	foreach my $casenum (keys %{$caseRef}) {
		my $query = qq {
			select
				cdrcpty_seq_no as "Sequence",
				spbpers_birth_date as "DOB"
			from
				cdrcpty,
				spbpers
			where
				cdrcpty_case_id = ?
				and cdrcpty_pidm=spbpers_pidm
				and cdrcpty_seq_no = (
					select
						min(cdrcpty_seq_no)
					from
						cdrcpty
					where
						cdrcpty_case_id = ?
						and cdrcpty_ptyp_code = 'CHLD'
				)
			order by
				cdrcpty_seq_no
		};
		my $firstDob = getDataOne($query,$dbh,[$casenum, $casenum]);
		# We only want the first one
		$caseRef->{$casenum}->{'FirstChildDOB'} = $firstDob->{'DOB'}; 
    }
}

my $surcnt = 0;
my $totcnt = 0;


sub report {
	my $caseRef = shift;
	
    if ($DEBUG) {
        print "DEBUG: Building report files\n";
    }
	
	print "Doing database stuff.\n";
	
	my $crdbh = dbConnect("case_reports");
	
	# Turn off AutoCommit
	$crdbh->{'AutoCommit'} = 0;
	
	my $query = qq {drop table if exists `juvenile_cases_new` };
	
	doQuery($query,$crdbh);
	
	$query = qq {
		CREATE TABLE `juvenile_cases_new` (
			`CaseNumber` char(20) NOT NULL,
			`CaseStyle` text NOT NULL,
			`DivisionID` char(6) NOT NULL,
			`FirstDOB` date DEFAULT NULL,
			`FileDate` date NOT NULL,
			`CaseAge` int(11) NOT NULL,
			`CourtType` char(6) NOT NULL,
			`CaseType` char(6) NOT NULL,
			`CaseStatus` char(20) NOT NULL,
			`ChargeCount` tinyint(3) unsigned DEFAULT '0',
			`LastActivity` date DEFAULT NULL,
			`EventCode` char(20) DEFAULT NULL,
			`FarthestEvent` date DEFAULT NULL,
			`OutstandingWarrants` tinyint(3) unsigned DEFAULT '0',
			`FlagsAndNotes` text DEFAULT NULL,
			PRIMARY KEY (`CaseNumber`),
			KEY `juv_file_date_idx` (`FileDate`) USING BTREE,
			KEY `juv_case_age_idx` (`CaseAge`) USING BTREE,
			KEY `juv_event_idx` (`LastActivity`,`EventCode`) USING BTREE,
			KEY `juv_case_nbr_idx` (`CaseNumber`) USING HASH,
			KEY `juv_div_idx` (`DivisionID`) USING HASH,
			KEY `juv_court_type_idx` (`CourtType`) USING HASH,
			KEY `juv_case_type_idx` (`CaseType`) USING HASH,
			KEY `juv_case_status_idx` (`CaseStatus`) USING HASH
		)
	};
	
	doQuery($query,$crdbh);
	my $count = 0;
	foreach my $casenum (keys %{$caseRef}) {
		
		$caseRef->{$casenum}->{'CaseAge'} = getAge($caseRef->{$casenum}->{'FileDate'});
		my $evcode = undef;
		my $evdate = undef;
		if (defined($caseRef->{$casenum}->{'LastEvent'})) {
			$evcode = $caseRef->{$casenum}->{'LastEvent'}->{'EventCode'};
			$evdate = ISO_date($caseRef->{$casenum}->{'LastEvent'}->{'EventDate'});
		}
		my $ladate = undef;
		if (defined($caseRef->{$casenum}->{'LastActivityDate'})) {
			$ladate = ISO_date($caseRef->{$casenum}->{'LastActivityDate'});
		}
		
		my $ucn=casenumtoucn($caselist{$casenum}->{'CaseNumber'});
		
		my @vals = ($ucn, $caseRef->{$casenum}->{'CaseStyle'},
					$caseRef->{$casenum}->{'DivisionID'},
					ISO_date($caseRef->{$casenum}->{'FileDate'}),
					$caseRef->{$casenum}->{'CaseAge'},
					$caseRef->{$casenum}->{'CourtType'},
					$caseRef->{$casenum}->{'CaseType'},
					$caseRef->{$casenum}->{'CaseStatus'},
					$caseRef->{$casenum}->{'ChargeCount'},
					$ladate,
					ISO_date($caseRef->{$casenum}->{'FirstChildDOB'}),
					$evcode, $evdate,$caseRef->{$casenum}->{'OutstandingWarrants'},
					$caseRef->{$casenum}->{'FlagsAndNotes'}
					);
		
		$query = qq {
			insert into
				juvenile_cases_new
				(
					CaseNumber,
					CaseStyle,
					DivisionID,
					FileDate,
					CaseAge,
					CourtType,
					CaseType,
					CaseStatus,
					ChargeCount,
					LastActivity,
					FirstDOB,
					EventCode,
					FarthestEvent,
					OutstandingWarrants,
					FlagsAndNotes
				)
			values
				(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
		};
		
		doQuery($query,$crdbh,\@vals);
		$count++;
		if (!($count % 1000)) {
			print "Entered $count cases...\n";
		}
		
	}
	
	$crdbh->do("drop table if exists juvenile_cases");
	$crdbh->do("rename table juvenile_cases_new to juvenile_cases");
	$crdbh->do("Commit");
	$crdbh->disconnect();
}


sub buildWarrants {
	my $caseRef = shift;
    my $dbh = shift;
	
	my $query = qq {
		select
			distinct (cobdreq_case_id) as "CaseNumber"
		from
			cobdreq,
			cdbcase
		where
			cobdreq_case_id = cdbcase_id
			and cobdreq_evnt_code = 'JPU'
			and cdbcase_cort_code = 'CJ'
			and not exists (
				select
					'X'
				from
					cobdtra
				where
					cobdtra_dreq_id = cobdreq_id
			)
	};
	
	# get all warrants
	my %rawwarrants;
	getData(\%rawwarrants,$query,$dbh,{hashkey => "CaseNumber", flatten => 1});
	
	my $count = 0;
	foreach my $casenum (keys %rawwarrants) {
		if(defined $caseRef->{$casenum} ) {
			$caseRef->{$casenum}->{'OutstandingWarrants'} = 1;
			$count++;
		}
	}
	return $count;
}

sub buildCharges {
	my $caseRef = shift;
	my $dbh = shift;
	
	my $query = qq {
		select
			cdrccpt_case_id as "CaseNumber"
		from
			cdrccpt,
			cdbcase
		where
			cdrccpt_case_id=cdbcase_id
			and cdrccpt_maint_code is null
			and cdbcase_cort_code in ('CJ')
	};
	
	my %rawcharges;
	
	getData(\%rawcharges,$query,$dbh,{hashkey => "CaseNumber"});
	
	my $count = 0;
	foreach my $casenum (keys %rawcharges) {
		if (defined ($caseRef->{$casenum})) {
			$caseRef->{$casenum}->{'ChargeCount'} = scalar(@{$rawcharges{$casenum}});
			$count++;
		}
	}
	return $count;
}


#
# buildStyles  fills the %style hash with a text style for each case.
sub buildStyles {
	my $caseRef = shift;
	my $partyRef = shift;
	my $outPath = shift;
	
	my %styles;
	
	foreach my $casenum (keys %{$caseRef}) {
		$caseRef->{$casenum}->{'CaseAge'} = getAge($caseRef->{$casenum}->{'FileDate'});
		$caseRef->{$casenum}->{'CaseStyle'} = makeStyle($partyRef,$casenum);
		
		$styles{$casenum} = sprintf("%s~%s~%d", $caseRef->{$casenum}->{'CaseStyle'},
									$caseRef->{$casenum}->{'DivisionID'},
									$caseRef->{$casenum}->{'CaseAge'});
	}
	writehash("$outPath/styles.txt",\%styles);
}




# makeStyle    makes a case style of the form "x v. y" where x and y are the
#               first plaintiff/defendant, petitioner/respondent, etc.
#               listed for a case.
sub makeStyle {
	my $partyRef = shift;
	my $casenum = shift;
	
    my($case_id,$i,$typ,$last,$first,$middle,$name,$fullname,$key,$etal,$x);
	
    if (scalar keys %{$partyRef} == 0) {
		die "bannerciv.pl: makeastyle: partylist is empty.";
    }
	
	my %ptype;
	
	foreach my $i (1..30) {  # 30 parties max
		my $key="$casenum;$i";
		if (!defined $partyRef->{$key}) {
			next;
		}
		
		($typ,$last,$first,$middle)=(split '~',$partyRef->{$key})[2..5];
		
		if (!defined $middle) {
			$middle="";
		}
		
		if (!defined $first) {
			$first="";
		}
		
		if (!defined $last) {
			$last="";
		}
		
		$middle=trim($middle);
		$last=trim($last);
		$first=trim($first);
		$name="$last";
		$fullname="$last";
		
		if(length($first) > 0) {
			$fullname="$last, $first $middle";
		}
		
		if ($typ=~/DECD/) {
			return "Estate of $last, $first $middle";
		} elsif ($typ=~/WARD/) {
			return "Guardianship of $last, $first $middle";
		} elsif ($typ=~/^AI/) {
			return "Incapacity of $last, $first $middle";
		} elsif (!defined $ptype{$typ}) {
			$ptype{$typ}=$fullname;
		} else {
			if (!($ptype{$typ}=~/, et al./)) {
				$ptype{$typ}.=", et al.";
			}
		}
	}
	
	if (defined $ptype{'PLT'} and defined $ptype{'DFT'}) {
		return "$ptype{'PLT'} v. $ptype{'DFT'}";
	} elsif (defined $ptype{'CPLT'} and defined $ptype{'DFT'}) {
		return "$fullname"; # traffic cases
	} elsif (defined $ptype{'PET'} and defined $ptype{'RESP'}) {
		return "$ptype{'PET'} v. $ptype{'RESP'}";
	} else {
		return join " ",sort values %ptype;
	}
}


sub doit() {
    if($MSGS) {
		print "starting juvenile reports bannerjuv ".timeStamp()."\n";
    }
	
    if (@ARGV==1 and $ARGV[0] eq "DEBUG") {
		$DEBUG=1;
		print "DEBUG!\n";
    }
    $outpath="/var/www/html/case/$county/juv";
    $webpath="/case/$county/juv";
    
	my $ndbh = dbConnect("wpb-banner-rpt");
    
    if($MSGS) {
		print "starting buildSRSList ".timeStamp()."\n";
    }
	
	buildSRSList(\%srsstatus,$outpath,$casetypes,$ndbh);
    
    
    if($MSGS) {
		print "starting buildCaseList ".timeStamp()."\n";
    }
	
	buildCaseList(\%caselist,$casetypes,\%srsstatus,$outpath,$ndbh);
    
    updateCaseNotes(\%caselist,\@casetypes);
	
	my @justcases = keys(%caselist);
    
    if($MSGS) {
		print "starting buildWarrants ".timeStamp()."\n";
    }
    
    buildWarrants(\%caselist,$ndbh);
    
    if($MSGS) {
		print "starting buildCharges ".timeStamp()."\n";
    }
    buildCharges(\%caselist,$ndbh);
    
    if($MSGS) {
		print "starting buildLastDocket ".timeStamp()."\n";
    }
    buildLastDocket(\%caselist,$casetypes,$ndbh);
    
    if($MSGS) {
		print "starting buildLastActivity ".timeStamp()."\n";
    }
    buildLastActivity(\%caselist,$casetypes,$ndbh);
    
    if($MSGS) {
		print "starting buildEvents ".timeStamp()."\n";
    }
    buildEvents(\%caselist,$casetypes,$ndbh);
    
    if($MSGS) {
		print "starting buildNotes ".timeStamp()."\n";
    }
	buildNotes(\%caselist,$casetypes);
    #buildnotes(\%merged, \%flags, $casetypes, $outpath, $DEBUG);
    
    if($MSGS) {
		print "starting buildpartylist ".timeStamp()."\n";
    }
	buildPartyList(\%partylist,$outpath,\@justcases,$ndbh);
	
#	if($MSGS) {
#        print "starting buildStyles ".timeStamp()."\n";
#    }
#    buildStyles(\%caselist,\%partylist,$outpath);
        
    if($MSGS) {
		print "starting builddobs ".timeStamp()."\n";
	}
    builddobs(\%caselist,$ndbh);
    
    if($MSGS) {
		print "starting report ".timeStamp()."\n";
    }
    report(\%caselist);
    
    if($MSGS) {
		print "finished juvenile reports bannerjuv ".timeStamp()."\n";
    }
}

$::SIG{'__WARN__'} = sub {
	my $warning = shift;
	if ( $warning =~ m{\s at \s \S+ \s line \s \d+ \. $}xms ) {
		$DB::single = 1;    # debugger stops here automatically
    }
    warn $warning;
};


#
# MAIN PROGRAM STARTS HERE!
#

doit();
