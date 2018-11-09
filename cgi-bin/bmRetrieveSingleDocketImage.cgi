#!/usr/bin/perl

#
# Retrieves a single pdf file from Benchmark DMS by using the benchmark web
#
BEGIN {
    use lib $ENV{'PERL5LIB'};
}

use strict;
use warnings;

use WWW::Mechanize;
use XML::Simple;
use CGI;
use Common qw (
	getUser
    getSession
);
	
sub main{
	my $info=new CGI;
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
	
	my $caseNumber = $params{'cn'};
	my $docketId = $params{'did'};
	my $username = getUser();
	my $todayUtc = localtime; 
	my $agent = WWW::Mechanize->new( autocheck => 1);
	my $loggedIn = 0;
	my $loginCount = 0;
	# Try Login to Benchmark  try 3 times befor failure
	do{
		if($loginCount >= 2){
			print $info->header();
			print "There was a error logging into BenchMark for $username.  Please contact the CATS team with this error.\n\n";
			print STDERR "Error Logging into BenchMark for $username.\n";
			exit;			
		}
		$loggedIn = login($agent,$loginPage,$todayUtc,$defaultUser,$defaultPassword);
		++$loginCount;
	}while($loggedIn == 0);
	
	#search for Case Number in BenchMark
	my $searchResult = searchCase($agent,$caseSearch,$caseNumber,$caseSearchAction);
	
	#Get Docket List and search for value passed in
	if($searchResult == 1){
		my $detailsUri = $agent->uri();
		$detailsUri =~ s/Details/CaseDockets/g;  # Modify the URI set it to details page
		
		# Get the Docket List
		$agent->get($detailsUri);
		
		# Find the link matching the Docket Id
		my $link = $agent->find_link(id=> $docketId);
		if(! defined $link){
			print $info->header();
			print "There was a error retrieving docket record from BenchMark for id: $docketId.  Please try again later.\n\n";
			print STDERR "Error retrieving docket record for id: $docketId from BenchMark.\n";
			exit;
		}
		
		# Get the GUID so we can retrive the pdf
		my $guid = getGuid($agent,$link,$pdfGUID,$todayUtc);
		
		if($guid eq ""){
			print $info->header();
			print "There was a error retrieving image guid from BenchMark for id: $docketId.  Please try again later.\n\n";
			print STDERR "Error retrieving guid for id: $docketId from BenchMark.\n";
			exit;

		}
		
		my $filename ="Image.pdf";
		$filename =~ s[^.+/][];
		
		#Get PDF Image
		$agent->get($pdfFile . '?guid=' . $guid);
		print "Content-Type: application/pdf\n\n";
	    print 'Content-Length: ' . $agent->response->header('Content-Length') . "\n\n";
	    print 'Content-Disposition: inline; filename="Image.pdf"' . "\n\n";
	    print $agent->content();
		exit;
		
	}else{
		print $info->header();
		print "There was a error finding doceket information in BenchMark.  Please contact the CATS team with this error.\n\n";
		print STDERR "Error Searching for case: $caseNumber in BenchMark.\n";
		exit;
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
	my $caseNumber = shift;
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
    my $searchValue = $caseNumber;   
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

sub getGuid{
	my $agent = shift;
	my $link = shift;
	my $pdfGUID = shift;
	my $todayUtc = shift;
	my $guid = '';
	my $responseGuid=$agent->post($pdfGUID , 
		[
		   'cid' => $link->attrs->{id},
		   'digest' => $link->attrs->{digest},
		   'time' => $todayUtc,
		   'redacted' => "False",	                            
		]) ; 
	if ($responseGuid->is_success){
		$guid = $agent->content();
	}
	return $guid;		
}

main();