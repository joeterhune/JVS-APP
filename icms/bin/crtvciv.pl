#!/usr/bin/perl 
#
#   crtvciv.pl - CourtView civil case reports
# 
# 04/18/05 - derived from genciv.pl
# 09/30/2005 - added Pending Motion On/Off override flag support
# 1/9/07 added Circuit Bench Referral category for N&P, cleaned up
#        categories.
# 1/16/07 modified ROCBR to ROACBR so suppress/pmoff flag would
#         suppress cases properly for ROA CBRs.
#         Also fixed bug for Guardianship no future ticklers.
# 1/30/07 added FA01-R, MA00-P to ignorable docket codes
# 8/3/07 made reportgeneric use the Active Reopened case model for div W
# 8/22/07 disabled pendingmotion & finaljudgement queries, since
#         they were hanging, and we don't using "pending motion" stuff 
#         any more
# 8/27/07 modified reportfamily so levy DRs will just have a "reopened"
#         list with a suppress capabiliity
# 8/30/07 added definition for ROPRO I started using on 8/27. :-(

# TODO:
#    Pre-Initial Release:
#       make sure that numbers are the same! (where they should be)
#       write appropriate help screens for each report type
#
#    WHENEVER:
#       remove dependency on Alachua.pm
#       Simplify!
#       check all variables for use/need     
#       my-ify all vars possible at first use.
#       see if $tim,$webpath, other variables/functions can be eliminated
#       take all magic stuff out of code, into ICMS.conf variables
#       eliminate generic report category, if possible
#       create special table type in icms1.css so color codes can be
#       changed globally.

use DBI;
use Date::Calc qw(:all);
use ICMS;
use Alachua;
use strict;

my $outpath; # set in docounty()
my $outpath2; # set in report()
my $webpath; # set in docounty()
my $secpath; # set in docounty();

#
# this vars set in main from icms.conf values
# 
my $countynum;  # set in main
my $county;     # set in main
my $dbname;     # set in main
my $dbtype;     # set in main
my $casetype;   # set in main
my $splitflag;     # set in main
my $divlist;    # set in main
my $oddvals;    # set in main
my $tendate;    # set in main
#
my %caselist;
my %xrefcaseid;
my %xrefucn;
my %eventlist;
my %ticklerga;  # tickerl for guardianship cases
my %assignlist;
my %partylist;
my %dob;     # for wards, set by makeastyle
my %xref;
my %age;
my %style;
my %notes; 
my %flags; 
my %flagtypes; 
my %proflag; 
my %inmateflag;
my %attyflag;
my %dorflag;
my %cmcflag;
my %motiononflag;
my %motionoffflag;
my %formevents;
my %casehit; # set in makelist
my %judgelist; # set in buildthings
my %docket; # set in buildthings
my %pendingmotion; # set in buildtickler, buildnotes
my %finaljudgement; # set in buildtickler, buildnotes, too.
my %suppressflag; # set in buildnotes
my %cbrflag; # set in buildnotes

my $CASE; # name of case table, set in docounty()

my $CLINE="#EEFFCC";
my $TLINE="#D0FFD0";


my %rpttitle= (
"P"=>"Pending Cases",
"PPRO"=>"Pending Pro Se Cases",
"PCBR"=>"Circuit Bench Referral Cases",
"PINMATE"=>"Pending Inmate Cases",
"PDOR"=>"Pending DOR Cases",
"PN"=>"Pending Cases with No Events Scheduled",
"POG"=>"Open Guardianship Cases",
"POE"=>"Open Estate Cases",
"POM"=>"Open Mental Health Cases",
"PGT"=>"Guardianship Cases with no Future Ticklers Scheduled",
"PE210"=>"Estate Cases over 210 days old with no Events Scheduled",
"PG18"=>"Open Minor Guardianship Cases where Ward is 18 or Age Unknown",
"PS"=>"Secret Cases",
"PFOR"=>"Foreclosure Cases",
"PNFOR"=>"Non-Foreclosure Cases",
"PFLAGCMC"=>"Flagged \"Schedule CMC\"",
"PCC"=>"County Civil",
"PSC"=>"Small Claims",
"RO"=>"Reopened Cases",
"ROPRO"=>"Reopened Cases - Pro Se",
"RODOR"=>"Reopened Cases - DOR",
"ROA"=>"Active Reopened Cases",
"ROAPRO"=>"Active Reopened Cases - Pro Se",
"ROI"=>"Inactive Reopened Cases",
"ROPM"=>"Reopened Cases with Pending Petitions/Motions",
"ROPMPRO"=>"Reopened Cases with Pending Petitions/Motions - Pro Se",
"RONP"=>"Reopened Cases with no Pending Petitions/Motions",
"ROACBR"=>"Reopened Circuit Bench Referral Cases"
	    );

my $secdivlist=";AD;DR;"; # family divisions that get secret case reports
my $probdivlist=";A;B;CP;";
my $famdivlist=";DR;";  # Levy family only these days
my $famdivlist2=";AA;AD;DV;F;H;M;N;P;";
my $civdivlist=";J;K;";
my $countycivdivlist=";IV;Va;";
my $allsecdiv=";AD;"; # totally secret division

my $DOCKETIGNORE="'AC07-R','AR01-R','CE02-R','CE17-R','CE18-R','CK01-R','DOC-R','FA01-R','LE01-R','LE19-R','MA00-P','NO01-R','NO11-R','NO42-R','OR87-R','RE08-R','RE38-R','RE98-R','SDUC','SH06-R'";

my $pendingcodes; # set in docounty from %CODES

my $offcodes; # set in docounty from %CODES

my $DEBUG;     # set to 1, suppresses fresh queries; loads old data from files.


#
# issecdiv
#
sub issecdiv {
    my($div)=@_;
    if ($secdivlist=~/;$div;/) { return 1; }
    return 0;
    }


#
# istype returns "OG" if it's guardian case,
#        "OE" if it's estate, "OM" mental health, and "" otherwise;
#      
sub istype {
    my $case_id=$_[0];
    my $case_cd=$_[1];
    if ($case_cd=~/CPGA/) { return "POG"; }
    elsif ($case_cd=~/CP/) { return "POE"; }
    elsif ($case_cd=~/MHO/) { return "POM"; }
    else {
       return "";
       }
   }




#
# fixdatehash needed for Microsoft SQL via freetds, since convers
#

sub fixdatehash {
    my ($list,$ind,@arr,$key,$yc,$mc,$dc,$newdate);
    if ($dbtype eq "CV") { return; } # Courtview on Unix dates are OK.
    $list=$_[0];
    $ind=$_[1];
    foreach $key (sort keys %$list) {
	@arr=split '~',$$list{$key};
        if (defined $arr[$ind]) {
           ($yc,$mc,$dc)=Decode_Date_US(substr($arr[$ind],0,11));
           $newdate=sprintf "%02d/%02d/%04d",$mc,$dc,$yc;
           $arr[$ind]=$newdate;
           $$list{$key}=join '~',@arr;
           }
        }
    }

#
#  buildcaselist fills the global %caselist hash with a list of *ALL* 
#                open Civil cases in CourtView

sub buildcaselist {
   my %nc;
   my ($case_id,$dscr,$jdg_id,$file_dt,$case_cd,$actn_cd,$ucn);
   if ($DEBUG) {
      print "DEBUG: RELOADING OLD CASELIST\n";
      %caselist=readhash("$outpath/caselist.txt");
      %xrefcaseid=readhash("$outpath/xrefcaseid.txt");
      %xrefucn=readhash("$outpath/xrefucn.txt");
      return;
      }
   %caselist=sqlhash("select a.case_id,a.dscr,b.jdg_id,a.file_dt,a.case_cd,a.actn_cd,stat_cd,last_file_dt from cases a left join dspjdg b on a.case_id=b.case_id where a.stat_cd in ('O','RO','ROM','ROO') and a.actn_cd not like 'ML%' and a.case_cd not in ('PM','CM','CJ','DP','MM','CF') order by a.case_id,b.seq");
   fixdatehash(\%caselist,3);
   fixdatehash(\%caselist,7);
   foreach (values %caselist) {
      ($case_id,$ucn)=split '~';
      $ucn="$countynum-$ucn";
      $ucn=~s/ /-/g;
      $xrefcaseid{$case_id}=$ucn;
      $xrefucn{$ucn}=$case_id;
      }
   writehash("$outpath/caselist.txt",\%caselist);
   writehash("$outpath/xrefcaseid.txt",\%xrefcaseid);
   writehash("$outpath/xrefucn.txt",\%xrefucn);
   }




#
#  buildeventlist fills the global %eventlist hash with a list of the last 
#                event scheduled for open cases in the Civil System

sub buildeventlist {
   my %nc;
   my ($crtdt,$cgn,$crttype,$olddate,@xeventlist);
   if ($DEBUG) {
      print "DEBUG: RELOADING OLD EVENTLIST\n";
      %eventlist=readhash("$outpath/eventlist.txt");
      return;
      }
    %eventlist=sqlhash("select a.case_id,c.blk_dt,a.evnt_cd from evnt a,evnttm b,jdgblktm c, $CASE e where a.evnt_id=b.evnt_id and b.jdg_blktm_id=c.jdg_blktm_id and a.case_id=e.case_id and e.stat_cd='O' order by c.blk_dt");
    # hashing this list ordered by blk_dt will only preserve the last entry per case, which is exactly what we want here.
    %nc=sqlhash("select a.case_id,c.blk_dt,a.evnt_cd from evnt a,evnttm b,jdgblktm c, $CASE e, tkl f where a.evnt_id=b.evnt_id and b.jdg_blktm_id=c.jdg_blktm_id and a.case_id=e.case_id and a.case_id=f.case_id and e.stat_cd like 'RO%' and completion_dt is null and (tkl_cd='TC45CL') order by c.blk_dt");
    foreach (keys %nc) {
       $eventlist{$_}=$nc{$_};
       }
    fixdatehash(\%eventlist,1);
    #
    # now check formevents to make sure they show up 
    # (unless trumped by an existing eventlist entry) 
    #
    #
    foreach (keys %formevents) {
      my $caseid=$xrefucn{$_};
      if (!$eventlist{$caseid}) { # add this event
          my($ecasenum,$etype,$edate)=split '~',$formevents{$_};
	  $eventlist{$caseid}="$caseid~$edate~$etype";
         }
      else { # compare and add if justifiable
         my($ecasenum,$etype,$edate)=split '~',$formevents{$_};
         my($ocaseid,$odate,$oevent)=split '~',$eventlist{$caseid};
         if (compdate($edate,$odate)>0) { # more recent
            $eventlist{$caseid}="$caseid~$edate~$etype";
            }
         }
      }
    writehash("$outpath/eventlist.txt",\%eventlist);
    }



sub buildticklerlists() {
    $pendingcodes=~s/,/','/g;
    $offcodes=~s/,/','/g;
#    print "$pendingcodes\n$offcodes\n"; 
#    %pendingmotion=sqlhash("select a.case_id,dt,dkt_cd from dkt a,cases b where a.case_id=b.case_id and b.stat_cd in ('RO','ROM','ROO') and dkt_cd in ('$pendingcodes') and (dkt_st_cd is null or dkt_st_cd<>'D') order by a.case_id,dt");

#    %finaljudgement=sqlhash("select a.case_id,dt from dkt a,cases b where a.case_id=b.case_id and b.stat_cd in ('RO','ROM','ROO') and (dkt_cd in ('$offcodes') or (dkt_cd='OR01-R' and dkt_text not like '%REFERRAL%')) and (dkt_st_cd is null or dkt_st_cd<>'D') order by a.case_id,dt");

   writehash("$outpath/pendingmotion.txt",\%pendingmotion);
   writehash("$outpath/finaljudgement.txt",\%finaljudgement);
   if ($DEBUG) {
      print "DEBUG: RELOADING OLD TICKLERS\n";
      %ticklerga=readhash("$outpath/ticklerga.txt");
      return;
      }
   %ticklerga=sqlhash("select case_id from tkl a where due_dt>'$TODAY' and completion_dt is null");
   writehash("$outpath/ticklerga.txt",\%ticklerga);
   }


#
# buildassignlist fills the global %assignlist hash with the values
#                 contained in the assign.conf file (divname,judgeid,judgeid...)
#

sub buildassignlist() {
   my($key,$val);
   open(INFILE2,"$UTILSFILEPATH/assign.conf") or die "crtvciv.pl: Can't open assign.conf";
   foreach (<INFILE2>) {
      if (!/^\#/) {
         ($key,$val)=split ';';
         $assignlist{$key}=$val;
	}
    }
   close(INFILE2);
 }




#
#  buildpartylist fills the global %partylist hash with a list of *ALL*
#                parties for open cases in the Civil System

sub buildpartylist() {
   my (%nc,@plist,$oldcase,$newcase,$i,$dob,$ptytype,$pname);
   if ($DEBUG) {
      print "DEBUG: RELOADING OLD PARTYLIST\n";
      %partylist=readhash("$outpath/partylist.txt");
      return;
      }
   %partylist=sqlhash("select a.case_id, a.seq,pty_cd,c.last_name, c.first_name, c.middle_name, c.company_name,dob from pty a,$CASE b,idnt c where a.case_id=b.case_id and b.stat_cd='O' and b.actn_cd not like 'ML%' and a.idnt_id=c.idnt_id",2);
   #  (,2 signifies "hash on first two fields"--default is 1)
   %nc=sqlhash("select a.case_id, a.seq,pty_cd,c.last_name, c.first_name, c.middle_name, c.company_name,dob from pty a,$CASE b,idnt c where a.case_id=b.case_id and b.stat_cd like 'RO%' and a.idnt_id=c.idnt_id",2);
   foreach (keys %nc) {
      $partylist{$_}=$nc{$_};
      }
   fixdatehash(\%partylist,7);
   writehash("$outpath/partylist.txt",\%partylist);
   }



#
# makeastyle    makes a case style of the form "x v. y" where x and y are the
#               first plaintiff/defendant, petitioner/respondent, etc.
#               listed for a case.  It uses partylist
#               if it's a guardianship case, it sets the %dob hash for the case
#               if the case has a petitioner with FLORIDA in the name,
#               it makes and entry in the %dor hash for the case.


sub makeastyle {
   my($case_id,$actn_cd,$case_cd,$i,$outline,$oldtyp,$typ,$last,$first,$middle,$company,$name,$fullname,$key,$dob,$etal,$oneflag,%ptype,$x);
   if (scalar keys %partylist==0) { die "crtvciv.pl: makeastyle: partylist is empty."; }
   $case_id=$_[0];
   $case_cd=$_[1];
   $actn_cd=$_[2];
   $outline="";
   $oldtyp="";
   $etal=0;
   $oneflag=0;
   %ptype=();
   foreach $i (1..30) {  # 30 parties max
      $key="$case_id;$i";
      if (!defined $partylist{$key}) { next; } 
      ($typ,$last,$first,$middle,$company,$dob)=(split '~',$partylist{$key})[2..7];
      if (defined $company && trim($company) ne "") {
         $name=trim($company);
         }
      else {
         if (!defined $middle) { $middle=""; }
         if (!defined $first) { $first=""; }
         if (!defined $last) { $last=""; }
         $middle=trim($middle);
         $last=trim($last);
         $first=trim($first);

         $name="$last";
         if ($typ eq "DFNDT") { $fullname="$last, $first $middle"; }
         }
      if ($typ=~/DCDNT/) {
	  return "Estate of $last, $first $middle";
          }
      elsif ($typ=~/ADPT/) {
          if ($actn_cd eq "06P") {
             return "TPR of $last, $first $middle";
             }
          else {
             return "Adoption of $last, $first $middle";
	     }
          }
      elsif ($typ=~/WARD/) {
          if (defined $dob) { $dob{$case_id}=$dob; }
	  return "Guardianship of $last, $first $middle";
          }
      elsif ($typ=~/^AI/) {
	  return "Incapacity of $last, $first $middle";
          }
      elsif ($typ=~/OLDNM/) {
          return "The Name Change of $last, $first $middle";
          }
      elsif (!defined $ptype{$typ}) {
	  $ptype{$typ}=$name;
          }
      else { 
          if (!($ptype{$typ}=~/, et al./)) { $ptype{$typ}.=", et al."; }
          }
      }
   if (defined $ptype{'PLNTF'} and defined $ptype{'DFNDT'}) {
       return "$ptype{'PLNTF'} v. $ptype{'DFNDT'}";
      }
   elsif (defined $ptype{'CPLNT'} and defined $ptype{'DFNDT'}) {
       return "$fullname"; # traffic cases
      }
   elsif (defined $ptype{'PET'} and defined $ptype{'RSPND'}) {
       return "$ptype{'PET'} v. $ptype{'RSPND'}";
      }
   elsif (defined $ptype{'PET'} and defined $ptype{'RSPND'}) {
       return "$ptype{'PET'} v. $ptype{'RSPND'}";
      }
   elsif (defined $ptype{'PET'} and defined $ptype{'ADPPARENT'}) {
       return "In Re: Adoption of $ptype{'PET'}";
      }
   elsif (defined $ptype{'CTRE'} and defined $ptype{'CTPT'}) {
       return "$ptype{'CTRE'} v. $ptype{'CTPT'}";
      }
   elsif (defined $ptype{'HUSBAND'} and defined $ptype{'WIFE'}) {
      return "$ptype{'HUSBAND'} v. $ptype{'WIFE'}";
      }
   else { return join " ",sort values %ptype; }
  }




#
# buildthings fills the global %xref hash with an index of judge IDs for each 
#             pending case.  It also fills the %age hash with a list of case
#             ages in days.  It also fills the %style hash with a text style
#             for each case. Makeastyle also sets the %dob hash.

sub buildthings() {
   my($case_id,$case_cd,$dscr,$actn_cd,$stat_cd,$judge,$date,$last_file_dt);
   %xref=();
   %age=();
   %style=();
   %dob=();
   %judgelist=sqlhash("select jdg_id,first_name,middle_name,last_name from jdg a,idnt b where a.idnt_id=b.idnt_id");
   if ($DEBUG) {
       print STDERR "DEBUG: reloading docket.txt\n";
       %docket=readhash("$outpath/docket.txt");
       }
   else {
      %docket=sqlhash("select a.case_id,max(a.dt) from dkt a,cases b where a.case_id=b.case_id and b.stat_cd in ('O','RO','ROM','ROO') and b.actn_cd not like 'ML%' and b.case_cd not in ('PM','CM','CJ','DP','MM','CF') and a.dkt_cd not in ($DOCKETIGNORE) and (dkt_st_cd is null or dkt_st_cd<>'D') group by a.case_id");
      writehash("$outpath/docket.txt",\%docket);
      }
#   print scalar keys %docket, " entries in docket\n";
   foreach (values %caselist) {
       chomp;
      ($case_id,$dscr,$judge,$date,$case_cd,$actn_cd,$stat_cd,$last_file_dt)=(split '~')[0,1,2,3,4,5,6,7];
      $xref{$case_id}=$judge;
      if (defined $last_file_dt and $stat_cd=~/RO/ and $last_file_dt ne "") {
	  $age{$case_id}=getage($last_file_dt);
         }
      else {
         $age{$case_id}=getage($date);
         }
      $style{$case_id}=makeastyle($case_id,$case_cd,$actn_cd);
    }
 writehash("$outpath/styles.txt",\%style);
 }



#
# buildnotes fills the %notes hash with appropriate casenotes for this
#            division, and the %proflag hash with any pro se flags.

sub buildnotes {
    my ($key,$casenum,$flagtype,$fcol);
    dbdisconnect();
    dbconnect("casenotes");
    %notes=sqlhash("select casenum,note from casenotes where seq in (select max(seq) from casenotes where casenum like '$countynum-%' group by casenum)");
    %flags=sqlhash("select casenum,flagtype,date from flags where casenum like '$countynum-%'",2);
    %flagtypes=sqlhash("select flagtype,dscr from flagtypes");
    foreach $casenum (sort keys %notes) {
        $notes{$casenum}=(split '~',$notes{$casenum})[1]; # just the note
        $notes{$casenum}=~s/\;/&#59/g; # alias ; to &#59 to make different from delimiter
        }
    foreach $key (%flags) {
       ($casenum,$flagtype)=split ';',$key;
       if ($flagtypes{$flagtype}=~/Review/) { $fcol="red"; }
       else { $fcol="green"; }
       $notes{$casenum}="<font color=$fcol>&radic; ".(split '~',$flagtypes{$flagtype})[1]."</font> $notes{$casenum}";
       }
    %proflag=sqlhash("select casenum from flags where flagtype=2");
    %inmateflag=sqlhash("select casenum from flags where flagtype=1");
    %attyflag=sqlhash("select casenum from flags where flagtype=18");
    %dorflag=sqlhash("select casenum from flags where flagtype=11");
    %cmcflag=sqlhash("select casenum from flags where flagtype=12");
    %cbrflag=sqlhash("select casenum from flags where flagtype=32");
    %suppressflag=sqlhash("select casenum,date from flags where flagtype in (17,31)");
    my @mflags=sqllist("select casenum,date,flagtype from flags where flagtype in (16,17)");
    foreach (@mflags) {
       my($casenum,$date,$flagtype)=split '~';
       my $caseid=$xrefucn{$casenum};
       if ($flagtype==16) { # %pendingmotion, %finaljudgement
	   if ($pendingmotion{$caseid}) {
              my $tdate=(split '~',$pendingmotion{$caseid})[1];
              if (compdate($date,$tdate)==1) { # new date is later
		  $pendingmotion{$caseid}="$caseid~$date~Flag";
#		  print "PENDING MOTION $casenum,$caseid $date\n";
	         }
	      }
           else {
	       $pendingmotion{$caseid}="$caseid~$date~Flag";
#		  print "PENDING MOTION $casenum,$caseid, $date\n";
               }
           }
       elsif ($flagtype==17) { # %finaljudgement
	   if ($finaljudgement{$caseid}) {
              my $tdate=(split '~',$finaljudgement{$caseid})[1];
              if (compdate($date,$tdate)==1) { # new date is later
		 $finaljudgement{$caseid}="$caseid~$date";
#		  print "FINAL JUDGEMENT $casenum,$caseid, $date\n";
	         }
	      }
           else {
	       $finaljudgement{$caseid}="$caseid~$date";
#		  print "FINAL JUDGEMENT $casenum,$caseid, $date\n";
               }
           }
 
        }
    dbdisconnect();
    dbconnect("circuit8");
    %formevents=sqlhash("select casenum,etype,edate from events order by casenum,edate");
    foreach (sort keys %formevents) {
	my($casenum,$etype,$edate)=split '~',$formevents{$_};
        }
    # most recent event for a given case #
    dbdisconnect();
    dbconnect($dbname);
}



#
# makelist is called by report; it makes a list of case matching criteria
#          it returns the number of records matching that criteria
#
#
sub makelist {
   my(@judgecodes,$case,$jdgid,$i,$flag,$count,$style,$issecret,$case_id,$case_num,$jdg_id,$file_dt,$case_cd,$actn_cd,$stat_cd,$name,$evdate,$evtype,$it,$age,$acp,$bref,$reopen,$cdate,$tdue,$docketage);
   my($div,$sdiv,$crit,$xpath)=@_;
   $count=0;
   if ($splitflag) {
      @judgecodes=split ',',$assignlist{$div};
      if (scalar @judgecodes==0) {
         die "crtvciv.pl: No judge codes found for division *$div*\n";
         }
      }
   if (!$rpttitle{$crit}) {
      print "crtvciv.pl: Invalid Criteria $crit\n";
      return; 
      }
   open(OUTFILE,">$xpath/$crit.txt") or die "crtvciv.pl: Couldn't open $xpath/$crit.txt";
   if ($xpath=~/juv/) {
       $bref="<a href=$ROOTPATH/$county/juv/div$sdiv/index.html>";    
       }
   elsif ($xpath=~/prob/) {
       $bref="<a href=$ROOTPATH/$county/prob/div$sdiv/index.html>";
       }
   elsif ($xpath=~/traf/) {
        $bref="<a href=$ROOTPATH/$county/traf/div$sdiv/index.html>";
        }
   elsif ($xpath=~/secret/) {
        $bref="<a href=$ROOTPATH/$county/secret/div$sdiv/index.html>";
        }
   else {
      $bref="<a href=$ROOTPATH/$county/civ/div$sdiv/index.html>";
      }
   print OUTFILE <<EOS;
DATE=$MTEXT $DAY, $YEAR
TITLE1=$county County - $CIVILDIVNAME{$sdiv}
TITLE2=$rpttitle{$crit}
VIEWER=crtvview.cgi
EOS
    if ($crit eq "ROPM" or $crit eq "ROPMPRO") {
	print OUTFILE <<EOS;
FIELDNAMES=Case #~Name~Date~Age~Type~Event Date~Type~Pet./Mot. Date~Code~Flags/Notes
FIELDTYPES=L~A~D~G~A~D~A~D~A~A
EOS
        }
   elsif ($crit=~/ROA/) {
	print OUTFILE <<EOS;
FIELDNAMES=Case #~Name~Date~Age~Type~Event Date~Type~Docket Age~Flags/Notes
FIELDTYPES=L~A~D~G~A~D~A~G~A
EOS
        }
   else {
       print OUTFILE <<EOS;
FIELDNAMES=Case #~Name~Date~Age~Type~Event Date~Type~Flags/Notes
FIELDTYPES=L~A~D~G~A~D~A~A
EOS
        }
   foreach $case (keys %caselist) {
      ($case_id,$case_num,$jdg_id,$file_dt,$case_cd,$actn_cd,$stat_cd,$reopen)=split '~',$caselist{$case};
      my $xcase=substr($case_cd,0,2); 
      if ($splitflag) {
         $jdgid=$xref{$case};
         $flag=0;
         for ($i=0;$i<@judgecodes;$i++) {
            if ($jdgid==$judgecodes[$i]) {
               $flag++;
               last;
               }
            }
         if (!$flag) { next; } # skip those that don't match judge codes
         }
      elsif (not $div=~/$xcase/) { next; } # skip non-matching case codes
      $acp=substr($actn_cd,0,3);
      # If pending modification report, skip all those non-ROM cases
      #    (reopened-modification)
      $case_num="$countynum $case_num";
      $case_num=~s/ /-/g;
      my $ddate=fixdate((split '~',$docket{$case_id})[1]);
      # if it's an RO* division, and it's not an RO case, skip
      if (($crit=~/^RO/) and !($stat_cd=~/RO/)) { next; }

      # if it's a P* (pending) division, and not a Open (O) case, skip.
      if (($crit=~/^P/) and ($stat_cd ne "O")) { next; }

      # set DOR flag for appropriate actn_cds for Levy Cases
      #
      if ($countynum eq "38" and ",7013,7023,3009,"=~/,$actn_cd,/) {
	  $dorflag{$case_num}=1;
         }

      if (defined $eventlist{$case}) {
         ($evdate,$evtype)=(split '~',$eventlist{$case})[1,2]
         }
      else {
         $evdate=""; $evtype="";
         }

      if (defined $dob{$case_id}) {
	  $age=getage($dob{$case_id})/365.25;
          }
      else {
          $age=999;
          }

      if ($crit=~/PRO/) { # some pro se criteria
         if (not $proflag{$case_num}) { next; }
         }
      elsif ($crit=~/INMATE/) { # some inmate criteria
         if (not $inmateflag{$case_num}) { 
            next; 
            }
         }
      elsif ($crit=~/CBR/) { # some Circuit Bench Referral
	  if (not $cbrflag{$case_num}) { 
	      next;
	  }
      }
      elsif ($crit=~/DOR/ and not defined $dorflag{$case_num}) { next; } 
      elsif ($crit eq "PN" and $evdate ne "" and compdate($evdate,$tendate)>-1) { 
         next; 
         # if No events criteria, and case has event today or afterwards, skip
         }
      elsif (($crit=~/POG|POE|POM/) && (istype($case_id,$case_cd) ne $crit)) { next; } 
      elsif (($crit=~/PGT/) && ((istype($case_id,$case_id) ne "POG" || defined($ticklerga{$case_id}) ))) { next; }
      elsif ($crit eq "PE210") {
         if (istype($case_id,$case_cd) ne "POE") { next; } # estate cases
         if ($age{$case_id}<210) { next; }  # over 210 days only
         if ($evdate ne "" && compdate($evdate,$tendate)>-1) { next; } # no events
         }
      elsif ($crit eq "PG18") {
         if (istype($case_id,$case_cd) ne "POG") { next; }
         $actn_cd=trim($actn_cd);
         if (not (";B01;B03;"=~/;$actn_cd;/)) { next; }
         if ($age<18.0) { next; }
         } 
      elsif ($crit=~/^ROPM/) {
	  if (not $pendingmotion{$case_id}) { 
             next; 
             }
          if ($finaljudgement{$case_id}) { 
	      my $pmdate=(split '~',$pendingmotion{$case_id})[1];
	      my $fjdate=(split '~',$finaljudgement{$case_id})[1];
              if (compdate($pmdate,$fjdate)!=1) { 
                 next; 
                 }
             } 
         }
      elsif ($crit eq "RONP") { # no pending motions
	  if ($pendingmotion{$case_id}) { 
             if ($finaljudgement{$case_id}) { 
	         my $pmdate=(split '~',$pendingmotion{$case_id})[1];
	         my $fjdate=(split '~',$finaljudgement{$case_id})[1];
#                 print "RONP: $case_num: $case_id: $pmdate $fjdate\n";
                 if (compdate($pmdate,$fjdate)==1) { next; }
                 } 
             else { next; }
	     }
         }
      elsif ($crit=~/^RO/) { # RO and ROPRO allow suppress flag now...
          if ($suppressflag{$case_num}) {
	      my $suppdate=(split '~',$suppressflag{$case_num})[1];
              if (compdate($suppdate,$ddate)==1) { next; }
	     }
          }      

      $cdate=$file_dt; 

      #
      # secret case handling
      #
      $style=$style{$case_id};
      if (";DRAM;DRSE;DRHS;CASCR;DRA;"=~/\;$case_cd\;/) { $issecret=1; }
      else { $issecret=0; }
      if ($crit eq "PS" and not $issecret) { next; }
      if (($crit ne "PS" and issecdiv($div) and $issecret) and $div ne "AD") { next; }      
      if ($crit ne "PS" and not issecdiv($div) and $issecret and $div ne "AD") {
	  $style="** SECRET CASE **";
          }
      if ($crit eq "PFOR" && $actn_cd ne $CODES{"$countynum;FORECLOSCODE"}) { next; }
      if ($crit eq "PNFOR" && $actn_cd eq $CODES{"$countynum;FORECLOSCODE"}) { next; }
      if ($crit eq "PFLAGCMC" && not $cmcflag{$case_num}) { next; }

      # ROI - Reopened, Inactive (no docket for 180 days)
      if ($crit eq "ROI") {
          my $dage=getage(fixdate($ddate));
#          print "$case_id: $ddate: $dage\n";
          if ($dage<180) { next; }
          }
      # ROA - Reopened Active (meaningful docket activity last two years)
      # (includes ROAPRO, ROACBR)
      if ($crit=~/ROA/) {
          $docketage=getage($ddate);
#          print "ROA: docket age is  $docketage\n";
          if ($docketage>730) { next; } 
          if ($suppressflag{$case_num}) {
	      my $suppdate=(split '~',$suppressflag{$case_num})[1];
              if (compdate($suppdate,$ddate)==1) { next; }
	     }
          }
      #
      # RONP - Reopened with no Pending Petitions/Motions
      # (for F,H,M,AA, implement 20-year cutoff)
      if ($crit eq "RONP" and ";F;H;M;AA;"=~/;$div;/) {
          my $dageyear=getageinyears(fixdate($ddate));
          if ($dageyear>2) { 
             #print "RONP: skipping $case_num, $dageyear\n"; 
             next; 
             } # skip if over 2 years old
          }
      #
      # CC - open County Civil cases
      if ($crit eq "PCC" and not $case_num=~/CC/) { next; }
      # SC - open small claims cases
      if ($crit eq "PSC" and not $case_num=~/SC/) { next; }
      #
      #  NOW OUTPUT THE LINE
      #
      # Pending petitions show the petition that made them pending
      #
      if ($crit=~/^ROPM/) {
         my($pmdate,$pmcode)=(split '~',$pendingmotion{$case_id})[1,2];
         $pmdate=fixdate($pmdate);
         print OUTFILE "$case_num~$style~$cdate~$age{$case_id}~$actn_cd~$evdate~$evtype~$pmdate~$pmcode~$notes{$case_num}\n";
         }
      #
      # ROA lists age of most recent docket activity as well as age of case
      #
      elsif ($crit=~/ROA/) {
         my($pmdate,$pmcode)=(split '~',$pendingmotion{$case_id})[1,2];
         $pmdate=fixdate($pmdate);
         print OUTFILE "$case_num~$style~$cdate~$age{$case_id}~$actn_cd~$evdate~$evtype~$docketage~$notes{$case_num}\n";
         }
      else {
         print OUTFILE "$case_num~$style~$cdate~$age{$case_id}~$actn_cd~$evdate~$evtype~$notes{$case_num}\n";
         }
      $casehit{$case_id}++;
      $count++;
      }
   close(OUTFILE);
   return $count;
   }


#
# reportprobate is called for Alachua County probate divisions by report()
#

sub reportprobate {
   my($div,$tim);
   $div=$_[0];
   if (!-d $outpath) { mkdir($outpath,0755); }
   if (!-d "$outpath/div$div") { mkdir("$outpath/div$div",0755); }
   $tim="$YEAR-$M2";
   $outpath2="$outpath/div$div/$tim";
   if (!-d "$outpath2") { mkdir("$outpath2",0755); }

   my $numopen=makelist($div,$div,"P",$outpath2);
   my $numguard=makelist($div,$div,"POG",$outpath2);
   my $numestate=makelist($div,$div,"POE",$outpath2);
   my $nummental=makelist($div,$div,"POM",$outpath2);
   my $numgnotick=makelist($div,$div,"PGT",$outpath2);
   my $nume210nfe=makelist($div,$div,"PE210",$outpath2);
   my $numg18=makelist($div,$div,"PG18",$outpath2);
   my $numro=makelist($div,$div,"RO",$outpath2);
   my $numroi=makelist($div,$div,"ROI",$outpath2);
   my $tot=$numguard+$numestate+$nummental;

   open(OUTFILE,">$outpath2/index.html") or die "crtvciv.pl: Couldn't open $outpath2/index.html";

   reportheader(*OUTFILE,$county,$CIVILDIVNAME{$div},"helpprob");
   tabletitle(*OUTFILE,$CIVILDIVNAME{$div});


   if ($div ne "CP") {
       tableline(*OUTFILE,"POG","Guardianship",$numguard,"",$outpath2);
       tableline(*OUTFILE,"PGT","With no Future Ticklers",$numgnotick,"2",$outpath2);
       tableline(*OUTFILE,"PG18","Minor Cases where Ward is 18 or Age Unknown",$numg18,"2",$outpath2);
       tableline(*OUTFILE,"POE","Estate",$numestate,"",$outpath2);
      }
   else { 
       tableline(*OUTFILE,"P","Open Cases",$numopen,"",$outpath2); 
       }
   tableline(*OUTFILE,"PE210","Over 210 days old with no Future Events",$nume210nfe,"2",$outpath2);
   if ($div ne "CP") {
       tableline(*OUTFILE,"POM","Mental Health",$nummental,"",$outpath2);
#       tableline(*OUTFILE,"RO","Reopened Cases",$numro,"",$div,$tim);
#       tableline(*OUTFILE,"ROI","Inactive Reopened Cases",$numroi,"",$div,$tim);
       tabletotal(*OUTFILE,$tot);
       }
   else {
#      tableline(*OUTFILE,"RO","Reopened Cases",$numro,"",$outpath2);
      }

   reportfooter(*OUTFILE,$outpath2);
   close(OUTFILE);
   
   unlink("$outpath/div$div/index.html");
   symlink("$outpath2/index.html","$outpath/div$div/index.html");
   
   #
   # Write summary for judgepage
   #
   open(OUTFILE,">$outpath/div$div/rptsumm.txt") or die "crtvciv.pl: couldn's open rptsumm.txt";
   if ($div eq "CP") {
      print OUTFILE "$county County~Probate~$tot~\n",
      }
   else {
      # $sub: $num: $cnum 
       print OUTFILE "$county County~Probate Division $div: Guardianship~$numguard~\n";
       print OUTFILE "$county County~Probate Division $div: Estate~$numestate~\n";
       print OUTFILE "$county County~Probate Division $div: Mental Health~$nummental~\n";
      }
   close(OUTFILE);
   }
   



#
# reportfamily is used for Levy DR cases only at this point...
#

sub reportfamily {
   my($div)=@_;
   my($tim,$issecret,$secpath2);
   if (!-d $outpath) { mkdir($outpath,0755); }
   if (!-d "$outpath/div$div") { mkdir("$outpath/div$div",0755); }
   $tim="$YEAR-$M2";
   $outpath2="$outpath/div$div/$tim";
   $secpath2="$secpath/div$div/$tim";
   if (!-d "$outpath2") { mkdir("$outpath2",0755); }
   if (!-d "$secpath2") { mkdir("$secpath2",0755); }
   my $numopen=makelist($div,$div,"P",$outpath2);
   my $numdor=makelist($div,$div,"PDOR",$outpath2);
   my $numsec=makelist($div,$div,"PS",$secpath2); # secret cases in levy dr!
   my $numpro=makelist($div,$div,"PPRO",$outpath2);
   my $numro=makelist($div,$div,"RO",$outpath2);
   my $numropro=makelist($div,$div,"ROPRO",$outpath2);
   my $numrodor=makelist($div,$div,"RODOR",$outpath2);

   open(OUTFILE,">$outpath2/index.html") or die "crtvciv.pl: Couldn't open $outpath2/index.html";
   reportheader(*OUTFILE,$county,$CIVILDIVNAME{$div},"helpcrtvfam");
   tabletitle(*OUTFILE,$CIVILDIVNAME{$div});
   my $xpath=$outpath2;
   tableline(*OUTFILE,"P","Open Cases",$numopen,"",$xpath);
   tableline(*OUTFILE,"PDOR","DOR",$numdor,"2",$xpath);
   tableline(*OUTFILE,"PPRO","Pro Se",$numpro,"2",$xpath);
   if (issecdiv($div)) { # secret cases
      tableline(*OUTFILE,"PS","Secret Cases",$numsec,"",$secpath2);
      }
   tableline(*OUTFILE,"RO","Reopened Cases",$numro,"",$xpath);
   tableline(*OUTFILE,"ROPRO","Pro Se",$numropro,"2",$xpath);
   tableline(*OUTFILE,"RODOR","DOR",$numrodor,"2",$xpath);
   reportfooter(*OUTFILE,$outpath2);
   close(OUTFILE);

   unlink("$outpath/div$div/index.html");
   symlink("$outpath2/index.html","$outpath/div$div/index.html");
   #
   # Write summary for judgepage
   #
   open(OUTFILE,">$outpath/div$div/rptsumm.txt") or die "crtvciv.pl: couldn't open rptsumm.txt for div $div.";
   # $sub: $num: $cnum 
   print OUTFILE "$county County~$CIVILDIVNAME{$div}~$numopen~\n";
   print OUTFILE "$county County~Pro Se Cases~$numpro~2\n";
   print OUTFILE "$county County~Reopened Cases~$numro~2~\n";
   close(OUTFILE);
   }


#
# reportfamily2 is now used for divisiions: F,H,M,AA,AD
#               but will eventually be used for all family divisions
#               (we think) [ AD will need a separate report? ]

sub reportfamily2 {
   my($div)=@_;
   my($tim);
   if (!-d $outpath) { mkdir($outpath,0755); }
   if (!-d "$outpath/div$div") { mkdir("$outpath/div$div",0755); }
   $tim="$YEAR-$M2";
   $outpath2="$outpath/div$div/$tim";
   if (!-d "$outpath2") { mkdir("$outpath2",0755); }
   my $numopen=makelist($div,$div,"P",$outpath2);
   my $numdor=makelist($div,$div,"PDOR",$outpath2);
   my $numpro=makelist($div,$div,"PPRO",$outpath2);
   my $numcbr=makelist($div,$div,"PCBR",$outpath2);
   my $numroa=makelist($div,$div,"ROA",$outpath2);
   my $numroapro=makelist($div,$div,"ROAPRO",$outpath2);
   my $numrocbr=makelist($div,$div,"ROACBR",$outpath2);

   open(OUTFILE,">$outpath2/index.html") or die "crtvciv.pl: Couldn't open $outpath2/index.html";

   reportheader(*OUTFILE,$county,$CIVILDIVNAME{$div},"helpcrtvfam2");
   tabletitle(*OUTFILE,$CIVILDIVNAME{$div});
   tableline(*OUTFILE,"P","Open Cases",$numopen,"",$outpath2);
   if (!$splitflag) { # split county has a DOR division
       tableline(*OUTFILE,"PDOR","PDOR",$numdor,"2",$outpath2);
       }
   tableline(*OUTFILE,"PPRO","Pro Se",$numpro,"2",$outpath2);
   if ($div=~/N|P/) {
       tableline(*OUTFILE,"PCBR","Circuit Bench Referral Cases",$numcbr,"2",$outpath2);
       }
   tableline(*OUTFILE,"ROA","Active Reopened Cases",$numroa,"",$outpath2);
   tableline(*OUTFILE,"ROAPRO","Pro Se",$numroapro,"2",$outpath2);
   if ($div=~/N|P/) {
       tableline(*OUTFILE,"ROACBR","Circuit Bench Referral Cases",$numrocbr,"2",$outpath2);
       }
   reportfooter(*OUTFILE,$outpath2);

   close(OUTFILE);

   unlink("$outpath/div$div/index.html");
   symlink("$outpath2/index.html","$outpath/div$div/index.html");
   #
   # Write summary for judgepage
   #
   open(OUTFILE,">$outpath/div$div/rptsumm.txt") or die "crtvciv.pl: couldn't open rptsumm.txt for div $div.";
   print OUTFILE "$county County~$CIVILDIVNAME{$div}~$numopen~\n";
   print OUTFILE "$county County~Pro Se Cases~$numpro~2\n";
   close(OUTFILE);
   }



#
# reportcivil is called for civil division cases
#

sub reportcivil {
   my($div,$numpending,$numnoevent,$numcmc,$numro,$href,$tim,$name,$dp);
   $div=$_[0];
   if (!-d $outpath) { mkdir($outpath,0755); }
   if (!-d "$outpath/div$div") { mkdir("$outpath/div$div",0755); }
   $tim="$YEAR-$M2";
   $outpath2="$outpath/div$div/$tim";
   if (!-d "$outpath2") { mkdir("$outpath2",0755); }

   $numpending=makelist($div,$div,"P",$outpath2);
   $numnoevent=makelist($div,$div,"PN",$outpath2);
   my $numfor=makelist($div,$div,"PFOR",$outpath2);
   my $numnfor=makelist($div,$div,"PNFOR",$outpath2);
   my $numflagcmc=makelist($div,$div,"PFLAGCMC",$outpath2);
   my $numroa=makelist($div,$div,"ROA",$outpath2);
#   my $numroi=makelist($div,$div,"ROI",$outpath2);

   open(OUTFILE,">$outpath2/index.html") or die "crtvciv.pl: Couldn't open $outpath2/index.html";

   reportheader(*OUTFILE,$county,$CIVILDIVNAME{$div},"helpciv");
   tabletitle(*OUTFILE,$CIVILDIVNAME{$div});
   tableline(*OUTFILE,"P","Open Cases",$numpending,"",$outpath2);
   tableline(*OUTFILE,"PFOR","Foreclosures",$numfor,"2",$outpath2);
   tableline(*OUTFILE,"PNFOR","Non-Foreclosures",$numnfor,"2",$outpath2);
   tableline(*OUTFILE,"PFLAGCMC","Flagged \"Schedule CMC\"",$numflagcmc,"2",$outpath2);
   tableline(*OUTFILE,"PN","With no Future Events",$numnoevent,"2",$outpath2);
   tableline(*OUTFILE,"ROA","Active Reopened Cases",$numroa,"",$outpath2);
#   tableline(*OUTFILE,"ROI","Inactive Reopened Cases",$numroi,"2",$outpath2);
   reportfooter(*OUTFILE,$outpath2);

   close(OUTFILE);

   unlink("$outpath/div$div/index.html");
   symlink("$outpath2/index.html","$outpath/div$div/index.html");
   #
   # Write summary for judgepage
   #
   open(OUTFILE,">$outpath/div$div/rptsumm.txt") or die "crtvciv.pl: couldn't open rptsumm.txt for div $div.";
   # $sub: $num: $cnum 
   print OUTFILE "$county County~$CIVILDIVNAME{$div}~$numpending~\n";
   close(OUTFILE);
   }



#
# "Generic" Civil report (now divs Q,R,S & W)
#

sub reportgeneric {
   my($div)=@_;
   my($numpending,$numnoevent,$numreopen,$numinmate,$numprose,$numdor,$tim,$name,$dp);
   if (!-d "$outpath/div$div") { mkdir("$outpath/div$div",0755); }
   $tim="$YEAR-$M2";
   $outpath2="$outpath/div$div/$tim";
   if (!-d "$outpath2") { mkdir("$outpath2",0755); }
   $numpending=makelist($div,$div,"P",$outpath2);
   $numnoevent=makelist($div,$div,"PN",$outpath2);

   my $numroa=makelist($div,$div,"ROA",$outpath2);
   $numreopen=makelist($div,$div,"RO",$outpath2);
   my $numroi=makelist($div,$div,"ROI",$outpath2);

   $numinmate=makelist($div,$div,"PINMATE",$outpath2);
   $numprose=makelist($div,$div,"PPRO",$outpath2);
   open(OUTFILE,">$outpath2/index.html") or die "crtvciv.pl: Couldn't open $outpath2/index.html";

   reportheader(*OUTFILE,$county,$CIVILDIVNAME{$div},"helpgen");
   tabletitle(*OUTFILE,$CIVILDIVNAME{$div});
   tableline(*OUTFILE,"P","Pending Cases",$numpending,"",$outpath2);
   if ($div ne "GA" and $div ne "MH") {
      tableline(*OUTFILE,"PINMATE","Inmate",$numinmate,"2",$outpath2);
      tableline(*OUTFILE,"PPRO","Pro Se",$numprose,"2",$outpath2);
      }
   tableline(*OUTFILE,"PN","With no Future Events",$numnoevent,"2",$outpath2);
#   if ($div eq "W") {
       tableline(*OUTFILE,"ROA","Active Reopened Cases",$numroa,"",$outpath2);
#      }
#   else {
#     tableline(*OUTFILE,"RO","Reopened Cases",$numreopen,"",$outpath2);
#     tableline(*OUTFILE,"ROI","Inactive Reopened Cases",$numroi,"",$outpath2);
#     }
   reportfooter(*OUTFILE,$outpath2);

   close(OUTFILE);

   unlink("$outpath/div$div/index.html");
   symlink("$outpath2/index.html","$outpath/div$div/index.html");
   #
   # Write summary for judgepage
   #
   open(OUTFILE,">$outpath/div$div/rptsumm.txt") or die "crtvciv.pl: couldn't open rptsumm.txt for division $div.";
   # $sub: $num: $cnum 
   print OUTFILE "$county County~$CIVILDIVNAME{$div}~$numpending~\n";
   close(OUTFILE);
   }




#
# for County Civil Divisions (IV & Va)
#
sub reportcountycivil {
   my($div)=@_;
   my($tim,$name);
   if (!-d "$outpath/div$div") { mkdir("$outpath/div$div",0755); }
   $tim="$YEAR-$M2";
   $outpath2="$outpath/div$div/$tim";
   if (!-d "$outpath2") { mkdir("$outpath2",0755); }

   my $numpending=makelist($div,$div,"P",$outpath2);
   my $numnoevent=makelist($div,$div,"PN",$outpath2);
   my $numreopen=makelist($div,$div,"RO",$outpath2);
   my $numcc=makelist($div,$div,"PCC",$outpath2);
   my $numsc=makelist($div,$div,"PSC",$outpath2);

   open(OUTFILE,">$outpath2/index.html") or die "crtvciv.pl: Couldn't open $outpath2/index.html";

   reportheader(*OUTFILE,$county,$CIVILDIVNAME{$div},"crtvhelpcc");
   tabletitle(*OUTFILE,$CIVILDIVNAME{$div});
   tableline(*OUTFILE,"P","Pending Cases",$numpending,"",$outpath2);
   tableline(*OUTFILE,"PSC","Small Claims",$numsc,"2",$outpath2);
   tableline(*OUTFILE,"PCC","County Civil",$numcc,"2",$outpath2);
   tableline(*OUTFILE,"PN","With no Future Events",$numnoevent,"2",$outpath2);
   tableline(*OUTFILE,"RO","Reopened Cases",$numreopen,"",$outpath2);
   reportfooter(*OUTFILE,$outpath2);

   close(OUTFILE);

   unlink("$outpath/div$div/index.html");
   symlink("$outpath2/index.html","$outpath/div$div/index.html");
   #
   # Write summary for judgepage
   #
   open(OUTFILE,">$outpath/div$div/rptsumm.txt") or die "crtvciv.pl: couldn't open rptsumm.txt for division $div.";
   # $sub: $num: $cnum 
   print OUTFILE "$county County~$CIVILDIVNAME{$div}~$numpending~\n";
   close(OUTFILE);
   }




#
# report is called once per division
#

sub report {
   my($div)=@_;
#   print "Running report for $div\n";
   # CourtView DP & CJ cases are handled by crtvdep.pl & crtvdel.pl
   if (($div eq "DP" or $div eq "CJ")) { return; }
   if ($probdivlist=~/;$div;/)   {   reportprobate($div); }
   elsif ($famdivlist=~/;$div;/) {   reportfamily($div); }
   elsif ($famdivlist2=~/;$div;/) {   reportfamily2($div); }
   elsif ($civdivlist=~/;$div;/) {   reportcivil($div);  }
   elsif ($countycivdivlist=~/;$div;/) {   reportcountycivil($div);  }
   else {                            reportgeneric($div); }
  }
   


#
# buildarchive builds the archive web page for each civil division
#


sub buildarchive {
  my($div,@allfiles,$fname,$flag,$year,$month,$mtext,$sdiv);
  foreach $div (split ',',$divlist) {
      if ($div eq "DP" or $div eq "CJ") { next; }
      $sdiv=$div;
      # to handle SC:SP, if it contains SC, treat it as SC
      if ($sdiv=~/SC/) { $sdiv="SC"; } 
      opendir THISDIR,"$outpath/div$sdiv" || die "crtvciv.pl: Can't open directory $outpath/div$div";
      @allfiles=reverse sort( grep !/^\.\.?$/, readdir THISDIR);
      closedir THISDIR;
      open OUTFILE,">$outpath/div$sdiv/archive.html" or die "crtvciv.pl: Can't open archive $outpath/div$sdiv/archive.html";
      reportheader(*OUTFILE,$county,"$CIVILDIVNAME{$sdiv} Archive","archivehelp",3);
      $flag=0;
      foreach $fname (@allfiles) {
	if (!($fname=~/^[0-9]/)) { next; }
	if (!$flag) { $flag++; next; }   # skip the current report
         ($year,$month)=split '-',$fname;
         $mtext=Month_to_Text($month);
         print OUTFILE "<div class=h2><a href=$fname>$mtext, $year</a></div>";
      }
      print OUTFILE "<p><font size=-2><i>Court Technology Department, 8th Judicial Circuit of Florida</i></font>";
      close(OUTFILE);
    }
}



#
# docounty is called once per county - it builds case lists and 
#   generates reports for that county.
#

sub docounty {
    my ($case,$ucn,$code);
    if (not defined dbconnect($dbname)) {
        print "   **ERROR**: crtvciv.pl: Couldn't connect to database $dbname; skipping\n";
        return;
    }
   $outpath="/var/www/html$ROOTPATH/$county/civ";
   $secpath="/var/www/html$ROOTPATH/$county/secret";
   $webpath="$ROOTPATH/$county/civ";
   if (!-d "$ROOTPATH/$county") { mkdir("/var/www/html$ROOTPATH/$county",0755); }
   if (!-d $outpath) { mkdir($outpath,0755); }
   if (!-d $secpath) { mkdir($secpath,0755); }
   
   # The Informix and Microsoft SQL server versions of CourtView
   # use a different name for the "case" table. $CASE gets around this.

   if ($dbtype eq "CV2") { $CASE="cases"; }
   else { $CASE="case"; }
   $pendingcodes=$CODES{"$countynum;PENDINGCODES"};
   $offcodes=$CODES{"$countynum;OFFCODES"};

   buildcaselist();
   buildnotes();
   buildeventlist();
   buildticklerlists();
   buildassignlist();
   buildpartylist();
   buildthings();
   foreach (split ',',$divlist) {
      report($_);
      }
   buildarchive();
   dbdisconnect();
    my %judgexref;
    foreach $case (keys %caselist) {
        $ucn=$xrefcaseid{$case};
        $code=substr($ucn,8,2);
	if (not $casehit{$case}) {
            my($cgn,$casenum,$jdgcd,$fdate,$casecd,$actncd,$stat,$rodate)=split '~',$caselist{$case};
            if ($judgelist{$jdgcd}=~/REASSIGNED|UNASSIGNED|INACTIVE/) { next; }
            $judgexref{$judgelist{$jdgcd}}++;
	}
    }
 open LOGFILE,">/var/log/crtvciv.$county.rpt" or die "crtvciv.pl: Couldn't open report log /var/log/crtvciv.$county.rpt\n";
    if ((scalar keys %judgexref)>0) {
        print LOGFILE "The following civil cases appear on NO REPORT:\n\n";
        foreach (keys %judgexref) {
	   print LOGFILE "$_: $judgexref{$_}\n";
           }
      }
 close LOGFILE;
}



#
# MAIN PROGRAM STARTS HERE!
#
$DEBUG=0;
#print "$TIMESTAMP crtvciv.pl...\n";
# tendate is used to check event ages
my ($yearev,$monthev,$dayev)=Add_Delta_Days($YEAR,$MONTH,$DAY,-10);
$tendate=sprintf "%02d/%02d/%d",$monthev,$dayev,$yearev;

if ($ARGV[0] eq "DEBUG" or $ARGV[1] eq "DEBUG") { $DEBUG=1; }

$SQLPROFILE=0;

foreach (@DATABASES) {
   ($countynum,$county,$dbname,$dbtype,$casetype,$divlist,$oddvals)=(split ';')[0..5,7];
   if ($casetype ne "civ") { next; } # civil only
   if (not $dbtype=~/CV/) { next; }  # courtview only
   if ($oddvals=~/SPLITCIV/) { $splitflag=1; }
   else { $splitflag=0; }
   if (($ARGV[0] eq "") or ($ARGV[0] eq $county)) {
#      print timestamp()," $county\n";
      docounty();
      }
  }
#print timestamp()," crtvciv.pl Finished\n";
