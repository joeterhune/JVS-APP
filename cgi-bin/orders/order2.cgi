#!/usr/bin/perl
#
#  orders2.cgi - generates PDF form orders from data
#
# derived from galrpt2.cgi
# 8/16/07 added built-in parenthesis handling
# 06/11/10 added Levy Support
# 06/15/10 added Union Civil support
# 06/23/10 fixed bug in judge names
# 07/09/10 made CC lists allow for long names
# 08/17/10 added initial space supression on word wrap
# 08/18/10 added support for flags, and NOSLASHS flag
# 08/18/10 created JAsig that isn't affected by NOSLASHS
# 09/27/10 added support for ALLOWSAMETIME flag
# 10/7/10 added support for page headers
# 10/8/10 added logging via ordergenlog table
# 10/22/10 added #include functionality...non-nesting, please!
# 10/28/10 lms 	Modified for 15th circuit.
# 04/11    lms 	getting back to PBC modifications
# 04/11    lms 	add underline support: <u></u> tags and /t tag for title
#		(centered, bold, underlined)
# 04/11    lms 	top of form may have:
#              	plaints vs defs (8th's 'parties')
#              	pets vs resps,
#              	pets vs decds, or just defendants in addition to 8th's
#		parties (plaints vs defs)
# 04/11    lms 	add support for drop down selections
#          lms 	checkboxes for produce/generate copies and envelopes (8th
#		always produced these)
#          lms 	maxcopies parameter now passed - - hidden var set in
#		order.cgi - for max copies to generate
#          lms 	moved the envelopes to end of generation (so that all will be
#		generated, even if more than max copies)
#          lms 	add support for <a> </a> tags - for ADA text - always 14pt
#          lms 	added another checkbox to produce (or not produce) the
#		address list page
#          lms 	don't show form name on header (per counsel)
#          lms 	get username from info CGI
#          lms 	new field:  eaddr for courthouse address
# 05/12/11 lms 	fix vs. (was -- vs. --)
# 05/11    lms 	attempting esignatures - new tag %esig% is where the
#		electronic signature should go and new %estamp% for electronic
#		stamp file#
# 05/24/11 lms 	Changed the processing to read both the orders.conf file, then
#		the new form file.  This way, the fieldlist hash will be
#		accurate (field in form file will override field in conf file,
#		if duplicate).  Also, just processing the fields in the form
#		(rather than all the ones in the conf file).
#              	Note:  every .form file must have ORDER, FIELDS, and FORM
#		tags, in this order!
# 05/25/11 lms 	Putting code into Production - including esignature support.
#		Signature files go in the sigs folder and must be in the
#		format of username_sig.tif and username_stamp.tif to be
#		recognized and used.
# 05/26/11 lms 	Chomp when doing title. Fix type checking to use ~/ rather
#		than eq. (CHECKBOX was breaking.)
# 05/31/11 lms 	Adding new tags (for Juvenile):
#		%kids% to show Child or Children with no label below them.
#		%minors% to show kids with "Minor Child" or "Minor Children"
#		below it/them.
#              	Adding new block tags \copystart and \copyend in FIELDS
#		section to create a list of additional copy party lines.
#              	We won't produce envelopes/copies for these.  Must have
#		accompanying %copylist% in FORM body to show.
#              	Cleaned up address line entry fields (trim).
#          lms 	Adding new tag \selectkids in FIELDS section to create list
#		of selectable children on entry page.
#              	%selectkids% tag in FORM body drops them in.
# 06/05/11 lms 	Amy Borman wanted a blank line after 'vs.' - - so all get
#		it ;-)
# 06/17/11 lms 	Added new %thisyear% for displaying the current year
#		somewhere on a form.
# 06/17/11 lms 	Fixed ccaddr list so that empty lines don't print with comma
#		separators.
#
#          lms 	BUGBUG - still need to work on what happens if electronic
#		signature/stamp cross a page boundary!!!!

use lib "$ENV{'PERL5LIB'}";
use strict;
use DBI;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use ICMS;
use Date::Calc qw(:all Date_to_Text_Long);
use PDF::Create;
use PDF::API2;
use Cwd;
use File::Temp qw / :POSIX /;
use Common qw(dumpVar);

my $info=new CGI;

my $username=$info->remote_user();

#
# other global vars...
#
my %vars;
my $caseid;
my ($numparties,$numkids,$numextracc,$rpttype,$test,$dbtype,$ucn,$formdesc,
    $pagenum);
my (@addrlist,@ccaddrlist,@extracc,@kidslist,@errlist,%jas,%interval);
my ($penvelopes,$pcopies,$paddresses,$usees);

my $returnAddress = $info->param('returnAddr');

my $DPATH="/usr/local/icms/cgi-bin/orders/forms";
my $SIGS="/usr/local/icms/cgi-bin/orders/sigs/";
my $FLAGS="";
my $FFEXT=".form";  # form file extension

my $maxcopies = 0;  # hidden var

my $pdf2; 	    # for API2
my $page2;    	# for API2

# for esignatures
# used for esignature placeholder - one per doc
my ($esfound,$espage,$escnt,$esy);
# stamp place holders (each one is page~ycord) - mult per doc
my @esstamps=();
# used to determine if esignature files exist
my ($essigexists,$esstampexists);
my $essigfn = $SIGS.$username."_sig.tif";
my $esstampfn = $SIGS.$username."_stamp.tif";
$essigexists=$esstampexists=0;
if (-e $essigfn) {$essigexists = 1;}
if (-e $esstampfn) {$esstampexists = 1;}


#
# drawimage - quick test to draw an image file on a PDF page...
#             image comes from a signature pad or a stored .tiff file

sub drawimage {
    # these really change in fred's sig code...
    my $centerx=306; # half of 612
    my($fname,$isnew,$ypos)=@_;
    my $liney=$ypos;
    my $gfx=$page2->gfx;
    my $image=$pdf2->image_tiff($fname);
    my($scale,$bw,$bh);
    my $imagex=$centerx;
    if ($isnew) {
	$scale=.33;  # was .125 for 8th...
	$bw=1708*$scale; # a fixed box size (was 1708x341
	$bh=341*$scale;
	$liney-=$bh;
    } else { # stored image, 1116x317 pixels, 300dpi but it things it's 96dpi
	$scale=.25;
	$liney-=72;
	$imagex-=36;
    }
    $gfx->image($image,$imagex,$liney,$scale);
    if ($isnew) {
	$gfx->strokecolor('white'); # use white so the box outline doesn't show
	$gfx->move($centerx,$liney);
	$gfx->line($centerx+$bw,$liney);
	$gfx->line($centerx+$bw,$liney+$bh);
	$gfx->line($centerx,$liney+$bh);
	$gfx->line($centerx,$liney);
	$gfx->stroke;
    }
}



#
# fixdate makes dates of form mm/dd/yyyy
#
sub myfixdate {
    my($date)=@_;
    if ($date eq "") {
	return "";
    }
    my($m,$d,$y)=split '/',$date;
    if ($y<100) { $y+=2000; }
    return sprintf("%02d/%02d/%04d",$m,$d,$y);
}

#
# Takes a text representation of a time and returns it as $hour,$min
#         on a 24h clock.
#
sub text_to_time {
    my($intime)=@_;
    my($hour,$min,$ampm);
    if ($intime=~/(\d+)\:(\d+)/) {
	$hour=$1;
        $min=$2;
        if ($intime=~/(a|p)/i) {
	    $ampm=$1;
            if ($ampm=~/p/i and $hour!=12) {
		$hour+=12;
	    } elsif ($ampm=~/a/i and $hour==12) {
                $hour-=12;
	    }
            return($hour,$min);
	}
    }
    return (-1,-1);
}


sub time_to_text {
    my($hour,$min)=@_;
    if ($hour==-1) { return ""; }
    if ($hour==0) {
	return sprintf("12:%02d AM",$min);
    } elsif ($hour<12) {
	return sprintf("%d:%02d AM",$hour,$min);
    } elsif ($hour==12) {
	return sprintf("12:%02d PM",$min);
    } elsif ($hour>12) {
	return sprintf("%d:%02d PM",$hour-12,$min);
    }
}



sub add_time {
    my($hour,$min,$delta)=@_;
    $min+=$delta;
    if ($min>=60) {
	$min-=60;
	$hour++;
	if ($hour>=24) {
	    $hour-=24;
	}
    }
    return($hour,$min);
}

sub check_time {
    my($time,$edate,$eloc,$eaddr)=@_;
    if ($edate eq "" or $time eq "") {
	return;
    }
    if ($eloc eq "") {
	push(@errlist,"Hearing Location is blank--must be filled in.");
    }
    if ($eaddr eq "") {
	   push(@errlist,"Hearing address is blank--must be filled in.");
    }
    my(@list,$holiday,$hdate,$hname,$everyyear,$hm,$hd,$hy,$em,$ed,$ey);
    my($hour,$min)=text_to_time($time);
    if ($hour<0 or $hour>23 or $min>60 or $min<0) {
	push(@errlist,"Error: Invalid Time $time\n");
    }
    if ($hour<8 or $hour>17) {
	push(@errlist,"Event time of $time is out of normal business day range.\n");
    }
    $time=time_to_text($hour,$min);
    if (!$FLAGS=~/ALLOWSAMETIME/) { # otherwise, check for time collisions
	my $query = qq {
	    select
		casenum
	    from
		events
	    where
		edate='$edate'
		and  eloc='$eloc'
		and eaddr='$eaddr'
		and (estart<='$time' and '$time'<=eend)
	};

	@list=sqllist($query);
	if (@list) {
	    push(@errlist,"Event Date & Time $edate $time conflicts with ".
		 "existing event for case $list[0].\n");
	}
    }

    # now check against weekends/holidays
    ($em,$ed,$ey)=split '/',$edate;
    if ($ey<100) {
		$ey+=2000;
    }
    $ed=Day_of_Week($ey,$em,$ed);
    if ($ed>=6) {
	if ($ed==6) {
	    $ed="Saturday";
	} else {
	    $ed="Sunday";
	}
	push(@errlist,"Event Date $edate is on a $ed\n");
    }
    my $query = qq {
	select
	    date,
	    name,
	    everyyear
	from
	    holidays
    };
    @list=sqllist($query);
    foreach $holiday (@list) {
	($hdate,$hname,$everyyear)=split '~',$holiday;
        ($hm,$hd,$hy)=split '/',$hdate;
        if ($everyyear) { $hy=$ey; }
        $hdate=myfixdate("$hm/$hd/$hy");
        if ($hdate eq $edate) {
           push(@errlist,"Event Date $edate conflicts with holiday $hname.\n");
           }
       }
    return $time;
    }

# modified for 15th - - 8th had addr parts on separate lines.  we want just
#one line for all parts, separated by commas.
sub buildaddrlist {
    my($i,$addrline,$x,$realcount,$ta);
    for ($i=0;$i<$numparties;$i++) {
	if ($info->param("check$i") eq "on") {
	    # build addr list for envelopes
	    $addrline=$info->param("name$i");
	    $addrline.="~".$info->param("addr1$i");
	    $x=$info->param("addr2$i");
	    if ($x ne "") {
		$addrline.="~$x";
	    }
	    $x=$info->param("addr3$i");
	    if ($x ne "") {
		$addrline.="~$x";
	    }
	    $addrline.="~".$info->param("csz$i");
	    $addrline=trim($addrline);
	    $ta = $addrline;
	    $ta=~s/,| //g;  # remove all commas and blanks
	    if($ta ne '') {
		push(@addrlist,$addrline);
	    }

	    # build addr list for cc section
	    $addrline=$info->param("name$i");
	    $x=trim($info->param("addr1$i"));
	    if ($x ne "") {
		$addrline.=", $x";
	    }
	    $x=trim($info->param("addr2$i"));
	    if ($x ne "") {
		$addrline.=", $x";
	    }
	    $x=trim($info->param("addr3$i"));
	    if ($x ne "") {
		$addrline.=", $x";
	    }
	    $x=trim($info->param("csz$i"));
	    if ($x ne "") {
		$addrline.=", $x";
	    }
	    if($addrline ne '') {
		push(@ccaddrlist,$addrline);
	    }
	}
    }
}

# new for 15th - extra cc list - built from user entry on the form
# - - /copystart, /copyend in DFIELDS section to define and using %copylist%
# in form text
sub buildextracc {
    my($i,$addrline);
    for ($i=0;$i<$numextracc;$i++) {
	if ($info->param("eccheck$i") eq "on") {
	    # build addr list for cc section
	    $addrline=trim($info->param("ecaddr$i"));
	    if($addrline ne '') {
		push(@extracc,$addrline);
	    }
	}
    }
}

# new for 15th - selectable children list (for ufc) - built from user entry
# on the form - - /selectkids section to define and using %selectkids% in
# form text
sub buildkids {
    my($i,$kid);
    for ($i=0;$i<$numkids;$i++) {
	if ($info->param("skcheck$i") eq "on") {
	    # build list for %selectkids% section
	    $kid=trim($info->param("skname$i"));
	    if($kid ne '') {
		push(@kidslist,$kid);
	    }
	}
    }
}

sub addevent {
    my($ucn,$etype,$edate,$etime,$eend,$eloc,$eaddr)=@_;
    # expects eaddr to have the courthouse as the first element
    my @house =();
    @house=split ',',$eaddr;
    my $house = $house[0];
    $house = substr $house, 0, index($house, 'Courthouse');
    my $query = qq {
	insert into
	    events (casenum,etype,edate,estart,eend,eloc,eaddr)
	values
	    ('$ucn','$etype','$edate','$etime','$eend','$eloc','$house')
    };
    ask($query);
}


#
# addlogentry creates an entry in the ordergenlog table
#

sub addlogentry {
    my($ucn,$rpttype,$test,$pdfnm)=@_;
    if ($test eq "on") {
	$test="y";
    } else {
	$test="n";
    }
    my $query = qq {
	insert into
	    ordergenlog (ucn,formtype,formuser,gendate,pdffile,istest)
	values
	    ('$ucn','$rpttype','$username',now(),'$pdfnm','$test')
    };
    ask($query);
}

#
# Getwidth (font,size,string) returns the width of a string in points
#          written with the font & point size specified.
#

sub getwidth {
    my $font=shift;
    my $size=shift;
    my $string=shift;
    my $page=shift;
    my $width=$page->string_width($font,$string);
    return $size*$width;
}

#
# getmaxwidth determines the maximum width of each column
#

sub getmaxwidths {
    my $font=shift;
    my $size=shift;
    my $list=shift;
    my $page=shift;
    my @width;
    my(@j,$i,$k);
    foreach (@$list) {
	@j=split ';';
        for ($i=0;$i<@j;$i++) {
	    $k=getwidth($font,$size,$j[$i],$page);
	    if ($width[$i]<$k) {
		$width[$i]=$k;
	    }
	}
    }
    return @width;
}


sub varsub {
    my($line,$copynum)=@_;
    my($varname,$vv);
    while ($line=~/%(\w+)%/) {
	$varname=$1;
	if ($varname eq "sig") {
	    if ($copynum==1 || $FLAGS=~/NOSLASHS/) {
		$line=~s/%sig%/_________________________________________/;
	    } else {
		$line=~s#%sig%# /s/#;
	    }
	} elsif ($varname eq "jasig") {
	    if ($copynum==1) {
		$line=~s/%jasig%/_________________________________________/;
	    } else {
		$line=~s#%jasig%# /s/#;
	    }
	} elsif ($vars{$varname}) {
	    $vv=$vars{$varname};
	    $vv=trim($vv);
	    # for 15th, we won't bold all variables - - put bold in forms, where desired
	    $line=~s/%$varname%/$vv/g;
	} else {
	    # was "UNKNOWN" - lms changed this to underscores
	    $line=~s/%$varname%/<b>___________________<\/b>/g; }
	}
    return $line;
}




#
# rpt creates a PDF file
#

sub rpt {
    my(@list,@listmain,@l,$fname,$lname,$name,$party,
       @paralist,$blockflag,$boldflag,$ulflag,$adaflag,$parastart,$paraend);

    # 612x792 points is 8.5/11
    # thus, 792x612 points is 11x8.5
    my $pdfname=tmpnam();
    my $pdf=new PDF::Create('filename'=>"/var/www/html/$pdfname.pdf",
			    'Version' =>1.2,
                            'PageMode'=>'UseNone',
                            'Author' => 'The Golem',
                            'Title' => 'Volunteer Contact Information',
                            );
    my $root=$pdf->new_page('MediaBox'=>[0,0,612,792]);
    my $page = $root->new_page;

    # Prepare 2 fonts
    my $f1 = $pdf->font('Subtype'  => 'Type1',
                        'Encoding' => 'WinAnsiEncoding',
                        'BaseFont' => 'Times-Roman');
    my $f2 = $pdf->font('Subtype'  => 'Type1',
                        'Encoding' => 'WinAnsiEncoding',
                        'BaseFont' => 'Times-Bold');

    # stringc font size x y text

    my ($i,$j);
    my $ll=0;

    my $boxtop=740;   # was 720 for 8th
    my $boxcenterx=306;
    my $boxrightx=540;
    my $boxleft=54; # (was 72)
    my $boxbottom=36;
    my $leading=15; # was 13
    my $fontsize=12; # was 14 for 8th
    my $regfont=12;  # regular font size - new for 15th
    my $adafont=14;  # ada font size - new for 15th
    my $border=8;
    my $hangmode=0;
    my $bullet;
    my $indent=30;
    my $line;
    my $indentflag=0;

    my $linenum=0;
    my @lines;

    my $email;
    my (@parties,@plaints,@defs,@resps,@petits,@decds,@aplnts,
	@aplees,@kids,@ccs);
    my (@parr,@parr2,$pp,$kk,@addr,$addr1,$addr2,$addr3,$city,$state,
		$zip,$id,$typ,$first,$middle,$last,$company,$seq,$dob,$pline,
		$addrline);

    open(INFILE,"$DPATH/$rpttype$FFEXT") ||
	die "Couldn't open $rpttype$FFEXT";

    # skip to FORM tag
    while (<INFILE>) {
	chomp;
	if (! /^FORM/) {
	    next;
	} else {
	    last;
	}
    }

    # now includes #include
    while (<INFILE>) {
	if (/\#include \"([^"]*)"/) {  # include detected
	    open(INFILE2,"$DPATH/$1") ||
		die "Couldn't open $1\n";
	    while (<INFILE2>) {
		push @listmain,$_;
	    }
	    close INFILE2;
	} else {
	    push @listmain,$_;
	}
    }
    close(INFILE);
    my ($x,$y,$ox);
    my $numcopies=(scalar @addrlist)+1;
    #
    # parseline does the first-pass processing of a line, creating appropriate line breaks
    #
    sub parseline {
	my($line)=@_;
	my($dx)=$x;  # global
	my(@words,$word,$wordsize,$font);
	$line=varsub($line,$i);
	# RATS - $i here is numcopies counter, varsub handles copy one
	# differently!

	if (!$blockflag) {
	    $parastart=$linenum;
	}
	if ($line=~/\\i/) { # INDENT / HANGING INDENT
	    $hangmode=index($line,"\\i");
	    $bullet=substr($line,0,$hangmode);
	    $line=substr($line,$hangmode+2);
	    if ($bullet ne "") {
		# 0=no line feed
		$lines[$linenum++]="$x~$bullet~0";
	    }
	    # so subsequent lines will stay indented
	    $x+=$indent;
	    $indentflag++;
	    $dx=$x;
	} elsif ($line=~/\\u/) { # un-indent
	    $x-=$indent;
	    $indentflag--;
	    $line=~s/^\\u//;
	    $dx=$x;
	} elsif ($line=~/\\l/) { # set left
	    $x=$boxleft;
	    $indentflag=0;
	    $line=~s/^\\l//;
	    $dx=$x;
	} elsif ($line=~/\\bstart/) { # block start
	    $line=~s/^\\bstart//;
	    $blockflag=1;
	}

	my $newline;
	$font=$f1;
	if ($line=~/\\bend/) { # block end
	    $line=~s/^\\bend//;
	    $blockflag=0;
	}

	@words=split /( |<b>|<\/b>|<u>|<\/u>)/,$line;
	foreach $word (@words) {
	    if ($word eq "<b>") {
		$font=$f1;
		$wordsize=0;
	    } elsif ($word eq "</b>") {
		$font=$f2;
		$wordsize=0;
	    } elsif ($word eq "<u>" or $word eq "</u>") {
		$wordsize=0;
	    } else {
		$wordsize=$page->string_width($font,"$word")*$fontsize;
	    }

	    if ($dx+$wordsize>$boxrightx-$border) {
		$lines[$linenum++]="$x~$newline~1";
		$newline="";
		$dx=$x;
	    }

	    if ($newline eq "") {
		$word=~s/^ +//;
	    }
	    $newline.="$word";
	    $dx+=$wordsize;
	}

	$lines[$linenum++]="$x~$newline~1";
	if (!$blockflag) {
	    $paraend=$linenum-1;
	    push(@paralist,"$parastart~$paraend");
	}
    }

   sub getheight {
      my($h,$i);
      for ($i=$parastart;$i<=$paraend;$i++) {
	  my($startx,$text,$lf)=split '~',$lines[$i];
          if ($lf) { $h+=$leading; }
          }
      return $h;
      }

   #
   # writeheading increments the page #, and then writes a heading on the page
   #

   sub writeheading {
      $pagenum++;
      $page->string($f1,10,$boxleft-36,$boxtop+30,$ucn);		# these were +50 for 8th
      #$page->stringc($f1,10,$boxcenterx,$boxtop+30,$formdesc);  # 15th doesn't want this
      $page->stringr($f1,10,$boxrightx+36,$boxtop+30,"Page $pagenum");
   }

   #
   # writeline writes a line on the page
   #

   sub writeline {
      my($startx,$line)=@_;
      my (@words,$word,$dx,$wordsize,$font);
      $dx=$startx;
      $font=$f1;
      if ($line=~/^\\p/) { # page break
         $page=$root->new_page;
         $y=$boxtop;
         writeheading();
      }
      elsif ($line=~/^\\c/) { # centered
         $line=~s/^\\c//;
         $page->stringc($f2,$fontsize,$boxcenterx,$y,$line);
      }
      elsif ($line=~/^\\t/) { # title - centered, bold, underlined
	     chomp($line);
         $line=~s/^\\t//;
		 $line=~s#<b>|</b>|<u>|</u>|<a>|</a>##g;
         $page->stringc($f2,$fontsize,$boxcenterx,$y,$line);
		 $page->string_underline($f2,$fontsize,$boxcenterx,$y,$line,'c');
      }
      elsif ($line=~/^\\r/) { # right-justified
         $line=~s/^\\r//;
         $line=~s#<b>|</b>##g;
         $page->stringr($f2,$fontsize,$boxrightx,$y,$line);
      }
      else {
	     if ($line=~/^\\m/) { # midpage
             $line=~s#^\\m##;
             $dx=$boxcenterx;
	     }
         @words=split /( |<b>|<\/b>|<u>|<\/u>|<a>|<\/a>)/,$line;
         foreach $word (@words) {
             if ($word eq "<b>") { $boldflag=1; }
             elsif ($word eq "</b>") { $boldflag=0; }
             elsif ($word eq "<u>") { $ulflag=1; }
             elsif ($word eq "</u>") { $ulflag=0; }
             elsif ($word eq "<a>") { $adaflag=1; }
             elsif ($word eq "</a>") { $adaflag=0; }
             else {
                if ($boldflag) { $font=$f2; } else { $font=$f1; }
				if ($adaflag) { $fontsize=$adafont; } else {$fontsize=$regfont;}
                $wordsize=$page->string_width($font,"$word")*$fontsize;
                $page->string($font,$fontsize,$dx,$y,"$word");
				if ($ulflag) {$page->string_underline($font,$fontsize,$dx,$y,"$word");}
                $dx+=$wordsize;
             }
          }
       }
   }


	#
	# 	Requires changes for Sarasota County
	#
   sub getinfo_pbc {
      #
      # get active party info
      #
      @parties=sqllist("select cdrcpty_pidm,cdrcpty_ptyp_code
                     from cdrcpty where cdrcpty_case_id='$caseid'
					 and cdrcpty_csev_seq_no is null and cdrcpty_end_date is null");
      foreach (@parties) {
		   my($id,$code)=split '~';
		   my $fullname;
		   if ($code eq "JUDG") { next; }  # skip judges
		   if ($code eq "AFFP") { next; }  # skip affiliated parties
		   my ($last,$first,$mi)=sqllistone("select spriden_last_name,spriden_first_name,spriden_mi
		                                          from spriden where spriden_pidm='$id' and spriden_change_ind is null");
		   if($code eq "ASA" or $code eq "APD") { $fullname = "$first $mi $last"; }
		   else {
				if ($first eq "") { $fullname=$last; } else { $fullname="$last, $first $mi"; }
		   }
		   # may have to add more types here.
		   # like attorneys....
           if ($code eq "PLT") { push(@plaints,"$fullname"); }
           elsif ($code eq "DFT") { push(@defs,"$fullname"); }
           elsif ($code eq "RESP") { push(@resps,"$fullname"); }
		   elsif ($code eq "PET") { push(@petits,"$fullname"); }
		   elsif ($code eq "DECD") { push(@decds,"$fullname"); }
		   elsif ($code eq "APNT") { push(@aplnts,"$fullname"); }
		   elsif ($code eq "APLE") { push(@aplees,"$fullname"); }
		   elsif ($code eq "CHLD") { push(@kids,"$fullname"); }
      }
   }

   #
   # get active judges for this case - - should only be one!
   # could combine this with sub above...
   #
   sub getactivejudge {
	  my @judge;
      my @judges=sqllist("select cdrcpty_pidm,cdrcpty_ptyp_code
                     from cdrcpty where cdrcpty_case_id='$caseid'
					 and cdrcpty_ptyp_code = 'JUDG'
					 and cdrcpty_csev_seq_no is null and cdrcpty_end_date is null");
      foreach (@judges) {
		   my($id,$code)=split '~';
		   my $fullname;
		   my ($last,$first,$mi)=sqllistone("select spriden_last_name,spriden_first_name,spriden_mi
		         from spriden where spriden_pidm='$id' and spriden_change_ind is null");
		   $fullname="$last, $first $mi";
		   push(@judge,"$fullname");
      }
	  return @judge;
   }

   #####################################
   #   MAIN BODY OF RPT
   #####################################
   getinfo_pbc();

   #
   # have to do both passes on the PDF each time as copies 2..n are different than the first.
   #
   $esfound=$espage=0;			   # esig
   $escnt=0;
   for ($i=1;$i<=$numcopies;$i++) {
	  if($i == 1 or ($pcopies eq 'on' and $i <= $maxcopies)) {
		  #
		  # first pass -- determine individual lines of text...
		  #
		  @list=@listmain;
		  @lines=@paralist=();
		  $blockflag=$boldflag=0;
		  $x=$boxleft;
		  $pagenum=1;
		  foreach $line (@list) {
			 my @firstp=();
			 my @secondp=();
			 my ($first,$second,$separator);
			 #
			 # 8th only had "parties" - we support a lot more combinations...
			 #
			 # multiple party type directives - builds vs or for sections
			 #
			 if ($line=~/^%plaintsvsdefs%/ or $line=~/^%parties%/ or $line=~/^%plaintsvsresps%/
			  or $line=~/^%petsvsresps%/ or $line=~/^%petsfordecds%/ or $line=~/^%stvsdefs%/ or $line=~/^%aplntsvsaplees%/
			  or $line=~/^%minors%/) {
				if($line=~/^%parties%/ or $line=~/^%plaintsvsdefs%/ ) {
					@firstp = @plaints;
					$first='Plaintiff';
					$separator = "vs.";
					@secondp = @defs;
					$second='Defendant';
				}
				elsif($line=~/^%plaintsvsresps%/) {
					@firstp = @plaints;
					$first='Plaintiff';
					$separator = "vs.";
					@secondp = @resps;
					$second='Respondent';
				}
				elsif($line=~/^%petsvsresps%/) {
					@firstp = @petits;
					$first='Petitioner';
					$separator = "vs.";
					@secondp = @resps;
					$second='Respondent';
				}
				elsif($line=~/^%petsfordecds%/) {
					@firstp = @petits;
					$first='Petitioner';
					$separator = "for";
					@secondp = @decds;
					$second='Decendant';
				}
				elsif($line=~/^%stvsdefs%/) {
					$firstp[0] = "STATE OF FLORIDA";
					$separator = "vs.";
					@secondp = @defs;
					$second = 'Defendant';
				}
				elsif($line=~/^%aplntsvsaplees%/) {
					@firstp = @aplnts;
					$first='Appellant';
					$separator = "vs.";
					@secondp = @aplees;
					$second='Appellee';
				}
				elsif($line=~/^%minors%/) {
					@firstp = @kids;
					$first='Minor Child';
					$separator = "";
					@secondp = ();
					$second='';
				}
				if(@firstp>1) {
				   if($line=~/^%minors%/) {$first.='ren';}
				   else {$first.='s';}
				}
				if(@secondp>1) {$second.='s';}

				$parastart=$linenum;
				if(@firstp eq 1) { $lines[$linenum++]="$boxleft~".$firstp[0]."~1"; }
				elsif(@firstp eq 2) {
				   $lines[$linenum++]="$boxleft~".$firstp[0]." AND ~1";
				   $lines[$linenum++]="$boxleft~".$firstp[1]."~1";
				}
				elsif(@firstp >5 ) { $lines[$linenum++]="$boxleft~".$firstp[0]." et al.~1"; }
				else {
				   foreach $pline (@firstp) {$lines[$linenum++]="$boxleft~$pline~1"; }
				}
				$lines[$linenum++]=($boxleft+30)."~$first~1";
				if( $line!=~/^%minors%/ ){
					# show 2nd half of block... if not minors!
					$lines[$linenum++]="$boxleft~$separator~1";
					$lines[$linenum++]="$boxleft~~1";			# req by amy borman
					if(@secondp eq 1) { $lines[$linenum++]="$boxleft~".$secondp[0]."~1"; }
					elsif(@secondp eq 2) {
					   $lines[$linenum++]="$boxleft~".$secondp[0]." AND ~1";
					   $lines[$linenum++]="$boxleft~".$secondp[1]."~1";
					}
					elsif(@secondp >5 ) { $lines[$linenum++]="$boxleft~".$secondp[0]." et al.~1"; }
					else {
					   foreach $pline (@secondp) {$lines[$linenum++]="$boxleft~$pline~1"; }
					}
					$lines[$linenum++]=($boxleft+30)."~$second~1";
				}
				$paraend=$linenum-1;
				push(@paralist,"$parastart~$paraend");
			 }
			 # parties can be done just as a block of names - - one on each line
			 elsif ($line=~/^%plaints%/ or $line=~/^%defs%/ or $line=~/^%resps%/ or $line=~/^%pets%/
			     or $line=~/^%decds%/ or $line=~/^%dcdnt%/ or $line=~/^%aplnts%/ or $line=~/^%aplees%/
				 or $line=~/^%kids%/ ) {
				if($line=~/^%plaints%/) { @firstp = @plaints; }
				elsif($line=~/^%defs%/) { @firstp = @defs; }
				elsif($line=~/^%resps%/) { @firstp = @resps; }
				elsif($line=~/^%pets%/) { @firstp = @petits; }
				elsif($line=~/^%decds%/) { @firstp = @decds; }
				elsif($line=~/^%dcdnt%/) { @firstp = @decds; }
				elsif($line=~/^%aplnts%/) { @firstp = @aplnts; }
				elsif($line=~/^%aplees%/) { @firstp = @aplees; }
				elsif($line=~/^%kids%/) { @firstp = @kids; }
				$parastart=$linenum;
				if(@firstp eq 1) { $lines[$linenum++]="$boxleft~".$firstp[0]."~1"; }
				elsif(@firstp eq 2) {
				   $lines[$linenum++]="$boxleft~".$firstp[0]." AND ~1";
				   $lines[$linenum++]="$boxleft~".$firstp[1]."~1";
				}
				elsif(@firstp >5 ) { $lines[$linenum++]="$boxleft~".$firstp[0]." et al.~1"; }
				else {
				   foreach $pline (@firstp) {$lines[$linenum++]="$boxleft~$pline~1"; }
				}
				$paraend=$linenum-1;
				push(@paralist,"$parastart~$paraend");
			 }
			 elsif ($line=~/^%esig%/) {  # electronic signature place holder
			    if($usees eq "on" and $essigexists) {
				   # user says use sig file and it does exist
				   $parastart=$linenum;
                   if($i == 1) { $lines[$linenum++]="$boxleft~%esig%~1"; }
				   else { $lines[$linenum++]="$boxleft~%estamp%~1"; }
                   $lines[$linenum++]="$boxleft~~1";
                   $lines[$linenum++]="$boxleft~~1";
                   $lines[$linenum++]="$boxleft~~1";
                   $lines[$linenum++]="$boxleft~~1";
                   $lines[$linenum++]="$boxleft~~1";
                   $lines[$linenum++]="$boxleft~~1";
                   $lines[$linenum++]="$boxleft~~1";
				   $paraend=$linenum-1;
				   push(@paralist,"$parastart~$paraend");
				}
				else {
				   # user says don't use electronic signature or sig file not found
				   $parastart=$linenum;
                   $lines[$linenum++]="$boxleft~~1";
				   $lines[$linenum++]="$boxleft~~1";
				   $lines[$linenum++]="$boxleft~~1";
				   $paraend=$linenum-1;
				   push(@paralist,"$parastart~$paraend");
				}
			 }
			 elsif ($line=~/^%cc%/) { # another special case--multi-line field
				# ideally should put addresses in double columns if there's room
				# Levy names can be long, so I had to disable that capability
				for ($pp=0;$pp<@ccaddrlist;$pp++) {
					if (!$blockflag) { $parastart=$linenum; }
					if ($pp==9) {  # too many lines!
						$paraend=$linenum-1;
						push @paralist,"$parastart~$paraend";
						$parastart=$linenum;
					}
					@parr=split '~',$ccaddrlist[$pp];
					foreach $pline (@parr) {
						$lines[$linenum++]="$boxleft~$pline~1";
					}
					#$lines[$linenum++]="$boxleft~~1";  # don't sep with blank line for 15th district
					if (!$blockflag) {
					   $paraend=$linenum-1;
					   push @paralist,"$parastart~$paraend";
					}
				}
			 }
			 elsif ($line=~/^%copylist%/) { # another special case--multi-line field
				# new for 15th circuit - to show additional copy to lines from form (not case data)
				#$parastart=$linenum;
				#for ($pp=0;$pp<@extracc;$pp++) {
				#	@parr=split '~',$extracc[$pp];
				#	foreach $pline (@parr) {
				#		$lines[$linenum++]="$boxleft~$pline~1";
				#	}
				#}
    			#$paraend=$linenum-1;
				#push(@paralist,"$parastart~$paraend");
				for ($pp=0;$pp<@extracc;$pp++) {
					if (!$blockflag) { $parastart=$linenum; }
					if ($pp==50) {  # too many lines!
						$paraend=$linenum-1;
						push @paralist,"$parastart~$paraend";
						$parastart=$linenum;
					}
					@parr=split '~',$extracc[$pp];
					foreach $pline (@parr) {
						$lines[$linenum++]="$boxleft~$pline~1";
					}
					#$lines[$linenum++]="$boxleft~~1";  # don't sep with blank line for 15th district
					if (!$blockflag) {
					   $paraend=$linenum-1;
					   push @paralist,"$parastart~$paraend";
					}
				}



			 }
			 elsif ($line=~/^%selectkids%/) { # another special case--multi-line field
				# new for 15th circuit - to show selected children is a specified format
				# no block tags allowed!
				$parastart=$linenum;
				for ($pp=0;$pp<@kidslist;$pp++) {
					@parr=split '~',$kidslist[$pp];
					foreach $pline (@parr) {
						$lines[$linenum++]="$boxleft~$pline~1";
					}
				}
				my $style = "Minor Child";
				if(@kidslist > 1) {$style.="ren";}
				if(@kidslist > 0) {$lines[$linenum++]=($boxleft+30)."~$style~1"; }
				$paraend=$linenum-1;
				push(@paralist,"$parastart~$paraend");
			 }
			 else { parseline($line); }
		  }
		  #
		  #  NOW RENDER THE PAGES
		  #
		  $x=$boxleft;
		  $y=$boxtop;
		  my ($height,$ll,$line);
		  $escnt++;
		  foreach (@paralist) {
			  ($parastart,$paraend)=split '~';
			  $height=getheight();
			  if ($y-$height<$boxbottom) {
				 $page=$root->new_page;
				 $escnt++;        # esig
				 writeheading();
				 $y=$boxtop;
			  }
			  for ($ll=$parastart;$ll<=$paraend;$ll++) {
				 $line=$lines[$ll];
				 my($startx,$text,$lf)=split '~',$line;
				 if($text=~/^%esig%/) {  # electronic signature place holder
				 	$esfound = 1;
					$espage = $escnt;
				 	$esy = $y;
					$text = '';			 # don't show tag...
				 }
				 if($text=~/^%estamp%/) {  # electronic signature stamp place holder
				 	push(@esstamps,"$escnt~$y");
					$text = '';			 # don't show tag...
				 }
				 writeline($startx,$text);
				 if ($lf) { $y-=$leading; }
			  }
		  }
		  #
		  # Printing envelopes was here...
		  # Envelopes (except for the last (file) copy)
		  #
		  if($i<$numcopies and $pcopies eq 'on'){
		 	 $root=$pdf->new_page('MediaBox'=>[0,0,612,792]);
		 	 $page = $root->new_page;
		  }
      }
   }
   #
   # Do envelopes last...
   #
	if ($penvelopes eq "on") {
		my @retAddr;
		if (defined($returnAddress)) {
			@retAddr = split(/~/, $returnAddress);
		}

		# loop through all addresses
		foreach (@addrlist) {
			$root=$pdf->new_page('MediaBox'=>[0,0,679,279]);
			$page=$root->new_page;

			# Return address (if defined)
			if (scalar(@retAddr)) {
				$x = 25;
				my $y = 250;
				foreach my $line (@retAddr) {
					chomp $line;
					$page->string($f1,$fontsize-2,$x,$y,$line);
					$y -= $leading;
				}
			}

			$x=288;
			my $y=153;
			@parr=split '~',$_;
			foreach (@parr) {
				$page->string($f1,$fontsize-2,$x,$y,"$_");
				$y-=$leading;
			}
		}
	}
   #
   # Address list page (new, for 15th)
   #
   if ($paddresses eq "on") {
   	  # write the 1st (up to) 40 addresses on a page
	  $root=$pdf->new_page('MediaBox'=>[0,0,612,792]);
	  $page = $root->new_page;
      my $ax=$boxleft;
      my $ay=$boxtop;
	  $page->string($f2,$fontsize-2,$ax,$ay,"ADDRESS LIST FOR $ucn - $formdesc:");
	  $ay-=$leading;
	  $page->string($f2,$fontsize-2,$ax,$ay,"Number of cc parties:  ".@ccaddrlist);
  	  $ay-=$leading;
	  $page->string($f2,$fontsize-2,$ax,$ay,"First (up to) 40 cc parties:");
	  $ay-=$leading;
	  my $m = @ccaddrlist;
	  if($m > 40) {$m=40;}
	  for ($pp=0;$pp<$m ;$pp++) {
		 @parr=split '~',$ccaddrlist[$pp];
		 foreach $pline (@parr) {
			$page->string($f1,$fontsize-2,$ax,$ay,"$pline");
	        $ay-=$leading;
		 }
	  }
   }
   $pdf->close;


   # -------------------------------------------------------------------
   #
   # for esignatures...and stamped copies
   # put the esignature in the correct place!
   #
   if($esfound and $essigexists){
      $pdf2 = PDF::API2->open("/var/www/html/$pdfname.pdf");
      $page2 = $pdf2->openpage($espage);
	  drawimage($essigfn,1,$esy);
      # do stamped copies
	  if(@esstamps > 0 and $esstampexists) {
		  foreach (@esstamps) {
			  my($p,$y)=split '~';
			  $page2 = $pdf2->openpage($p);
			  drawimage($esstampfn,1,$y);
		  }
	  }
	  $pdf2->update();
   }

   my $cookie1=$info->cookie(-name=>"ICMS_EDATE",
                             -value=>$vars{"edateraw"},
                             -path=>"/",
			    -domain=>".15thcircuit.com");
   my ($hours,$min)=text_to_time($vars{"etime"});
   if (($test ne "on") and not ($FLAGS=~/ALLOWSAMETIME/)) {
      ($hours,$min)=add_time($hours,$min,$vars{"interval"});
   }
   my $etime2=time_to_text($hours,$min);
   my $cookie2=$info->cookie(-name=>"ICMS_ETIME",
                             -value=>$etime2,
                             -path=>"/",
			    -domain=>".15thcircuit.com");
   my $cookie3=$info->cookie(-name=>"ICMS_ELOC",
                             -value=>$vars{"eloc"},
                             -path=>"/",
			    -domain=>".15thcircuit.com");
   my $cookie4=$info->cookie(-name=>"ICMS_MDATE",
                             -value=>$vars{"mdateraw"},
                             -path=>"/",
			    -domain=>".15thcircuit.com");
   my $cookie5=$info->cookie(-name=>"ICMS_EADDR",
                             -value=>$vars{"eaddr"},
                             -path=>"/",
			    -domain=>".15thcircuit.com");
   print $info->redirect(-uri=>"$pdfname.pdf",-cookie=>[$cookie1,$cookie2,$cookie3,$cookie4,$cookie5]);
   return "$pdfname.pdf";
}


sub getjudgeinfo_pbc {
	# get the judge name and div from parties list - find the active judge for this case
	my $caseid = shift;
	my $dbh = shift;

	my $query = qq {
		select
			cdrcpty_pidm as "PIDM",
			cdrcpty_ptyp_code as
		from
			cdrcpty
		where
			cdrcpty_case_id='$caseid'
			and cdrcpty_ptyp_code = 'JUDG'
			and cdrcpty_csev_seq_no is null
			and cdrcpty_end_date is null
	};
	my @judges;
	sqlHashArray($query,$dbh,\@judges);

	my $name;
	#my ($name,$lastname,$first,$mi,$div);
	foreach my $judge (@judges) {
		my($id,$code)=split '~';
		my $adesc;
		my $query = qq {
			select
				spriden_id as "DivisionID",
				spriden_last_name as "LastName",
				spriden_first_name as "FirstName",
				spriden_mi as "MiddleName"
			from
				spriden
			where
				spriden_pidm='$judge->{PIDM}'
				and spriden_change_ind is null
		};

		my $judgerec = sqlHashOne($query,$dbh);

		$judgerec->{'FirstName'} =~ s/JUDGE\s?//;

		$vars{division}=$judgerec->{'DivisionID'};
		$judgerec->{LastName} =~ s/\s$//g;
		$vars{ja}=$jas{$judgerec->{LastName}};
		$vars{interval}=$interval{$judgerec->{LastName}};
		# Now look to see if the judge has a suffix (Jr., III, etc.) and tack it onto the last name.
		# It's stupid that this is a different table.
		$query = qq {
			select
				spbpers_name_suffix as "Suffix"
			from
				spbpers
			where
				spbpers_pidm='$judge->{PIDM}'
		};
		my $pidm = sqlHashOne($query,$dbh);
		#print "Content-type: text/html\n\n";
		#print "<pre>$query\n\n</pre>";
		#dumpVar($pidm);
		if ($pidm->{'Suffix'} ne "") {
			$judgerec->{'LastName'} .= ", $pidm->{'Suffix'}";
		}

		if ($judgerec->{'MiddleName'} ne '') {
			$name = "$judgerec->{'FirstName'} $judgerec->{'MiddleName'}. $judgerec->{'LastName'}";
		} else {
			$name = "$judgerec->{'FirstName'} $judgerec->{'LastName'}";
		}

		$vars{judge}=$name;
	}
}


sub myprettydate {
    my($date)=@_;
    if ($date eq "") { return ""; }
    my($month,$day,$year)=split '/',$date;
    if ($year<2000) { $year+=2000; }
    my $x=Date_to_Text_Long($year,$month,$day);
    $x=~s/ $year/, $year/;
    return $x;
   }



sub prettycheck {
    my($v)=@_;
print "checking $v - length is ".length($v)."<br/>";
    if ($v eq "X") { return "X"; }
    else { return " "; }
}

#
#  main program starts here
#

#my $info=new CGI;

my(%forms,@fields,%fieldtypes);

open INFILE,"$DPATH/orders.conf" or die "Unable to open file '$DPATH/orders.conf': $!";
#
# ORDERS Section
#
while (<INFILE>) {
   chomp;
   if (/^#/) { next; }
   if (/^ORDERS/) { next; }
   if (/^FIELDS/) { last; }
   my($title,$formfile,$div,$vars,$county,$evtypex,$flags)=split '~';
   $forms{$formfile}="$title~$div~$vars~$county~$evtypex~$flags";
   }
#
# FIELDS Section
#
while (<INFILE>) {
   chomp;
   if (/^#/) { next; }
   if (/^JAS/) { last; } # skip JA section--not relevent here
   my($fieldname,$fielddesc,$cookie,$type,$length,$comment)=split '~';
   push @fields,"$fieldname~$fielddesc~$cookie~$type~$length~$comment";
   $fieldtypes{$fieldname}=$type;
   }
#
# JAS section
#
while (<INFILE>) {
   chomp;
   if (/^#/) { next; }
   my($judge,$janame,$interval)=split '~';
   $jas{$judge}=$janame;
   $interval{$judge}=$interval;
   }
close(INFILE);


#
# Read this form's form file, first, then the orders.conf file.
#
$rpttype=$info->param("rpttype");
# new - read this form's .form file
open INFILE,"$DPATH/$rpttype$FFEXT" or die "Nope";
while (<INFILE>) {
   chomp;
   if (/^#/) { next; }
   if (/^ORDER/) { next; }
   if (/^FIELDS/) { last; }
   my($title,$formfile,$div,$vars,$county,$evtype,$ttype)=split '~';
   $forms{$formfile}="$title~$div~$vars~$county~$evtype~$ttype";
   #$thisform=$formfile;
}
# when a form is selected, get its forms fields.
#if($rpttype eq $thisform){
	while (<INFILE>) {
	   chomp;
	   if (/^#/) { next; }
	   if (/^FORM/) { last; }
	   my($fieldname,$fielddesc,$cookie,$type,$length,$comment)=split '~';
	   push @fields,"$fieldname~$fielddesc~$cookie~$type~$length~$comment";
	   $fieldtypes{$fieldname}=$type;
	}
#}
close(INFILE);

my $edate=$info->param("edate");
my $etime=$info->param("etime");
my $eloc=$info->param("eloc");
my $eaddr=$info->param("eaddr");
my $mdate=$info->param("mdate");
my $trialdate=$info->param("trialdate");
my $trialtime=$info->param("trialtime");
my $trialdur=$info->param("trialdur");
my $evtype=$info->param("evtype");
my $ttype=$info->param("ttype");
my $dbname=$info->param("dbname");
$maxcopies=$info->param("maxcopies");
$dbtype=$info->param("dbtype");

$ucn=$info->param("ucn");
$test=$info->param("test");
$formdesc=$info->param("formdesc");

$caseid=$info->param("caseid");
$numparties=$info->param("numparties"); # starting val
$numextracc=$info->param("numextracc"); # extra cc entries
$numkids=$info->param("numkids"); # might have kids' list for ufc
$pcopies = $info->param("pcopies");
$penvelopes = $info->param("penvelopes");
$paddresses = $info->param("paddresses");
$usees = $info->param("usees");  # use electronic signature

#
# set up vars{} array
#

$FLAGS=(split '~',$forms{$rpttype})[5];  # set global FLAGS variable

#print $info->header();
#print "<br/>";
# dump the field list
#foreach (@fields) {
#   my($fieldname,$fielddesc,$cookie,$type,$length,$comment)=split '~';
#   print "fieldname: $fieldname,  type: $type <br/>";
#}
#print "FLAGS are/is: $FLAGS <br/>";

my $fvars=(split '~',$forms{$rpttype})[2];
#print "fvars is : $fvars <br/>";
my @fvarlist = split ',',$fvars;
my @formfields = ();
my $fnd = 0;
# for each variable in the form
foreach my $var (@fvarlist) {
   my $val=$info->param($var);
   my $type=$fieldtypes{$var};
   # print "doing form var: $var, val: $val, type: $type (length of val is: ".length($val)." and length of type is ".length($type).")<br/>";
   if ($type=~/DATE/) { $vars{$var}=myprettydate($val); }
   elsif ($type=~/CHECKBOX/) { $vars{$var}=prettycheck($val); }
   #elsif ($type=~/DROPDOWN/) {
   #		print $info->header();
   #		print "doing dropdown - val is $val and length of val is ".length($val)."<br/>";
   #		exit;
   #}
   else { $vars{$var}=$val; }
}

#my ($key,$value);
#print "showing vars hash after first loop...<br/>";
#while (($key, $value) = each %vars)
#{
#  print "$key has the value $vars{$key} (length of val is: ".length($vars{$key}).") <br/>";
#}
#exit;

my $month;
my $age;
my $counties;
my ($division,$judge,$error,$ja);

#
#
# some processing of the input variables
#
#$SQLPROFILE=1; # debug info...
dbconnect("icms");
$edate=myfixdate($edate);
$etime=check_time($etime,$edate,$eloc,$eaddr);
# check time range for sanity? (nothing before 8am or after 6pm?)
# check date, validity, holiday
# check room (loc)
# check address of courthouse (eaddr)
# check # of checked addresses (must be >0)
dbdisconnect();
if (@errlist>0) {
    print $info->header();
    print "<h2>Error:</h2>";
    foreach $error (@errlist) {
	   print "<h3>$error</h3>";
    }
    print "Please hit the Back button and try again!";
    exit;
}
$vars{"casenum"}=$ucn;
$vars{"today"}=sprintf("%s day of %s, %s",English_Ordinal($DAY),Month_to_Text($MONTH),$YEAR);
$vars{"thismonth"}=sprintf("%s",Month_to_Text($MONTH));
$vars{"thisyear"}=sprintf("%s",$YEAR);
$vars{"edateraw"}=$edate;
$vars{"mdateraw"}=$mdate;
if ($vars{"reason"} eq "") { $vars{"reason"}=" "; }
if ($vars{"matter"} eq "") { $vars{"matter"}=" "; }


my $dbh = dbconnect($dbname);

# don't really have to do both here...
getjudgeinfo_pbc($caseid,$dbh);
#---my @judge = getactivejudge();

my($h,$m)=text_to_time($etime);
if ($test ne "on") {
   ($h,$m)=add_time($h,$m,$vars{'interval'}-1);
}
my $eend=time_to_text($h,$m);

# might have children list...
buildkids();

# don't have addresses yet...
buildaddrlist();
buildextracc();

my $pdfname = rpt();

dbdisconnect();
#
# put hearing & log events in the ICMS events table...
#
dbconnect("icms");
addlogentry($ucn,$rpttype,$test,(substr $pdfname,5));
if ($test ne "on") {
   if ($edate ne "") {
      addevent($ucn,$evtype,$edate,$etime,$eend,$eloc,$eaddr);
      }
   if ($trialdate ne "") {
       addevent($ucn,$ttype,$trialdate,$trialtime,$trialtime,"","");
      }
   dbdisconnect();

   # bugbug   not sure about this
   #if ($evtype eq "CMC") {  # turn off schedule cmc flag if CMC scheduled
   #   dbconnect("casenotes");
   #   ask("delete from flags where flagtype=12 and casenum='$ucn'");
   #   dbdisconnect();
   #   }
}
