#!/usr/bin/perl -w

BEGIN {
    use lib "$ENV{'JVS_PERL5LIB'}";
}

use strict;

use JSON;
use CGI;
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
    sanitizeCaseNumber
    getUser
    checkLoggedIn
);
use Showcase qw (
    $db
);
use XML::Simple;
checkLoggedIn();

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

my $clearAll = ($params{'clearAll'} eq 'true') ? 1 : 0;


my @inCases;
if (defined($params{'cases'})) {
    @inCases = split(/\s+/, $params{'cases'});
}

my %bannerHash;
my %scHash;

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
                    $data{'Cases'}->{$casenum}->{'AlreadyFlagged'} = 1;
                    $scHash{$casenum} = 1;
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
                $scHash{$case} = 1;
                $data{'Cases'}->{$case}->{'CMSCaseID'} = $case;
                $data{'Cases'}->{$case}->{'CaseNotesNum'} = $case;
                $data{'Cases'}->{$case}->{'AlreadyFlagged'} = 1;
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

my %notFlagged;

my @lookups;

if ($clearAll) {
    my $query = qq {
        select
            f.casenum as CaseNumber,
            f.casenum as CaseNotesNum,
            s.style as CaseStyle,
            f.division as DivisionID,
            f.userid as UserID,
            f.date as FlagDate,
            1 as IsFlagged
        from
            flags f left outer join summaries s on (f.casenum = s.casenum)
        where
            flagtype = ?
    };
    getData($data{'Cases'}, $query, $dbh, {valref => [$flagtype], hashkey => 'CaseNumber', flatten => 1});
} else {
    my @caseKeys = keys(%{$data{'Cases'}});
    
    my $count = 0;
    my $perQuery = 100;
    while ($count < scalar(@caseKeys)) {
        my @temp;
        getArrayPieces(\@caseKeys, $count, $perQuery, \@temp, 1);
        
        my $inString = join(",", @temp);
        my $query = qq {
            select
                f.casenum as CaseNumber,
                s.style as CaseStyle,
                f.division as DivisionID,
                f.userid as UserID,
                f.date as FlagDate,
                1 as IsFlagged
            from
                flags f left outer join summaries s on (f.casenum = s.casenum)
            where
                flagtype = ?
                and f.casenum in ($inString)
        };
        getData(\@lookups, $query, $dbh, { valref => [$flagtype] });
        $count += $perQuery;
    }
    
    foreach my $case (@lookups) {
        my $cn = $case->{'CaseNumber'};
        foreach my $key (keys %{$case}) {
            $data{'Cases'}->{$cn}->{$key} = $case->{$key};
        }
    }
    
    # Look up styles for thoe that don't have it in summaries.
    foreach my $case (keys %{$data{'Cases'}}) {
        $data{'Cases'}->{$case}->{'CaseNotesNum'} = $case;
        if ($case =~ /^50/) {
            $data{'Cases'}->{$case}->{'CMSCaseID'} = $case;
        } else {
            my $stripCase = $case;
            $stripCase =~ s/-//g;
            $data{'Cases'}->{$case}->{'CMSCaseID'} = $stripCase;
        }
        
        if (!defined($data{'Cases'}->{$case}->{'CaseStyle'})) {
            $scHash{$data{'Cases'}->{$case}->{'CMSCaseID'}} = 1;
        }
    }
    
    # Ok, now that we know which cases we need to look up, look them up. Do Banner first.
    my @scCases = keys(%scHash);
    my %lookups;
    #$data{'lookups'} = \%lookups;
    #$data{'scCases'} = \@scCases;
    
    # And then Showcase
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
        getData(\%lookups, $query, $sdbh, {hashkey => 'CaseNumber', flatten => 1});
        $count += $perQuery;
    }
    
    # Ok, now loop through the request case numbers and match up the case style.  If there is none, list
    # the case as not found.
    foreach my $case(keys %{$data{'Cases'}}) {
        my $casenum = $case;
        if (!defined($lookups{$casenum})) {
            if ($casenum =~ /^50/) {
                # A Showcase case should have been found
                push(@{$data{'NotFound'}}, $casenum);
                delete ($data{'Cases'}->{$casenum});
                next;
            } else {
                $casenum =~ s/-//g;
                if (!defined($lookups{$casenum})) {
                    push(@{$data{'NotFound'}}, $casenum);
                    delete ($data{'Cases'}->{$casenum});
                    next;
                }
            }
        }
        
        # Ok, if we're here, we have a record for $casenum in %lookups, where the key matches the key in
        # the $data{'Cases'} hash.
        my $caserec = $data{'Cases'}->{$case};
        $caserec->{'CaseStyle'} = $lookups{$casenum}->{'CaseStyle'};
        $caserec->{'DivisionID'} = $lookups{$casenum}->{'DivisionID'};
    }
}

foreach my $case (keys %{$data{'Cases'}}) {
    if ((defined($data{'Cases'}->{$case}->{'IsFlagged'})) && (defined($data{'Cases'}->{$case}->{'IsFlagged'} == 1))) {
        $data{'Cases'}->{$case}->{'AlreadyFlagged'} = 0;
    }
}

my $json_text = JSON->new->ascii->pretty->encode(\%data);
print $json_text;
exit;