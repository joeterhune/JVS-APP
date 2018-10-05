#!/usr/bin/perl -w

BEGIN {
	use lib "/usr/local/icms/bin";
}

use strict;
use Common qw (
    ISO_date
    today
    dumpVar
    @SCCODES
);
use DB_Functions qw (
    dbConnect
    getData
    getDataOne
    getDbSchema
    doQuery
);
use Calendars qw (
    $BANNER_SOURCE_ID
    getVRBEvents
    sortExternalEvents
    vrbCompareAndUpdate
);

use Getopt::Long;

my $vrb;
my $startDate;
GetOptions("d=s" => \$vrb, "s=s" => \$startDate);
if (!defined($vrb)) {
    $vrb = "vrb2";
}

if (!defined($startDate)) {
    $startDate = ISO_date(today());
}

my $dbh = dbConnect("wpb-banner-prod");

my $SRC_ID = $BANNER_SOURCE_ID;

my $sccodes = join(",", @SCCODES);

my $query = qq {
    select
        cs.csrcsev_case_id as "CaseNumber",
        ct.ctrevnt_desc as "EventName",
        cs.csrcsev_evnt_code as "EventCode",
        cs.csrcsev_case_id as "UCN",
        cs.csrcsev_judge_pidm as "JudgeIdentifier",
        cs.csrcsev_csev_seq as "Sequence",
        s.spriden_last_name || ', ' || s.spriden_first_name as "JudgeName",
        to_char(cs.csrcsev_sched_date,'YYYY-MM-DD') as "Date",
        substr(cs.csrcsev_start_time,1,5) as "StartTime",
        substr(cs.csrcsev_end_time,1,5) as "EndTime",
        'N' as "Canceled",
        cd.cdbcase_division_id as "DivisionID",
        cd.cdbcase_desc as "CaseStyle"
    from
        csrcsev cs left outer join spriden s on (cs.csrcsev_judge_pidm = s.spriden_pidm),
        ctrevnt ct,
        cdbcase cd
    where
        csrcsev_evnt_code=ctrevnt_code
        and cdbcase_id = csrcsev_case_id
        and cdbcase_division_id is not null
        and cdbcase_division_id <> ' '
        and csrcsev_sched_date >= to_date(?,'YYYY-MM-DD')
        and s.spriden_change_ind is null
        and cdbcase_cort_code not in ($sccodes)
    order by
        csrcsev_sched_date desc
};

my %events;
getData(\%events, $query, $dbh, {valref => [$startDate], hashkey => 'DivisionID'});

foreach my $div (keys %events) {
    foreach my $event (@{$events{$div}}) {
        $query = qq {
            select
                cdrdoct_csev_seq
            from
                cdrdoct
            where
                cdrdoct_dtyp_code in ('EVCAN','EVERR','EVRST')
                and cdrdoct_csev_seq = ?
                and cdrdoct_case_id = ?
        };
        my $canc = getDataOne($query,$dbh,[$event->{'Sequence'}, $event->{'UCN'}]);
        
        if (defined($canc)) {
            undef($event);
            next;
        }
        
        if ($event->{'CaseNumber'} =~ /(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)/) {
            $event->{'CaseNumber'} = sprintf("%04d-%s-%06d", $1, $2, $3);
        }
    }
}

my %sorted;
sortExternalEvents(\%sorted, \%events);

$dbh->disconnect;

my $vdbh = dbConnect($vrb);

my %existing;
getVRBEvents(\%existing,$SRC_ID,$vdbh);

my %vrbSorted;
sortExternalEvents(\%vrbSorted,\%existing);

# Now that we have the existing records from VRB and the "official" records from the
# import source, do the work.
vrbCompareAndUpdate(\%vrbSorted,\%sorted,$SRC_ID,$vdbh);
