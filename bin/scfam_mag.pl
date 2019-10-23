#!/usr/bin/perl
#
# scfam_mag.pl - Family Magistrates

BEGIN {
	use lib $ENV{'JVS_PERL5LIB'};
}

use strict;
use POSIX qw(strftime);
use ICMS;
use DBI qw(:sql_types);
use Switch;

use Showcase qw (
	$ACTIVE
	$NOTACTIVE
);
use strict;
use Casenotes qw (
    mergeNotesAndFlags
    updateCaseNotes
	buildnotes
);
use Common qw(
    inArray
    dumpVar
    getArrayPieces
	@dorPIDMs
	@skipHack
	writeJsonFile
	US_date
    getShowcaseDb
	convertDates
	today
);
use DB_Functions qw (
    dbConnect
    getData
	getVrbEvents
	doQuery
    getDbSchema
);
use Showcase::Reports qw (
	buildPartyList
	buildPartyListMag
);

use Reports qw (
    getVrbEventsByCaseList
	buildNoHearings
	buildCAJuryCaseList
	buildLOS
	buildContested
);

use Date::Calc qw (:all Parse_Date);
use Getopt::Long;

my $DEBUG=0;  # will read txt files if set to 1
my $MSGS=1;   # will spit out diag msgs if set to 1

my $dbName = getShowcaseDb();
my $schema = getDbSchema($dbName);
my $dbh = dbConnect($dbName);

# No output buffering
$| = 1;

my $outpath;
my $outpath2;
my $webpath;
my $county="Palm";

my %allcases; # set in buildallcases
my %caselist; # set in buildcaselist
my %divlist;  # set in buildcaselist
my %partylist;
my %style;
my %critdesc=(
    "pend"=>"Pending Cases","nopend"=>"Other Cases","ro"=>"Reopened Cases",
    "pendne"=>"Pending Cases with No Events Scheduled","pendwe"=>"Pending Cases with Events Scheduled",
    "rowe"=>"Reopened Cases with Events Scheduled","rone"=>"Pending Cases with No Events Scheduled",
    );


my %lastdocket; # set in buildlastdocket
my %lastactivity; # set in buildlastactivity
my %reopened; # set in buildcaselist
my %noHearings;
my %juryCases;
my $reopencodes=",Reopen,";
my %others; # set in buildcaselist
#my $othercodes=",TO,DH,FNOA,";
#my $othercodes=",Open,Reopen,";
my $othercodes = "";
my %events;
my %lastevent;
my %merged;	# merged notes and flags
my %flags;
my $icmsdb='ok'; # status of icms database when run - 'ok' or 'bad'
#my @justcases;  # An array of JUST case numbers

my %all_ufcl; #set in buildufc
my %all_ufct; #set in buildufc
my %all_ufjm; #set in buildufc
# Contested/uncontested dissolutions
my %contested;
my %uncontested;

my %all_dor;  	# set in builddor
my %los;

my @casetypes = ('CA','CC','SC','DR','RS','RD','DA','DU');
my $casetypes="('CA','CC','SC','DR','RS','RD','DA','DU')";  # note that Juvenile are not in here
#my $stattypes="('PE','PEAJ','PTPR','RE','RM','RO','TO','DH','FNOA')"; # first 3 are Pending, then 3 Reopened, then 3 Other
my $stattypes="('Open', 'Reopen')";
my $famptypes="('JUDG','DFT','PET','HYBRID')";

my @allCivLOS;

#
# this is for civil cases only..leaves off that final -A
#
sub casenumtoucn {
    my($casenum)=@_;
    #return substr($casenum,0,4)."-".substr($casenum,4,2)."-".substr($casenum,6,6);
	return $casenum;
}



#
# makeastyle    makes a case style of the form "x v. y" where x and y are the
#               first plaintiff/defendant, petitioner/respondent, etc.
#               listed for a case.
sub makeastyle {
    my($case_id,$i,$typ,$last,$first,$middle,$name,$fullname,$key,$etal,%ptype,$x,$partyID,$assoc,$ptyp_desc);
    if (scalar keys %partylist==0) {
		die "scfam_mag.pl: makeastyle: partylist is empty.";
    }
    $case_id=shift;
    %ptype=();
    foreach $i (1..30) {
		# 30 parties max
		$key="$case_id;$i";
		if (!defined $partylist{$key}) {
		    next;
		}
		
		($typ,$last,$first,$middle,$partyID,$assoc,$ptyp_desc)=(split '~',$partylist{$key})[2..8];
		if($typ ne "ATTY"){
			if($typ eq "HYBRID"){
				$typ = $ptyp_desc;
			}
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
    }
    
    if (defined $ptype{'PLT'} and defined $ptype{'DFT'}) {
		return "$ptype{'PLT'} v. $ptype{'DFT'}";
    } elsif (defined $ptype{'CPLT'} and defined $ptype{'DFT'}) {
		return "$fullname"; # traffic cases
    } elsif (defined $ptype{'PET'} and defined $ptype{'RESP'}) {
		return "$ptype{'PET'} v. $ptype{'RESP'}";
    } elsif (defined $ptype{'PLAINTIFF/PETITIONER'} and defined $ptype{'DEFENDANT/RESPONDENT'}) {
		return "$ptype{'PLAINTIFF/PETITIONER'} v. $ptype{'DEFENDANT/RESPONDENT'}";
	} else {
		return join " ",sort values %ptype;
    }
}

#
# buildstyles  fills the %style hash with a text style for each case.
#
sub buildstyles() {
	my $dbh;
	#my($id,$desc,$last,$first,$middle,$status,$casetype,$filedate);
	if ($DEBUG) {
		print "DEBUG: Reading styles.txt\n";
		%style=readhash("$outpath/styles.txt");
	} else {
		foreach my $case (keys %caselist) {
			my ($div, $style, $name, $status, $type, $filedate, $dispodate, $reopendate, $reopenclosedate, $courttype, $real_div) = split(/~/, $caselist{$case});
			my $caseage = getScCaseAge($filedate, $dispodate, $reopendate, $reopenclosedate, $status, $dbh);
			$style{$case} = sprintf("%s~%s~%d", makeastyle($case), $real_div, $caseage);
		}
		writehash("$outpath/styles.txt",\%style);
	}
}

#
# makelist
#
# keep these off the list...
# warrants
# sworn complaints (no charges filed)
# disposed cases (case with no pending charges)
#
sub makelist {
    my($casetype,$thisdiv,$crit)=@_;
    my @list;
	my @noEventList;
	my @juryList;
	my @losList;
	my @contestedList;
	my @uncontestedList;
    if (!$critdesc{$crit}) {
		die "invalid criteria $crit\n";
    }
    my $mag;
    
    switch($thisdiv){
    	case 'SCHD' { $mag = "BAKER, THOMAS"; }
    	case 'SCHC' { $mag = "BASSALINE, PETER"; }
    	case 'DORAK' { $mag = "FANELLI, JUDETTE"; }
    	case 'NCH2706' { $mag = "KIRIGIN, DIANE"; }
    	case 'NCH1418' { $mag = "WILLIAMS, JEAN-ADEL"; }
    	case 'MJCLZ' { $mag = "WILLIAMS, MAXINE"; }
    	case 'MJCAK' { $mag = "ZEITENBERG, TEMI"; }
    	case 'DORLZ' { $mag = "WILLIAMS, JAMES"; }
    	else { $mag = 'NA'; }
    }
    	
    #my $cttext=getdesc($casetype,$thisdiv);
    my $cttext = $casetype;
	
	my $reportData =  [
		{'label' => '0 - 120 Days', 'value' => 0},
		{'label' => '121 - 180 Days', 'value' => 0},
		{'label' => '180+ Days', 'value' => 0}
	];

    foreach my $case (keys %caselist) {

        my($div,$desc,$status,$casetype,$filedate,$dispodate,$reopendate,$reopenclosedate,$ctyp,$real_div)=split '~',$caselist{$case};
		
		next if (inArray(\@skipHack,$status));

        if (!inArray(["UFCL","UFCT","UFJM"],$thisdiv)) {
			if ($thisdiv ne $div) {
				next;
			}
        }
        if (($thisdiv eq "UFCL") && (!$all_ufcl{$case})) {
			next;
		}
        if (($thisdiv eq "UFCT") && (!$all_ufct{$case})) {
			next;
		}
        if(($thisdiv eq "UFJM") && (!$all_ufjm{$case})) {
			next;
		} elsif ((inArray(["UFCL","UFCT"."UFJM"], $thisdiv)) && (($all_ufcl{$case})||($all_ufct{$case})||($all_ufjm{$case}))) {
			write_nodiv_file("$outpath/UFC_cases.txt","$case,$div");
		}
		
		#  DR family cases in civ dirs, but if
		# the divisions are juvenile skip these cases as the bannerjuv gets them
		#
		if (inArray(["JO","JL","JK","JM","JA","JS"],$thisdiv)){
			next;
		}

        # check for suppress flag...
        my $ucn=casenumtoucn($case);
        if ($flags{"$ucn;2"}) { # we have a suppress
            my $flagdate=(split '~',$flags{"$ucn;2"})[2];
            my $lastdockdate = $lastdocket{$case}->{'FilingDate'};
            # if the last docket date is < flagdate, then skip
            if (compdate($lastdockdate,$flagdate)==-1) {
				next;
			}
        }
		
        if ($crit=~/^pend/) {  # pending cases
            if ($crit eq "pendne" and $events{$case}) {
				next;
			}
			if ($crit eq "pendwe" and !$events{$case}) {
				next;
			}
			if ($crit eq "pendd" and !$all_dor{$case}) {
				next;
			}
			if ($crit eq "pendnd" and $all_dor{$case}) {
				next;
			}
            if ($reopened{$case}) {
				# skip if reopened
				next;
			} 
            if ($others{$case}) {
				# skip if 'other' case
				next;
			}
		} elsif ($crit=~/^nopend/) {
			# other cases
			if ($crit eq "nopendd" and !$all_dor{$case}) {
				next;
			}
			if ($crit eq "nopendnd" and $all_dor{$case}) {
				next;
			}
			if (!$others{$case}) {
				# skip if not an other case
				next;
			}
		} elsif ($crit=~/^ro/) {
			# reopened cases
			if ($crit eq "rone" and $events{$case}) {
				next;
			}
			if ($crit eq "rowe" and !$events{$case}) {
				next;
			}
			if ($crit eq "rod" and !$all_dor{$case}) {
				next;
			}
			if ($crit eq "rond" and $all_dor{$case}) {
				next;
			}
			if (!$reopened{$case}) {
				# skip if not reopened
				next;
			}
		}
		my $age = getScCaseAge($filedate, $dispodate, $reopendate, $reopenclosedate, $status, $dbh);
		my $evcode = $events{$case}->{'CourtEventType'};
		my $evdate = $events{$case}->{'CourtEventDate'};
		#my ($evcode,$evdate)=split '~',$events{$case};
		my $s = $style{$case};	# get the style from the styles hash
		# Since the case age has been tacked onto the style, remove it for our purpose here.
		$s = join("~", (split(/~/,$s))[0..1]);
		my $ladate = $lastactivity{$case}->{'FilingDate'};
        my $ladoct = $lastactivity{$case}->{'DocketType'};
		my $listString = "$ucn~$s$real_div~$filedate~$age~$ctyp~$status~$ladate~$ladoct~$evcode~$evdate~$merged{$ucn}\n";
		push @list,$listString;
		
		if (defined($noHearings{$ucn})) {
			push(@noEventList, $listString);
		}
		
		if (defined($juryCases{$ucn})) {
			push(@juryList, $listString);
		}
		
		if (defined($los{$ucn})) {
			push(@losList, $listString);
			push(@allCivLOS, $listString);
		}
		
		if ($thisdiv =~ /^F/) {
			if (defined($contested{$ucn})) {
				push(@contestedList, $listString);
			}
			if (defined($uncontested{$ucn})) {
				push(@uncontestedList, $listString);
			}
		}
		
	}
    
    # skip juvenile divisions
    #
	my $outFile = sprintf("%s/%s.txt", $outpath2, $crit);
	
    if (!inArray(["JO","JL","JK","JM","JA","DG","JS"],$thisdiv)) {
		open(OUTFILE,">$outFile") ||
			die "Couldn't open '$outFile' for writing: $!\n\n";
		my $fntitle = "Flags/Most Recent Note";
		
		if($icmsdb eq 'bad'){
			$fntitle.="<br/>* Not Current *";
		}
		print OUTFILE <<EOS;
DATE=$TODAY
TITLE1=$county Beach County - $cttext
TITLE2=$critdesc{$crit}
VIEWER=view.cgi
FIELDNAMES=Case #~Name~Division~Initial File~Age~Type~Status~Last Activity Date~Last Activity~Event Code~Latest / Farthest Event~$fntitle
FIELDTYPES=L~I~C~D~G~S~A~D~A~A~D~A
EOS
		print OUTFILE @list;
		close(OUTFILE);
		
		$outFile = sprintf("%s/%s_motNoEvent.txt", $outpath2, $crit);
		open(OUTFILE,">$outFile") ||
			die "Couldn't open '$outFile' for writing: $!\n\n";
		print OUTFILE <<EOS;
DATE=$TODAY
TITLE1=$county Beach County - $cttext With Motions But No Events Division $thisdiv
TITLE2=$critdesc{$crit}
VIEWER=view.cgi
FIELDNAMES=Case #~Name~DOB~Division~Initial File~Age~Type~Status~Last Activity~# of Charges~Charges~Event Code~Latest / Farthest Event~$fntitle
FIELDTYPES=L~I~D~C~D~G~S~A~D~C~I~A~D~A
EOS
		print OUTFILE @noEventList;
		close(OUTFILE);
		
		
		$outFile = sprintf("%s/%s_juryTrials.txt", $outpath2, $crit);
		open(OUTFILE,">$outFile") ||
			die "Couldn't open '$outFile' for writing: $!\n\n";
		print OUTFILE <<EOS;
DATE=$TODAY
TITLE1=$county Beach County - $cttext Cases Set for Jury Trial Division $thisdiv
TITLE2=$critdesc{$crit}
VIEWER=view.cgi
FIELDNAMES=Case #~Name~DOB~Division~Initial File~Age~Type~Status~Last Activity~# of Charges~Charges~Event Code~Latest / Farthest Event~$fntitle
FIELDTYPES=L~I~D~C~D~G~S~A~D~C~I~A~D~A
EOS
		print OUTFILE @juryList;
		close(OUTFILE);	
		
$outFile = sprintf("%s/%s_los.txt", $outpath2, $crit);
		open(OUTFILE,">$outFile") ||
			die "Couldn't open '$outFile' for writing: $!\n\n";
		print OUTFILE <<EOS;
DATE=$TODAY
TITLE1=$county Beach County - $cttext Lack of Service Division $thisdiv
TITLE2=$critdesc{$crit}
VIEWER=view.cgi
FIELDNAMES=Case #~Name~Division~Initial File~Age~Type~Status~Last Activity Date~Last Activity~Event Code~Latest / Farthest Event~$fntitle
FIELDTYPES=L~I~C~D~G~S~A~D~A~A~D~A
EOS
		print OUTFILE @losList;
		close(OUTFILE);
		
		if (($thisdiv =~ /^F/) || ($thisdiv == 'WE')) {
			$outFile = sprintf("%s/%s_contested.txt", $outpath2, $crit);
			open(OUTFILE,">$outFile") ||
				die "Couldn't open '$outFile' for writing: $!\n\n";
			print OUTFILE <<EOS;
DATE=$TODAY
TITLE1=$county Beach County - $cttext Contested Dissolutions Division $thisdiv
TITLE2=$critdesc{$crit}
VIEWER=view.cgi
FIELDNAMES=Case #~Name~Division~Initial File~Age~Type~Status~Last Activity Date~Last Activity~Event Code~Latest / Farthest Event~$fntitle
FIELDTYPES=L~I~C~D~G~S~A~D~A~A~D~A
EOS
			print OUTFILE @contestedList;
			close(OUTFILE);
			
			
			$outFile = sprintf("%s/%s_uncontested.txt", $outpath2, $crit);
			open(OUTFILE,">$outFile") ||
				die "Couldn't open '$outFile' for writing: $!\n\n";
			print OUTFILE <<EOS;
DATE=$TODAY
TITLE1=$county Beach County - $cttext Uncontested Dissolutions Division $thisdiv
TITLE2=$critdesc{$crit}
VIEWER=view.cgi
FIELDNAMES=Case #~Name~Division~Initial File~Age~Type~Status~Last Activity Date~Last Activity~Event Code~Latest / Farthest Event~$fntitle
FIELDTYPES=L~I~C~D~G~S~A~D~A~A~D~A
EOS
			print OUTFILE @uncontestedList;
			close(OUTFILE);
		}
		
		return scalar @list;
    }
}



sub write_nodiv_file
{
    my ($f, @nodiv_case) = @_;
    @nodiv_case = () unless @nodiv_case;
    open (F, ">>$f");
    print F @nodiv_case, "\n";
    close F;
}


# take a casetype (really is cort code) and return a "nice" string

sub getdesc {
    my $casetype=$_[0];
    my $div=$_[1];
	if ($div eq "") {
		return "Civil No ";
	} elsif ($casetype eq "CA") {
		if (inArray(['AW','AV'],$div)) {
			return "Foreclosure";
		} else {
			return "Circuit Civil";
		}
    } elsif ($casetype eq "CC") {
		return "County Civil";
	} elsif (inArray(['DR','DA','DR,DA','DU'],$casetype)) {
        if (inArray(['UFCL','UFCT','UFJM'],$div)) {
            return "Unified Family Court";
        }
        if (inArray(['JK','JL','JM','JO','JA','DG','JS'],$div)) {
           return "Juvenile";
        } else {
			return "Family";
		}
    }
    else { print "Error: unknown casetype of $casetype\n"; }
}

sub report {
	my($numpend,$numpendwe,$numpendne,$numpendd,$numpendnd,$numro,$numrowe,$numrone,$numrod,$numrond,$numnopend,$numnopendd,$numnopendnd,$mag);
    
    foreach my $div (sort keys %divlist) {
		next if ($div eq '');
		next if (inArray(["JO","JL","JK","JM","JA","DG","JS"],$div));
		print "Reporting for division '$div'...\n";
		my $casetype=$divlist{$div};
		
		switch($div){
	    	case 'SCHD' { $mag = "BAKER, THOMAS"; }
	    	case 'SCHC' { $mag = "BASSALINE, PETER"; }
	    	case 'DORAK' { $mag = "FANELLI, JUDETTE"; }
	    	case 'NCH2706' { $mag = "KIRIGIN, DIANE"; }
	    	case 'NCH1418' { $mag = "WILLIAMS, JEAN-ADEL"; }
	    	case 'MJCLZ' { $mag = "WILLIAMS, MAXINE"; }
	    	case 'MJCAK' { $mag = "ZEITENBERG, TEMI"; }
	    	case 'DORLZ' { $mag = "WILLIAMS, JAMES"; }
	    	else { $mag = 'NA'; }
	    }
        
        my $cttext = $casetype;
        
		#my $cttext=getdesc($casetype,$div);
		
		# for each division...
		my $tim="$YEAR-$M2";
		if (!-d "$outpath/div$div") {
			mkdir "$outpath/div$div",0755;
		}
		$outpath2="$outpath/div$div/$tim";
		if (!-d "$outpath2") {
			mkdir("$outpath2",0755);
		}
		
		#builddivcs($div);		# write a div case style file
		
		$numpend=makelist($casetype,$div,"pend");
		$numpendwe=makelist($casetype,$div,"pendwe");
		$numpendne=makelist($casetype,$div,"pendne");
		$numro=makelist($casetype,$div,"ro");
		$numrowe=makelist($casetype,$div,"rowe");
		$numrone=makelist($casetype,$div,"rone");
		$numnopend=makelist($casetype,$div,"nopend");
		if ($numpend==0) {
			print "WARNING: no pending cases for $div\n";
		}
		
		# do DOR and Non-DOR Cases
		if($casetype eq 'Family') {
			$numpendd=makelist($casetype,$div,"pendd");
			$numpendnd=makelist($casetype,$div,"pendnd");
			$numrod=makelist($casetype,$div,"rod");
			$numrond=makelist($casetype,$div,"rond");
			$numnopendd=makelist($casetype,$div,"nopendd");
			$numnopendnd=makelist($casetype,$div,"nopendnd");
			#
			# now create the summary file for this Family division
			#
			open OUTFILE,">$outpath2/index.txt" or die "Couldn't open $outpath2/index.txt";
			print OUTFILE <<EOS;
DATE=$TODAY
TITLE1=$county Beach County
TITLE2=$cttext
PATH=case/$county/civ/div$div/$tim/
HELP=helpbannerciv
Pending Cases~$numpend~1~pend
Reopened Cases~$numro~1~ro
Other Cases~$numnopend~1~nopend
BLANK
EOS
			unlink("$outpath/div$div/index.txt");
			symlink("$outpath2/index.txt","$outpath/div$div/index.txt");
		} else {
			#
			# now create the summary file for all other divisions
			#
			open OUTFILE,">$outpath2/index.txt" or die "Couldn't open $outpath2/index.txt";
			print OUTFILE <<EOS;
DATE=$TODAY
TITLE1=$county Beach County
TITLE2=$cttext
PATH=case/$county/civ/div$div/$tim/
HELP=helpbannerciv
Pending Cases~$numpend~1~pend
Reopened Cases~$numro~1~ro
Other Cases~$numnopend~1~nopend
BLANK
EOS
			unlink("$outpath/div$div/index.txt");
			symlink("$outpath2/index.txt","$outpath/div$div/index.txt");
		}
	}
}

sub buildlastdocket {
	my $caselist = shift;
	my $dbh = shift;
	
	if (!defined($dbh)) {
		$dbh = dbConnect($dbName);
	}
	
    my %rawlastdocket;
    if ($DEBUG) {
       print "DEBUG: Reading lastdocket.txt\n";
       %lastdocket=readhash("$outpath/lastdocket.txt");
    } else {
		if($MSGS) {
			print "getting rawlastdocket - query started at ".timestamp()." \n";
		}
		
		my $count = 0;
		my $perQuery = 1000;
		
		while ($count < scalar(@{$caselist})) {
			my @temp;
			getArrayPieces($caselist, $count, $perQuery, \@temp, 1);
			
			my $inString = join(",", @temp);
			
			my $query = qq {
				SELECT
					a.CaseNumber,
					CONVERT(varchar(10), a.EffectiveDate, 101) as FilingDate,
					a.DocketCode
				FROM
					$schema.vDocket a
				INNER JOIN $schema.vCase b
					ON a.CaseID = b.CaseID
					AND b.CourtType IN $casetypes
					AND b.CaseNumber IN ($inString)
				ORDER BY
					a.EffectiveDate desc
			};
			
			getData(\%rawlastdocket, $query, $dbh, {hashkey => "CaseNumber", flatten => 1});
			
			$count += $perQuery;
		}
		
		if($MSGS) {
			my $s=keys %rawlastdocket;
			print "finished getting rawlastdocket: rows: $s - query finished at ".timestamp()." \n";
		}
		
		foreach my $case (keys %rawlastdocket) {
			if(defined $caselist{$case}) {
				$lastdocket{$case}=$rawlastdocket{$case};
			}
		}
		if($MSGS) {
			print "buildlastdocket finished parsing against caselist - ".timestamp()." \n";
		}
		
		#writehash("$outpath/lastdocket.txt",\%lastdocket);
    }
}

# Now, uses cdrdoct_filing_date rather than cdrdoct_activity_date as the last activity date.
sub buildlastactivity {
	my $caselist = shift;
	my $dbh = shift;
	
	if (!defined($dbh)) {
		$dbh = dbConnect($dbName);
	}
    
    if ($DEBUG) {
        print "DEBUG: Reading lastactivity.txt\n";
		%lastactivity = readhash("$outpath/lastactivity.txt");
    } else {
		my %rawlastactivity;
		
		my $count = 0;
		my $perQuery = 1000;
		
		while ($count < scalar(@{$caselist})) {
			my @temp;
			getArrayPieces($caselist, $count, $perQuery, \@temp, 1);
			
			my $inString = join(",", @temp);
			
			#my $query = qq {
			#	SELECT
			#		SeqPos as Sequence,
			#		c.CaseNumber,
			#		CONVERT(varchar,EffectiveDate,101) AS FilingDate,
			#		DocketCode as DocketType
			#	FROM
			#		$schema.vDocket d
			#	INNER JOIN $schema.vCase c
            #       ON d.UCN = c.UCN
			#		AND c.CourtType in $casetypes
			#		AND c.CaseNumber in ($inString)
			#	order by
			#		SeqPos desc
			#};
			
			#my $query = qq {
			#	SELECT a.CaseNumber,
			#	    CONVERT(varchar(10), MAX(a.EffectiveDate), 101) AS FilingDate,
			#		MAX(DocketCode) AS DocketType
            #    FROM $schema.vDocket a
            #   INNER JOIN $schema.vCase c
			#	    ON a.CaseID = c.CaseID
            #        AND c.CourtType IN $casetypes
			#		AND c.CaseNumber in ($inString)
            #    GROUP BY a.CaseNumber
			#};
			
			my $query = qq {
				SELECT 
					a.CaseNumber,
					CONVERT(varchar(10), MAX(a.EffectiveDate), 101) AS FilingDate,
					DocketCode as DocketType
				FROM 
					$schema.vDocket a
				INNER JOIN $schema.vCase c
					ON a.CaseID = c.CaseID
					AND c.CourtType IN $casetypes
					AND c.CaseNumber in ($inString)
				WHERE a.EffectiveDate = 
				(
					SELECT MAX(b.EffectiveDate)
					FROM $schema.vDocket b
					WHERE b.CaseID = a.CaseID
					AND b.DocketCode NOT IN ('INDIV', 'INACT')
					AND b.DocketCode NOT IN ('INDIV', 'INACT')
				)
				AND a.DocketCode NOT IN ('INDIV', 'INACT')
				GROUP BY a.CaseNumber, DocketCode
			};
			
			getData(\%rawlastactivity, $query, $dbh, {hashkey => 'CaseNumber', flatten => 1});
			
			$count += $perQuery;
		}
		
		foreach my $case (keys %rawlastactivity) {
			if (defined $caselist{$case}) {
				$lastactivity{$case} = $rawlastactivity{$case};
			}
		}
		
		#writehash("$outpath/lastactivity.txt",\%lastactivity);
    }
}

sub buildevents {
	my $caselist = shift;
	my %rawevents;
    my %rawlastevents;
    if ($DEBUG) {
        print "DEBUG: Reading events.txt\n";
	    %events=readhash("$outpath/events.txt");
    }
    else {
		
		getVrbEvents(\%rawevents, 0, $caselist);
		
		# Build a new hash with the keys having stripped dashes, so we get the match below
		#my %newRawEvents;
		#foreach my $key (keys %rawevents) {
		#	next if ($key =~ /^50/);
		#	my $strippedKey = $key;
		#	$strippedKey =~ s/-//g;
		#	$newRawEvents{$strippedKey} = $rawevents{$key};
		#}
		
		foreach my $case (keys %rawevents) {
			if( defined $caselist{$case} ) {
				$events{$case} = $rawevents{$case};
			}
		}

		#getVrbEventsByCaseList($caselist, \%rawevents, 0);
		#getVrbEventsByCaseList($caselist, \%rawlastevents, 1);
		
		#foreach my $case (keys %rawevents) {
		#	if( defined $caselist{$case} ) {
		#		$events{$case}=$rawevents{$case};
		#	}
		#}
		#
		#foreach my $case (keys %rawlastevents) {
		#	if ( defined $caselist{$case} ) {
		#		$lastevent{$case} = $rawlastevents{$case};
		#	}
		#}
    }
	
	#writehash("$outpath/events.txt",\%events);
	#writehash("$outpath/last_events.txt",\%lastevent);
}


sub buildcaselist {
    my $caselist = shift;
	my $divs = shift;
	my $dbh = shift;
	
	if (!defined($dbh)) {
		$dbh = dbConnect($dbName);
	}
	
    my $caseString = "";
    if (defined($caselist)) {
        my @temp;
        foreach my $case (@{$caselist}) {
            push(@temp,"'$case'");
        }
        $caseString = "and CaseNumber in (" . join(",", @temp) . ") ";
    }
	
	my $divStr ="";
	if (defined($divs)) {
		# This should be an array ref of the divisions.
		my @temp;
		foreach my $div (@{$divs}) {
			push(@temp, "'$div'");
		}
		my $inStr = join(",", @temp);
		$divStr = "and DivisionID in ($inStr)";
	}
    
    my ($nodiv,%divassign,%rawcase,$r);
    
    my $flagDbh = dbConnect("icms");
	my $jdbh = dbConnect("judge-divs");
	my $vrbDbh = dbConnect("vrb2");
    my $magQuery = qq {
        select
            division,
            SUBSTRING_INDEX(magistrate_type, '/', -1) AS magistrate_type,
            last_name,
            first_name,
            middle_name,
            SUBSTRING_INDEX(flagtype, '/', -1) AS flagtype,
            SUBSTRING_INDEX(hearing_room, '/', -1) AS hearing_room
        from
            magistrates
        where
            (magistrate_type like '%Family%')
            or (magistrate_type like '%DOR%')
        order by
            division
    };
    getData(\%divassign, $magQuery, $jdbh, {hashkey => 'division', flatten => 1});
    
    my $masterFlagStr;
    my $divCount = 0;
    my $query;
    foreach my $divID (keys %divassign) {
        $divlist{$divID} = $divassign{$divID}->{'magistrate_type'} . ' MAGISTRATE ' . $divassign{$divID}->{'last_name'} . ', ' . $divassign{$divID}->{'first_name'} . ' ' . $divassign{$divID}->{'middle_name'};
    	
    	my %tempFlags;
    	my @magistrateFlags;
    	my $flagQuery = qq{
    		SELECT casenum
    		FROM flags
    		WHERE flagtype = ?
    		AND active = 1
    	};
    	
    	getData(\%tempFlags, $flagQuery, $flagDbh, {valref => [$divassign{$divID}->{'flagtype'}], hashkey => "casenum"});
	    foreach my $cn (keys %tempFlags) {
			push(@magistrateFlags, "'$cn'");
		}
		
		my %tempEvents;
    	my $eventQuery = qq{
    		SELECT DISTINCT case_num
    		FROM events e
    		INNER JOIN event_cases ec
    			ON e.event_id = ec.event_id
    			AND ec.canceled = 0
    		WHERE division = ?
    		AND e.canceled = 0
    		AND e.start_date > NOW()
    	};
    	
    	getData(\%tempEvents, $eventQuery, $vrbDbh, {valref => [$divID], hashkey => "case_num"});
	    foreach my $cn (keys %tempEvents) {
			push(@magistrateFlags, "'$cn'");
		}
		
		my $flagStr = join(",", @magistrateFlags);
		if($flagStr eq ''){
			$flagStr = "'x'";
		}
		$masterFlagStr .= $flagStr;
		
		if($divCount ne 0){
			$query .= qq{
				UNION
			};
		}
		
		$query .= qq{
			SELECT DISTINCT c.UCN,
				c.CaseNumber,
				c.DivisionID AS Actual_DivisionID,
				c.CourtType,
				c.CaseStatus,
				CONVERT(varchar(10), DispositionDate, 101) AS DispositionDate,
				CONVERT(varchar(10), FileDate, 101) AS FileDate,
				CONVERT(varchar(10), ReopenDate, 101) AS ReopenDate,
				CONVERT(varchar(10), ReopenCloseDate, 101) AS ReopenCloseDate,
				c.CaseType,
				'$divID' AS DivisionID,
				NEWID() as CaseKey
			FROM 
				$schema.vCase c
			WHERE CaseStatus not in $NOTACTIVE
				AND Sealed = 'N' 
				AND Expunged = 'N'
				$caseString $divStr	
				AND CaseNumber IN ($flagStr)	
		};
		
		$divCount++;
    	
    }
    
    # keys=all divisions in use; values=# cases in each
    if ($DEBUG) {
        print "DEBUG: Reading rawcase.txt\n";
		%rawcase=readhash("$outpath/rawcase.txt");
    } else {
		if($MSGS) {
			print "doing rawcase sql... ".timestamp()."\n";
		}
		# simplified....
		$query .= qq {	
			UNION			
				select
					DISTINCT c.UCN,
					c.CaseNumber,
					c.DivisionID AS Actual_DivisionID,
					c.CourtType,
					c.CaseStatus,
					CONVERT(varchar(10), DispositionDate, 101) AS DispositionDate,
					CONVERT(varchar(10), FileDate, 101) AS FileDate,
					CONVERT(varchar(10), ReopenDate, 101) AS ReopenDate,
					CONVERT(varchar(10), ReopenCloseDate, 101) AS ReopenCloseDate,
					c.CaseType,
					CASE 
		};
		
		foreach my $divID (keys %divassign) {
			$query .= qq {
			 	WHEN (
			 		REPLACE(REPLACE(REPLACE(REPLACE(MagistrateRoom,' ','\{\}'),'\}\{',''),'\{\}',' '), '#', '') = 'ROOM $divassign{$divID}->{'hearing_room'}' 
			 		OR REPLACE(SUBSTRING(MagistrateRoom, 0, CHARINDEX(' ', MagistrateRoom, CHARINDEX(' ', MagistrateRoom, 0) +1)), '#', '') = 'ROOM $divassign{$divID}->{'hearing_room'}' 
			 	)
				THEN '$divID'
			};
		}
		
		$query .= qq { 
					ELSE 'XXX'
					END AS DivisionID,
					NEWID() as CaseKey
				from
					$schema.vCase c with(nolock)
				inner join
					$schema.vDocket d
						ON c.CaseID = d.CaseID
						AND d.DocketCode IN('ORGM', 'NAGM', 'NOC', 'POWR')
						AND c.CaseNumber NOT IN ($masterFlagStr)
				where
					c.CaseStatus not in $NOTACTIVE
					AND c.CourtType in $casetypes
					AND Sealed = 'N' 
					AND Expunged = 'N'
					$caseString $divStr						
		};

		getData(\%rawcase, $query, $dbh, {hashkey => "CaseKey", flatten => 1});
		
		#Cases to remove
		foreach my $caseKey (sort keys %rawcase) {
			
			if($rawcase{$caseKey}->{'DivisionID'} eq 'XXX'){
				delete $rawcase{$caseKey};
			}
				
			my $room;
			foreach my $divID (keys %divassign) {
				if($divID eq $rawcase{$caseKey}->{'DivisionID'}){
					$room = "ROOM " . $divassign{$divID}->{'hearing_room'};
				}
			}
			
			my %removeData;
			my $removeQuery = qq{
				SELECT 
					'Out' AS Type, 
					COUNT(DocketCode) AS Count
				FROM 
					$schema.vDocket
				WHERE 
					DocketCode IN('GMDF', 'POWR')
				AND 
					CaseNumber = ?
				AND 
					CaseNumber NOT IN ($masterFlagStr)	
				AND 
					CAST(EffectiveDate AS Date) >= '2016-03-01'
				AND (	
						REPLACE(REPLACE(REPLACE(REPLACE(MagistrateRoom,' ','\{\}'),'\}\{',''),'\{\}',' '), '#', '') = ?	
						OR REPLACE(SUBSTRING(MagistrateRoom, 0, CHARINDEX(' ', MagistrateRoom, CHARINDEX(' ', MagistrateRoom, 0) +1)), '#', '') = ?
				)
				UNION
				SELECT 
					'In' AS Type,  
					COUNT(DocketCode) AS Count
				FROM 
					$schema.vDocket
				WHERE 
					DocketCode IN('ORGM', 'NAGM', 'NOC', 'POWR')
				AND 
					CaseNumber = ?
				AND 
					CaseNumber NOT IN ($masterFlagStr)	
				AND 
					CAST(EffectiveDate AS Date) >= '2016-03-01'
				AND (	
					REPLACE(REPLACE(REPLACE(REPLACE(MagistrateRoom,' ','\{\}'),'\}\{',''),'\{\}',' '), '#', '') = ?
					OR REPLACE(SUBSTRING(MagistrateRoom, 0, CHARINDEX(' ', MagistrateRoom, CHARINDEX(' ', MagistrateRoom, 0) +1)), '#', '') = ?
				)
			};
				
			getData(\%removeData, $removeQuery, $dbh, {valref => [$rawcase{$caseKey}->{'CaseNumber'}, $room, $room, $rawcase{$caseKey}->{'CaseNumber'}, $room, $room], hashkey => "Type", flatten => 1});
				
			if($removeData{'Out'}->{'Count'} >= $removeData{'In'}->{'Count'} && ($removeData{'Out'}->{'Count'} > 0)){
				delete $rawcase{$caseKey};
			}
		}
		
		my $key;
		my $value;
		my %rawcase2;
		while(($key, $value) = each %rawcase) {
		   $rawcase2{$value->{'CaseNumber'}} = $rawcase{$key};
		}
		
		%rawcase = %rawcase2;
		
		if($MSGS) {
			$r = keys %rawcase;
			print "got all the rawcase rows - $r of them ".timestamp()."\n";
		}
    }
	
	if($MSGS) {
		print "coursing through rawcase hash - filling caselist... ".timestamp()."\n";
	}
	
	foreach my $casenum (sort keys %rawcase) {
		my $rec = $rawcase{$casenum};
		my $div = $rec->{'DivisionID'};
		my $desc = $rec->{'CaseStyle'};
		my $status = $rec->{'CaseStatus'};
		my $casetype = $rec->{'CourtType'};
		my $filedate = $rec->{'FileDate'};
		my $dispodate = $rec->{'DispositionDate'};
		my $reopendate = $rec->{'ReopenDate'};
		my $reopenclosedate = $rec->{'ReopenCloseDate'};
		my $ctyp = $rec->{'CaseType'};
		my $real_div = $rec->{'Actual_DivisionID'};
		
		if ($div eq "") {
			$nodiv++;
			write_nodiv_file("$outpath/nodiv_civcases.txt","$casenum, status=$status \n");
		}
		
		$caselist{$casenum}="$div~$desc~$status~$casetype~$filedate~$dispodate~$reopendate~$reopenclosedate~$ctyp~$real_div";
        
        if ($reopencodes=~/,$status,/) {
			# a reopened case
			$reopened{$casenum}=1;
		}
		
		if ($othercodes=~/,$status,/) { # an 'other' case
			$others{$casenum}=1;
		}
	
    }
	
	if($MSGS) {
		print "$nodiv Cases with No Division!\n";
	}
	
	write_nodiv_file("$outpath/nodiv_civcases.txt","$nodiv cases with no division");
	writehash("$outpath/caselist.txt",\%caselist);
	writehash("$outpath/reopened.txt",\%reopened);
	writehash("$outpath/others.txt",\%others);
	if($MSGS) {
		print "done building caselist ".timestamp()."\n";
	}
}


# builddivcs  fills the %divcs hash with a text style for each case in this division.
sub builddivcs {
    my $thisdiv = shift;
    
    my %divcs=();
    
    if(onlinediv($thisdiv) eq "true") {
	if($MSGS) {
	    print "building divcs for div $thisdiv - started at ".timestamp()."\n";
	}
	
	# will build the all cases list the first time a div w/ online scheduing is done
	if( scalar %allcases == 0 ) {
	    no strict 'refs';
	    buildallcases();
	}
	
	foreach my $case (keys %allcases) {
	    my($divid,$desc)=split '~',$allcases{$case};
	    if($thisdiv eq $divid) {
		$divcs{$case}=$desc;
	    }
	}
	
	writehash("$outpath/div$thisdiv/divcs.txt",\%divcs);
        if($MSGS) {
	    print "finished building divcs for div $thisdiv - finished at ".timestamp()."\n";
	}
    }
}

# Get all cases (not just active) - needed for online scheduling.
# Don't do it if no divisions in online scheduling.
# Also, not saving all cases to a text file because they're too big!
sub buildallcases {
    if($MSGS) {print "building allcases - started at ".timestamp()."\n";}
	if(scalar @OLSCHEDULING > 0) {
		my (%all);
		# don't exclude closed cases
		%all=sqllookup("SELECT c.CaseNumber,
					   DivisionID,
					   CaseStyle
						FROM $schema.vAllParties p
						INNER JOIN $schema.vCase c
						  ON p.CaseID = c.CaseID
						  AND c.CourtType in $casetypes
						  AND Sealed = 'N'
						  AND Expunged = 'N'
						WHERE
						  p.Active = 'Y'
						  AND (p.Discharged = 0 OR p.Discharged IS NULL)
						  AND PartyTypeDescription in ('JUDGE','DEFENDANT','PLAINTIFF', 'DEFENDANT/RESPONDENT', 'PLAINTIFF/PETITIONER')", $dbh);
		foreach my $casenum (sort keys %all) {
			$allcases{$casenum}=$all{$casenum};
		}
	}
    if($MSGS) {print "finished building allcases - finished at ".timestamp()."\n";}
}

sub getScCaseAge {
    # Calculate the age of a case.  If a case is reopened, then the age is
    # calculated from the date of the reopen.  If a case is closed, then the age
    # calculation will stop with the close date.
    my $filedate = shift;
    my $dispodate = shift;
    my $reopendate = shift;
    my $reopenclosedate = shift;
    my $status = shift;
    my $dbh = shift;
    
	if (!defined($dbh)) {
		$dbh = dbConnect($dbName);
	}
    
    my $openDate = $filedate;
    # Default to today.  Overrides below.
    my $endDate = today();
    
    if ((defined($reopendate)) && ($reopendate ne '')) {
		# A reopened case
		$openDate = $reopendate;
		if ((defined($reopenclosedate)) && ($reopenclosedate ne '')) {
		    # A reopened and then re-disposed case with a reopen disposition date
		    if (inArray(['Closed','Disposed'], $status)) {
				$endDate = $reopenclosedate;
		    }
		}
    } elsif ((defined($dispodate)) && ($dispodate) ne '') {
		# A case that wasn't reopened but has been disposed.
		$endDate = $dispodate;
    }
    
    # We want the dates in the same format
    if ($endDate =~ /(\d\d\d\d)-(\d\d)-(\d\d)/) {
		$endDate = sprintf("%02d/%02d/%04d", $2, $3, $1);
    }
    
    if ($openDate =~ /(\d\d\d\d)-(\d\d)-(\d\d)/) {
		$openDate = sprintf("%02d/%02d/%04d", $2, $3, $1);
    }
    
    my ($mt,$dt,$yt) = split(/[-\/]/,$endDate);
    my ($mc,$dc,$yc) = split(/[-\/]/,$openDate);
    
    my $days;

    if (defined $yc) {
		$days = Delta_Days($yc,$mc,$dc,$yt,$mt,$dt);
    } else {
		$days = 0;
    }
    
    return $days;
}


sub doit() {
    my @divlist;
	
	GetOptions ("d:s" => \@divlist);
	
    if($MSGS) {
		print "starting civil reports scfam_mag ".timestamp()."\n";
    }

    if (@ARGV==1 and $ARGV[0] eq "DEBUG") {
		$DEBUG=1;
		print "DEBUG!\n";
    }
    $outpath="/var/www/$county/civ";
    $webpath="/case/$county/civ";
    #dbConnect($dbName);
    my $dbh = dbConnect($dbName);
	
    rename("$outpath/nodiv_civcases.txt", "$outpath/nodiv_civcases.txt_prev");
    
	if (scalar(@divlist)) {
		my $divStr = join(",", @divlist);
		
		print "Restricting to division $divStr...\n";
		
		if($MSGS) {
			print "starting buildcaselist ".timestamp()."\n";
		}
		buildcaselist(undef, \@divlist, $dbh);
	} else {
		print "Using all divs.\n";

		if($MSGS) {
			print "starting buildcaselist ".timestamp()."\n";
		}
		buildcaselist(undef, undef, $dbh);
	}
    
	my @justcases = keys(%caselist);
	
	if($MSGS) {
		#print "starting updateCaseNotes ".timestamp()."\n";
    }
	
	#updateCaseNotes(\%caselist,\@casetypes);
	
	buildNoHearings(\@justcases, \%noHearings);
    
    if($MSGS) {
		print "starting buildlastdocket ".timestamp()."\n";
    }
    buildlastdocket(\@justcases, $dbh);
	
	if($MSGS) {
		print "starting buildlastactivity ".timestamp()."\n";
    }
    buildlastactivity(\@justcases,$dbh);
    
    if($MSGS) {
		print "starting buildevents ".timestamp()."\n";
    }
    buildevents(\@justcases);
	
    #if($MSGS) {
	#	print "starting buildnotes ".timestamp()."\n";
    #}
	#buildnotes(\%merged, \%flags, $casetypes, $outpath, $DEBUG);
	
    if($MSGS) {
		print "starting buildPartyList ".timestamp()."\n";
    }
    #buildPartyList(\%partylist,,$ndbh);
	buildPartyListMag(\%partylist, $outpath, \@justcases, $dbh);
	
    if($MSGS) {
		print "starting buildstyles ".timestamp()."\n";
    }
    buildstyles;
	
    if($MSGS) {
		print "starting report ".timestamp()."\n";
    }
    report;
	
    if($MSGS) {
		print "all done with civil reports scfam_mag ".timestamp()."\n";
    }
}

#
# MAIN PROGRAM STARTS HERE!
#

doit();
