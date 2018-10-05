#!/usr/bin/perl

#
# scimage.cgi - render a PDF for a given docket line - using Showcase's
# Trakman Image Service (TIS)
#
# derived (very loosely) from the ICMS-8th Circuit image.cgi
# Fred Buhl 8/22/09
#
# 11/09/09 lms new algorithm for creating dir2
# 10/14/10 lms use tiff2pdf rather than tiff2ps and ps2pdf to avoid docs
#                  getting chopped off on right
# 07/12/11 lms new code based on old image.cgi
# 07/15/11 lms new objid passed in

BEGIN {
    use lib $ENV{'PERL5LIB'};
}

use strict;
use CGI;
use ICMS;
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
use File::Temp qw(tmpfile);
use File::Basename;
use File::Copy;
use CGI::Carp qw(fatalsToBrowser);
use XML::Simple;
use Common qw (
    inArray
    dumpVar
	makePaths
	getUser
);
use DB_Functions qw (
    dbConnect
    getDataOne
    getDivsLDAP
    getDbSchema
    inGroup
    ldapConnect
);

sub doit {
    my $info=new CGI;
    my @images;
    
    my %params = $info->Vars;
    
    my $dbh = dbConnect($db);
    my $schema = getDbSchema($db);
    
    my $casenum = getDocketItems($info,\@images,$dbh,$schema);
	$casenum = $info->param('ucn');
	my $ucn = $casenum;
    #$casenum =~ s/^50//g;
    my $caseid = $params{'caseid'};

	my $workpath = sprintf("%s/casefiles/%s/", $ENV{'DOCUMENT_ROOT'}, $ucn);
	if (!-d $workpath) {
		makePaths($workpath);
	}
	
    my @documents;

	# Does the user just want to show a single TIF image instead of doing
	# the PDF conversion?
	my $showTif = 0;
	if (defined($info->param('showTif'))) {
		$showTif = 1;
	}

    my $conf = XMLin("$ENV{'APP_ROOT'}/conf/ICMS.xml");
	my $TMPASS = $conf->{'TrakMan'}->{'nosealed'}->{'password'};
	my $TMUSER = $conf->{'TrakMan'}->{'nosealed'}->{'userid'};
    
	my $ldap = ldapConnect();
    
    my $user = getUser();
	
	if (inGroup($user,'CAD-ICMS-SEALED',$ldap)) {
        my $canView = 0;
		my @divs;
		
		getDivsLDAP(\@divs,$user,$ldap);
		
		if ((inArray(\@divs, "AllDivs")) || (inArray(\@divs, "MH")) || (inArray(\@divs, "VA"))) {
			$canView = 1;
		} else {
            # What's the case's division?
            my $query = qq {
                select
                    DivisionID
                from
                    $schema.vCase with(nolock)
                where
                    CaseID = ?
            };
			my $casediv = getDataOne($query,$dbh,[$caseid]);
			if ((defined($casediv)) && (inArray(\@divs, $casediv->{'DivisionID'}))) {
				# This user is in the case's division
				$canView = 1;
			}
		}

		if ($canView) {
			# User is allowed to see sealed images on this case.  Use the privileged ID
			$TMPASS = $conf->{'TrakMan'}->{'sealed'}->{'password'};
			$TMUSER = $conf->{'TrakMan'}->{'sealed'}->{'userid'};
		}
	} elsif (inGroup($user,'CAD-ICMS-SEALED-JUV',$ldap) || inGroup($user,'CAD-ICMS-SEALED-PROBATE',$ldap)
		|| inGroup($user,'CAD-ICMS-SEALED-APPEALS',$ldap)) {
		# User can see ONLY Juvenile sealed
		if ($casenum =~ /^(\d\d)-(\d{1,4})-(\D\D)-(\d{0,6})(.*)/) {
			if (inArray(['CJ','DP'], $3) && inGroup($user,'CAD-ICMS-SEALED-JUV',$ldap)) {

				my $canView = 0;
				my @divs;
				getDivsLDAP(\@divs,$user,$ldap);

				if (inArray(\@divs, "AllDivs")) {
					$canView = 1;
				} else {
                    # What's the case's division?
                    my $query = qq {
                        select
                            DivisionID
                        from
                            $schema.vCase with(nolock)
                        where
                            CaseID = ?
                    };
                    my $casediv = getDataOne($query,$dbh,[$caseid]);
					if ((defined($casediv)) && (inArray(\@divs, $casediv->{'DivisionID'}))) {
						# This user is in the case's division
						$canView = 1;
					}
				}

				if ($canView) {
					# User is allowed to see sealed images on this case.  Use the privileged ID
					$TMPASS = $conf->{'TrakMan'}->{'sealed'}->{'password'};
					$TMUSER = $conf->{'TrakMan'}->{'sealed'}->{'userid'};
				}
			}
			elsif (inArray(['GA','CP','MH'], $3) && inGroup($user,'CAD-ICMS-SEALED-PROBATE',$ldap)) {
				# User can see ONLY Probate sealed
				my $canView = 1;
				
				# Taking this out for now so Probate people can see sealed images regardless of division - LK 4/21/16
				#my @divs;
				#getDivsLDAP(\@divs,$user,$ldap);

				#if (inArray(\@divs, "AllDivs")) {
				#	$canView = 1;
				#} else {
	            #	# What's the case's division?
	            #    my $query = qq {
	            #    	select
	            #        	DivisionID
	            #        from
	            #            $schema.vCase with(nolock)
	            #        where
	            #            CaseID = ?
	            #    };
	            #    my $casediv = getDataOne($query,$dbh,[$caseid]);
				#	if ((defined($casediv)) && (inArray(\@divs, $casediv->{'DivisionID'}))) {
				#		# This user is in the case's division
				#		$canView = 1;
				#	}
				#}
	
				if ($canView) {
					# User is allowed to see sealed images on this case.  Use the privileged ID
					$TMPASS = $conf->{'TrakMan'}->{'sealed'}->{'password'};
					$TMUSER = $conf->{'TrakMan'}->{'sealed'}->{'userid'};
				}
			}
			else{
				my $query = qq {
	            	select
	                	DivisionID
	                from
	                	$schema.vCase with(nolock)
	                where
	                	CaseID = ?
	            };
	        	my $casediv = getDataOne($query,$dbh,[$caseid]);
	        	
	        	if((inArray['AC', 'AY'], $casediv->{'DivisionID'}) && inGroup($user,'CAD-ICMS-SEALED-APPEALS',$ldap)){
	        		#User can see ONLY Appeals sealed
	        		my $canView = 1;
	        		
	        		if ($canView) {
						# User is allowed to see sealed images on this case.  Use the privileged ID
						$TMPASS = $conf->{'TrakMan'}->{'sealed'}->{'password'};
						$TMUSER = $conf->{'TrakMan'}->{'sealed'}->{'userid'};
					}
	        	}
			}
		}
	}
		
	my $pdfListFile = getImagesFromNewTM(\@images,\@documents,$TMUSER,$TMPASS,$showTif, undef,undef,$workpath,$params{'pdforder'});

    if ($pdfListFile eq 'TIMEOUT') {
		print $info->header();
		print "There was a timeout retrieving images from the TrakMan service.  Please try again later.\n\n";
		print STDERR "Timeout retrieving images for case $casenum.\n";
		exit;
	}

    # Remove the TIFs (so subsequent users can't see them - in case the document is sealed)
    #foreach my $tif (@images) {
    #    my $tifname = sprintf("/tmp/%s.tif", $tif->{'object_id'});
    #    unlink ($tifname)
    #}

	my $finalPdf;
	if (scalar(@documents) > 1) {
		$finalPdf = buildImageFile($pdfListFile, \@images, \@documents, $casenum);
	} elsif (scalar(@documents) == 1) {
		# Just a single file - don't do the GhostScript stuff
		my $oldFile = $documents[0]->{'file'};
		my $newFile = sprintf("%s/tmp/%s", $ENV{'DOCUMENT_ROOT'}, basename($oldFile));
		if ((!-f $newFile) && (!-l $newFile)) {
			symlink($oldFile, $newFile);
		}
		
		$finalPdf = sprintf("tmp/%s", basename($oldFile));
	} else {
		# Clean up
		#unlink($pdfListFile);
        print $info->header();
        print "No images found for case $casenum.";
        exit;
	}

	# Clean up
	#unlink ($pdfListFile);

	if (defined($finalPdf)) {
		print $info->redirect("http://$ENV{'HTTP_HOST'}/$finalPdf");
    } else {
		# Whine whine whine
		print $info->header();
		print "There was a problem generating the PDF.<br><br>\n";
    }
}

doit("tm");