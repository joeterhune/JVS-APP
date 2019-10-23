#!/usr/bin/perl -w

BEGIN {
    use lib "$ENV{'JVS_PERL5LIB'}";
}

use strict;

use Common qw (
    dumpVar
    getArrayPieces
    today
    ISO_date
    getUser
);
use DB_Functions qw (
    dbConnect
    doQuery
    inGroup
);

use JSON;
use CGI;
use XML::Simple;
my $info = new CGI;

my $user = getUser();
############### Added 04/17/2019 jmt security from conf 
my $conf = XMLin("$ENV{'JVS_ROOT'}/conf/ICMS.xml");
my $notesGroup = $conf->{'ldapConfig'}->{'notesgroup'};
if (!inGroup($user, $notesGroup)) {
    print $info->header;
    print "You do not have rights to use this function.\n";
    exit;
}

print $info->header('application/json');

my %params = $info->Vars;

my @inCases = split(",", $params{'cases'});

my @cases;
foreach my $case (@inCases) {
    my ($casenum, $junk) = split(/\|/, $case, 2);
    push(@cases,$casenum);
}

my $flagnum = $params{'flags'};

my $today = ISO_date(today());

my $dbh = dbConnect("icms");

# Make it a transaction!
$dbh->begin_work;

my %result;
$result{'UpdateCount'} = 0;
$result{'Completed'} = [];

my $count = 0;
my $perQuery = 100;

while ($count < scalar(@cases)) {
    my @temp;
    my @utemp;
    getArrayPieces(\@cases, $count, $perQuery, \@temp, 1);
    getArrayPieces(\@cases, $count, $perQuery, \@utemp, 0);
    my $inString = join(",", @temp);
    
    my $query = qq {
        delete from
            flags
        where
            flagtype = ?
            and casenum in ($inString);
    };
    
    my $done = doQuery($query, $dbh, [$flagnum]);
    $result{'UpdateCount'} += $done;
    
    # @utemp is the same as @temp. but the case numbers aren't quoted.
    push(@{$result{'Completed'}}, @utemp);
    
    $count += $perQuery;
}

$dbh->commit;

my $json_text = JSON->new->ascii->pretty->encode(\%result);
print $json_text;