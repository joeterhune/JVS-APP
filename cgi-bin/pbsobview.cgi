#!/usr/bin/perl
#
# pbsobview.cgi - PBSO Booking Viewing Function
#
# 11/29/10 lms don't attempt pbso search if there's no database connection

BEGIN {
   use lib "$ENV{'PERL5LIB'}";
}

use strict;
use DBI;
use CGI;
use ICMS;
use POSIX;
use PBSO;
use Date::Calc qw(:all);

use Common qw (
    dumpVar
    doTemplate
    $templateDir
    returnJson
    createTab
    getUser
    getSession
    checkLoggedIn
);

use DB_Functions qw (
    dbConnect
    getData
    getSubscribedQueues
	getSharedQueues
	getQueues
);


sub doit {

	my $info=new CGI;
	
	my $jacket=clean($info->param("jacket"));
	my $booking=clean($info->param("booking"));
	my $ucn=clean($info->param("ucn"));

	checkLoggedIn();
	
	my $user = getUser();
	my $fdbh = dbConnect("icms");
	
	my @myqueues = ($user);
	my @sharedqueues;
	
	getSubscribedQueues($user, $fdbh, \@myqueues);
	getSharedQueues($user, $fdbh, \@sharedqueues);
	my @allqueues = (@myqueues, @sharedqueues);
	my %queueItems;
	
	my $wfcount = getQueues(\%queueItems, \@allqueues, $fdbh);
	
	createTab("PBSO Details - Jacket " . $jacket . " and Booking " . $booking,  "/cgi-bin/case/pbsobview.cgi?jacket=" . $jacket . "&booking=" . $booking, 1, 1, "index");
	
	my $session = getSession();

   	# test the pbso connection.  if can't connect, don't do anything!
   	my $pbsoconn=test_pbsoconnection();
	if($pbsoconn == 0) {
		print $info->header();
	    print "No connection can be made to the PBSO database at this time.  ".
		"Please try later.<br/>";
	    exit;
	}

	my %data;
	$data{'wfCount'} = $wfcount;
	$data{'active'} = "index";
	$data{'tabs'} = $session->get('tabs');
	
	print $info->header;
	doTemplate(\%data, "$templateDir/top", "header.tt", 1);
	
	print "<div class=\"clear\"></div>

	<script language=\"javascript\" type=\"text/javascript\">
	function toggleMe(a){
		  var e=document.getElementById(a);
		  if(!e)return true;
		  if(e.style.display==\"none\"){
		    e.style.display=\"block\";
		  } else {
		    e.style.display=\"none\";
		  }
		  return true;
		}
	</script>
	
	<h2 style=\"background-color:#428bca; color:#FFFFFE\">Palm Beach Sheriff's Office Booking Details<br/>for Jacket # $jacket and Booking # $booking</h2>";
	
	   write_jacketIdentifier($jacket);
	   print "<button name=\"GoBookings2\" onclick=\"window.location.href='pbsojview.cgi?jacket=$jacket&ucn=$ucn';\">See All Bookings for this Person</button>";
	   write_bookingHeader($jacket,$booking);
	   print "<p>";
	   write_bookingArrestInformation($jacket,$booking);
	   print "<p>";
	   write_bookingChargeBondInformation($jacket,$booking);
	   print "<p>";
	   write_bookingSentencing($jacket,$booking);
	   print "<p>";
	
	   print "<button name=\"GoBookings2\" onclick=\"window.location.href='pbsojview.cgi?jacket=$jacket&ucn=$ucn';\">See All Bookings for this Person</button>";
}

#
# MAIN PROGRAM
#
doit();
