#!/usr/bin/perl

# Determine if there were cases opened in Showcase on the previous day.  If there
# weren't, then something happened with the overnight snapshot.

# Don't just use business days, because traffic/FAP cases are filed on weekends, too.

BEGIN {
	use lib "$ENV{'PERL5LIB'}";
}

use strict;
use Common qw (
	sendMessage
	dumpVar
);

use DB_Functions qw (
	dbConnect
	getData
);

use Date::Manip;

# Get yesterday's date, and put it into the correct format
my $yesterday = UnixDate(&ParseDate("yesterday"),'%Y-%m-%d');

# Look up cases with a FileDate of yesterday
my $query = qq {
	select
		CaseNumber
	from
		vCase
	where
		FileDate = ?
};

my $dbh = dbConnect("showcase-prod");

my @cases;
getData(\@cases,$query,$dbh,{valref => [$yesterday]});

# If none were found, send an alert email.
if (!scalar(@cases)) {
	my @recips = (
		{
			fullname => "Rich Haney",
			email_addr => 'rhaney@jud12.flcourts.org'
		}
	);
	my $sender = {
				  fullname => "ICMS Alerts",
				  email_addr => 'cad-icmsalert@jud12.flcourts.org'
				 };
	my $subject = "ALERT: Showcase Shows No Cases Files Yesterday ($yesterday)";
	my $body = "The Showcase reporting database is showing that there were no ".
		"cases filed yesterday ($yesterday).  This could be an indication that the ".
		"overnight snapshot didn't run.  You might want to check into it.\n\n".
		"That is all.\n\n";
	sendMessage(\@recips,$sender,undef,$subject,$body,undef,1,0);
}

exit;