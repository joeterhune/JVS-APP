#!/usr/bin/perl -w

BEGIN {
    use lib $ENV{'JVS_PERL5LIB'};
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
        exit;
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
        my %criticalData;
        my %juryData;
        my $rptMonth = $month;
        
        my $rptType = $reportType->{'rptType'};
        my @rpts;
        my @critical;
        
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
                'type' => "$rptType" . "_noAct180",
                'file' => "$rptType" . "_noAct180.txt",
                'caselist' => [],
                'TitleAppend' => 'No Activity for 180 Days'
            };
            push(@critical,$temp);
            $temp = {
                'type' => "$rptType" . "_noAct300",
                'file' => "$rptType" . "_noAct300.txt",
                'caselist' => [],
                'TitleAppend' => 'No Activity for 300 Days'
            };
            push(@critical,$temp);
            
            $reportData{'data'} =  [
                {'label' => '0 - 120', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$rpts[0]->{'type'}')"},
                {'label' => '121 - 180', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$rpts[1]->{'type'}')"},
                {'label' => '181+', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$rpts[2]->{'type'}')"}
            ];
            
            $criticalData{'data'} = [
                {'label' => 'No Activity<br/>180 Days', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$critical[0]->{'type'}')"},
                {'label' => 'No Activity<br/>300 Days', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$critical[1]->{'type'}',-1,1)"}
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
                    $criticalData{'data'}[1]->{'value'}++;
                    push(@{$critical[1]->{'caselist'}}, $line);
                } elsif ($days > 180) {
                    $criticalData{'data'}[0]->{'value'}++;
                    push(@{$critical[0]->{'caselist'}}, $line);
                }
            }
            close INFILE;
            
            my $ftype = $file;
            $ftype =~ s/\.txt//g;
            my $outJson = sprintf("%s.json", $ftype);
            writeJsonFile($reportData{'data'}, $outJson);
            print "Wrote '$outJson',\n\n";
            
            # Build the report for jury trials
            my $jth = sprintf("%s_juryTrials", $rptType);
            my $jthFile = sprintf("%s/%s.txt", $dir, $jth);
            $juryData{'data'} = [
                {'label' => '0-12', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','pend_juryTrials',0)"},
                {'label' => '12-18', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','pend_juryTrials',1)"},
                {'label' => '19+', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','pend_juryTrials',2)"}
            ];
            if (-e($jthFile)) {
                open(INFILE, $jthFile);
                while (my $line = <INFILE>) {
                    next if ($line !~ /^FIELDTYPES/);
                    last;
                }
                # Start counting here/
                while (my $line = <INFILE>) {
                    my @pieces = split("~", $line);
                    my $age = $pieces[4];
                    if ($age > 548) {
                        $juryData{'data'}[2]->{'value'}++;
                        #push(@{$rpts[2]->{'caselist'}}, $line);
                    } elsif ($age > 365) {
                        $juryData{'data'}[1]->{'value'}++;
                        #push(@{$rpts[1]->{'caselist'}}, $line);
                    } else {
                        $juryData{'data'}[0]->{'value'}++;
                        #push(@{$rpts[0]->{'caselist'}}, $line);
                    }
                }
                #push(@{$criticalData{'data'}}, $mnhRef);
            }
            $ftype = $jthFile;
            $ftype =~ s/\.txt//g;
            $outJson = sprintf("%s.json", $ftype);
            writeJsonFile($juryData{'data'}, $outJson);
            print "Wrote '$outJson',\n\n";
            
            
            # Now build the "critical" info chart data (LOS, LOP, etc.)
            
            # Now get the pending cases with motions but no hearings
            my $mnh = sprintf("%s_motNoEvent", $rptType);
            my $mnhFile = sprintf("%s/%s.txt", $dir, $mnh);
            
            my $mnhRef = {'label' => 'Motion with<br/>No Hearing','value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$mnh')"};
            
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
                push(@{$criticalData{'data'}}, $mnhRef);
            }
            
            # And LOS
            my $los = sprintf("%s_los", $rptType);
            my $losFile = sprintf("%s/%s.txt", $dir, $los);
            
            my $losRef = {'label' => 'LOS','value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$los')"};
            
            if (-e($losFile)) {
                # We only need to read this file - no writing of anything is necessary
                open(INFILE, $losFile);
                while (my $line = <INFILE>) {
                    next if ($line !~ /^FIELDTYPES/);
                    last;
                }
                # Start counting here/
                while (my $line = <INFILE>) {
                    $losRef->{'value'}++;
                }
                push(@{$criticalData{'data'}}, $losRef);
            }
            
            my $filetype = $file;
            $filetype =~ s/\.txt//g;
            $outJson = sprintf("%s_crit.json", $filetype);
            writeJsonFile($criticalData{'data'}, $outJson);
            print "Wrote '$outJson'\n\n";
            
        } else {
            my $temp = {
                'type' => "$rptType" . "_0-75",
                'file' => "$rptType" . "_0-75.txt",
                'caselist' => [],
                'TitleAppend' => '0-75 Days'
            };
            
            push(@rpts,$temp);
            $temp = {
                'type' => "$rptType" . "_76-95",
                'file' => "$rptType" . "_76-95.txt",
                'caselist' => [],
                'TitleAppend' => '76-95 Days'
            };
            push(@rpts,$temp);
            $temp = {
                'type' => "$rptType" . "_96+",
                'file' => "$rptType" . "_96+.txt",
                'caselist' => [],
                'TitleAppend' => '96+ Days'
            };
            push(@rpts,$temp);
            
            
            $temp = {
                'type' => "$rptType" . "_noAct180",
                'file' => "$rptType" . "_noAct180.txt",
                'caselist' => [],
                'TitleAppend' => 'No Activity for 180 Days'
            };
            push(@critical,$temp);
            $temp = {
                'type' => "$rptType" . "_noAct300",
                'file' => "$rptType" . "_noAct300.txt",
                'caselist' => [],
                'TitleAppend' => 'No Activity for 300 Days'
            };
            push(@critical,$temp);
            
            $reportData{'data'} =  [
                {'label' => '0 - 75', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$rpts[0]->{'type'}')"},
                {'label' => '75 - 95', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$rpts[1]->{'type'}')"},
                {'label' => '96+', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$rpts[2]->{'type'}')"}
            ];
            
            $criticalData{'data'} = [
                {'label' => 'No Activity<br/>180 Days', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$critical[0]->{'type'}')"},
                {'label' => 'No Activity<br/>300 Days', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$critical[1]->{'type'}',-1,1)"}
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
                
                if (!defined($lm)) {
                    # No activity date?  Look at the filing date.
                    ($lm, $ld, $ly) = split("/",US_date($pieces[3]));
                    if (!defined($lm)) {
                        next;
                    }
                }
                
                my $days = Delta_Days($ly, $lm, $ld, $ty, $tm, $td);
                if ($days > 300) {
                    $criticalData{'data'}[1]->{'value'}++;
                    push(@{$critical[1]->{'caselist'}}, $line);
                } elsif ($days > 180) {
                    $criticalData{'data'}[0]->{'value'}++;
                    push(@{$critical[0]->{'caselist'}}, $line);
                }
            }
            close INFILE;
            
            my $ftype = $file;
            $ftype =~ s/\.txt//g;
            my $outJson = sprintf("%s.json", $ftype);
            writeJsonFile($reportData{'data'}, $outJson);
            print "Wrote '$outJson',\n\n";
            
            # Now build the "critical" info chart data (LOS, LOP, etc.)
            
            # Now get the pending cases with motions but no hearings
            my $mnh = sprintf("%s_motNoEvent", $rptType);
            my $mnhFile = sprintf("%s/%s.txt", $dir, $mnh);
            
            my $mnhRef = {'label' => 'Motion with<br/>No Hearing','value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$mnh')"};
            
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
                push(@{$criticalData{'data'}}, $mnhRef);
            }
            
            # And LOS
            my $los = sprintf("%s_los", $rptType);
            my $losFile = sprintf("%s/%s.txt", $dir, $los);
            
            my $losRef = {'label' => 'LOS','value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$los')"};
            
            if (-e($losFile)) {
                # We only need to read this file - no writing of anything is necessary
                open(INFILE, $losFile);
                while (my $line = <INFILE>) {
                    next if ($line !~ /^FIELDTYPES/);
                    last;
                }
                # Start counting here/
                while (my $line = <INFILE>) {
                    $losRef->{'value'}++;
                }
                push(@{$criticalData{'data'}}, $losRef);
            }
            
            my $filetype = $file;
            $filetype =~ s/\.txt//g;
            $outJson = sprintf("%s_crit.json", $filetype);
            writeJsonFile($criticalData{'data'}, $outJson);
            print "Wrote '$outJson'\n\n";
            
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
        
        foreach my $rpt (@critical) {
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
        
        #my $filetype = $file;
        #$filetype =~ s/\.txt//g;
        #my $outJson = sprintf("%s.json", $filetype);
        #writeJsonFile($reportData{'data'}, $outJson);
        #print "Wrote '$outJson'\n\n";
    }
}