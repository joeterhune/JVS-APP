#!/usr/bin/perl -w

BEGIN {
    use lib "$ENV{'JVS_PERL5LIB'}";
}

use strict;
use Common qw (
    getArrayPieces
    dumpVar
);
use DB_Functions qw (
    dbConnect
    getData
    getDataOne
    doQuery
    getDbSchema
);
use Showcase qw (
    $db
);
use POSIX qw (
    strftime
);

use VRB qw (
    processDockets
    processEvents
    processBannerParties
    processShowcaseParties
    getBannerDockets
    getBannerParties
    getBannerEvents
    getShowcaseParties
    getShowcaseDockets
    getShowcaseEvents
);

use Getopt::Long;

my $vrb = "rich-vrb";

GetOptions("d=s" => \$vrb);

my $vdbh = dbConnect($vrb);
my $bdbh = dbConnect("wpb-banner-rpt");
my $sdbh = dbConnect($db);

doQuery("set foreign_key_checks=0", $vdbh);

# First get the distinct Banner cases
my $query = qq {
    select
        distinct(case_num) as CaseNumber
    from
        event_cases
    where
        case_num not like '58-%'
    order by
        case_num
};

my @bannerCases;
my $caseList = [];
#
getData($caseList, $query, $vdbh);
foreach my $case (@{$caseList}) {
    my $bcase = $case->{'CaseNumber'};
    $bcase =~ s/-//g;
    push(@bannerCases, $bcase);
}

my $count = 0;
my $perQuery = 1000;

# To keep track of which PIDMs we've seen so we don't insert/update multiple times on the run
my %seenPIDMs;
my %seenDockets;
my %seenEvents;

my $now = strftime "%Y-%m-%d %H:%M:%S", localtime;

$vdbh->begin_work();

# Find the time of the last imports (if any)
$query = qq {
    select
        import_type,
        import_time
    from
        last_imports
    where
        import_type in ('case_events','case_dockets','case_parties');
};
my %lastImports;
getData(\%lastImports, $query, $vdbh, {hashkey => 'import_type', 'flatten' => 1});

while ($count < scalar(@bannerCases)) {
    my @temp;
    my $result;
    getArrayPieces(\@bannerCases, $count, $perQuery, \@temp, 1);
    
    # Process dockets for this group
    my $dockets = {};
    
    print "Retrieving dockets from Banner...\n";
    getBannerDockets($dockets, $bdbh, \@temp);
    processDockets($dockets, \%seenDockets, $vdbh);
    print "Added dockets...\n";
    
    # And parties for this group    

    my $parties = {};
    print "Retrieving parties from Banner...\n";
    getBannerParties($parties, $bdbh, \@temp);
    processBannerParties($parties, \%seenPIDMs, $vdbh);
    print "Added parties...\n\n";
    
    
    # And events for this group
    my $events = {};
    
    print "Retrieving events from Banner...\n";
    getBannerEvents($events, $bdbh, \@temp);
    print "Adding events to VRB...\n";
    processEvents($events, \%seenEvents, $vdbh);
    print "Added events...\n";
    
    $count += $perQuery;
    print "Completed $count...\n";
}


# And then Showcase
$query = qq {
    select
        distinct(case_num) as CaseNumber
    from
        event_cases
    where
        case_num like '58-%'
    order by
        case_num
};



my @showcaseCases;
$caseList = [];

getData($caseList, $query, $vdbh);
foreach my $case (@{$caseList}) {
    push(@showcaseCases, $case->{'CaseNumber'});
}

my $schema = getDbSchema($db);

$count = 0;
$perQuery = 1000;

while ($count < scalar(@showcaseCases)) {
    my @temp;
    my $result;
    getArrayPieces(\@showcaseCases, $count, $perQuery, \@temp, 1);
    
    my $inString = join(",", @temp);
    
    # Process dockets for this group
    my $dockets = {};
    print "Retrieving dockets from Showcase...\n";
    getShowcaseDockets($dockets, $sdbh, $schema, \@temp);
    print "Adding dockets to VRB...\n";
    processDockets($dockets, \%seenDockets, $vdbh);
    print "Added dockets.\n\n";
    
    my $parties = {};
    print "Retrieving parties from Showcase...\n";
    getShowcaseParties($parties, $sdbh, $schema, \@temp);
    print "Adding parties to VRB...\n";
    processShowcaseParties($parties, \%seenPIDMs, $vdbh);
    print "Added parties...\n\n";
    
    # And events for this group
    my $events = {}; 
    print "Retrieving events from Showcase...\n";
    getShowcaseEvents($events, $sdbh, $schema, \@temp);
    print "Adding events to VRB...\n";
    processEvents($events, \%seenEvents, $vdbh);
    print "Added events...\n\n";
    
    $count += $perQuery;
    
    print "Completed $count...\n\n";
}


$query = qq {
    replace into
        last_imports
    values
        ('case_events','$now'),
        ('case_dockets','$now'),
        ('case_parties','$now')
};

doQuery($query,$vdbh);

$vdbh->commit;

exit;

