#!/usr/bin/perl

BEGIN {
    use strict;
    use lib $ENV{'PERL5LIB'};
}

use XML::Simple;
use Data::Dumper qw(Dumper);

my $configXml = $ENV{'APP_ROOT'} . "/conf/ICMS.xml";
my $config = XMLin($configXml);

my $olsdb = "olscheduling";

if (defined($config->{'dbConfig'}->{'calendars'}->{'dbName'})) {
    print "FOO\n";
    $olsdb = $config->{'dbConfig'}->{'calendars'}->{'dbName'};
}

print Dumper $olsdb;