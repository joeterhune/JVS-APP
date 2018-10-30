#!/usr/bin/perl

# ldapgroups - creates list of samaaccount names for a set of groups
# sorting in /var/tmp/ldapgroups.txt
#
# NOTE: This program is run hourly via symlink in /etc/cron.hourly
# 12/08/09 lms add more error checking and don't write group file unless no errors
# 04/21/11 lms add two new groups:  CAD-ICMS-ODPS and CAD-ICMS-OACS
#

BEGIN {
	use lib "$ENV{'PERL5LIB'}";
}

use strict;
use Net::LDAP;
use Net::LDAP::Control::Paged;
use Net::LDAP::Constant qw(LDAP_CONTROL_PAGED);
use DB_Functions qw (
	ldapLookup
	$LDAPBINDDN
	$LDAPBINDPW
	$LDAPBASE
	$LDAPHOST
	$LDAPSVCBASE
);

use Common qw (
	inArray
);

my @ADGroups = (
	'CAD-ICMS-GROUP',
	'CAD-ICMS-JUV',
	'CAD-ICMS-NOTES',
	'CAD-ICMS-SEC',
	'CAD-ICMS-ODPS',
	'CAD-ICMS-OACS',
	'CAD-ICMS-SEALED',
	'CAD-ICMS-SEALED-JUV',
	'CAD-ICMS-TIF'
);

my %grouplist = "";

sub listmembers {
    my $groupname = shift;
    my $groupRef = shift;
	my $ldap = shift;
    my $line=";";
    my $page=Net::LDAP::Control::Paged->new(size=>100);
    #my $cookie;

	my @users;
	my $filter = "(memberOf=CN=$groupname,OU=Services,OU=CAD,OU=Enterprise,DC=pbcgov,DC=org)";
	ldapLookup(\@users,$filter,$ldap,["sAMAccountName"],$LDAPBASE);

	# Special cases - add all members of CAD-Judges to CAD-ICMS-SEALED
	if ($groupname eq "CAD-ICMS-SEALED") {
		my $filter = "(memberOf=CN=CAD-Judges,OU=Groups,OU=Users,OU=CAD,OU=Enterprise,DC=pbcgov,DC=org)";
		ldapLookup(\@users,$filter,$ldap,["sAMAccountName"],$LDAPBASE);
	}

	$groupRef->{$groupname} = [];

	foreach my $user (@users) {
		if (!inArray($groupRef->{$groupname}, $user->{'sAMAccountName'})) {
			# Avoid duplication
			push (@{$groupRef->{$groupname}}, $user->{'sAMAccountName'});
		}
	}

	if ($groupname eq "CAD-ICMS-GROUP") {
		push (@{$groupRef->{$groupname}}, 'cad-nagios');
	}

    return 0;
}

#
# MAIN PROGRAM
#
my $ldap = Net::LDAP->new($LDAPHOST);

my $mesg = $ldap->bind($LDAPBINDDN,
					   password => $LDAPBINDPW);
if ($mesg->code) {
	print STDERR "There was an error binding to LDAP!";
    exit;
}

my %groups;

foreach my $group (@ADGroups) {
	listmembers($group,\%groups,$ldap);
}

$ldap->unbind();

# Ok, now we have a hash (keyed on the group name) of arrays of users.  Build the list.
open(OUTFILE, ">/var/tmp/ldapgroups.txt") ||
	die "Unable to create output file: $!\n\n";

foreach my $group (@ADGroups) {
	my $string = sprintf("%s~;%s;\n", $group, join(";", sort(@{$groups{$group}})));
	print OUTFILE $string;
}

close OUTFILE;
exit;
