#!/usr/bin/perl -w

BEGIN {
    use lib "$ENV{'PERL5LIB'}";
}

use strict;

use XML::Simple;
use Net::SMTP;
use Date::Manip;
use Data::Dumper qw(Dumper);
use Getopt::Long;
use DB_Functions qw (
    dbConnect
    getData
);

use Common qw(
    dumpVar
    doTemplate
);

use DB_Functions qw (
    dbConnect
    getData
);

my @allowOverrides = (
                      'fromAddress',
                      'fromName',
                      'smtpHost',
                      'templateFile',
                      'contentType',
                      'dbHost',
                      'dbType',
                      'dbName',
                      'dbPass',
                      'dbUser',
                      'advanceDays'
                     );

sub getCases {
    my $conf = shift;
    my $data = shift;
    my $dbh = shift;

    if (!defined($dbh)) {
        my $dbh = dbConnect($conf);
    }

    $dbh->do("use $conf->{dbName}");

    my $days = $conf->{advanceDays};

    my $targetDate = UnixDate(DateCalc("today", "+ $days business days"),
                              "%Y-%m-%d");

    # Gosh, I hate one-offs.
    if ($conf->{dbName} ne "awevent") {
        my $query = qq {
            select
                sch_conf_num,
                sch_date,
                sch_time,
                sch_contact_email
            from
                scheduling s,
                calendar c
            where
                sch_active_cancelled=1
                and reminder_sent = '0000-00-00 00:00:00'
                and sch_conf_num = conf_num
                and sch_date = '$targetDate'
        };

        getData($data,$query,$dbh);
    } else {
        my $query = qq {
            select
                r_conf_num as sch_conf_num,
                r_date as sch_date,
                r_time as sch_time,
                r_created_by as sch_contact_email
            from
                brequest
            where
                r_date='$targetDate'
                and r_cancelled = '0000-00-00 00:00:00'
                and reminder_sent = '0000-00-00 00:00:00'
        };
        getData($data,$query,$dbh);
    }
    # Get all of the case numbers for the confirmation number, and
    # then drop them into an array, which will be referenced by
    # $reminder->{casenums}
    foreach my $reminder (@{$data}) {
        my $cntable = ($conf->{dbName} eq "awevent") ? "bcasenumber" : "casenumber";
        my $query = qq {
            select
                cn_casenumber as casenum
            from
                $cntable
            where
                cn_conf_num='$reminder->{sch_conf_num}'
            order by
                casenum
        };
        my @casenums;
        getData(\@casenums, $query, $dbh);
        $reminder->{casenums} = \@casenums;
    }
    return scalar(@{$data});
}


sub sendMessages {
    my $conf = shift;
    my $reminders = shift;
    my $dbh = shift;

    my $smtp = Net::SMTP->new(
                              $conf->{smtpHost},
                              );

    foreach my $message(@{$reminders}) {
        $message->{fromname} = $conf->{fromName};
        $message->{fromaddress} = $conf->{fromAddress};

        my $body = doTemplate($message, "c:\\wamp\\utils\\scheduleReminders", $conf->{'templateFile'}, 0);

        $smtp->mail($conf->{fromAddress});
        $smtp->to($message->{sch_contact_email});
        $smtp->bcc('rhaney@pbcgov.org');
        $smtp->data();
        if (defined($conf->{contentType})) {
            $smtp->datasend("Content-Type: $conf->{contentType}\n");
        }
        $smtp->datasend($body);
        $smtp->dataend();
        if (defined($dbh)) {
            my $query;
            if ($conf->{dbName} ne "awevent") {
                $query = qq {
                    update
                        scheduling
                    set
                        reminder_sent=now()
                    where
                        sch_conf_num='$message->{sch_conf_num}'
                };
            } else {
                $query = qq {
                    update
                        brequest
                    set
                        reminder_sent=now()
                    where
                        r_conf_num='$message->{sch_conf_num}'
                };
            }
            $dbh->do($query);
        }
    }
    $smtp->quit;
}

## Main Program Body

my $configFile = undef;

GetOptions("f=s" => \$configFile);

if (!defined($configFile)) {
    die "Usage: $0 -f <config file>\n\n";
}

my $xs = XML::Simple->new();
my $xml = $xs->XMLin($configFile);

my $dbh = undef;

foreach my $key (keys %{$xml->{division}}) {
    my $reminders = [];

    my $conf = $xml->{division}->{$key};

    # For a few values, a default will be set at the top level, but can be
    # overridden by defining them within the division block
    foreach my $field (@allowOverrides) {
        if (!defined($conf->{$field})) {
            $conf->{$field} = $xml->{$field};
        }
    }

    $dbh = dbConnect($conf);
    if (!defined ($dbh)) {
        warn "WARNING: Unable to connect to DB '$conf->{dbName}' - ".
            "skipping\n";
        next;
    }

    # Switch to the appropriate DB
    if (!$dbh->do("use $conf->{dbName}")) {
        warn "WARNING: Unable to change to DB '$conf->{dbName}' - skipping\n";
        next;
    }

    if (getCases($conf, $reminders, $dbh)) {
        # We have valid results. Got some mailin' to do.
        sendMessages($conf,$reminders,$dbh);
    }
}
