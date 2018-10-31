#!/usr/bin/perl -w

BEGIN {
    use lib "$ENV{'PERL5LIB'}";
}

use strict;
use Common qw (
    dumpVar
    inArray
);
use DB_Functions qw (
    dbConnect
    getData
);
use Getopt::Long;
use JSON;

my @casetypes;

my $dump = 0;

GetOptions ("t=s" => \@casetypes, "d" => \$dump);

if (!scalar(@casetypes)) {
    die "Usage: $0 -t <type> [-d] [-t <type>] ...\n\n";
}


open(ALLCASES, "/var/tmp/styles.txt") ||
    die "Unable to open /var/tmp/styles.txt for reading: $!\n\n";

my %caseref;

my @partyTypes = ('ATTY','DFT','PLT','PET','RESP','CHLD','MTH','FTH');

my $partyTypeStr = "'ATTY','DFT','PLT','PET','RESP','CHLD','MTH','FTH'";

my $bdbh = dbConnect("wpb-banner-prod");

my $count = 0;

while (my $line = <ALLCASES>) {
    chomp $line;
    my $casenum = (split("`", $line))[0];
    if ($casenum =~ /(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)/) {
        my $type = $2;
        if (inArray(\@casetypes, $type, 0)) {
            if (!defined($caseref{$casenum})) {
                $caseref{$casenum} = {};
                $caseref{$casenum}{'Parties'} = [];
                $caseref{$casenum}{'Attorneys'} = [];
            }
            
            my $query = qq {
                select
                    spriden_last_name as "LastName",
                    spriden_first_name as "FirstName",
                    cdrcpty_seq_no as "Sequence",
                    cdrcpty_assoc_with as "Represents",
                    cdrcpty_ptyp_code as "PartyType"
                from
                    spriden,
                    cdrcpty
                where
                    cdrcpty_case_id = ? 
                    and cdrcpty_pidm = spriden_pidm
                    and cdrcpty_ptyp_code in ($partyTypeStr)
                    and spriden_change_ind is null
                    and cdrcpty_end_date is null
            };
            
            my @parties;
            getData(\@parties, $query, $bdbh, {valref => [$casenum]});
            
            foreach my $party (@parties) {
                if ($party->{'PartyType'} eq 'ATTY') {
                    my %partytemp = (
                                     'FirstName' => $party->{'FirstName'},
                                     'LastName' => $party->{'LastName'},
                                     'Represents' => $party->{'Represents'},
                                     'Sequence' => $party->{'Sequence'}
                                     );
                    push (@{$caseref{$casenum}{'Attorneys'}}, $party);
                } elsif (inArray(\@partyTypes,$party->{'PartyType'})) {
                    my %partytemp = (
                                     'FirstName' => $party->{'FirstName'},
                                     'LastName' => $party->{'LastName'},
                                     'Sequence' => $party->{'Sequence'},
                                     'PartyType' => $party->{'PartyType'}
                                     );
                    push (@{$caseref{$casenum}{'Parties'}}, $party);
                }
            }
            next;
        }
    }
}

close ALLCASES;

# Ok, now we have a listing of all of the attorneys and parties, including the sequence of the party that the
# attorney represents.  Go through and, for each party, determine if the party is represented by counsel

my $proSeParties = 0;
my $proSeCases = 0;
my @proSeCases;

foreach my $case (keys %caseref) {
    $caseref{$case}{'ProSePartyCount'} = 0;
    foreach my $party (@{$caseref{$case}{'Parties'}}) {
        # Loop through the attorneys; if there is an attorney that represents this sequence ID, then the party
        # is not pro se
        my $seq = $party->{'Sequence'};
        $party->{'ProSe'} = 1;
        foreach my $attorney (@{$caseref{$case}{'Attorneys'}}) {
            if ((defined($attorney->{'Represents'})) && ($attorney->{'Represents'} ne "") && ($attorney->{'Represents'} == $seq)) {
                $party->{'ProSe'} = 0;
                last;
            }
        }
        if ($party->{'ProSe'}) {
            # If we're here, we didn't find a matching attorney.  This party is pro se.
            $caseref{$case}{'ProSePartyCount'}++;
            $proSeParties++;
        }
    }
    if ($caseref{$case}{'ProSePartyCount'}) {
        $proSeCases++;
        push(@proSeCases, $case);
    }
}


my $caseTotal = scalar(keys(%caseref));
my $typeString = join(",", @casetypes);


if ($dump) {
    my $json = JSON->new->allow_nonref;
    my $string = $json->pretty->encode(\%caseref);
    print $string . "\n\n";
} else {
    print "There are a total of $proSeParties pro se parties in $proSeCases cases for case types $typeString ($caseTotal total active cases).\n\n";
}

foreach my $case (sort @proSeCases) {
    print "$case\n";
}

exit;