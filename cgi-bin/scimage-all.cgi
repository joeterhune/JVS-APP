#!/usr/bin/perl

# Render a multi-case docket for selected images.

BEGIN {
    use lib $ENV{'PERL5LIB'};
}

use strict;
use CGI;
use Showcase qw (
    getDocketItems
    buildTMImageList
    $db
);
use Images qw(
	buildImageFile
	getImagesFromNewTM
);
use POSIX;
use SOAP::Lite;
use File::Temp qw(tempfile);
use File::Basename;
use File::Copy;
use CGI::Carp qw(fatalsToBrowser);
use XML::Simple;
use Common qw (
	inArray
	dumpVar
	doTemplate
	$templateDir
	getShowcaseDb
);
use DB_Functions qw (
	dbConnect
	getDataOne
	getData
	getDivsLDAP
	getDbSchema
	inGroup
	ldapConnect
);

# needed so SOAP::Lite can find the cert for the clerk vcp02xweb server...
$ENV{HTTPS_CA_FILE} = '/etc/pki/tls/certs/ca1_clerk_local.pem';
$ENV{HTTPS_CERT_FILE} = '/etc/pki/CA/private/vcp02xweb_lms.pem';

our $db = getShowcaseDb();


sub getDocketList {
	# A reference to an array of hashes containing the file paths
	my $docketList = shift;
	my $cmsDocSelect = shift;

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
            ObjectId
        from
            $schema.vDocket with(nolock)
        where
            $cmsDocSelect
        order by
            SeqPos desc
    };
    
    getData($docketList,$query,$dbh);
}


sub doit {
    my $info=new CGI;

	my @selected = $info->param('selected');

	my @ucns;
	my @objids;

	foreach my $object (@selected) {
		my ($ucn, $objid) = split(/\|/, $object);
		if (!inArray(\@ucns, $ucn)) {
			push(@ucns, "'$ucn'");
		}
		if (!inArray(\@objids, $objid)) {
			push(@objids, $objid);
		}
	}

	my $ucnInStr = join(",", @ucns);
	my $objInStr = join(",", @objids);

	my $dbh = dbConnect($db);
	my $schema = getDbSchema($db);

	my $query = qq {
		select
            d.CaseNumber,
            d.UCN,
			d.LegacyCaseNumber,
			d.SeqPos,
			d.DocketDescription,
			CONVERT(varchar(10),d.EffectiveDate,101) as EffectiveDate,
			d.ObjectId,
			d.ObjectId as object_id,
			c.DivisionID
		from
			$schema.vDocket d with(nolock),
			$schema.vCase c
		where
			d.UCN in ($ucnInStr)
			and d.ObjectID in ($objInStr)
			and d.CaseNumber = c.CaseNumber
		order by
			SeqPos desc
	};

	my %items;
	getData(\%items, $query, $dbh, {hashkey => "CaseNumber"});

	# Need to determine which TrakMan user we should be using.
    my $conf = XMLin("$ENV{'APP_ROOT'}/conf/ICMS.xml");
	my $TMPASS = $conf->{'TrakMan'}->{'nosealed'}->{'password'};
	my $TMUSER = $conf->{'TrakMan'}->{'nosealed'}->{'userid'};
	my $STMPASS = $conf->{'TrakMan'}->{'sealed'}->{'password'};
	my $STMUSER = $conf->{'TrakMan'}->{'sealed'}->{'userid'};
	
	# Now get the Object ID of the highest sequence number for each.
	my @images;
	foreach my $doctCode (keys %items) {
	    #my @sorted = sort { $b->{'SeqPos'} <=> $a->{'SeqPos'}} @{$items{$doctCode}};
	    push(@images, @{$items{$doctCode}});
	}
	
	# Get the images - need to do the call twice, once for secure and once for non-secure.
	if (scalar(@images)) {
		my @docs;
		my $pdfListFile = getImagesFromNewTM(\@images,\@docs,$TMUSER,$TMPASS,0);
	
		if ($pdfListFile eq 'TIMEOUT') {
			print $info->header();
			print "There was a timeout retrieving images from the TrakMan service.  Please try again later.\n\n";
			exit;
		}
		unlink $pdfListFile;
		
		foreach my $nd (keys %items) {
			foreach my $nd2 (@{$items{$nd}}){
			
				foreach my $doc (@docs) {
				
					next if ($doc->{'object_id'} != $nd2->{'ObjectId'});
					$nd2->{'file'} = $doc->{'file'};
					$nd2->{'pagecount'} = $doc->{'pagecount'};
					last;
				}
			}
		}
	}

	my $totalPages = 1;

	my ($fh, $pdfList) = tempfile(
								  DIR => "/tmp",
								  UNLINK => 0
								  );

	# Ok, we have everything we need.  Let's build the file.
	foreach my $case (reverse (sort keys %items)) {
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
		print $info->redirect("http://$ENV{'HTTP_HOST'}/tmp/$rdfile");
	}
}

doit("tm");
