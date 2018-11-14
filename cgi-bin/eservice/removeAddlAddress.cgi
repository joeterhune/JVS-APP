#!/usr/bin/perl -w

BEGIN {
    use lib "$ENV{'PERL5LIB'}";
}

use strict;

use DB_Functions qw (
    dbConnect
    doQuery
);

use CGI;
use XML::Simple;
use Common qw (
    returnJson
);

my $info = new CGI;

my %params = $info->Vars;

my $casenum = $params{'casenum'};
my $email = $params{'email'};

my $dbh = dbConnect("ols");

my $query = qq {
    delete from
        reuse_emails
    where
        casenum = ?
        and email_addr = ?
};

doQuery($query, $dbh, [$casenum, $email]);

my %response;

$response{'result'} = "Success";
$response{'email'} = $email;
$response{'tab'} = sprintf("case-%s-eservice", $casenum);

returnJson(\%response);
exit;
