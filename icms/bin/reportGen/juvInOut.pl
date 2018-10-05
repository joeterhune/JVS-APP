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

my $dbh = dbConnect("wpb-banner-rpt");
doQuery("alter session set nls_date_format='YYYY-MM'", $dbh);

my $query = qq {
     
    select
        cdbcase_id as "CaseNumber",
        cdbcase_division_id as "DivisionID",
        'Total Filings' as "Category"
    from
        cdbcase
    where
        cdbcase_cort_code in ('CJ','DP')
        and cdbcase_init_filing >= '$month' and cdbcase_init_filing < ADD_MONTHS('$month',1)
        and cdbcase_division_id in ('JA', 'JK', 'JL', 'JO', 'JS', 'JM' )

    UNION
    
    select
        cdbcase_id as "CaseNumber",
        cdbcase_division_id as "DivisionID",
        'Dispositions' as "Category"
    from
        czbcsrs,
        cdbcase
    where
        czbcsrs_case_id = cdbcase_id
        and cdbcase_cort_code in ('CJ','DP')
        and czbcsrs_srs_disp_date >= '$month' and czbcsrs_srs_disp_date < ADD_MONTHS('$month',1)
        and czbcsrs_srs_disp_code in ('JC', 'JNF', 'JPD','PDC', 'PDU', 'PDDP', 'PDAJ', 'PDCFN', 'PDSH', 'PDTPR', 'TC', 'XX')
        and cdbcase_division_id in ('JA', 'JK', 'JL', 'JO', 'JS', 'JM' )
            
    UNION
    
    select
        cdbcase_id as "CaseNumber",
        cdbcase_division_id as "DivisionID",
        'Re-Opens' as "Category"
    from
        czbcsrs,
        cdbcase
    where
        czbcsrs_case_id = cdbcase_id
        and cdbcase_cort_code in ('CJ','DP')
        and czbcsrs_status_date >= '$month' and czbcsrs_status_date < ADD_MONTHS('$month',1)
        and czbcsrs_status_code in ('PVOP', 'ROCJ', 'RO', 'RODP')
        and cdbcase_division_id in ('JA', 'JK', 'JL', 'JO', 'JS', 'JM' )
                
    UNION
    
    select
        cdbcase_id as "CaseNumber",
        cdbcase_division_id as "DivisionID",
        'Re-Dispositions' as "Category"
    from
        czbcsrs,
        cdbcase
    where
        czbcsrs_case_id = cdbcase_id
        and cdbcase_cort_code in ('CJ','DP')
        and czbcsrs_srs_disp_date >= '$month' and czbcsrs_srs_disp_date < ADD_MONTHS('$month',1)
        and czbcsrs_srs_disp_code in ('RD')
        and cdbcase_division_id in ('JA', 'JK', 'JL', 'JO', 'JS', 'JM' )
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

