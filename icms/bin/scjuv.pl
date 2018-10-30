#!/usr/bin/perl
#

BEGIN {
	use lib "$ENV{'PERL5LIB'}";
}

use strict;
use ICMS;
use Showcase qw (
	$ACTIVE
	$NOTACTIVE
);
use Casenotes qw (
    mergeNotesAndFlags
	updateCaseNotes
	buildnotes
);
use DB_Functions qw (
    dbConnect
	getData
	getDataOne
	doQuery
	getDbSchema
	getVrbEvents
);
use Showcase::Reports qw (
	buildPartyList
);
use Common qw (
	dumpVar
	inArray
	@skipHack
	getArrayPieces
	getShowcaseDb
);

use Reports qw (
    getVrbEventsByCaseList
    getLastDocketFromList
	buildNoHearings
);
use Getopt::Long;


my $DEBUG=0;  # will read txt files if set to 1
my $MSGS=1;   # will spit out diag msgs if set to 1

# No output buffering
$| = 1;

my $dbName = getShowcaseDb();
my $schema = getDbSchema($dbName);
my $dbh = dbConnect($dbName);

my $outpath;
my $outpath2;
my $webpath;
my $county="Palm";
#my %allcases; # set in buildallcases
my %caselist; # set in buildcaselist
my %divlist;  # set in buildcaselist
my %doblist;
my %critdesc=(
	"pend" => "Pending Cases - All",
    "penddel"=>"Pending Cases - Delinquency",
    "penddep"=>"Pending Cases - Dependency",
    "warrdel"=>"Outstanding Warrants - Delinquency",
    "warrdep"=>"Outstanding Warrants - Dependency",
    "nopenddel"=>"Other Cases - Delinquency",
    "nopenddep"=>"Other Cases - Dependency",
	"ro" => "Reopened Cases - All",
    "rodel"=>"Reopened Cases - Delinquency",
    "rodep"=>"Reopened Cases - Dependency",
    "pendnedel"=>"Pending Cases with No Events Scheduled - Delinquency",
    "pendnedep"=>"Pending Cases with No Events Scheduled - Dependency",
    "pendwedel"=>"Pending Cases with Events Scheduled - Delinquency",
    "pendwedep"=>"Pending Cases with Events Scheduled - Dependency",
    "rowedel"=>"Reopened Cases with Events Scheduled - Delinquency",
    "rowedep"=>"Reopened Cases with Events Scheduled - Dependency",
    "ronedel"=>"Reopened Cases with No Events Scheduled - Delinquency",
    "ronedep"=>"Reopened Cases with No Events Scheduled - Dependency",
);

my %warrants; # set in buildwarrants
my %charges;  # set in buildcharges
my %caseCharges; # a hash keyed on just the casenumber, pointing to an array of hash refs
my %chargepending; # set in buildcharges
my %chargecnt; # set in buildcharges
my %lastdocket; # set in buildlastdocket
my %lastactivity; # set in buildlastactivity
my %reopened; # set in buildcaselist
my %noHearings;
my %partylist;
my %style;

my %shelterHearings;
my %depDisposed;

my $reopencodes=",Reopen,";

my %magcases; # set in flagFanelli - to flag magistrate cases

my %events;
my %flags;
my %merged;	# merged notes and flags
my $icmsdb='ok'; # status of icms database when run - 'ok' or 'bad'

my @casetypes = ('CJ','DP');
my $casetypes="('CJ','DP')";

# closed status codes for Juvenile
# will get these based on inactivecodes in icms.pm

# cdbcase_sealed_ind  3 - sealed/expunged?

#
# this is for civil cases only..leaves off that final -A
#
sub casenumtoucn {
    my($casenum)=@_;
    #return substr($casenum,0,4)."-".substr($casenum,4,2)."-".substr($casenum,6,6);
	return $casenum;
}

#
# get list of child's dobs for report
#
sub builddobs {
	my $caselist = shift;
    my %rawdobs;
    if ($DEBUG) {
     	print "DEBUG: Reading dobs.txt\n";
	%doblist=readhash("$outpath/dobs.txt");
    } else {
		
		my $count = 0;
		my $perQuery = 1000;
		
		while ($count < scalar(@{$caselist})) {
			my @temp;
			
			getArrayPieces($caselist, $count, $perQuery, \@temp, 1);
			my $inString = join(",", @temp);
			
			%rawdobs=sqlhash("SELECT CaseNumber,
							  1 AS SeqNo,
							  PersonID,
							  CONVERT(VARCHAR(10), DOB, 101) AS DOB
							  FROM $schema.vAllParties
							  WHERE CaseNumber IN ($inString) 
							  AND ( 
							  	PartyType = 'CHLD'
								  OR (
								  	PartyType = 'HYBRID'
								  	AND PartyTypeDescription = 'CHILD (CJ)'
								  )
								)", 2, $dbh);
			foreach (keys %rawdobs) {
				$doblist{$_}=$rawdobs{$_};
			}
		
			$count += $perQuery;
		}
		
		#foreach my $case (keys %caselist) {
		#	%rawdobs=sqlhash("SELECT CaseNumber,
		#					  1 AS SeqNo,
		#					  PersonID,
		#					  DOB
		#					  FROM $schema.vAllParties
		#					  WHERE CaseNumber='$case' 
		#					  AND PartyType = 'CHLD'", 2, $dbh);
		#	foreach (keys %rawdobs) {
		#		$doblist{$_}=$rawdobs{$_};
		#	}
		#}
		writehash("$outpath/dobs.txt",\%doblist);
    }
}

#
# getfirstchilddob - pulls the dob of the first child found in the doblist
#
sub getfirstchilddob {
	my($dob,$case_id,$i,$key);
	if (scalar keys %doblist==0) {
		die "scjuv.pl: getfirstchilddob: doblist is empty.";
	}
	$case_id=$_[0];
	$dob=" ";
	foreach $i (1..30) {  # 30 parties max
		$key="$case_id;$i";
		if (!defined $doblist{$key}) {
			next;
		}
		$dob=(split '~',$doblist{$key})[3];
		last; # found what we're looking for - - 1st child - get out
	}
	return $dob;
}

#
# This routine marks all of Magistrate Fanelli's cases - - she is flag # 75.
#
# This is very specialized code for this particular magistrate.
#
sub flagfanelli {
    my %rawmagcases;
	my $thisflag=75;		# this is magistrate fanelli's flag number!
	my ($res,$x);
	if ($DEBUG) {
		print "DEBUG: Reading mag75cases.txt\n";
		%magcases=readhash("$outpath/mag75cases.txt");
	} else {
		my $query = qq {
			SELECT
			a.CaseNumber,
			a.DocketCode,
			c.DivisionID
		FROM
			$schema.vDocket a
		INNER JOIN $schema.vCase c
			ON a.CaseID = c.CaseID
			AND c.CourtType = 'DP'
			AND c.DivisionID in ('JK','JL','JO')
		WHERE
			a.DocketCode in ('ORGM','OTJF','OTJSF','OTDF','OTSF')
		};
		%rawmagcases = sqlhash($query, 2, $dbh);
		foreach my $case (sort keys %rawmagcases) {
			if( defined $caselist{$case} ) {
				$magcases{$case}=$rawmagcases{$case};
			}
		}
		writehash("$outpath/mag75cases.txt",\%magcases);
	}

    # flag each case as magistrate faneilli's (put it into the flags table)
	my $icmsconn = dbConnect("icms");
	if (defined($icmsconn)) {
		foreach (keys %magcases) {
			my($doc_id,$doc_code,$case_div)=split '~',$magcases{$_};
			my $fcn=casenumtoucn($doc_id);
			#  check to make sure flag for that case isn't already set.
			my  $res=sqllookup("select b.dscr from flags a,flagtypes b where a.flagtype=b.flagtype and casenum='$fcn' and a.flagtype='$thisflag'");
			# if found, delete record and insert new
			if ($res ne "") {
				$res=sqldel("delete from flags where flagtype='$thisflag' and casenum='$fcn'");
			}
			$res=sqlin("insert into flags (casenum,userid,date,flagtype) values ('$fcn','icms','$TODAY',$thisflag)");
		} #end foreach
	} else {
		print "problem!  no icms database connection while processing magistrate fanelli's cases.  Cases not marked. \n";
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

sub makelist {
    my $casetype = shift;
    my $thisdiv = shift;
    my $crit = shift;
    
    my @list;
	my @noEventList;
	my @noShelterDepList;
	
    if (!$critdesc{$crit}) {
        die "invalid criteria $crit\n";
    }
    
    my $cttext;
    $cttext=getdesc($casetype,$thisdiv);

    foreach my $case (keys %caselist) {

        my($div,$desc,$status,$casetype,$filedate,$ctyp)=split '~',$caselist{$case};

		next if (inArray(\@skipHack,$status));
		
        if ($thisdiv ne $div) {
            next;
        }

        # check for suppress flag...
        my $ucn=casenumtoucn($case);
        if ($flags{"$ucn;2"}) {
            # we have a suppress
            my $flagdate=(split '~',$flags{"$ucn;2"})[2];
            my $lastdockdate=(split '~',$lastdocket{$case})[1];
            # if the last docket date is < flagdate, then skip
            if (compdate($lastdockdate,$flagdate)==-1) {
                next;
            }
        }
        
        if ($crit=~/^pend/) {
            # pending cases
            if ($crit =~ /^pendne/ and defined($events{$case}->{'CourtEventDate'})) {
                next;
            }
            if ($crit =~ /^pendwe/ and !defined($events{$case}->{'CourtEventDate'})) {
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
        } elsif ($crit =~ /^warr/) {
            if (!$warrants{$case}) {
                # skip if NO warrant outstanding
                next;
            } 
        } elsif ($crit=~/^ro/) {
            if ($crit =~ /^rone/ and defined($events{$case}->{'CourtEventDate'})) {
                next;
            }
            if ($crit =~ /^rowe/ and !defined($events{$case}->{'CourtEventDate'})) {
                next;
            }
            if ($warrants{$case}) {
                # skip if warrant outstanding
                next;
            } 
            if (!$reopened{$case}) {
                # skip if not reopened
                next;
            }
        }
        
        # Now, is it a delinquency case or a dependency case?
        # If it's a delinquency case (CJ), then $crit must end in "del"
        if (($case =~ /CJ/) && (($crit !~ /del$/) && ($crit ne "pend") && ($crit ne "ro"))) {
            next;
        }
        
        if (($case !~ /CJ/) && (($crit =~ /del$/) && ($crit ne "pend") && ($crit ne "ro"))) {
            next;
        }
        
        my $age=getage($filedate);
		my $dob=getfirstchilddob($case);
		$desc = (split '~', $style{$case})[0];
		my $evcode = $events{$case}->{'CourtEventType'};
		my $evdate = $events{$case}->{'CourtEventDate'};
		my $ladate = (split '~',$lastactivity{$case})[1];
        my $charges;
        my $casenum = $ucn;
        $casenum =~ s/-//g;
        if (defined($caseCharges{$casenum})) {
            $charges = "<ul>";
            my @tmpChrg;
            foreach my $charge (@{$caseCharges{$casenum}}) {
                push (@tmpChrg, "<li>$charge->{'Desc'}</li>");
            }
            $charges .= join(" ", @tmpChrg);
            $charges .= "</ul>";
        }
        	
		my $listString;
	
		if ($crit =~ /dep/) {
			# Don't show charges for dependency
			$listString = "$ucn~$desc~$dob~$filedate~$age~$ctyp~$status~$ladate~$evcode~$evdate~$merged{$ucn}\n";
		} else {
			my $chgs = $chargecnt{$case};
			$listString = "$ucn~$desc~$dob~$filedate~$age~$ctyp~$status~$ladate~$chgs~$charges~$evcode~$evdate~$merged{$ucn}\n";
		}
		
		
        push(@list, $listString);
		if (defined($noHearings{$ucn})) {
			push(@noEventList, $listString);
		}
		
		if ($crit =~ /dep/) {
			if (defined($shelterHearings{$ucn})) {
				# There was a shelter hearing requested for this case. Was it disposed?
				if (!defined($depDisposed{$ucn})) {
					push(@noShelterDepList, $listString)
				}
			}
		} elsif ($crit =~ /del/) {
			# Do delinquencey stuff here.
		}
		
    }
    
	if ($crit =~ /dep/) {
		my $outFile = sprintf("%s/%s.txt", $outpath2, $crit);
	
		open(OUTFILE,">$outFile") ||
			die "Couldn't open '$outFile' for writing: $!\n\n";
		my $fntitle = "Flags/Most Recent Note";
		if($icmsdb eq 'bad') {
			$fntitle.="<br/>* Not Current *";
		}
		print OUTFILE <<EOS;
DATE=$TODAY
TITLE1=$county Beach County - $cttext Division $thisdiv
TITLE2=$critdesc{$crit}
VIEWER=view.cgi
FIELDNAMES=Case #~Name~DOB~Initial File~Age~Type~Status~Last Activity~Event Code~Latest / Farthest Event~$fntitle
FIELDTYPES=L~I~D~D~G~S~A~D~A~D~A
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
FIELDNAMES=Case #~Name~DOB~Initial File~Age~Type~Status~Last Activity~Event Code~Latest / Farthest Event~$fntitle
FIELDTYPES=L~I~D~D~G~S~A~D~A~D~A
EOS
		print OUTFILE @noEventList;
		close(OUTFILE);
	
		
		$outFile = sprintf("%s/%s_shelterUndisposed.txt", $outpath2, $crit);
		open(OUTFILE,">$outFile") ||
			die "Couldn't open '$outFile' for writing: $!\n\n";
		print OUTFILE <<EOS;
DATE=$TODAY
TITLE1=$county Beach County - $cttext Undisposed Shelter Hearings Division $thisdiv
TITLE2=$critdesc{$crit}
VIEWER=view.cgi
FIELDNAMES=Case #~Name~DOB~Initial File~Age~Type~Status~Last Activity~Event Code~Latest / Farthest Event~$fntitle
FIELDTYPES=L~I~D~D~G~S~A~D~A~D~A
EOS
		print OUTFILE @noShelterDepList;
		close(OUTFILE);
	} elsif ($crit =~ /del/) {
		# DELINQUENCY
		my $outFile = sprintf("%s/%s.txt", $outpath2, $crit);
	
		open(OUTFILE,">$outFile") ||
			die "Couldn't open '$outFile' for writing: $!\n\n";
		my $fntitle = "Flags/Most Recent Note";
		if($icmsdb eq 'bad') {
			$fntitle.="<br/>* Not Current *";
		}
		print OUTFILE <<EOS;
DATE=$TODAY
TITLE1=$county Beach County - $cttext Division $thisdiv
TITLE2=$critdesc{$crit}
VIEWER=view.cgi
FIELDNAMES=Case #~Name~DOB~Initial File~Age~Type~Status~Last Activity~# of Charges~Charges~Event Code~Latest / Farthest Event~$fntitle
FIELDTYPES=L~I~D~D~G~S~A~D~C~I~A~D~A
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
FIELDNAMES=Case #~Name~DOB~Initial File~Age~Type~Status~Last Activity~# of Charges~Charges~Event Code~Latest / Farthest Event~$fntitle
FIELDTYPES=L~I~D~D~G~S~A~D~C~I~A~D~A
EOS
		print OUTFILE @noEventList;
		close(OUTFILE);
	
		
		$outFile = sprintf("%s/%s_shelterUndisposed.txt", $outpath2, $crit);
		open(OUTFILE,">$outFile") ||
			die "Couldn't open '$outFile' for writing: $!\n\n";
		print OUTFILE <<EOS;
DATE=$TODAY
TITLE1=$county Beach County - $cttext Undisposed Shelter Hearings Division $thisdiv
TITLE2=$critdesc{$crit}
VIEWER=view.cgi
FIELDNAMES=Case #~Name~DOB~Initial File~Age~Type~Status~Last Activity~# of Charges~Charges~Event Code~Latest / Farthest Event~$fntitle
FIELDTYPES=L~I~D~D~G~S~A~D~C~I~A~D~A
EOS
		print OUTFILE @noShelterDepList;
		close(OUTFILE);
		# do delinquency stuff here
	}
	
	return scalar @list;
}

sub write_nodiv_file
{
    my ($f, @nodiv_case) = @_;
    @nodiv_case = () unless @nodiv_case;
    open (F, ">>$f");
    print F @nodiv_case, "\n";
    close F;
}


# take a casetype and return a "nice" string

sub getdesc {
    my $casetype=$_[0];
    my $div=$_[1];
	if ($div eq "") { return "Juvenile No "; }
    elsif ( ($div eq "JK") || ($div eq "JL") || ($div eq "JM") ||
($div eq "JO") || ($div eq "JA") || ($div eq "DG") || ($div eq "JS"))
    { return "Juvenile"; }
    else { print "Error: unknown casetype of $casetype\n"; }
}

sub report {

    if ($DEBUG) {
        print "DEBUG: Building report files\n";
    }
    
    # Build a hash of the charges, keyed on just the case number - it'll be MUCH easier to work with
    my %chargeHash;
    

    foreach my $div (keys %divlist) {
        my $casetype=$divlist{$div};
		my $cttext=getdesc($casetype,$div);
        # for each division...
        my $tim="$YEAR-$M2";
 		if (!-d "$outpath/div$div") { mkdir "$outpath/div$div",0755; }
		$outpath2="$outpath/div$div/$tim";
		if (!-d "$outpath2") { mkdir("$outpath2",0755); }

		#builddivcs($div);		# write a div case style file

		my $numpend = makelist($casetype,$div,"pend");
		my $numpenddel = makelist($casetype,$div,"penddel");
        my $numpenddep = makelist($casetype,$div,"penddep");
		my $numpendwedel = makelist($casetype,$div,"pendwedel");
        my $numpendwedep = makelist($casetype,$div,"pendwedep");
        my $numpendnedel = makelist($casetype,$div,"pendnedel");
        my $numpendnedep = makelist($casetype,$div,"pendnedep");
        my $numwarrdel = makelist($casetype,$div,"warrdel");
        my $numwarrdep = makelist($casetype,$div,"warrdep");
		my $numro = makelist($casetype,$div,"ro");
        my $numrodel = makelist($casetype,$div,"rodel");
        my $numrodep = makelist($casetype,$div,"rodep");
        my $numrowedel = makelist($casetype,$div,"rowedel");
        my $numrowedep = makelist($casetype,$div,"rowedep");
        my $numronedel = makelist($casetype,$div,"ronedel");
        my $numronedep = makelist($casetype,$div,"ronedep");
#        my $numnopend=makelist($casetype,$div,"nopend");
        if (($numpenddel == 0)  && ($numpenddep == 0)) {
            print "WARNING: no pending cases for $div\n";
        }
        #
        # now create the summary file for this division
        #
        open OUTFILE,">$outpath2/index.txt" or die "Couldn't open $outpath2/index.txt";
        print OUTFILE <<EOS;
DATE=$TODAY
TITLE1=$county Beach County
TITLE2=$cttext Division $div
PATH=case/$county/juv/div$div/$tim/
HELP=helpbannerciv
Pending Cases - Dependency~$numpenddep~1~penddep
With Events - Dependency~$numpendwedep~2~pendwedep
With No Events - Dependency~$numpendnedep~2~pendnedep
Reopened Cases - Dependency~$numrodep~1~rodep
With Events - Dependency~$numrowedep~2~rowedep
With No Events - Dependency~$numronedep~2~ronedep
BLANK
Pending Cases - Delinquency~$numpenddel~1~penddel
With Events - Delinquency~$numpendwedel~2~pendwedel
With No Events - Delinquency~$numpendnedel~2~pendnedel
Reopened Cases - Delinquency~$numrodel~1~rodel
With Events - Delinquency~$numrowedel~2~rowedel
With No Events - Delinquency~$numronedel~2~ronedel
BLANK
Outstanding Warrants~$numwarrdel~1~warr
EOS
        unlink("$outpath/div$div/index.txt");
        symlink("$outpath2/index.txt","$outpath/div$div/index.txt");
        }

    }

sub buildwarrants {
    my(%rawwarrants);
    if ($DEBUG) {
        print "DEBUG: Reading warrants.txt\n";
	    %warrants=readhash("$outpath/warrants.txt");
    }
    else {
	   # get all warrants
	   # cobdreq_evnt_code = 'JPU'?? @todo
	   %rawwarrants=sqllookup("SELECT w.CaseNumber
							   FROM $schema.vWarrant w
							   INNER JOIN $schema.vCase c
								ON w.CaseID = c.CaseID
								AND c.CourtType = 'CJ'
							   WHERE w.Closed = 'N'", $dbh);
       writehash("$outpath/rawwarrants.txt",\%rawwarrants);
       foreach my $c (keys %rawwarrants) {
	   		if( defined $caselist{$c} ) {
	             #print "OUTSTANDING WARRANT: $c \n";
    	         $warrants{$c}=1;
			}
       }
	   if($MSGS) {
	      print scalar keys %rawwarrants," raw Outstanding warrants\n";
          print scalar keys %warrants," Outstanding warrants for cases we want \n";
	   }
       writehash("$outpath/warrants.txt",\%warrants);
	}
}

sub buildcharges {
    my %rawcharges;
    if ($DEBUG) {
        print "DEBUG: Reading charges.txt\n";
        %charges=readhash("$outpath/charges.txt");
		%chargecnt=readhash("$outpath/chargecnt.txt");
    }
    else {
       %rawcharges=sqlhash("SELECT h.CaseNumber,
							h.ChargeCount,
							CONVERT(VARCHAR(10), h.ChargeDate, 101),
							h.CourtStatuteNumber,
							h.CourtStatuteNumSubSect,
							h.CourtStatuteDescription,
							h.CourtStatuteLevel,
							h.CourtStatuteDegree,
							h.Disposition,
							CONVERT(VARCHAR(10), h.DispositionDate, 101),
							1 as fcic
							FROM $schema.vCharge h
							INNER JOIN $schema.vCase c
								ON h.CaseID = c.CaseID
								AND h.CourtType IN ('CJ') ", 2, $dbh);
       foreach my $charge (keys %rawcharges) {
	      my($case,$chrg)=split ';',$charge;
          if( defined $caselist{$case} ) {
	         $charges{$case.";".$chrg}=$rawcharges{$charge};
	      }
       }
       writehash("$outpath/charges.txt",\%charges);
    }
    foreach (keys %charges) {
        my($case,$count,$filedate,$statute,$subsec,$desc,$level,$degree,$dispcode,$dispdate,$fcic)=split '~',$charges{$_};
        if ($dispcode eq "") { $chargepending{$case}=1; }
        if (!defined($caseCharges{$case})) {
            $caseCharges{$case} = [];
        }
        my %temp = (
            'FileDate' => $filedate,
            'Statute' => $statute,
            'SubSec' => $subsec,
            'Desc' => $desc,
            'Level' => $level,
            'Degree' => $degree
        );
        push (@{$caseCharges{$case}}, \%temp);
    }
	foreach (keys %caselist) {
		my $ind=1;
		while (defined $charges{$_.";".$ind} ) { $ind++; }
		$chargecnt{$_} = $ind-1;
	}
    writehash("$outpath/chargecnt.txt",\%chargecnt);
    
    # Build a hash of the charges, keyed on just the case number - it'll be MUCH easier to work
}

sub buildlastdocket {
    my %rawlastdocket;
    if ($DEBUG) {
        print "DEBUG: Reading lastdocket.txt\n";
    	%lastdocket=readhash("$outpath/lastdocket.txt");
    }
    else {
       %rawlastdocket=sqlhash("SELECT a.CaseNumber,
							  CONVERT(varchar(10), MAX(a.EffectiveDate), 101),
							  MAX(a.DocketCode) AS DocketCode
	                          FROM $schema.vDocket a
							  INNER JOIN $schema.vCase b
								ON a.CaseID = b.CaseID
								AND b.CourtType in $casetypes
							  GROUP BY a.CaseNumber", 1, $dbh);
       foreach my $case (keys %rawlastdocket) {
         if( defined $caselist{$case} ) {
	         $lastdocket{$case}=$rawlastdocket{$case};
	     }
       }
       writehash("$outpath/lastdocket.txt",\%lastdocket);
    }
}

# Now, uses cdrdoct_filing_date rather than cdrdoct_activity_date as the last activity date.
sub buildlastactivity {
	my $justcases = shift;
	my $dbh = shift;
	
	my %rawlastactivity;
	if ($DEBUG) {
		print "DEBUG: Reading lastactivity.txt\n";
		%lastactivity=readhash("$outpath/lastactivity.txt");
    } else {
		my $count = 0;
		my $perQuery = 1000;
		
		while ($count < scalar(@{$justcases})) {
			my @temp;
			
			getArrayPieces($justcases, $count, $perQuery, \@temp, 1);
			my $inString = join(",", @temp);
			
			#my $query = qq {
			#	SELECT
			#		a.CaseNumber,
			#		CONVERT(varchar(10), MAX(a.EffectiveDate), 101) AS FilingDate,
			#		MAX(a.DocketCode) AS DocketCode
			#	FROM
			#		$schema.vDocket a
			#	INNER JOIN
			#		$schema.vCase b
			#		ON a.CaseID = b.CaseID
			#		AND b.CaseNumber in ($inString)
			#		-- AND b.CourtType in $casetypes
			#		GROUP BY a.CaseNumber
			#};
			
			my $query = qq {
				SELECT 
					a.CaseNumber,
					CONVERT(varchar(10), MAX(a.EffectiveDate), 101) AS FilingDate,
					DocketCode
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
				)
				GROUP BY a.CaseNumber, DocketCode
			};
			
			my %rawlastactivity;
			getData(\%rawlastactivity, $query, $dbh, {hashkey => 'CaseNumber', flatten => 1});
			
			foreach my $case (keys %rawlastactivity) {
				if( defined $caselist{$case} ) {
					$lastactivity{$case} = sprintf("%s~%s", $rawlastactivity{$case}->{'CaseNumber'}, $rawlastactivity{$case}->{'FilingDate'});
					#$lastactivity{$case}=$rawlastactivity{$case};
				}
			}
			
			$count += $perQuery;
		}
		writehash("$outpath/lastactivity.txt",\%lastactivity);
    }
}

sub buildevents {
	my $caselist = shift;
	
    my %rawevents;
    if ($DEBUG) {
        print "DEBUG: Reading events.txt\n";
        %events=readhash("$outpath/events.txt");
    } else {
		
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

        #writehash("$outpath/events.txt",\%events);
    }
}



sub buildcaselist {
    my $caselist = shift;
	my $divs = shift;
	my $dbh = shift;
    
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
	
    my $jdbh = dbConnect("judge-divs");
    my $judgeQuery = qq {
        select
            division_id as DivisionID,
            division_type as DivisionType
        from
            divisions
        where
            (division_type like '%Juvenile')
        order by
            DivisionID
    };
    getData(\%divassign, $judgeQuery, $jdbh, {hashkey => 'DivisionID', flatten => 1});
    
    foreach my $divID (keys %divassign) {
        $divlist{$divID} = $divassign{$divID}->{'DivisionType'};
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
		my $query = qq {
			SELECT
				c.CaseNumber,
				c.DivisionID,
				NULL as CaseStyle,
				c.CaseStatus,
				c.CourtType,
				CONVERT(VARCHAR(10), c.FileDate, 101) as FileDate,
				c.CaseType
			FROM
				$schema.vCase c
			INNER JOIN
				$schema.vDivision_Judge j with(nolock)
					ON c.DivisionID = j.DivisionID
					AND j.Division_Active = 'Yes'	
			WHERE
				c.CourtType IN $casetypes
				AND c.CaseStatus not in $NOTACTIVE
				AND c.Sealed = 'N' $caseString $divStr
		};
		
		getData(\%rawcase, $query, $dbh, {hashkey => "CaseNumber", flatten => 1});
		
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
		my $ctyp = $rec->{'CaseType'};
		
		if ($div eq "") {
			$nodiv++;
			write_nodiv_file("$outpath/nodiv_civcases.txt","$casenum, status=$status \n");
		}
		
		$caselist{$casenum}="$div~$desc~$status~$casetype~$filedate~$ctyp";
        
        if ($reopencodes=~/,$status,/) {
			# a reopened case
			$reopened{$casenum}=1;
		}
    }
	
	if($MSGS) {
		print "$nodiv Cases with No Division!\n";
	}
	
	write_nodiv_file("$outpath/nodiv_civcases.txt","$nodiv cases with no division");
	writehash("$outpath/caselist.txt",\%caselist);
	if($MSGS) {
		print "done building caselist ".timestamp()."\n";
	}
}



#sub buildcaselist {
#	my $caselist = shift;
#	my $divs = shift;
#	
#	my $caseString = "";
#    if (defined($caselist)) {
#        my @temp;
#        foreach my $case (@{$caselist}) {
#            push(@temp,"'$case'");
#        }
#        $caseString = "and cdbcase_id in (" . join(",", @temp) . ") ";
#    }
#	
#	my $divStr ="";
#	if (defined($divs)) {
#		# This should be an array ref of the divisions.
#		my @temp;
#		foreach my $div (@{$divs}) {
#			push(@temp, "'$div'");
#		}
#		my $inStr = join(",", @temp);
#		$divStr = "and cdbcase_division_id in ($inStr)";
#	}
#	
#	my ($nodiv,%divassign,%rawcase,$r);
#	
#	my $jdbh = dbConnect("judge-divs");
#    my $judgeQuery = qq {
#        select
#            division_id as DivisionID,
#            division_type as DivisionType
#        from
#            divisions
#        where
#            (division_type like '%Juvenile%')
#        order by
#            DivisionID
#    };
#    getData(\%divassign, $judgeQuery, $jdbh, {hashkey => 'DivisionID', flatten => 1});
#    
#    foreach my $divID (keys %divassign) {
#        $divlist{$divID} = $divassign{$divID}->{'DivisionType'};
#    }
#	
#	if ($DEBUG) {
#        print "DEBUG: Reading rawcase.txt\n";
#		%rawcase=readhash("$outpath/rawcase.txt");
#    } else {
#		if($MSGS) {
#			print "doing rawcase sql... ".timestamp()."\n";
#		}
#		# simplified....
#		my $query = qq {
#			select
#				cdbcase_id,
#				cdbcase_division_id,
#				cdbcase_desc,
#				'unknown',
#				cdbcase_cort_code,
#				cdbcase_init_filing,
#				cdbcase_ctyp_code
#			from
#				cdbcase
#			where
#				cdbcase_cort_code in $casetypes
#				and cdbcase_sealed_ind<>3 $caseString $divStr
#		};
#		%rawcase=sqllookup($query);
#		if($MSGS) {
#			$r = keys %rawcase;
#			print "got all the rawcase rows - $r of them ".timestamp()."\n";
#		}
#		my %t;
#		
#		foreach my $c (keys %rawcase) {
#			if(defined $srsstatus{$c}) {
#				$t{$c}=$rawcase{$c};
#			}
#		}
#		
#		$r=keys %t;
#		%rawcase = %t;
#		my $t1 = keys %rawcase;
#		if($MSGS) {
#			print "extracted out the rawcases that weren't in srsstatus.  \n";
#			print "---- now, there are $r keys in rawcase (s/b = $t1) ".timestamp()."\n";
#		}
#		writehash("$outpath/rawcase.txt",\%rawcase);
#		if($MSGS) {
#			print "just wrote rawcase file... ".timestamp()."\n";
#		}
#    }
#	
#	if($MSGS) {
#		print "coursing through rawcase hash - filling caselist... ".timestamp()."\n";
#	}
#    foreach my $casenum (sort keys %rawcase) {
#        my($div,$desc,$last,$first,$middle,$status,$casetype,$filedate,$ctyp)=split '~',$rawcase{$casenum};
#        # Clean up the desc a little - a lot of them don't have spaces, so at least split them at commas.
#        my @temp = split(",", $desc);
#        # Combine them with comma-space
#        $desc = join(", ", @temp);
#        # And compress whitespace.
#        $desc =~ s/\s+/ /;
#        
#		$status=$srsstatus{$casenum}; # get the status for this case
#        if ($div eq "") {
#	   		$nodiv++;
#	   		write_nodiv_file("$outpath/nodiv_juvcases.txt","$casenum~$desc~$last, $first $middle~$div~$status~$casetype~$filedate~$ctyp");
#		}
#		$caselist{$casenum}="$div~$desc~$last, $first $middle~$status~$casetype~$filedate~$ctyp";
#        if ($reopencodes=~/,$status,/) { # a reopened case
#	    	$reopened{$casenum}=1;
#	    }
#    }
#    if($MSGS) {
#		print "$nodiv Cases with No Division!\n";
#	}
#    write_nodiv_file("$outpath/nodiv_juvcases.txt","$nodiv cases with no division");
#    writehash("$outpath/caselist.txt",\%caselist);
#    writehash("$outpath/reopened.txt",\%reopened);
#	if($MSGS) {
#		print "done building caselist ".timestamp()."\n";
#	}
#}


sub findit{
    my($val,$array)= @_;
	my(@array)= @$array;
	foreach (@array) {
	   if ( $val eq $_ ) { return 1; }
	}
	return 0;
}


#
# makeastyle    makes a case style of the form "x v. y" where x and y are the
#               first plaintiff/defendant, petitioner/respondent, etc.
#               listed for a case.
sub makeastyle {
    my($case_id,$i,$typ,$last,$first,$middle,$name,$fullname,$key,$etal,%ptype,$x,$pidm,$assoc,$ptyp_desc);
    if (scalar keys %partylist==0) {
		die "scjuv.pl: makeastyle: partylist is empty.";
    }
    
    $case_id=shift;
    %ptype=();
    foreach $i (1..30) {  # 30 parties max
		$key="$case_id;$i";
		if (!defined $partylist{$key}) {
			next;
		}
		($typ,$last,$first,$middle,$pidm,$assoc,$ptyp_desc)=(split '~',$partylist{$key})[2..8];
		
		#only want kids for this one
		#if($typ eq "CHLD" && ($pidm == (split '~',$doblist{$key})[2])){
		if($typ eq "CHLD" || ($typ eq "HYBRID" && ($ptyp_desc eq "CHILD (CJ)"))){
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
				$ptype{$typ} = $fullname;
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
    } else {
		return join " ", sort values %ptype;
    }
}


#
# buildstyles  fills the %style hash with a text style for each case.
#
sub buildstyles() {
    if ($DEBUG) {
		print "DEBUG: Reading styles.txt\n";
		%style=readhash("$outpath/styles.txt");
    } else {
		foreach my $case (keys %caselist) {
			my ($div, $style, $name, $status, $type, $filedate, $courttype) = split(/~/, $caselist{$case});
			my $caseage = getage($filedate);
			$style{$case} = sprintf("%s~%s~%d", makeastyle($case), $div, $caseage);
		}
		writehash("$outpath/styles.txt",\%style);
    }
}

sub doit() {
	my @divlist;
	my $readCaseList;
	
	GetOptions ("d:s" => \@divlist, "c" => \$readCaseList);
	
    if($MSGS) {
		print "starting juvenile reports scjuv ".timestamp()."\n";
    }
    
    if (@ARGV==1 and $ARGV[0] eq "DEBUG") {
		$DEBUG=1;
		print "DEBUG!\n";
    }
    $outpath="/var/www/$county/juv";
    $webpath="/case/$county/juv";

    rename("$outpath/nodiv_juvcases.txt", "$outpath/nodiv_juvcases.txt_prev");
	
	if($MSGS) {
		print "starting buildcaselist ".timestamp()."\n";
	}
	
	if (defined($readCaseList)) {
		open(INFILE, "/var/www/Palm/civ/caselist.txt");
		while (my $line = <INFILE>) {
			chomp $line;
			my ($case, $data) = split("\`", $line);
			$caselist{$case} = $data;
		}
		close INFILE;
	} else {
		if (scalar(@divlist)) {
			buildcaselist(undef, \@divlist, $dbh);
		} else {
			buildcaselist(undef, undef, $dbh);
		}
	}
	
	
	if($MSGS) {
		print "starting updateCaseNotes ".timestamp()."\n";
    }
	
	my @justcases = keys(%caselist);
	
	my @depCases;
	my @delCases;
	foreach my $case (@justcases) {
		if ($case =~ /DP/) {
			push(@depCases, $case)
		} elsif ($case =~ /CJ/) {
			push(@delCases, $case);
		}
	}
	
	# Get cases with shelter hearings
	getLastDocketFromList(\@depCases, ['SH'], \%shelterHearings, "showcase", $dbh);
	
	my @shelters = keys(%shelterHearings);
	
	getLastDocketFromList(\@shelters, ['PDDP'], \%depDisposed, "showcase", $dbh);
	
	updateCaseNotes(\%caselist,\@casetypes);
	
	buildNoHearings(\@justcases, \%noHearings);
	
    if($MSGS) {
		print "starting buildwarrants ".timestamp()."\n";
    }
    
    buildwarrants;
    
    if($MSGS) {
		print "starting buildcharges ".timestamp()."\n";
    }
    buildcharges;
    
    if($MSGS) {
		print "starting buildlastdocket ".timestamp()."\n";
    }
    buildlastdocket;
    
    if($MSGS) {
		print "starting buildlastactivity ".timestamp()."\n";
    }
    buildlastactivity (\@justcases, $dbh);
	
    if($MSGS) {
		print "starting buildevents ".timestamp()."\n";
    }
    buildevents (\@justcases);
	
#	if($MSGS) {
#		print "starting getVrbEventsByCaseList ".timestamp()."\n";
#    }
#	
#	getVrbEventsByCaseList(\@justcases, \%events);
#    
    if($MSGS) {
		print "starting buildnotes ".timestamp()."\n";
    }
    buildnotes(\%merged, \%flags, $casetypes, $outpath, $DEBUG);
	
	my $merged = \%merged;
	my $flags = \%flags;
	
	foreach my $casenum (keys(%caselist)) {
        my $caseCopy = $casenum;
        my $checkCase_vrb;
        if ($caseCopy =~ /(\d\d)-(\d\d\d\d)-(\D\D)-(\d\d\d\d\d\d)-(\D\D\D\D)-(\D\D)/) {
			$checkCase_vrb = sprintf("%04d-%s-%06d", $2, $3, $4);
		}
            
        if (defined($merged->{$checkCase_vrb})) {
			$merged->{$casenum} = $merged->{$checkCase_vrb};
            delete $merged->{$checkCase_vrb};
		}
		if (defined($flags->{$checkCase_vrb})) {
			$flags->{$casenum} = $flags->{$checkCase_vrb};
            delete $flags->{$checkCase_vrb};
		}
    }
    
    if($MSGS) {
		print "starting buildpartylist ".timestamp()."\n";
    }
	buildPartyList(\%partylist,$outpath,\@justcases,$dbh);
    
    if($MSGS) {
		print "starting buildstyles ".timestamp()."\n";
    }
    buildstyles;
    
    if($MSGS) {
		print "starting builddobs ".timestamp()."\n";
	}
    builddobs(\@justcases);
	
    # do not do this until Noel says to...
    #if($MSGS) {print "starting flagfanelli ".timestamp()."\n";}
    #flagfanelli;
    
    if($MSGS) {
		print "starting report ".timestamp()."\n";
    }
    report;
    
    if($MSGS) {
		print "finished juvenile reports scjuv ".timestamp()."\n";
    }
}


#
# MAIN PROGRAM STARTS HERE!
#

doit();
