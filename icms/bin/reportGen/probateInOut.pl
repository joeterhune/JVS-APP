#!/usr/bin/perl

BEGIN {
    use lib "$ENV{'PERL5LIB'}";
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
        cdbcase_cort_code in ('CP','GA','MH')
        and cdbcase_init_filing >= '$month' and cdbcase_init_filing < ADD_MONTHS('$month',1)
        and cdbcase_division_id in ('IB','IC', 'IH', 'II', 'IJ', 'IX', 'IY', 'IZ')
        
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
        and cdbcase_cort_code in ('CP','GA','MH')
        and czbcsrs_srs_disp_date >= '$month' and czbcsrs_srs_disp_date < ADD_MONTHS('$month',1)
        and czbcsrs_srs_disp_code in ('CLSD', 'DA', 'DADR', 'DBDR', 'DAM', 'DAO', 'DAS', 'DB', 'DBM', 'DBO', 'DBS', 'DD', 'DJ', 'DO', 'DY', 'NJ', 'TC')
        and cdbcase_division_id in ('IB','IC', 'IH', 'II', 'IJ', 'IX', 'IY', 'IZ')
        
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
        and cdbcase_cort_code in ('CP','GA','MH')
        and czbcsrs_status_date >= '$month' and czbcsrs_status_date < ADD_MONTHS('$month',1)
        and czbcsrs_status_code in ('RO', 'RE', 'RM', 'TO')
        and cdbcase_division_id in ('IB','IC', 'IH', 'II', 'IJ', 'IX', 'IY', 'IZ')
    
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
        and cdbcase_cort_code in ('CP','GA','MH')
        and czbcsrs_status_date >= '$month' and czbcsrs_status_date < ADD_MONTHS('$month',1)
        and czbcsrs_srs_disp_code in ('AS', 'DE', 'DM')
        and cdbcase_division_id in ('IB','IC', 'IH', 'II', 'IX', 'IJ', 'IY', 'IZ')
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


#
#
#
#--JUVENILE DEPENDENCY
#
#
#Select 'Dependency' As "CourtType", cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name "Judge_Name", 'Total Filings' as Category, count(*) "TotalCount"
#from cdbcase, spriden
#where cdbcase_division_id = spriden_id 
#and spriden_change_ind is null 
#and cdbcase_cort_code in ('DP')
#and cdbcase_init_filing between trunc(trunc(sysdate,'MM')-1,'MM') and trunc(sysdate,'MM')-1
#and cdbcase_division_id in ('JA', 'JK', 'JL', 'JO', 'JS', 'JM' )
#group by cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name
#
#Union
#
#Select 'Dependency' As "CourtType", cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name "Judge_Name", 'Dispositions' as Category, count(czbcsrs_srs_disp_code)
#from czbcsrs, cdbcase, spriden
#where czbcsrs_case_id = cdbcase_id 
#and cdbcase_division_id = spriden_id 
#and spriden_change_ind is null 
#and cdbcase_cort_code in ('DP')
#and czbcsrs_srs_disp_date between trunc(trunc(sysdate,'MM')-1,'MM') and trunc(sysdate,'MM')-1
#and czbcsrs_srs_disp_code in ('JC', 'PDC', 'PDU', 'PDDP', 'PDAJ', 'PDCFN', 'PDSH', 'PDTPR', 'TC', 'XX')
#and cdbcase_division_id in ('JA', 'JK', 'JL', 'JO', 'JS', 'JM' )
#group by cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name
#
#
#Union
#
#Select 'Dependency' As "CourtType", cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name "Judge_Name", 'Re-Opens' as Category, count(czbcsrs_status_code)
#from czbcsrs, cdbcase, spriden
#where czbcsrs_case_id = cdbcase_id 
#and cdbcase_division_id = spriden_id 
#and spriden_change_ind is null  
#and cdbcase_cort_code in ('DP') 
#and czbcsrs_status_date between trunc(trunc(sysdate,'MM')-1,'MM') and trunc(sysdate,'MM')-1
#and czbcsrs_status_code in ('RO', 'RODP'  )
#and cdbcase_division_id in ('JA', 'JK', 'JL', 'JO', 'JS', 'JM' )
#group by cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name
#
#
#Union
#
#Select 'Dependency' As "CourtType", cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name "Judge_Name", 'Re-Dispositions' as Category, count(czbcsrs_status_code)
#from czbcsrs, cdbcase, spriden
#where czbcsrs_case_id = cdbcase_id 
#and cdbcase_division_id = spriden_id 
#and spriden_change_ind is null 
#and cdbcase_cort_code in ('DP')
#and czbcsrs_srs_disp_date between trunc(trunc(sysdate,'MM')-1,'MM') and trunc(sysdate,'MM')-1
#and czbcsrs_srs_disp_code in ('RD')
#and cdbcase_division_id in ('JA', 'JK', 'JL', 'JO', 'JS', 'JM' )
#group by cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name
#
#
#Union
#
#
#
#Select 'Dependency' As "CourtType", cdbcase_id, cdbcase_division_id,   cdbcase_ctyp_code, spriden_last_name "Judge_Name", 'Pending Status' as Category, count(*) "TotalCount"
#from cdbcase, spriden
#where cdbcase_division_id = spriden_id 
#and spriden_change_ind is null 
#and cdbcase_cort_code in ('DP')
#and srs_status_code(cdbcase_id) not in ('AS','CFDS','CLSD','DA','DADR','DAM','DAO','DAS','DB','DBDR','DBM','DBO','DBS','DD','DE','DJ','DM','DO','DY','GC','JC','JDF','JDIV','JNF','JPD','NJ','OPROB','OTCD','OTDF','PCA','PDAJ','PDC','PDDP','PDU','RD','TC','XX','ZVDS','PDAD','PDCF','PDCFN','PDSH','PDTPR','RO', 'ROCJ', 'RODP', 'RE', 'RM')
#and cdbcase_division_id in ('JA', 'JK', 'JL', 'JO', 'JS', 'JM' )
#group by cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name
#
#
#Union
#
#
#Select 'Dependency' As "CourtType", cdbcase_id, cdbcase_division_id,   cdbcase_ctyp_code, spriden_last_name "Judge_Name", 'ReOpen Status' as Category, count(*) "TotalCount"
#from cdbcase, spriden
#where cdbcase_division_id = spriden_id 
#and spriden_change_ind is null 
#and cdbcase_cort_code in ('DP')
#and srs_status_code(cdbcase_id) in ('RO', 'ROCJ', 'RODP', 'RE', 'RM')
#and cdbcase_division_id in ('JA', 'JK', 'JL', 'JO', 'JS', 'JM' )
#group by cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name
#
#
#
#Union
#
#
#
#
#
#
#
#
#
#--JUVENILE DELINQUENCY
#
#
#
#Select 'Delinquency' As "CourtType", cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name "Judge_Name", 'Total Filings' as Category, count(*) "TotalCount"
#from cdbcase, spriden
#where cdbcase_division_id = spriden_id 
#and spriden_change_ind is null 
#and cdbcase_cort_code in ('CJ')
#and cdbcase_init_filing between trunc(trunc(sysdate,'MM')-1,'MM') and trunc(sysdate,'MM')-1
#and cdbcase_division_id in ('JA', 'JK', 'JL', 'JO', 'JS', 'JM' )
#group by cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name
#
#Union
#
#Select 'Delinquency' As "CourtType", cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name "Judge_Name", 'Dispositions' as Category, count(czbcsrs_srs_disp_code)
#from czbcsrs, cdbcase, spriden
#where czbcsrs_case_id = cdbcase_id
#and cdbcase_division_id = spriden_id 
#and spriden_change_ind is null 
#and cdbcase_cort_code in ('CJ') 
#and czbcsrs_srs_disp_date between trunc(trunc(sysdate,'MM')-1,'MM') and trunc(sysdate,'MM')-1
#and czbcsrs_srs_disp_code in ('JC', 'JNF', 'JPD')
#and cdbcase_division_id in ('JA', 'JK', 'JL', 'JO', 'JS', 'JM' )
#group by cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name
#
#Union
#
#Select 'Delinquency' As "CourtType", cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name "Judge_Name", 'Re-Opens' as Category, count(czbcsrs_status_code)
#from czbcsrs, cdbcase, spriden
#where czbcsrs_case_id = cdbcase_id
#and cdbcase_division_id = spriden_id 
#and spriden_change_ind is null 
#and cdbcase_cort_code in ('CJ') 
#and czbcsrs_status_date between trunc(trunc(sysdate,'MM')-1,'MM') and trunc(sysdate,'MM')-1
#and czbcsrs_status_code in ('PVOP', 'ROCJ', 'RO' )
#and cdbcase_division_id in ('JA', 'JK', 'JL', 'JO', 'JS', 'JM' )
#group by cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name
#
#
#Union
#
#Select 'Delinquency' As "CourtType", cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name "Judge_Name", 'Re-Dispositions' as Category, count(czbcsrs_status_code)
#from czbcsrs, cdbcase, spriden
#where czbcsrs_case_id = cdbcase_id 
#and cdbcase_division_id = spriden_id 
#and spriden_change_ind is null 
#and cdbcase_cort_code in ('CJ') 
#and czbcsrs_srs_disp_date between trunc(trunc(sysdate,'MM')-1,'MM') and trunc(sysdate,'MM')-1
#and czbcsrs_srs_disp_code in ('RD')
#and cdbcase_division_id in ('JA', 'JK', 'JL', 'JO', 'JS', 'JM' )
#group by cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name
#
#
#
#
#Union
#
#
#Select 'Delinquency' As "CourtType", cdbcase_id, cdbcase_division_id,   cdbcase_ctyp_code, spriden_last_name "Judge_Name", 'Pending Status' as Category, count(distinct cdbcase_id)
#from cdbcase, spriden
#where cdbcase_division_id = spriden_id 
#and spriden_change_ind is null 
#and cdbcase_cort_code in ('CJ')
#and srs_status_code(cdbcase_id) not in ('AS','CFDS','CLSD','DA','DADR','DAM','DAO','DAS','DB','DBDR','DBM','DBO','DBS','DD','DE','DJ','DM','DO','DY','GC','JC','JDF','JDIV','JNF','JPD','NJ','OPROB','OTCD','OTDF','PCA','PDAJ','PDC','PDDP','PDU','RD','TC','XX','ZVDS','PDAD','PDCF','PDCFN','PDSH','PDTPR', 'RO', 'ROCJ', 'RODP', 'RE', 'RM')
#and cdbcase_division_id in ('JA', 'JK', 'JL', 'JO', 'JS', 'JM' )
#group by cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name
#
#
#Union
#
#
#Select 'Delinquency' As "CourtType", cdbcase_id, cdbcase_division_id,   cdbcase_ctyp_code, spriden_last_name "Judge_Name", 'ReOpen Status' as Category, count(distinct cdbcase_id)
#from cdbcase, spriden
#where cdbcase_division_id = spriden_id 
#and spriden_change_ind is null 
#and cdbcase_cort_code in ('CJ')
#and srs_status_code(cdbcase_id) in ('RO', 'ROCJ', 'RODP', 'RE', 'RM')
#and cdbcase_division_id in ('JA', 'JK', 'JL', 'JO', 'JS', 'JM' )
#group by cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name
#
#
#
#Union
#
#
#
#
#
#
#
#
#--Probate
#
#Select 'Probate' As "CourtType", cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name "Judge_Name", 'Total Filings' as Category, count(*) "TotalCount"
#from cdbcase, spriden
#where cdbcase_division_id = spriden_id 
#and spriden_change_ind is null 
#and cdbcase_cort_code in ('CP','GA','MH')
#and cdbcase_init_filing between trunc(trunc(sysdate,'MM')-1,'MM') and trunc(sysdate,'MM')-1
#and cdbcase_division_id in ('IB','IC', 'IH', 'II', 'IJ', 'IX', 'IY', 'IZ')
#group by cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name
#
#
#Union
#
#Select 'Probate' As "CourtType", cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name "Judge_Name", 'Dispositions' as Category, count(distinct cdbcase_id)
#from czbcsrs, cdbcase, spriden
#where cdbcase_division_id = spriden_id 
#and spriden_change_ind is null 
#and czbcsrs_case_id = cdbcase_id 
#and cdbcase_cort_code in ('CP','GA','MH')
#and czbcsrs_srs_disp_date between trunc(trunc(sysdate,'MM')-1,'MM') and trunc(sysdate,'MM')-1
#and czbcsrs_srs_disp_code in ('CLSD', 'DA', 'DADR', 'DBDR', 'DAM', 'DAO', 'DAS', 'DB', 'DBM', 'DBO', 'DBS', 'DD', 'DJ', 'DO', 'DY', 'NJ', 'TC')
#and cdbcase_division_id in ('IB','IC', 'IH', 'II', 'IJ', 'IX', 'IY', 'IZ')
#group by cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name
#
#Union
#
#Select 'Probate' As "CourtType", cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name "Judge_Name", 'Re-Opens' as Category, count(distinct cdbcase_id)
#from czbcsrs, cdbcase, spriden
#where cdbcase_division_id = spriden_id 
#and spriden_change_ind is null 
#and czbcsrs_case_id = cdbcase_id
#and cdbcase_cort_code in ('CP','GA','MH')
#and czbcsrs_status_date between trunc(trunc(sysdate,'MM')-1,'MM') and trunc(sysdate,'MM')-1
#and czbcsrs_status_code in ('RO', 'RE', 'RM', 'TO')
#and cdbcase_division_id in ('IB','IC', 'IH', 'II', 'IJ', 'IX', 'IY', 'IZ')
#group by cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name 
#
#Union
#
#Select 'Probate' As "CourtType", cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name "Judge_Name", 'Re-Dispositions' as Category, count(distinct cdbcase_id)
#from czbcsrs, cdbcase, spriden
#where cdbcase_division_id = spriden_id 
#and spriden_change_ind is null 
#and czbcsrs_case_id = cdbcase_id 
#and cdbcase_cort_code in ('CP','GA','MH')
#and czbcsrs_status_date between trunc(trunc(sysdate,'MM')-1,'MM') and trunc(sysdate,'MM')-1
#and czbcsrs_srs_disp_code in ('AS', 'DE', 'DM')
#and cdbcase_division_id in ('IB','IC', 'IH', 'II', 'IX', 'IJ', 'IY', 'IZ')
#group by cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name 
#
#
#
#Union
#
#
#Select 'Probate' As "CourtType", cdbcase_id, cdbcase_division_id,   cdbcase_ctyp_code, spriden_last_name "Judge_Name", 'Pending status' as Category, count(distinct cdbcase_id)
#from cdbcase, spriden
#where cdbcase_division_id = spriden_id 
#and spriden_change_ind is null 
#and cdbcase_cort_code in ('CP','GA','MH')
#and srs_status_code(cdbcase_id) in ('PE')
#and cdbcase_division_id in ('IB','IC', 'IH', 'II', 'IJ', 'IX', 'IY', 'IZ')
#group by cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name 
#
#
#Union
#
#
#Select 'Probate' As "CourtType", cdbcase_id, cdbcase_division_id,   cdbcase_ctyp_code, spriden_last_name "Judge_Name", 'ReOpen Status' as Category, count(distinct cdbcase_id)
#from cdbcase, spriden
#where cdbcase_division_id = spriden_id 
#and spriden_change_ind is null 
#and cdbcase_cort_code in ('CP','GA','MH')
#and srs_status_code(cdbcase_id) in ('RO', 'RE', 'RM','TO')
#and cdbcase_division_id in ('IB','IC', 'IH', 'II', 'IJ', 'IX', 'IY', 'IZ')
#group by cdbcase_id, cdbcase_division_id, cdbcase_ctyp_code, spriden_last_name
#};
