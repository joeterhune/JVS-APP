#!/usr/bin/perl -w

BEGIN {
    use lib "$ENV{'PERL5LIB'}";
}

use strict;

use DB_Functions qw (
    dbConnect
    doQuery
    getWatchList
    getCaseInfo
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

my $caseinfo = getCaseInfo($casenum);

my $dbh = dbConnect("icms");
my $query = qq {
    insert into
        watchlist (
            casenum,
            division_id,
            email,
            casestyle
        ) values (?,?,?,?)
};

doQuery($query, $dbh, [$casenum, $caseinfo->{'DivisionID'}, $email, $caseinfo->{'CaseStyle'}]);

my $watchList = getWatchList($casenum, $user, $dbh);

my %result;
$result{'status'} = "Success";
$result{'html'} = $watchList;
$result{'action'} = "Added";

returnJson(\%result);