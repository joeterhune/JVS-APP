#!/usr/bin/perl -w

# This script is accessed through an ajax call and will return the tables used in case details
# to show booking history for the defendant

BEGIN {
    use lib "$ENV{'PERL5LIB'}";
}

use strict;
use Common qw (
    dumpVar
    doTemplate
    $templateDir
    returnJson
);

use DB_Functions qw (
    dbConnect
    getData
    getDbSchema
    inGroup
    getInitDockets
    getDataOne
);

use Banner qw (
    getDockets
    getExtCaseId
);

use JSON;

use CGI;

my $info = new CGI;

my %params = $info->Vars;

my $casenum = $params{'casenum'};

my $casetype = $params{'casetype'};

my $dbh = dbConnect("wpb-banner-prod");
if (!defined($dbh)) {
    print $info->header;
    die "There was a problem connecting to the Showcase database. Please try again later."
}

if (!defined($casetype)) {
    # It should have been passed in, but just in case
    my $query = qq {
        select
            cdbcase_ctyp_code as "CaseType"
        from
            cdbcase
        where
            cdbcase_id = ?
    };
    my $rec = getDataOne($query, $dbh, [$casenum]);
    $casetype = $rec->{'CaseType'};
}

my %data;
$data{'dockets'} = [];
$data{'extcaseid'} = getExtCaseId($dbh, $casenum);
getDockets($casenum, $dbh, $data{'dockets'});

my $initDockets = [];
getInitDockets($casetype,$initDockets);

my $json = JSON->new->allow_nonref;
$data{'initDockets'} = $json->encode($initDockets);

#$data{'showTif'} = inGroup($info->remote_user, "CAD-ICMS-TIF");
$data{'casenum'} = $casenum;
$data{'ucn'} = $casenum;

my $html = doTemplate(\%data, "$templateDir/casedetails", "bannerDocket.tt", 0);

my %result;
$result{'status'} = "Success";
$result{'html'} = $html;
$result{'casenum'} = $casenum;

returnJson(\%result);
exit;

