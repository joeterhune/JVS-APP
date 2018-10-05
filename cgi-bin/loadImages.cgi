#!/usr/bin/perl -w

BEGIN {
    use lib $ENV{'PERL5LIB'};
}

use strict;

use Common qw (
    dumpVar
);

use Images qw (
    getImagesFromNewTM
);

use Showcase qw (
    $db
    getDockets
);

use DB_Functions qw (
    dbConnect
    getDbSchema
    getData
);

use CGI;

use XML::Simple;

my $MAX_CHILDREN = 5;

my $info = new CGI;
print $info->header;
my %params = $info->Vars;
my $caselist = $info->param('caselist');
my @cases = split(",", $caselist);
#@cases = ("50-2012-TR-098065-AXXX-SB", "50-2009-MM-018477-AXXX-SB");

my $conf = XMLin("$ENV{'APP_ROOT'}/conf/ICMS.xml");
my $TMPASS = $conf->{'TrakMan'}->{'nosealed'}->{'password'};
my $TMUSER = $conf->{'TrakMan'}->{'nosealed'}->{'userid'};

# Ok, now for each of the cases specified, get the listing of images
# so we can pull down any images that aren't already in the cache.

my @pdfLists;
my $schema = getDbSchema($db);
my $dbh = dbConnect($db);

my @images;

foreach my $case (@cases) {
    my $docketRef = [];
    getDockets($case, $dbh, $docketRef, $schema);
    
    foreach my $docket (@{$docketRef}) {
        next if (!defined($docket->{'ObjectID'}));
        my %temp = (
                    'object_id' => $docket->{'ObjectID'},
                    'dt_created' => $docket->{'EffectiveDate'}
                    );
        push (@images, \%temp);
    }
}

my $pdfListFile = getImagesFromNewTM(\@images, undef, $TMUSER, $TMPASS);
open(INFILE, "$pdfListFile") ||
    die "Can't open file '$pdfListFile': $!\n\n'";
            
# Move the files into /var/www/html/tmp
while (my $line = <INFILE>) {
    chomp $line;
    if (-f $line) {
        rename ($line, "/var/www/html/$line");
    }
}

close INFILE;

print "Done!";