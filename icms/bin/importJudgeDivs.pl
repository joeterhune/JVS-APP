#!/usr/bin/perl

BEGIN {
    use lib "/usr/local/icms/bin";
}

use strict;
use Common qw (
    dumpVar
);
use DB_Functions qw (
    dbConnect
    getData
    getDataOne
    doQuery
);

my $infile = "/usr/local/icms/etc/judgepage.conf";

open(INFILE,$infile) ||
    die "Can't open '$infile' for reading: $!\n\n";

my $judge_drop = "drop table if exists judges_new";
my $jd_drop = "drop table if exists judge_divisions_new";

my $judge_create = qq {
    CREATE TABLE `judges_new` (
        `judge_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
        `last_name` char(30) NOT NULL,
        `first_name` char(30) NOT NULL,
        `middle_name` char(30) NOT NULL,
        `suffix` char(5) NOT NULL,
        PRIMARY KEY (`judge_id`),
        UNIQUE KEY `name_unique_idx` (`first_name`,`middle_name`,`last_name`,`suffix`) USING BTREE
    ) ENGINE = InnoDB
};

my $judge_divs_create = qq {
    CREATE TABLE `judge_divisions_new` (
        `division_id` char(6) NOT NULL,
        `judge_id` smallint(5) unsigned NOT NULL,
        KEY `division_id` (`division_id`),
        KEY `judge_id` (`judge_id`)
    ) ENGINE=InnoDB
};


my %judgeDivs;
while (my $line = <INFILE>){
    chomp ($line);
    my ($name, $div, $type) = split("~", $line);

    # Compress whitespace
    $name =~ s/\s+/ /g;

    my ($last, $first, $middle) = split(/\s+/, $name);
    $last =~ s/,$//g;
    if (!defined($middle)) {
        $middle = "";
    }
    
    if (!defined($judgeDivs{$name})) {
        # Create a has ref for the judge if he doesn't exist.
        $judgeDivs{$name} = {
                             last_name => $last,
                             first_name => $first,
                             middle_name => $middle
                             };
        $judgeDivs{$name}->{'Divs'} = [];
    }
    push (@{$judgeDivs{$name}->{'Divs'}}, $div);
}

my $dbh = dbConnect("judge-divs");
$dbh->{AutoCommit} = 0;

# Create new tables
doQuery($judge_drop,$dbh);
doQuery($jd_drop,$dbh);
doQuery($judge_create, $dbh);
doQuery($judge_divs_create, $dbh);

foreach my $key (sort keys %judgeDivs) {
    my $judge = $judgeDivs{$key};
    
    # Insert the Judge
    my $query = qq {
        insert into
            judges_new (
                last_name,
                first_name,
                middle_name
            )
            values (
                ?,
                ?,
                ?
            )
    };
    doQuery($query,$dbh,[$judge->{'last_name'}, $judge->{'first_name'}, $judge->{'middle_name'}]);
    
    # Get the ID - we're going to need it
    $query = qq {
        select
            judge_id
        from
            judges_new
        where
            last_name = ?
            and first_name = ?
            and middle_name = ?
    };
    my $judgeRec = getDataOne($query,$dbh,[$judge->{'last_name'}, $judge->{'first_name'}, $judge->{'middle_name'}]);
    
    my $divs = $judge->{'Divs'};
    foreach my $div (@{$divs}) {
        $query = qq {
            insert into
                judge_divisions_new (
                    division_id,
                    judge_id
                )
                values (
                    ?,
                    ?
                )
        };
        doQuery($query,$dbh,[$div, $judgeRec->{'judge_id'}]);
    }
}

# Ok, all done.  Drop the old tables, put the new ones in place, and commit
doQuery("drop table if exists judges",$dbh);
doQuery("drop table if exists judge_divisions",$dbh);
doQuery('rename table judges_new to judges', $dbh);
doQuery('rename table judge_divisions_new to judge_divisions', $dbh);

$dbh->commit();
