#!/usr/bin/perl

#
# image.cgi - render a PDF for a given docket line
#
# derived (very loosely) from the ICMS-8th Circuit image.cgi
# Fred Buhl 8/22/09
#
# 11/09/09 lms new algorithm for creating dir2
# 10/14/10 lms use tiff2pdf rather than tiff2ps and ps2pdf to avoid docs
#              getting chopped off on right

BEGIN {
	use lib "/usr/local/icms/bin";
}

use strict;
use CGI;
use ICMS;
use Banner qw(
    getDocketItems
	buildImageList
);
use Images qw (buildImageFile);
use Common qw(
    dumpVar
    returnJson
);
use CGI::Carp qw(fatalsToBrowser);
use File::Basename;
use File::Copy;

sub doit {
    my $info=new CGI;
	
	my %params = $info->Vars;
	
    my $casenum=$params{'casenum'};

    # An array of hash refs, used to generate the full document from the list
    my @documents = ();

    my $itemCount = 1;

    my @images;

    my %requestInfo;
    $requestInfo{'casenum'} = $casenum;
    $requestInfo{'num'} = $params{'num'};
    if (defined($info->param('showmulti'))) {
        $requestInfo{showmulti} = $params{'showmulti'};
    }
    if (defined($info->param('selected'))) {
        $requestInfo{selected} = [];
        @{$requestInfo{selected}} = $info->param('selected');
    }
	
    getDocketItems(\%requestInfo,\@images);
	
	# Does the user just want to show a single TIF image instead of doing
	# the PDF conversion?
	my $showTif = 0;
	if (defined($info->param('showTif'))) {
		$showTif = 1;
	}
	
    my $pdfListFile = buildImageList(\@images, \@documents, $showTif, undef, $info->param('pdforder'));

    my $finalPdf;

    if (scalar(@documents) > 1) {
        $finalPdf = buildImageFile($pdfListFile, \@images, \@documents,$casenum);
    } elsif (scalar(@documents) == 1) {
		# Only a single image.  Don't do all of the GhostScript stuff
		my $oldFile = $documents[0]->{'file'};
		my $newFile = sprintf("/var/www/html/tmp/%s", basename($oldFile));
		if ((!-f $newFile) && (!-l $newFile)) {
			symlink($oldFile, $newFile);
		}
		#move($oldFile, $newFile);
		$finalPdf = sprintf("tmp/%s", basename($oldFile));
	} else {
		# Clean up
		unlink($pdfListFile);
        print $info->header();
        print "No images found for case $casenum.";
        exit;
    }

	unlink($pdfListFile);
    if (defined($finalPdf)) {
        my %result;
        my $protocol = 'http';
        if (defined($ENV{'HTTPS'})) {
            $protocol = 'https';
        }
        $result{'imageUrl'} = "$protocol://$ENV{'HTTP_HOST'}/$finalPdf";
        $result{'tab'} = $params{'tab'};
        returnJson(\%result);
    } else {
		# Whine whine whine
		print $info->header();
		print "There was a problem generating the PDF.<br><br>\n";
    }
}

doit();
