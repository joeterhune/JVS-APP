#!/usr/bin/perl -w

BEGIN {
    use lib "/usr/local/icms/bin";
}

use strict;

use Getopt::Long;

use JSON;

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

my $jdbh = dbConnect("judge-divs");

my $query = qq {
    select
        division_id as DivisionID,
        division_type as DivisionType
    from
        divisions
    where
        show_icms_list = 1
};

my %divlist;
getData(\%divlist, $query, $jdbh, {hashkey => 'DivisionID', flatten => 1});

my $dbh = dbConnect("icms");

$query = qq {
    select
        division_id as DivisionID,
        rptmonth as Month,
        IFNULL(init_filings,0) as InitFilings,
        IFNULL(dispositions,0) as Dispos,
        IFNULL(re_opens,0) as Reopens,
        IFNULL(re_dispositions,0) as Redispos
    from
        in_out
    order by
        rptmonth
};

my %rptData;
getData(\%rptData, $query, $dbh, {hashkey => 'DivisionID'});

my $json = JSON->new->allow_nonref;

foreach my $div (keys %rptData) {
    my $dir;
    
    next if (!defined($divlist{$div}->{'DivisionType'}));
    
    if ($divlist{$div}->{'DivisionType'} =~ /Civil|Family|UFC/) {
        $dir = "civ"
    } elsif ($divlist{$div}->{'DivisionType'} =~ /Felony|Misdemeanor|Traffic/) {
        $dir = "crim"
    } elsif ($divlist{$div}->{'DivisionType'} =~ /Juvenile/) {
        $dir = "juv"
    } elsif ($divlist{$div}->{'DivisionType'} =~ /Probate/) {
        $dir = "pro";
    } else {
        next;
    }
    
    my $divData = $rptData{$div};
    
    my %dataset;
    
    $dataset{'categories'} = [];
    my %categories;
    $categories{'category'} = [];
    push(@{$dataset{'categories'}}, \%categories);
    
    $dataset{'dataset'} = [];
    my %initFile = ('seriesname' => 'Initial Filings', 'data' => []);
    my %reopen = ('seriesname' => 'Reopens', 'data' => []);
    my %dispo = ('seriesname' => 'Dispositions', 'data' => []);
    my %redispo = ('seriesname' => 'Re-dispositions', 'data' => []);
    
    push(@{$dataset{'dataset'}}, \%initFile);
    push(@{$dataset{'dataset'}}, \%dispo);
    push(@{$dataset{'dataset'}}, \%reopen);
    push(@{$dataset{'dataset'}}, \%redispo);
    
    #dumpVar($dataset{'dataset'}[0]); exit;
    
    foreach my $month (@{$divData}) {
        my @pieces = split("-", $month->{'Month'});
        my $printMonth = sprintf("%02d/%04d", $pieces[1], $pieces[0]);
        my $catLabel = {'label' => $printMonth};
        push(@{$categories{'category'}}, $catLabel);
        
        my $initFile = {'value' => $month->{'InitFilings'}};
        my $dispo = {'value' => $month->{'Dispos'}};
        my $reopen = {'value' => $month->{'Reopens'}};
        my $redispo = {'value' => $month->{'Redispos'}};
                       
        push(@{$dataset{'dataset'}[0]->{'data'}}, $initFile);
        push(@{$dataset{'dataset'}[1]->{'data'}}, $dispo);
        push(@{$dataset{'dataset'}[2]->{'data'}}, $reopen);
        push(@{$dataset{'dataset'}[3]->{'data'}}, $redispo);
    }
    
    # Now write the file.  Since this is itself historical, we will put it into the top level of the directory,
    # NOT into a particular month
    my $jsonfile = sprintf("/var/www/Palm/%s/div%s/inOut.json", $dir, $div);
    
    print "Writing $jsonfile...\n";
    writeJsonFile(\%dataset, $jsonfile);
}