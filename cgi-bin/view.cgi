#!/usr/bin/perl

BEGIN {
    use lib "$ENV{'JVS_PERL5LIB'}";
}

use strict;
use CGI;
use Common qw (
    inArray
    dumpVar
);
use Showcase qw (
    @ctArray
);

my $info = new CGI;

my $ucn = $info->param('ucn');
my $lev = $info->param('lev');
my $caseid = $info->param('caseid');

if(!defined($caseid)){
	$caseid = getCaseID($ucn);
}

my $redirect = "scview.cgi";

my $temp = $ucn;
$temp =~ s/-//g;
#$temp =~ s/^50//g;

if ($temp =~ /^(\d{1,6})(\D\D)(\d{0,6})(.*)/ ) {
    if (!inArray(\@ctArray, $2)) {
        # Might be an appeal.
        if (($2 eq "AP") && ($3 =~ /^9/)) {
            $redirect = "scview.cgi";
        } else {
            $redirect = "sccivilview.cgi";
        }
    }
}

print $info->redirect("$redirect?ucn=$ucn&amp;caseid=$caseid&amp;lev=$lev");
exit;
