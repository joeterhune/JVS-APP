#!/usr/bin/perl -w

BEGIN {
	use lib "$ENV{'JVS_PERL5LIB'}";
}

use strict;
use Common qw (
    dumpVar
    today
    ISO_date
);
use DB_Functions qw (
    dbConnect
    getData
    getDbSchema
    doQuery
);
use Showcase qw (
    $db
);
use Calendars qw (
    $SC_SOURCE_ID
    getVRBEvents
    sortExternalEvents
    vrbCompareAndUpdate
);

use Getopt::Long;

my $vrb;
my $startDate;
GetOptions("d=s" => \$vrb, "s=s" => \$startDate);
if (!defined($vrb)) {
    $vrb = "vrb2";
}

if (!defined($startDate)) {
    $startDate = ISO_date(today());
}


my $dbh = dbConnect($db);
my $schema = getDbSchema($db);

my $SRC_ID = $SC_SOURCE_ID;

my $query = qq {
    select
        vce.CaseNumber,
        vce.CourtEventType,
        vce.UCN,
        JudgeName,
        CONVERT(varchar(10),vce.CourtEventDate,120) as Date,
        CONVERT(varchar(5),vce.CourtEventDate,114) as StartTime,
        CONVERT(varchar(5),DATEADD(hour,1,vce.CourtEventDate),114) as EndTime,
        CASE vce.Cancelled
            WHEN 'Yes' THEN 'Y'
            ELSE 'N'
        END as Canceled,
        vce.DivisionCode as DivisionID,
        vc.CaseStyle,
        vce.CourtEventNotes as EventNotes
    from
        $schema.vCourtEvent vce with(nolock),
        $schema.vCase vc
    where
        vce.CourtEventDate >= ?
        and vc.CaseNumber = vce.CaseNumber
        and DivisionCode is not null
        and vce.Cancelled = 'No'
};

my %events;
getData(\%events, $query, $dbh, {valref => [$startDate], hashkey => 'DivisionID'});

foreach my $div (keys %events) {
    foreach my $event (@{$events{$div}}) {
        # We don't want the court event code that comes back from the DB - just the type
        # description itself.  Take it apart.
        next if (!defined($event->{'CourtEventType'}));
        
        my ($cec,$junk,$cet) = (split(/\s+/, $event->{'CourtEventType'}, 3));
        $event->{'CourtEventType'} = $cet;
        $event->{'EventName'} = $cet;
        $event->{'EventCode'} = $cec;
        # Fix the Judge name
        
        if (defined($event->{'JudgeName'})) {
            $event->{'JudgeName'} =~ s/, JUDGE/, JUDGE /g;
        }
    }
}

my %sorted;
sortExternalEvents(\%sorted, \%events);

$dbh->disconnect;

my $vdbh = dbConnect($vrb);

my %existing;
getVRBEvents(\%existing,$SRC_ID,$vdbh);

my %vrbSorted;
sortExternalEvents(\%vrbSorted,\%existing);

# Now that we have the existing records from VRB and the "official" records from the
# import source, do the work.
vrbCompareAndUpdate(\%vrbSorted,\%sorted,$SRC_ID,$vdbh);
