#!/usr/bin/perl -w

BEGIN {
    use lib "/usr/local/icms/bin";
}

use strict;

use DB_Functions qw (
    dbConnect
    doQuery
);
use Common qw (
    dumpVar
);

use CGI;
use JSON;

my $info = new CGI;

my %params = $info->Vars;

my $casenum = $params{'casenum'};
my $email = $params{'email'};

my $dbh = dbConnect("eservice");

my $query = qq {
    replace into
        suppress_emails (
            casenum,
            email_addr
        )
    values (
        ?,?
    )
};

doQuery($query, $dbh, [$casenum, $email]);

my %response;

$response{'result'} = "Success";
$response{'email'} = $email;

my $json = JSON->new->allow_nonref;

print $info->header("application/json");
print $json->encode(\%response);

exit;