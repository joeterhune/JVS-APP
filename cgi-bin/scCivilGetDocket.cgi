#!/usr/bin/perl -w

# This script is accessed through an ajax call and will return the tables used in case details
# to show booking history for the defendant

BEGIN {
    use lib "$ENV{'JVS_PERL5LIB'}";
}

use strict;
use Common qw (
    dumpVar
    doTemplate
    $templateDir
    returnJson
    getShowcaseDb
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
use XML::Simple;
use Showcase qw (
    getDockets
);

our $db = getShowcaseDb();

use JSON;

use CGI;

my $info = new CGI;

my %params = $info->Vars;

my $casenum = $params{'casenum'};
my $caseid = $params{'caseid'};

my $casetype = $params{'casetype'};

my $dbh = dbConnect($db);
my $schema = getDbSchema($db);

my $conf = XMLin("$ENV{'JVS_ROOT'}/conf/ICMS.xml");
my $tifgroup = $conf->{'ldapConfig'}->{'tifgroup'};

if (!defined($dbh)) {
    print $info->header;
    die "There was a problem connecting to the Showcase database. Please try again later."
}

if (!defined($casetype)) {
    # It should have been passed in, but just in case
    my $query = qq {
        SELECT
            CaseType
        FROM
            $schema.vCase
        WHERE
            CaseID = ?
    };
    my $rec = getDataOne($query, $dbh, [$caseid]);
    $casetype = $rec->{'CaseType'};
}

my %data;
$data{'dockets'} = [];
$data{'ucn'} = $casenum;
#$data{'ucn'} =~ s/^50-//g;
getDockets($casenum, $dbh, $data{'dockets'}, $schema, $caseid);

my $initDockets = [];
getInitDockets($casetype,$initDockets);

my $json = JSON->new->allow_nonref;
$data{'initDockets'} = $json->encode($initDockets);

$data{'showTif'} = inGroup(getUser(), $tifgroup);
#$data{'casenum'} = $casenum;
#$data{'ucn'} = $casenum;
$data{'CaseID'} = $caseid;

my $html = doTemplate(\%data, "$templateDir/casedetails", "scCivilDocket.tt", 0);

my %result;
$result{'status'} = "Success";
$result{'html'} = $html;
$result{'casenum'} = $casenum;
#$result{'casenum'} =~ s/^50-//g;

returnJson(\%result);
exit;

