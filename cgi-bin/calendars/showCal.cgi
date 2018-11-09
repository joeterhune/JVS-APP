#!/usr/bin/perl -w

BEGIN {
	use lib $ENV{'PERL5LIB'};
};

use strict;
use DB_Functions qw(
	dbConnect
	getData
	getDataOne
	doQuery
	getDbSchema
	getDivJudges
    inGroup
    getSubscribedQueues
	getSharedQueues
	getQueues
);
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use File::Temp qw { tempfile };
use File::Basename;
use Date::Calc qw(Today);
use Common qw(
	doTemplate
	dumpVar
	today
	@months
	$templateDir
	ISO_date
	writeXmlFile
	writeJsonFile
	inArray
    returnJson
    createTab
    getUser
    getSession
    checkLoggedIn
);
use Calendars qw (
	getJudges
	getMagistrates
	getMediators
	getBannerEvents
	getFirstAppearance
	getScEvents
	getVRBCalendar
	getCaseStyles
	getOLSJudges
	getDivType
	getMagistrateCalendar
	getMediatorCalendar
	getExParteCalendar
	getMentalHealthCalendar
);
use Showcase qw (
	$db
);
use JSON;
use XML::Simple;

checkLoggedIn();

my $info = new CGI;

my %params = $info->Vars;

my $division;
my $fapdivs = [];

my $jddbh;
my $divtype;
my $has_ols;

my $cdbh = dbConnect("icms");
my $user = getUser();

my @myqueues = ($user);
my @sharedqueues;

getSubscribedQueues($user, $cdbh, \@myqueues);
getSharedQueues($user, $cdbh, \@sharedqueues);
my @allqueues = (@myqueues, @sharedqueues);
my %queueItems;

my $wfcount = getQueues(\%queueItems, \@allqueues, $cdbh);
############### Added 11/6/2018 jmt security from conf 
my $conf = XMLin("$ENV{'APP_ROOT'}/conf/ICMS.xml");
my $secGroup = $conf->{'ldapConfig'}->{'securegroup'};

my $secretUser = inGroup($user,$secGroup);

if ($params{'calType'} eq 'fapcal') {
	my $fapch = $params{'fapch'};
	$jddbh = dbConnect("judge-divs");
	my $query = qq {
		select
			division_id
		from
			divisions d left outer join courthouses c on (d.courthouse_id=c.courthouse_id)
		where
			first_appearance = 1
			and c.courthouse_id = ?
	};
	my @temp;
	getData(\@temp,$query, $jddbh,{valref => [$fapch]});
	foreach my $div (@temp) {
		push(@{$fapdivs}, $div->{'division_id'});
	}
	$division = join(",", @{$fapdivs});
	$has_ols = 0;
	
	if($division eq ""){
		$division = $params{'div'};
		$division =~ s/-/,/g;
	}
} elsif (defined($params{'div'})) {
	$division = uc($params{'div'});
	$jddbh = dbConnect("judge-divs");
	($divtype,$has_ols) = getDivType($division,$jddbh);
} else {
	print $info->header();
	print "You must specify a division.";
	exit;
}

my %data;
my @events;
my $caldbh;
my @judges;
my @magistrates;
my @mediators;
my $judgeID = undef;

#$data{'foo'} = 'bar';
#my $foo = JSON->new->ascii->encode(\%data);
#print $info->header(
#    -type => 'application/json',
#    -expires => '-1d'
#);
#print $foo; exit;

if ($params{'calType'} eq 'fapcal') {
	$data{'isFap'} = 1;
	$data{'fapch'} = $params{'fapch'};
}

if (defined($params{'isFap'}) && ($params{'isFap'})) {
	$divtype = "fap";
}

my $title;
if($data{'isFap'}){
	$title = "First Appearance Calendar";
}
elsif($params{'calType'} eq "medcal"){
	my @medRef;
	
	if(defined($params{'judgeID'}) && ($params{'judgeID'} ne "")){
		$division = $params{'judgeID'};
	}
	
	getMediators($jddbh, \@medRef, $division);
	
	if($division eq "ALL" || ($division eq "all")){
		$title = "Mediation Calendar";
	}
	else{
		$title = "Calendar for Mediator " . $medRef[0]->{'FullName'};
	}
}
elsif($params{'calType'} eq "expcal"){
	
	if($division eq "ALL" || ($division eq "all")){
		$title = "Ex-Parte Calendar";
	}
	else{
		$title = "Division " . $division . " Ex-Parte Calendar";
	}
}
elsif($params{'calType'} eq "mhcal"){
	
	if($division eq "ALL" || ($division eq "all")){
		$title = "Mental Health Calendar";
	}
	else{
		$title = "Division " . $division . " Mental Health Calendar";
	}
}
else{
	$title = "Division " . $division . " Calendar";
}

my $href = "/cgi-bin/case/calendars/showCal.cgi?div=" . $division . "&fapch=" . $params{'fapch'} . "&calType=" . $params{'calType'};

if(defined($params{'otherday'})){
	$href .= "&otherday=" . $params{'otherday'} . "&judgeID=" . $params{'judgeID'};
}
elsif($params{'rangetype'} eq 'dayrange'){
	$href .= "&rangetype=" . $params{'rangetype'} . "&startday=" . $params{'startday'} . "&endday=" . $params{'endday'} . "&judgeID=" . $params{'judgeID'};
}
elsif($params{'rangetype'} eq 'today'){
	$href .= "&rangetype=" . $params{'rangetype'} ."&judgeID=" . $params{'judgeID'};
}

if($title ne "Division ALL Calendar" && ($title ne "Division 4 Calendar") && ($title ne "Division 5 Calendar")){	
	createTab($title, $href, 1, 1, "calendars");
}

my $session = getSession();
$data{'tabs'} = $session->get('tabs');

# Build a hash (keyed on division) of the Judges' names so we can display the Judge name if there isn't one already in the event
my @divJudges;
getDivJudges(\@divJudges);
my %divJudges;
foreach my $judge (@divJudges) {
	$judge->{'JudgeName'} =~ s/^(\D+), /$1, JUDGE /;
	$divJudges{$judge->{'DivisionID'}} = $judge;
}

if (!$has_ols || ($params{'calType'} eq "expcal")) {
	if ($params{'calType'} eq 'fapcal') {
		getJudges($jddbh, \@judges, $fapdivs->[0]);
	}elsif($params{'calType'} eq 'magcal') {
		getMagistrates($jddbh, \@magistrates, $division);	
	}elsif($params{'calType'} eq 'medcal') {
	
		if(defined($params{'judgeID'}) && ($params{'judgeID'} ne "")){
			$division = $params{'judgeID'};
		}
		else{
			$division = $params{'div'};
		}
	
		getMediators($jddbh, \@mediators, $division);	
	}else {
		getJudges($jddbh, \@judges, $division);	
	}
	
	if($params{'calType'} eq 'magcal') {
		$data{'JudgeName'} = $magistrates[0]->{'FullName'};
	}elsif($params{'calType'} eq 'medcal') {
		$data{'JudgeName'} = $mediators[0]->{'FullName'};
	}else{
		$data{'JudgeName'} = $judges[0]->{'FullName'};
	}
	
	if (!defined($params{'rangetype'}) || !defined($params{'jsonOnly'})) {
		($data{'year'},$data{'month'},$data{'day'}) = Today();
		$data{'months'} = \@months;
		$data{'judges'} = \@judges;
		$data{'magistrates'} = \@magistrates;
		$data{'mediators'} = \@mediators;
		$data{'division'} = $division;
        $data{'division'} =~ s/,/-/g;
        $data{'wfCount'} = $wfcount;
		$data{'active'} = "calendars";
		$data{'calType'} = $params{'calType'};
		$data{'rangetype'} = $params{'rangetype'};
		$data{'otherday'} = $params{'otherday'};
		$data{'startday'} = $params{'startday'};
		$data{'endday'} = $params{'endday'};
		
		print $info->header;
		doTemplate(\%data,"$templateDir/top","header.tt",1);
        doTemplate(\%data,"$templateDir/calendars","showCalTop.tt",1);
		exit;
	}
} else {
	$caldbh = dbConnect("calendars", "olscheduling");
	getOLSJudges($caldbh,\@judges,$division);
    
	if (!defined($params{'judgeID'}) || !defined($params{'jsonOnly'})) {
		($data{'year'},$data{'month'},$data{'day'}) = Today();
		$data{'months'} = \@months;
		$data{'judges'} = \@judges;
		$data{'division'} = $division;
        $data{'division'} =~ s/,/-/g;
        $data{'wfCount'} = $wfcount;
		$data{'active'} = "calendars";
		$data{'calType'} = $params{'calType'};
		$data{'rangetype'} = $params{'rangetype'};
		$data{'otherday'} = $params{'otherday'};
		$data{'startday'} = $params{'startday'};
		$data{'endday'} = $params{'endday'};
		
		print $info->header;
		doTemplate(\%data, "$templateDir/top", "header.tt", 1);
        doTemplate(\%data,"$templateDir/calendars","showCalTop.tt",1);
		exit;
	}

	$judgeID = $params{'judgeID'};
	# Find the correct fullname for the judge
	if ($judgeID eq "all") {
		$data{'allJudges'} = 1;
	} else {
		foreach my $judge (@judges) {
			next if ($judge->{'JudgeID'} ne $judgeID);
			$data{'JudgeName'} = $judge->{'FullName'};
			last;
		}
	}
}

my $vdbh = dbConnect('vrb2');

my $start;
my $end;

my $sortOrder = 6;
if ($params{'rangetype'} eq "today") {
	my ($year,$month,$day) = Today();
	$start = $end = sprintf("%04d-%02d-%02d", $year, $month, $day);
	$sortOrder = 4;
} elsif ($params{'rangetype'} eq "anotherday") {
	$start = $end = $params{'otherday'};
	$sortOrder = 4;
} else {
	$start = $params{'startday'};
	$end = $params{'endday'};
}

$start = ISO_date($start);
$end = ISO_date($end);

$data{'start'} = $start;
$data{'end'} = $end;

#my $templateFile;

my @exportHeaders;

if ($divtype eq "crim") {
	
	getVRBCalendar(\@events, $judgeID, $start, $end, $division, $vdbh, 0, "crim");
	
	#
	# Use this to specify the order of the headers in a generated spreadsheet
	@exportHeaders = (
		{
			'Column' => 'Case Number',
			'XMLField' => 'CaseNumber',
			'cellClass' => 'widelink',
			'filterPlaceholder' => 'Part of case #'
		},
		{
			'Column' => 'Case Style',
			'XMLField' => 'CaseStyle',
			'filterPlaceholder' => 'Part of case style',
			'cellClass' => 'caseStyle'
		},
		{
			'Column' => 'Event Code',
			'XMLField' => 'EventCode',
			'filterType' => 'filter-select',
			'filterPlaceholder' => 'Code',
			'cellClass' => 'code'
		},
		{
			'Column' => 'Description',
			'XMLField' => 'EventType',
			'filterType' => 'filter-select',
			'filterPlaceholder' => 'Type',
			'cellClass' => 'eventDesc'
		},
		{
			'Column' => 'Judge',
			'XMLField' => 'JudgeName',
			'filterType' => 'filter-select',
			'filterPlaceholder' => 'Select Judge',
			'cellClass' => 'Judge'
		},
		{
			'Column' => 'Date',
			'XMLField' => 'StartDate',
			'filterType' => 'filter-select',
			'filterPlaceholder' => 'Date',
			'cellClass' => 'timeDate'
		},
		{
			'Column' => 'Time',
			'XMLField' => 'StartTime',
			'filterType' => 'filter-select',
			'filterPlaceholder' => 'Date',
			'cellClass' => 'timeDate'
		},
		{
			'Column' => 'Notes',
			'XMLField' => 'EventNotes',
			'filterPlaceholder' => 'Part of event note',
			'cellClass' => 'timeDate'
		},
		{
			'Column' => 'Source',
			'XMLField' => 'ImportSourceName',
			'filterType' => 'filter-select',
			'filterPlaceholder' => 'Select',
			'cellClass' => 'timeDate'
		},
		{
			'Column' => 'Canceled',
			'XMLField' => 'isCanceled',
			'filterType' => 'filter-select',
			'filterPlaceholder' => 'Select',
			'cellClass' => 'timeDate'
		}
	);
	
	my %newCol;
	$newCol{'Column'} = 'PC Affidavit<br/><button type="button" class="showmulti">All Selected</button><br/>Select <a class="checkallboxes">All</a> | <a class="uncheckallboxes">None</a>';
	$newCol{'XMLField'} = 'CPCA';
	$newCol{'cellClass'} =  'timeDate sorter-false';
	$newCol{'filterPlaceholder'} = '';
	$newCol{'filterType'} = '';
	push(@exportHeaders, \%newCol);
		
	$data{'cookieName'} = "icms-crim-cal";
} elsif ($divtype eq "fap") {
	my $caldbh = dbConnect($db);
	my $schema = getDbSchema($db);
	getFirstAppearance($caldbh, \@events, $start, $end, $division, $schema);
	
	# Use this to specify the order of the headers in a generated spreadsheet
	@exportHeaders = (
		{
			'Column' => 'Case Number',
			'XMLField' => 'CaseNumber',
			'cellClass' => 'widelink',
			'filterPlaceholder' => 'Part of case #'
		},
		{
			'Column' => 'Case Style',
			'XMLField' => 'CaseStyle',
			'filterPlaceholder' => 'Part of case style',
			'cellClass' => 'caseStyle'
		},
		{
			'Column' => 'Event Code',
			'XMLField' => 'EventCode',
			'filterType' => 'filter-select',
			'filterPlaceholder' => 'Code',
			'cellClass' => 'code'
		},
		{
			'Column' => 'Description',
			'XMLField' => 'EventType',
			'filterType' => 'filter-select',
			'filterPlaceholder' => 'Type',
			'cellClass' => 'eventDesc'
		},
		{
			'Column' => 'Charges',
			'XMLField' => 'Charges',
			'filterPlaceholder' => 'Part of charge',
			'cellClass' => 'caseStyle'
		},
		{
			'Column' => 'Date',
			'XMLField' => 'StartDate',
			'filterType' => 'filter-select',
			'filterPlaceholder' => 'Date',
			'cellClass' => 'timeDate'
		},
		{
			'Column' => 'Time',
			'XMLField' => 'StartTime',
			'filterType' => 'filter-select',
			'filterPlaceholder' => 'Date',
			'cellClass' => 'timeDate'
		},
		{
			'Column' => 'Notes',
			'XMLField' => 'EventNotes',
			'filterPlaceholder' => 'Part of event note',
			'cellClass' => 'timeDate'
		}
	);
	$data{'cookieName'} = "icms-fap";
	
} 
elsif($params{'calType'} eq "magcal"){

	getMagistrateCalendar(\@events, $start, $end, $division);
	
	# Use this to specify the order of the headers in a generated spreadsheet
	@exportHeaders = (
			{
				'Column' => 'Case Number',
				'XMLField' => 'CaseNumber',
				'cellClass' => 'link',
				'filterPlaceholder' => 'Part of case #'
			},
			{
				'Column' => 'Law Firm',
				'XMLField' => 'LawFirm',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Select law firm',
				'cellClass' => 'lawFirm'
			},
			{
				'Column' => 'Case Style',
				'XMLField' => 'CaseStyle',
				'filterPlaceholder' => 'Part of case style',
				'cellClass' => 'caseStyle'
			},
			{
				'Column' => 'Magistrate',
				'XMLField' => 'JudgeName',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Select Magistrate',
				'cellClass' => 'Judge'
			},
			{
				'Column' => 'Motion / Supporting Documents',
				'XMLField' => 'Motion',
				'filterPlaceholder' => 'Part of Motion / Supporting Documents',
				'cellClass' => 'motion'
			},
			{
				'Column' => 'Time',
				'XMLField' => 'StartTime',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Time',
				'cellClass' => 'timeDate'
			},
			{
				'Column' => 'Event Type',
				'XMLField' => 'EventType',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Type',
				'cellClass' => 'eventDesc'
			},
			{
				'Column' => 'Date',
				'XMLField' => 'StartDate',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Date',
				'cellClass' => 'timeDate'
			},
			{
				'Column' => 'Conf. Num',
				'XMLField' => 'OLSConfNum',
				'filterPlaceholder' => 'Search Conf #',
				'cellClass' => 'lawFirm'
			},
			{
				'Column' => 'Source',
				'XMLField' => 'ImportSourceName',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Select',
				'cellClass' => 'timeDate'
			},
			{
				'Column' => 'Canceled',
				'XMLField' => 'isCanceled',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Select',
				'cellClass' => 'timeDate'
			},
			{
				'Column' => 'Attorney',
				'XMLField' => 'AttorneyInfo',
				'filterPlaceholder' => 'Search Attorney Name',
				'cellClass' => 'contact'
			},
			{
				'Column' => 'Contact',
				'XMLField' => 'ContactInfo',
				'filterPlaceholder' => 'Search Contact Name',
				'cellClass' => 'contact'
			}
		);
	$data{'cookieName'} = "icms-mag-cal";
} 
elsif($params{'calType'} eq "medcal"){

	getMediatorCalendar(\@events, $start, $end, $division);
	
	# Use this to specify the order of the headers in a generated spreadsheet
	@exportHeaders = (
			{
				'Column' => 'Case Number',
				'XMLField' => 'CaseNumber',
				'cellClass' => 'link',
				'filterPlaceholder' => 'Part of Case #'
			},
			{
				'Column' => 'Law Firm',
				'XMLField' => 'LawFirm',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Select Law Firm',
				'cellClass' => 'lawFirm'
			},
			{
				'Column' => 'Case Style',
				'XMLField' => 'CaseStyle',
				'filterPlaceholder' => 'Part of Case Style',
				'cellClass' => 'caseStyle'
			},
			{
				'Column' => 'Division',
				'XMLField' => 'DivisionID',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Select Division',
				'cellClass' => 'timeDate'
			},
			{
				'Column' => 'Mediator',
				'XMLField' => 'JudgeName',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Select Mediator',
				'cellClass' => 'Judge'
			},
			{
				'Column' => 'Time',
				'XMLField' => 'StartTime',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Time',
				'cellClass' => 'timeDate'
			},
			{
				'Column' => 'Event Type',
				'XMLField' => 'EventType',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Type',
				'cellClass' => 'eventDesc'
			},
			{
				'Column' => 'Date',
				'XMLField' => 'StartDate',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Date',
				'cellClass' => 'timeDate'
			},
			{
				'Column' => 'Conf. Num',
				'XMLField' => 'OLSConfNum',
				'filterPlaceholder' => 'Search Conf #',
				'cellClass' => 'lawFirm'
			},
			{
				'Column' => 'Room',
				'XMLField' => 'room_number',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Select',
				'cellClass' => 'attorney'
			},
			{
				'Column' => 'Canceled',
				'XMLField' => 'isCanceled',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Select',
				'cellClass' => 'timeDate'
			},
			{
				'Column' => 'Notes',
				'XMLField' => 'EventNotes',
				'filterPlaceholder' => 'Search Notes',
				'cellClass' => 'notes'
			},
			{
				'Column' => 'Attorney',
				'XMLField' => 'AttorneyInfo',
				'filterPlaceholder' => 'Search Attorney Name',
				'cellClass' => 'attorney'
			},
			{
				'Column' => 'Contact',
				'XMLField' => 'ContactInfo',
				'filterPlaceholder' => 'Search Contact Name',
				'cellClass' => 'contact'
			},
			{
				'Column' => 'Observer',
				'XMLField' => 'observer',
				'filterPlaceholder' => 'Search Observer Name',
				'cellClass' => 'observer'
			}
		);
	$data{'cookieName'} = "icms-med-cal";
} 
elsif($params{'calType'} eq "expcal"){

	getExParteCalendar(\@events, $start, $end, $division);
	
	# Use this to specify the order of the headers in a generated spreadsheet
	@exportHeaders = (
			{
				'Column' => 'Case Number',
				'XMLField' => 'CaseNumber',
				'cellClass' => 'link',
				'filterPlaceholder' => 'Part of Case #'
			},
			{
				'Column' => 'Law Firm',
				'XMLField' => 'LawFirm',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Select Law Firm',
				'cellClass' => 'lawFirm'
			},
			{
				'Column' => 'Case Style',
				'XMLField' => 'CaseStyle',
				'filterPlaceholder' => 'Part of Case Style',
				'cellClass' => 'caseStyle'
			},
			{
				'Column' => 'Division',
				'XMLField' => 'DivisionID',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Select Division',
				'cellClass' => 'timeDate'
			},
			{
				'Column' => 'Judge',
				'XMLField' => 'JudgeName',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Select Judge',
				'cellClass' => 'Judge'
			},
			{
				'Column' => 'Motion / Supporting Documents',
				'XMLField' => 'Motion',
				'filterPlaceholder' => 'Part of Motion / Supporting Documents',
				'cellClass' => 'motion'
			},
			{
				'Column' => 'Time',
				'XMLField' => 'StartTime',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Time',
				'cellClass' => 'timeDate'
			},
			{
				'Column' => 'Event Type',
				'XMLField' => 'EventType',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Type',
				'cellClass' => 'eventDesc'
			},
			{
				'Column' => 'Date',
				'XMLField' => 'StartDate',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Date',
				'cellClass' => 'timeDate'
			},
			{
				'Column' => 'Conf. Num',
				'XMLField' => 'OLSConfNum',
				'filterPlaceholder' => 'Search Conf #',
				'cellClass' => 'lawFirm'
			},
			{
				'Column' => 'Canceled',
				'XMLField' => 'isCanceled',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Select',
				'cellClass' => 'timeDate'
			},
			{
				'Column' => 'Notes',
				'XMLField' => 'EventNotes',
				'filterPlaceholder' => 'Search Notes',
				'cellClass' => 'notes'
			},
			{
				'Column' => 'Attorney',
				'XMLField' => 'AttorneyInfo',
				'filterPlaceholder' => 'Search Attorney Name',
				'cellClass' => 'attorney'
			},
			{
				'Column' => 'Contact',
				'XMLField' => 'ContactInfo',
				'filterPlaceholder' => 'Search Contact Name',
				'cellClass' => 'contact'
			}
		);
	$data{'cookieName'} = "icms-exp-cal";

}elsif($params{'calType'} eq "mhcal"){

	getMentalHealthCalendar(\@events, $start, $end, $division);
	
	# Use this to specify the order of the headers in a generated spreadsheet
	@exportHeaders = (
		{
			'Column' => 'Case Number',
			'XMLField' => 'CaseNumber',
			'cellClass' => 'widelink',
			'filterPlaceholder' => 'Part of case #'
		},
		{
			'Column' => 'Case Style',
			'XMLField' => 'CaseStyle',
			'filterPlaceholder' => 'Part of case style',
			'cellClass' => 'caseStyle'
		},
		{
			'Column' => 'Division',
			'XMLField' => 'DivisionID',
			'filterType' => 'filter-select',
			'filterPlaceholder' => 'Select Division',
			'cellClass' => 'timeDate'
		},
		{
			'Column' => 'Event Code',
			'XMLField' => 'EventCode',
			'filterType' => 'filter-select',
			'filterPlaceholder' => 'Code',
			'cellClass' => 'code'
		},
		{
			'Column' => 'Description',
			'XMLField' => 'EventType',
			'filterType' => 'filter-select',
			'filterPlaceholder' => 'Type',
			'cellClass' => 'eventDesc'
		},
		{
			'Column' => 'Magistrate',
			'XMLField' => 'JudgeName',
			'filterType' => 'filter-select',
			'filterPlaceholder' => 'Select Judge',
			'cellClass' => 'Judge'
		},
		{
			'Column' => 'Date',
			'XMLField' => 'StartDate',
			'filterType' => 'filter-select',
			'filterPlaceholder' => 'Date',
			'cellClass' => 'timeDate'
		},
		{
			'Column' => 'Time',
			'XMLField' => 'StartTime',
			'filterType' => 'filter-select',
			'filterPlaceholder' => 'Date',
			'cellClass' => 'timeDate'
		},
		{
			'Column' => 'Notes',
			'XMLField' => 'EventNotes',
			'filterPlaceholder' => 'Part of event note',
			'cellClass' => 'timeDate'
		},
		{
			'Column' => 'Source',
			'XMLField' => 'ImportSourceName',
			'filterType' => 'filter-select',
			'filterPlaceholder' => 'Select',
			'cellClass' => 'timeDate'
		},
		{
			'Column' => 'Canceled',
			'XMLField' => 'isCanceled',
			'filterType' => 'filter-select',
			'filterPlaceholder' => 'Select',
			'cellClass' => 'timeDate'
		}
	);
	
	$data{'cookieName'} = "icms-mh-cal";

}else {
	if ($has_ols) {		
		getVRBCalendar(\@events, $judgeID, $start, $end, $division, $vdbh, 1, "civ");
	        
		# Use this to specify the order of the headers in a generated spreadsheet
		@exportHeaders = (
			{
				'Column' => 'Case Number',
				'XMLField' => 'CaseNumber',
				'cellClass' => 'link',
				'filterPlaceholder' => 'Part of case #'
			},
			{
				'Column' => 'Law Firm',
				'XMLField' => 'LawFirm',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Select law firm',
				'cellClass' => 'lawFirm'
			},
			{
				'Column' => 'Case Style',
				'XMLField' => 'CaseStyle',
				'filterPlaceholder' => 'Part of case style',
				'cellClass' => 'caseStyle'
			},
			{
				'Column' => 'Judge',
				'XMLField' => 'JudgeName',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Select Judge',
				'cellClass' => 'Judge'
			},
			{
				'Column' => 'Motion / Supporting Documents',
				'XMLField' => 'Motion',
				'filterPlaceholder' => 'Part of Motion / Supporting Documents',
				'cellClass' => 'motion'
			},
			{
				'Column' => 'Time',
				'XMLField' => 'StartTime',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Time',
				'cellClass' => 'timeDate'
			},
			{
				'Column' => 'Event Type',
				'XMLField' => 'EventType',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Type',
				'cellClass' => 'eventDesc'
			},
			{
				'Column' => 'Date',
				'XMLField' => 'StartDate',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Date',
				'cellClass' => 'timeDate'
			},
			{
				'Column' => 'Conf. Num',
				'XMLField' => 'OLSConfNum',
				'filterPlaceholder' => 'Search Conf #',
				'cellClass' => 'lawFirm'
			},
			{
				'Column' => 'Source',
				'XMLField' => 'ImportSourceName',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Select',
				'cellClass' => 'timeDate'
			},
			{
				'Column' => 'Canceled',
				'XMLField' => 'isCanceled',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Select',
				'cellClass' => 'timeDate'
			},
			{
				'Column' => 'Attorney',
				'XMLField' => 'AttorneyInfo',
				'filterPlaceholder' => 'Search Attorney Name',
				'cellClass' => 'contact'
			},
			{
				'Column' => 'Contact',
				'XMLField' => 'ContactInfo',
				'filterPlaceholder' => 'Search Contact Name',
				'cellClass' => 'contact'
			}
		);
		
		# Add judge name if we're showing all judges
		if ($data{'allJudges'}) {
			foreach my $event (@events) {
				foreach my $judge (@judges) {
					next if ($judge->{'JudgeID'} ne $event->{'JudgeID'});
					$event->{'JudgeFullName'} = $judge->{'FullName'};
					last;
				}
			}
		}
		$data{'cookieName'} = "icms-ols-cal";
	} else {
		getVRBCalendar(\@events, $judgeID, $start, $end, $division, $vdbh, "civ");
		
		@exportHeaders = (
			{
				'Column' => 'Case Number',
				'XMLField' => 'CaseNumber',
				'cellClass' => 'link',
				'filterPlaceholder' => 'Part of case #'
			},
			{
				'Column' => 'Case Style',
				'XMLField' => 'CaseStyle',
				'filterPlaceholder' => 'Part of case style',
				'cellClass' => 'lawFirm'
			},
			{
				'Column' => 'Code',
				'XMLField' => 'EventCode',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Code',
				'cellClass' => 'code'
			},
			{
				'Column' => 'Description',
				'XMLField' => 'EventType',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Type',
				'cellClass' => 'eventDesc'
			},
			{
				'Column' => 'Judge',
				'XMLField' => 'JudgeName',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Select Judge',
				'cellClass' => 'Judge'
			},
			{
				'Column' => 'Date',
				'XMLField' => 'StartDate',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Date',
				'cellClass' => 'timeDate'
			},
			{
				'Column' => 'Time',
				'XMLField' => 'StartTime',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Time',
				'cellClass' => 'timeDate'
			},
			{
				'Column' => 'Notes',
				'XMLField' => 'EventNotes',
				'filterPlaceholder' => 'Part of event note',
				'cellClass' => 'timeDate'
			},
			{
				'Column' => 'Source',
				'XMLField' => 'ImportSourceName',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Select',
				'cellClass' => 'timeDate'
			},
			{
				'Column' => 'Canceled',
				'XMLField' => 'isCanceled',
				'filterType' => 'filter-select',
				'filterPlaceholder' => 'Select',
				'cellClass' => 'timeDate'
			},
		);
		$data{'cookieName'} = "icms-banner-cal";
	}
}

foreach my $event (@events) {
    if (!$secretUser) {
        if ($event->{'CaseNumber'} =~ /DP|CJ/) {
            $event->{'CaseStyle'} = '-- restricted case --';
        }
    }
}

# Check to see if there's an export XML def file.
my $exportXMLdef = sprintf("/var/www/cgi-bin/case/calendars/exportXMLdefs/cal_def_%s.xml", uc($division));
if (-e $exportXMLdef) {
	$data{'exportXMLdef'} = $exportXMLdef;
}

$data{'exportHeaders'} = \@exportHeaders;
$data{'calType'} = $params{'calType'};
$data{'division'} = uc($division);
$data{'division'} =~ s/,/-/g;

# Go through the @events; for those that have nulls for the judge, add it from the %divJudges array
foreach my $event (@events) {
	if (!defined $event->{'JudgeName'}) {
		$event->{'JudgeName'} = $divJudges{uc($division)}->{'JudgeName'};
	}
}

$data{'divType'} = $divtype;
$data{'cases'} = \@events;
$data{'lev'} = 3;
if ($divtype eq "fap") {
	$data{'dTitle'} = sprintf("First Appearance Calendar for Division %s, %s - %s, %d Rows", $division,
						  $data{'start'}, $data{'end'}, scalar(@events));
} else {
	$data{'dTitle'} = sprintf("Calendar for Division %s, %s - %s, %d Rows", $division,
						  $data{'start'}, $data{'end'}, scalar(@events));
}

$data{'tmpfile'} = writeXmlFile(\%data, \@exportHeaders);
$data{'foo'} = writeJsonFile(\%data);

my $json_text = JSON->new->ascii->encode(\%data);

print $info->header(
    -type => 'application/json',
    -expires => '-1d'
);
print $json_text;