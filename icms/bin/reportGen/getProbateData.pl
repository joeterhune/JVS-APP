#!/usr/bin/perl -w

BEGIN {
    use lib "/usr/local/icms/bin";
}

use strict;

use Getopt::Long;

use Common qw (
    dumpVar
    writeJsonFile
    $reportTopDir
);
use DB_Functions qw (
    dbConnect
    getData
);
use POSIX qw(
    strftime
);

my $month;
my $type = "pro";

GetOptions ("m=s" => \$month);

if (!defined($month)) {
    $month = strftime('%Y-%m', localtime(time));
}

my $dbh = dbConnect("judge-divs");
my $query = qq {
    select
        division_id
    from
        divisions
    where
        division_type like '%probate%'
        and show_icms_list = 1
};
my @divlist;
my @divs;
getData(\@divlist, $query, $dbh);
foreach my $div (@divlist) {
    push(@divs, $div->{'division_id'});
}

my @reportTypes = (
    {
        'file' => 'pend.txt',
        'caption' => 'Pending Cases - Division ',
        'rptType' => 'pend'
    },
    {
        'file' => 'ro.txt',
        'caption' => 'Reopened Cases - Division ',
        'rptType' => 'ro'
    }
);

foreach my $div (@divs) {
    my $dir = sprintf("%s/%s/div%s/%s", $reportTopDir,$type,$div,$month);
    if (!-e $dir) {
        print "Skipping '$dir': no such directory\n";
        next;
    }
    
    foreach my $reportType (@reportTypes) {
        my $file = sprintf("%s/%s", $dir, $reportType->{'file'});
        if (!-f $file) {
            print "Skipping '$file': no such file.\n";
            next;
        }
        # Ok, now read in the file and count the number of cases for each age group
        open (INFILE, $file);
        while (my $line = <INFILE>) {
            if ($line =~ /^FIELDTYPES/) {
                last;
            }
        };
        # Ok, we should be at the first case.
        my %reportData;
        my $rptMonth = $month;
        
        my $rptType = $reportType->{'rptType'};
        
        $reportData{'data'} =  [
            {'label' => '0 - 120 Days', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$rptType',0)"},
            {'label' => '121 - 180 Days', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$rptType',1)"},
            {'label' => '180+ Days', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$rptType',2)"}
        ];
        
        
        while (my $line = <INFILE>) {
            my @pieces = split("~", $line);
            my $age = $pieces[4];
            if ($age > 180) {
                $reportData{'data'}[2]->{'value'}++;
            } elsif ($age > 120) {
                $reportData{'data'}[1]->{'value'}++;
            } else {
                $reportData{'data'}[0]->{'value'}++;
            }
        }
        close INFILE;
        
        my $type = $file;
        $type =~ s/\.txt//g;
        my $outJson = sprintf("%s.json", $type);
        writeJsonFile($reportData{'data'}, $outJson);
        print "Wrote '$outJson'\n\n";
    }
}