#!/usr/bin/perl -w

BEGIN {
    use lib "$ENV{'PERL5LIB'}";
}

use strict;

use DB_Functions qw (
    dbConnect
    doQuery
    getWatchList
    getEmailFromAD
);

use Common qw (
    returnJson
    getUser
);

use CGI;

my $info = new CGI;

my %params = $info->Vars;

my $casenum = $params{'casenum'};
my $user = getUser();

my $email = getEmailFromAD($user);

my $dbh = dbConnect("icms");
my $query = qq {
    delete from
        watchlist
    where
        casenum = ?
        and email = ?
};

doQuery($query, $dbh, [$casenum, $email]);

my $watchList = getWatchList($casenum, $user, $dbh);

my %result;
$result{'status'} = "Success";
$result{'html'} = $watchList;
$result{'action'} = "Removed";

returnJson(\%result);
