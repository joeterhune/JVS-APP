#!/usr/bin/perl
#
# sccrim.pl - ShowCase Criminal Case Reports - based on 06/07/2010 level of
#             bannercrim.pl

use lib "$ENV{'PERL5LIB'}";
use strict;
use POSIX qw(strftime);
use ICMS;
use DBI qw(:sql_types);

# For redirecting STDOUT, STDERR
use IO::Handle;

use Common qw (
	inArray
	dumpVar
	convertDates
	writeDebug
	sendMessage
	redirectOutput
	timeStamp
    getArrayPieces
    getShowcaseDb
);
use PBSO;
use Showcase qw (
	$ACTIVE
	$NOTACTIVE
	getSCcasetype
	@juvDivs
);
use Casenotes qw (
	mergeNotesAndFlags
	buildnotes
	updateCaseNotes
);

use DB_Functions qw (
	dbConnect
	getData
	getScCaseAge
    getVrbEvents
    getDbSchema
);

use File_Funcs qw (
	getLock
);

use Date::Calc qw (
	Today
	Parse_Date
	Delta_Days
);

use Reports qw (
    getVrbEventsByCaseList
    getLastDocketFromList
	buildNoHearings
);

use Switch;

our $db = getShowcaseDb();
our $dbh = dbConnect($db);
our $schema = getDbSchema($db);

# will read txt files if set to 1
my $DEBUG=0;
# will spit out diag msgs if set to 1
my $MSGS=1;

# No output buffering
$| = 1;

my @casetypes = ('CF','CT','MM','MO','CO','AP','TR');
my $casetypes="('CF','CT','MM','MO','CO','AP','TR')";

my $newcase;
my $outpath;
my $outpath2;
my $webpath;
my $county="Sarasota";
# contains all cases for this report with the corresponding srs status
my %allsrs;
# just status of cases we're interested in
my %srsstatus;
# set in buildallcases
my %allcases;
# set in buildcaselist
my %caselist;
# set in buildcaselist
my %divlist;
my %critdesc=(
	      "pend"=>"Pending Cases",
	      "warr"=>"Outstanding Warrants",
	      "nopend"=>"Other Cases",
	      "ro"=>"Reopened Cases",
	      "pendne"=>"Pending Cases with No Events Scheduled",
	      "pendwe"=>"Pending Cases with Events Scheduled",
	      "rowe"=>"Reopened Cases with Events Scheduled",
	      "rone"=>"Reopened Cases with No Events Scheduled",
	      "trial"=>"Trial Events this Month",
	      "nonjury"=>"Non Jury Trial Events this Month",
	      "njnonjury"=>"Non Jury Trial Events this Month",
	      "njinfraction"=>"Infraction Trial Events this Month",
	      "jury"=>"Jury Trial Events this Month"
	     );
# set in buildwarrants
my %warrants;
# set in buildcharges
my %charges;
# set in buildcharges
my %chargepending;
# set in buildincustody
my %jailtime;
# set in buildlastdocket
my %lastdocket;
my @lastdockets;
# set in buildlastactivity
my %lastactivity;
my %reopened;
# set in buildcaselist
my %events;
# A list of cases with motions but no hearing set afterward
my %noHearings;

# The most recent (past) event
my %lastevent;
# set in buildnotes
my %notes;
# set in buildnotes
my %flags;
# merged notes and flags
my %merged;
# status of icms database when run - 'ok' or 'bad'
my $icmsdb='ok';

# testing - set in buildCodes
my %vcodes;
my %vcodeshash;
my %vcodeslookup;
my %scdivs;

# set in buildmh
my %mhcases;
# set in buildmh
my %all_mhcases;
# set in buildmh
my %temp_mhcases;

# Need to get appeals, too.
push(@CRIMCODES,"'AP'");
my $courtcodes="(" . join(",", @CRIMCODES) . ")";

my $trialtypes=
  "('NJ - NON JURY TRIAL','IT - INFRACTION TRIAL','JT - JURY TRIAL')";
my %njevents;
my %itevents;
my %jtevents;
# cases that have trial events
my %tcases;

# Ranking for the CourtStatuteDegree - so we can determine the highest degree
# of charge for a case.
my %csds = (
	'C' => 0,
	'L' => 1,
	'P' => 2,
	'F' => 3,
	'S' => 4,
	'T' => 5,
	'N' => 6
);

my @csdescs = (
	'C - Capital',
	'L - Life',
	'P - 1st Punishable by Life',
	'F - 1st',
	'S - 2nd',
	'T - 3rd',
	'N - Not Applicable'
);

my %topcharges;

# cdbcase_sealed_ind  3 - sealed/expunged?
#
# expecting:  50yyyyXXxxxxxxAXXXMB format
# case numbers are preceded by '50' in showcase...
# sc done
sub casenumtoucn {
  my($casenum)=@_;
  return "50-" . substr($casenum,2,4)."-".substr($casenum,6,2)."-".
    substr($casenum,8,6)."-".substr($casenum,14,4)."-".substr($casenum,18);
}

# sc done
sub write_nodiv_file
  {
    my ($f, @nodiv_case) = @_;
    @nodiv_case = () unless @nodiv_case;
    open (F, ">>$f");
    print F @nodiv_case, "\n";
    close F;
  }


# take a casetype and return a "nice" string
# sc ok
sub getdesc {
	my $casetype = shift;
	my $div = shift;

	if ($div eq "") {
		return "Criminal No ";
	} elsif ($casetype eq "CF") {
		if (($div eq "Y") || ($div eq "YD")) {
			return "Circuit & County Criminal";
		}
		if ($div eq "CFMH") {
			return "Mental Health";
		}
		return "Circuit Criminal";
	} else {
		if ($div eq "KD") {
			return "Circuit Criminal";
		}
		if (($div eq "Y") || ($div eq "YD")) {
			return "Circuit & County Criminal";
		}
		return "County Criminal";
	}
}



# sc converted
sub buildmh {
	my $dbh = shift;

	my %rawmhcases;
	my ($res,$x);
	if ($DEBUG) {
		print "DEBUG: Reading mhcases.txt\n";
		#%mhcases=readhash("$outpath/mhcases.txt");
	} else {
		my $query = qq {
			select
				c.UCN,
				c.CaseNumber,
				DivisionID,
				EffectiveDate as Effective
			from
				vDocket d with(nolock),
				vCase c with(nolock)
			where
				d.CaseID = c.CaseID
				and c.CourtType ='CF'
				and DocketCode ='OSMH'
				and EffectiveDate=(
					select
						MIN(EffectiveDate)
					from
						vDocket d2 with(nolock)
					where
						d2.CaseID=d.CaseID
						and d2.DocketCode=d.DocketCode
				)
				-- and c.DivisionID='S'
		};

		#%rawmhcases = sqlhash($query);
		sqlHashHash($query,$dbh,\%rawmhcases,"CaseNumber");
		convertDates(\%rawmhcases,"Effective");

		foreach my $case (sort keys %rawmhcases) {
			if ( defined $caselist{$case} ) {
				$mhcases{$case}=$rawmhcases{$case};
			}
		}

		writeHashFromHash(\%mhcases,"$outpath/mhcases.txt",0,"CaseNumber","CaseNumber","DivisionID","Effective");
	}

	# Put all cases with mental health docket code OSMH
	# into one array, then put only those cases with the initial, first time
	# docket is coded with the code  and initial filing date that is
	# after 1/20/09  - for now both arrays are the same since only OSMH
	# is new and identifying them.
	# Keeping extra code in case future testing may need to subdivide
	# into a different array to identify these as cases to be transfered
	# temporarily to division T.
	# Flag each case as mental health and put it into the flags table.

	foreach my $fcn (keys %mhcases) {
		#my($ucn,$case_div,$doc_date)=split '~',$mhcases{$_};
		#my $fcn=casenumtoucn($ucn);

		my $doc_date = $mhcases{$fcn}->{'EffectiveDate'};

		my $icmsconn = dbConnect("icms");
		if (defined($icmsconn)) {
			#  check to make sure flag for that case isn't already set.
			my $query = qq {
				select
					b.dscr
				from
					flags a,
					flagtypes b
				where
					a.flagtype=b.flagtype
					and casenum='$fcn'
					and a.flagtype='3'
		    };

			my @flags;
			sqlHashArray($query,$icmsconn,\@flags);

			# if found then delete record and insert new
			if (scalar(@flags)) {
				my $query = qq {
					delete from
						flags
					where
						flagtype='3'
						and casenum='$fcn'
				};
				$icmsconn->do($query);
			}
			my $x='3';
			$query = qq {
				insert into
					flags (casenum,userid,date,flagtype)
				values
					('$fcn','icms','$TODAY',$x)
			};
			$icmsconn->do($query);
		} else {
			print "problem!  no icms database connection while processing mental ".
				"health case $fcn.  Case not marked. \n";
		}

		$icmsconn->disconnect;

		$all_mhcases{$fcn}=1;
		if ($doc_date >= '01/20/2009') {
			$temp_mhcases{$fcn}=1;
		}
	}
}

sub makelist {
	my $casetype = shift;
	my $thisdiv = shift;
	my $crit = shift;
	my $dbh = shift;

	my @list;
    my @noEventList;
	my $injail;
	if (!$critdesc{$crit}) {
		die "invalid criteria $crit\n";
	}

	if (!defined($dbh)) {
	  $dbh = dbConnect("showcase-rpt");
	}

	my $cttext;
	$cttext=getdesc($casetype,$thisdiv);

	foreach my $case (keys %caselist) {
		my ($id,$desc,$name,$div,$status,$casetype,$filedate,$ctyp,
		   $dob,$sex,$ccnts,$disposition,$reopendate,$reopenclose)=split '~',$caselist{$case};

		# showcase:  casetype above is really the CourtType and ctyp is the CaseType
		if ($thisdiv ne "CFMH") {
			if ($thisdiv ne $div) {
				next;
			}
		}

		if (($thisdiv eq "CFMH") and (!$all_mhcases{$case})) {
			next;
		} elsif (($thisdiv eq "CFMH") and ($all_mhcases{$case})) {
			write_nodiv_file("$outpath/MHdiv_cases.txt","$case,$div\n");
		}

		# check for suppress flag...
		#my $ucn=casenumtoucn($case);
		if ($flags{"$case;2"}) {
			# we have a suppress
			my $flagdate=(split '~',$flags{"$case;2"})[2];
			my $lastdockdate=(split '~',$lastdocket{$case})[1];
			# if the last docket date is < flagdate, then skip
			if (compdate($lastdockdate,$flagdate)==-1) {
				next;
			}
		}

		# showcase has 50YYYY format for case!
		$newcase = substr($case,2,4);

		if ($crit=~/^pend/) {	# pending cases
			if (($crit eq "pendne") && (defined($events{$case}))) {
				next;
			}
			if (($crit eq "pendwe") && (!defined($events{$case}))) {
				next;
			}
			if ($warrants{$case}) {
				# skip if warrant outstanding
				next;
			}
			if ($reopened{$case}) {
				# skip if reopened
				next;
			}
			if (!defined($chargepending{$case})) {
				# skip if no pending charges
				next;
			}
		} elsif ($crit eq "warr") {
			# skip if NO warrant outstanding
			if (!$warrants{$case}) {
				next;
			}
		} elsif ($crit eq "nopend") {
			if ($warrants{$case}) {
				# skip if warrant outstanding
				next;
			}
			if ($reopened{$case}) {
				# skip if reopened
				next;
			}
			if ($chargepending{$case}) {
				# skip if no pending charges
				next;
			}
		} elsif ($crit=~/^ro/) {
			if (($crit eq "rone") && ($events{$case})) {
				next;
			}
			if (($crit eq "rowe") && (!$events{$case})) {
				next;
			}
			if (!$reopened{$case}) {
				# skip if not reopened
				next;
			}
			if ($warrants{$case}) {
				# skip if warrant outstanding
				next;
			}
		} elsif ($crit eq "trial") {
			if (!$tcases{$case}) {
				next;
			}
		} elsif ($crit eq "nonjury") {
			if (!(($njevents{$case} == 1) || ($itevents{$case} == 1 ))) {
				next;
			}
		} elsif ($crit eq "njnonjury") {
			if (!$njevents{$case}) {
				next;
			}
		} elsif ($crit eq "njinfraction") {
			if (!$itevents{$case}) {
				next;
			}
		} elsif ($crit eq "jury") {
			if (!$jtevents{$case}) {
				next;
			}
		}

		#my $age=getage($filedate);
		my %casehash = (
			CaseNumber => $case,
			CaseStatus => $status,
			DispositionDate => $disposition,
			ReopenDate => $reopendate,
			ReopenCloseData => $reopenclose,
			FileDate => $filedate
		);
		my $age=getScCaseAge(\%casehash,$dbh);
		#my ($evcode,$evdate)=split '~',$events{$case};
		my $evcode = "";
		my $evdate = "";
		if (defined($events{$case})) {
			$evcode = $events{$case}->{'EventType'};
			$evdate = $events{$case}->{'EventDate'};
		}
		my $levcode = "";
		my $levdate = "";
		if (defined($lastevent{$case})) {
			$levcode = $lastevent{$case}->{'EventType'};
			$levdate = $lastevent{$case}->{'EventDate'};
		}
		my $ladate = $lastactivity{$case};

		# for showcase, ctyp (case type) will sometimes be empty.
		# casetype var is really court type...
		my $sccasetype = getSCcasetype($casetype, $ctyp);

		# use $name instead of $desc - because case style changed between Banner
		# and Showcase
		my $csd = '';
		if ((defined($topcharges{$case})) && ($topcharges{$case} ne '')) {
			$csd = $csdescs[$csds{$topcharges{$case}}];
		}
        
        my $listString = "$case~$name~$sex~$dob~$jailtime{$case}->{'InJail'}~$jailtime{$case}->{'DaysServed'}~$age~$filedate~$sccasetype~$status~".
			"$ladate~$ccnts~$csd~$levdate~$levcode~$evdate~$evcode~$merged{$case}\n";
		push @list,$listString;
        
        if (defined($noHearings{$case})) {
			push(@noEventList, $listString);
		}
        
	}

    my $outFile = sprintf("%s/%s.txt", $outpath2, $crit);
	
	open(OUTFILE,">$outFile") ||
		die "Couldn't open '$outFile' for writing: $!\n\n";
    
	my $fntitle = "Flags/Most Recent Note";
	if ($icmsdb eq 'bad') {
		$fntitle.="<br/>* Not Current *";
	}
	print OUTFILE "DATE=$TODAY\n";
	print OUTFILE "TITLE1=$county Beach County - $cttext Division $thisdiv\n";
	print OUTFILE "TITLE2=$critdesc{$crit}\n";
	print OUTFILE "VIEWER=view.cgi\n";
	print OUTFILE "FIELDNAMES=Case #~Name~Sex~DOB~In<br>Jail~Days<br>Served~Case<br>Age~Initial File~Case<br>".
		"Type~Status~Last Activity~# of<br>Charges~Highest<br>Charge<br>Degree~".
		"Most<br>Recent<br>Event Date~Most Recent<br>Event Type~".
		"Farthest<br>Event~Farthest Event<br>Type~$fntitle\n";
	print OUTFILE "FIELDTYPES=L~I~C~D~C~G~G~D~C~A~D~C~C~D~A~D~A~A\n";

	print OUTFILE @list;
	close(OUTFILE);
    
    $outFile = sprintf("%s/%s_motNoEvent.txt", $outpath2, $crit);
    	open(OUTFILE,">$outFile") ||
		die "Couldn't open '$outFile' for writing: $!\n\n";
    
	print OUTFILE "DATE=$TODAY\n";
	print OUTFILE "TITLE1=$county Beach County - $cttext With Motions But No Events Division $thisdiv\n";
	print OUTFILE "TITLE2=$critdesc{$crit}\n";
	print OUTFILE "VIEWER=view.cgi\n";
	print OUTFILE "FIELDNAMES=Case #~Name~Sex~DOB~In<br>Jail~Days<br>Served~Case<br>Age~Initial File~Case<br>".
		"Type~Status~Last Activity~# of<br>Charges~Highest<br>Charge<br>Degree~".
		"Most<br>Recent<br>Event Date~Most Recent<br>Event Type~".
		"Farthest<br>Event~Farthest Event<br>Type~$fntitle\n";
	print OUTFILE "FIELDTYPES=L~I~C~D~C~G~G~D~C~A~D~C~C~D~A~D~A~A\n";

	print OUTFILE @noEventList;
	close(OUTFILE);
    
    return scalar @list;
}


# Took this out of below list to 'hide' Other reports.
# Other Cases~$numnopend~1~nopend
# Was under Reopened with No events.

sub report {
	my $dbh = shift;
	my($numpend,$numpendwe,$numpendne,$numwarr,$numro,$numrowe,$numrone,
	   $numnopend,$numnotrial,$numtrial,$numnonjury,$numnjnonjury,
	   $numnjinfraction,$numjury);

	foreach my $div (keys %divlist) {
		my $casetype=$divlist{$div};
		my $cttext=getdesc($casetype,$div);
		# for each division...
		my $tim = strftime("%Y-%m",localtime(time));
		if (!-d "$outpath/div$div") {
			mkdir "$outpath/div$div",755;
		}
		$outpath2="$outpath/div$div/$tim";
		if ($MSGS) {
			print "outpath2 is $outpath2 \n";
		}
		if (!-d "$outpath2") {
			mkdir("$outpath2",0755);
		}

		$numpend=makelist($casetype,$div,"pend",$dbh);
		$numpendwe=makelist($casetype,$div,"pendwe",$dbh);
		$numpendne=makelist($casetype,$div,"pendne",$dbh);
		$numwarr=makelist($casetype,$div,"warr",$dbh);
		$numro=makelist($casetype,$div,"ro",$dbh);
		$numrowe=makelist($casetype,$div,"rowe",$dbh);
		$numrone=makelist($casetype,$div,"rone",$dbh);
		$numnopend=makelist($casetype,$div,"nopend",$dbh);
		# new reports
		$numtrial=makelist($casetype,$div,"trial",$dbh);
		$numnonjury=makelist($casetype,$div,"nonjury",$dbh);
		$numnjnonjury=makelist($casetype,$div,"njnonjury",$dbh);
		$numnjinfraction=makelist($casetype,$div,"njinfraction",$dbh);
		$numjury=makelist($casetype,$div,"jury",$dbh);
		if ($numpend==0) {
			print "WARNING: no pending cases (but reopened cases exist) for $div\n";
		}
		#
		# now create the summary file for this division
		#
		open OUTFILE,">$outpath2/index.txt" ||
		die "Couldn't open $outpath2/index.txt";
		print OUTFILE <<EOS;
DATE=$TODAY
TITLE1=$county Beach County
TITLE2=$cttext Division $div
PATH=case/$county/crim/div$div/$tim/
HELP=helpbannercrim
Pending Cases~$numpend~1~pend
With Events~$numpendwe~2~pendwe
With No Events~$numpendne~2~pendne
Reopened Cases~$numro~1~ro
With Events~$numrowe~2~rowe
With No Events~$numrone~2~rone
BLANK
Outstanding Warrants~$numwarr~1~warr
BLANK
Cases with Trial Events this Month~$numtrial~1~trial
Non Jury~$numnjnonjury~3~njnonjury
Infraction~$numnjinfraction~3~njinfraction
Jury~$numjury~2~jury
BLANK
Other~$numnopend~1~nopend
EOS
		unlink("$outpath/div$div/index.txt");
		symlink("$outpath2/index.txt","$outpath/div$div/index.txt");
	}
}

# sc done
# Get all the warrants, then flag ones that are in our caselist
sub buildwarrants {
	my $dbh = shift;

	if ($DEBUG) {
		print "DEBUG: Reading warrants.txt\n";
		%warrants=readhash("$outpath/warrants.txt");
	} else {
		my $query = qq {
			select
				c.CaseNumber,
				'1' as Truth
			from
				vWarrant w with(nolock),
				vCase c with(nolock)
			where
				w.CaseID=c.CaseID
				and c.CaseStatus not in $NOTACTIVE
				and c.CourtType in $courtcodes
				and w.Closed = 'N'
				-- and c.DivisionID='S'
			order by
				c.LegacyCaseNumber
		};

		my %rawwarrants;
		getData(\%rawwarrants,$query,$dbh,{hashkey => "CaseNumber", flatten => 1});
		#sqlHashArray($query,$dbh,\@rawwarrants);

		writeHashFromHash(\%rawwarrants,"$outpath/rawwarrants.txt",0,"CaseNumber","Truth");

		foreach my $key (keys %rawwarrants) {
			if (defined $caselist{$rawwarrants{$key}->{'CaseNumber'}}) {
				$warrants{$rawwarrants{$key}->{'CaseNumber'}}=1;
			}
		}

		if ($MSGS) {
			print scalar keys %rawwarrants," raw Outstanding warrants\n";
			print scalar keys %warrants," Outstanding warrants for cases we want \n";
		}
		writehash("$outpath/warrants.txt",\%warrants);
	}
}


# done for sc
sub buildcharges {
	my $dbh = shift;

	my %rawcharges;
	if ($DEBUG) {
		print "DEBUG: Reading charges.txt\n";
		#%charges=readhash("$outpath/charges.txt");
		open (CHARGES, "$outpath/charges.txt");
		while (my $line = <CHARGES>) {
			chomp $line;
			my ($leader,$data) = split(/\`/, $line);
			my %charge;
			($charge{'CaseNumber'}, $charge{'ChargeDate'}, $charge{'CourtStatuteNumber'}, $charge{'CourtStatuteNumSubSect'},
			 $charge{'CourtStatuteDescription'},$charge{'CourtStatuteLevel'},$charge{'CourtStatuteDegree'},$charge{'Disposition'},
			 $charge{'DispositionDate'},$charge{'fcic'}) = split(/~/, $data);
			$charge{'Leader'} = $leader;
			if (!defined($charges{$charge{'CaseNumber'}})) {
				$charges{$charge{'CaseNumber'}} = [];
			}
			push(@{$charges{$charge{'CaseNumber'}}}, \%charge);
		}
	} else {
		# not sure about statute stuff....  several of these in the view -
		# told to use Court ones by Parik on 8/4/11
		my $query = qq {
		    select
				c.CaseNumber + ';' + convert(varchar, ChargeCount) as Leader,
				c.CaseNumber,
				ChargeCount,
				ChargeDate,
				CourtStatuteNumber,
				CourtStatuteNumSubSect,
				CourtStatuteDescription,
				CourtStatuteLevel,
				CourtStatuteDegree,
				chg.Disposition,
				chg.DispositionDate,
				1 as fcic
	        from
				vCharge chg with(nolock),
				vCase c with(nolock)
		    where
				chg.CaseID=c.CaseID
				and CaseStatus not in $NOTACTIVE
				and c.CourtType in $courtcodes
				-- and c.DivisionID='S'
			order by
				c.CaseNumber,
				ChargeCount
		};

		getData(\%rawcharges,$query,$dbh,{hashkey => "CaseNumber"});
		#sqlArrayHash($query,$dbh,\%rawcharges,"CaseNumber");
		convertDates(\%rawcharges,"ChargeDate","DispositionDate");
		print "Got raw charges. There were " . scalar(keys %rawcharges) . " found. " . timeStamp() ."\n\n";

		my %chargelist;

		foreach my $casenum (keys %rawcharges) {
			if (defined ($caselist{$casenum})) {
				$charges{$casenum} = $rawcharges{$casenum};
				foreach my $charge (@{$rawcharges{$casenum}}) {
					$chargelist{$charge->{'Leader'}} = $charge;
					if ((!defined($topcharges{$casenum})) ||
						((defined($topcharges{$casenum})) &&
						($csds{$charge->{CourtStatuteDegree}} < $csds{$topcharges{$casenum}}))) {
						# This charge is a more serious charge than others that we've seen for this case
						# (if we've seen any)
						$topcharges{$casenum} = $charge->{CourtStatuteDegree};
					}
				}
			}
		}


		print "Writing file $outpath/charges.txt " . timeStamp() ."\n\n";

		writeHashFromHash(\%chargelist,"$outpath/charges.txt",0,"Leader",
						  "CaseNumber","ChargeDate","CourtStatuteNumber",
						  "CourtStatuteNumSubSect","CourtStatuteDescription",
						  "CourtStatuteLevel","CourtStatuteDegree","Disposition",
						  "DispositionDate","fcic"
						  );

		print "Done writing file $outpath/charges.txt " . timeStamp() ."\n\n";
	}

	foreach my $key (keys %charges) {
		foreach my $charge (@{$charges{$key}}) {
			if ((!defined($charge->{DispositionDate})) || ($charge->{DispositionDate} eq "")) {
				my ($casenum,$seq) = split(/~/, $key);
				$chargepending{$casenum}=1;
				# No sense continuing if we don't need to.
				last;
			}
		}
	}

	print "Writing file $outpath/chargepending.txt " . timeStamp() ."\n\n";

	writehash("$outpath/chargepending.txt",\%chargepending);
	print "Done writing file $outpath/chargepending.txt " . timeStamp() ."\n\n";
}

sub buildincustody {
	my $dbh = shift;

	if ($MSGS) {
		print "in buildincustody \n";
	}
	my %rawarrests;
	my %rawpbsocases;
	my %rawpbsoincustody;


	if ($MSGS) {
		print "getting rawarrests \n";
	}
	# Get all Clerk Arrests in a hash with case #
	# The BookingSheetNumber is the PBSO Case Number!
	my $query = qq {
		select
			a.CaseNumber,
			a.BookingSheetNumber,
			a.CountyID
		from
			vCase c with(nolock),
			vArrest a with(nolock)
		where
			c.CaseID=a.CaseID
			-- and c.DivisionID='S'
		order by
			c.LegacyCaseNumber desc
	};

	getData(\%rawarrests,$query,$dbh,{ hashkey => "CaseNumber" });
	#writeHashFromHash(\%rawarrests,"$outpath/rawarrests.txt",0,"CaseNumber","CaseNumber","BookingSheetNumber","CountyID");

	my $pbsoconn = dbConnect("pbso2",undef,1);
	if (defined($pbsoconn)) {
		# Get all PBSO cases (may have multiple per booking) into a hash with
		# PBSO Case # as key (which is the Showcase booking number) and save
		# inmateid (jacket), pbso booking id, and release date (a null release
		if ($MSGS) {
			print "getting raw pbso cases \n";
		}
		my %rawpbsocases;
		#%rawpbsocases=get_allpbsocases();
		get_allpbsocases(\%rawpbsocases, $pbsoconn);
		writeHashFromHash(\%rawpbsocases,"$outpath/rawpbsocases.txt",0,"CaseNumber","CaseNumber","InmateID","BookingID","ReleaseDate",
						  "AssigedCellID");

		$pbsoconn->disconnect;

		if ($MSGS) {
			print "building incustody list \n";
		}
		my %arrests;

		foreach my $case (keys %caselist) {
			my($div,$desc,$name,$status,$casetype,$filedate,$ctyp,
			   $dob,$ccnts)=split '~',$caselist{$case};
			# see if this case is in the arrests hash
			$jailtime{$case} = ();
			$jailtime{$case}->{'InJail'} = "N";
			$jailtime{$case}->{'DaysServed'} = 0;

			if (defined ($rawarrests{$case})) {
				# Set up a hash of the different arrest dates, so we don't accidentally
				# count the days in an arrest twice (if there were multiple PBSO
				# cases on the booking)

				my %arrests;

				foreach my $arrest (@{$rawarrests{$case}}) {
					# get the booking number (which is pbso case number) and jacket
					my $scbn = $arrest->{'BookingSheetNumber'};
					if (defined ($rawpbsocases{$scbn})) {
						# Have we already processed this booking?
						my ($sy,$sm,$sd) = Parse_Date($rawpbsocases{$scbn}->{'BookingDate'});
						my $bd = sprintf("%04d-%02d-%02d", $sy, $sm, $sd);
						next if (defined($arrests{$bd}));
						$arrests{$bd} = 1;
						my ($ey,$em,$ed); # End date components
						if ((!defined($rawpbsocases{$scbn}->{'ReleaseDate'})) ||
							($rawpbsocases{$scbn}->{'ReleaseDate'} eq '')) {
							# For this booking sheet, the defendant is still in custody
							$jailtime{$case}->{'InJail'} = "Y";
							$jailtime{$case}->{'AssignedCellID'} = $rawpbsocases{$scbn}->{'AssignedCellID'};
							# Special Cases - these days do not count!
							switch ($jailtime{$case}->{'AssignedCellID'}) {
								case "WEEKENDER OUT" {
									$jailtime{$case}->{'InJail'} = "W";
								}
								case "IN-HOUSE ARREST" {
									$jailtime{$case}->{'InJail'} = "H";
								}
								case "ESCAPED" {
									$jailtime{$case}->{'InJail'} = "E";
								}
								else {
									# Ok, the person is actually in jail.
									($ey,$em,$ed) = Today();
									my $served = Delta_Days($sy,$sm,$sd,$ey,$em,$ed);
									if ($served < 0) {
										$served = 0;
									}

									$jailtime{$case}->{'DaysServed'} += $served;
								}
							}
						} else {
							# The inmate has been released for this arrest
							($ey,$em,$ed) = Parse_Date($rawpbsocases{$scbn}->{'ReleaseDate'});
							my $served = Delta_Days($sy,$sm,$sd,$ey,$em,$ed);
							if ($served < 0) {
								$served = 0;
							}
							$jailtime{$case}->{'DaysServed'} += $served;
						}
					}
				}
			}
		}
	}
}


# done for sc
sub buildlastdocket {
	my $dbh = shift;

	my %rawlastdocket;
	if ($DEBUG) {
		print "DEBUG: Reading lastdocket.txt\n";
		%lastdocket=readhash("$outpath/lastdocket.txt");
	} else {
		my $query = qq{
		    select
				vCase.CaseNumber,
				x.EffectiveDate,
				x.DocketCode,
				vCase.CaseID
		    from
				$schema.vCase with(nolock),
				(
					select
						d1.CaseNumber,
						d1.EffectiveDate,
						d1.DocketCode,
						d1.SeqPos,
						d1.CaseID
					from
						$schema.vDocket d1 with(nolock)
					where
						d1.EffectiveDate = (
						    select
								MAX(d2.EffectiveDate)
						    from
								$schema.vDocket d2 with(nolock)
						    where
								d2.CaseID = d1.CaseID
						)
				) as x
		    where
				x.CaseID = vCase.CaseID
				and CaseStatus not in  $NOTACTIVE
				and CourtType in $courtcodes
				-- and vCase.DivisionID='S'
			order by
				vCase.LegacyCaseNumber asc
		};

		my @tempdockets;
		getData(\@tempdockets,$query,$dbh);

		#sqlHashArray($query,$dbh,\@tempdockets);
		convertDates(\@tempdockets,"EffectiveDate");

		print "Selected " . scalar(@tempdockets) . " rows. " . timeStamp() . "\n";

		# It's possible for there to be duplicates, so march through and just take
		# the first one
		my %found;
		foreach my $row (@tempdockets) {
			next if (defined($found{$row->{'CaseNumber'}}));
			push (@lastdockets, $row);
			$found{$row->{'CaseNumber'}} = 1;
		}

		print "Kept " . scalar(@lastdockets) . " rows. " . timeStamp() . "\n";

		print "Writing $outpath/lastdocket.txt..." . timeStamp() . "\n";

		writeHashFromArray(\@lastdockets,"$outpath/lastdocket.txt",0,"CaseNumber","CaseNumber",
						   "EffectiveDate","DocketCode");

		# Since lastactivity is just a subset of lastdocket, use the same hash to
		# write that file.  No need for buildlastactivity
		print "Writing $outpath/lastactivity.txt..." . timeStamp() . "\n";
		writeHashFromArray(\@lastdockets,"$outpath/lastactivity.txt",0,"CaseNumber","CaseNumber",
						   "EffectiveDate");

		# Need to populate the %lastactivity hash
		foreach my $lastdocket (@lastdockets) {
			$lastactivity{$lastdocket->{'CaseNumber'}} = $lastdocket->{'EffectiveDate'};
		}

		print "Finished writing hash file " . timeStamp() . "\n";
	}
}




# sc done
sub buildevents {
    my $caselist = shift;
	my $dbh = shift;

	my %rawevents;
    my %rawlastevents;

	if ($DEBUG) {
		print "DEBUG: Reading events.txt\n";
		#%events=readhash("$outpath/events.txt");
		open (HASHFILE, "$outpath/events.txt");
		while (my $line = <HASHFILE>) {
			chomp $line;
			my ($key, $data) = split(/\`/, $line);
			my ($event, $date) = split(/~/, $data);
			$events{$key}->{'CaseNumber'} = $key;
			$events{$key}->{'CourtEventType'} = $event;
			$events{$key}->{'CourtEventDate'} = $date;
		}
	} else {
        my $count = 0;
        my $perQuery = 1000;
        
        print "Getting events - farthest and last recent,,," . timeStamp() . "\n\n";
        
        getVrbEventsByCaseList($caselist, \%rawevents, 0);
        getVrbEventsByCaseList($caselist, \%rawlastevents, 1);
        
        #while ($count < scalar(@{$caselist})) {
        #    my @temp;
        #    getArrayPieces($caselist, $count, $perQuery, \@temp, 1);
        #    
        #    getVrbEventsByCaseList(\@temp, \%rawevents, 0);
        #    getVrbEventsByCaseList(\@temp, \%rawlastevents, 1);
        #    
        #    $count += $perQuery;
        #}
        
        foreach my $case (keys %rawevents) {
			if ( defined $caselist{$case} ) {
				$events{$case} = $rawevents{$case};
			}
		}
        
        foreach my $case (keys %rawlastevents) {
			if ( defined $caselist{$case} ) {
				$lastevent{$case} = $rawlastevents{$case};
			}
		}
        
        print "Finished getting events - farthest and last recent,,," . timeStamp() . "\n\n";
    }
}
        
        #my $query = qq {
        #    select
        #        ce.CaseNumber,
        #        ce.CourtEventType,
        #        ce.CourtEventDate
        #    from
        #        vCourtEvent ce with(nolock),
        #        vCase c
        #    where
        #        ce.CourtEventDate >= ?
        #        and ce.Cancelled <> 'Yes'
        #        and ce.CaseNumber = c.CaseNumber
        #        and c.CourtType in $courtcodes
        #        and c.CaseStatus not in $NOTACTIVE
        #    order by
        #        CourtEventDate asc
        #};

#		print "Getting farthest events..." . timeStamp() . "\n";
#        
#        getVrbEvents(\%rawevents);
        
		#getData(\%rawevents,$query,$dbh,{hashkey => "CaseNumber", flatten => 1,
		#								 valref => [$SQLEVTDATE]});
#		
#		foreach my $case (keys %rawevents) {
#			if ( defined $caselist{$case} ) {
#				$events{$case} = $rawevents{$case};
#			}
#		}
#        
#        foreach my $case (keys %rawlastevents) {
#			if ( defined $caselist{$case} ) {
#				$lastevent{$case} = $rawlastevents{$case};
#			}
#		}
		#writeHashFromHash(\%events,"$outpath/events.txt",0,"CaseNumber","CourtEventType","CourtEventDate");

#		print "Getting last events..." . timeStamp() . "\n";
#		# And do the same thing for the last (past) event.        
#        my $query = qq {
#            select
#                ce.CaseNumber,
#                ce.CourtEventType,
#                ce.CourtEventDate
#            from
#                vCourtEvent ce with(nolock),
#                vCase c
#            where
#                CourtEventDate <= GETDATE()
#                and ce.Cancelled <> 'Yes'
#                and ce.CaseID = c.CaseID
#                and c.CourtType in $courtcodes
#                and c.CaseStatus not in $NOTACTIVE
#            order by
#                CourtEventDate desc
#        };
#        
#		my %rawlastevents;
#
#		getData(\%rawlastevents,$query,$dbh,{hashkey => "CaseNumber", flatten => 1});
#
#		print "Got last events..." . timeStamp() . "\n\n";
#
#		convertDates(\%rawlastevents,"CourtEventDate");

#		foreach my $case (keys %rawlastevents) {
#			if ( defined $caselist{$case} ) {
#				$lastevent{$case} = $rawlastevents{$case};
#			}
#		}
#	}
#}


sub buildtrialevents {
	my $dbh = shift;

	my (%rawnjevents,%rawitevents,%rawjtevents);
	if ($DEBUG) {
		print "DEBUG: Reading njevents.txt\n";
		%njevents=readhash("$outpath/njevents.txt");
		print "DEBUG: Reading itevents.txt\n";
		%njevents=readhash("$outpath/itevents.txt");
		print "DEBUG: Reading jtevents.txt\n";
		%njevents=readhash("$outpath/jtevents.txt");
	} else {
		# gets 1st one of each
		my $query = qq {
			select
				c.CaseNumber,
				'1' as Truth
			from
				vCourtEvent e with(nolock),
				vCase c with(nolock)
			where
				c.CaseID = e.CaseID
				and c.CourtType in $courtcodes
				and CaseStatus not in $NOTACTIVE
				and CourtEventType = 'NJ - NON JURY TRIAL'
				and Sealed != 'Y'
				and substring(convert(varchar(10),CourtEventDate,101),1,2) =
					substring(convert(varchar(10),GETDATE(),101),1,2)
				and substring(convert(varchar(10),CourtEventDate,101),7,4) =
					substring(convert(varchar(10),GETDATE(),101),7,4)
				-- and c.DivisionID='S'
			order by
				c.LegacyCaseNumber
		};

		getData(\%rawnjevents,$query,$dbh,{hashkey => "CaseNumber", flatten => 1});

		foreach my $case (keys %rawnjevents) {
			if ( defined $caselist{$case} ) {
				$njevents{$case}=$rawnjevents{$case};
			}
		}

		writeHashFromHash(\%njevents,"$outpath/njevents.txt",0,"CaseNumber","Truth");

		$query = qq {
			select
				c.CaseNumber,
				'1' as Truth
			from
				vCourtEvent e with(nolock),
				vCase c with(nolock)
			where
				c.CaseID = e.CaseID
				and c.CourtType in $courtcodes
				and CaseStatus not in $NOTACTIVE
				and CourtEventType = 'IT - INFRACTION TRIAL'
				and Sealed != 'Y'
				and substring(convert(varchar(10),CourtEventDate,101),1,2) =
					substring(convert(varchar(10),GETDATE(),101),1,2)
				and substring(convert(varchar(10),CourtEventDate,101),7,4) =
					substring(convert(varchar(10),GETDATE(),101),7,4)
				-- and c.DivisionID='S'
			order by
				c.LegacyCaseNumber
		};

		getData(\%rawitevents,$query,$dbh,{hashkey => "CaseNumber", flatten => 1});

		foreach my $case (keys %rawitevents) {
			if ( defined $caselist{$case} ) {
				$itevents{$case}=$rawitevents{$case};
			}
		}

		writeHashFromHash(\%itevents,"$outpath/itevents.txt",0,"CaseNumber","Truth");

		$query = qq {
			select
				c.CaseNumber,
				'1' as Truth
			from
				vCourtEvent e with(nolock),
				vCase c with(nolock)
			where
				c.CaseID = e.CaseID
				and c.CourtType in $courtcodes
				and CaseStatus not in $NOTACTIVE
				and CourtEventType = 'JT - JURY TRIAL'
				and Sealed != 'Y'
				and substring(convert(varchar(10),CourtEventDate,101),1,2) =
					substring(convert(varchar(10),GETDATE(),101),1,2)
				and substring(convert(varchar(10),CourtEventDate,101),7,4) =
					substring(convert(varchar(10),GETDATE(),101),7,4)
				-- and c.DivisionID='S'
			order by
				c.LegacyCaseNumber
		};

		getData(\%rawjtevents,$query,$dbh,{hashkey => "CaseNumber", flatten => 1});

		foreach my $case (keys %rawjtevents) {
			if ( defined $caselist{$case} ) {
				$jtevents{$case}=$rawjtevents{$case};
			}
		}
		writeHashFromHash(\%jtevents,"$outpath/jtevents.txt",0,"CaseNumber","Truth");
	}
}


sub buildtrialcases {
	my $dbh = shift;

	my %rawtcases;
	if ($DEBUG) {
		print "DEBUG: Reading tcases.txt\n";
		%tcases=readhash("$outpath/tcases.txt");
	} else {
		my $query = qq {
			select
				c.CaseNumber,
                e.CourtEventType,
				'1' as Truth
			from
				vCourtEvent e with(nolock),
				vCase c with(nolock)
			where
				c.CaseID = e.CaseID
				and c.CourtType in $courtcodes
				and CaseStatus not in $NOTACTIVE
				and CourtEventType in $trialtypes
				and Sealed != 'Y'
				and substring(convert(varchar(10),CourtEventDate,101),1,2) =
					substring(convert(varchar(10),GETDATE(),101),1,2)
				and substring(convert(varchar(10),CourtEventDate,101),7,4) =
					substring(convert(varchar(10),GETDATE(),101),7,4)
			order by
				c.LegacyCaseNumber
		};

		getData(\%rawtcases,$query,$dbh,{ hashkey => "CaseNumber", flatten => 1});

		foreach my $case (keys %rawtcases) {
			if ( defined $caselist{$case} ) {
				$tcases{$case}=$rawtcases{$case};
                if ($rawtcases{$case}->{'CourtEventType'} eq 'JT - JURY TRIAL') {
                    $jtevents{$case}=$rawtcases{$case};
                } elsif ($rawtcases{$case}->{'CourtEventType'} eq 'IT - INFRACTION TRIAL') {
                    $itevents{$case}=$rawtcases{$case};
                } elsif ($rawtcases{$case}->{'CourtEventType'} eq 'NJ - NON JURY TRIAL') {
                    $njevents{$case}=$rawtcases{$case};
                }
			}
		}
		writeHashFromHash(\%tcases,"$outpath/tcases.txt",0,"CaseNumber","Truth");
	}
}


sub buildcaselist {
	my $dbh = shift;

	my $nodiv;
	my %divassign;
	my %rawcase;
	my @scdivs;
	my @scdivassign;
	my $s;
	my $q;
	my %rawcases;

	if ($DEBUG) {
		print "DEBUG: Reading divassign.txt\n";
		readHashHash("$outpath/divassign.txt",\%divassign,"~|`","CaseNumber","DivisionID",
					 "CourtType","Judge_LN","Judge_FN","Judge_MN");
	} else {
		# If there's no judge on the case, it won't pull the case...
		# NOT SURE IF THAT'S OK OR NOT.  I DON'T THINK IT MAKES A DIFFERENCE IN
		# THE END...

		$q = qq{
			select
				c.UCN,
				c.CaseNumber,
				c.DivisionID,
				c.CourtType,
				c.CaseStatus,
				DispositionDate,
				FileDate,
				ReopenDate,
				j.Judge_LN,
				j.Judge_FN,
				j.Judge_MN
			from
				vCase c with(nolock),
				vDivision_Judge j with(nolock)
			where
				c.DivisionID=j.DivisionID
				and c.CaseStatus not in $NOTACTIVE
				and c.CourtType in $courtcodes
				and j.Division_Active='Yes'
				and c.DivisionID not in (} .
					join(",", @juvDivs) . qq {)
				-- and c.DivisionID='S'
			order by
				c.CaseNumber asc
		};

		getData(\%divassign,$q,$dbh,{ hashkey => "CaseNumber", flatten => 1 });
		convertDates(\%divassign,"DispositionDate","FileDate","ReopenDate");

		print "There were " . scalar(keys(%divassign)) . " records returned.\n\n";

		print "Done reading case list from DB." . timeStamp() . "\n";

		writeHashFromHash(\%divassign,"$outpath/divassign.txt",0,"CaseNumber",
						  "DivisionID","CourtType","Judge_LN","Judge_FN", "Judge_MN");

		if ($MSGS) {
			print "wrote divassign '$outpath/divassign.txt' ".timeStamp()."\n";
		}
	}

	if ($DEBUG) {
		print "DEBUG: Reading divlist.txt\n";
		%divlist=readhash("$outpath/divlist.txt");
	} else {
		foreach my $case (keys %divassign) {
			my $code = ($divassign{$case}->{'CourtType'} eq "CF") ? "CF" : "MM";
			# for our purposes all the MM types treated the same

			if ($divlist{$divassign{$case}->{'DivisionID'}}) {
				next if (grep{/$code/} values %divlist);
				$divlist{$divassign{$case}->{'DivisionID'}}.=",$code";
			} else {
				$divlist{$divassign{$case}->{'DivisionID'}}=$code;
			}
		}
		$divlist{'CFMH'}="CF";
		writehash("$outpath/divlist.txt",\%divlist);
	}

	# do rawcase
	# keys=all divisions in use; values=# cases in each
	if ($DEBUG) {
		print "DEBUG: Reading rawcase.txt\n";
		readHashHash("$outpath/rawcase.txt",\%rawcases,"~|`","CaseNumber","DivisionID",
					 "CaseStyle","LastName","FirstName","MiddleName", "CaseStatus",
					 "CourtType","FileDate","CaseType","DOB","CaseCounts");
	} else {
		if ($MSGS) {
			print "starting rawcase query ".timeStamp()."\n";
		}
		$q = qq{
			select
				c.CaseNumber,
				c.DivisionID,
				NULL as CaseStyle,
				p.LastName,
				p.FirstName,
				p.MiddleName,
				p.Sex,
				c.CaseStatus,
				c.CourtType,
				c.FileDate,
				c.DispositionDate,
				c.ReopenDate,
				c.ReopenCloseDate,
				c.CaseType,
				p.DOB,
				CaseCounts
			from
				vCase c with(nolock),
				vParty p with(nolock)
			where
				c.CaseID = p.CaseID
				and p.PartyTypeDescription in ('DEFENDANT','APPELLANT')
				and c.CourtType in $courtcodes
				and c.CaseStatus not in $NOTACTIVE
				and c.Sealed = 'N'
				and c.Expunged = 'N'
				-- and c.DivisionID='S'
			order by
				c.CaseNumber
		};

		getData(\%rawcases,$q,$dbh,{hashkey => "CaseNumber", flatten => 1});
		#sqlHashHash($q,$dbh,\%rawcases,"CaseNumber");
		convertDates(\%rawcases,"FileDate","DispositionDate","ReopenDate","ReopenCloseDate","DOB");

		$s = scalar(keys %rawcases);
		if ($MSGS) {
			print "got all the rawcase rows - $s of them ".timeStamp()."\n";
		}

		writeHashFromHash(\%rawcases,"$outpath/rawcase.txt",0,"CaseNumber",
						  "DivisionID","CaseStyle","LastName","FirstName",
						  "MiddleName","CaseStatus","CourtType","FileDate",
						  "CaseType","DOB","Sex","CaseCounts");
	}

	if ($MSGS) {
		print "coursing through rawcase hash - filling caselist... ".
		timeStamp()."\n";
	}

	foreach my $casenum (keys %rawcases) {
		my $case = $rawcases{$casenum};
		my $div;
		if ((!defined($divassign{$casenum}->{'DivisionID'})) ||
			($divassign{$casenum} eq "")) {
			$nodiv++;
			write_nodiv_file("$outpath/nodiv_crimcases.txt",
							 "$casenum, status=$case->{'CaseStatus'}");
		} else {
			$div = $divassign{$casenum}->{'DivisionID'};
		}

		$caselist{$casenum} = sprintf("%s~%s~%s, %s %s~%s~%s~%s~%s~%s~%s~%s~%s~%s~%s~%s",
									  $case->{'DivisionID'}, $case->{'CaseStyle'},
									  $case->{'LastName'}, $case->{'FirstName'},
									  $case->{'MiddleName'}, $div,
									  $case->{'CaseStatus'}, $case->{'CaseType'},
									  $case->{'FileDate'}, $case->{'CourtType'},
									  $case->{'DOB'}, $case->{'Sex'}, $case->{'CaseCounts'},
									  $case->{'DispositionDate'},$case->{'ReopenDate'},
									  $case->{'ReopenCloseDate'}
									  );

		if (inArray(["Reopen","Reopen VOP"], $case->{'CaseStatus'})) {
			$reopened{$casenum}=1;
		}
	}

	if ($MSGS) {
		print "$nodiv Cases with No Division!\n";
		}
	write_nodiv_file("$outpath/nodiv_crimcases.txt",
					 "$nodiv cases with no division");
	writehash("$outpath/caselist.txt",\%caselist);
	writehash("$outpath/reopened.txt",\%reopened);
	if ($MSGS) {
		print "done building caselist ".timeStamp()."\n";
	}
}

# sc done
# builddivcs  fills the %divcs hash with a text style for each case in this
# division.
sub builddivcs {
	my $thisdiv = shift;
	my $dbh = shift;

	my %divcs=();
	if (onlinediv($thisdiv) eq "true") {
		if ($MSGS) {
			print "building divcs for division $thisdiv \n";
		}
		# will build the all cases list the first time a div w/ online scheduing
		# is done
		if ( scalar %allcases == 0 ) {
			no strict 'refs';
			buildallcases($dbh);
		}
		foreach my $case (keys %allcases) {
			my($divid,$desc)=split '~',$allcases{$case};
			# format for this file is YYYYXXxxxxxxX - so get rid of 50 in front
			# and get 12 chars
			if ($thisdiv eq $divid) {
				$divcs{substr($case,2,14)}=$desc;
			}
		}
		writehash("$outpath/div$thisdiv/divcs.txt",\%divcs);
	}
}

# Get all cases (not just active) - needed for online scheduling.
# Don't do it if no divisions in online scheduling.
# Also, not saving all cases to a text file because they're too big!
# (Writing the file for testing purposes, right now.)
sub buildallcases {
	my $dbh = shift;

	if (scalar @OLSCHEDULING > 0) {
		my %all;
		my $query;
		# don't exclude closed cases
		$query = qq{
			select
				c.CaseNumber,
				c.DivisionID,
				NULL as c.CaseStyle
			from
				vCase c with(nolock),
				vParty p with(nolock)
			where
				c.CaseID = p.CaseID
				and p.PartyTypeDescription in ('DEFENDANT', 'APPELLANT')
				and c.CourtType in $courtcodes
				and c.Sealed = 'N'
				-- and c.DivisionID='S'
		};

		getData(\%all,$query,$dbh, { hashkey => "CaseNumber", flatten => 1});

		foreach my $casenum (sort keys %all) {
			$allcases{$casenum}=$all{$casenum};
		}
		if ($MSGS) {
			my $s = keys %allcases;
			print "size of allcases is $s \n";
		}
		writehash("$outpath/allcases.txt",\%allcases);
	}
}

sub doit() {
	my $RETRY_MAX = 20;
	my $RETRY_INTERVAL = 300;

	#my $database = "reports";

	my $dbh = dbConnect("showcase-rpt",undef,1);

	my $retries = 0;
	while ((!defined($dbh)) && ($retries < $RETRY_MAX)) {
		$retries++;
		writeDebug("Retrying Showcase connection (retry #" . $retries . ") in $RETRY_INTERVAL seconds.\n");
		warn "Retrying Showcase connection (retry #" . $retries . ") in $RETRY_INTERVAL seconds.\n";
		sleep $RETRY_INTERVAL;
		$dbh = dbConnect("showcase-rpt",undef,1);
	}

	if ((!defined($dbh)) && ($retries >= $RETRY_MAX)) {
		my @recips;
		my $recip = {
			"email_addr" => 'cad-alllinuxadmins@jud12.flcourts.org'
		};
		push(@recips,$recip);
		my $sender = {
			"email_addr" => 'cad-icmsalert@jud12.flcourts.org'
		};
		my $subject = "Showcase Criminal Report Unable to Establish DB Connection";
		my $msgbody = "The Showcase reporting script ($0) was unable to establish a database connection, after $retries ".
			"tries!\n\nNo reports were generated by this script.\n\nThat is all.\n";
		sendMessage(\@recips,$sender,undef,$subject,$msgbody);
		die "Too many retries!!!\n\n";
	}

	if ($MSGS) {
		print "starting criminal reports sccrim ".timeStamp()."\n";
	}

	if (@ARGV==1 and $ARGV[0] eq "DEBUG") {
		$DEBUG=1;
		print "DEBUG!\n";
	}

	$outpath="/var/www/html/case/$county/crim";
	$webpath="/case/$county/crim";

	rename("$outpath/nodiv_crimcases.txt", "$outpath/nodiv_crimcases.txt_prev");

	if ($MSGS) {
		print "starting buildcaselist ".timeStamp()."\n";
	}

	buildcaselist($dbh);
    
    if ($MSGS) {
		print "starting updateCaseNotes ".timeStamp()."\n";
	}
	#updateCaseNotes(\%caselist,\@casetypes);
    
    my @justcases = keys(%caselist);
    buildNoHearings(\@justcases, \%noHearings);
    
    if ($MSGS) {
		print "finished updateCaseNotes ".timeStamp()."\n";
	}

	if ($MSGS) {
		print "starting buildwarrants ".timeStamp()."\n";
	}
	buildwarrants($dbh);

	if ($MSGS) {
		print "starting buildcharges ".timeStamp()."\n";
	}

	buildcharges($dbh);

	if ($MSGS) {
		print "starting buildlastdocket ".timeStamp()."\n";
	}
	buildlastdocket($dbh);

	if ($MSGS) {
		print "starting buildevents ".timeStamp()."\n";
	}
	buildevents(\@justcases,$dbh);
    
	if ($MSGS) {
		print "starting buildnotes ".timeStamp()."\n";
	}
	buildnotes(\%merged, \%flags, $casetypes, $outpath, $DEBUG);

	#if ($MSGS) {
	#	print "starting buildtrialevents ".timeStamp()."\n";
	#}
	#buildtrialevents ($dbh);

	if ($MSGS) {
		print "starting buildtrialcases ".timeStamp()."\n";
	}
	buildtrialcases($dbh);

	if ($MSGS) {
		print "starting buildincustody ".timeStamp()."\n";
	}
	buildincustody($dbh);

	if ($MSGS) {
		print "starting report ".timeStamp()."\n";
	}
	report($dbh);

	# If we're here, write something to indicate that we ran successfully.
	my @now = localtime(time);
	my $donefile = sprintf("$ENV{'PERL5LIB'}/results/sccrim-done.%04d%02d%02d", $now[5] + 1900, $now[4] + 1, $now[3]);
	open (DONE, ">$donefile");
	close DONE;

	if ($MSGS) {
		print "finished criminal reports sccrim ".timeStamp()."\n";
	}
}

#
# MAIN PROGRAM STARTS HERE!
#

# First, try to obtain a lock file, to ensure that no other copies are running.
my $lockfile = "$ENV{'PERL5LIB'}/results/sccrim.lock";

if (!getLock($lockfile,5)) {
	print "Unable to obtain exclusive lock on '$lockfile'.  Another instance is running.  Exiting.\n";
	exit;
}

# Ok, it's the only one.
# First, redirect STDOUT and STDERR
#redirectOutput("crim");

doit();
