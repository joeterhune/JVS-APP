#!/usr/bin/perl -w

BEGIN {
	use lib "/usr/local/icms/bin";
}

use strict;

use Common qw(
    dumpVar  
);

use DB_Functions qw(
    dbConnect
    getData
    doQuery
    getDbSchema
);

use Showcase qw (
    $db
);

use Getopt::Long;

my $vrb;
GetOptions("d:s" => \$vrb);

if (!defined($vrb)) {
    die "Usage: $0 -d <vrb instance>\n\n";
}

my $vdbh = dbConnect($vrb);

if (!defined($vdbh)) {
    die "Unable to establish DB connection for '$vrb'.\n\n";
}

my $sdbh = dbConnect($db);
my $schema = getDbSchema($db);

my $query = qq {
    select
        CourtEventType
    from
        $schema.vewCourtEventType
};
my @scevnts;
getData(\@scevnts, $query, $sdbh);

foreach my $eventType (@scevnts) {
    my ($code, $junk, $desc) = split(/\s+/, $eventType->{'CourtEventType'});
    
    $query = qq {
        update
            event_types
        set
            event_type_code = ?
        where
            event_type_desc = ?
    };
    doQuery($query,$vdbh,[$code, $desc]);
};

exit;