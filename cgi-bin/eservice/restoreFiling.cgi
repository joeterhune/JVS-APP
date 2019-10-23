#!/usr/bin/perl

BEGIN {
    use lib "$ENV{'JVS_PERL5LIB'}";
}

use strict;

use JSON;
use DB_Functions qw (
    dbConnect
    doQuery
);

use CGI;

my $info = new CGI;

my %params = $info->Vars;

my $filingID = $params{'filingID'};
my $casenum = $params{'casenum'};
my $ignore = $params{'ignore'};

if (!defined($ignore)) {
    $ignore = 0;
}


if (defined($filingID) && defined($casenum)) {
    my $dbh = dbConnect("portal_info");
    my $query = qq {
        update
            portal_filings
        set
            status_ignore = ?
        where
            filing_id = ?
            and clerk_case_id = ?
    };
    doQuery($query, $dbh, [$ignore, $filingID, $casenum]);
}

my $json = JSON->new->allow_nonref;

my %response;
$response{'status'} = "Success";
$response{'filingid'} = $filingID;
$response{'casenum'} = $casenum;
$response{'user'} = $user;

print $info->header('application/json');
print $json->encode(\%response);
