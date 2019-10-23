#!/usr/bin/perl -w

BEGIN {
	use lib "$ENV{'JVS_PERL5LIB'}";
}

use strict;
#use ICMS;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use File::Temp;
use File::Basename;
use Date::Calc qw(:all Date_to_Text_Long);

use Images qw (
	buildImageFile
	pdf_info
);

use DB_Functions qw (
	dbConnect
	getDbSchema
    eFileInfo
    ldapLookup
	getDataOne
);

use Common qw (
	doTemplate
	dumpVar
	prettifyString
    getConfig
    $templateDir
	buildName
	getUser
);

use Orders qw (
	buildAddrList
	buildChildren
	buildRelCases
	createEnvelopes
	getCaseInfo
	getDocInfo
	getLinkedCases
	getParties
	getSigImage
);

use Showcase qw (
	$db
);

use Date::Calc qw(:all Month_to_Text);

use MIME::Base64;

my $config = getConfig("$ENV{'JVS_ROOT'}/etc/ICMS.xml");

my $info = new CGI;

my %params = $info->Vars;

my $docketDesc = $params{'formdesc'};
my $portalDesc = $params{'docketDesc'};

my $canEfile = ($portalDesc ne '') ? 1 : 0;
my $canEserve = 0;

print $info->header;

my %pageData;

my $eFileInfo;
if ($canEfile) {
    # Another layer - the user has to exist in the portal info DB.
    my $user = getUser();
    my $dbh = dbConnect("portal_info");
    $eFileInfo = eFileInfo($user,$dbh);
    if (!defined($eFileInfo)) {
        $canEfile = 0;
    } 
}

my $returnAddress = $params{'returnAddr'};

my $dbtype;

# Which script - order.cgi or scorder.cgi - called me?
my ($url,$get) = split(/\?/, $ENV{'HTTP_REFERER'},2);
my $referer = basename($url);

my $schema;
my $DB;


$dbtype = $db;
$DB = "showcase";
$schema = getDbSchema($db);

my $dbh = dbConnect($dbtype);

$ENV{PATH} .= ":/usr/local/bin";

my @kids;

buildChildren($info,\@kids);

$pageData{'UCN'} = $params{'extendedcaseid'};
$pageData{'CaseNumber'} = $params{'caseid'};
$pageData{'FormName'} = $params{'formdesc'};

my %data;
$data{'kids'} = \@kids;

# Now push all of the other values onto the %data hash.
#my $params = $info->Vars;

foreach my $param (keys %params) {
	if ($params{$param} ne '') {
		$data{$param} = $params{$param};
		$data{$param} =~ s/\r\n/\\line /g;
	}
}

my $casenum = $params{'caseid'};
my $CaseNum = $params{'ucn'};

getParties($casenum,$dbh,\%data,$schema, $DB);

foreach my $partyType('PLT','DFT','PET','RESP','HYBRID') {
	if (defined($data{$partyType})) {
		my $short = $partyType . "SHORT";
		$data{$short} = shortPartyString($data{$partyType});
		my $long = $partyType . "LONG";
		$data{$long} = longPartyString($data{$partyType});
	}
	
}

getCaseInfo($casenum,$dbh,\%data,$schema, $DB);
getLinkedCases($CaseNum,$dbh,\%data, $DB, $schema);

$pageData{'DivisionID'} = $data{'DivisionID'};
$pageData{'DBtype'} = $DB;

my @relcases;
buildRelCases($info,\@relcases);
$data{'relcases'} = \@relcases;

$data{'addressList'} = [];
$data{'ccAddressList'} = [];
buildAddrList($info,$data{'addressList'},$data{'ccAddressList'});

$data{'extraCCList'} = [];

my($i,$addrline);
my $numextracc = $params{'numextracc'};

for ($i=0;$i<$numextracc;$i++) {
	if ((defined $info->param("eccheck$i")) && ($info->param("eccheck$i") eq "on")) {
		# build addr list for cc section
		$addrline=prettifyString($info->param("ecaddr$i"));
		if($addrline ne '') {
			push(@{$data{'extraCCList'}},$addrline);
	    }
	}
}

# Generate the RTF output and write it to a temp file

my $template = $params{'rpttype'} . ".rtf";

my ($YEAR,$MONTH,$DAY)=Today();

$data{'Month'} = Month_to_Text($MONTH);
$data{'Year'} = $YEAR;
$data{'Day'} = $DAY;
$data{'today'} = sprintf("%s day of %s, %s",English_Ordinal($DAY),Month_to_Text($MONTH),$YEAR);
$data{'usdate'} = sprintf("%02d/%02d/%04d", $MONTH, $DAY, $YEAR);

# Remove "JUDGE"
if (defined($data{'JUDG'})) {
	$data{'JUDG'} =~ s/^JUDGE\s*//i;
	$data{'Judg'} = lc($data{'JUDG'});
	$data{'Judg'} =~ s/\b(\w)/\U$1/g;
} else {
	$data{'JUDG'} = "";
}

if ($data{'isCircuit'} eq '1') {
	$data{'TITLE'} = "Circuit Judge";
} else {
	$data{'TITLE'} = "County Court Judge";
}

my $user = getUser();

# Don't really care for this, but we need to have a way of handling THO Sara Blumberg while also allowing Judges to issue Traffic orders.
if ($user =~ /sblumberg/i) {
    $data{'JUDG'} = "SARA BLUMBERG";
    $data{'TITLE'} = "Traffic Hearing Officer";
} elsif ($data{'rpttype'} =~ /^tr-/i) {
    # For traffic orders, look up the user in AD.  If the user's title is "Traffic Hearing Officer", set that user's name for JUDG and
    # set THO for TITLE.
    
    # If the user is NOT a THO, dislay the divisional judge
    
    my $adRec = [];
    my $filter = sprintf("sAMAccountName=%s", $user);
    my $fields = ['givenName','initials','sn','title','mail'];
    ldapLookup($adRec, $filter, undef, $fields);
    my $temp = $adRec->[0];
    if ($temp->{'title'} =~ /Traffic Hearing Officer/i) {
        if (defined($temp->{'initials'})) {
            $data{'JUDG'} = uc(sprintf("%s %s. %s", $temp->{'givenName'}, $temp->{'initials'}, $temp->{'sn'}));
        } else {
            $data{'JUDG'} = uc(sprintf("%s %s", $temp->{'givenName'}, $temp->{'sn'}));
        }
        $data{'TITLE'} = $temp->{'title'};
    }
}

#my $sigfile = undef;
$data{'SIGNATURE'} = "_______________________________________";

if ((defined($params{'usees'})) && ($params{'usees'} == 1)) {
	my $siguser = $params{'signAs'};	
	
	# Look up the information on the signature user
	my $adRec = [];
	my $filter = sprintf("sAMAccountName=%s", $siguser);
    my $fields = ['givenName','initials','sn','title','mail'];
    ldapLookup($adRec, $filter, undef, $fields);
    my $temp = $adRec->[0];
	if ($temp->{'title'} =~ /judge/i) {
		if ($data{'isCircuit'} eq '1') {
			$data{'TITLE'} = "Circuit Judge";
		} else {
			$data{'TITLE'} = "County Court Judge";
		}
	} elsif ($siguser =~ /sblumberg/i) {
		$data{'TITLE'} = "Traffic Hearing Officer";
	} else {
		$data{'TITLE'} = $temp->{'title'};
	}
	
	($data{'SIGNATURE'}, $data{'JUDG'}) = getSigImage($siguser, $data{'extendedcaseid'},$data{'TITLE'},
													  getUser(),1);
	$pageData{'eFileInfo'} = $eFileInfo;
	$canEserve = 1;
} else {
	$canEfile = 0;
}

$canEserve = 0;

$data{'ADACoordinator'} = $config->{'ADACoordinator'};

my $rtf = doTemplate(\%data,"$ENV{'JVS_ROOT'}/cgi-bin/orders/templates",$template,0);

my $tmpdir = "/tmp";

if ((defined ($params{'genrtf'})) && ($params{'genrtf'} eq "on")) {
	# We usually want to generate these files into /tmp, but if the user is
	# bypassing PDF creation and just generating an RTF, then we'll want that put
	# inside the webspace without having to move it (which might cross a
	# filesystem boundary and take time)
	$tmpdir = "/var/www/html/tmp";
}

my $fh = File::Temp->new (
	UNLINK => 0,
	DIR => $tmpdir,
	SUFFIX => ".rtf"
);
my $rtfname = $fh->filename;
print $fh $rtf;
close $fh;

if ((defined ($info->param('genrtf'))) && ($info->param('genrtf') eq "on")) {
	$data{'formdesc'} =~ s/\//-/g;
	
	# User selected option to just generate RTF instead of PDF.
	my $newname;
	if (defined($data{'DFT'})) {
		my $dftname;
		if (ref($data{'DFT'}) eq "ARRAY") {
			$dftname = $data{'DFT'}->[0];
		} else {
			$dftname = $data{'DFT'};
		}
		$dftname =~ s/[\/\#\%]/-/g;
	    $newname = sprintf("%s/%s-%s-%s.rtf", $tmpdir, $dftname, $casenum, $data{'formdesc'});
	} else {
		$newname = sprintf("%s/%s-%s.rtf", $tmpdir, $casenum, $data{'formdesc'});
	}
	
	$newname =~ s/\s+/_/g;

	rename($rtfname,$newname);
	$rtfname = $newname;
	my $tempname = basename($rtfname);

	my $protocol = "http";
    if (defined $ENV{'HTTPS'}) {
        $protocol = "https"
    }
    my $url = sprintf("%s://%s/tmp/%s", $protocol, $ENV{'HTTP_HOST'}, $tempname);
	print $info->redirect(-uri => $url, -attachment => $tempname, -Foo => "Bar", -type => 'application/rtf');
	exit;
}

my @images; # Just so we can use the existing buildImageFile() in ICMS.pm
my @documents;

# The list of PDFs that are generated, which will be combined into a single
# PDF at the end.
my $listfh = new File::Temp (
	UNLINK => 0,
	DIR => "/tmp"
	);
my $listfn = $listfh->filename;

# Now generate the PDF from the temp file.
my $pdfname = $rtfname . ".pdf";

my $command = "/usr/share/Ted/examples/rtf2pdf.sh --paper letter $rtfname $pdfname";

print $info->header;
my $result = system($command);

my $numcopies = 1;

if ((defined ($info->param('pcopies'))) && ($info->param('pcopies') eq "on")) {
	$numcopies = scalar(@{$data{'addressList'}}) + 1;
}

if (!$result) {
	for (my $count = 1; $count <= $numcopies; $count++) {
		print $listfh $pdfname . "\n";
		push (@images, $pdfname);
		my $formdesc;
		if ($count == 1) {
			$formdesc = $data{'formdesc'} . " - Case No: $data{ucn}";
		} else {
			$formdesc = $data{'formdesc'} . " - Case No: $data{ucn} - COPY";
		}
		getDocInfo($pdfname, \@documents, $formdesc);
	}
}

# Do we need to generate envelopes?
my $envelopes = undef;
my $envPrint = 0;
if ((defined ($info->param('penvelopes'))) && ($info->param('penvelopes') eq "on")) {
	if ((scalar(@{$data{addressList}})) && (defined($returnAddress))) {
		$envelopes = createEnvelopes($data{'addressList'},undef,$returnAddress);
		print $listfh $envelopes . "\n";
		push (@images, $envelopes);
		getDocInfo($envelopes, \@documents, "ENVELOPES");
		$envPrint = 1;
	}
}

# How about an address list page?
if ((defined ($info->param('paddresses'))) && ($info->param('paddresses') eq "on")) {
	# Generate the RTF output and write it to a temp file
	my $template = "addressList.rtf";

	my $rtf = doTemplate(\%data,"$ENV{'JVS_ROOT'}/cgi-bin/orders/templates",$template,0);

	my $fh = File::Temp->new (
							  UNLINK => 0,
							  DIR => "/tmp"
							  );

	my $rtfname = $fh->filename;
	print $fh $rtf;
	close $fh;

	# Now generate the PDF from the temp file.
	my $pdfname = $rtfname . ".pdf";
	my $command = "/usr/share/Ted/examples/rtf2pdf.sh $rtfname $pdfname";
	my $result = system($command);

	if (!$result) {
		print $listfh $pdfname . "\n";
		push (@images, $pdfname);
		getDocInfo($envelopes, \@documents, "ADDRESS LIST");
	}
}


close $listfh;

my $finalPdf = buildImageFile($listfn,\@images,\@documents,$info->param('ucn'),undef,undef,$envPrint);

my $sanitized = $data{'formdesc'};
$sanitized =~ s/[\/\#\%]/-/g;

my $newname;
if (defined($data{'DFT'})) {
	my $dftname;
	if (ref($data{'DFT'}) eq "ARRAY") {
		$dftname = $data{'DFT'}->[0];
	} else {
		$dftname = $data{'DFT'};
	}
	$dftname =~ s/[\/\#\%]/-/g;
	$newname = sprintf("tmp/%s-%s-%s.pdf", $dftname, $casenum, $sanitized);
} else {
	$newname = sprintf("tmp/%s-%s.pdf", $casenum, $sanitized);
}

$newname =~ s/\s+/_/g;

rename("$ENV{'JVS_DOCROOT'}/$finalPdf", "$ENV{'JVS_DOCROOT'}/$newname");
$finalPdf = $newname;

print $info->header;

my $protocol = "http";
if (defined $ENV{'HTTPS'}) {
	$protocol = "https"
}

$pageData{'canEserve'} = $canEserve;
;
if ($canEfile || $canEserve)  {
	$pageData{'pdf'} = $finalPdf;
	$pageData{'docketDesc'} = $docketDesc;
	$pageData{'portalDesc'} = $portalDesc;
	$pageData{'docketGroup'} = "Judiciary";
	print $info->header;	
    doTemplate(\%pageData,"$templateDir/portal", "odpRedirect.tt", 1);
    exit;
}

$url = sprintf("%s://%s/%s", $protocol, $ENV{'HTTP_HOST'}, $finalPdf);

print $info->redirect(-uri => $url, -attachment => $finalPdf, -Foo => 'Baz');
exit;


sub shortPartyString {
	my $partyref = shift;
	
	if (ref($partyref) eq "ARRAY") {
		my $partycount = scalar(@{$partyref});
		
		if ($partycount == 2) {
			# If there are only 2, return the names separated by "and"
			return join(" and ", @{$partyref});
		} elsif ($partycount == 3) {
			# Separate the first two by commas, and the last one with "and"
			my $string = sprintf("%s, %s and %s", @{$partyref});
			return $string;
		} elsif ($partycount > 3) {
			my $string = sprintf("%s, %s, %s, et al", @{$partyref});
			return $string;
		} else {
			# Really shouldn't be here, because it should be a scalar if there's only one, but just in case...
			return $partyref->[0];
		}
	} else {
		return $partyref;
	}
}

sub longPartyString {
	my $partyref = shift;
	
	if (ref($partyref) eq "ARRAY") {
		my $partycount = scalar(@{$partyref});
		
		if ($partycount >= 2) {
			# Remove the last element of the array - first copy the array and work from the copy
			my @partyCopy;
			push(@partyCopy, @{$partyref});
			my $last = pop(@partyCopy);
			# Return a comma-separated list of remaining elements, and then "and" and the one we removed from the end.
			return sprintf("%s and %s", join(", ", @partyCopy), $last)
		} else {
			# Really shouldn't be here, because it should be a scalar if there's only one, but just in case...
			return $partyref->[0];
		}
	} else {
		return $partyref;
	}
}
