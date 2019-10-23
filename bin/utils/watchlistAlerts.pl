#!/usr/bin/perl -w

BEGIN {
    use lib "$ENV{'JVS_PERL5LIB'}/";
}

use strict;

use DB_Functions qw (
    getData
    dbConnect
    getLastRun
    getWatchCases
    getDbSchema
    doQuery
);

use Common qw (
    dumpVar
    getArrayPieces
    timeStamp
    sendMessage
    getConfig
    doTemplate
    $templateDir
);

use Showcase qw (
    $db
    getSCCaseNumber
);

my $dbh = dbConnect("icms");

my $now = timeStamp();

my $lastrun = getLastRun("watchlistalert", $dbh, $now);

my %watchlist;

getWatchCases(\%watchlist, $dbh);

# Build separate lists of Showcase cases
my @scCases;

foreach my $casenum (sort keys %watchlist) {

	if ($casenum =~ /(\d\d)-(\d\d\d\d)-(\D\D)-(\d\d\d\d\d\d)-(\D\D\D\D)-(\D\D)/) {
		push(@scCases, $casenum)
	}
	else{
		my $new_casenum = getSCCaseNumber($casenum);
		
		my $cleanup = qq{
			UPDATE 
				watchlist
			SET 
				casenum = ?
			WHERE 
				casenum = ?
		};
		
		doQuery($cleanup, $dbh, [$new_casenum, $casenum]);
		push(@scCases, $new_casenum)
	}

	
}

my %newFilings;
my $count = 0;
my $perQuery = 100;

# And then for Showcase
my $sdbh = dbConnect($db);
my $schema = getDbSchema($db);

$count = 0;
while ($count < scalar(@scCases)) {
    my @temp;
    getArrayPieces(\@scCases, $count, $perQuery, \@temp, 1);
    
    my $inString = join(",", @temp);
    
    my $query = qq {
        select
            CaseNumber,
            DocketCode,
            DocketDescription
        from
            $schema.vDocket with(nolock)
        where
            EnteredDate >= ?
            and EnteredDate <= ?
            and CaseNumber in ($inString)
    };
    
    getData(\%newFilings, $query, $sdbh, {valref => [$lastrun, $now], hashkey => 'CaseNumber'});
    
    $count += $perQuery;
}

$sdbh->disconnect;

if (!scalar(keys %newFilings)) {
    print "Nothing to do.\n";
    exit;
}

my $config = getConfig("$ENV{'JVS_ROOT'}/conf/ICMS.xml");

my $baseURL = $config->{'baseURLSearch'};

# Ok, now that we know what's been filed, send the alerts.
foreach my $casenum (sort keys %newFilings) {
    my %data;
    $data{'baseURL'} = $baseURL;
    $data{'CaseNumber'} = $casenum;
    $data{'docs'} = $newFilings{$casenum};
    my $subject = "Case Watchlist Alert - Case $casenum\n";
    my $mailList = $watchlist{$casenum};
    
    foreach my $rec (@{$mailList}) {
        my %recip = (
            'email_addr' => $rec->{'Email'}
        );
        
        my %sender = (
            'fullname' => 'Web Help',
            'email_addr' => 'webhelp@jud12.flcourts.org'
        );
        
        $data{'icms_user'} = $rec->{'icms_user'};
        
        my $msgBody = doTemplate(\%data, "$templateDir/watchlist", "watchlist-email.tt", 0);
        
        sendMessage([\%recip], \%sender, undef, $subject, $msgBody, undef, 0, 0);
    }
}