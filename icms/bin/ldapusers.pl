#!/usr/bin/perl

# Makes a list of all users and DNs,
# sorting in /var/tmp/ldapusers.txt


BEGIN {
	use lib "$ENV{'PERL5LIB'}";
}

use strict;
use Net::LDAP;
use Net::LDAP::Control::Paged;
use Net::LDAP::Constant qw(LDAP_CONTROL_PAGED);
use Data::Dumper qw(Dumper);
use DB_Functions qw (
	$LDAPBINDDN
	$LDAPBINDPW
	$LDAPBASE
	$LDAPHOST
	$LDAPSVCBASE
	$CAD_OU
);

my $ldap;
my %userlist;

# modified to return 1 if error, 0 if not.
sub errchk {
    my($mesg)=@_;
    if ($mesg->code) {
       print "code=",$mesg->code,", message=",$mesg->error,"\n";
       return 1;
    } else { return 0; }
}

# Active Directory (AD) counts time as the # of 100-nanosecond intervals since Jan 1, 1600.
# this function adjusts that to Unix-style time and returns a nice timestamp
# based on http://aspn.activestate.com/ASPN/Cookbook/Python/Recipe/303344

sub convertADtime {
    my($time)=@_;
    if (!$time) {
		return "";
	}
    $time=($time-116444736000000000)/10000000;
    # difference between 1601 & 1970, divided by a 10million to get seconds
    my($s,$m,$h,$mday,$mon,$year,$wday,$yday,$isdst)=localtime($time);
	return sprintf("%02d/%02d/%04d %02d:%02d:%02d",$mon+1,$mday,$year+1900,
				   $h,$m,$s);
}

#
# since AD logins are context-free, but Net::LDAP binds aren't,
# I need to make a list of userid->dn mappings...
# And, since the list is so long, I have to use the Paged stuff...
#
# returns 0 if list was built without errors,
#         1 if failed on bind, 2 if failed on search.
sub builduserlist {
    my $userlist = shift;

    my $page=Net::LDAP::Control::Paged->new(size=>100);
    my $cookie;
    my $mesg=$ldap->bind($LDAPBINDDN, password=>$LDAPBINDPW);
    if(errchk($mesg) == 1) { return 1; }

    my @args=(filter=>"(objectCategory=Person)",
			  base=>$LDAPBASE,
			  control=>[ $page ],
			  attrs=>['sAMAccountname','distinguishedName',
					  'userAccountControl','lastLogon']);

    while (1) {
		$mesg=$ldap->search(@args);
		if(errchk($mesg) == 1) {
			return 2;
		}
		$mesg->code and last;
		foreach my $entry ($mesg->entries) {
			my $userid=$entry->get_value("sAMAccountname");
			$userid=~tr/A-Z/a-z/;
			my $dn=$entry->get_value("distinguishedName");
			my $userattr=$entry->get_value("userAccountControl");
			my $lastlogon=$entry->get_value("lastLogon");
			$lastlogon=convertADtime($lastlogon);
			if ($userid ne "") {
				$userlist->{$userid}="$dn~$userattr~$lastlogon";
			}
		}
		
		# get cookie from paged control
		my($resp)  = $mesg->control( LDAP_CONTROL_PAGED ) or last;
		$cookie    = $resp->cookie or last;
		# set cookie in paged control
		$page->cookie($cookie);
	}
	
	if ($cookie) {
		$page->cookie($cookie);
		$page->size(0);
		$ldap->search(@args);
		die "Failure!";
	}
   return 0;
}

#
# MAIN PROGRAM
#
$ldap=Net::LDAP->new($LDAPHOST);
my $res = builduserlist(\%userlist);

# Hack.  Force cad-nagios, which isn't in the User container
$userlist{'cad-nagios'}="CN=CAD Nagios,OU=Services,OU=CAD,ou=$CAD_OU,DC=pbcgov,DC=org~66048~";

if( $res != 1 ) {
    $ldap->unbind();
}
if($res == 0){
	open OUTFILE,">/var/tmp/ldapusers.txt" ||
		die "Couldn't open /var/tmp/ldapusers.txt";
    foreach (sort keys %userlist) {
		print OUTFILE "$_~$userlist{$_}\n";
    }
    close OUTFILE;
}
