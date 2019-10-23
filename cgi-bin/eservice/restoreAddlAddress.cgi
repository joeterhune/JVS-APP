#!/usr/bin/perl -w

BEGIN {
    use lib "$ENV{'JVS_PERL5LIB'}";
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

my $dbh = dbConnect("eservice");

my $query = qq {
    insert into
        reuse_emails (
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
$response{'tab'} = sprintf("case-%s-eservice", $casenum);

returnJson(\%response);
