#!/usr/bin/perl -w

BEGIN {
    use lib "$ENV{'PERL5LIB'}";
}

use strict;

use Common qw (
    dumpVar
    doTemplate
    $templateDir
    inArray
    returnJson
    createTab
    getUser
    getSession
    checkLoggedIn
);

use DB_Functions qw (
    dbConnect
    getData
    getDivJudges
    getDbSchema
    getSubscribedQueues
	getSharedQueues
	getQueues
);

use Showcase qw (
    $db
);

use CGI;

checkLoggedIn();

my $info = new CGI;

my %params = $info->Vars;

my $dbh = dbConnect('judge-divs');
my $cdbh = dbConnect("icms");
my $user = getUser();

my @myqueues = ($user);
my @sharedqueues;

getSubscribedQueues($user, $cdbh, \@myqueues);
getSharedQueues($user, $cdbh, \@sharedqueues);
my @allqueues = (@myqueues, @sharedqueues);
my %queueItems;

my $wfcount = getQueues(\%queueItems, \@allqueues, $cdbh);

#Special handling for this calendar....
my $session = getSession();
my $sess_tabs = $session->get('tabs');
my $tdExists = 0;
my $param_href;
foreach my $key (keys %{$sess_tabs}){
	if($sess_tabs->{$key}->{'name'} eq 'Traffic Docket'){
		$tdExists = 1;
		$param_href = $sess_tabs->{$key}->{'href'};
	}
}

if(!$tdExists){
	my $href = "/cgi-bin/case/calendars/trafficDocket.cgi";
	createTab("Traffic Docket", $href, 1, 1, "calendars");
	$session = getSession();
} else{
	createTab("Traffic Docket", $param_href, 1, 1, "calendars");
	$session = getSession();
}

my $query = qq {
    select
        courtroom,
        courthouse
    from
        courtrooms
    order by
        courtroom
};


my %data;
$data{'courtrooms'} = [];
getData($data{'courtrooms'}, $query, $dbh);

my %divJudges;
getDivJudges(\%divJudges, $dbh);

# Get a listing of the criminal divs
my @scDivs;
$data{'divs'} = [];
foreach my $key (sort keys %divJudges) {
    next if $divJudges{$key}->{'DivisionType'}  =~ /Civil|Juvenile|Family|Probate|UFC|Foreclosure/;
    if (!inArray(\@scDivs, "'$key'")) {
        push (@scDivs, "'$key'");
        push (@{$data{'divs'}}, $key);
    }
}

# Ok, now we have a listing of the Showcase divs.  Get their current judges (as they show in Showcase)
my $scdbh = dbConnect($db);
my $schema = getDbSchema($db);

my $inString = join(",", @scDivs);

$query = qq {
    select
        distinct(Judge_LN + ', ' + Judge_FN + ' ' + Judge_MN) as JudgeName
    from
        $schema.vDivision_Judge with(nolock)
    where
        DivisionID in ($inString)
        and Division_Active = 'Yes'
        and EffectiveFrom <= GETDATE()
        and ((EffectiveTo is null) or (EffectiveTo >= GETDATE()))
    order by
        JudgeName
};

$data{'judges'} = [];
getData($data{'judges'}, $query, $scdbh);
$data{'wfCount'} = $wfcount;
$data{'active'} = "calendars";
$data{'tabs'} = $session->get('tabs');

if($params{'starttime'}){
	$data{'starttime'} = $params{'starttime'};
}
else{
	$data{'starttime'} = "";
}

if($params{'endtime'}){
	$data{'endtime'} = $params{'endtime'};
}
else{
	$data{'endttime'} = "";
}

if($params{'day'}){
	$data{'day'} = $params{'day'};
}
else{
	$data{'day'} = "";
}

if($params{'courtroom'}){
	$params{'courtroom'} =~ s/%23/#/g;
	$data{'courtroom'} = $params{'courtroom'};
}
else{
	$data{'courtroom'} = "";
}

if($params{'judge'}){
	$data{'judge'} = $params{'judge'};
}
else{
	$data{'judge'} = "";
}
		
print $info->header;
doTemplate(\%data,"$templateDir/top","header.tt",1);
doTemplate(\%data, "$templateDir/calendars", "viewDocket.tt", 1);

