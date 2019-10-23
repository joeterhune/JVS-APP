#!/usr/bin/perl

BEGIN {
    use lib "$ENV{'JVS_PERL5LIB'}";
}

use strict;

use Getopt::Long;
use DB_Functions qw (
	dbConnect
	getData
	doQuery
);
use Common qw {
    convertCaseNumber
};

my $maxLength = 100;

my $styleFile;

GetOptions("f=s" => \$styleFile);

if ($styleFile eq '') {
	die "Usage: $0 -f <input file>\n\n";
}

# Check to be sure the file exists
if (!-e $styleFile) {
    die "No such file '$styleFile'.  Exiting before doing any damage.\n\n";
}

my $dbh = dbConnect('olsadmin');

open (INFILE, $styleFile) ||
    die "Unable to open '$styleFile' for reading: $!\n\n";

# Signal handler
$SIG{'INT'} = 'cleanup';

# Create a new table for the new data.
my $delete = qq {drop table if exists `case_styles_new` };

doQuery($delete,$dbh);

my $create = qq {CREATE TABLE `case_styles_new` (
    `casenum` char(25) NOT NULL,
    `case_style` mediumtext,
    `case_div` char(10) NOT NULL,
    `case_age` int(11) DEFAULT NULL,
    PRIMARY KEY (`casenum`),
    KEY `cs_casenum_idx` (`casenum`),
    KEY `cs_div_idx` (`case_div`),
    KEY `cs_age_idx` (`case_age`)
	) ENGINE=InnoDB DEFAULT CHARSET=latin1;
};

doQuery($create,$dbh);

# Disable AutoCommit - this is a transaction
$dbh->{AutoCommit} = 0;

my $count = 0;

my $query = qq {
    insert into
        case_styles_new
            (
                casenum,
                case_style,
                case_div,
                case_age
            )
        values
            (
                ?,
                ?,
                ?,
                ?
            )
};

while (my $line = <INFILE>) {
    chomp $line;
    my ($casenum,$other) = split(/\`/,$line);

	#next if ($casenum =~ /^58/);
    $casenum = convertCaseNumber($casenum, 1);
    $casenum =~ s/-//gi;
    next if (length($casenum) > 25);
	next if ($casenum eq '');

    my ($style,$casediv,$caseage) = split(/~/, $other);
    next if ($casediv eq '');

	# Truncate to $maxLength characters
	my @vals = ($casenum, $style, $casediv, $caseage);
	doQuery($query,$dbh,\@vals);
    $count++;
    if (!($count % 1000)) {
        print "Entered $count records.\n";
    }
}

cleanup();



sub cleanup {
	print "Finished inserting.  Committing and stuff...\n\n";

    print "Dropping old table...\n\n";
    doQuery('drop table if exists `case_styles`', $dbh);

    print "Renaming new table...\n\n";
    doQuery('rename table `case_styles_new` to `case_styles`',$dbh);

    print "Committing...\n\n";
	$dbh->commit;

	print "Done!\n\n";
	exit(0);
}

