#!/usr/bin/perl

# $Id: flag.cgi 2196 2015-08-22 12:51:51Z rhaney $

BEGIN {
    use lib $ENV{'PERL5LIB'};
}

use strict;
use CGI qw (fatalsToBrowser);

use Common qw (
	doTemplate
	dumpVar
	$templateDir
	today
	inArray
    returnJson
    createTab
    getUser
    getSession
    checkLoggedIn
);

use DB_Functions qw (
	dbConnect
	getData
	getSubscribedQueues
	getSharedQueues
	getQueues
);

checkLoggedIn();

my $info = new CGI;

my %params = $info->Vars;

my $user = getUser();
my $dbh = dbConnect("icms");

my @myqueues = ($user);
my @sharedqueues;

getSubscribedQueues($user, $dbh, \@myqueues);
getSharedQueues($user, $dbh, \@sharedqueues);
my @allqueues = (@myqueues, @sharedqueues);
my %queueItems;

my $wfcount = getQueues(\%queueItems, \@allqueues, $dbh);

# Get the case type from the case number
my $temp = $params{'ucn'};

createTab("Flags and Notes", "/casenotes/flag.cgi?ucn=" . $temp, 1, 1, "cases");
my $session = getSession();

my $casetype = '';
# modified 11/20/2018 jmt benchmark ucn used as casenum as casenum has spaces
if ($params{'ucn'} =~ /(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)/) {
	$casetype = $2;
}else{
	## Do this just in case we have the leading "50-" (which we will for Showcase)
	$temp =~ s/^58//g;
	my @pieces = split(" ",$temp);
	#my $casetype = $params{'caseType'};
	$casetype = $pieces[1];
}


my $query = qq {
	select
		flagtype as "FlagType",
		dscr as "FlagDesc",
		casetypes as "CaseTypes"
	from
		flagtypes
	order by
		dscr
};

my @flagTypes;
getData(\@flagTypes,$query,$dbh);

# Now determine which flags, based on the case type, we should show by default
foreach my $flagtype (@flagTypes) {
	# Split the casetype listing at space or commas
	my @pieces = split(/[\s+,]/, $flagtype->{'CaseTypes'});
	if ((inArray(\@pieces,"All",0)) || (inArray(\@pieces,$casetype,0))) {
		$flagtype->{'display'} = 1;
	} else {
		$flagtype->{'display'} = 0;
	}
}

# Get the flags that are already set
$query = qq {
	select
		f.flagtype as "FlagType",
		ft.dscr as "FlagDesc",
		f.date as "FlagDate",
		f.userid as "FlagUser",
		f.expires as "Expires"
	from
		flags f,
		flagtypes ft
	where
		casenum = ?
		and f.flagtype = ft.flagtype
};

my $querycase = $params{'ucn'};
# modified 11/20/2018 jmt benchmark ucn used as casenum as casenum has spaces instead of dashes
#if ($querycase =~ /(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)/) {
#    $querycase = sprintf("%04d-%s-%06d", $1, $2, $3);
#}

my @vals = ($querycase);
my @currentFlags;
getData(\@currentFlags, $query, $dbh, {valref => \@vals});

my %data;

$data{'currentFlags'} = \@currentFlags;
$data{'flagTypes'} = \@flagTypes;
$data{'ucn'} = $params{'ucn'};
$data{'division'} = $params{'division'};
$data{'today'} = today();
$data{'userid'} = getUser();

$data{'casetype'} = $casetype;
$data{'wfCount'} = $wfcount;
$data{'active'} = "cases";
$data{'tabs'} = $session->get('tabs');

print $info->header;

doTemplate(\%data, "$templateDir/top", "header.tt", 1);
doTemplate(\%data,"$templateDir/casenotes","flag.tt",1);
