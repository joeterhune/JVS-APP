#!/usr/bin/perl -w

# This script is accessed through an ajax call and will return the tables used in case details
# to show linked cases

BEGIN {
    use lib $ENV{'PERL5LIB'};
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
);

use Showcase qw (
    getLinkedCases
    $db
);

use CGI;
use JSON;

my $info = new CGI;

my %params = $info->Vars;

my $caseid = $params{'caseid'};
my $casenum = $params{'casenum'};

my $dbh = dbConnect($db);
if (!defined($dbh)) {
    die "There was a problem connecting to the Showcase database. Please try again later."
}

my $schema = getDbSchema($db);

my %data;

$data{'linkedCases'} = [];
$data{'ucn'} = $casenum;

getLinkedCases($caseid, $dbh, $data{'linkedCases'}, $schema);
my $html = doTemplate(\%data, "$templateDir/casedetails", "scLinkedCases.tt", 0);

my %result;
$result{'status'} = "Success";
$result{'html'} = $html;
$result{'casenum'} = $casenum;
#$result{'casenum'} =~ s/^50-//g;

returnJson(\%result);
exit;