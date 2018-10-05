#!/usr/bin/perl

#
# newdiv.cgi just adds a single new divison to the list
#

BEGIN {
    use lib $ENV{'PERL5LIB'};
}

use strict;
use CGI;
use JSON;
use ICMS15 qw (
    load_module_config
    save_module_config
);

use Common qw (
    dumpVar
    getUser
);

my $info=new CGI();

my %params = $info->Vars;

my $user = getUser();
$user = lc($user);

my $div=$params{'div'};

my $settings = load_module_config($user, 'config');

if ($settings->{'filings'} ne "") {
    $settings->{'filings'}.=",$div";
} else {
    $settings->{'filings'}="$div";
}

if ($settings->{'calendars'} ne "") {
    $settings->{'calendars'}.=",$div";
} else {
    $settings->{'calendars'}="$div";
}

if ($settings->{'reports'} ne "") {
    $settings->{'reports'}.=",$div";
} else {
    $settings->{'reports'}="$div";
}

if ($settings->{'queues'} ne "") {
    $settings->{'queues'}.=",$div";
} else {
    $settings->{'queues'}="$div";
}

save_module_config($user, 'config', $settings);

print $info->header();

print "OK";
