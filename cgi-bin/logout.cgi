#!/usr/bin/perl -w

BEGIN {
    use lib $ENV{'PERL5LIB'};
}

use strict;
use CGI qw(:standard);
use ICMS;
use Common qw (
    inArray
    dumpVar
    doTemplate
    $templateDir
    ISO_date
	stripWhiteSpace
	sanitizeCaseNumber
	logToFile
    returnJson
    createTab
    getUser
    getSession
);

my $session = getSession();

if($session ne ""){
	$session->unregister('tabs');
	$session->unset;
	$session->save;
	$session->destroy;
}

my $info = new CGI;
my %params = $info->Vars;
my $url;
my $reqPage = $ENV{'REQUEST_URI'};

if(defined($params{'timeout'})){
	if(defined($reqPage)){
		$url = "/login.php?ref=" . $reqPage;
	}
	else{
		$url = "/login.php";
	}
}
else{
	$url = "/logout.php";
}

print $info->redirect(-uri => $url);
exit;