#!/usr/bin/perl

BEGIN {
	use lib "$ENV{'PERL5LIB'}";
}

use strict;
use XML::Simple;

use ICMS;
use Common qw (
	dumpVar
	getShowcaseDb
);
use DB_Functions qw (
	dbConnect
	getDataOne
	getDbSchema
);
use CGI qw (fatalsToBrowser);

my $db = getShowcaseDb();
my $dbh = dbConnect($db);
my $schema = getDbSchema($db);

my $info = new CGI;

my %params = $info->Vars;

my $dbh = dbConnect("eservice");

my $tmpcase = $params{'casenum'};

my $retVal = undef;

# Is it a criminal case?

$tmpcase = uc($tmpcase);

my $isCrim = 0;

foreach my $ct (@CRIMCODES) {
	$ct =~ s/'//g;
	if ($tmpcase =~ /$ct/) {
		$isCrim = 1;
		last;
	}
}

$tmpcase =~ s/-//g;
$tmpcase =~ s/^50//;

	if ($tmpcase =~ /^(\d{1,6})(\D\D)(\d{0,6})(.*)/) {
		my $year = $1;
		my $type = $2;
		my $seq = $3;
		my $other = $4;
		
        if ($year < 100) {
            if ($year > 20) {
                $year = sprintf("19%02d", $year);
            } else {
                $year = sprintf("20%02d", $year);
            }
        }
				
		my $casenum;
		$casenum = sprintf("50%04d%s%06d%s", $year, $type, $seq, $other);
		$casenum = uc($casenum);	
		my $query = qq {
			select
				CaseNumber as casenum,
				DivisionID as case_div,
				CaseStyle as case_style
			from
				$schema.vCase with(nolock)
			where
				UCN like '$casenum%'
		};
		
		$retVal = getDataOne($query,$dbh);

	}

my $xs = XML::Simple->new(RootName => 'Response', NoAttr => 1, KeepRoot => 1);
my $xml = $xs->XMLout($retVal);
print $info->header("text/xml");
print $xml;


