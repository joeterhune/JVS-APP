#!/usr/bin/perl -w

BEGIN {
    use lib "$ENV{'JVS_PERL5LIB'}";
}

use strict;

use Common qw (
    dumpVar
    returnJson
    $templateDir
    doTemplate
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
use File::Temp qw(tempfile);

my $info = new CGI;

my %params = $info->Vars;
my $casenum = $params{'casenum'};
my $casenumStr = " ('" . $params{'casenum'} . "')";
my @casenums = $info->param("selectedCPCA");
my $orderStr = "'" . $params{'casenum'} . "'";
	
if(scalar(@casenums)){
	my @caseArr;
	my @orderArr;
	foreach my $case (@casenums) {
		$casenum = $case;
    	push(@caseArr, "'" . $case . "'");
    	push(@orderArr, $case);
    }
        
    $casenumStr = " (" . join(",", @caseArr) .") ";
    $orderStr = "'";
    $orderStr .= join(",", @orderArr) ."'";
}

my $dbh = dbConnect($db);
my $schema = getDbSchema($db);

my $query = qq {
    select
        CaseNumber,
        UCN,
		LegacyCaseNumber,
		SeqPos,
		DocketDescription,
		CONVERT(varchar(10),EffectiveDate,101) as EffectiveDate,
		ObjectId,
		ObjectId as object_id,
		DocketCode
    from
        $schema.vDocket with(nolock)
    where
        CaseNumber IN $casenumStr
        and DocketCode in ('CPCA', 'SPCA', 'PCA', 'APC')
    -- ORDER BY 
    	-- CHARINDEX(CAST(CaseNumber AS VARCHAR), $orderStr)
};


my %items;
getData(\%items, $query, $dbh, {hashkey => 'CaseNumber'});

# Now get the Object ID of the highest sequence number for each.
my @images;
foreach my $doctCode (keys %items) {
    #my @sorted = sort { $b->{'SeqPos'} <=> $a->{'SeqPos'}} @{$items{$doctCode}};
    push(@images, @{$items{$doctCode}});
}

my $conf = XMLin("$ENV{'JVS_ROOT'}/conf/ICMS.xml");
my $TMPASS = $conf->{'TrakMan'}->{'nosealed'}->{'password'};
my $TMUSER = $conf->{'TrakMan'}->{'nosealed'}->{'userid'};

my $ucn = $casenum;
$ucn =~ s/-//g;
my $workPath = sprintf("/var/www/html/casefiles/%s", $ucn);

my @documents;
my $pdfListFile;

my $finalPdf;
if (scalar(@images) > 1) {
    $pdfListFile = getImagesFromNewTM(\@images, \@documents, $TMUSER, $TMPASS, 0);
	
	if ($pdfListFile eq 'TIMEOUT') {
		print $info->header();
		print "There was a timeout retrieving images from the TrakMan service.  Please try again later.\n\n";
		exit;
	}
	unlink $pdfListFile;
		
	foreach my $nd (keys %items) {
		foreach my $nd2 (@{$items{$nd}}){
			foreach my $doc (@documents) {
				next if ($doc->{'object_id'} != $nd2->{'ObjectId'});
				$nd2->{'file'} = $doc->{'file'};
				$nd2->{'pagecount'} = $doc->{'pagecount'};
				last;
			}
		}
	}
	
	my $totalPages = 1;

	my ($fh, $pdfList) = tempfile(
								  DIR => "/tmp",
								  UNLINK => 0
								  );

	# Ok, we have everything we need.  Let's build the file.
	#foreach my $case (reverse (sort keys %items)) {
	foreach my $case (keys %items) {
		# Need to go through a case at a time.
		my $caseDocket = $items{$case};
		foreach my $image (@{$caseDocket}) {
			$image->{'page'} = $totalPages;
			$totalPages += $image->{'pagecount'};
			print $fh $image->{'file'} . "\n";
		}
	}
	
	close $fh;

	my %data;
	$data{'images'} = \%items;

	my $marks = doTemplate(\%data, $templateDir, "pdfmarks.multicase.tt", 0);

	my ($configfh, $configfn) = tempfile (
		DIR => "/tmp",
		UNLINK => 0
	);

	print $configfh $marks;
	close $configfh;

	my $rdfile = basename($configfn) . ".pdf";

	my $command = "gs -q -dBATCH -dNOPAUSE -sDEVICE=pdfwrite -sOUTPUTFILE=/var/www/html/tmp/$rdfile -f $configfn \@$pdfList > /dev/null 2>&1";
	
	my $res = system($command);
	
	if (!$res) {
		# Clean up the "temporary" PDFs before redirecting
		open (INFILE, $pdfList);
		while (my $pdfFile = <INFILE>) {
			chomp $pdfFile;
			if (-f $pdfFile) {
				unlink($pdfFile);
			}
		}
		$finalPdf = sprintf("tmp/%s", $rdfile);
	}
    
} elsif (scalar(@images) == 1) {
	$pdfListFile = getImagesFromNewTM(\@images,\@documents,$TMUSER,$TMPASS,0,undef,undef,$workPath,'asc');
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
