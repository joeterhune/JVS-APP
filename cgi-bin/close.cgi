#!/usr/bin/perl -w

BEGIN {
    use lib "$ENV{'DOCUMENT_ROOT'}/../lib";
}

use strict;
use Common qw (
    dumpVar
    doTemplate
    $templateDir
    returnJson
    closeTab
);
use CGI;

my $info = new CGI;
my %params = $info->Vars;

my $location = closeTab($params{'type'}, $params{'outer_key'}, $params{'inner_key'});

print $info->redirect(-uri => $location);
exit;