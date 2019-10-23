#!/usr/bin/perl 

#
# export.cgi exporting text case list files as xls documents
#
# 09/09/09 added link support for type L fields
# 10/12/10 lms Remove &nbsp; and .jpg from fields
# 04/07/11 lms Change &Dagger; to "F:" to indicate flag

BEGIN {
    use lib "$ENV{'JVS_PERL5LIB'}";
}

use Spreadsheet::WriteExcel;
use Date::Calc qw(:all);
use CGI;
use POSIX;

my $info = new CGI;

print $info->header;

my $fpath = $info->param("rpath");
my $header = $info->param("header");

# Special fix for _96+ files...
$fpath =~ s/ro_96 /ro_96+/g;
$fpath =~ s/pend_96 /pend_96+/g;

my $oname = tmpnam();

my $workbook=Spreadsheet::WriteExcel->new("/var/www/html$oname.xls");

my $worksheet=$workbook->addworksheet();

my $format1=$workbook->addformat();
$format1->set_num_format('mm/dd/yy');

my $format2=$workbook->addformat();
$format2->set_bold();

my $formath1=$workbook->addformat();
$formath1->set_bold();
$formath1->set_size(14);

my $formath2=$workbook->addformat();
$formath2->set_bold();
$formath2->set_size(12);

my $formath3=$workbook->addformat();
$formath3->set_bold();
$formath3->set_size(11);

$row=$col=0;

$fpath = sprintf("/var/www/html%s", $fpath);

open(INFILE,$fpath) ||
    die "Unable to open file '$fpath' for reading: $!\n\n";
$sep=';';

my $viewer = "bannerview.cgi";

if ($header) {  # genlist2 style text files 
    while (my $line = <INFILE>) {
        chomp $line;
        if ($line =~ /TITLE1=(.*)/) {
			$worksheet->set_row($row,18);
			$worksheet->write(0,0,$1,$formath1);
		} elsif ($line =~ /TITLE2=(.*)/) {
			$worksheet->set_row($row,16);
			$worksheet->write(1,0,$1,$formath2);
		} elsif ($line =~ /DATE=(.*)/) {
			$worksheet->set_row($row,14);
			$worksheet->write(2,0,$1,$formath3);
		} elsif ($line =~ /VIEWER=/) {
			my $foo;
			($foo,$viewer) = split(/=/,$line,2);
			last;
		}
    }
	
	$row=4; # skip a line
    $collist=<INFILE>;
    chomp($collist);
    $collist=~s/FIELDNAMES=//;
    if ($collist=~/~/) { $sep='~'; }
    else { $sep=';'; }
    @collist=split $sep,$collist;
    foreach (@collist) {
		if (not defined $max{$col} or ($max{$col}<length($_))) {
			$max{$col}=length($_);
		}
        $worksheet->write($row,$col++,$_,$format2);
    }
	
	$typeline=<INFILE>; # read the FIELDTYPES line
	$typeline=~s/^FIELDTYPES=//; # remove the prefix
	@types=split '~',$typeline; # deprecated, schmeprecated...
	$row++;
}

foreach (<INFILE>) {
    chomp;
    @list=split $sep;
    $col=0;
    foreach (@list) {
	    # remove &nbsp;'s from field.   
		if($_=~/&nbsp;/) {
			$_=~s/&nbsp;/ /g;
		}	
		if($_=~/&Dagger;/) {
			$_=~s/&Dagger;/F:/g;
		}			
		if($_=~/.jpg/) {
			$_=' ';
		}
        
		# if field's a link, bust it out and redefine $_ to description
        # (for accurate size determination)
        if (/<a href=([^>]+)>([^<]+)/) {
			$link=$1;
			$_=$2;
		} elsif ($types[$col] eq "L") {
			$protocol = "http";
			if (defined $ENV{'HTTPS'}) {
				$protocol = "https"
			}
			if ($_ !~ /scview.cgi/) {
				$link="$protocol://$ENV{'HTTP_HOST'}/cgi-bin/search.cgi?name=$_";
			} else {
				my $ucn = (split(/;/, $_))[0];
				$link="$protocol://$ENV{'HTTP_HOST'}/cgi-bin/search.cgi?name=$ucn";
			}
		} else {
			$link="";
		}
        
		if (not defined $max{$col} or ($max{$col}<length($_))) { 
           $max{$col}=length($_); 
	    }
        if ($_=~m#^\d+/\d+/\d+$#) { # a date
	    	($yc,$mc,$dc)=Decode_Date_US($_);
            if ($yc>0) {
				$x=Delta_Days(1899,12,30,$yc,$mc,$dc);
				# excel counts 1/1/1900 as day 1,
				# but since excel thinks there's a 2/29/00,
				# I'm starting two days earlier to make things add up
				$worksheet->write($row,$col++,$x,$format1); 
	   		}
		} elsif ($link ne "") {
			$display = (split(/;/,$_))[0];
			$worksheet->write_url($row,$col++,$link,$display);
		} else {
			$_=~s/<[^<]*>//g; # remove any other tags...
			$worksheet->write($row,$col++,$_);
		}
    }
    $row++;
}

#
# set approximate column widths for data
#
foreach (keys %max) {
    $worksheet->set_column($_,$_,$max{$_}+1);
}    
$workbook->close();
print $info->redirect("$oname.xls");
exit;
