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
	inArray
	@skipHack
	writeJsonFile
);
use Casenotes qw(
    mergeNotesAndFlags
	updateCaseNotes
    buildnotes
);
use DB_Functions qw (
    dbConnect
);
use Banner::Reports qw (
	buildPartyList
);

use Reports qw (
    getVrbEventsByCaseList
    getLastDocketFromList
	buildNoHearings
);

my $DEBUG=0;  # will read txt files if set to 1
my $MSGS=1;   # will spit out diag msgs if set to 1

# No output buffering
$| = 1;

my $county="Palm";
my $outpath="/var/www/$county/pro";
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
my %noHearings;
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

# cdbcase_sealed_ind  3 - sealed/expunged?

#
# this is for civil cases only..leaves off that final -A
#
sub casenumtoucn {
    my($casenum)=@_;
    return substr($casenum,0,4)."-".substr($casenum,4,2)."-".substr($casenum,6,6);
}


#
# makeastyle    makes a case style of last name, first name, mi
#
sub makeastyle {
   my($case_id,$i,$typ,$last,$first,$middle,$name,$fullname,$key,$etal,%ptype,$x);
   if (scalar keys %partylist==0) { die "bannerpro.pl: makeastyle: partylist is empty."; }
   $case_id=$_[0];
   %ptype=();

   foreach $i (1..30) {  # 30 parties max
      $key="$case_id;$i";
      if (!defined $partylist{$key}) { next; }
      ($typ,$last,$first,$middle)=(split '~',$partylist{$key})[2..5];
      if (!defined $middle) { $middle=""; }
      if (!defined $first) { $first=""; }
      if (!defined $last) { $last=""; }
      $middle=trim($middle);
      $last=trim($last);
      $first=trim($first);
      $name="$last";
	  $fullname="$last";
	  if(length($first) > 0) {$fullname="$last, $first $middle";}

      if ($typ=~/DECD/) {
	  		return "$fullname - Estate of";
      }
      elsif ($typ=~/WARD/) {
	  	  return "$fullname - Guardianship of";
      }
      elsif ($typ=~/MIN/) {
	  	  return "$fullname - Minor";
      }
      elsif ($typ=~/^INCP/) {
	  		return "$fullname - Incapacity of ";
      }
      elsif ($typ=~/^AINC/) {
	  		return "$fullname - Alleged Incapacity of ";
      }
      elsif ($typ=~/^INRE/) {
	  		return "$fullname - In re";
      }
      elsif (!defined $ptype{$typ}) {
	     $ptype{$typ}=$fullname;
      }
      else {
          if (!($ptype{$typ}=~/, et al./)) { $ptype{$typ}.=", et al."; }
      }
   }
   if (defined $ptype{'PLT'} and defined $ptype{'DFT'}) {
       return "$ptype{'PLT'} v. $ptype{'DFT'}";
   }
   elsif (defined $ptype{'PET'} and defined $ptype{'PAT'}) {
       return "$ptype{'PAT'} v. $ptype{'PET'}";
   }
   elsif (defined $ptype{'PET'} and defined $ptype{'RESP'}) {
       return "$ptype{'RESP'} v. $ptype{'PET'}";
   }
   else { return join " ",sort values %ptype; }
}

#
# buildstyles  fills the %style hash with a text style for each case.
sub buildstyles {
	if ($DEBUG) {
		print "DEBUG: reading styles.txt\n";
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
    my($casetype,$thisdiv,$crit)=@_;
    my @list;
	my @noEventList;
    if (!$critdesc{$crit}) { die "invalid criteria $crit\n"; }

    my $cttext;
    $cttext=getdesc($casetype,$thisdiv);
	
	my $reportData =  [
		{'label' => '0 - 120 Days', 'value' => 0},
		{'label' => '121 - 180 Days', 'value' => 0},
		{'label' => '180+ Days', 'value' => 0}
	];

    foreach my $case (keys %caselist) {
		my($div,$desc,$name,$status,$casetype,$filedate,$ctyp)=split '~',$caselist{$case};
		
		next if (inArray(\@skipHack,$status));

        if ($thisdiv ne $div) { next; }

        # check for suppress flag...
        my $ucn=casenumtoucn($case);
        if ($flags{"$ucn;2"}) { # we have a suppress
            my $flagdate=(split '~',$flags{"$ucn;2"})[2];
            my $lastdockdate=(split '~',$lastdocket{$case})[1];
            # if the last docket date is < flagdate, then skip
            if (compdate($lastdockdate,$flagdate)==-1) {
                 next; }
            }
        if ($crit=~/^pend/) {  # pending cases
            if ($crit eq "pendne" and $events{$case}) { next; }
            if ($crit eq "pendwe" and !$events{$case}) { next; }
            if ($status ne "PE") { next; } # skip if not Pending
            if ($reopened{$case}) { next; } # skip if reopened

        } elsif ($crit eq "nopend") {
			if ($status eq "PE") {
				next;
			}
			if ($reopened{$case}) {
				next;
			} # skip if reopened
		} elsif ($crit=~/^ro/) {
            if ($crit eq "rone" and $events{$case}) {
				next;
			}
            if ($crit eq "rowe" and !$events{$case}) {
				next;
			}
            if ($status eq "PE") {
				next;
			}
            if (!$reopened{$case}) {
				next;
			} # skip if not reopened
		} elsif ( $crit eq "cp") {
			if ( $casetype ne "CP" ) {
				next;
			}
		} elsif ( $crit eq "cpfo") {
			if ( $casetype ne "CP" ) {
				next;
			}
			if ( $ctyp ne "FO" ) {
				next;
			}
		} elsif ( $crit eq "cpsa") {
			if ( $casetype ne "CP" ) {
				next;
			} if ( $ctyp ne "SA" ) {
				next;
			}
		} elsif ( $crit eq "cpse") {
			if ( $casetype ne "CP" ) {
				next;
			}
			if ( $ctyp ne "SE" ) {
				next;
			}
		} elsif ( $crit eq "cpsp") {
			if ( $casetype ne "CP" ) {
				next;
			}
			if ( $ctyp ne "SP" ) {
				next;
			}
		} elsif ( $crit eq "ga") {
			# include MH, IC under Guardianship
			if ( ! ($casetype eq "GA" or $casetype eq "MH") ) {
				next;
			}
			if ( $casetype eq "MH" ) {
				if ( $ctyp ne "IC" ) {
					next;
				}
			}
		} elsif ( $crit eq "gain") {
			if ( $casetype ne "GA" ) {
				next;
			}
			if ( $ctyp ne "IN" ) {
				next;
			}
		} elsif ( $crit eq "mh") {
			if ( $casetype ne "MH" ) {
				next;
			}
			# MH, IC is now reporting under Guardianship
			if ( $ctyp eq "IC" ) {
				next;
			}
		} elsif ( $crit eq "mhba") {
			if ( $casetype ne "MH" ) {
				next;
			}
			if ( $ctyp ne "BA" ) {
				next;
			}
		} elsif ( $crit eq "mhic") {
			if ( $casetype ne "MH" ) {
				next;
			}
			if ( $ctyp ne "IC" ) {
				next;
			}
		} elsif ( $crit eq "mhma") {
			if ( $casetype ne "MH" ) {
				next;
			}
			if ( $ctyp ne "MA" ) {
				next;
			}
		} elsif ( $crit eq "wo") {
			if ( $casetype ne "CP" ) {
				next;
			}
			if ( $ctyp ne "WO" ) {
				next;
			}
		}
		
		my $age=getage($filedate);
		my ($evcode,$evdate)=split '~',$events{$case};
		my $s = $style{$case};	# get the style from the styles hash - not desc
		# Since the case age has been tacked onto the style, remove it for our purpose here.
		$s = join("~", (split(/~/,$s))[0..1]);
		my $ladate = (split '~',$lastactivity{$case})[1];
		my $listString = "$ucn~$s~$filedate~$age~$ctyp~$status~$ladate~$evcode~$evdate~$merged{$ucn}\n";
		push @list,$listString;
		
		if (defined($noHearings{$ucn})) {
			push(@noEventList, $listString);
		}
		
		
		if ($age > 180) {
			$reportData->[2]->{'value'}++;
		} elsif ($age > 120) {
			$reportData->[1]->{'value'}++;
		} else {
			$reportData->[0]->{'value'}++;
		}
	}
	
	my $outFile = sprintf("%s/%s.txt", $outpath2, $crit);
	
	open(OUTFILE,">$outFile") ||
		die "Couldn't open '$outFile' for writing: $!\n\n";
   
	my $fntitle = "Flags/Most Recent Note";
	if($icmsdb eq 'bad'){$fntitle.="<br/>* Not Current *";}
	print OUTFILE <<EOS;
DATE=$TODAY
TITLE1=$county Beach County - $cttext Division $thisdiv
TITLE2=$critdesc{$crit}
VIEWER=view.cgi
FIELDNAMES=Case #~Name~Div~Initial File~Age~Type~Status~Last Activity~Event Code~Latest / Farthest Event~$fntitle
FIELDTYPES=L~I~C~D~G~S~A~D~A~D~A
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
   
   	my $outJson = sprintf("%s/%s.json", $outpath2, $crit);
	print "Creating JSON data file '$outJson'\n";
	writeJsonFile($reportData, $outJson);
	
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
	if ($div eq "") { return "Probate No "; }
	# only pulling Probate
	return "Probate";
}

sub report {
    if ($DEBUG) {
        print "DEBUG: Building report files\n";
    }
    foreach my $div (keys %divlist) {
	my $casetype=$divlist{$div};
	
	my $cttext=getdesc($casetype,$div);
        my @mcases=split(',',$casetype);
	
	if ($mcases[0] ne " ") {
	    $cttext=getdesc($mcases[0],$div);
        } elsif ($mcases[1] ne " ") {
	    $cttext=getdesc($mcases[1],$div);
        } elsif ($mcases[2] ne " ") {
	    $cttext=getdesc($mcases[2],$div);
        } else {
	    $cttext=getdesc($casetype,$div);
        }

        # for each division...
        my $tim="$YEAR-$M2";
 	    if (!-d "$outpath/div$div") { mkdir "$outpath/div$div",0755; }
	    $outpath2="$outpath/div$div/$tim";
	    if (!-d "$outpath2") { mkdir("$outpath2",0755); }

		#builddivcs($div);		# write a div case style file

		my $numpend=makelist($casetype,$div,"pend");
		my $numpendwe=makelist($casetype,$div,"pendwe");
        my $numpendne=makelist($casetype,$div,"pendne");
        my $numro=makelist($casetype,$div,"ro");
        my $numrowe=makelist($casetype,$div,"rowe");
        my $numrone=makelist($casetype,$div,"rone");
		#my $numnopend=makelist($casetype,$div,"nopend");
        if ($numpend==0) { print "WARNING: no pending cases for $div\n"; }
		# new reports
		#my $numall=makelist($casetype,$div,"all");
		my $numcp=makelist($casetype,$div,"cp");
		my $numcpfo=makelist($casetype,$div,"cpfo");
		my $numcpsa=makelist($casetype,$div,"cpsa");
		my $numcpse=makelist($casetype,$div,"cpse");
		my $numcpsp=makelist($casetype,$div,"cpsp");
		my $numga=makelist($casetype,$div,"ga");
		my $numgain=makelist($casetype,$div,"gain");
		my $nummh=makelist($casetype,$div,"mh");
		my $nummhba=makelist($casetype,$div,"mhba");
		my $nummhic=makelist($casetype,$div,"mhic");
		my $nummhma=makelist($casetype,$div,"mhma");
		#my $numwo=makelist($casetype,$div,"wo");	# will only really goes under probate (CP)
        #
        # now create the summary file for this division
        #
        open OUTFILE,">$outpath2/index.txt" or die "Couldn't open $outpath2/index.txt";
        print OUTFILE <<EOS;
DATE=$TODAY
TITLE1=$county Beach County
TITLE2=$cttext Division $div
PATH=case/$county/pro/div$div/$tim/
HELP=helpbannerciv
Pending Cases~$numpend~1~pend
Reopened Cases~$numro~1~ro
BLANK
Probate Cases~$numcp~1~cp
Formal Admin~$numcpfo~2~cpfo
Small Estate~$numcpse~2~cpse
Summary Admin < \$1000~$numcpsp~2~cpsp
Summary Admin => \$1000~$numcpsa~2~cpsa
Guardianship Cases~$numga~1~ga
Incapacity~$nummhic~2~mhic
Mental Health Cases~$nummh~1~mh
Baker Act~$nummhba~2~mhba
Marchman Act~$nummhma~2~mhma
BLANK
EOS
        unlink("$outpath/div$div/index.txt");
        symlink("$outpath2/index.txt","$outpath/div$div/index.txt");
        }
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
   my %rawlastactivity;
    if ($DEBUG) {
        print "DEBUG: Reading lastactivity.txt\n";
	    %lastactivity=readhash("$outpath/lastactivity.txt");
    }
    else {
       %rawlastactivity=sqlhash("select a.cdrdoct_case_id,a.cdrdoct_filing_date from cdrdoct a,cdbcase b
	          where cdrdoct_case_id=cdbcase_id and cdbcase_cort_code in $casetypes and
			  a.cdrdoct_filing_date=(select max(c.cdrdoct_filing_date) from cdrdoct c where c.cdrdoct_case_id=a.cdrdoct_case_id)");
       foreach my $case (keys %rawlastactivity) {
          if( defined $caselist{$case} ) {
             $lastactivity{$case}=$rawlastactivity{$case};
          }
       }
       writehash("$outpath/lastactivity.txt",\%lastactivity);
       }
}

sub buildevents {
   my %rawevents;
    if ($DEBUG) {
        print "DEBUG: Reading events.txt\n";
	    %events=readhash("$outpath/events.txt");
    }
    else {
       %rawevents=sqllookup("select cdbcase_id,a.csrcsev_evnt_code,a.csrcsev_sched_date from csrcsev a,cdbcase
	           where csrcsev_case_id=cdbcase_id and a.csrcsev_sched_date>=to_date('$EVTDATE','MM/DD/YYYY')
			   and cdbcase_cort_code in $casetypes and a.csrcsev_sched_date =
			   (select max(c.csrcsev_sched_date) from csrcsev c where c.csrcsev_case_id=a.csrcsev_case_id)
			   order by cdbcase_id");
       foreach my $case (keys %rawevents) {
          if( defined $caselist{$case} ) {
             $events{$case}=$rawevents{$case};
          }
       }
        writehash("$outpath/events.txt",\%events);
    }
}


sub buildcaselist {
    my ($nodiv,%divassign,%rawcase,$r);
    if ($DEBUG) {
        print "DEBUG: Reading divassign.txt\n";
	    %divassign=readhash("$outpath/divassign.txt");
    }
    else {
        # for juvenile both CJ and DP types there will always be a CHLD cdrcpty_ptyp_code - the difference is for DP there
		# may be multiple chlds and therefore duplicate casenumbers will be pulled from the spriden table

    	if($MSGS) {print "starting divassign query ".timestamp()."\n";}

	    # just use cdbcase_dtyp_code_status for this query rather than srs_status_code.  same bang for the buck, but less time...
        %divassign=sqllookup("select cdbcase_id,cdbcase_division_id,cdbcase_cort_code,spriden_last_name,spriden_first_name,spriden_mi
	              from cdbcase,cdrcpty c,spriden
				  where cdbcase_id=cdrcpty_case_id and (cdrcpty_ptyp_code in ('JUDG')) and cdrcpty_pidm=spriden_pidm
				  and cdbcase_cort_code in $casetypes and cdbcase_dtyp_code_status in $dtypcodes
				  and spriden_change_ind is null and cdrcpty_end_date is null
				  and cdrcpty_start_date=(SELECT MAX(a.cdrcpty_start_date) from cdrcpty a
				  where a.cdrcpty_case_id=c.cdrcpty_case_id and a.cdrcpty_ptyp_code=c.cdrcpty_ptyp_code)");
        writehash("$outpath/divassign.txt",\%divassign);
	    if($MSGS) {print "finished divassign ".timestamp()."\n";}
    }
    if ($DEBUG) {
      print "DEBUG: reading divlist.txt\n";
      %divlist=readhash("$outpath/divlist.txt");
    }
    else {
		foreach my $case (sort keys %divassign) {
		   my($div,$code,$last,$first,$middle)=split '~',$divassign{$case};
		   if ($divlist{$div}) {
			  if (grep{/$code/} values %divlist) { my $i++; }
			  else { $divlist{$div}.=",$code"; }
		   }
		   else { $divlist{$div}=$code; }
		} # end foreach
		if($MSGS) {
		   my $s=keys %divlist;
		   print "divlist size: ".$s."\n";
		}
		writehash("$outpath/divlist.txt",\%divlist);
	}
    # keys=all divisions in use; values=# cases in each
    if ($DEBUG) {
        print "DEBUG: Reading rawcase.txt\n";
	    %rawcase=readhash("$outpath/rawcase.txt");
    }
    else {
		if($MSGS) {print "starting rawcase query ".timestamp()."\n";}
        # removed this: srs_status_code(cdbcase_id) in $dtypcodes
        %rawcase=sqllookup("select cdbcase_id,cdbcase_division_id,cdbcase_desc,spriden_last_name,spriden_first_name,spriden_mi,
		           'unknown',cdbcase_cort_code,cdbcase_init_filing,cdbcase_ctyp_code
				   from cdbcase,cdrcpty c,spriden
		           where cdbcase_id=cdrcpty_case_id and (cdrcpty_ptyp_code in ('JUDG')) and cdrcpty_pidm=spriden_pidm
				   and cdbcase_cort_code in $casetypes
				   and cdbcase_sealed_ind<>3 and spriden_change_ind is null and cdrcpty_end_date is null
				   and c.cdrcpty_start_date=(SELECT MAX(a.cdrcpty_start_date) from cdrcpty a
				   where a.cdrcpty_case_id=c.cdrcpty_case_id and a.cdrcpty_ptyp_code=c.cdrcpty_ptyp_code)");
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
		if($MSGS) {print "extracted out the rawcases that weren't in srsstatus.  \n ------------- now, there are $r keys in rawcase (s/b = $t1) ".timestamp()."\n";}
		writehash("$outpath/rawcase.txt",\%rawcase);
		if($MSGS) {print "wrote rawcase ".timestamp()."\n";}

    }

	if($MSGS) {print "coursing through rawcase hash - filling caselist... ".timestamp()."\n";}
    foreach my $casenum (sort keys %rawcase) {
        my($div,$desc,$last,$first,$middle,$status,$casetype,$filedate,$ctyp)=split '~',$rawcase{$casenum};
		$status=$srsstatus{$casenum}; # get the status for this case
        if ($div eq "") {
	        $nodiv++;
	        write_nodiv_file("$outpath/nodiv_procases.txt","$casenum, status=$status");
	    }
	    $caselist{$casenum}="$div~$desc~$last, $first $middle~$status~$casetype~$filedate~$ctyp";
        if ($reopencodes=~/,$status,/) { # a reopened case
	       $reopened{$casenum}=1;
	    }
    }
    if($MSGS) {print "$nodiv Cases with No Division!\n";}
    write_nodiv_file("$outpath/nodiv_procases.txt","$nodiv cases with no division");
    writehash("$outpath/caselist.txt",\%caselist);
    writehash("$outpath/reopened.txt",\%reopened);
	if($MSGS) {print "done building caselist ".timestamp()."\n";}
}

# builddivcs  fills the %divcs hash with a text style for each case in this division.
sub builddivcs {
	my($thisdiv)=@_;
	my %divcs=();
	if(onlinediv($thisdiv) eq "true") {
		# will build the all cases list the first time a div w/ online scheduing is done
		if( scalar %allcases == 0 ) { no strict 'refs'; buildallcases(); }
		foreach my $case (keys %allcases) {
			my($divid,$desc)=split '~',$allcases{$case};
			if($thisdiv eq $divid) { $divcs{$case}=$desc; }
		}
		writehash("$outpath/div$thisdiv/divcs.txt",\%divcs);
	}
 }

# Get all cases (not just active) - needed for online scheduling.
# Don't do it if no divisions in online scheduling.
# Also, not saving all cases to a text file because they're too big!
sub buildallcases {
	if(scalar @OLSCHEDULING > 0) {
		my (%all);
		# don't exclude closed cases
        %all=sqllookup("select cdbcase_id, cdbcase_division_id, cdbcase_desc
		from cdbcase,cdrcpty c,spriden
		where cdbcase_id=cdrcpty_case_id and (cdrcpty_ptyp_code in ('JUDG')) and cdrcpty_pidm=spriden_pidm
		and cdbcase_cort_code in $casetypes
		and cdbcase_sealed_ind<>3 and spriden_change_ind is null and cdrcpty_end_date is null and c.cdrcpty_start_date=
		(SELECT MAX(a.cdrcpty_start_date) from cdrcpty a where a.cdrcpty_case_id=c.cdrcpty_case_id and a.cdrcpty_ptyp_code=c.cdrcpty_ptyp_code)");
		foreach my $casenum (sort keys %all) {
			#my($divid,$desc)=split '~',$all{$casenum};
			#$allcases{$casenum}="$divid~$desc";
			$allcases{$casenum}=$all{$casenum};
		}
	}
}


sub doit() {
    if($MSGS) {
        print "starting probate reports bannerpro ".timestamp()."\n";
    }

    if (@ARGV==1 and $ARGV[0] eq "DEBUG") {
        $DEBUG=1;
        print "DEBUG!\n";
    }
    
    dbconnect("wpb-banner-rpt");
	my $ndbh = dbConnect("wpb-banner-rpt");
    rename("$outpath/nodiv_procases.txt", "$outpath/nodiv_procases.txt_prev");
    
    if($MSGS) {
        print "starting buildSRSList ".timestamp()."\n";
    }
	buildSRSList(\%srsstatus,$outpath,$casetypes,$ndbh);
    #buildsrslist;
    
    if($MSGS) {
        print "starting buildcaselist ".timestamp()."\n";
    }
    buildcaselist;
    
    updateCaseNotes(\%caselist,\@casetypes);
	my @justcases = keys(%caselist);
	
	buildNoHearings(\@justcases, \%noHearings);
    
    if($MSGS) {
        print "starting buildlastdocket ".timestamp()."\n";
    }
    buildlastdocket;
    
    if($MSGS) {
        print "starting buildlastactivity ".timestamp()."\n";
    }
    buildlastactivity;
    
    if($MSGS) {
        print "starting buildevents ".timestamp()."\n";
    }
    buildevents;
    
    if($MSGS) {
        print "starting buildnotes ".timestamp()."\n";
    }
    buildnotes(\%merged, \%flags, $casetypes, $outpath, $DEBUG);
    
    if($MSGS) {
        print "starting buildPartyList ".timestamp()."\n";
    }
    #buildpartylist;
	buildPartyList(\%partylist,$outpath,\@justcases,$ndbh);
    
    if($MSGS) {
        print "starting buildstyles ".timestamp()."\n";
    }
    buildstyles;
    
    if($MSGS) {
        print "starting report ".timestamp()."\n";
    }
    report;
    
    if($MSGS) {
        print "finished probate reports bannerpro ".timestamp()."\n";
    }
}

#
# MAIN PROGRAM STARTS HERE!
#

doit();
