#!/usr/bin/perl
#
# pbsojview.cgi - PBSO JAcket Viewing Function
#
# 11/29/10 lms don't attempt pbso search if there's no database connection

BEGIN {
	use lib "$ENV{'JVS_PERL5LIB'}";
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
	getDbSchema
);

use Showcase qw (
	$db
);

sub doit {

	my $info=new CGI;
	
	my $jacket=clean($info->param("jacket"));
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
	
	createTab("PBSO Jacket/Inmate View - Jacket " . $jacket, "/cgi-bin/pbsojview.cgi?jacket=" . $jacket, 1, 1, "index");

	my $session = getSession();

	# test the pbso connection.  if can't connect, don't do anything!
	my $pbsoconn = dbConnect("pbso2");
	if (!defined($pbsoconn)) {
		print $info->header();
		print "No connection can be made to the SCSO database at this time.  ".
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
	}</script>


<h2 style=\"background-color:#428bca; color:#FFFFFE\">Sarasota County Sheriff's Office Jacket/Inmate View </h2>";

	write_jacketIdentifier($jacket);
	print "<p>";
	my $dbh = dbConnect($db);
	my $schema = getDbSchema($db);
	write_pbsoblock($jacket,'',"",$dbh, $pbsoconn, $schema, $ucn);  # no case number to share...
}

#
# MAIN PROGRAM
#
doit();
