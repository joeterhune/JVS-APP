#!/usr/bin/perl -w

BEGIN {
    use lib "/usr/local/icms/bin";
}

use strict;

use CGI;

use CGI::Carp qw (
    fatalsToBrowser
);

use Common qw (
    dumpVar 
    getShowcaseDb
);

use DB_Functions qw (
    dbConnect
    getData
    getDataOne
    doQuery
    getDbSchema
);

my $db = getShowcaseDb();
my $dbh = dbConnect($db);
my $schema = getDbSchema($db);

my $info = new CGI;

#print $info->header;

my %params = $info->Vars;

my $ucn = $params{'ucn'};
#$ucn =~ s/-//g;

my $query = qq {
    select
        LastName,
        FirstName,
        CONVERT(varchar,DOB,101) AS DOB
    from
        $schema.vAllParties
    where
        ( PartyType = 'CHLD'
        OR PartyTypeDescription = 'CHILD (CJ)')
        and CaseNumber = '$ucn'
};

my $child = getDataOne($query, $dbh);

my $searchName = sprintf("%s, %s", $child->{'LastName'}, $child->{'FirstName'});
my $dob = $child->{'DOB'};

my %result;
$result{'searchName'} = $searchName;
$result{'DOB'} = $dob;

my $location = sprintf("/cgi-bin/case/search.cgi?name=%s&DOB=%s&fuzzyDOB=1&charges=on", $searchName, $dob);
print $info->redirect(-uri => $location);
exit;