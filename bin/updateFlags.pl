#!/usr/bin/perl -w

# Script to update flags and casenotes DBs, converting Banner case numbers
# to Showcase case numbers where required.

use lib ".";
use strict;
use ICMS;
use Common qw (
    dumpVar
);

# A connection to casenotes
my $cdbh = dbconnect("icms");
# A connection to showcase
my $sdbh = dbconnect("showcase-rpt");


# Get a list of the current case numbers in flags
my $query = qq {
    select
	distinct(casenum)
    from
	flags
    order by
	casenum
};

my @flagcases;
sqlHashArray($query,$cdbh,\@flagcases);
print "Selected " . scalar(@flagcases) . " cases from flags.\n";

# And do the same thing for casenotes
$query = qq {
    select
	distinct(casenum)
    from
	casenotes
    order by
	casenum
};
my @notescases;
sqlHashArray($query,$cdbh,\@notescases);
print "Selected " . scalar(@notescases) . " cases from notes.\n";


# This will be faster than individual queries for each case
$query = qq {
    select
	CaseNumber,
	LegacyCaseFormat
    from
	vCase
};
my %legacycases;
sqlHashHash($query,$sdbh,\%legacycases,'LegacyCaseFormat');

# In flags, update the case numbers to reflect the new Showcase case numbers.
foreach my $case (@flagcases) {
    next if ($case->{casenum} eq '');
    my $legacy = $case->{casenum};
    $legacy =~ s/-//g;

    if (defined($legacycases{$legacy})) {
	print "Converting '$case->{casenum}' to ".
	    "'$legacycases{$legacy}->{CaseNumber}' in flags\n";
	$query = qq {
	    update
		flags
	    set
		casenum='$legacycases{$legacy}->{CaseNumber}'
	    where
		casenum='$case->{casenum}'
	};

	$cdbh->do($query);
    }
}


# And do the same thing for casenotes
foreach my $case (@notescases) {
    next if ($case->{casenum} eq '');
    my $legacy = $case->{casenum};
    $legacy =~ s/-//g;

    if (defined($legacycases{$legacy})) {
	print "Converting '$case->{casenum}' to ".
	    "'$legacycases{$legacy}->{CaseNumber}' in casenotes\n";
	$query = qq {
	    update
		casenotes
	    set
		casenum='$legacycases{$legacy}->{CaseNumber}'
	    where
		casenum='$case->{casenum}'
	};

	$cdbh->do($query);
    }
}

print "\n\nDone!!\n\n";
