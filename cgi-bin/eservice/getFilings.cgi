#!/usr/bin/perl

BEGIN {
    use lib "$ENV{'PERL5LIB'}";
}

use strict;
use Common qw (
    dumpVar
    doTemplate
    $templateDir
    ISO_date
    US_date
    today
    getUser
);
use DB_Functions qw (
    dbConnect
    getData
    ldapLookup
);

use CGI;
use Date::Calc qw (Add_Delta_Days);
use JSON;

my $info = new CGI;

my %params = $info->Vars;

my $endDate;
my $startDate;

if (defined($params{'endDate'})) {
    $endDate = ISO_date($params{'endDate'});
} else {
    $endDate = ISO_date(today);
}


if (defined($params{'startDate'})) {
    $startDate = ISO_date($params{'startDate'});
} else {
    my ($year, $month, $day) = split("-", $endDate);
    my ($syear, $smonth, $sday) = Add_Delta_Days($year,$month,$day,-30);
    $startDate = sprintf("%04d-%02d-%02d", $syear, $smonth, $sday);
}

my $user = getUser();

my $ldapFilter = "(sAMAccountName=$user)";

my $userInfo = [];

ldapLookup($userInfo, $ldapFilter, undef, ['displayName','givenName','sn']);

my @filings;

my $query = qq {
    select
        pof.filing_id,
        clerk_case_id,
        pof.case_style,
        DATE_FORMAT(filing_date,'%m/%d/%Y') as filing_date,
        DATE_FORMAT(filing_date,'%h:%m:%s %p') as filing_time,
        CASE completion_date
            WHEN '0000-00-00 00:00:00' then null
            ELSE DATE_FORMAT(completion_date,'%m/%d/%Y') 
        END as completion_date, 
        CASE completion_date
            WHEN '0000-00-00 00:00:00' then null
            ELSE DATE_FORMAT(completion_date,'%h:%m:%s %p')
        END as completion_time, 
        filing_status,
        status_dscr,
        status_ignore,
        CASE WHEN (filing_status = 'Correction Queue' and status_ignore = 0) THEN 'pqueue'
            ELSE 'normal'
        END as class,
        portal_post_date,
        base64_attachment,
       	CASE
        	WHEN wf.portal_filing_id IS NOT NULL
        		THEN wf.doc_id
        	ELSE NULL
        END AS workflow_id
    from
        portal_info.portal_filings pof
    left outer join 
    	portal_info.pending_filings pef
    	on pef.filing_id = pof.filing_id
    left outer join
    	workflow wf
    	on wf.portal_filing_id = pof.filing_id	
    where
        user_id = ?
        and filing_date between '$startDate 00:00:00' and '$endDate 23:59:59'
    -- get pending queue filings regardless of date
    UNION
    select
        pof.filing_id,
        clerk_case_id,
        pof.case_style,
        DATE_FORMAT(filing_date,'%m/%d/%Y') as filing_date,
        DATE_FORMAT(filing_date,'%h:%m:%s %p') as filing_time,
        CASE completion_date
            WHEN '0000-00-00 00:00:00' then null
            ELSE DATE_FORMAT(completion_date,'%m/%d/%Y') 
        END as completion_date, 
        CASE completion_date
            WHEN '0000-00-00 00:00:00' then null
            ELSE DATE_FORMAT(completion_date,'%h:%m:%s %p')
        END as completion_time, 
        filing_status,
        status_dscr,
        status_ignore,
        CASE WHEN (filing_status = 'Correction Queue' and status_ignore = 0) THEN 'pqueue'
            ELSE 'normal'
        END as class,
        portal_post_date,
        base64_attachment,
        CASE
        	WHEN wf.portal_filing_id IS NOT NULL
        		THEN wf.doc_id
        	ELSE NULL
        END AS workflow_id
    from
        portal_info.portal_filings pof
    left outer join 
    	portal_info.pending_filings pef
    	on pef.filing_id = pof.filing_id
    left outer join
    	workflow wf
    	on wf.portal_filing_id = pof.filing_id	
    where
        user_id = ?
        and filing_status = 'Correction Queue'
    order by
        FIELD(filing_status,'Pending Filing','Correction Queue') desc,
        filing_date desc
};

my $dbh = dbConnect("icms");

getData(\@filings, $query, $dbh, {valref => [$user,$user]});

foreach my $filing (@filings) {
    if ($filing->{'class'} eq 'pqueue') {
        if (!defined($filing->{'portal_post_date'})) {
            # Remove Pending Queue items that have no portal_post_date, because we can't re-file them anyway
            undef $filing;
            next;
        }
        
        $filing->{'canResubmit'} = 1;
    }
    if (defined($filing->{'workflow_id'}) && ($filing->{'workflow_id'} ne "")) {
        $filing->{'fromWorkflow'} = 1;
    }
}

my %data;
$data{'startDate'} = US_date($startDate);
$data{'endDate'} = US_date($endDate);
$data{'userInfo'} = $userInfo->[0];

$data{'filings'} = \@filings;

my %result;
$result{'status'} = 'Success';
$result{'html'} = doTemplate(\%data, $templateDir, "eservice/getFilings.tt", 0);
#$result{'html'} = $query;

my $json = JSON->new->allow_nonref;
print $info->header('application/json');

print $json->encode(\%result);
exit;