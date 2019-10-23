#!/usr/bin/perl

BEGIN {
	use lib "$ENV{'JVS_PERL5LIB'}";
}

use strict;
use Common qw (
	doTemplate
	$templateDir
	dumpVar
);

use DB_Functions qw (
	dbConnect
	getData
);

use CGI;
use CGI::Carp qw (fatalsToBrowser);

my $info = new CGI;

print $info->header();

my %params = $info->Vars;

my $query = qq {
	select
		casenum,
		seq,
		userid,
		DATE_FORMAT(date, '%m/%d/%Y') as date,
		note
	from
		casenotes
	where
		casenum = ?
};

my @casenotes;

my @vals = ($params{'ucn'});

my $dbh = dbConnect("icms");
getData(\@casenotes,$query,$dbh,{valref => \@vals});
$dbh->disconnect;

my %data;
$data{'notes'} = \@casenotes;
$data{'casenum'} = $params{'ucn'};

if (defined($params{'lev'})) {
	$data{'lev'} = $params{'lev'};
} else {
	$data{'lev'} = 4;
}

doTemplate(\%data,"$templateDir/casenotes","delnote.tt",1);
