#!/usr/bin/perl -w

BEGIN {
    use lib "$ENV{'PERL5LIB'}";
}

use strict;
use Common qw (
    dumpVar
);

use DB_Functions qw (
    dbConnect
    getData
    doQuery
    getDbSchema
);

use Showcase qw (
    $db
);


my $dbh = dbConnect($db);
my $schema = getDbSchema($db);

my $query = qq {
    select
        distinct(CourtRoom) as CourtRoom,
        CourtLocation
    from
        $schema.vCourtEvent with(nolock)
    where
        CourtEventDate >= GETDATE()
    order by
        CourtRoom
};


my @courtRooms;

getData(\@courtRooms, $query, $dbh);

$dbh->disconnect;

my $jdbh = dbConnect('judge-divs');
$jdbh->{'AutoCommit'} = 0;

foreach my $courtroom (@courtRooms) {
    $query = qq {
        insert into
            courtrooms
                (
                    courtroom,
                    courthouse
                )
            values
                (
                    ?,
                    ?
                )
            on duplicate key
            update courtroom = courtroom
    };
    doQuery($query, $jdbh, [$courtroom->{'CourtRoom'}, $courtroom->{'CourtLocation'}]);
}

$jdbh->commit;

$jdbh->disconnect;
