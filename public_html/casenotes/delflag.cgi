#!/usr/bin/perl

BEGIN {
	use lib "/usr/local/icms/bin";
}

use strict;
use CGI qw (fatalsToBrowser);
use Common qw (
	doTemplate
	dumpVar
	$templateDir
    returnJson
);
use DB_Functions qw (
	dbConnect
	getData
);

my $info = new CGI;

my %params = $info->Vars;

my $query = qq {
	select
		f.flagtype as "FlagType",
		ft.dscr as "FlagDesc",
		DATE_FORMAT(f.date, '%m/%d/%Y') as "FlagDate",
		f.idnum as "Seq",
		DATE_FORMAT(f.expires, '%m/%d/%Y') as "Expires"
	from
		flags f,
		flagtypes ft
	where
		f.casenum = ?
		and f.flagtype = ft.flagtype
	order by
		ft.dscr
};
my @vals = ($params{'ucn'});
my @flags;
my $dbh = dbConnect("icms");
getData(\@flags,$query,$dbh,{valref => \@vals});
$dbh->disconnect;

my %data;

$data{'flags'} = \@flags;
$data{'ucn'} = $params{'ucn'};

if (defined($params{'lev'})) {
	$data{'lev'} = $params{'lev'};
} else {
	$data{'lev'} = 4;
}


my %result;
$result{'html'} = doTemplate(\%data,"$templateDir/casenotes","delflag.tt",0);

returnJson(\%result);