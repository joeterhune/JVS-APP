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
	returnJson
);
use Showcase qw (
    getDocketsWithImages
     $db
);
use DB_Functions qw (
    dbConnect
    getDbSchema
);
sub main{
	
	my @docketIds;
	my $info = new CGI;
	my %params = $info->Vars;
	my $conf = XMLin("$ENV{'APP_ROOT'}/conf/ICMS.xml");
	my $appRoot =$conf->{'BenchMark'}->{'appRoot'};
	my $loginPage = $appRoot . $conf->{'BenchMark'}->{'loginPage'};
	my $caseSearchAction = $appRoot . $conf->{'BenchMark'}->{'caseSearchAction'};
	my $pdfGUID = $appRoot . $conf->{'BenchMark'}->{'pdfGUID'};
	my $pdfFile = $appRoot . $conf->{'BenchMark'}->{'pdfFile'};
	my $caseSearch = $appRoot . $conf->{'BenchMark'}->{'caseSearch'};
	my $defaultUser = $conf->{'BenchMark'}->{'defaultUser'};
	my $defaultPassword = $conf->{'BenchMark'}->{'defaultPassword'};
	my $ucn = $params{'ucn'};
	my $caseId = $params{'caseid'};
	my $docketCount = 0;
	my $missingImage = 0;
	my $dbh = dbConnect($db);
    my $schema = getDbSchema($db);
    my @dockets;
	
	# Get Dockets with Images so we can check if images already exist
	getDocketsWithImages($caseId,\@dockets,$dbh,$schema);
	$docketCount = scalar @dockets;
	
	if($docketCount > 0){
		# create case number folder if not exists
		my $workpath = sprintf("%s/casefiles/%s/", $ENV{'DOCUMENT_ROOT'}, $caseId);
		if (!-d $workpath) {
			makePaths($workpath);
		}
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
			my %result;
			$result{'status'} = "Success";
			$result{'html'} = "All Images Exist";
			returnJson(\%result);
			exit;
		}else{
			my $result = getImages($ucn,$workpath,\@dockets,$info,$loginPage,$caseSearchAction,$pdfGUID,$pdfFile,$caseSearch,$defaultUser,$defaultPassword);
			my %result;
			if ($result ne "error"){
				$result{'status'} = "Success";
				$result{'html'} = "$result";
			}else{
				$result{'status'} = "Error";
				$result{'html'} = "$result";
			}
			returnJson(\%result);
			exit;
		}
		
	}else{
		# nothing to do so exit
		my %result;
		$result{'status'} = "Success";
		$result{'html'} = "No Dockets Retrieved";
		returnJson(\%result);
		exit;
	}
	
}
sub getImages{
	# Gets missing images from BenchMark
	my $ucn = shift;
	my $workpath = shift;
	my $docketRef = shift;
	my $info = shift;
	my $loginPage = shift;
	my $caseSearchAction = shift;
	my $pdfGUID = shift;
	my $pdfFile = shift;
	my $caseSearch = shift;
	my $defaultUser = shift;
	my $defaultPassword = shift;	
	my $todayUtc = localtime; 
	my $start = time;
	my $agent = WWW::Mechanize->new( autocheck => 1);
	$agent->agent_alias('Windows Mozilla');
	my $loggedIn = 0;
	my $loginCount = 0;
	
	# Try Login to Benchmark  try 3 times befor failure
	do{
		if($loginCount >= 2){
			print $info->header();
			print "There was a error logging into BenchMark for $defaultUser.  Please contact the CATS team with this error.\n\n";
			print STDERR "Error Logging into BenchMark for $defaultUser.\n";
			$loggedIn = 1;
			return "error";
			exit;
		}
		$loggedIn = login($agent,$loginPage,$todayUtc,$defaultUser,$defaultPassword);
		++$loginCount;
	}while($loggedIn == 0);
	
	# if we logged in Start looking for case
	my $searchResult = searchCase($agent,$caseSearch,$ucn,$caseSearchAction);
	
	#Get Docket List and search for value passed in
	if ($searchResult == 1) {
	    my $detailsUri = $agent->uri();
	    $detailsUri =~ s/Details/CaseDockets/g;  # Modify the URI set it to details page
		
		# Get the Docket List
	    $agent->get($detailsUri);
	  	my $guid ='';
	  	my $message="";
	  	# loop throught dockets and get image where missing
	  	my $docketId;
	  	my @links = $agent->links; 
		my $linkCount = scalar @links;
		if ($linkCount > 0 ){
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
							last;			   
						}
					}				 	
				}
			}	
			my $duration = time - $start;
			return "Execution time: $duration";
		}else{
			print $info->header();
			print "There was a error retrieving image links from BenchMark.  Please contact the CATS team with this error.\n\n";
			print STDERR "Error retrieving image links for case $ucn.\n";
			return "error";
		}
	}
	else {
    	print $info->header();
		print "There was a error retrieving image from BenchMark.  Please contact the CATS team with this error.\n\n";
		print STDERR "Error retrieving image for case $ucn.\n";
		return "error";
	}
}
sub login{

	my $agent = shift;
	my $loginPage = shift;
	my $todayUtc = shift;
	my $defaultUser = shift;
	my $defaultPassword = shift;
	my $response = $agent->post($loginPage,content=>"time=$todayUtc&username=$defaultUser&password=$defaultPassword");
	my $returnValue = 0;
	if ($response->is_success) {
		if($agent->content() eq "True"){
			return 1;
		}
	}
	return $returnValue;
}

sub searchCase{
	my $agent = shift;
	my $caseSearch =shift;
	my $ucn = shift;
	my $caseSearchAction = shift;
	my $returnValue = 0;
	
	$agent->get($caseSearch); #URL of search page
    $agent->form_number('1'); #Get the Form
    
    my $verificationToken = $agent->value('__RequestVerificationToken');
    my $courtTypes=$agent->value('courtTypes');
    my $caseTypes = $agent->value('caseTypes');
    my $partyTypes = $agent->value('partyTypes');
    my $divisions = $agent->value('divisions');
    my $searchType = 'CaseNumber';
    my $searchValue = $ucn;   
	my $responseCase = $agent->post($caseSearchAction , 
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
    
    if ($responseCase->is_success){
    	if(index($agent->content(),"caseFoundFilter") == -1){
    		$returnValue = 1;
    	}
    }
    
 	return $returnValue;   
}
main();
   