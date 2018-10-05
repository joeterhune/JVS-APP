#!/usr/bin/perl

BEGIN {
    use lib "/usr/local/icms/bin";
}

use strict;

use Getopt::Long;

use Common qw (
    lastMonth
    dumpVar
    inArray
);

use DB_Functions qw (
    dbConnect
    doQuery
    getData
);

my $month;
GetOptions("m=s" => \$month);

if (!defined($month)) {
    $month = lastMonth();
}

my $dbh = dbConnect("showcase-rpt");

my $query = qq {
    select
        CaseNumber,
        DivisionID,
        'Total Filings' as Category
    from
    	vCase with(nolock)
    where
    	CourtType in ('MM','MO','CO','CT','CF')
        and DivisionID is not null
    	and ((cast(FileDate as DATE) between '$month-01 00:00:00' and DATEADD(month,1,'$month-01 00:00:00')))
        
    UNION
    
    select
        CaseNumber,
        DivisionID,
        'Dispositions' as Category
    from
        vCase with(nolock)
    where
        CourtType in ('MM','MO','CO','CT','CF')
        and DivisionID is not null
        and ((cast(DispositionDate as DATE) between '$month-01 00:00:00' and DATEADD(month,1,'$month-01 00:00:00')))
        
    UNION
    
    select
        vc.CaseNumber,
        vc.DivisionID,
        'Re-Opens' as Category
    from
    	vReopenHistory vr
            INNER JOIN vCase vc with(nolock) on (vr.CaseNumber = vc.CaseNumber)
    where
        vc.CourtType in ('MM','MO','CO','CT','CF')
        and vc.DivisionID is not null
        and ((cast(vr.ReopenDate as DATE) between '$month-01 00:00:00' and DATEADD(month,1,'$month-01 00:00:00')))

    UNION
    
    select
        vc.CaseNumber,
        vc.DivisionID,
        'Re-Dispositions' as Category
    from
    	vReopenHistory vr
            INNER JOIN vCase vc with(nolock) on (vr.CaseNumber = vc.CaseNumber)
    where
        vc.CourtType in ('MM','MO','CO','CT','CF')
        and vc.DivisionID is not null
        and ((cast(vr.ReopenCloseDate as DATE) between '$month-01 00:00:00' and DATEADD(month,1,'$month-01 00:00:00')))
};

my @results;

getData(\@results,$query,$dbh);

my %counts;

foreach my $result (@results) {
    my $div = $result->{'DivisionID'};
    if (!defined($counts{$div})) {
        $counts{$div} = {};
    }
    if (!defined($counts{$div}->{$result->{'Category'}})) {
        $counts{$div}->{$result->{'Category'}} = {};
    }
    $counts{$div}->{$result->{'Category'}}->{$result->{'CaseNumber'}} = 1;
}

my %divCounts;

foreach my $div (keys (%counts)) {
    $divCounts{$div} = {};
    foreach my $category (keys %{$counts{$div}}) {
        $divCounts{$div}->{$category} = scalar(keys(%{$counts{$div}->{$category}}));
    }
}

# Now fo the DB stuff
my $idbh = dbConnect("icms");

foreach my $div (keys %divCounts) {
    my $initFilings = $divCounts{$div}->{'Total Filings'};
    my $dispos = $divCounts{$div}->{'Dispositions'};
    my $reopens = $divCounts{$div}->{'Re-Opens'};
    my $redispos = $divCounts{$div}->{'Re-Dispositions'};
    my $query = qq {
        replace into
            in_out (
                division_id,
                rptmonth,
                init_filings,
                dispositions,
                re_opens,
                re_dispositions
            ) values (
                ?,?,?,?,?,?
            )
    };
    my @args = ($div, $month, $initFilings, $dispos, $reopens, $redispos);
    doQuery($query, $idbh, \@args);
}
