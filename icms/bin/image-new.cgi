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
    scGetDocketItems
    buildTMImageList
    $db
);
use Banner qw (
    bannerGetDocketItems
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
    returnJson
    doTemplate
    $templateDir
    isShowcase
);
use DB_Functions qw (
    dbConnect
    getDataOne
    getDivsLDAP
    getDbSchema
    inGroup
    ldapConnect
);

# needed so SOAP::Lite can find the cert for the clerk vcp02xweb server...
$ENV{HTTPS_CA_FILE} = '/etc/pki/tls/certs/ca1_clerk_local.pem';
$ENV{HTTPS_CERT_FILE} = '/etc/pki/CA/private/vcp02xweb_lms.pem';

sub doit {
    my $info=new CGI;
    
    my @images;
    
    my %params = $info->Vars;
    
    my $isShowcase = undef;;
    if (defined($params{'ucn'})) {
        $isShowcase = isShowcase($params{'ucn'});
    }
    
    my $dbh;
    my @documents;
    my $conf = XMLin("$ENV{'APP_ROOT'}/conf/ICMS.xml");
    my $TMPASS = $conf->{'TrakMan'}->{'nosealed'}->{'password'};
    my $TMUSER = $conf->{'TrakMan'}->{'nosealed'}->{'userid'};
	my $secGroup = $conf->{'ldapConfig'}->{'securegroup'};
	my $sealedGroup = $conf->{'ldapConfig'}->{'sealedgroup'};
	my $sealedProbateGroup = $conf->{'ldapConfig'}->{'sealedprobategroup'};
	my $sealedAppealsGroup = $conf->{'ldapConfig'}->{'sealedappealsgroup'};
	my $sealedJuvGroup = $conf->{'ldapConfig'}->{'sealedjuvgroup'};
   
    # Does the user just want to show a single TIF image instead of doing
    # the PDF conversion?
    my $showTif = 0;
    if (defined($info->param('showTif'))) {
        $showTif = 1;
    }
    
    my $workpath;
    my $casenum;
    my $ucn;
    
    if ((defined($isShowcase)) && ($isShowcase)) {
        # The case where we have a single object and it's a Showcase case
        $dbh = dbConnect($db);
        my $schema = getDbSchema($db);
    
        $casenum = scGetDocketItems($info,\@images,$dbh,$schema);
    
        $ucn = $casenum;
        $casenum =~ s/^50//g;    

        $workpath = sprintf("/var/www/html/case/casefiles/%s/", $ucn);
        if (!-d $workpath) {
            makePaths($workpath);
        }
        
        my @documents;
    
        my $ldap = ldapConnect();
        
        my $user = $info->remote_user();
        
        if (inGroup($user,$sealedGroup,$ldap)) {
            my $canView = 0;
            my @divs;
            
            getDivsLDAP(\@divs,$user,$ldap);
            
            if ((inArray(\@divs, "AllDivs")) || (inArray(\@divs, "MH"))) {
                $canView = 1;
            } else {
                # What's the case's division?
                my $query = qq {
                    select
                        DivisionID
                    from
                        $schema.vCase with(nolock)
                    where
                        UCN = ?
                };
                my $casediv = getDataOne($query,$dbh,[$ucn]);
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
        } elsif ((inGroup($info->remote_user(),$sealedJuvGroup),$ldap)) {
            # User can see ONLY Juvenile sealed
            if ($casenum =~ /^(\d{1,6})(\D\D)(\d{0,6})(.*)/) {
                if (inArray(['CJ','DP'], $2)) {
                    my $canView = 0;
                    my @divs;
                    my $user = $info->remote_user();
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
                                UCN = ?
                        };
                        my $casediv = getDataOne($query,$dbh,[$ucn]);
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
            }
        }
    } elsif ((defined($isShowcase)) && (!$isShowcase)) {
        # Single image for a Banner case
        $dbh = dbConnect("wpb-banner-prod");
        
        $casenum = bannerGetDocketItems($info,\@images,$dbh);
        
        print $info->header();
    
        $ucn = $casenum;
        $casenum =~ s/^50//g;    

        $workpath = sprintf("/var/www/html/case/casefiles/%s/", $ucn);
        if (!-d $workpath) {
            makePaths($workpath);
        }
        
        my @documents;
    }
		
	my $pdfListFile = getImagesFromNewTM(\@images,\@documents,$TMUSER,$TMPASS,$showTif, undef,undef,$workpath,$params{'pdforder'});

    if ($pdfListFile eq 'TIMEOUT') {
		print $info->header();
		print "There was a timeout retrieving images from the TrakMan service.  Please try again later.\n\n";
		print STDERR "Timeout retrieving images for case $casenum.\n";
		exit;
	}

    # Remove the TIFs (so subsequent users can't see them - in case the document is sealed)
    foreach my $tif (@images) {
        my $tifname = sprintf("/tmp/%s.tif", $tif->{'object_id'});
        unlink ($tifname)
    }

	my $finalPdf;
	if (scalar(@documents) > 1) {
		$finalPdf = buildImageFile($pdfListFile, \@images, \@documents, $casenum, undef, "/var/www/html/case/pdfs");
        $finalPdf =~ s/\var\/www\/html//g;
	} elsif (scalar(@documents) == 1) {
		# Just a single file - don't do the GhostScript stuff
		my $oldFile = $documents[0]->{'file'};
		my $newFile = sprintf("/var/www/html/case/pdfs/%s", basename($oldFile));
		if ((!-f $newFile) && (!-l $newFile)) {
			symlink($oldFile, $newFile);
		}
		
		$finalPdf = sprintf("pdfs/%s", basename($oldFile));
        
	} else {
		# Clean up
		#unlink($pdfListFile);
        print $info->header();
        print "No images found for case $casenum.";
        exit;
	}

	# Clean up
	#unlink ($pdfListFile);

    my %data;
    $data{'imageID'} = basename($finalPdf);
    $data{'imageID'} =~ s/\./-/g;
    $data{'imageURL'} = $finalPdf;
    $data{'UCN'} = $ucn;
    
    #print $info->header('text/plain');
    print $info->header;
    #dumpVar(\%data);
    doTemplate(\%data, "$templateDir/casedetails", "image.tt",1);
    
#	if (defined($finalPdf)) {
#        my %result;
#        my $protocol = 'http';
#        if (defined($ENV{'HTTPS'})) {
#            $protocol = 'https';
#        }
#        $result{'imageUrl'} = "$protocol://$ENV{'HTTP_HOST'}/$finalPdf";
#        $result{'tab'} = $params{'tab'};
#        returnJson(\%result);
#    } else {
#		# Whine whine whine
#		print $info->header();
#		print "There was a problem generating the PDF.<br><br>\n";
#    }
}

doit("tm");
