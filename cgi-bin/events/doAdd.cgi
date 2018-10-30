#!/usr/bin/perl

BEGIN {
	use lib "$ENV{'PERL5LIB'}";
}

use strict;
use CGI;

use DB_Functions qw (
	dbConnect
	doQuery
	getDataOne
);

use Calendars qw (
	writeCal
);

use Common qw (
	dumpVar
	getUser
);

use XML::Simple;

my $info = new CGI;

my %params = $info->Vars;

my $query = qq{
	insert into
		events (
			casenum,
			case_div,
			sched_div,
			event_location,
			case_style,
			event_title,
			event_date,
			start_time,
			end_time,
			event_notes,
			created_by,
			created_ip,
			created_timestamp
		)
		values (
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			now()
		)
};

my @values = ($params{'casenum'}, $params{'casediv'},$params{'sched_div'},$params{'evtlocation'},
			  $params{'casestyle'},$params{'evtdesc'},$params{'evtdate'},$params{'starttime'},
			  $params{'endtime'},$params{'evtnotes'}, getUser(),$ENV{'REMOTE_ADDR'});

my $dbh = dbConnect("events");
doQuery($query,$dbh,\@values);

# Now look it up to be sure it worked
$query = qq {
	select
		event_id
	from
		events
	where
		casenum = ?
		and event_date = ?
		and start_time = ?
		and end_time = ?
		and sched_div = ?
};

my @checkVals = ($params{'casenum'}, $params{'evtdate'}, $params{'starttime'}, $params{'endtime'},
				 $params{'sched_div'});

my $checkRec = getDataOne($query,$dbh,\@checkVals);

# Write the calendar
writeCal($params{'sched_div'}, $dbh);

my $xs = XML::Simple->new(RootName => 'Response', NoAttr => 1, KeepRoot => 1);
my $xml = $xs->XMLout($checkRec);
print $info->header("text/xml");
print $xml;
