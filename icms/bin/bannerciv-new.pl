#!/usr/bin/perl
#
# bannerciv.pl - Banner Civil (and Family?)

use strict;

use ICMS;
use SRS qw (
	buildSRSList
);

use Casenotes qw (
    mergeNotesAndFlags
    updateCaseNotes
	buildnotes
);
use Common qw(
    inArray
    dumpVar
    getArrayPieces
	timeStamp
	@dorPIDMs
	getAge
	ISO_date
);
use DB_Functions qw (
    dbConnect
    getData
	doQuery
);
use Banner::Reports qw (
	buildCaseList
	buildLastDocket
	buildLastActivity
	buildEvents
	buildPartyList
);
use Banner qw (
	casenumtoucn
);
use XML::Simple;

my $DEBUG=0;  # will read txt files if set to 1
my $MSGS=1;   # will spit out diag msgs if set to 1

# No output buffering
$| = 1;

my $outpath;
my $outpath2;
my $webpath;
my $county="Palm";
#my %allsrs;    # contains all cases for this report with the corresponding srs status
my %srsstatus; # just status of cases we're interested in
my %caselist; # set in buildcaselist
my %partylist;

my %merged;	# merged notes and flags
my %flags;

my @casetypes = ('CA','CC','SC','DR','RS','RD','DA','DU');
my $casetypes="('CA','CC','SC','DR','RS','RD','DA','DU')";  # note that Juvenile are not in here


#
# makeStyle    makes a case style of the form "x v. y" where x and y are the
#               first plaintiff/defendant, petitioner/respondent, etc.
#               listed for a case.
sub makeStyle {
	my $partyRef = shift;
	my $case_id = shift;
	
    #my($typ,$last,$first,$middle,$name,$fullname,$key,$etal,%ptype,$x);
	
	if (scalar keys %partylist==0) {
		die "bannerciv.pl: makeStyle: partylist is empty.";
    }
    
	my %ptype;
	my $key;
	my $name;
	my $fullname;
    foreach my $i (1..30) {
		# 30 parties max
		$key="$case_id;$i";
		if (!defined $partyRef->{$key}) {
			next;
		}
		
		my ($typ,$last,$first,$middle)=(split '~',$partyRef->{$key})[2..5];
		
		if (!defined $middle) {
			$middle=""
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


sub buildUFC {
	my $caseRef = shift;
	my $dbh = shift;
	
	my %ufc;
	
	my $query = qq {
		select
			cdrdoct_case_id as "CaseNumber",
			cdrdoct_dtyp_code as "DocketCode"
		from
			cdrdoct,
			cdbcase
		where
			cdrdoct_case_id=cdbcase_id
			and cdbcase_cort_code = 'DR'
			and cdrdoct_dtyp_code in ('UFCL','UFCT','UFJM')
		};
		
	getData(\%ufc,$query,$dbh,{hashkey => "CaseNumber"});
	foreach my $casenumber (keys (%ufc)) {
		next if (!defined($caseRef->{$casenumber}));
		
		foreach my $docket (@{$ufc{$casenumber}}) {
			$caseRef->{$casenumber}->{$docket->{'DocketCode'}} = 1;
		}
	}
}

# Find and save the DOR case info
sub buildDOR {
	my $caseRef = shift;
	my $dorPIDMs = shift;
	my $dbh = shift;
	
	my $dorString = join(",", @{$dorPIDMs});
	
	my $query = qq {
		select
			cdbcase_id as "CaseNumber"
		from
			cdrcpty,
			cdbcase
		where
			cdrcpty_pidm in ($dorString)
			and cdrcpty_end_date is null
			and cdrcpty_case_id = cdbcase_id
			and cdbcase_cort_code in ('DA','DR')
	};
	my %rawdor_cases;
	
	getData(\%rawdor_cases,$query,$dbh,{hashkey => "CaseNumber", flatten => 1});
	
	foreach my $casenum (keys %rawdor_cases) {
		if( defined $caseRef->{$casenum} ) {
			$caseRef->{$casenum}->{'DOR'} = 1;
		}
	}
}

sub report {
	my $caseRef = shift;
	
    if ($DEBUG) {
        print "DEBUG: Building report files\n";
    }
	
	print "Doing database stuff.\n";
	
	my $crdbh = dbConnect("case_reports");
	
	# Turn off AutoCommit
	$crdbh->{'AutoCommit'} = 0;
	
	my $query = qq {drop table if exists `civil_cases_new` };
	
	doQuery($query,$crdbh);
	
	$query = qq {
		CREATE TABLE `civil_cases_new` (
			`CaseNumber` char(20) NOT NULL,
			`CaseStyle` text NOT NULL,
			`DivisionID` char(6) NOT NULL,
			`FileDate` date NOT NULL,
			`CaseAge` int(11) NOT NULL,
			`CourtType` char(6) NOT NULL,
			`CaseType` char(6) NOT NULL,
			`CaseStatus` char(20) NOT NULL,
			`LastActivity` date DEFAULT NULL,
			`EventCode` char(20) DEFAULT NULL,
			`FarthestEvent` date DEFAULT NULL,
			`IsDOR` tinyint(3) unsigned DEFAULT 0,
			`IsUFCL` tinyint(3) unsigned DEFAULT 0,
			`IsUFCT` tinyint(3) unsigned DEFAULT 0,
			`IsUFJM` tinyint(3) unsigned DEFAULT 0,
			PRIMARY KEY (`CaseNumber`),
			KEY `civ_file_date_idx` (`FileDate`) USING BTREE,
			KEY `civ_case_age_idx` (`CaseAge`) USING BTREE,
			KEY `civ_event_idx` (`LastActivity`,`EventCode`) USING BTREE,
			KEY `civ_case_nbr_idx` (`CaseNumber`) USING HASH,
			KEY `civ_div_idx` (`DivisionID`) USING HASH,
			KEY `civ_court_type_idx` (`CourtType`) USING HASH,
			KEY `civ_case_type_idx` (`CaseType`) USING HASH,
			KEY `civ_case_status_idx` (`CaseStatus`) USING HASH,
			KEY `civ_dor_idx` (`IsDOR`) USING HASH,
			KEY `civ_ufcl_idx` (`IsUFCL`) USING HASH,
			KEY `civ_ufct_idx` (`IsUFCT`) USING HASH,
			KEY `civ_ufjm_idx` (`IsUFJM`) USING HASH
		)
	};
	
	doQuery($query,$crdbh);
	my $count = 0;
	foreach my $casenum (keys %{$caseRef}) {
		if (!defined($caseRef->{$casenum}->{'CaseNumber'})) {
			print "Skipping $casenum\n";
			next;
		}
		
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
		
		my $ucn=casenumtoucn($caseRef->{$casenum}->{'CaseNumber'});
		next if (!defined($ucn));
		
		my @vals = ($ucn,
					$caseRef->{$casenum}->{'CaseStyle'},
					$caseRef->{$casenum}->{'DivisionID'},
					ISO_date($caseRef->{$casenum}->{'FileDate'}),
					$caseRef->{$casenum}->{'CaseAge'},
					$caseRef->{$casenum}->{'CourtType'},
					$caseRef->{$casenum}->{'CaseType'},
					$caseRef->{$casenum}->{'CaseStatus'},
					$ladate,
					$evcode,
					$evdate,
					$caseRef->{$casenum}->{'DOR'},
					$caseRef->{$casenum}->{'UFCL'},
					$caseRef->{$casenum}->{'UFCT'},
					$caseRef->{$casenum}->{'UFJM'}
					);
		
		$query = qq {
			insert into
				civil_cases_new
				(
					CaseNumber,
					CaseStyle,
					DivisionID,
					FileDate,
					CaseAge,
					CourtType,
					CaseType,
					CaseStatus,
					LastActivity,
					EventCode,
					FarthestEvent,
					IsDOR,
					IsUFCL,
					IsUFCT,
					IsUFJM
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
	
	$crdbh->do("drop table if exists civil_cases");
	$crdbh->do("rename table civil_cases_new to civil_cases");
	$crdbh->do("Commit");
	$crdbh->disconnect();
}



sub doit() {
    if($MSGS) {
		print "starting civil reports bannerciv ".timeStamp()."\n";
    }

    if (@ARGV==1 and $ARGV[0] eq "DEBUG") {
		$DEBUG=1;
		print "DEBUG!\n";
    }
    $outpath="/var/www/html/case/$county/civ";
    $webpath="/case/$county/civ";
    
	my $ndbh = dbConnect("wpb-banner-rpt");
	
	if($MSGS) {
		print "starting buildSRSList ".timeStamp()."\n";
    }
    buildSRSList(\%srsstatus,$outpath,$casetypes,$ndbh);
	
    if($MSGS) {
		print "starting buildCaseList ".timeStamp()."\n";
    }
	buildCaseList(\%caselist,$casetypes,\%srsstatus,$outpath,$ndbh);
    
	if($MSGS) {
		print "starting updateCaseNotes ".timeStamp()."\n";
    }
    updateCaseNotes(\%caselist,\@casetypes);
    
    my @justcases = keys(%caselist);
    
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
		print "starting buildnotes ".timeStamp()."\n";
    }
	buildnotes(\%merged, \%flags, $casetypes, $outpath, $DEBUG);
    
	if($MSGS) {
		print "starting buildUFC ".timeStamp()."\n";
    }
    buildUFC(\%caselist,$ndbh);
    
    if($MSGS) {
		print "starting buildPartyList ".timeStamp()."\n";
    }
	buildPartyList(\%partylist, $outpath, \@justcases, $ndbh);
	
	if($MSGS) {
		print "starting buildDOR ".timeStamp()."\n";
    }
	buildDOR(\%caselist, @dorPIDMs, $ndbh);
	
	if($MSGS) {
        print "starting buildStyles ".timeStamp()."\n";
    }
    buildStyles(\%caselist,\%partylist,$outpath);
	
	#xmlRead(\%caselist);
	xmlDump(\%caselist);
	
    if($MSGS) {
		print "starting report ".timeStamp()."\n";
    }
    report(\%caselist);
	
    if($MSGS) {
		print "all done with civil reports bannerciv ".timeStamp()."\n";
    }
}


sub xmlDump {
	my $caseRef = shift;
	
	my %copy;
	foreach my $key (keys %{$caseRef}) {
		# Need to do this because a casenumber - beginning with a digit - isn't a valid
		# XML member key
		my $XMLKey = "case-$key";
		$copy{$XMLKey} = $caseRef->{$key};
	}
	
	my $path = "/var/www/Palm/civ/civ.xml";
	
	print "Dumping data to $path...\n\n";
	
	my $xs = XML::Simple->new();
	open my $fh, '>:encoding(iso-8859-1)', $path ||
		die "open($path): $!";
	my $xml = $xs->XMLout(\%copy, OutputFile => $fh);
	close $fh;
	
	print "Done!!\n";
}

sub xmlRead {
	my $caseRef = shift;
	
	my $path = "/var/www/Palm/civ/civ.xml";
	
	print "Reading stored data from $path...\n";
	
	my $copy = {};
	
	my $xs = XML::Simple->new();
	$copy = $xs->XMLin($path);
	
	print "Read " . scalar(keys %{$copy}) . " values.\n\n";
	
	foreach my $key (keys %{$copy}) {
		my $casenum = $key;
		$casenum =~ s/^case-//g;
		$caseRef->{$casenum} = $copy->{$key};
	}
	return scalar(keys(%{$caseRef}));
}


#
# MAIN PROGRAM STARTS HERE!
#

doit();
