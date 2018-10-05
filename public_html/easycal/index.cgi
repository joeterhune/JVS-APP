#!/usr/bin/perl

BEGIN {
	use lib "/usr/local/icms/bin";
}

use strict;
use Common qw (
	dumpVar
	doTemplate
	inArray
	today
	$templateDir
	fatalError
);

use DB_Functions qw (
	dbConnect
	getData
	getDivsLDAP
);

use Calendars qw (
	@MONTHS
	writeEasyCal
	$easyCalDir
	%caseTypes
);



use CGI;
use CGI::Carp qw(fatalsToBrowser);


my $info = new CGI;
print $info->header();

# Get a listing (from AD) of the court divisions to which the user is assigned.
my @divs;

getDivsLDAP(\@divs);

if (!scalar(@divs)) {
	fatalError("We couldn't find your division association.");
	exit;
}

my %data;
$data{'divisions'} = \@divs;
$data{'months'} = \@MONTHS;

if (defined($info->param('year'))) {
	my $div = $info->param('division');
	
	if (!inArray(\@divs,$div)) {
		fatalError("You do not have permission to edit the calendar for division '$div'.");
		exit;
	}
	
	$data{'division'} = $div;
	
	my $relPath = $easyCalDir;
	$relPath =~ s/^$ENV{'DOCUMENT_ROOT'}//i;
	$data{'subscribeLink'} = "webcal://$ENV{'HTTP_HOST'}/$relPath/div$div.ics";
	
	my $params = $info->Vars;
	
	my $dbh = dbConnect("easycal");
		
	my $hearingTypeId = $params->{'hearingtype'};
	my $hearingDate = sprintf("%04d-%02d-%02d", $params->{'year'}, $params->{'month'},
							  $params->{'day'});
	my $startTime =sprintf ("%s %02d:%02d:00", $hearingDate, $params->{'starthour'},
							$params->{'startmin'});
	my $endTime =sprintf ("%s %02d:%02d:00", $hearingDate, $params->{'endhour'},
						  $params->{'endmin'});
	my $caseNum = sprintf ("%04d-%s-%06d", $params->{'caseyear'},$params->{'casetype'},
						   $params->{'caseseq'});
	my $caseStyle = $params->{'casestyle'};
	my $lawFirm = $params->{'lf_name'};
	my $user = $ENV{'REMOTE_USER'};
	my $uuid = "$hearingDate-$startTime-$caseNum-$div-$$\@pbvgoc.org";
	
	# Check to see if the event already exists.
	my $query = qq {
		select
			hearing_start_time,
			case_num
		from
			hearings
		where
			hearing_start_time = '$startTime'
			and case_num = '$caseNum'
			and division = '$div'
			and removed = 0
	};
	my @temp;
	getData(\@temp,$query,$dbh);
	
	if (scalar(@temp)) {
		$data{'alreadyExists'} = 1;
		$data{'exists'} = $temp[0];
		writeEasyCal($div, $dbh);
	} else {
		
		# add_cal_event is a MySQL stored function
		$query = qq {
			select
				add_cal_event(?,?,?,?,?,?,?,?,?) as hearing_id
		};
		
		my $sth = $dbh->prepare_cached($query);
		
		my $rv = $sth->execute(
			$div,
			$caseNum,
			$caseStyle,
			$hearingTypeId,
			$startTime,
			$endTime,
			$lawFirm,
			$uuid,
			$user
		);
		writeEasyCal($div, $dbh);
		$data{'added'} = 1;
	}
	doTemplate(\%data,$templateDir,"easycal-done.html",1);
	exit;
} else {
	my $ecdbh = dbConnect("easycal");
	
	my @hearingTypes;
	my $query = qq {
		select
			hearing_type_id,
			hearing_type_desc
		from
			hearing_types
		order by
			hearing_type_desc
	};
	getData(\@hearingTypes,$query,$ecdbh);
	$data{'hearingTypes'} = \@hearingTypes;
	my $today = today();
	my ($month,$day,$year) = split(/\//,today());
	$data{'year'} = $year;
	# How many years out can a hearing be scheduled?
	$data{'yearsout'} = 1;
	# What is the earliest year for which we want to allow a case?
	$data{'earliest'} = 1990;
}

doTemplate(\%data,$templateDir,"easycal-index.html",1);
exit;



