#!/usr/bin/perl 

#
# createPDF.cgi -- script to generate convert the file to PDF
#
# 08/24/10 lms Remove <br/> or <br> from lines.
# 10/20/10 lms Remove &nbsp; from lines.

use CGI;
use Date::Calc qw(:all);
use PDF::Create;
use POSIX;

my $info=new CGI;
my $fpath=$info->param("path");
my $header=$info->param("header");
my $order=$info->param("order");

#print $info->header();
#print $info->start_html("");

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
	@j=split '~';
	
        for ($i=0;$i<@j;$i++) {
	    #print "the text is $j[$i]<br>";
	    if($j[$i]=~/<a href=([^>]+)>([^<]+)/) {
		$link=$1;
		$j[$i]=$2;
	#	print "the text is $j[$i]<br>";
	    }
           $k=getwidth($font,$size,$j[$i],$page);
	   if ($width[$i]<$k) { $width[$i]=$k; }
	#   print "The width found is $width[$i]<br><br>";
	}
    }
    return @width;
 }


print $info->header("application/pdf"); 
my $pdf = new PDF::Create('filename' => '/var/tmp/test.pdf',
                              'Version'  => 1.2,
                              'PageMode' => 'UseOutlines',
                              'Author'   => 'CPC',
                              'Title'    => 'List',
			      );
my $root = $pdf->new_page('MediaBox' => [ 0, 0, 792, 612 ]);
# Add a page which inherits its attributes from $root
my $page = $root->new_page;

# Prepare 2 fonts
my $f1 = $pdf->font('Subtype'  => 'Type1',
                        'Encoding' => 'WinAnsiEncoding',
                        'BaseFont' => 'Helvetica');
my $f2 = $pdf->font('Subtype'  => 'Type1',
                        'Encoding' => 'WinAnsiEncoding',
                        'BaseFont' => 'Helvetica-Bold');
$x=$y=0;
my $boxtop=540;
my $boxleft=36;
my $boxbottom=36;
my $boxright=25;
my $leading=13;
my $fontsize=10;
my $border=8;

open(INFILE,$fpath) or die "Nope. $fpath";
$sep=';';
if ($header) {  # genlist2 style text files 
    while (<INFILE>) {
        chomp;
        if (/TITLE1=(.*)/) {
	      $t1=$1;
              $page->stringl($f2,12,36,590,$1);
           }
        elsif (/TITLE2=(.*)/) { 
	      $t2=$1;
	      $page->stringl($f2,12,36,575,$1);
           }
        elsif (/DATE=(.*)/) { 
	      $dt=$1;
	      $page->stringl($f2,12,36,560,$1);
	  }
        elsif (/VIEWER=/) { last; }
    }
    
    $collist=<INFILE>;
    chomp($collist);
    $collist=~s/FIELDNAMES=//;
	if ($collist=~/~/) { $sep='~'; }
	else { $sep=';'; }
    @collist=$collist;
    <INFILE>; # chew up types line
}

$j=$boxtop;
foreach (<INFILE>) {
    chomp;
	$_ =~ s/;scview.cgi//g;
    push(@list,$_);
}  
@list=sort(@list);
unshift(@list,@collist);

@width=getmaxwidths($f1,$fontsize,\@list,$page);
$tot=0;
$maxtablewidth=791-($border*scalar(@width-1))-$boxleft-$boxright;

foreach(@width) {
   $perct = $_/$maxtablewidth*100;
   if($perct>=25){
       $_=(0.25*$maxtablewidth);
       $perct=25;
   }
}

foreach(@width) {
    $tot+=$_;
    if($tot>$maxtablewidth) {  
	$_-=($tot-$maxtablewidth);
    }
}

sub splitandfit {
    my($line,$width,$offset)=@_;
    $realoffset=$offset;
    $woffset=0;
    @word=split ' ',$line;
    $jflag=0;
    for($a=0;$a<@word;$a++) {
	$word[$a]=$word[$a].' ';
	$wlen=getwidth($f1,$fontsize,$word[$a],$page);
	$woffset+=$wlen;
        if($woffset>=($width-$border)) {
	    #if($jflag) {
		    $j-=$leading;
	#	}
		    $realoffset=$offset;
		    $page->stringl($f1,$fontsize, $realoffset, $j,$word[$a]);
	    #if(!$jflag) {
		#   $j-=$leading;
	   # }
		    $realoffset+=$wlen;
		    $flag2=1;
		    $woffset=$wlen;
	} else {
	         #$jflag=1;
	         $page->stringl($f1,$fontsize, $realoffset, $j,$word[$a]);
		 $realoffset+=$wlen;
        }
    }#word for ends
}

for($k=0;$k<@list;$k++) {
    @line=split $sep,$list[$k];
    $offset=$boxleft;
    $top=$j;
    @jarray=();
    for($i=0;$i<@width;$i++) {
	$ln=getwidth($f1,$fontsize,$line[$i],$page);
	$line[$i]=~s/&nbsp;/ /g;	    	
    if($line[$i]=~/<a href=([^>]+)>([^<]+)/ || $line[$i]=~/<font color=([^>]+)>([^<]+)/ ) {
	     $link=$1;
		 $line[$i]=~s/<a href=\w+>//g;
		 $line[$i]=~s/<\/A>//g;
		 $line[$i]=~s/<font color=\w+>//g;
		 $line[$i]=~s/<\/font>//g;
		 $line[$i]=~s/&radic;//g;
		 $line[$i]=$2.$line[$i];
        }
	if($line[$i]=~/\(/ || $line[$i]=~/\)/) {
	    $line[$i]=~s/\(//;
	     $line[$i]=~s/\)//;
	}
	if($line[$i]=~/&#59/ || $line[$i]=~/;/) {
	    $line[$i]=~s/;/,/;
        $line[$i]=~s/&#59/,/;
	}
	if($line[$i]=~/<br\/>/  || $line[$i]=~/<br>/) {
	    $line[$i]=~s/<br\/>/ /g;
	    $line[$i]=~s/<br>/ /g;		
	}
	if($ln>$width[$i]) {
	   $j=$top;
	   splitandfit($line[$i],$width[$i],$offset);
	   $offset+=$width[$i]+$border;  
	   push(@jarray,$j);
	}
	elsif($k==0) {
	       $page->stringl($f2,$fontsize, $offset, $j,$line[$i]);
	       $offset+=$width[$i]+$border;
	       push(@jarray,$j);
	    
	} else {
	       $page->stringl($f1,$fontsize, $offset, $top,$line[$i]);
	       $offset+=$width[$i]+$border;
	       push(@jarray,$top);
	}   
    }# for loop of width ends
	$j=$jarray[0];
    for($s=0;$s<@jarray;$s++) {
	if($j>$jarray[$s]) {
	   $j=$jarray[$s];
       }
   }   
   if($k==0 || $k!=scalar @list-1) {
	  $page->line($boxleft-$border/2,$top+$leading-3,$offset-$border/2,$top+$leading-3);
    }

    $j-=$leading;
    $page->line($boxleft-$border/2,$j+$leading-3,$offset-$border/2,$j+$leading-3);
    if ($j<=($boxbottom+$leading) || $k==scalar @list-1) { 
          $page->line($boxleft-$border/2,$j+$leading-3,$offset-$border/2,$j+$leading-3);
          $page->line($offset-$border/2,$boxtop+$leading-3,$offset-$border/2,$j+$leading-3);
          $offset=$boxleft-$border/2;
          for ($i=0;$i<@width;$i++) {
             # vertical lines	      
	      $page->line($offset,$boxtop+$leading-3,$offset,$j+$leading-3);
	      $offset+=$width[$i]+$border;
          } 
          if ($k!=scalar @list-1) {
	      $page=$root->new_page; 
	      $page->stringl($f2,12,36,590,$t1);
	      $page->stringl($f2,12,36,575,$t2);
	      $page->stringl($f2,12,36,560,$dt);
	      $j=$boxtop; 
	      @line=split $sep,$list[$0];
	      $offset=$boxleft;
	       for($i=0;$i<@width;$i++) {
		   $page->stringl($f2,$fontsize, $offset, $j,$line[$i]);
		   $offset+=$width[$i]+$border;
	       }
	       $page->line($boxleft-$border/2,$j+$leading-3,$offset-$border/2,$j+$leading-3);
	       $j-=$leading;
	 }
    }
}
$pdf->close;

open(INFILE,"/var/tmp/test.pdf");
while (<INFILE>) { print; }
close(INFILE);





