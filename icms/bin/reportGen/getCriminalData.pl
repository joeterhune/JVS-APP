#!/usr/bin/perl -w

BEGIN {
    use lib "$ENV{'PERL5LIB'}";
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
use POSIX qw (
    strftime
);

my $month;
my $type = "crim";

GetOptions ("m=s" => \$month);

if (!defined($month)) {
    $month = strftime('%Y-%m', localtime(time));
}

my $dbh = dbConnect("judge-divs");
my $query = qq {
    select
        division_id as DivisionID,
        division_type as DivisionType
    from
        divisions
    where
        ((division_type like '%felony%') or (division_type like '%misdemeanor%') or (division_type like '%traffic%'))
        and show_icms_list = 1
};

my %divlist;
getData(\%divlist, $query, $dbh, {hashkey => "DivisionID", flatten => 1});

my @divs = keys (%divlist);

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

foreach my $div (sort @divs) {
    my $dir = sprintf("%s/%s/div%s/%s", $reportTopDir,$type,$div,$month);
    if (!-e $dir) {
        print "Skipping '$dir': no such directory\n";
        next;
    }
    
    my $isFelony;
    
    if ($divlist{$div}->{'DivisionType'} =~ /Felony/) {
        $isFelony = 1;
        print "$div\tFELONY\n";
    } elsif ($divlist{$div}->{'DivisionType'} =~ /Misdemeanor/) {
        $isFelony = 0;
    } else {
        next;
    }
    
    my @newRptHeader;
    
    foreach my $reportType (@reportTypes) {
        my $file = sprintf("%s/%s", $dir, $reportType->{'file'});
        if (!-f $file) {
            print "Skipping '$file': no such file.\n";
            next;
        }
        # Ok, now read in the file and count the number of cases for each age group
        @newRptHeader = ();
        
        open (INFILE, $file);
        while (my $line = <INFILE>) {
            push(@newRptHeader,$line);
            if ($line =~ /^FIELDTYPES/) {
                last;
            }
        };
        
        # Ok, we should be at the first case.
        my %reportData;
        my $rptMonth = $month;
        
        my $rptType = $reportType->{'rptType'};
        my @rpts;
        
        if ($isFelony) {
            my $temp = {
                'type' => "$rptType" . "_0-120",
                'file' => "$rptType" . "_0-120.txt",
                'caselist' => [],
                'TitleAppend' => '0-120 Days'
            };
            
            push(@rpts,$temp);
            $temp = {
                'type' => "$rptType" . "_121-180",
                'file' => "$rptType" . "_121-180.txt",
                'caselist' => [],
                'TitleAppend' => '121-180 Days'
            };
            push(@rpts,$temp);
            $temp = {
                'type' => "$rptType" . "_181",
                'file' => "$rptType" . "_181.txt",
                'caselist' => [],
                'TitleAppend' => '181+ Days'
            };
            push(@rpts,$temp);
            
            $reportData{'data'} =  [
                {'label' => '0 - 120 Days', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$rpts[0]->{'type'}')"},
                {'label' => '121 - 180 Days', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$rpts[1]->{'type'}')"},
                {'label' => '181+ Days', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$rpts[2]->{'type'}')"}
            ];
            
            while (my $line = <INFILE>) {
                my @pieces = split("~", $line);
                my $age = $pieces[6];
                if ($age > 180) {
                    $reportData{'data'}[2]->{'value'}++;
                    push(@{$rpts[2]->{'caselist'}}, $line);
                } elsif ($age > 120) {
                    $reportData{'data'}[1]->{'value'}++;
                    push(@{$rpts[1]->{'caselist'}}, $line);
                } else {
                    $reportData{'data'}[0]->{'value'}++;
                    push(@{$rpts[0]->{'caselist'}}, $line);
                }
            }
            close INFILE;
        } else {
            my $temp = {
                'type' => "$rptType" . "_0-60",
                'file' => "$rptType" . "_0-60.txt",
                'caselist' => [],
                'TitleAppend' => '0-60 Days'
            };
            
            push(@rpts,$temp);
            $temp = {
                'type' => "$rptType" . "_61-90",
                'file' => "$rptType" . "_61-90.txt",
                'caselist' => [],
                'TitleAppend' => '61-90 Days'
            };
            push(@rpts,$temp);
            $temp = {
                'type' => "$rptType" . "_91",
                'file' => "$rptType" . "_91.txt",
                'caselist' => [],
                'TitleAppend' => '91+ Days'
            };
            push(@rpts,$temp);
            
            $reportData{'data'} =  [
                {'label' => '0 - 60 Days', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$rpts[0]->{'type'}')"},
                {'label' => '61 - 90 Days', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$rpts[1]->{'type'}')"},
                {'label' => '91+ Days', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$rpts[2]->{'type'}')"}
            ];
            
            while (my $line = <INFILE>) {
                my @pieces = split("~", $line);
                my $age = $pieces[6];
                if ($age > 90) {
                    $reportData{'data'}[2]->{'value'}++;
                    push(@{$rpts[2]->{'caselist'}}, $line);
                } elsif ($age > 60) {
                    $reportData{'data'}[1]->{'value'}++;
                    push(@{$rpts[1]->{'caselist'}}, $line);
                } else {
                    $reportData{'data'}[0]->{'value'}++;
                    push(@{$rpts[0]->{'caselist'}}, $line);
                }
            }
            close INFILE;
        }

        foreach my $rpt (@rpts) {
            my $outFile = sprintf("%s/%s", $dir, $rpt->{'file'});
            open(OUTFILE, ">$outFile") ||
                die "Unable to create '$outFile': \n\n";
            foreach my $line (@newRptHeader) {
                chomp $line;
                my $newline = $line;
                if ($newline =~ /^TITLE2/) {
                    $newline .= " - $rpt->{'TitleAppend'}";
                }
                print OUTFILE "$newline\n";
            }
            print OUTFILE (@{$rpt->{'caselist'}});
            print "Created '$outFile'\n";
        }
        
        my $type = $file;
        $type =~ s/\.txt//g;
        my $outJson = sprintf("%s.json", $type);
        writeJsonFile($reportData{'data'}, $outJson);
        print "Wrote '$outJson'\n\n";
    }
}
