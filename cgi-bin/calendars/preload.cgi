#!/usr/bin/perl -w

BEGIN {
	use lib "$ENV{'JVS_PERL5LIB'}";
	$ENV{'TNS_ADMIN'} = "/var/www/";
};

use strict;
use Common qw (
	dumpVar
);

use Showcase qw (
	$db
);

use DB_Functions qw (
    dbConnect
    getData
    getDbSchema
);

use XML::Simple;

use Images qw (
    getImagesFromNewTM
);

use CGI;

my $info = new CGI;
print $info->header;

my %params = $info->Vars;

my $caseList = $params{'cases'};

my @cases = split(",", $caseList);

my $conf = XMLin("$ENV{'JVS_ROOT'}/conf/ICMS.xml");
my $TMPASS = $conf->{'TrakMan'}->{'nosealed'}->{'password'};
my $TMUSER = $conf->{'TrakMan'}->{'nosealed'}->{'userid'};

my $dbh = dbConnect($db);
my $schema = getDbSchema($db);

foreach my $case (@cases) {
	my $query = qq {
		select
		    ObjectID as object_id,
		    DocketCode as code,
		    SeqPos,
		    CONVERT(varchar(10),CreateDate,120) as dt_created
		from
		    $schema.vDocket with(nolock)
		where
		    CaseNumber = ?
		    and DocketCode in ('CIT','DLHIST','DLHISD')
	};

	my @images;
	getData(\@images, $query, $dbh, {valref => [$case], hashkey => 'code'});
	
	# Now get the Object ID of the highest sequence number for each.
	#my @images;
	#foreach my $doctCode (keys %items) {
	#    my @sorted = sort { $b->{'SeqPos'} <=> $a->{'SeqPos'}} @{$items{$doctCode}};
	#    push(@images, $sorted[0]);
	#}

	my $pdfListFile = getImagesFromNewTM(\@images,undef,$TMUSER,$TMPASS);

	open(PDFLIST, $pdfListFile) ||
	    die "Unable to open PDF list '$pdfListFile': $!\n\n";
    
	while (my $pdf = <PDFLIST>) {
	    chomp($pdf);
	    # Move it to web space
	    rename($pdf, "/var/www/html/$pdf");
	}
}

print "Success";

exit;