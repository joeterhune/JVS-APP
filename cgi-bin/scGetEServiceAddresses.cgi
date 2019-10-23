#!/usr/bin/perl -w

# This script is accessed through an ajax call and will return the tables used in case details
# to show booking history for the defendant

BEGIN {
    use lib "$ENV{'JVS_PERL5LIB'}";
}

use strict;
use Common qw (
    doTemplate
    $templateDir
);

use DB_Functions qw (
    dbConnect
    getData
    getDbSchema
);

use Showcase qw (
    getEServiceAddresses
    $db
);

use CGI;
use JSON;

my $info = new CGI;

my %params = $info->Vars;

print $info->header;

my $casenum = $params{'casenum'};
my $caseid = $params{'caseid'};

my $dbh = dbConnect($db);
if (!defined($dbh)) {
    die "There was a problem connecting to the Showcase database. Please try again later."
}

my $schema = getDbSchema($db);

my %data;

$data{'ucn'} = $casenum;
#$data{'ucn'} =~ s/^50-//g;

$data{'otherCases'} = [];

my $addresses;
$addresses = getEServiceAddresses($casenum, $caseid);

my %result;
$result{'status'} = "Success";
$result{'casenum'} = $casenum;
#$result{'casenum'} =~ s/^50-//g;
$result{'addresses'} = $addresses;

my $json = JSON->new->allow_nonref;

print $info->header;
print $json->encode(\%result);
exit;