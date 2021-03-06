package Common;

use strict;
use warnings;
use Data::Dumper qw(Dumper);
use POSIX qw (strftime);
use Date::Calc qw (:all Parse_Date);
use DateTime;
use Carp qw(cluck);
use Net::FTP;
use Email::Valid;
use Template;
use MIME::Lite;
use File::Basename;
use HTML::Entities;
use IO::Handle;
use Text::CSV;
use MIME::Base64;
use HTML::Strip;
use File::Path qw (
    make_path
);
use JSON;
use XML::Simple;
use PHP::Session;
use CGI::Cookie;
use Sys::Hostname;

require Exporter;
our @ISA = qw(Exporter);

our $reportTopDir = "/var/www/Sarasota";

our @EXPORT_OK = qw(
    $templateDir
    doTemplate
    dumpVar
    inArray
    changeDate
    convertDates
    convertTimes
    escapeFields
    fatalError
    findMonFri
    getAge
    getArrayPieces
    logThis
    log_this
    logToFile
    @months
    printCell
    readCSV
    readHash
    readJsonFile
    redirectOutput
    sanitizeEmail
    sendMessage
    today
    transferFile
    writeDebug
    writeJsonFile
    ISO_date
    US_date
    buildName
    $tmpDir
    timeStamp
    @INACTIVECODES
    $INACTIVECODES
    @dorPIDMs
    @skipHack
    stripWhiteSpace
    writeXmlFile
    writeXmlFromHash
    readHashFromXml
    encodeFile
    makePaths
    prettifyString
    getConfig
    sanitizeCaseNumber
    @SCCODES
    returnJson
    getSystemType
    getFileType
    %courtTypes
    %portalTypes
    $reportTopDir
    uploadFile
    lastMonth
    convertCaseNumber
    isShowcase
	getShowcaseDb
	createTab
	getUser
	closeTab
	$session
	checkLoggedIn
	getSession
    readFileToHash
    writeFileFromHash
    verifyFieldsExist
    @adminMails
);

our %courtTypes = (
	'CF' => 'Circuit Criminal',
	'MM' => 'County Criminal',
	'MO' => 'County Criminal',
	'CT' => 'Criminal Traffic',
	'DR' => 'Domestic Relations/Family',
	'CA' => 'Circuit Civil',
	'SC' => 'County Civil',
	'TR' => 'Civil Traffic',
	'CP' => 'Probate',
	'GA' => 'Probate',
	'MH' => 'Probate',
	'CJ' => 'Juvenile Delinquency',
	'DP' => 'Juvenile Dependency',
	'CO' => 'County Criminal',
	'CC' => 'County Civil',
	'AP' => 'Appellate Criminal',
	'AP1' => 'Appellate Criminal',
	'AC' => 'Appellate Civil',
	'IN' => 'Civil Traffic',
	'4D' => 'Appellate Criminal',
	'WO' => 'Probate',
	'DA' => 'Domestic Relations/Family',
	'WP' => 'Circuit Civil'
);

our %portalTypes = (
	'Circuit Civil' => 'circuit_civil',
	'Foreclosure' => 'circuit_civil',
	'Felony' => 'circuit_criminal',
	'Circuit Criminal' => 'circuit_criminal',
	'Family' => 'family',
	'Juvenile Dependency' => 'dependency',
	'Probate' => 'probate',
	'County Civil' => 'county_civil',
	'Misdemeanor' => 'county_criminal',
	'County Criminal' => 'county_criminal',
	'Juvenile Delinquency' => 'delinquency',
	'Criminal Traffic' => 'criminal_traffic',
	'Appellate Civil' => 'circuit_civil',
	'Appellate Criminal' => 'circuit_criminal',
	'VA' => 'county_criminal',
	'Civil Traffic' => 'civil_traffic',
	'Domestic Relations/Family' => 'family'
);


# A listing of PIDMs to use to list DOR cases
our @dorPIDMs = (
	"'3572240'",
	"'9006538'"
);

our @SCCODES=(
    "'CF'",
    "'MM'",
    "'MO'",
    "'CO'",
    "'CT'",
    "'IN'",
    "'TR'",
	"'CA'",
	"'CC'",
	"'SC'",
	"'DR'",
	"'AP'",
	"'DP'",
	"'CP'",
	"'CJ'",
	"'MH'",
	"'GA'",
	"'AS'"
);

# A common directory for file creation
our $tmpDir = "/tmp";

our @months = (
	# Forces index to start from 1
	"",
	"Jan",
	"Feb",
	"Mar",
	"Apr",
	"May",
	"Jun",
	"Jul",
	"Aug",
	"Sep",
	"Oct",
	"Nov",
	"Dec"
);

our $templateDir = $ENV{'JVS_ROOT'} . "/templates";

# An array of statuses that we won't want in the pending reports but still need
# to exist in e-Service.  Stupid, stupid hack.
our @skipHack = (
	'TC'
);

#our $INACTIVECODES="('AS','CFDS','CLSD','DA','DADR','DAM','DAO','DAS','DB','DBDR','DBM','DBO','DBS','DD','DE','DJ','DM','DO','DY','GC','JC','JDF','JDIV','JNF','JPD','NJ','OPROB','OTCD','OTDF','PCA','PDAJ','PDC','PDDP','PDU','RD','TC','XX','ZVDS','PDAD','PDCF','PDCFN','PDSH','PDTPR','OGTP', 'ODTPR','SH')";
our $INACTIVECODES="('AS','CFDS','CLSD','DA','DADR','DAM','DAO','DAS','DB','DBDR','DBM','DBO','DBS','DD','DE','DJ','DM','DO','DY','GC','JC','JDF','JDIV','JNF','JPD','NJ','OPROB','OTCD','OTDF','PCA','PDAJ','PDC','PDDP','PDU','RD','TC','XX','ZVDS','PDAD','PDCF','PDCFN','PDSH','PDTPR')";
# Build @INACTIVECODES from $INACTIVECODES - I like working with arrays better
# than strings (more slexible), but there are a lot of pieces of code that
# use $INACTIVECODES.  Do this until they can all be fixed.
my $string = $INACTIVECODES;
# Strip the parens and quotes
$string =~ s/[\(\)\']//g;
# And split it up
our @INACTIVECODES = split(/,/, $string);

our @adminMails = (
	{
		'fullname' => 'Joe Terhune',
		'email_addr' => 'jterhune@jud12.flcourts.org'
	}
);

# Build the email address to use for sending messages
my $host = hostname;
my @pwent = getpwuid($>);

our %defSender = (
	'fullname' => $pwent[0],
	'email_addr' => $pwent[0] . '@' . $host
);


sub uploadFile {
    my $info = shift;
    my $paramname = shift;
    
    my %params = $info->Vars;
    
    my $filename = $params{$paramname};
    
    my $safe_filename_characters = "a-zA-Z0-9_.-";

	# Don't need the uploaded files visible to the webserver
	my $uploaduser = getUser();
	my $upload_base = $ENV{'JVS_DOCROOT'} . "/uploads";

	# Keep users from possibly stomping on each other's uploads
	my $upload_dir = "$upload_base/$uploaduser";
	if (!-d $upload_dir) {
		mkdir $upload_dir;
	}
    
    my ($name,$path,$extension ) = fileparse ( $filename, '\..*' );
    $filename = $name . $extension;
    
    # Sanitize the filename a bit
    $filename =~ tr/ /_/;
    $filename =~ s/[^$safe_filename_characters]//g;
    
	if ($filename =~ /^([$safe_filename_characters]+)$/) {
        $filename = $1;
    } else {
        return undef;
    }
    
    # Ok, we're here, so the filename is good.  Upload.
    my $upload_filehandle = $info->upload($paramname);
    my $targetFile = "$upload_dir/$filename";
    
    open (UPLOADFILE, ">$targetFile") ||
        die "Unable to upload file '$params{$paramname}: $!";
    binmode UPLOADFILE;
    while (<$upload_filehandle>) {
        print UPLOADFILE;
    }
    close UPLOADFILE;
    
    return $targetFile;
}

sub getConfig {
    my $configFile = shift;
    my @forceArrays = @_;
    
    my $xs = XML::Simple->new();
    my $xml;
    if (@forceArrays) {
        $xml = XMLin(
                     $configFile,
                     ForceArray => [ @forceArrays ]
                     );
    } else {
        $xml = XMLin(
                     $configFile
                     );
    }
    return $xml;
}

sub getSystemType {
    my $config = shift;
    
    if (!defined($config)) {
		$config = getConfig($ENV{'JVS_ROOT'} . "/conf/ICMS.xml");
    }
    
    if (defined($config->{'systemType'})) {
        return $config->{'systemType'};
    } else {
        return 'prod';
    }
}

sub getAge {
	my $indate = shift;

	if (defined $indate) {
		my ($yc,$mc,$dc)=Decode_Date_US($indate);
		if (defined $yc) {
			return Delta_Days($yc,$mc,$dc,Today());
		}
  }
  return 0;
}

sub getArrayPieces {
	my $arrayRef = shift;
	my $first = shift;
	my $count = shift;
	my $targetRef = shift;
	my $quote = shift;
	
	if (!defined($quote)) {
		$quote = 0;
	}

	my $end = $first + $count - 1;

	my @foo = @{$arrayRef}[$first..$end];

	foreach my $element (@foo) {
		next if (!defined($element));
		$element =~ s/^\s+//g;
		$element =~ s/\s+$//g;
		next if ($element eq "");
		if ($quote) {
			# String value - quote it
			push(@{$targetRef}, "'$element'");
		} else {
			# Numeric
			push(@{$targetRef}, $element);
		}
	}
}

sub fatalError {
	# Generic error displaying thingy.  Just pass it the error string, and let it do the magic.
	my $errorString = shift;
	my %data;
	$data{'errorString'} = $errorString;
	doTemplate(\%data,$templateDir,"error.html", 1);
}




sub logThis {
    my $logString = shift;

    # Don't log stuff from monitoring
    return if (getUser() eq "cad-nagios");

    my $dbh = dbconnect("icms");
    my $query = qq {
        insert into
            icms_log (icms_user, logstring, ipv4Addr)
        values
            (?,?,?)
    };
    my $sth = $dbh->prepare_cached($query);
    $sth->execute(getUser(),$logString,$ENV{'REMOTE_ADDR'});

    $dbh->disconnect();
}


sub logToFile {
	my $logString = shift;
	my $logFile = shift;

	if (!defined($logFile)) {
		$logFile = "/tmp/icms.log";
	}

	my $date = localtime();
	my $string = sprintf("%s: %d: %s\n", $date, $$, $logString);

	open (LOGFILE, ">>$logFile");
	print LOGFILE $string;
	close LOGFILE;
}


sub writeDebug {
    my $string = shift;

    open (OUTFILE, ">>/tmp/debug.out");
    my $outstring = sprintf ("%li %li '%s'\n", localtime(time), $$, $string);
    print OUTFILE "$$\t$string\n";
    close OUTFILE;
}

sub inArray {
    # Is the target element in the array?  Wants full, exact matches!

    my $arrayref = shift;
    my $target = shift;
	my $matchcase = shift;

	if (!defined($matchcase)) {
		$matchcase = 1;
	}

    if (!defined($target)) {
        return 0;
    }

    foreach my $element (@{$arrayref}) {
		if ($matchcase) {
			if ($element eq $target) {
			    # We have a match!
			    return 1;
			}
		} else {
			if ($element =~ /^\Q$target\E$/i) {
			    # We have a match!
			    return 1;
			}
		}
	}
    # No, it doesn't match anything in the array.
    return 0;
}


sub dumpVar {
    my $var = shift;

    print "<pre>\n";
    print Dumper $var;
    print "</pre>\n";
}

sub doTemplate {
    my $dataref = shift;
    my $inclDir = shift;
    my $templateFile = shift;
    my $printOutput = shift;

    my $tt = Template->new (
		{
			INCLUDE_PATH => $inclDir
		}
	);

	my $output;

	$tt->process(
		$templateFile,
		{
			data => $dataref
		}, \$output
	) || writeDebug($tt->error());

	if ($printOutput) {
		print $output;
		return undef;
	} else {
		return $output;
	}
}


sub printCell {
    # Used to print a single <td> in a table; handles the logic of determining
    # whether or not the value is an empty string, and prints &nbsp; if it is.
    # Otherwise, it prints the value.
    my $string = shift;
    my $cellparams = shift;

    if (defined($cellparams)) {
        print qq{
			<td $cellparams>
		};
    } else {
        print qq{
			<td>
		};
    }

    if ((defined($string)) && ($string ne "")) {
        print qq{
			$string
		};
    } else {
        print qq{
			&nbsp;
		};
    }

    print qq{
		</td>
	};
}

sub today {
	# Returns today's date in the format %m/%d/%Y
	return (strftime("%m/%d/%Y", localtime(time)));
}

sub timeStamp {
	# Returns current date and time.
	return (strftime("%Y-%m-%d %H:%M:%S", localtime(time)));
}


sub findMonFri {
	# Given a date (in format YYYY-MM-DD), find the Monday and Friday of that week,
	# returning them in the format YYYY-MM-DD.
	use Date::Calc qw (
		Monday_of_Week
		Week_of_Year
		Add_Delta_Days
	);
	my $date = shift;

	my ($tyear,$tmonth,$tday) = split(/-/, $date);
	my ($myear,$mmonth,$mday) = Monday_of_Week(Week_of_Year($tyear,$tmonth,$tday));
	my $monday = sprintf('%04d-%02d-%02d',$myear, $mmonth, $mday);
	my ($fyear,$fmonth,$fday) = Add_Delta_Days($myear,$mmonth,$mday,4);
	my $friday = sprintf('%04d-%02d-%02d',$fyear, $fmonth, $fday);

	return ($monday, $friday);
}


sub convertDates {
	# Since doing data conversions in M$ SQL Server is so expensive, just have the queries leave
	# them as SQL server datetime format, and convert them here.

	# This takes 2 or more arguments: The first is a reference to an array of hashes, such as would
	# be returned my sqlHashArray.  The second (and subsequent) will form an array of field
	# names that should be converted.
	my $dataRef = shift;
	my @fields = @_;

	return if (!scalar(@fields));

	if (ref($dataRef) eq "ARRAY") {
		foreach my $row (@{$dataRef}) {
			changeRow($row,\@fields);
		}
	} elsif (ref($dataRef) eq "HASH") {
		foreach my $key (keys %{$dataRef}) {
			my $row = $dataRef->{$key};
			changeRow($row,\@fields);
		}
	}
}

sub changeRow {
	my $row = shift;
	my $fieldRef = shift;

	if (ref($row) eq "HASH") {
		foreach my $field (@{$fieldRef}) {
			if ((defined($row->{$field})) && ($row->{$field} ne '')) {
				$row->{$field} = changeDate($row->{$field});
			}
		}
	} elsif (ref($row) eq "ARRAY") {
		foreach my $inner (@{$row}) {
			# Recursion!
			changeRow($inner,$fieldRef);
		}
	}
}

sub changeDate {
	my $date = shift;

	my ($year,$month,$day) = Parse_Date($date);

	if ((!defined($month)) || (!defined($year)) || (!defined($day))) {
		return '';
	}
	my $string = sprintf("%02d/%02d/%04d", $month, $day, $year);
	return $string;
}

sub ISO_date {
	# Takes a date in mm/dd/yyyy format and changes to yyyy-mm-dd
	my $date = shift;
	return undef if (!defined($date));	
	
	if ($date =~ /(\d\d)\/(\d\d)\/(\d\d\d\d)/) {
		return sprintf("%04d-%02d-%02d", $3, $1, $2);
	} elsif ($date =~ /(\d\d\d\d)-(\d\d)-(\d\d)/) {
		return $date;
	}else {
		# Didn't match the format.  Return null.
		return undef;
	}
}

sub US_date {
	# Takes a date in YYYY-MM-DD format and changes to mm/dd/yyyy
	my $date = shift;
	if ($date =~ /(\d\d\d\d)-(\d\d)-(\d\d)/) {
		return sprintf("%02d/%02d/%04d", $2, $3, $1);
	} elsif ($date =~ /(\d\d)\/(\d\d)\/(\d\d\d\d)/) {
		# Already in format
		return ($date);
	} else {
		# Didn't match the format.  Return null.
		return undef;
	}
}


sub convertTimes {
	# Since doing data conversions in M$ SQL Server is so expensive, just have the queries leave
	# them as SQL server datetime format, and convert them here.

	# This takes 2 or more arguments: The first is a reference to an array of hashes, such as would
	# be returned my sqlHashArray.  The second (and subsequent) will form an array of field
	# names that should be converted.
	my $dataRef = shift;
	my @fields = @_;

	return if (!scalar(@fields));

	if (ref($dataRef) eq "ARRAY") {
		foreach my $row (@{$dataRef}) {
			foreach my $field (@fields) {
				if ((defined($row->{$field})) && ($row->{$field} ne '')) {
					my @temp = split(/\s+/,$row->{$field});
					my $time = $temp[3];
					my($hr,$min,$sec,$junk) = split(/:/,$time);
					$row->{$field} = sprintf("%02d:%02d:%02d", $hr, $min, $sec);
				}
			}
		}
	} elsif (ref($dataRef) eq "HASH") {
		foreach my $key (keys %{$dataRef}) {
			my $row = $dataRef->{$key};
			foreach my $field (@fields) {
				if ((defined($row->{$field})) && ($row->{$field} ne '')) {
					my @temp = split(/\s+/,$row->{$field});
					my $time = $temp[3];
					my($hr,$min,$sec,$junk) = split(/:/,$time);
					$row->{$field} = sprintf("%02d:%02d:%02d", $hr, $min, $sec);
				}
			}
		}
	}
}

sub transferFile {
	# FTPs a file to the specified location
	my $file = shift;
	my $ftpConfig = shift;
	my $useASCII = shift;
	
	my $script = $0;
	my $msg;
	my $subject;
	
	if (!defined($useASCII)) {
		# Don't use ASCII transfers unless explicitly required.
		$useASCII = 0;
	}
	
	my $ftp = Net::FTP->new($ftpConfig->{'ftpHost'}, Debug => 0);
	if (!defined($ftp)) {
		$msg = sprintf("The FTP connection to %s failed, with the following error:\n\n%s", $ftpConfig->{'ftpHost'}, $@);
		$subject = sprintf("%s: Error connecting to FTP server.", $0);
		sendMessage(\@adminMails,\%defSender,undef,$subject,$msg,undef,0,0);
		die "Cannot connect to $ftpConfig->{'ftpHost'}: $@";
	}
	
	if (!$ftp->login($ftpConfig->{'ftpUser'}, $ftpConfig->{'ftpPass'})) {
		$msg = sprintf("The FTP LOGIN to %s failed, with the following error:\n\n%s", $ftpConfig->{'ftpHost'}, $ftp->message);
		$subject = sprintf("%s: Error logging in to FTP server.", $0);
		sendMessage(\@adminMails,\%defSender,undef,$subject,$msg,undef,0,0);
		die "Cannot login: ", $ftp->message;
	}
	
	if (!$ftp->cwd($ftpConfig->{'ftpDir'})) {
		$msg = sprintf("The FTP cwd command on %s failed (to directory %s), with the following error:\n\n%s",
					   $ftpConfig->{'ftpHost'}, $ftpConfig->{'ftpDir'}, $ftp->message);
		$subject = sprintf("%s: Changing directory on FTP server.", $0);
		sendMessage(\@adminMails,\%defSender,undef,$subject,$msg,undef,0,0);
		die "Cannot change working directory: ", $ftp->message;		
	}
	
	if ($useASCII) {
		$ftp->ascii;
	}
	
	my $result = $ftp->put($file);
	if (!defined($result)) {
		$msg = sprintf("The FTP PUT command on %s failed (file %s).\n\n",
							 $ftpConfig->{'ftpHost'}, $file);
		$subject = sprintf("%s: Error logging in to FTP server.", $0);
		sendMessage(\@adminMails,\%defSender,undef,$subject,$msg,undef,0,0);
		die "PUT of file '$file' failed: ", $ftp->message;	
	}
	
	$ftp->quit;
	
	$msg = sprintf("Transfer of file %s to server %s successful.", $file, $ftpConfig->{'host'});
	$subject = "FTP transfer complete";
	sendMessage(\@adminMails,\%defSender,undef,$subject,$msg,undef,0,0);
}

sub sanitizeEmail {
	my $email = shift;
	my @temp = split(/[;,\ ]+/, $email);
	foreach my $piece (@temp) {
		if (Email::Valid->address($piece)) {
			return $piece;
		}
	}
	return undef;
}


sub sendMessage {
	my $recips = shift;
	my $sender = shift;
	my $cc = shift;
	my $subject = shift;
	my $msgBody = shift;
	my $attachments = shift;
	# Whether or not to send the message as plain text.  Defaults to 0 (send text/html)
	my $plaintext = shift;
	# Whether or not to request a read receipt.  Defaults to 1 (request receipt)
	my $req_receipt = shift;

	if (!defined($plaintext)) {
		$plaintext = 0;
	}

	if (!defined($req_receipt)) {
		$req_receipt = 1;
	}

	my $count = 0;
	my $perMessage = 50;
	
	# USe the CC list up front, so we don't worry about sending it multiple times if we have to break up the recipient list
	my @temp;
	foreach my $recip (@{$cc}) {
		my $string;
		if ((defined($recip->{'fullname'}) && ($recip->{'fullname'} ne ''))) {
			$string = sprintf ("\"%s\" <%s>", $recip->{'fullname'}, $recip->{'email_addr'});
		} else {
			$string = sprintf ("<%s>", $recip->{'email_addr'});
		}
		push(@temp,$string);
	}
	my $ccString = join(", ", @temp);
	
	while ($count < scalar(@{$recips})) {
		my @recipTemp;
		getArrayPieces($recips, $count, $perMessage, \@recipTemp,0);
		
		my @recips;
		# Build the recipient string
		foreach my $recip (@recipTemp) {
			my $string;
			if ((defined($recip->{'fullname'}) && ($recip->{'fullname'} ne ''))) {
				$string = sprintf ("\"%s\" <%s>", $recip->{'fullname'}, $recip->{'email_addr'});
			} else {
				$string = sprintf ("<%s>", $recip->{'email_addr'});
			}
			if ($string ne '') {
				push(@recips,$string);
			}
			
		}
		my $recipString = join(", ", @recips);
	
		
		my $senderString;
		if ((defined($sender->{'fullname'}) && ($sender->{'fullname'} ne ''))) {
			$senderString = sprintf("\"%s\" <%s>", $sender->{'fullname'}, $sender->{'email_addr'});
		} else {
			$senderString = sprintf("<%s>", $sender->{'email_addr'});
		}
		
		# Create the message
		my $msg = MIME::Lite->new(
			From    => $senderString,
			To      => $recipString,
			Cc      => $ccString,
			Subject => $subject,
			Type    => 'multipart/mixed'
		);
		
		$msg->add("Importance" => "high");
		if ($req_receipt) {
			$msg->add("Disposition-Notification-To" => $sender->{'email_addr'});
		}
		$msg->add("X-Priority" => 1);
		
		# Attach the message body
		my $body = MIME::Lite->new(
			Type => 'multipart/alternative'
		);
		
		# Always do plaintext first
		my $attBody = $msgBody;
		if (!$plaintext) {
			my $hs = HTML::Strip->new();
			$attBody = $hs->parse($msgBody);
			$hs->eof;
		}
		
		my $att_plain = MIME::Lite->new(
										Type => 'text',
										Data => $attBody,
										Encoding => 'quoted-printable'
										);
		$att_plain->attr('content-type' => "text/plain; charset=UTF-8");
		$body->attach($att_plain);
		
		if (!$plaintext) {
			# Since the original isn't plaintext, we need to also attach it
			my $att = MIME::Lite->new(
									  Type => 'text',
									  Data => $msgBody,
									  Encoding => 'quoted-printable'
									  );
			$att->attr('content-type' => "text/html; charset=UTF-8");
			$body->attach($att);
		}
		
		$msg->attach($body);
		
		# And attach any attachments
		foreach my $attachment (@{$attachments}) {
			my $fname = basename($attachment->{'filename'});
			$msg->attach(
				Type => 'AUTO',
				Encoding => 'base64',
				Path => $attachment->{'filename'},
				Filename => $fname,
				Disposition => 'attachment'
			);
		}
		
		$msg->send("sendmail","/usr/lib/sendmail -tf $sender->{'email_addr'}");
		$ccString = "";
		$count += $perMessage;
	}
}

sub escapeFields {
	my $ref = shift;

	if (ref ($ref) eq "HASH") {
		foreach my $key (keys %{$ref}) {
			encode_entities($ref->{$key});
		}
	} elsif (ref($ref) eq "ARRAY") {
		for (my $count = 0; $count < scalar(@{$ref}); $count++) {
			encode_entities($ref->[$count]);
		}
	} else {
		encode_entities($$ref);
	}
}


#
# readHash reads a hash table from a file.  Similar to readhash() from ICMS.pm, but
# instead of returning a complete hash (a memory-intensitve operation), it instead
# takes a hash reference as one of the arguments and populates that hash.  It reads
# the same format of file that readhash() would read.
#

sub readHash {
    my $fname = shift;
	my $hashref = shift;
    open(HASHIN,$fname);
    foreach my $line (<HASHIN>) {
        chomp($line);
        my ($key,$rec) = split('`',$line);
        $hashref->{$key} = $rec;
    }
    close(HASHIN);

	# Return the number of records in the hash
	return scalar(keys(%{$hashref}));
}

sub redirectOutput {
	my $prog = shift;

	my $basepath = "$ENV{'JVS_PERL5LIB'}/results";

	open OUTPUT, '>', "$basepath/$prog.stdout.txt" ||
		die "Unable to redirect STDOUT to $basepath/$prog.stdout.txt: $!\n\n";

	open ERROR, '>', "$basepath/$prog.stderr.txt" ||
		die "Unable to redirect STDERR to $basepath/$prog.stderr.txt: $!\n\n";

	STDOUT->fdopen (\*OUTPUT, "w") ||
		die "Unable to redirect STDOUT to $basepath/$prog.stdout.txt: $!\n\n";

	STDERR->fdopen (\*ERROR, "w") ||
		die "Unable to redirect STDERR to $basepath/$prog.stderr.txt: $!\n\n";
}


# Read in a CSV file.
sub readCSV {
    # The CSV file containing the data to be read
    my $file = shift;
    # An array of the key names to be used for the hashes
    my $fieldnames = shift;
    # The array of hash refs, each corresponding to a CSV row
    my $valref = shift;
    # The key (optional) that will determine whether or not a given row is to
    # be imported.  If the row does not have a valued specified for the field,
    # then the line is not adde to the hash.
    my $reqKey = shift;
	my $charset = shift;

	if (!defined($charset)) {
		$charset = "utf8";
	}

    my $csv = Text::CSV->new ( { binary => 1 } ) ||
        die "Cannot use CSV: ".Text::CSV->error_diag ();

    $csv->column_names(@{$fieldnames});

    open my $fh, "<:encoding($charset)", $file ||
        die "Unable to open file '$file': $!";

    while (my $row = $csv->getline_hr($fh)) {
        if (defined($reqKey)) {
            if ($row->{$reqKey} ne "") {
                push(@{$valref}, $row);
            }
        } else {
            push(@{$valref}, $row);
        }
    }

    close ($fh);
}

sub buildName {
    # Builds a name string from the supplied person hash - required elements are FirstName and LastName, and
    # MiddleName is optional
    my $person = shift;
    my $lastFirst = shift;

    if (!defined($lastFirst)) {
        $lastFirst = 0;
    }
    
    my $name;

    if ((!defined($person->{'MiddleName'})) || ($person->{'MiddleName'} eq '')) {
        # No middle name specified; build from just the first and last
        if ($lastFirst) {
            if (defined($person->{'FirstName'})) {
                if ((defined($person->{'Suffix'})) && ($person->{'Suffix'} ne '')) {
                    $name = sprintf("%s %s, %s", $person->{'LastName'}, $person->{'Suffix'}, $person->{'FirstName'});
                } else {
                    $name = sprintf("%s, %s", $person->{'LastName'}, $person->{'FirstName'});
                }
            } else {
                $name = $person->{'LastName'};
            }
        } else {
            if (defined($person->{'FirstName'})) {
                if ((defined($person->{'Suffix'})) && ($person->{'Suffix'} ne '')) {
                    $name = sprintf("%s %s, %s", $person->{'FirstName'}, $person->{'LastName'}, $person->{'Suffix'});
                } else {
                    $name = sprintf("%s %s", $person->{'FirstName'}, $person->{'LastName'});
                }
            } else {
                $name = $person->{'LastName'}
            }
        }
        return $name;
    } else {
        if ((!defined($person->{'FirstName'})) || ($person->{'FirstName'} eq '')) {
            # No first name?  Must be a company name.  Just use the last name/
            $name = $person->{'LastName'};
            return $name;
        }
        # If we're here, we have all 3 names.  Just put them into the correct order.
        if ($lastFirst) {
            if ((defined($person->{'Suffix'})) && ($person->{'Suffix'} ne '')) {
                $name = sprintf("%s %s, %s %s", $person->{'LastName'}, $person->{'Suffix'}, $person->{'FirstName'},
                                $person->{'MiddleName'});
            } else {
                $name = sprintf("%s, %s %s", $person->{'LastName'}, $person->{'FirstName'},
                            $person->{'MiddleName'});
            }
        } else {
            if ((defined($person->{'Suffix'})) && ($person->{'Suffix'} ne '')) {
                $name = sprintf("%s %s %s, %s", $person->{'FirstName'}, $person->{'MiddleName'},
                                $person->{'LastName'}, $person->{'Suffix'});
            } else {
                $name = sprintf("%s %s %s", $person->{'FirstName'}, $person->{'MiddleName'},
                                $person->{'LastName'});
            }
        }
    }
    return $name;
}

sub stripWhiteSpace {
	# Strips leading/trailing whitespace from a string, and also compresses multiple whitespaces into a single
	# space
	my $string = shift;
	
	$string =~ s/^\s+//g;
	$string =~ s/\s+$//g;
	$string =~ s/\s+/ /g;
	$string =~ s/^\n+//g;
	
	return $string;
}


sub writeXmlFile {
    my $data = shift;
	my $exportHeaders = shift;
	
	if (!defined($data->{'name'})) {
		$data->{'name'} = '';
	}
	
    my $otherInfo = {
        "dTitle" => $data->{'dTitle'},
        "name" => $data->{'name'},
		"division" => $data->{'division'}
    };
    if ((defined ($data->{'limitdiv'})) && ($data->{'limitdiv'} ne "")) {
        $otherInfo->{'limitdiv'} = $data->{'limitdiv'};
    }
	if ((defined($data->{'DOB'})) && ($data->{'DOB'} ne "")) {
		$otherInfo->{'DOB'} = $data->{'DOB'};
	}
	if (defined($data->{'exportXMLdef'})) {
		$otherInfo->{'exportXMLdef'} = $data->{'exportXMLdef'};
	}
	if (defined($data->{'start'})) {
		$otherInfo->{'start'} = $data->{'start'};
	}
	if (defined($data->{'end'})) {
		$otherInfo->{'end'} = $data->{'end'};
	}
	
    
    my $fh = File::Temp->new (
                              UNLINK => 0,
                              DIR => "/tmp",
                              SUFFIX => '.xml'
    );
    my $filename = $fh->filename;
    # We only needed a unique name, so close the file.
    close ($fh);
    
    my $xs = XML::Simple->new(
        XMLDecl => 1,
		NoAttr => 1,
        KeepRoot => 1,
        RootName => 'SearchResult',
        OutputFile => $filename
    );
    
	if (defined($data->{'cases'})) {
		my $xml = $xs->XMLout({cases => $data->{'cases'},
							   otherInfo => $otherInfo,
							   exportHeaders => $exportHeaders} );
	} else {
		my $xml = $xs->XMLout({cases => $data,
							   otherInfo => $otherInfo,
							   exportHeaders => $exportHeaders} );
	}
    
    return $filename;
}

sub writeXmlFromHash {
	# Returns 1 on success; 0 on failure
	my $outputFile = shift;
	my $dataRef = shift;
	
	eval {
		my $xs = XML::Simple->new;
		
		my $xml = $xs->XMLout (
			$dataRef,
			"OutputFile" => $outputFile,
			"XMLDecl" => 1,
			"NoAttr" => 1
		);
	};
	
	if ($@) {
		print STDERR $@;
		return 0;
	}
	return 1;
}

sub readHashFromXml {
	my $xmlFile = shift;
	
	my $hashRef = {};
	
	eval {
		my $xs = XML::Simple->new;
		$hashRef = $xs->XMLin($xmlFile);
	};
	
	if ($@) {
		print STDERR $@;
		return undef;
	}
	
	return $hashRef;
}

sub encodeFile {
	my $inFile = shift;
	
	return undef if ((!defined($inFile)) || (!-e $inFile));
	
	local $/ = undef;
	open(INFILE, $inFile) ||
		die "Unable to open input file '$inFile': $!\n\n";

	binmode(INFILE);
	my $binary = <INFILE>;
	close INFILE;
	
	my $hex = encode_base64($binary);
	
	return $hex;
}

sub makePaths {
    my @dirs = @_;
    
    make_path (@dirs, {error => \my $err});
    if (@$err) {
        for my $diag (@{$err}) {
            my ($file, $message) = %{$diag};
            if ($file eq "") {
                print "Error: $message\n";
            } else {
                print "Unable to create directory $file: $message\n";
            }
        }
        exit;
    }
    return scalar(@dirs);
}

sub readJsonFile {
	# Reads a JSON file into $dataRef and returns the number of keys in the top element. Returns -1 on error (file
	# doesn't exist, etc.)
	my $dataRef = shift;
	my $jsonFile = shift;
	
	if ((!defined($jsonFile)) || (!-e $jsonFile)) {
		return -1;
	}
	
	local $/;
	open(my $fh, '<', $jsonFile);
	if (!$fh) {
		warn "Unable to open JSON file'$jsonFile' for reading: $!\n\n";
		return -1;
	}
	my $json_text = <$fh>;
	close $fh;
	my $ref = JSON->new->ascii->decode($json_text);
	foreach my $key (keys %{$ref}) {
		$dataRef->{$key} = $ref->{$key};
	}
	return scalar(keys(%{$dataRef}));
}

sub writeJsonFile {
	# Writes the data structure $dataRef to a JSON file
	my $dataRef = shift;
	my $jsonFile = shift;
    my $pretty = shift;
    
    if (!defined($pretty)) {
        $pretty = 1;
    }
    
    if (!defined($jsonFile)) {
        my $fh = File::Temp->new (
                                  UNLINK => 0,
                                  DIR => "/tmp",
                                  SUFFIX => '.json'
        );
        $jsonFile = $fh->filename;
        # We only needed a unique name, so close the file.
        close ($fh);
    }
    
	
	if (!open(JSONFILE, ">$jsonFile")) {
		warn "WARNING: Unable to create JSON file '$jsonFile': !\n\n";
		return undef;
	}
	my $json_text;
    if ($pretty) {
        $json_text = JSON->new->ascii->pretty->encode($dataRef);
    } else {
        $json_text = JSON->new->ascii->encode($dataRef);
    }
	print JSONFILE $json_text;
	close JSONFILE;
	
	return $jsonFile;
}

sub prettifyString {
	# Cleans up a string - probably used most commonly with case styles.
	my $inString = shift;
	
	my $newString = stripWhiteSpace($inString);
	
    $newString =~ s/_/ /g;
	my @pieces = split(",", $newString);
	$newString = join(", ", @pieces);
	return $newString;
}

sub sanitizeCaseNumber {
    my $casenum = uc(stripWhiteSpace(shift));
    
    # Strip leading "58" and any dashes.
    $casenum =~ s/^58//g;
    $casenum =~ s/-//g;
    
    if ($casenum =~ /^(\d{1,6})(\D\D)(\d{0,6})(.*)/) {
        my $year = $1;
        my $type = $2;
        my $seq = $3;
        my $suffix = $4;
        
        # If we have a 2-digit year, adjust it (we'll use 60 as the split point)
        if ($year < 100) {
            if ($year > 60) {
                $year = sprintf("19%02d", $year);
            } else {
                $year = sprintf("20%02d", $year);
            }
        }
        
        if (inArray(\@SCCODES,"'$type'")) {
            # If it's a Showcase code, prepend the 58
            $year = sprintf("58-%04d", $year);
            if ($suffix =~ /(\w\w\w\w)(\D\D)/) {
                $suffix = sprintf("%s-%s", $1, $2);
            }
        } elsif ($type eq "AP") {
			if ($seq > 900000) {
				# It's a criminal appeal
				$year = sprintf("58-%04d", $year);
				if ($suffix =~ /(\w\w\w\w)(\D\D)/) {
					$suffix = sprintf("%s-%s", $1, $2);
				}
			}
		}
        
        
        if ((!defined($suffix)) || ($suffix eq ''))  {
            return sprintf("%s-%s-%06d", $year, $type, $seq);
        } else {
            return sprintf("%s-%s-%06d-%s", $year, $type, $seq, $suffix);
        }  
    }
}

sub convertCaseNumber {
    my $casenum = shift;
	my $btoSC = shift;
	
	if (!defined($btoSC)) {
		$btoSC = 0;
	}
    
    # Sometimes, Banner case numbers are stored in the XXXX-XX-XXXXXX format; Banner uses
    # them without the dashes.  This routine will be called when we need to be sure
    # the number we're working with has the dashes.
    if ($casenum =~ /(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)/) {
        return sprintf("%04d-%s-%06d", $1, $2, $3);
    }
	elsif($btoSC eq 1 && ($casenum =~ /(\d\d)-(\d\d\d\d)-(\D\D)-(\d\d\d\d\d\d)-(\D\D\D\D)-(\D\D)/)){
		return sprintf("%04d-%s-%06d", $2, $3, $4);
	}else {
        # No change necessary.  Return the original case
        return $casenum;
    }
}

sub getFileType {
    my $filename = shift;
    
    return undef if (!defined($filename));
    
    my %extensionTypes = (
        'doc' => 'application/ms-word',
        'docx' => 'application/ms-word',
        'pdf' => 'application/pdf'
    );
    
    my @tmp = split('\.', $filename);
    my $extension = $tmp[scalar(@tmp) - 1];
    
    if (defined($extensionTypes{$extension})) {
        return $extensionTypes{$extension};
    } else {
        return undef;
    }
}


sub returnJson {
    my $ref = shift;
    
    my $json = JSON->new->allow_nonref;
    print "Content-type: application/json\n\n";
    print $json->encode($ref);
}


sub lastMonth {
    my $timeStr = DateTime->now()->subtract( months => 1 );
    
    my @pieces = split("-", $timeStr);
    
    return sprintf("%04d-%02d", $pieces[0], $pieces[1]);
}

sub isShowcase {
    my $casenum = shift;
    
    my $testCn = sanitizeCaseNumber($casenum);
    if ($testCn =~ /^58/) {
        return 1;
    }
    return 0;
}

sub getShowcaseDb {
    # Get the name of the Showcase DB from the ICMS.xml file
    my $xml = XMLin($ENV{'JVS_ROOT'} . "/conf/ICMS.xml");
    if (!defined($xml->{'showCaseDb'})) {
        return ("showcase-prod");
    }
    return $xml->{'showCaseDb'};
}

sub createTab {
	my $tabName = shift;
	my $href = shift;
	my $active = shift;
	my $close = shift;
	my $parent = shift;
	my $tabs = shift;
	my $session = getSession();

	my $sess_tabs = $session->get('tabs');
	my $next_key = scalar(keys %{$sess_tabs});
	
	#Deactivate all tabs
	foreach my $key (keys %{$sess_tabs}){
		$sess_tabs->{$key}->{'active'} = 0;
		
		if($sess_tabs->{$key}->{'name'} eq $tabName){
			$next_key = $key;
		}
		
		foreach my $t_key (keys %{$sess_tabs->{$key}->{'tabs'}}){
			$sess_tabs->{$key}->{'tabs'}->{$t_key}->{'active'} = 0;
		}
	}
	
	my $keepTabs;
	if(defined($sess_tabs->{$next_key}->{'tabs'})){
		$keepTabs = $sess_tabs->{$next_key}->{'tabs'};
		
		$sess_tabs->{$next_key} = { 
			"name" => $tabName,
			"active" => $active,
			"close" => $close,
			"href" => $href,
			"parent" => $parent,
			"tabs" => $keepTabs
		};
	} else{
	
		$sess_tabs->{$next_key} = { 
			"name" => $tabName,
			"active" => $active,
			"close" => $close,
			"href" => $href,
			"parent" => $parent
		};
	
	}

	if(defined($tabs)){
		my $tab_key = scalar(keys %{$sess_tabs->{$next_key}->{'tabs'}});
		
		foreach my $tkey (keys %{$sess_tabs->{$next_key}->{'tabs'}}){
			if($sess_tabs->{$next_key}->{'tabs'}->{$tkey}->{'name'} eq $tabs->{'name'}){
				$tab_key = $tkey;
			}
		}
		
		$sess_tabs->{$next_key}->{'tabs'}->{$tab_key} = (
			{
				"name" => $tabs->{'name'},
				"active" => $tabs->{'active'},
				"close" => $tabs->{'close'},
				"href" => $tabs->{'href'},
				"parent" => $tabs->{'parent'}
			}
		);
	}
	
	my $sorted_tabs;
	my $count = 0;
	foreach my $t (sort keys %{$sess_tabs}){
		$sorted_tabs->{$count} = $sess_tabs->{$t};
		$count++;
	}
	
	$session->set("tabs", $sorted_tabs);
	$session->save();
}

sub getUser{
	my $session = getSession();
	if($session ne ""){
		my $user = $session->get('user');
		return $user;
	}
	else{
		checkLoggedIn();
	}
	
}

sub closeTab{
	my $type = shift;
	my $outer_key = shift;
	my $inner_key = shift;
	my $location;
	my $parent;
	my $session = getSession();
	my $newOuter = 0;
	
	if(defined($session) && ($session ne "")){
		my $sess_tabs = $session->get('tabs');
		
		if($sess_tabs ne ""){
			if($type eq "outer"){
				$parent = $sess_tabs->{$outer_key}->{'parent'};
				delete $sess_tabs->{$outer_key};
				
				my $t;
				my $tabCount = 0;
				my $lowestKey;
				foreach my $key (keys %$sess_tabs) {
					if($sess_tabs->{$key}->{'parent'} eq $parent){
						if(!$lowestKey || ($key < $lowestKey)){
							$lowestKey = $key;
						}
						$tabCount++;
					}
				}
				
				#We still have tabs open under this parent
				if($tabCount > 0){
					$outer_key = $lowestKey;
				}
				
				if(($sess_tabs->{$outer_key}->{'href'} ne "") && ($sess_tabs->{$outer_key}->{'parent'} eq $parent)){
					$sess_tabs->{$outer_key}->{'active'} = 1;
					$location = $sess_tabs->{$outer_key}->{'href'};
				}
				else{
					$sess_tabs->{0}->{'active'} = 1;
					$location = "/tabs.php";
				}
			}
			else{
				$parent = $sess_tabs->{$outer_key}->{'tabs'}->{$inner_key}->{'parent'};
				
				delete $sess_tabs->{$outer_key}->{'tabs'}->{$inner_key};
				if(scalar(keys %{$sess_tabs->{$outer_key}->{'tabs'}}) < 1){
					#This was the last inner tab, we're deleting the outer tab, too
					delete $sess_tabs->{$outer_key};
					$newOuter = 1;
				}
				
				#Now we need to move to a new outer tab
				if($newOuter){
					while(!defined($sess_tabs->{$outer_key}) && ($outer_key > '0')){
						$outer_key--;
					}
					
					$parent = $sess_tabs->{$outer_key}->{'parent'};
				
					if(($sess_tabs->{$outer_key}->{'href'} ne "") && ($sess_tabs->{$outer_key}->{'parent'} eq $parent)){
						$sess_tabs->{$outer_key}->{'active'} = 1;
						$location = $sess_tabs->{$outer_key}->{'href'};
					}
					else{
						$sess_tabs->{0}->{'active'} = 1;
						$location = "/tabs.php";
					}
				}
				else{
					#We are staying with the same outer tab, but need to move to a new inner tab
					while(!defined($sess_tabs->{$outer_key}->{'tabs'}->{$inner_key}) && ($inner_key > '0')){
						$inner_key--;
					}
					
					if(($sess_tabs->{$outer_key}->{'tabs'}->{$inner_key}->{'href'}) ne "" && 
						($sess_tabs->{$outer_key}->{'tabs'}->{$inner_key}->{'parent'} eq $parent)){
						$sess_tabs->{$outer_key}->{'tabs'}->{$inner_key}->{'active'} = 1;
						$location = $sess_tabs->{$outer_key}->{'tabs'}->{$inner_key}->{'href'};
					}
					else{
						$sess_tabs->{0}->{'active'} = 1;
						$location = "/tabs.php";
					}
				}
				
			}
			
			#Erase bad data
			foreach my $tab_key (keys %{$sess_tabs}){
				if(!defined($sess_tabs->{$tab_key}->{'name'}) || ($sess_tabs->{$tab_key}->{'name'} eq "") || ($tab_key < 0)){
					delete $sess_tabs->{$tab_key};
				}
				
				if(defined($sess_tabs->{$tab_key}->{'tabs'})){
					foreach my $inner_tab_key (keys %{$sess_tabs->{$tab_key}->{'tabs'}}){
						if(!defined($sess_tabs->{$tab_key}->{'tabs'}->{$inner_tab_key}->{'name'}) 
							|| ($sess_tabs->{$tab_key}->{'tabs'}->{$inner_tab_key}->{'name'} eq "") || ($inner_tab_key < 0)){
							delete $sess_tabs->{$tab_key}->{'tabs'}->{$inner_tab_key};
						}
					}
				}
			}
			
			#Sort them by key
			my $sorted_tabs;
			my $count = 0;
			foreach my $t (sort keys %{$sess_tabs}){
				if(defined($sess_tabs->{$t}->{'name'})){
					$sorted_tabs->{$count} = $sess_tabs->{$t};
					$count++;
				}
			}
			
			$session->unregister("tabs");
			$session->set("tabs", $sorted_tabs);
			$session->save();
		
			return $location; 
		}
		else{
			$location = "/tabs.php";
			return $location;
		}
	}
	else{
		$location = "/tabs.php";
		return $location;
	}
}

sub checkLoggedIn {
	my $session = getSession();
	my $MAX_INACTIVE = 28800;
	my $reqPage = $ENV{'REQUEST_URI'};
	my $url;
	my $info = new CGI;
	
	if($session eq ""){
		if($reqPage ne ""){
			$url = "/cgi-bin/logout.cgi?timeout=1&ref=" . $reqPage;
		}
		else{
			$url = "/cgi-bin/logout.cgi?timeout=1";
		}
		
		print $info->redirect(-uri => $url);
		exit;
	}

	if (!defined($session->get('LASTACTIVITY'))) {
		$session->set('LASTACTIVITY', time());
	} elsif ((time() - $session->get('LASTACTIVITY')) > $MAX_INACTIVE) {
		$session->set('LASTACTIVITY', time());
		
		if($reqPage ne ""){
			$url = "/cgi-bin/logout.cgi?timeout=1&ref=" . $reqPage;
		}
		else{
			$url = "/cgi-bin/logout.cgi?timeout=1";
		}
		
		print $info->redirect(-uri => $url);
		exit;
	} else {
		$session->set('LASTACTIVITY', time());
	}

	if (!defined($session->get('user'))) {
		if($reqPage ne ""){
			$url = "/login.php?&ref=" . $reqPage;
		}
		else{
			$url = "/login.php";
		}
		
		print $info->redirect(-uri => $url);
		exit;
	}
	else{
		$ENV{'USER'} = $session->get('user');
	}

	#Ok to proceed.
	return 1;
}

sub getSession{
	my %cookies = fetch CGI::Cookie;
	my $session;
	
	if(defined($cookies{PHPSESSID}) && (-e "/var/lib/php/session/sess_" . $cookies{PHPSESSID}->value)){
		$session = PHP::Session->new($cookies{PHPSESSID}->value, {save_path =>'/var/lib/php/session/', auto_save => 1});
	}
	else{
		$session = "";
	}
	
	return $session;
}

# Similar to the difference between sqlHashArray() and sqlHashHash(), this
# function performs essentially the same function as readHashArray(), but
# instead of populating an array of hash references, it populates a hash ref
# with additional hash refs, keyed on the $hashkey value.
sub readFileToHash {
	my $hashfile = shift;
    my $hashref = shift;
    my $delimiter = shift;
    my @fields = @_;

    my $hashkey = $fields[0];

    if (!open (INFILE, $hashfile)) {
        print "Unable to open input file '$hashfile': $!\n";
        return 0;
    }

    while (my $line = <INFILE>) {
        chomp $line;
        my @temp = split(/$delimiter/, $line, -1);
        my $count = 0;
        my $datahash = {};
        foreach my $field (@fields) {
            $datahash->{$field} = $temp[$count++];
        }
        $hashref->{$datahash->{$hashkey}} = $datahash;
    }
    close INFILE;
    return 1;
}

sub writeFileFromHash {
	# Improved version of writehash.  Instead of accepting a hash, it accepts
	# a reference to an array of hashes, as returned from sqlHashArray().  This
	# offers greater flexibility - instead of having a pre-built hash, keyed on
	# a single element and having a lot of tilde-delimited strings, it iterates
	# through the array and builds the strings as it likes (allowing reuse of
	# arrays)
	# Arguments are the array reference, and then the name of the file to be
	# created, and then hash fields that we'll want to deal with, in the order
	# we'd like to deal with them
	my $hashref = shift;
	my $hashfile = shift;
	my $keep = shift;
	my $first = shift;
	my @fields = @_;

	if ((defined($first)) && scalar(@fields)) {
		# Create a temporary file in the target directory, to avoid race conditions
		my $dir = dirname($hashfile);

		my $fh = File::Temp->new(
			DIR => $dir,
			UNLINK => 0
		);

		my $fname = $fh->filename;

		# No sense trying to process them if we don't have any field names
        foreach my $row (sort keys %{$hashref}) {
            print $fh $hashref->{$row}->{$first} . "`";
            my @stringArray;
            foreach my $field (@fields) {
                push(@stringArray,$hashref->{$row}->{$field});
            }            
            print $fh join("~",@stringArray) . "\n";   
		}
		close ($fh);

		# Make the file readable
		chmod(0644,$fname);
		# Clean up
		if ($keep) {
			# We've been asked to keep the original file.  Back it up using the
			# old file's mtime
			if (!keepOldFile($hashfile)) {
				print "Backup of original file '$hashfile' was requested, but the ".
					"backup failed.  No action taken.\n";
				return 0;
			}
		} else {
			# Not asked to keep the old file.  Remove it.
			if ((-e $hashfile) && (!unlink($hashfile))) {
				print "Unable to remove original file '$hashfile'.  No action ".
					"taken.\n";
				return 0;
			}
		}
		# Rename the temp file.
		if (!rename($fname, $hashfile)) {
			print "Unable to rename temp file '$fname' to '$hashfile'.  You ".
				"should manually rename the file if you need it.\n";
			return 0;
		} else {
			return 1;
		}
	} else {
		# Nothing was done
		return 0;
	}
}


sub verifyFieldsExist {
    # Just ensure that a field in a hash exists; create it as an empty string if not
    my $hashref = shift;
    my $fields = shift;
    
    my $changed = 0;
    
    foreach my $field (@{$fields}) {
        if (!defined($hashref->{$field})) {
            $hashref->{$field} = '';
            $changed = 1;
        }
    }
    
    return $changed;
}


1;
