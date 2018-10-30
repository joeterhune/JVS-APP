#!/usr/bin/perl
#
#  SRS.pm -- shared subroutines for SRS Status
#
# 08/18/10 lms new file created for accessing SRS status

package SRS;

BEGIN {
	use lib "$ENV{'PERL5LIB'}";
}

use strict;

use DB_Functions qw (
    dbConnect
    getData
);
use Common qw(
    inArray
    dumpVar
    timeStamp
    @INACTIVECODES
    writeXmlFromHash
);

my $DEBUG=0; # set to 1 to read srsstatus.txt file
my $MSGS=0;  # set to 1 to see messages

use Exporter();
our @ISA=qw(Exporter);
our @EXPORT_OK = qw (
    buildSRSStatus
    buildSRSList
    isStatusInList
    isStatusNull
);

#
# Build SRS style list using new status function call - - no longer pulling cases by cdbcase_dtyp_code_status
#
# Pass $casetypes like this:  "('CJ','DP')"  (for sql call)
# Pass $include like this: "('OPEN','PE','RO')"
# Pass $exclude like this:  "('CLSD','PCA')"  (for sql call) - - if "" is passed, won't be used.  Put 'none' in
# the list to exclude null cases.
# Pass $outpath to write the file to the correct place.  May eventually not write it.
# Returns the srsstatus hash, with any null status returned as 'none' in the hash, ordered by case # descending.
#
sub buildSRSStatus {
    if($MSGS) {
		print "\n----- starting buildsrsstatus at ".timeStamp()."\n";
	}
    my $srsref = shift;
    my $casetypes = shift;
    my $include = shift;
    my $exclude = shift;
    my $outpath = shift;
	my $dbh = shift;
	
	if (!defined($dbh)) {
		$dbh = dbConnect("wpb-banner-rpt");
	}
    
	use XML::Simple;
	
    if($MSGS) {
		print "casetypes are: $casetypes \n";
		print "include is $include \n";
		print "exclude is $exclude \n";
		print "outpath is $outpath \n";
    }
	
	if($DEBUG) {
		print "DEBUG: Reading srsstatus.txt from $outpath \n";
		#%srsstatus=readhash("$outpath/srsstatus.txt");
	} else {
		my $query = qq {
			select
				cdbcase_id as "CaseNumber",
				nvl(srs_status_code(cdbcase_id),'none') as "SRSStatus"
			from
				cdbcase
			where
				cdbcase_cort_code in $casetypes
				and cdbcase_sealed_ind <> 3
		};
		
		if($include ne "") {
			$query .= qq{
				and nvl(srs_status_code(cdbcase_id),'none') in $include
			};
		}
		
		if($exclude ne "") {
			$query .= qq{
				and nvl(srs_status_code(cdbcase_id),'none') not in $exclude
			};
		}
		
		$query .= qq{
			order by cdbcase_id desc
		};

		if($MSGS) {
			print "doing this query to get SRS status hash:\n $query \n";
		}
		
		print "Starting SRS Query..." . timeStamp() . "\n";
		my @srs;
		getData(\@srs,$query,$dbh);
		foreach my $srs (@srs) {
			$srsref->{$srs->{'CaseNumber'}} = $srs->{'SRSStatus'};
		}
		
		print "SRS Query finished..." . timeStamp() . "\n";
		if($MSGS) {
			print "query finished ".timeStamp()."\n";
		}

        writeXmlFromHash("$outpath/srsstatus.xml", $srsref);
	}

	if($MSGS) {
		print "query finished ".timeStamp()."\n";
	}
	
	if($MSGS) {
		my @s = keys %{$srsref};
		print "size of srsstatus is: " . scalar(@s) . " ".timeStamp()."\n";
		print "\n----- finished buildsrsstatus at ".timeStamp()."\n\n";
	}
}


# Check if case has status that is in the passed list.
# Pass case number, srsstatus hash, and list (like this: ',x,y,z,'  ).
# Return true or false.
sub isStatusInList {
    my ($case,$list,%srsstatus) = @_;
	if (defined $srsstatus{$case}) {
	    if ($list=~/,$srsstatus{$case},/) { return "true"; }
	}
	return "false";
}

# Check if the case status is null (which will be 'none' based on buildsrsstatus).
sub isStatusNull {
    my ($case,%srsstatus) = @_;
	if (defined $srsstatus{$case}) {
	    if ($srsstatus{$case} eq "none") { return "true"; }
	}
	return "false";
}



#
# build the srs status list per case.
#
sub buildSRSList {
	my $srsref = shift;
	my $outpath = shift;
	my $casetypes = shift;
	my $dbh = shift;
	
	my %allsrs;
    
	if($MSGS) {
		print "getting all srs status ".timeStamp()."\n";
	}
    
	buildSRSStatus(\%allsrs,$casetypes,"","",$outpath, $dbh);
	if($MSGS) {
		my $k = keys %allsrs;
		print "there are $k keys in allsrs ".timeStamp()."\n";
		print "getting rid of those we don't want \n";
	}
    
    my @skipcodes = (@INACTIVECODES, "none");
    
	# get rid of those we don't want
	foreach my $c (keys %allsrs) {
		my $s = $allsrs{$c};
		if(!inArray(\@skipcodes, $s)) {
			$srsref->{$c} = $allsrs{$c};
		}
	}
	
	if($MSGS) {
        my $k=keys %{$srsref};
		print "there are $k keys in srsstatus ".timeStamp()."\n";
	}
    
}





1;
