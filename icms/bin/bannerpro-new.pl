#!/usr/bin/perl
#
# bannerpro.pl - Banner Probate

BEGIN {
    use lib "$ENV{'PERL5LIB'}";
}

use strict;
use ICMS;
use SRS qw (
	buildSRSList
);

use Common qw(
    readHash
	ISO_date
	dumpVar
	getAge
	timeStamp
);
use Casenotes qw(
    mergeNotesAndFlags
	updateCaseNotes
    buildNotes
);
use DB_Functions qw (
    dbConnect
	doQuery
	getData
	getDataOne
);
use Banner qw (
	casenumtoucn
);
use Banner::Reports qw (
	buildCaseList
	buildLastDocket
	buildLastActivity
	buildEvents
	buildPartyList
);

my $DEBUG=0;  # will read txt files if set to 1

my $divPartyTypes = "'JUDG'";

my $MSGS=1;   # will spit out diag msgs if set to 1

# No output buffering
$| = 1;

my $county="Palm";
my $outpath="/var/www/html/case/$county/pro";
my $webpath="/case/$county/pro";

my $outpath2;
my %allsrs;    # contains all cases for this report with the corresponding srs status
my %srsstatus; # just status of cases we're interested in
my %allcases; # set in buildallcases
my %caselist; # set in buildcaselist
my %divlist;  # set in buildcaselist
my %partylist;
my %style;
my %critdesc=(
	      "pend"=>"Pending Cases","nopend"=>"Other Cases","ro"=>"Reopened Cases",
	      "pendne"=>"Pending Cases with No Events Scheduled","pendwe"=>"Pending Cases with Events Scheduled",
	      "rowe"=>"Reopened Cases with Events Scheduled","rone"=>"Reopened Cases with No Events Scheduled",
	      "all"=>"All Cases",
	      "cp"=>"Probate Cases","cpfo"=>"Formal Admin","cpsa"=>"Summary Admin GT \$1000","cpse"=>"Small Estate","cpsp"=>"Summary Admin < \$1000",
	      "ga"=>"Guardianship Cases","gain"=>"Guardianship - Incapacitation",
	      "mh"=>"Mental Health Cases","mhba"=>"Mental Health - Baker Act","mhic"=>"Mental Health - Incapacity",
	      "mhma"=>"Mental Health - Marchman Act",
	      "wo"=>"Will Only Cases"
	      );

my %lastdocket; # set in buildlastdocket
my %lastactivity; # set in buildlastactivity
my %reopened; # set in buildcaselist

my $reopencodes=",RO,RE,";
my %events;
my %flags;
my %merged;	# merged notes and flags
my $icmsdb='ok'; # status of icms database when run - 'ok' or 'bad'

#GA (guardianship), CP (estate [Circuit Probate]), and MH (Mental Health)
#(Will Only is cort code CP with case type WO)
my @casetypes = ('GA','CP','MH');
my $casetypes="('GA','CP','MH')";
my $dtypcodes="('PE','RO','RE')";  # these are the only status's pulled in this report

# had to add APLE because of two cases...
my $inptypes="('ATTY','AINC','DECD','DFT','INCP','INRE','MIN','PAT','PET','PLT','RESP','WARD', 'APLE')";

# probate always has a JUDG ?
my $ptypes="('JUDG')";


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


#
# makeastyle    makes a case style of last name, first name, mi
#
sub makeStyle {
	my $partyRef = shift;
	my $case_id = shift;
	
	my($i,$typ,$last,$first,$middle,$name,$fullname,$key,$etal,%ptype,$x);
	
	if (scalar keys %{$partyRef} == 0 ) {
		die "bannerpro.pl: makeastyle: partylist is empty.";
	}
	
	foreach $i (1..30) {  # 30 parties max
		$key="$case_id;$i";
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
	  		return "$fullname - Estate of";
		} elsif ($typ=~/WARD/) {
			return "$fullname - Guardianship of";
		} elsif ($typ=~/MIN/) {
			return "$fullname - Minor";
		} elsif ($typ=~/^INCP/) {
			return "$fullname - Incapacity of ";
		} elsif ($typ=~/^AINC/) {
			return "$fullname - Alleged Incapacity of ";
		} elsif ($typ=~/^INRE/) {
			return "$fullname - In re";
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
	} elsif (defined $ptype{'PET'} and defined $ptype{'PAT'}) {
		return "$ptype{'PAT'} v. $ptype{'PET'}";
	} elsif (defined $ptype{'PET'} and defined $ptype{'RESP'}) {
		return "$ptype{'RESP'} v. $ptype{'PET'}";
	} else {
		return join " ",sort values %ptype;
	}
}


# makelist
#
# keep these off the list...
# warrants
# sworn complaints (no charges filed)
# disposed cases (case with no pending charges)
#
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
	
	my $query = qq {drop table if exists `probate_cases_new` };
	
	doQuery($query,$crdbh);
	
	$query = qq {
		CREATE TABLE `probate_cases_new` (
			`CaseNumber` char(20) NOT NULL,
			`CaseStyle` text NOT NULL,
			`DivisionID` char(6) NOT NULL,
			`FileDate` date NOT NULL,
			`CaseAge` int(11) NOT NULL,
			`CourtType` char(6) NOT NULL,
			`CaseType` char(6) NOT NULL,
			`CaseStatus` char(20) NOT NULL,
			`LastActivity` date DEFAULT NULL,
			`FlagsAndNotes` text DEFAULT NULL,
			PRIMARY KEY (`CaseNumber`),
			KEY `prb_file_date_idx` (`FileDate`),
			KEY `prb_case_age_idx` (`CaseAge`) USING BTREE,
			KEY `prb_event_idx` (`LastActivity`) USING BTREE,
			KEY `prb_case_nbr_idx` (`CaseNumber`) USING HASH,
			KEY `prb_court_type_idx` (`CourtType`) USING HASH,
			KEY `prb_case_type_idx` (`CaseType`) USING HASH,
			KEY `prb_case_status_idx` (`CaseStatus`) USING HASH,
			KEY `prb_div_idx` (`DivisionID`) USING HASH
		)
	};
	
	doQuery($query,$crdbh);
	my $count = 0;
	foreach my $casenum (keys %caselist) {
		$caseRef->{$casenum}->{'CaseAge'} = getAge($caseRef->{$casenum}->{'FileDate'});
		#my $evcode = undef;
		#my $evdate = undef;
		#if (defined($caseRef->{$casenum}->{'LastEvent'})) {
		#	$evcode = $caseRef->{$casenum}->{'LastEvent'}->{'EventCode'};
		#	$evdate = ISO_date($caseRef->{$casenum}->{'LastEvent'}->{'EventDate'});
		#}
		my $ladate = undef;
		if (defined($caseRef->{$casenum}->{'LastActivityDate'})) {
			$ladate = ISO_date($caseRef->{$casenum}->{'LastActivityDate'});
		}
		
		my $ucn=casenumtoucn($casenum);
		
		my @vals = ($ucn, $caseRef->{$casenum}->{'CaseStyle'},
					$caseRef->{$casenum}->{'DivisionID'},
					ISO_date($caseRef->{$casenum}->{'FileDate'}),
					$caseRef->{$casenum}->{'CaseAge'},
					$caseRef->{$casenum}->{'CourtType'},
					$caseRef->{$casenum}->{'CaseType'},
					$caseRef->{$casenum}->{'CaseStatus'},
					$ladate,
					$caseRef->{$casenum}->{'FlagsAndNotes'},
					);
					
		
		$query = qq {
			insert into
				probate_cases_new
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
					FlagsAndNotes
				)
			values
				(?,?,?,?,?,?,?,?,?,?)
		};
		
		doQuery($query,$crdbh,\@vals);
		$count++;
		if (!$count % 1000) {
			print "Entered $count cases...\n";
		}
		
	}
	
	$crdbh->do("drop table if exists probate_cases");
	$crdbh->do("rename table probate_cases_new to probate_cases");
	$crdbh->do("Commit");
	$crdbh->disconnect();
}



sub doit() {
    if($MSGS) {
        print "starting probate reports bannerpro ".timeStamp()."\n";
    }

    if (@ARGV==1 and $ARGV[0] eq "DEBUG") {
        $DEBUG=1;
        print "DEBUG!\n";
    }
    
    my $ndbh = dbConnect("wpb-banner-rpt");
    
    if($MSGS) {
        print "starting buildSRSList ".timeStamp()."\n";
    }
	buildSRSList(\%srsstatus,$outpath,$casetypes,$ndbh);
    
    if($MSGS) {
        print "starting buildcaselist ".timeStamp()."\n";
    }
	buildCaseList(\%caselist,$casetypes,\%srsstatus,$outpath,$ndbh);
	
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
	#buildEvents(\%caselist,$casetypes,$ndbh);
    
    if($MSGS) {
        print "starting buildNotes ".timeStamp()."\n";
    }
	buildNotes(\%caselist,$casetypes);
    
    if($MSGS) {
        print "starting buildPartyList ".timeStamp()."\n";
    }
    #buildpartylist;
	buildPartyList(\%partylist,$outpath,\@justcases,$ndbh);
    
    if($MSGS) {
        print "starting buildStyles ".timeStamp()."\n";
    }
    buildStyles(\%caselist,\%partylist,$outpath);
    
    if($MSGS) {
        print "starting report ".timeStamp()."\n";
    }
    report(\%caselist);
    
    if($MSGS) {
        print "finished probate reports bannerpro ".timeStamp()."\n";
    }
}

#
# MAIN PROGRAM STARTS HERE!
#

doit();
