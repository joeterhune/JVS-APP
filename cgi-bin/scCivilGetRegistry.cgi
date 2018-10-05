#!/usr/bin/perl -w

# This script is accessed through an ajax call and will return the tables used in case details
# to show booking history for the defendant

BEGIN {
    use lib "/usr/local/icms/bin";
}

use strict;
use Common qw (
    doTemplate
    $templateDir
    returnJson
);

use DB_Functions qw (
    dbConnect
    getData
    getDbSchema
    inGroup
    getDataOne
);

use Showcase qw (
    getRegistry
    $db
);

use JSON;

use CGI;

my $info = new CGI;

my %params = $info->Vars;

my $casenum = $params{'casenum'};
my $caseid = $params{'caseid'};

my $dbh = dbConnect($db);
if (!defined($dbh)) {
    die "There was a problem connecting to the Showcase database. Please try again later."
}

my $schema = getDbSchema($db);

my %data;
$data{'registry'} = [];

getRegistry($caseid, $dbh, $data{'registry'}, $schema);

my $json = JSON->new->allow_nonref;

$data{'CaseID'} = $caseid;

my $html = doTemplate(\%data, "$templateDir/casedetails", "scCivilRegistry.tt", 0);

my %result;
$result{'status'} = "Success";
$result{'html'} = $html;
$result{'casenum'} = $casenum;
#$result{'casenum'} =~ s/^50-//g;

returnJson(\%result);
exit;
