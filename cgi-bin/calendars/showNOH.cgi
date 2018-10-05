#!/usr/bin/perl -w

BEGIN {
    use lib $ENV{'PERL5LIB'};
}

use strict;

use Common qw (
    dumpVar
    returnJson
);

use DB_Functions qw (
    dbConnect
    getData
    getDbSchema
);

use Showcase qw (
    $db
);

use XML::Simple;

use Images qw (
    getImagesFromNewTM
    buildImageFile
);

use CGI;
use File::Basename;

my $info = new CGI;

my %params = $info->Vars;
my $casenum = $params{'casenum'};
my $nohobj = $params{'nohobj'};

my $dbh = dbConnect($db);
my $schema = getDbSchema($db);

my $query = qq {
    select
        ObjectID as ObjectId,
        DocketCode,
        SeqPos,
        CONVERT(varchar(10),CreateDate,101) as dt_created,
        DocketDescription as code,
        CASE 
        	WHEN DocketCode = 'NOH'
        	THEN 1
        	ELSE 2
        END AS ImageOrder,
        EffectiveDate
    from
        $schema.vDocket with(nolock)
    where
        CaseNumber = ?
    and 
    	( DocketCode in ('WPNG', 'NG', 'NGP', 'PONG', 'WPNG_1', 'WPNG_2', 'WPNG_3' ) OR ObjectID = ? )
    and 
    	ObjectID IS NOT NULL	
    ORDER BY ImageOrder
};

my %items;
getData(\%items, $query, $dbh, {valref => [$casenum, $nohobj], hashkey => 'ImageOrder'});

# Now get the Object ID of the highest sequence number for each.
my @images;
foreach my $imOrd (sort keys %items) {
    my @sorted = sort { $a->{'ImageOrder'} <=> $b->{'ImageOrder'}} @{$items{$imOrd}};
    push(@images, $sorted[0]);
}

my $conf = XMLin("$ENV{'APP_ROOT'}/conf/ICMS.xml");
my $TMPASS = $conf->{'TrakMan'}->{'nosealed'}->{'password'};
my $TMUSER = $conf->{'TrakMan'}->{'nosealed'}->{'userid'};

my $ucn = $casenum;
$ucn =~ s/-//g;
my $workPath = sprintf("%s/casefiles/%s", $ENV{'DOCUMENT_ROOT'}, $ucn);

my @documents;

my $pdfListFile = getImagesFromNewTM(\@images,\@documents,$TMUSER,$TMPASS,0,undef,undef,$workPath,'asc');

my $finalPdf;
if (scalar(@documents) > 1) {
    $finalPdf = buildImageFile($pdfListFile, \@images, \@documents, $casenum);
} elsif (scalar(@documents) == 1) {
    # Just a single file - don't do the GhostScript stuff
    my $oldFile = $documents[0]->{'file'};
    my $newFile = sprintf("/var/www/html/tmp/%s", basename($oldFile));
    rename($oldFile, $newFile);
    $finalPdf = sprintf("tmp/%s", basename($oldFile));
} else {
    # Clean up
	#unlink($pdfListFile);
    print $info->header();
    print "No images found for case $casenum.";
    exit;
}

if (defined($finalPdf)) {
    my %result;
    my $protocol = 'http';
    if (defined($ENV{'HTTPS'})) {
        $protocol = 'https';
    }
    print $info->redirect("http://$ENV{'HTTP_HOST'}/$finalPdf");
    
} else {
    # Whine whine whine
    print $info->header();
    print "There was a problem generating the PDF.<br><br>\n";
}

exit;
