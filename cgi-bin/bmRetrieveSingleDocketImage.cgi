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

sub doit(){
	my $info=new CGI;
	my %params = $info->Vars;
	my $conf = XMLin("$ENV{'APP_ROOT'}/conf/ICMS.xml");
	my $appRoot =$conf->{'BenchMark'}->{'appRoot'};
	my $loginPage = $appRoot . $conf->{'BenchMark'}->{'loginPage'};
	my $caseSearchAction = $appRoot . $conf->{'BenchMark'}->{'caseSearchAction'};
	my $pdfGUID = $appRoot . $conf->{'BenchMark'}->{'pdfGUID'};
	my $pdfFile = $appRoot . $conf->{'BenchMark'}->{'pdfFile'};
	my $caseSearch = $appRoot . $conf->{'BenchMark'}->{'caseSearch'};
	
	
	my $caseNumber = $params{'cn'};
	my $docketId = $params{'did'};
	
	my $todayUtc = localtime; 
	my $agent = WWW::Mechanize->new( autocheck => 1);
	
	# Login to Benchmark Website
	my $response=$agent->post($loginPage,content=>'time='.$todayUtc.'&username=jterhune&password=Bk0k0m0j%40m');
	
	# if we logged in Start looking for case and docket id
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
	    for my $link ( $agent->links )
		{
			if ($link->attrs->{id} eq $docketId){			
				$agent->post($pdfGUID , 
			    [
			       'cid' => $link->attrs->{id},
			       'digest' => $link->attrs->{digest},
			       'time' => $todayUtc,
			       'redacted' => "False",	                            
			    ]) ; 
			    $guid = $agent->content();
			    
			    			
	        	last; # We got our docket exit for loop
			}
		}
		my $filename ="Image.pdf";
		$filename =~ s[^.+/][];
		$agent->get($pdfFile . '?guid=' . $guid);
		#print $agent->header();
		print "Content-Type: application/pdf\n\n";
	    print 'Content-Length: ' . $agent->response->header('Content-Length') . "\n\n";
	    print 'Content-Disposition: inline; filename="Image.pdf"' . "\n\n";
	    #print $agent->content();
	    print $agent->content();
	   exit;
	}
	else {
    	print $info->header();
		print "There was a error retrieving image from BenchMark.  Please try again later.\n\n";
		print STDERR "Error retrieving image for case $caseNumber.\n";
		exit;
	}
}
doit();
   