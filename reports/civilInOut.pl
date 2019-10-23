#!/usr/bin/perl

BEGIN {
    use lib $ENV{'JVS_PERL5LIB'};
}

use strict;

use Getopt::Long;

use Common qw (
    lastMonth
    dumpVar
    inArray
    getShowcaseDb
);

use DB_Functions qw (
    dbConnect
    doQuery
    getData
    getDbSchema
);

my $month;
GetOptions("m=s" => \$month);

if (!defined($month)) {
    $month = lastMonth();
}

my $inMonth = $month;
$month = sprintf("%s-01", $month);

my $db = getShowcaseDb();
my $dbh = dbConnect($db);
my $schema = getDbSchema($db);

my $query = qq {
    
    --CIRCUIT CIVIL
    SELECT
    	CaseNumber,
        DivisionID,
        'Total Filings' as Category
    FROM
        $schema.vCase
    WHERE
        CourtType = 'CA'
        AND CONVERT(char(10), FileDate, 126) >= '$month' AND CONVERT(char(10), FileDate, 126) < DATEADD(MONTH, 1, '$month')
        AND DivisionID in ('AA', 'AB','AC', 'AD', 'AE', 'AF', 'AG', 'AH', 'AI', 'AJ', 'AK', 'AN', 'AO', 'AY')
        
    UNION
        
    select
        CaseNumber,
        DivisionID,
        'Dispositions' as Category
    from
        $schema.vCase
    where
        CourtType = 'CA'
        AND CONVERT(char(10), DispositionDate, 126) >= '$month' AND CONVERT(char(10), DispositionDate, 126) < DATEADD(MONTH, 1, '$month')
        AND DivisionID in ('AA', 'AB','AC', 'AD', 'AE', 'AF', 'AG', 'AH', 'AI', 'AJ', 'AK', 'AN', 'AO', 'AY')
        
    UNION
    
    select
        vc.CaseNumber,
        vc.DivisionID,
        'Re-Opens' as Category
    from
    	$schema.vReopenHistory vr
    INNER JOIN $schema.vCase vc with(nolock) 
    	on (vr.CaseID = vc.CaseID)
    where
        vc.CourtType = 'CA'
        AND vc.DivisionID in ('AA', 'AB','AC', 'AD', 'AE', 'AF', 'AG', 'AH', 'AI', 'AJ', 'AK', 'AN', 'AO', 'AY')
        AND CONVERT(char(10), vr.ReopenDate, 126) >= '$month' AND CONVERT(char(10), vr.ReopenDate, 126) < DATEADD(MONTH, 1, '$month')
    
    UNION
    
    select
        vc.CaseNumber,
        vc.DivisionID,
        'Re-Dispositions' as Category
    from
    	$schema.vReopenHistory vr
    INNER JOIN $schema.vCase vc with(nolock) 
    	on (vr.CaseID = vc.CaseID)
    where
        vc.CourtType = 'CA'
        AND vc.DivisionID in ('AA', 'AB','AC', 'AD', 'AE', 'AF', 'AG', 'AH', 'AI', 'AJ', 'AK', 'AN', 'AO', 'AY')
        AND CONVERT(char(10), vr.ReopenCloseDate, 126) >= '$month' AND CONVERT(char(10), vr.ReopenCloseDate, 126) < DATEADD(MONTH, 1, '$month')
      
    UNION
    
    -- COUNTY CIVIL
    select
        CaseNumber,
        DivisionID,
        'Total Filings' as Category
    from
        $schema.vCase
    where
        CourtType in ('CC','SC')
        AND CONVERT(char(10), FileDate, 126) >= '$month' AND CONVERT(char(10), FileDate, 126) < DATEADD(MONTH, 1, '$month')
        AND DivisionID IN ('RA', 'RB', 'RD', 'RE', 'RF', 'RH', 'RJ', 'RL', 'RS' )
        
    UNION
    
    select
        CaseNumber,
        DivisionID,
        'Dispositions' as Category
    from
        $schema.vCase
    where
        CourtType in ('CC','SC')
        AND CONVERT(char(10), DispositionDate, 126) >= '$month' AND CONVERT(char(10), DispositionDate, 126) < DATEADD(MONTH, 1, '$month')
        AND DivisionID IN  ('RA', 'RB', 'RD', 'RE', 'RF', 'RH', 'RJ', 'RL', 'RS' )
        
        
    UNION
    
    select
        vc.CaseNumber,
        vc.DivisionID,
        'Re-Opens' as Category
    from
    	$schema.vReopenHistory vr
    INNER JOIN $schema.vCase vc with(nolock) 
    	on (vr.CaseID = vc.CaseID)
    where
        vc.CourtType in ('CC','SC')
        AND vc.DivisionID IN  ('RA', 'RB', 'RD', 'RE', 'RF', 'RH', 'RJ', 'RL', 'RS' )
        AND CONVERT(char(10), vr.ReopenDate, 126) >= '$month' AND CONVERT(char(10), vr.ReopenDate, 126) < DATEADD(MONTH, 1, '$month')
        
    UNION
    
    select
        vc.CaseNumber,
        vc.DivisionID,
        'Re-Dispositions' as Category
    from
    	$schema.vReopenHistory vr
    INNER JOIN $schema.vCase vc with(nolock) 
    	on (vr.CaseID = vc.CaseID)
    where
        vc.CourtType IN ('CC','SC')
        AND vc.DivisionID IN  ('RA', 'RB', 'RD', 'RE', 'RF', 'RH', 'RJ', 'RL', 'RS' )
         AND CONVERT(char(10), vr.ReopenCloseDate, 126) >= '$month' AND CONVERT(char(10), vr.ReopenCloseDate, 126) < DATEADD(MONTH, 1, '$month')
      
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
    my @args = ($div, $inMonth, $initFilings, $dispos, $reopens, $redispos);
    doQuery($query, $idbh, \@args);
}
