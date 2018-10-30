#!/usr/bin/perl

#
# Retrieves all documents associated with a case from BenchMark DMS and stores them locally
# Fires when case detail page is called.
#

BEGIN {
    use lib $ENV{'PERL5LIB'};
}

use strict;
use warnings;
use WWW::Mechanize;
use XML::Simple;
use LWP::Simple;
use CGI;
use Common qw (
	makePaths
	logToFile
);
use Showcase qw (
    getDocketsWithImages
     $db
);
use DB_Functions qw (
    dbConnect
    getDbSchema
);
sub doit{
	
	my @docketIds;
	my $info=new CGI;
	my %params = $info->Vars;
	my $caseNumber = $params{'cn'};
	my $caseId = $params{'cid'};
	my $docketCount = 0;
	my $missingImage = 0;
	my $dbh = dbConnect($db);
    my $schema = getDbSchema($db);
    my @dockets;
	# create case number folder if not exists
	my $workpath = sprintf("%s/casefiles/%s/", $ENV{'DOCUMENT_ROOT'}, $caseNumber);
	if (!-d $workpath) {
		makePaths($workpath);
	}
	
	# Get Dockets with Images so we can check if images already exist
	getDocketsWithImages($caseId,\@dockets,$dbh,$schema);
	$docketCount = scalar @dockets;
	
	if($docketCount > 0){
		
		# check to see if Images exist
		foreach my $docket (@dockets){
			my $docketId = $docket->{'DocketID'};
			if (! -f "$workpath/$docketId.pdf"){
				$docket->{'MissingImage'} = 1;
				$missingImage = 1;
			}else{
				$docket->{'MissingImage'} = 0;
			}
		}
		if ($missingImage == 0){
			# All Images exist nothing to do so exit
			print $info->header();
			print "All Case Images Already Exist";
			exit;
		}else{
			getImages($caseNumber,$workpath,\@dockets,$info);
		}
		
	}else{
		# nothing to do so exit
		print $info->header();
		print "No Dockets Retrieved";
		exit;
	}
	
}

sub getImages{
	# Gets missing images from BenchMark
	my $caseNumber = shift;
	my $workpath = shift;
	my $docketRef = shift;
	my $info = shift;
	my $start = time;
	
	my $conf = XMLin("$ENV{'APP_ROOT'}/conf/ICMS.xml");
	my $appRoot =$conf->{'BenchMark'}->{'appRoot'};
	my $loginPage = $appRoot . $conf->{'BenchMark'}->{'loginPage'};
	my $caseSearchAction = $appRoot . $conf->{'BenchMark'}->{'caseSearchAction'};
	my $pdfGUID = $appRoot . $conf->{'BenchMark'}->{'pdfGUID'};
	my $pdfFile = $appRoot . $conf->{'BenchMark'}->{'pdfFile'};
	my $caseSearch = $appRoot . $conf->{'BenchMark'}->{'caseSearch'};
	my $todayUtc = localtime; 
	my $agent = WWW::Mechanize->new( autocheck => 1);
	 $agent->agent_alias('Windows Mozilla');
	# Login to Benchmark Website
	my $response=$agent->post($loginPage,content=>'time='.$todayUtc.'&username=jterhune&password=Bk0k0m0j%40m');
	
	# if we logged in Start looking for case
	if ($response->is_success) {
	
	    $agent->get($caseSearch); #URL of search page
	
	    $agent->form_number('1'); #Get the Form
	    
	    my $verificationToken = $agent->value('__RequestVerificationToken');
	    my $courtTypes=$agent->value('courtTypes');
	    my $caseTypes = $agent->value('caseTypes');
	    my $partyTypes = $agent->value('partyTypes');
	    my $divisions = $agent->value('divisions');
	    my $searchType = 'CaseNumber';
	    my $searchValue =$caseNumber;   
	   $agent->post($caseSearchAction , 
	    [
	       '__RequestVerificationToken' => $verificationToken,
	       'type' => $searchType,
	       'search' => $searchValue,
	       'openedFrom' => "",
	       'openedTo' => "",
	       'closedFrom' => "",
	       'closedTo' => "",
	       'courtTypes' => $courtTypes,
	       'caseTypes' => $caseTypes,
	       'partyTypes' => $partyTypes,
	       'divisions' => $divisions,
	       'statutes' => "",
	       'partyBirthYear' => "",
	       'partyDOB' => "",
	       'caseStatus' => "",
	       'propertyAddress' => "",       
	       'propertyCity' => "",
	       'propertyZip' => "",       
	       'propertySubDivision' => "",       
	       'lawFirm' => "",       
	       'unpaidPrincipleBalanceFrom' => "",       
	       'unpaidPrincipleBalanceTo' => "",
	       'electionDemandFrom' => "",       
	       'electionDemandTo' => "",       
	       'attorneyFileNumber' => "",                           
	    ]) ; 
	    my $detailsUri = $agent->uri();
	    $detailsUri =~ s/Details/CaseDockets/g;  # Replace page in uri
	    $agent->get($detailsUri);
	  	my $guid ='';
	  	my $message="";
	  	# loop throught dockets and get image where missing
	  	my $docketId;
	  	my @links = $agent->links; 
	  	print $info->header();
	  	foreach my $docket (@{$docketRef}){  		
			if($docket->{'MissingImage'} == 1){
				$docketId = $docket->{'DocketID'};
				 for my $link ( @links ){
				 	if ($docketId == $link->attrs->{id}){
				 		$agent->post($pdfGUID , 
					    [
					       'cid' => $docketId,
					       'digest' => $link->attrs->{digest},
					       'time' => $todayUtc,
					       'redacted' => "False",	                            
					    ]) ; 
					    $guid = $agent->content();	
   						eval{ $agent->get($pdfFile . '?guid=' . $guid,':content_file' => "$workpath/$docketId.pdf") || die "$!" . "$docketId";};
						print "Copied $docketId.pdf<br />";
					   	last;			   
				 	}
				}				 	
			}
		}	
		my $duration = time - $start;
		print "<hr />Execution time: $duration <br />";
	}
	else {
    	print $info->header();
		print "There was a error retrieving image from BenchMark.  Please try again later.\n\n";
		print STDERR "Error retrieving image for case $caseNumber.\n";
	}
}
doit();
   