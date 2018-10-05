#!/usr/bin/perl -w

BEGIN {
    use lib "/usr/local/icms/bin";
}

use strict;

use Getopt::Long;

use DB_Functions qw (
    dbConnect
    doQuery
    getData
    getDataOne
);
use Common qw {
    inArray
    dumpVar
    getArrayPieces
    convertCaseNumber
};

# Turn off output buffering
$| = 1;

my $partyFile;

GetOptions("f=s" => \$partyFile);

if ($partyFile eq '') {
    die "Usage: $0 -f <input file>\n\n";
}

# Check to be sure the file exists
if (!-e $partyFile) {
    die "No such file '$partyFile'.  Exiting before doing any damage.\n\n";
}


my $dbh = dbConnect('olsadmin');

open (INFILE, $partyFile) ||
    die "Unable to open '$partyFile' for reading: $!\n\n";

my $count = 0;

my $insQuery = qq {
    insert into
        case_parties
            (
                casenum,
                partytype,
                last_name,
                first_name,
                middle_name,
                bar_num,
                party_id,
                party_seq,
                represents,
                street_addr,
                city,
                state,
                zip,
                area_code,
                phone_number,
                addr_date
            )
        values
            (
                ?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?
            )
};

my $updateQuery = qq {
    update
        case_parties
    set
        partytype = ?,
        last_name = ?,
        first_name = ?,
        middle_name = ?,
        bar_num = ?,
        party_id = ?,
        represents = ?,
        street_addr = ?,
        city = ?,
        state = ?,
        zip = ?,
        area_code = ?,
        phone_number = ?,
        addr_date = ?
    where
        casenum = ?
        and party_seq = ?
};


my %existParties;
my $query = qq {
    select
        casenum,
        bar_num,
        party_id,
        party_seq,
        addr_date
    from
        case_parties
};
getData(\%existParties, $query, $dbh, {hashkey => 'casenum'});

# Get a listing of existing cases already in the database.  Once we've
# processed all of the records, we need to delete records for cases that
# we didn't see today
#my @removeCases = sort keys (%existParties);

# Disable AutoCommit - this is a transaction
$dbh->{AutoCommit} = 0;

my %keepCases;

while (my $line = <INFILE>) {
    chomp $line;
    my ($junk,$info) = split(/\`/,$line,2);
    my ($casenum,$partyseq,$partytype,$last_name,$first_name,$middle_name,$bar_num,$represents,$street,$city,
		$state,$zip,$addr_date,$area_code,$phone_number) = split(/~/,$info);
    
    #$casenum =~ s/^50//g;
    $casenum = convertCaseNumber($casenum, 1);
    $casenum =~ s/-//gi;
    next if (length($casenum) > 13);
	next if ($casenum eq '');
    
    # Track the case numbers so we can figure out which to delete when we're done.
    $keepCases{$casenum} = 1;
        
	if ((defined($addr_date)) && ($addr_date eq '')) {
		$addr_date = "1970-01-01";
	}
    
    if (!defined($addr_date)) {
        $addr_date = "1970-01-01";
    }

    if ((defined($first_name)) && ($first_name eq '')) {
        $first_name = undef;
    }

    if ((defined($middle_name)) && ($middle_name eq '')) {
        $middle_name = undef;
    }

    my $party_id = undef;
    if ($bar_num !~ /^\d*$/) {
        $party_id = $bar_num;
        $bar_num = undef;
    }

	if ((defined($bar_num)) && ($bar_num eq "")) {
		$bar_num = undef;
	}

    if ((defined($represents)) && ($represents eq '')) {
        $represents = undef;
    }

	if ((defined($area_code)) && ($area_code eq '')) {
		$area_code = undef;
	}

	if ((defined($phone_number)) && ($phone_number eq '')) {
		$phone_number = undef;
	}
    
    # Does the record already exist?  Let's check to see if
    # the imported record has a newer date.
    
    my $found = 0;
    if (defined($existParties{$casenum})) {
        # We have parties for this case. Check to see if we have one that matches this party
        foreach my $party (@{$existParties{$casenum}}) {
            next if ($partyseq !=  $party->{'party_seq'});
            $party->{'keep'} = 1;
            if ($party->{'addr_date'} lt $addr_date) {
                # This is an old record and needs to be updated
                print $party->{'addr_date'} . " is more recent than " . $addr_date . ", so the record for party sequence $partyseq needs updating for case $casenum.\n";
                my @updVals = (
                    $partytype,
                    $last_name,
                    $first_name,
                    $middle_name,
                    $bar_num,
                    $party_id,
                    $represents,
                    $street,
                    $city,
                    $state,
                    $zip,
                    $area_code,
                    $phone_number,
                    $addr_date,
                    $casenum,
                    $partyseq
                );
                doQuery($updateQuery,$dbh,\@updVals);
            }
 
            $found++;
            last;
        }
    }
    
    if (!$found) {
        print "Need to add party $partyseq to case $casenum\n";
        my @insVals = (
            $casenum,
            $partytype,
            $last_name,
            $first_name,
            $middle_name,
            $bar_num,
            $party_id,
            $partyseq,
            $represents,
            $street,
            $city,
            $state,
            $zip,
            $area_code,
            $phone_number,
            $addr_date
        );
        doQuery($insQuery, $dbh, \@insVals);
    }
    
    $count++;
    if (!($count % 1000)) {
        print "Processed $count records.\n";
    }
}

# Determine which of the existing case parties need to be removed.
print "Starting to determine which ones we don't keep.\n\n";

foreach my $case (keys %existParties) {
    foreach my $party (@{$existParties{$case}}) {
        if (!$party->{'keep'}) {
            print "Removing party sequence " . $party->{'party_seq'} . " from case $case.\n";
            dumpVar($party);
            $query = qq {
                delete from
                    case_parties
                where
                    casenum = ?
                    and party_seq = ?
            };
            doQuery($query, $dbh, [$case, $party->{'party_seq'}]);
        }
    }
}

my @removeCases;
foreach my $ecase (keys(%existParties)) {
    if (!defined($keepCases{$ecase})) {
        push(@removeCases, $ecase);
    }
}


my $piececount = 0;
my $perQuery = 100;
while ($piececount < scalar(@removeCases)) {
    my @temp;
    getArrayPieces(\@removeCases, $piececount, $perQuery, \@temp, 1);
    my $inString = join(",", @temp);
    my $query = qq {
        delete from
            case_parties
        where
            casenum in ($inString)
    };
    doQuery ($query, $dbh);
    $piececount += $perQuery;
}

$dbh->commit;

exit;

