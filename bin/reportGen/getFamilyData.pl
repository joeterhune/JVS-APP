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
        (division_type like 'family') 
        and show_icms_list = 1
    union
	select
		division as DivisionID,
		'Family' as DivisionType
	from
		magistrates
	where 
		division NOT IN ('MJF')    
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
        #my %criticalData;
        my %contestedData;
        my %uncontestedData;
        my $rptMonth = $month;
        
        my $rptType = $reportType->{'rptType'};
        my @rpts;
        #my @critical;
    
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
        
        #$temp = {
        #    'type' => "$rptType" . "_noAct180",
        #    'file' => "$rptType" . "_noAct180.txt",
        #    'caselist' => [],
        #    'TitleAppend' => 'No Activity for 180 Days'
        #};
        #push(@critical,$temp);
        #$temp = {
        #    'type' => "$rptType" . "_noAct300",
        #    'file' => "$rptType" . "_noAct300.txt",
        #    'caselist' => [],
        #    'TitleAppend' => 'No Activity for 300 Days'
        #};
        #push(@critical,$temp);
        
        $reportData{'data'} =  [
            {'label' => '0 - 120', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$rpts[0]->{'type'}')"},
            {'label' => '121 - 180', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$rpts[1]->{'type'}')"},
            {'label' => '181+', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$rpts[2]->{'type'}')"}
        ];
        #
        #$criticalData{'data'} = [
        #    {'label' => 'No Activity<br/>180 Days', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$critical[0]->{'type'}')"},
        #    {'label' => 'No Activity<br/>300 Days', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','$critical[1]->{'type'}')"}
        #];
        
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
            #my ($lm, $ld, $ly) = split("/",US_date($pieces[7]));
            #my $days = Delta_Days($ly, $lm, $ld, $ty, $tm, $td);
            #if ($days > 300) {
            #    $criticalData{'data'}[1]->{'value'}++;
            #    push(@{$critical[1]->{'caselist'}}, $line);
            #} elsif ($days > 180) {
            #    $criticalData{'data'}[0]->{'value'}++;
            #    push(@{$critical[0]->{'caselist'}}, $line);
            #}
        }
        close INFILE;
        
        my $ftype = $file;
        $ftype =~ s/\.txt//g;
        my $outJson = sprintf("%s.json", $ftype);
        writeJsonFile($reportData{'data'}, $outJson);
        print "Wrote '$outJson',\n\n";
        
        # Build the reports for dissolution
        # First, contested
        my $cth = sprintf("%s_contested", $rptType);
        my $cthFile = sprintf("%s/%s.txt", $dir, $cth);
        $contestedData{'data'} = [
            {'label' => '0 - 120', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','pend_contested',0)"},
            {'label' => '121 - 180', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','pend_contested',1)"},
            {'label' => '181+', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','pend_contested',2)"}
        ];
        if (-e($cthFile)) {
            open(INFILE, $cthFile);
            while (my $line = <INFILE>) {
                next if ($line !~ /^FIELDTYPES/);
                last;
            }
            # Start counting here/
            while (my $line = <INFILE>) {
                my @pieces = split("~", $line);
                my $age = $pieces[4];
                if ($age > 180) {
                    $contestedData{'data'}[2]->{'value'}++;
                    #push(@{$rpts[2]->{'caselist'}}, $line);
                } elsif ($age > 120) {
                    $contestedData{'data'}[1]->{'value'}++;
                    #push(@{$rpts[1]->{'caselist'}}, $line);
                } else {
                    $contestedData{'data'}[0]->{'value'}++;
                    #push(@{$rpts[0]->{'caselist'}}, $line);
                }
            }
            #push(@{$criticalData{'data'}}, $mnhRef);
        }
        $ftype = $cthFile;
        $ftype =~ s/\.txt//g;
        $outJson = sprintf("%s.json", $ftype);
        writeJsonFile($contestedData{'data'}, $outJson);
        print "Wrote '$outJson',\n\n";
        
        # Then, uncontested
        my $ucth = sprintf("%s_uncontested", $rptType);
        my $ucthFile = sprintf("%s/%s.txt", $dir, $ucth);
        $uncontestedData{'data'} = [
            {'label' => '0 - 60', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','pend_uncontested',3)"},
            {'label' => '61 - 90', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','pend_uncontested',4)"},
            {'label' => '91+', 'value' => 0, "link" => "JavaScript:showDivRpt('$div','$month','$type','pend_uncontested',5)"}
        ];
        
        if (-e($ucthFile)) {
            open(INFILE, $ucthFile);
            while (my $line = <INFILE>) {
                next if ($line !~ /^FIELDTYPES/);
                last;
            }
            # Start counting here/
            while (my $line = <INFILE>) {
                my @pieces = split("~", $line);
                my $age = $pieces[4];
                if ($age > 90) {
                    $uncontestedData{'data'}[2]->{'value'}++;
                    #push(@{$rpts[2]->{'caselist'}}, $line);
                } elsif ($age > 60) {
                    $uncontestedData{'data'}[1]->{'value'}++;
                    #push(@{$rpts[1]->{'caselist'}}, $line);
                } else {
                    $uncontestedData{'data'}[0]->{'value'}++;
                    #push(@{$rpts[0]->{'caselist'}}, $line);
                }
            }
        } else {
            print "WHERE'S $ucthFile???\n";
        }
        $ftype = $ucthFile;
        $ftype =~ s/\.txt//g;
        $outJson = sprintf("%s.json", $ftype);
        writeJsonFile($uncontestedData{'data'}, $outJson);
        print "Wrote '$outJson',\n\n";
        
           
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
        }
        
    }
}