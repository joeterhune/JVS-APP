#!/usr/bin/perl -w

# This script is accessed through an ajax call and will return the tables used in case details
# to show booking history for the defendant

BEGIN {
    use lib $ENV{'PERL5LIB'};
}

use strict;
use Common qw (
    doTemplate
    $templateDir
    returnJson
    getUser
);

use DB_Functions qw (
    dbConnect
    getData
    getDbSchema
    inGroup
    getInitDockets
    getDataOne
);

use Showcase qw (
    getDockets
    $db
);

use JSON;

use CGI;

my $info = new CGI;

my %params = $info->Vars;

my $casenum = $params{'casenum'};
my $casetype = $params{'casetype'};
my $caseid = $params{'caseid'};

my $dbh = dbConnect($db);
if (!defined($dbh)) {
    print $info->header;
    die "There was a problem connecting to the Showcase database. Please try again later."
}

my $schema = getDbSchema($db);

if (!defined($casetype)) {
    # It should have been passed in, but just in case
    my $query = qq {
        select
            CaseType
        from
            vCase with(nolock)
        where
            CaseID = ?
    };
    my $rec = getDataOne($query, $dbh, [$caseid]);
    $casetype = $rec->{'CaseType'};
}


my %data;
$data{'dockets'} = [];
$data{'ucn'} = $casenum;
#$data{'ucn'} =~ s/^50-//g;
$data{'CaseID'} = $caseid;

$data{'showTif'} = inGroup(getUser(), "CAD-ICMS-TIF");

getDockets($casenum, $dbh, $data{'dockets'}, $schema, $caseid);

my $initDockets = [];
getInitDockets($casetype,$initDockets);

my $json = JSON->new->allow_nonref;
$data{'initDockets'} = $json->encode($initDockets);

my $html = doTemplate(\%data, "$templateDir/casedetails", "scDocket.tt", 0);

my %result;
$result{'status'} = "Success";
$result{'html'} = $html;
$result{'casenum'} = $casenum;
#$result{'casenum'} =~ s/^50-//g;

returnJson(\%result);
exit;
