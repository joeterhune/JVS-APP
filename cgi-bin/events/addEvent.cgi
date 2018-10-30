#!/usr/bin/perl

BEGIN {
	use lib "$ENV{'PERL5LIB'}";
}

use strict;
use CGI;
use Common qw (
	doTemplate
	dumpVar
	$templateDir
);

use DB_Functions qw (
	dbConnect
	doQuery
);

my $info = new CGI;

my %params = $info->Vars;

print $info->header();

my %data;

doTemplate(\%data,"$templateDir/events","addEvent.tt",1);
exit;
