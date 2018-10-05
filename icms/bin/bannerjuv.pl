#!/usr/bin/perl
#

BEGIN {
	use lib "/usr/local/icms/bin";
}

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
use DB_Functions qw (
    dbConnect
	getData
	getDataOne
	doQuery
);
use Banner::Reports qw (
	buildPartyList
);
use Common qw (
	dumpVar
	inArray
	@skipHack
	getArrayPieces
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

my $outpath;
my $outpath2;
my $webpath;
my $county="Palm";
my %allsrs;    # contains all cases for this report with the corresponding srs status
my %srsstatus; # just status of cases we're interested in
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

my $reopencodes=",RO,ROCJ,RODP,";

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
    return substr($casenum,0,4)."-".substr($casenum,4,2)."-".substr($casenum,6,6);
}

#
# get list of child's dobs for report
#
sub builddobs {
    my %rawdobs;
    if ($DEBUG) {
     	print "DEBUG: Reading dobs.txt\n";
	%doblist=readhash("$outpath/dobs.txt");
    } else {
	foreach my $case (keys %caselist) {
	    %rawdobs=sqlhash("select cdrcpty_case_id,cdrcpty_seq_no,cdrcpty_pidm,spbpers_birth_date
			     from cdrcpty, spbpers where cdrcpty_case_id='$case' and cdrcpty_ptyp_code='CHLD' and cdrcpty_pidm=spbpers_pidm",2);
	    foreach (keys %rawdobs) {
		$doblist{$_}=$rawdobs{$_};
	    }
	}
	writehash("$outpath/dobs.txt",\%doblist);
    }
}

#
# getfirstchilddob - pulls the dob of the first child found in the doblist
#
sub getfirstchilddob {
    my($dob,$case_id,$i,$key);
    if (scalar keys %doblist==0) {
	die "bannerjuv.pl: getfirstchilddob: doblist is empty.";
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
	    select
			a.cdrdoct_case_id,
			a.cdrdoct_dtyp_code,
			cdbcase_division_id
	    from
			cdrdoct a,
			cdbcase
	    where
			a.cdrdoct_case_id = cdbcase_id
			and a.cdrdoct_dtyp_code in ('ORGM','OTJF','OTJSF','OTDF','OTSF')
			and cdbcase_cort_code ='DP'
			and cdbcase_division_id in ('JK','JL','JO')  
	};
	%rawmagcases = sqlhash($query);
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
	}
	else {
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
    if (!$critdesc{$crit}) {
        die "invalid criteria $crit\n";
    }
    
    my $cttext;
    $cttext=getdesc($casetype,$thisdiv);

    foreach my $case (keys %caselist) {
        my($div,$desc,$name,$status,$casetype,$filedate,$ctyp)=split '~',$caselist{$case};

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
            if ($crit =~ /^pendne/ and $events{$case}) {
                next;
            }
            if ($crit =~ /^pendwe/ and !$events{$case}) {
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
            if ($crit =~ /^rone/ and $events{$case}) {
                next;
            }
            if ($crit =~ /^rowe/ and !$events{$case}) {
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
        my ($evcode,$evdate)=split '~',$events{$case};
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
        
		my $chgs = $chargecnt{$case};
		my $listString = "$ucn~$desc~$dob~$filedate~$age~$ctyp~$status~$ladate~$chgs~$charges~$evcode~$evdate~$merged{$ucn}\n";
        push @list,$listString;
		if (defined($noHearings{$ucn})) {
			push(@noEventList, $listString);
		}
    }
    
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
	   %rawwarrants=sqllookup("select distinct cobdreq_case_id from cobdreq, cdbcase where cobdreq_case_id = cdbcase_id
                          and cobdreq_evnt_code = 'JPU' and cdbcase_cort_code = 'CJ'
                          and not exists (Select 'X' from cobdtra where cobdtra_dreq_id = cobdreq_id)");
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
       %rawcharges=sqlhash("select cdrccpt_case_id,cdrccpt_chrg_no, cdrccpt_filing_date,
	                  cdrccpt_statute_code, cdrccpt_sub_sect, cdrccpt_desc, cdrccpt_level,
					  cdrccpt_degree, cdrccpt_disp_code,cdrccpt_disp_date,cdrccpt_fcic_code
					  from cdrccpt,cdbcase where cdrccpt_case_id=cdbcase_id
                      and cdrccpt_maint_code is null
					  and cdbcase_cort_code in ('CJ') ",2);
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
       %rawlastdocket=sqlhash("select a.cdrdoct_case_id,a.cdrdoct_filing_date,a.cdrdoct_dtyp_code
	                          from cdrdoct a,cdbcase b where cdrdoct_case_id=cdbcase_id and cdbcase_cort_code in $casetypes
							  and a.cdrdoct_filing_date=(select max(c.cdrdoct_filing_date) from cdrdoct c where c.cdrdoct_case_id=a.cdrdoct_case_id)");
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
			
			my $query = qq {
				select
					a.cdrdoct_case_id as "CaseNumber",
					a.cdrdoct_filing_date as "FilingDate"
				from
					cdrdoct a,
					cdbcase b
				where
					cdrdoct_case_id = cdbcase_id
					and cdrdoct_case_id in ($inString)
					-- and cdbcase_cort_code in $casetypes
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
			getData(\%rawlastactivity, $query, $dbh, {hashkey => 'CaseNumber', flatten => 1});
			
			foreach my $case (keys %rawlastactivity) {
				if( defined $caselist{$case} ) {
					$lastactivity{$case} = sprintf("%s~%s", $rawlastactivity{$case}->{'CaseNumber'}, $rawlastactivity{$case}->{'FilingDate'});
					#$lastactivity{$case}=$rawlastactivity{$case};
				}
			}
			
			$count += $perQuery;
		}
		dumpVar(\%lastactivity);
		writehash("$outpath/lastactivity.txt",\%lastactivity);
    }
}

sub buildevents {
	my $justcases = shift;
	
    my %rawevents;
    if ($DEBUG) {
        print "DEBUG: Reading events.txt\n";
        %events=readhash("$outpath/events.txt");
    } else {
		my $count = 0;
		my $perQuery = 1000;
		
		while ($count < scalar(@{$justcases})) {
			my @temp;
			
			getArrayPieces($justcases, $count, $perQuery, \@temp, 1);
			my $inString = join(",", @temp);
			
			$count += $perQuery;
		}
		
		my $query = qq{
			select
				cdbcase_id,
				a.csrcsev_evnt_code,
				a.csrcsev_sched_date
			from
				csrcsev a,
				cdbcase
			where
				csrcsev_case_id=cdbcase_id
				and a.csrcsev_sched_date >= to_date('$EVTDATE','MM/DD/YYYY')
				and cdbcase_cort_code in $casetypes
				and a.csrcsev_sched_date = (
					select
						max(c.csrcsev_sched_date)
					from
						csrcsev c
					where
						c.csrcsev_case_id=a.csrcsev_case_id)
					order by
						cdbcase_id
		};
		
		
	   %rawevents=sqllookup("select cdbcase_id,a.csrcsev_evnt_code,a.csrcsev_sched_date
	                  from csrcsev a,cdbcase where csrcsev_case_id=cdbcase_id and a.csrcsev_sched_date>=to_date('$EVTDATE','MM/DD/YYYY')
					  and cdbcase_cort_code in $casetypes
					  and a.csrcsev_sched_date=(select max(c.csrcsev_sched_date) from csrcsev c where c.csrcsev_case_id=a.csrcsev_case_id) order by cdbcase_id");
      foreach my $case (keys %rawevents) {
         if( defined $caselist{$case} ) {
	         $events{$case}=$rawevents{$case};
	     }
      }

        writehash("$outpath/events.txt",\%events);
    }
}

sub buildcaselist {
	my $caselist = shift;
	my $divs = shift;
	
	my $caseString = "";
    if (defined($caselist)) {
        my @temp;
        foreach my $case (@{$caselist}) {
            push(@temp,"'$case'");
        }
        $caseString = "and cdbcase_id in (" . join(",", @temp) . ") ";
    }
	
	my $divStr ="";
	if (defined($divs)) {
		# This should be an array ref of the divisions.
		my @temp;
		foreach my $div (@{$divs}) {
			push(@temp, "'$div'");
		}
		my $inStr = join(",", @temp);
		$divStr = "and cdbcase_division_id in ($inStr)";
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
            (division_type like '%Juvenile%')
        order by
            DivisionID
    };
    getData(\%divassign, $judgeQuery, $jdbh, {hashkey => 'DivisionID', flatten => 1});
    
    foreach my $divID (keys %divassign) {
        $divlist{$divID} = $divassign{$divID}->{'DivisionType'};
    }
	
	if ($DEBUG) {
        print "DEBUG: Reading rawcase.txt\n";
		%rawcase=readhash("$outpath/rawcase.txt");
    } else {
		if($MSGS) {
			print "doing rawcase sql... ".timestamp()."\n";
		}
		# simplified....
		my $query = qq {
			select
				cdbcase_id,
				cdbcase_division_id,
				cdbcase_desc,
				'unknown',
				cdbcase_cort_code,
				cdbcase_init_filing,
				cdbcase_ctyp_code
			from
				cdbcase
			where
				cdbcase_cort_code in $casetypes
				and cdbcase_sealed_ind<>3 $caseString $divStr
		};
		%rawcase=sqllookup($query);
		if($MSGS) {
			$r = keys %rawcase;
			print "got all the rawcase rows - $r of them ".timestamp()."\n";
		}
		my %t;
		
		foreach my $c (keys %rawcase) {
			if(defined $srsstatus{$c}) {
				$t{$c}=$rawcase{$c};
			}
		}
		
		$r=keys %t;
		%rawcase = %t;
		my $t1 = keys %rawcase;
		if($MSGS) {
			print "extracted out the rawcases that weren't in srsstatus.  \n";
			print "---- now, there are $r keys in rawcase (s/b = $t1) ".timestamp()."\n";
		}
		writehash("$outpath/rawcase.txt",\%rawcase);
		if($MSGS) {
			print "just wrote rawcase file... ".timestamp()."\n";
		}
    }
	
	if($MSGS) {
		print "coursing through rawcase hash - filling caselist... ".timestamp()."\n";
	}
    foreach my $casenum (sort keys %rawcase) {
        my($div,$desc,$last,$first,$middle,$status,$casetype,$filedate,$ctyp)=split '~',$rawcase{$casenum};
        # Clean up the desc a little - a lot of them don't have spaces, so at least split them at commas.
        my @temp = split(",", $desc);
        # Combine them with comma-space
        $desc = join(", ", @temp);
        # And compress whitespace.
        $desc =~ s/\s+/ /;
        
		$status=$srsstatus{$casenum}; # get the status for this case
        if ($div eq "") {
	   		$nodiv++;
	   		write_nodiv_file("$outpath/nodiv_juvcases.txt","$casenum~$desc~$last, $first $middle~$div~$status~$casetype~$filedate~$ctyp");
		}
		$caselist{$casenum}="$div~$desc~$last, $first $middle~$status~$casetype~$filedate~$ctyp";
        if ($reopencodes=~/,$status,/) { # a reopened case
	    	$reopened{$casenum}=1;
	    }
    }
    if($MSGS) {
		print "$nodiv Cases with No Division!\n";
	}
    write_nodiv_file("$outpath/nodiv_juvcases.txt","$nodiv cases with no division");
    writehash("$outpath/caselist.txt",\%caselist);
    writehash("$outpath/reopened.txt",\%reopened);
	if($MSGS) {
		print "done building caselist ".timestamp()."\n";
	}
}


# builddivcs  fills the %divcs hash with a text style for each case in this division.
#sub builddivcs {
#	my($thisdiv)=@_;
#	my %divcs=();
#	if(onlinediv($thisdiv) eq "true") {
#		# will build the all cases list the first time a div w/ online scheduing is done
#		if ( scalar %allcases == 0 ) { no strict 'refs'; buildallcases(); }
#		foreach my $case (keys %allcases) {
#			my($divid,$desc)=split '~',$allcases{$case};
#			if($thisdiv eq $divid) { $divcs{$case}=$desc; }
#		}
#		writehash("$outpath/div$thisdiv/divcs.txt",\%divcs);
#	}
# }

# Get all cases (not just active) - needed for online scheduling.
# Don't do it if no divisions in online scheduling.
# Also, not saving all cases to a text file because they're too big!
#sub buildallcases {
#	if(scalar @OLSCHEDULING > 0) {
#		my (%all);
#		# don't exclude closed cases
#        %all=sqllookup("select cdbcase_id, cdbcase_division_id, cdbcase_desc
#		               from cdbcase,cdrcpty c,spriden
#		               where cdbcase_id=cdrcpty_case_id and (cdrcpty_ptyp_code in ('JUDG','CHLD','PET'))
#		               and cdrcpty_pidm=spriden_pidm and cdbcase_cort_code in $casetypes and cdbcase_sealed_ind<>3
#					   and spriden_change_ind is null and cdrcpty_end_date is null
#					   and c.cdrcpty_start_date=(SELECT MAX(a.cdrcpty_start_date) from cdrcpty a where a.cdrcpty_case_id=c.cdrcpty_case_id and a.cdrcpty_ptyp_code=c.cdrcpty_ptyp_code)");
#		foreach my $casenum (sort keys %all) {
#			#my($divid,$desc)=split '~',$all{$casenum};
#			#$allcases{$casenum}="$divid~$desc";
#			$allcases{$casenum}=$all{$casenum};
#		}
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
    my($case_id,$i,$typ,$last,$first,$middle,$name,$fullname,$key,$etal,%ptype,$x);
    if (scalar keys %partylist==0) {
	die "bannerciv.pl: makeastyle: partylist is empty.";
    }
    
    $case_id=shift;
    %ptype=();
    foreach $i (1..30) {  # 30 parties max
	$key="$case_id;$i";
	if (!defined $partylist{$key}) {
	    next;
	}
	($typ,$last,$first,$middle)=(split '~',$partylist{$key})[2..5];
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
	    if (!($ptype{$typ}=~/, et al./)) { $ptype{$typ}.=", et al."; }
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
	
	GetOptions ("d:s" => \@divlist);
	
	
    if($MSGS) {
		print "starting juvenile reports bannerjuv ".timestamp()."\n";
    }
    
    if (@ARGV==1 and $ARGV[0] eq "DEBUG") {
		$DEBUG=1;
		print "DEBUG!\n";
    }
    $outpath="/var/www/$county/juv";
    $webpath="/case/$county/juv";
    dbconnect("wpb-banner-rpt");
	my $ndbh = dbConnect("wpb-banner-rpt");
    rename("$outpath/nodiv_juvcases.txt", "$outpath/nodiv_juvcases.txt_prev");
	
	if($MSGS) {
		print "starting buildSRSList ".timestamp()."\n";
    }
    
	if (scalar(@divlist)) {
		my $divStr = join(",", @divlist);
		
		print "Restricting to division $divStr...\n";
		
		buildSRSList(\%srsstatus,$outpath,$casetypes,$ndbh,0,undef,\@divlist);
		if($MSGS) {
			print "starting buildcaselist ".timestamp()."\n";
		}
		buildcaselist(undef, \@divlist);
	} else {
		print "Using all divs.\n";
		buildSRSList(\%srsstatus,$outpath,$casetypes,$ndbh,0,undef);
		if($MSGS) {
			print "starting buildcaselist ".timestamp()."\n";
		}
		buildcaselist();
	}
	
	if($MSGS) {
		print "starting updateCaseNotes ".timestamp()."\n";
    }
	
    updateCaseNotes(\%caselist,\@casetypes);
	
	my @justcases = keys(%caselist);
	
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
    buildlastactivity (\@justcases, $ndbh);
	
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
    
    if($MSGS) {
		print "starting buildpartylist ".timestamp()."\n";
    }
	buildPartyList(\%partylist,$outpath,\@justcases,$ndbh);
    
    if($MSGS) {
		print "starting buildstyles ".timestamp()."\n";
    }
    buildstyles;
    
    if($MSGS) {
		print "starting builddobs ".timestamp()."\n";
	}
    builddobs;
	
    # do not do this until Noel says to...
    #if($MSGS) {print "starting flagfanelli ".timestamp()."\n";}
    #flagfanelli;
    
    if($MSGS) {
		print "starting report ".timestamp()."\n";
    }
    report;
    
    if($MSGS) {
		print "finished juvenile reports bannerjuv ".timestamp()."\n";
    }
}


#
# MAIN PROGRAM STARTS HERE!
#

doit();
