#!/usr/bin/perl

BEGIN {
    use lib $ENV{'JVS_PERL5LIB'};
}

use strict;
use Common qw (
    readCSV
    dumpVar
    sendMessage
    @adminMails
);
use DB_Functions qw (
    dbConnect
    doQuery
	getData
);
use Net::FTP;
use Email::Valid;
use XML::Simple;
use Getopt::Long;
use POSIX qw (strftime);
use File::Temp qw (tempfile);
use IO::Uncompress::Unzip qw(unzip $UnzipError);
use utf8;
use Text::Unidecode;

my $configFile;

GetOptions ("f=s" => \$configFile);

if (!defined($configFile)) {
    die "$0 -f <FTP config XML file>\n\n";
}

# Check to be sure the file exists
if (!-e $configFile) {
    die "No such file '$configFile'.  Exiting.\n\n";
}

my $config = XMLin($configFile);

my $ftpConf = $config->{'ftpConfigs'}->{'merlin'};

if (!defined($ftpConf)) {
	# No config found
	die "No configuration found for ftpConfig 'merlin'.  Cannot proceed.\n\n"
}

my $file = getBarFile($ftpConf);
#my $file = "/var/tmp/CRTMIG.CSV";

my @fstat = stat($file);

if ($fstat[12] == 0) {
    # There was apparently a problem with the file - it's 0 bytes. Bail out! Danger, Will Robinson!
    my %sender = (
                  'fullname' => 'Jud12-Web',
                  'email_addr' => 'jterhune@jud12.flcourts.org'
    );
    my $cc = [];
    my $subject = "ERROR - Importing Florida Bar Feed";
    my $body = "The resulting file from the Florida Bar download was 0 bytes - no import action was taken. You may wish to look into it.";
    sendMessage(\@adminMails, \%sender, $cc, $subject, $body, undef, 0, 0);
    
    exit;
}

my @csvFields = (
    "bar_num",
    "first_name",
    "middle_name",
    "last_name",
    "suffix",
    "firm",
    "firm2",
    "street",
    "city",
    "state",
    "zip",
    "bus_area_code",
    "bus_phone",
    "fax_area_code",
    "fax",
    "email",
    "county_code",
    "circuit",
    "active",
    "judge_code"
);

my @barref;

print "Reading file...\n";

readCSV($file,\@csvFields,\@barref,undef,'ISO-8859-1');

# Signal handler
$SIG{'INT'} = 'cleanup';

my $dbh = dbConnect('olsadmin');

$dbh->{AutoCommit} = 0;

print "Creating temp tables...\n\n";

my $query = "DROP TABLE IF EXISTS `bar_members_new`";
$dbh->do($query);
$query = qq {
    CREATE TABLE `bar_members_new` (
        `bar_num` int(11) NOT NULL,
        `first_name` varchar(20) NOT NULL,
        `middle_name` varchar(20) DEFAULT NULL,
        `last_name` varchar(20) NOT NULL,
        `suffix` varchar(10) DEFAULT NULL,
        `street` varchar(50) NOT NULL,
        `city` varchar(50) NOT NULL,
        `state` char(5) NOT NULL,
        `zip` char(20) NOT NULL,
        `bus_area_code` char(3) NOT NULL,
        `bus_phone` char(20) NOT NULL,
        `fax_area_code` char(3) NOT NULL,
        `fax` char(20) NOT NULL,
        `email` varchar(100) NOT NULL,
        PRIMARY KEY (`bar_num`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1
};

doQuery($query,$dbh);

$query = "DROP TABLE IF EXISTS `unreg_bar_members_new`";
$dbh->do($query);
$query = qq {
	CREATE TABLE `unreg_bar_members_new` (
		`bar_num` int(11) NOT NULL,
		`first_name` varchar(20) NOT NULL,
		`middle_name` varchar(20) DEFAULT NULL,
		`last_name` varchar(20) NOT NULL,
		`suffix` varchar(10) DEFAULT NULL,
		`email_addr_id` int(10) unsigned NOT NULL,
		PRIMARY KEY (`bar_num`)
	) ENGINE=InnoDB DEFAULT CHARSET=latin1;
};

doQuery($query,$dbh);

print "Doing inserts...\n\n";

my $count = 0;
foreach my $row (@barref) {
	$count++;

	# Sanitize the email address
	my @temp = split(/[;,\ ]+/, $row->{'email'});
	foreach my $piece (@temp) {
		if (Email::Valid->address($piece)) {
			$row->{'email'} = $piece;
			last;
		}
	}

	my $bar_num = $row->{'bar_num'};
	my $qfirst_name = $dbh->quote($row->{'first_name'});
	my $qmiddle_name = $dbh->quote($row->{'middle_name'});
	my $qlast_name = $dbh->quote($row->{'last_name'});
	my $qsuffix = $dbh->quote($row->{'suffix'});
	my $qstreet = $dbh->quote($row->{'street'});
	my $qcity = $dbh->quote($row->{'city'});
	my $qstate = $dbh->quote($row->{'state'});
	my $qzip = $dbh->quote($row->{'zip'});
	my $qbus_area_code = $dbh->quote($row->{'bus_area_code'});
	my $qbus_phone = $dbh->quote($row->{'bus_phone'});
	my $qfax_area_code = $dbh->quote($row->{'fax_area_code'});
	my $qfax = $dbh->quote($row->{'fax'});
	my $qemail = $dbh->quote($row->{'email'});
	
	$qfirst_name = unidecode($qfirst_name);
	$qmiddle_name = unidecode($qmiddle_name);
	$qlast_name = unidecode($qlast_name);

	$query = qq{
		call add_bar_member_new (
			$bar_num,
			$qfirst_name,
			$qmiddle_name,
			$qlast_name,
			$qsuffix,
			$qstreet,
			$qcity,
			$qstate,
			$qzip,
			$qbus_area_code,
			$qbus_phone,
			$qfax_area_code,
			$qfax,
			$qemail
		)
	};

	$dbh->do($query);

	if (!($count % 1000)) {
        print "Inserted $count records ...\n";
    }
}

cleanup();
exit;


sub cleanup {
	print "Cleaning up...\n\n";

    $dbh->do('drop table if exists `bar_members`');
    $dbh->do('rename table `bar_members_new` to `bar_members`');

	$dbh->do('drop table if exists `unreg_bar_members`');
	$dbh->do('rename table `unreg_bar_members_new` to `unreg_bar_members`');

    print "Committing...\n\n";
	$dbh->do("commit");

	print "Done!\n\n";
	exit(0);
}


sub getBarFile {
	my $config = shift;

	# Get a temp filename in /var/tmp
	my ($fh, $filename) = tempfile (
									DIR => "/var/tmp",
									UNLINK => 1
									);
	# We only wanted the filename - close the filehandle
	close($fh);

    my $success = 0;
    my $maxtries = 5;
    my $count = 1;
    my $dlFile;
    
    while (!$success && ($count <= $maxtries)) {
        eval {
            my $ftp = Net::FTP->new($config->{'host'}, Debug => 0, Passive => 0) ||
                die "Cannot connect to FTP host '$config->{'host'}: $@\n\n";
            $ftp->login($config->{'user'}, $config->{'password'}) ||
                die "Cannot login: ", $ftp->message . "\n\n";
            my $today = strftime("%A", localtime(time));
            $ftp->cwd($today) ||
                die "Cannot change working directory to '$today':", $ftp->message . "\n\n";
            $ftp->binary;
            # Download the CRTMIG.CSV file to the temporary filename
            $dlFile = $ftp->get("CRTMIG.ZIP", $filename) ||
                die "Unable to retrieve file 'CRTMIG.ZIP': ", $ftp->message . "\n\n";
            $ftp->quit;
        };
        
        if ($@) {
            $count++;
        } else {
            $success = 1;
        }
    }
    
    if ($success) {
        my $status = unzip $dlFile => "/var/tmp/CRTMIG.CSV" ||
            die "Unzip failed: $UnzipError\n\n";

        unlink $dlFile;

        return "/var/tmp/CRTMIG.CSV";
    } else {
        # Unable to download the file. Send a message and then bail
        my %sender = (
                      'fullname' => 'Jud12-Web',
                      'email_addr' => 'jterhune@jud12.flcourts.org'
                    );
        my $cc = [];
        my $subject = "ERROR - Unable to download file from Florida Bar";
        my $body = "We were unable to download the Bar Members feed from the Florida Bar. We tried $maxtries times.<br>";
        sendMessage(\@adminMails, \%sender, $cc, $subject, $body, undef, 0, 0);
        
        exit;
    }
}
