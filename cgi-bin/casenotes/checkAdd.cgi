#!/usr/bin/perl -w

BEGIN {
    use lib $ENV{'PERL5LIB'};
}

use strict;

use JSON;
use CGI;
use Common qw (
    sanitizeCaseNumber
    getUser
    checkLoggedIn
);
use CGI::Carp qw (fatalsToBrowser);
use DB_Functions qw (
    getData
    dbConnect
    doQuery
    getDbSchema
    inGroup
);
use Common qw (
    getArrayPieces
    dumpVar
    stripWhiteSpace
);
use Showcase qw (
    $db
    getSCCaseNumber
);

checkLoggedIn();

my $info = new CGI;

my $user = getUser();
if (!inGroup($user, "CAD-ICMS-NOTES")) {
    print $info->header;
    print "You do not have rights to use this function.\n";
    exit;
}

print $info->header('application/json');

my %params = $info->Vars;

#print $info->header;

my @inCases = split(/\s+/, $params{'cases'});

my @scCases;

my $sdbh = dbConnect($db);
my $schema = getDbSchema($db);

my %data;
$data{'Cases'} = {};
$data{'Ambiguous'} = [];
$data{'NotFound'} = [];
$data{'NotValid'} = [];

foreach my $inCase (@inCases) {
    $inCase = stripWhiteSpace($inCase);
    next if ($inCase eq '');
    my $case = sanitizeCaseNumber($inCase);
    if (defined($case)) {
        if (!defined($data{'Cases'}->{$case})) {
            $data{'Cases'}->{$case} = {};
        }
        # Need to determine if we have a full case number, or if it's ambiguous
        my $stripCase = $case;
        $stripCase =~ s/-//g;
        if ($stripCase !~ /\d\d\d\d\d\d\D\D\d\d\d\d\d\d\D\D\D\D\D\D/) {
            # Ambiguous based on just the case number.  Look it up and see what we get
            my @lookups;
            my $query = qq {
                select
                    CaseNumber
                from
                    $schema.vCase with(nolock)
                where
                    UCN like '$stripCase%'
            };
            getData(\@lookups, $query, $sdbh);
            if (scalar(@lookups) == 1) {
                # A single match
                my $casenum = $lookups[0]->{'CaseNumber'};
                $data{'Cases'}->{$casenum} = $data{'Cases'}->{$case};
                delete ($data{'Cases'}->{$case});
                $data{'Cases'}->{$casenum}->{'CMSCaseID'} = $casenum;
                $data{'Cases'}->{$casenum}->{'CaseNotesNum'} = $casenum;
                push(@scCases, $casenum);
                next;
            } elsif (scalar(@lookups) > 1) {
                delete ($data{'Cases'}->{$case});
                push(@{$data{'Ambiguous'}}, $case);
                next;
            } elsif (!scalar(@lookups)) {
                delete ($data{'Cases'}->{$case});
                push(@{$data{'NotFound'}}, $case);
                next;
            }
        } else {
            # We have a legit-looking case number
            push(@scCases, $case);
            $data{'Cases'}->{$case}->{'CMSCaseID'} = $case;
            $data{'Cases'}->{$case}->{'CaseNotesNum'} = $case;
        }
    } else {
        push(@{$data{'NotValid'}}, $inCase);
    }
}

# No sense proceeding if there are invalid/abmiguous case numbers.
if ((scalar(@{$data{'NotValid'}})) || (scalar(@{$data{'Ambiguous'}}))) {
    my $json_text = JSON->new->ascii->pretty->encode(\%data);
    print $json_text;
    exit;
}

my $flagtype = $params{'flags'};

# Ok, we know what cases and flags.  First, check to see if any of the cases have the specified flag.
my $dbh = dbConnect("icms");

my $count = 0;
my $perQuery = 100;

my %alreadyFlagged;

my @caseKeys = keys(%{$data{'Cases'}});

while ($count < scalar(@caseKeys)) {
    my @temp;
    getArrayPieces(\@caseKeys, $count, $perQuery, \@temp, 1);
    
    my $inString = join(",", @temp);
    my $query = qq {
        select
            flagtype as FlagType,
            casenum as CaseNumber
        from
            flags
        where
            casenum in ($inString)
            and flagtype = ?
    };
    getData(\%alreadyFlagged, $query, $dbh, { valref => [$flagtype], hashkey => "CaseNumber"});
    $count += $perQuery;
}

# Now look up case style and division for each of the cases.
my @caseMatches;

# Then for Showcase
$count = 0;
while ($count < scalar(@scCases)) {
    my @temp;
    getArrayPieces(\@scCases, $count, $perQuery, \@temp, 1);
    my $inString = join(",", @temp);
    my $query = qq {
        select
            CaseNumber,
            CaseStyle,
            DivisionID
        from
            $schema.vCase with(nolock)
        where
            CaseNumber in ($inString)
    };
    getData(\@caseMatches, $query, $sdbh);
    $count += $perQuery;
}


foreach my $case (@caseMatches) {
    # Traverse this list and match them with the %cases hash
    foreach my $matchCase (keys %{$data{'Cases'}}) {
        next if ($case->{'CaseNumber'} ne $data{'Cases'}->{$matchCase}->{'CMSCaseID'});
        $data{'Cases'}->{$matchCase}->{'CaseStyle'} = $case->{'CaseStyle'};
        $data{'Cases'}->{$matchCase}->{'DivisionID'} = $case->{'DivisionID'};
    }
}

# Ok, we've matched all of the cases that we DO have with their records.  Traverse %cases once more to find cases
# where we didn't find anything, so we can add them to the NotFound array.

foreach my $case (keys %{$data{'Cases'}}) {
    if (!defined($data{'Cases'}->{$case}->{'CaseStyle'})) {
        push(@{$data{'NotFound'}}, $case);
        delete ($data{'Cases'}->{$case});
    }
    # And also check %alreadyFlagged to see if we need to exclude some
    if (defined($alreadyFlagged{$case})) {
        $data{'Cases'}->{$case}->{'AlreadyFlagged'} = 1;
    }
}

my $json_text = JSON->new->ascii->pretty->encode(\%data);
print $json_text;

exit;