#!/usr/bin/perl -w

BEGIN {
    use lib "$ENV{'PERL5LIB'}";
}

use strict;
use Common qw (
    dumpVar
    doTemplate
    $templateDir
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

use CGI;

my $info = new CGI;

my %params = $info->Vars;

my $listType = $params{'type'};

my $user = getUser();
my $fdbh = dbConnect("icms");

my @myqueues = ($user);
my @sharedqueues;

getSubscribedQueues($user, $fdbh, \@myqueues);
getSharedQueues($user, $fdbh, \@sharedqueues);
my @allqueues = (@myqueues, @sharedqueues);
my %queueItems;

my $wfcount = getQueues(\%queueItems, \@allqueues, $fdbh);

my %data;

my @typelist;

if ($listType eq 'crim') {
    $data{'type'} = 'Criminal';
    @typelist = ('Circuit Criminal', 'Mental Health Court','County Criminal');
} elsif ($listType eq 'civ') {
    $data{'type'} = 'Civil';
    @typelist = ('Circuit Civil','Foreclosure','County Civil');
}  elsif ($listType eq 'fam') {
    $listType = 'civ';
    $data{'type'} = 'Family';
    @typelist = ('Family','Unified Family Court');
} elsif ($listType eq 'juv') {
    $data{'type'} = 'Juvenile';
    @typelist = ('Juvenile');
} elsif ($listType eq 'pro') {
    $data{'type'} = 'Probate';
    @typelist = ('Probate');
}

createTab("All " . $data{'type'} . " Divisions", "/cgi-bin/case/alldivs.cgi?type=" . $listType, 1, 1, "index");
my $session = getSession();

$data{'pathpart'} = $listType;

print $info->header;

my $dbh = dbConnect("judge-divs");

my $query = qq {
    select
        division_id as DivisionID,
        CASE division_type
            WHEN 'Misdemeanor' THEN 'County Criminal'
            WHEN 'VA' then 'County Criminal'
            WHEN 'Felony' THEN 'Circuit Criminal'
            WHEN 'Mental Health' THEN 'Mental Health Court'
            WHEN 'UFC Linked Cases' THEN 'Unified Family Court'
            WHEN 'UFC Transferred Cases' THEN 'Unified Family Court'
            WHEN 'UFC Judicial Memo' THEN 'Unified Family Court'
        ELSE division_type
        END as CourtType
    from
        divisions
    where
        division_id not in ('CFTD')
        and show_icms_list = 1
};

my %divisions;
getData(\%divisions, $query, $dbh, {hashkey => 'CourtType'});

$data{'divlist'} = [];

foreach my $type (@typelist) {
    my %temp;
    $temp{'type'} = $type;
    $temp{'divs'} = $divisions{$type};
    push(@{$data{'divlist'}}, \%temp);
}

$data{'wfCount'} = $wfcount;
$data{'active'} = "index";
$data{'tabs'} = $session->get('tabs');

doTemplate(\%data, "$templateDir/top", "header.tt", 1);
doTemplate(\%data, $templateDir, "allDivs.tt", 1);
