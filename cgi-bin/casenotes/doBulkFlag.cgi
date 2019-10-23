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
use Casenotes qw (
    calcExpire  
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

my $expiration = calcExpire(\%params);

my @cases = split(",", $params{'cases'});
my $flagnum = $params{'flags'};

my $today = ISO_date(today());

my $dbh = dbConnect("icms");

# Make it a transaction!
$dbh->begin_work;

my %result;
$result{'UpdateCount'} = 0;
$result{'Completed'} = [];

foreach my $rec (@cases) {
    my ($case, $div) = split(/\|/, $rec);
    my $query = qq {
        insert into
            flags (
                casenum, flagtype, userid, date, division, active, expires
            ) values (
                ?, ?, ?, ?, ?, ?, ?
            )
    };
    doQuery($query, $dbh, [$case, $flagnum, $user, $today, $div, 1, $expiration]);
    push(@{$result{'Completed'}}, $case);
    $result{'UpdateCount'}++
}

$dbh->commit;

my $json_text = JSON->new->ascii->pretty->encode(\%result);
print $json_text;