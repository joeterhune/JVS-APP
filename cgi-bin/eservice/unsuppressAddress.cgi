#!/usr/bin/perl -w

BEGIN {
    use lib "$ENV{'PERL5LIB'}";
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
    delete from
        suppress_emails
    where
        casenum = ?
        and email_addr = ?
};

doQuery($query, $dbh, [$casenum, $email]);

my %response;

$response{'result'} = "Success";
$response{'email'} = $email;

my $json = JSON->new->allow_nonref;

print $info->header("application/json");
print $json->encode(\%response);

exit;