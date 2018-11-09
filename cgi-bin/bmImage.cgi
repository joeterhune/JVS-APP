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
# 11/05/2018 jmt modified to work with benchmark

BEGIN {
    use lib $ENV{'PERL5LIB'};
}

use strict;
use CGI;
use ICMS;
use Showcase qw (
    getDocketItems
    $db
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
    #$casenum =~ s/^58//g;
    my $caseid = $params{'caseid'};
	 my $docketid = $params{'docketid'};

	my $workpath = sprintf("%s/casefiles/%s/", $ENV{'DOCUMENT_ROOT'},$caseid);
	my $urlpath = sprintf("%s/casefiles/%s/", "http://$ENV{'HTTP_HOST'}",$caseid);
	
    my @documents;

	# Does the user just want to show a single TIF image instead of doing
	# the PDF conversion?
	############## commented 11/5/2018 jmt - No Tiff viewing for benchmark
	#my $showTif = 0;
	#if (defined($info->param('showTif'))) {
	#	$showTif = 1;
	#}
	############## end comment
	my $conf = XMLin("$ENV{'APP_ROOT'}/conf/ICMS.xml");
	my $sealedGroup = $conf->{'ldapConfig'}->{'sealedgroup'};
	my $sealedProbateGroup = $conf->{'ldapConfig'}->{'sealedprobategroup'};
	my $sealedAppealsGroup = $conf->{'ldapConfig'}->{'sealedappealsgroup'};
	my $sealedJuvGroup = $conf->{'ldapConfig'}->{'sealedjuvgroup'};
	
   
	############## commented 11/5/2018 jmt - Trackman not in use in benchmark
	# my $TMPASS = $conf->{'TrakMan'}->{'nosealed'}->{'password'};
	# my $TMUSER = $conf->{'TrakMan'}->{'nosealed'}->{'userid'};
    ############## end comment
	
	my $ldap = ldapConnect();
    my $user = getUser();
	my $canView = 0;
	if (inGroup($user,$sealedGroup,$ldap)) {
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

		############# commented 11/5/2018 jmt - trackman not in use for benchmark
		#if ($canView) {
			# User is allowed to see sealed images on this case.  Use the privileged ID
		#	$TMPASS = $conf->{'TrakMan'}->{'sealed'}->{'password'};
		#	$TMUSER = $conf->{'TrakMan'}->{'sealed'}->{'userid'};
		#}
		############ end comment
	} elsif (inGroup($user,$sealedJuvGroup,$ldap) || inGroup($user,$sealedProbateGroup,$ldap)
		|| inGroup($user,$sealedAppealsGroup,$ldap)) {
		# User can see ONLY Juvenile sealed
		if ($casenum =~ /^(\d\d)-(\d{1,4})-(\D\D)-(\d{0,6})(.*)/) {
			if (inArray(['CJ','DP'], $3) && inGroup($user,$sealedJuvGroup,$ldap)) {

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
				############# commented 11/5/2018 jmt - trackman not in use for benchmark
				#if ($canView) {
					# User is allowed to see sealed images on this case.  Use the privileged ID
				#	$TMPASS = $conf->{'TrakMan'}->{'sealed'}->{'password'};
				#	$TMUSER = $conf->{'TrakMan'}->{'sealed'}->{'userid'};
				#}
				############ end comment
			}
			elsif (inArray(['GA','CP','MH'], $3) && inGroup($user,$sealedProbateGroup,$ldap)) {
				# User can see ONLY Probate sealed
				$canView = 1;
				
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
				############# commented 11/5/2018 jmt - trackman not in use for benchmark
				#if ($canView) {
					# User is allowed to see sealed images on this case.  Use the privileged ID
				#	$TMPASS = $conf->{'TrakMan'}->{'sealed'}->{'password'};
				#	$TMUSER = $conf->{'TrakMan'}->{'sealed'}->{'userid'};
				#}
				############ end comment
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
	        	
	        	if((inArray['AC', 'AY'], $casediv->{'DivisionID'}) && inGroup($user,$sealedAppealsGroup,$ldap)){
	        		#User can see ONLY Appeals sealed
	        		$canView = 1;
					############# commented 11/5/2018 jmt - trackman not in use for benchmark
	        		#if ($canView) {
						# User is allowed to see sealed images on this case.  Use the privileged ID
					#	$TMPASS = $conf->{'TrakMan'}->{'sealed'}->{'password'};
					#	$TMUSER = $conf->{'TrakMan'}->{'sealed'}->{'userid'};
					#}
					############ end comment
	        	}
			}
		}
	}
		$canView = 1;
	if ($canView){
		if (!-d $workpath) {
			print $info->redirect("/cgi-bin/bmRetrieveSingleDocketImage.cgi?cn=$casenum&did=$docketid");
			exit;
		}
		if (!-f "$workpath/$docketid" . ".pdf"){
			print $info->redirect("/cgi-bin/bmRetrieveSingleDocketImage.cgi?cn=$casenum&did=$docketid");
			exit;
		}else{
			print $info->redirect("$urlpath$docketid" . ".pdf");
			exit;
		}
	}else{
		print $info->header();
		print "You do not have permissions to view this document";
		exit;
	}
		
}

doit("tm");
