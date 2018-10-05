#!/usr/bin/perl
#
#
# json.cgi makes settings available via javascript by leveraging a json request to /icms/settings/json.cgi 
#

BEGIN {
    use lib $ENV{'PERL5LIB'};
}
use CGI;
use ICMS15 qw (
    get_group_memberships
    load_module_config
);
use JSON;
use strict;
use DB_Functions qw(
    dbConnect
);

#
# MAIN PROGRAM
#
my $info=new CGI;

my $user=lc($ENV{REMOTE_USER});

my $dbh=dbConnect("icms");

get_group_memberships()

get_group_memberships($user);
my $config = load_module_config($user, 'config');

# Whitelist - rather than exposing all config values we explicitly add the ones we want here
my %settings = ();
$settings{'docviewer'} = $config->{'docviewer'};
$settings{'pdf_toolbar'} = $config->{'pdf_toolbar'};
$settings{'pdf_scrollbar'} = $config->{'pdf_scrollbar'};
$settings{'pdf_statusbar'} = $config->{'pdf_statusbar'};
$settings{'pdf_navpanes'} = $config->{'pdf_navpanes'};
$settings{'pdf_view'} = $config->{'pdf_view'};
$settings{'pdf_viewer'} = $config->{'pdf_viewer'};
$settings{'pdf_zoom'} = $config->{'pdf_zoom'};

print $info->header(-"Cache-Control"=>"no-store, no-cache, must-revalidate",
                        -"Cache-Control"=>"post-check=0, pre-check=0");
print encode_json \%settings;

