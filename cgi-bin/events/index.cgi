#!/usr/bin/perl

BEGIN {
    use lib "$ENV{'PERL5LIB'}";
}

use strict;
use CGI;
use Common qw (
    $templateDir
    doTemplate
    dumpVar
    getUser
);
use DB_Functions qw (
    ldapLookup
    getDivsLDAP
);

my $info = new CGI;

print $info->header();

my $user = getUser();

my @divs;
getDivsLDAP(\@divs, $user);

my %data;

if (!scalar(@divs)) {
	$data{'title'} = "Not Authorized";
	doTemplate(\%data,"$templateDir/events","notAuthorized.tt",1);
	exit;
}

my $divs = join(",", @divs);

$data{'title'} = "Case Scheduling";
$data{'divs'} = $divs;
$data{'user'} = $user;
doTemplate(\%data,"$templateDir/events", "index.tt",1);
exit;


