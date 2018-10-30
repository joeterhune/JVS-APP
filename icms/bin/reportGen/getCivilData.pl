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
    today
    US_date
);
use DB_Functions qw (
    dbConnect
    getData
);
use POSIX qw (
    strftime
);
use Date::Calc qw (Delta_Days);

my $month;
my $type = "civ";

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
        ((division_type like '%civil%') or (division_type like '%foreclosure%'))
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


my ($tm, $td, $ty) = split("/", today());

foreach my $div (sort @divs) {
    my $dir = sprintf("%s/%s/div%s/%s", $reportTopDir,$type,$div,$month);
    if (!-e $dir) {
        print "Skipping '$dir': no such directory\n";
        next;
    }
    
    my $isCircuit;
    
    if ($divlist{$div}->{'DivisionType'} =~ /Circuit|Foreclosure/) {
        $isCircuit = 1;
    } elsif ($divlist{$div}->{'DivisionType'} =~ /County/) {
        $isCircuit = 0;
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
        
        if ($isCircuit) {
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
            $temp = {
                'type' => "$rptType" . "_noAct",
                'file' => "$rptType" . "_noAct.txt",
                'caselist' => [],
                'TitleAppend' => 'No Activity for 300 Days'
            };
            push(@rpts,$temp);
            
            $reportData{'data'} =  [
                {'label' => '0 - 120 Days', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$rpts[0]->{'type'}')"},
                {'label' => '121 - 180 Days', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$rpts[1]->{'type'}')"},
                {'label' => '181+ Days', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$rpts[2]->{'type'}')"},
                {'label' => 'No Activity 300 Days', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$rpts[3]->{'type'}')"}
            ];
            
            while (my $line = <INFILE>) {
                my @pieces = split("~", $line);
                my $age = $pieces[4];
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
                
                # How long since the last activity?
                my ($lm, $ld, $ly) = split("/",US_date($pieces[7]));
                my $days = Delta_Days($ly, $lm, $ld, $ty, $tm, $td);
                if ($days > 300) {
                    $reportData{'data'}[3]->{'value'}++;
                    push(@{$rpts[3]->{'caselist'}}, $line);
                }
            }
            close INFILE;
            
            # Now get the pending cases with motions but no hearings
            my $mnh = sprintf("%s_motNoEvent", $rptType);
            my $mnhFile = sprintf("%s/%s.txt", $dir, $mnh);
            
            my $mnhRef = {'label' => 'Motion with No Hearing','value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$mnh')"};
            
            if (-e($mnhFile)) {
                # We only need to read this file - no writing of anything is necessary
                open(INFILE, $mnhFile);
                while (my $line = <INFILE>) {
                    next if ($line !~ /^FIELDTYPES/);
                    last;
                }
                # Start counting here/
                while (my $line = <INFILE>) {
                    $mnhRef->{'value'}++;
                }
                push(@{$reportData{'data'}}, $mnhRef);
            }
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
            $temp = {
                'type' => "$rptType" . "_noAct",
                'file' => "$rptType" . "_noAct.txt",
                'caselist' => [],
                'TitleAppend' => 'No Activity for 300 Days'
            };
            push(@rpts,$temp);
            
            $reportData{'data'} =  [
                {'label' => '0 - 60 Days', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$rpts[0]->{'type'}')"},
                {'label' => '61 - 90 Days', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$rpts[1]->{'type'}')"},
                {'label' => '91+ Days', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$rpts[2]->{'type'}')"},
                {'label' => 'No Activity 300 Days', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$rpts[3]->{'type'}')"}
            ];
            
            my @noact;
            while (my $line = <INFILE>) {
                my @pieces = split("~", $line);
                my $age = $pieces[4];
                
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
                
                # How long since the last activity?
                my ($lm, $ld, $ly) = split("/",US_date($pieces[7]));
                my $days = Delta_Days($ly, $lm, $ld, $ty, $tm, $td);
                if ($days > 300) {
                    $reportData{'data'}[3]->{'value'}++;
                    push(@{$rpts[3]->{'caselist'}}, $line);
                }
            }
            close INFILE;
            
            # Now get the pending cases with motions but no hearings
            my $mnh = sprintf("%s_motNoEvent", $rptType);
            my $mnhFile = sprintf("%s/%s.txt", $dir, $mnh);
            
            my $mnhRef = {'label' => 'Motion with No Hearing','value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$mnh')"};
            
            if (-e($mnhFile)) {
                # We only need to read this file - no writing of anything is necessary
                open(INFILE, $mnhFile);
                while (my $line = <INFILE>) {
                    next if ($line !~ /^FIELDTYPES/);
                    last;
                }
                # Start counting here/
                while (my $line = <INFILE>) {
                    $mnhRef->{'value'}++;
                }
                push(@{$reportData{'data'}}, $mnhRef);
            }
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
