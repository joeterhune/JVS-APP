#!/usr/bin/perl -w

BEGIN {
    use lib "$ENV{'JVS_PERL5LIB'}";
}

use strict;

use Common qw (
    dumpVar
    returnJson
);

use XML::Simple;

use DB_Functions qw (
    dbConnect
    getData
    getDbSchema
);

use Showcase qw (
    $db
);

use JSON;

use CGI;

my $info = new CGI;

my %params = $info->Vars;

my $eventString = $params{'eventids'};

my $dbh = dbConnect($db);
my $schema = getDbSchema($db);

my $query = qq {
    select
        CourtEventId as EID,
        CASE
            WHEN InCourtProcessingStartTime is null THEN 'Pending'
            WHEN InCourtProcessingEndTime is null THEN 'In Process'
            ELSE 'Processed'
        END as Status
    from
        $schema.vCourtEvent with(nolock)
    where
        CourtEventId in ($eventString)
};

my %status;
my @status;
getData(\@status, $query, $dbh);

foreach my $status (@status) {
    $status->{'ICP'} = $status->{'Status'};
    $status->{'ICP'} =~ s/\s+//g;
}

my %result;
returnJson(\@status);
exit;
