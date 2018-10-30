#!/usr/bin/perl -w

BEGIN {
    use lib "$ENV{'PERL5LIB'}";
}

use strict;
use Common qw (
    dumpVar
    doTemplate
    $templateDir
    encodeFile
);
use DB_Functions qw (
    dbConnect
    getData
    ldapLookup
    eFileInfo
    getCaseInfo
    getDivInfo
    doQuery
);
use CGI;

use XML::Simple;

my $info = new CGI;

my %params = $info->Vars;

my $user = $info->remote_user;

my $dbh = dbConnect("portal_info");

my $eFileInfo = eFileInfo($user,$dbh);

my %data;
$data{'filetime'} = `/bin/date +"%FT%H:%M:%S.%N%:z"`;
chomp $data{'filetime'};
$data{'firstname'} = $eFileInfo->{'first_name'};
$data{'lastname'} = $eFileInfo->{'last_name'};
$data{'logonname'} = $eFileInfo->{'user_id'};
$data{'password'} = $eFileInfo->{'password'};
$data{'bar_id'} = $eFileInfo->{'bar_num'} . "FL";
$data{'ClerkCase'} = $params{'casenum'};
$data{'UCN'} = $params{'ucn'};
$data{'county_id'} = 50;
$data{'judicial_circuit'} = "Fifteenth Circuit";
$data{'county'} = "Palm Beach County";

my $caseInfo = getCaseInfo($params{'casenum'});

if (!defined($caseInfo)) {
    die "Unable to determine information for case number '$params{casenum}'\n\n";
}

$data{'CaseStyle'} = $caseInfo->{'CaseStyle'};
my $divInfo = getDivInfo($caseInfo->{'DivisionID'});

if (defined($divInfo)) {
    $data{'case_type'} = $divInfo->{'portal_namespace'};
    $data{'court_id'} = $divInfo->{'court_type_id'};
    $data{'court_type'} = $divInfo->{'portal_court_type'};
} else {
    die "Unable to determine division type for divison '$caseInfo->{'DivisionID'}\n\n";
}


# The resulting data structure from this next part may be more complex than is strictly necessary for
# this, but it allows us to use the same template that we'd use for filing multiple documents.
$data{'doc_info'} = {};

my %image;
$image{'file_name'} = sprintf("/var/www/html/%s", $params{'pdf'});
$image{'encodedBase64'} = encodeFile($image{'file_name'});
$image{'file_group'} = $params{'docketGroup'};
$image{'file_desc'} = $params{'docketDesc'};
$image{'binary_size'} = (stat($image{'file_name'}))[7];
$image{'file_type'} = getFileType($image{'file_name'});
 
$data{'doc_info'}{'FilingLeadDocument'} = \%image;
$data{'doc_info'}{'FilingConnectedDocuments'} = [];
    
my $meta = doTemplate(\%data, "$templateDir/portal", "ReviewFiling.tt", 0);

my $file = "/tmp/foo.xml";
open(OUTFILE, ">$file") ||
    die "Unable to open output file '$file': $!\n\n";
print OUTFILE $meta;
close OUTFILE;

print "Content-type: text/html\n\n";
print "Done!";

my $filing = `/usr/bin/php $ENV{'PERL5LIB'}/portal/fileTemplate.php -f $file`;

open(OUTFILE, ">/tmp/filing.xml");
print OUTFILE $filing;
close OUTFILE;

print STDERR "$file\n";

my $xs = XML::Simple->new();
my $ref = $xs->XMLin($filing);

print $info->header;

my $response = $ref->{'s:Body'}->{'BulkReviewFilingResponse'};
my $errorCode = $response->{'MessageReceiptMessage'}->{'ecf:Error'}->{'ecf:ErrorCode'};

if ($errorCode) {
    my $errorString = $response->{'MessageReceiptMessage'}->{'ecf:Error'}->{'ecf:ErrorText'};
    print "There was an error filing.  The response received was:<br/><br/>";
    print $errorString;
} else {
    print "SUCCESS!!<br/><br/>";
    my $filingID = $response->{'MessageReceiptMessage'}->{'nc:DocumentIdentification'}[0]->{'nc:IdentificationID'};
    
    print "Filing ID $filingID has been submitted.\n\n";
    
    my $filingDate = $response->{'MessageReceiptMessage'}->{'nc:DocumentReceivedDate'}->{'nc:DateTime'};
    
    my $query = qq {
        insert into
            portal_filings (
                user_id,
                filing_id,
                casenum,
                filing_date
            )
            values (
                ?,?,?,?
            )
    };
    
    my @vals = ($user, $filingID, $params{'ucn'}, $filingDate);
    doQuery($query, $dbh, \@vals);
}


#dumpVar($response);
#dumpVar($errorCode);

exit;


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
