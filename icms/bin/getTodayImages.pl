#!/usr/bin/perl -w

# Pre-fetch images from TrakMan for cases that are scheduled today.

BEGIN {
    use lib "/usr/local/icms/bin";
}

use strict;
use Common qw (
    dumpVar
    today
    makePaths
);
use DB_Functions qw (
    dbConnect
    getVrbCases
);
use Getopt::Long;
use MIME::Base64;
use File::Path qw (
	remove_tree
);
use XML::Simple;

my $MAX_CHILDREN = 3;
my $dbh = dbConnect("vrb2");

my @caseList;

# Allow the user to specify case numbers on the command line
GetOptions("c=s" => \@caseList);
if (!scalar(@caseList)) {
	getVrbCases(\@caseList, $dbh);
}

# Now get the files for the cases.  Fork them off and get more than one at a time
my @childPids;
foreach my $casenum (@caseList) {
    my $pid = fork;
    if ($pid) {
        push (@childPids, $pid);
		if (scalar(@childPids) == $MAX_CHILDREN) {
            my $finished = wait();
            my $count = 0;
            while ($count < scalar(@childPids)) {
                if ($finished == $childPids[$count]) {
                    splice(@childPids, $count, 1);
                    last;
                } else {
                    $count++;
                }
            }
        }
    } else {
        if ($casenum =~ /50-(\d\d\d\d)-(\D\D)-(\d\d\d\d\d\d)-(\D\D\D\D)-(\D\D)/) {
            # A Showcase case.  Strip the dashes because that's what TrakMan wants
            $casenum =~ s/-//g;
        } else {
            # A Banner case.  Strip the leading 50 because TrakMan doesn't have it
            $casenum =~ s/^50//g;
			# We actually don't need to get Banner right now
			exit;
        }
        
		getDockets($casenum, "/var/www/html/case/casefiles");
        exit;
    }
}

foreach my $child (@childPids) {
    my $finished = waitpid($child, 0);
    #print "Child '$finished' returned...\n";
}



sub getDockets {
    my $caseNum = shift;
    my $topDir = shift;
    
    my $targetDir = sprintf("%s/%s", $topDir, $caseNum);
    
    if (!-d $targetDir) {
        makePaths($targetDir);
		# Make sure it's owned by Apache so we don't get bitten later
		my ($name,$passwd,$uid,$gid,$quota,$comment,$gcos,$dir,$shell,$expire) = getpwnam("apache");
		chown($uid, $gid, $targetDir);
    }
    
    print "Getting dockets for '$caseNum'...\n";

    my $xml;
    eval {
		my $command = "/usr/bin/php /usr/local/icms/bin/getTmImages.php -c $caseNum";
		$xml = `$command`;
    };
    
    if ($@) {
        die "Error retrieving images for $caseNum: $@";
    }
    
    my $xs = XML::Simple->new();
    my $ref = $xs->XMLin($xml);

    processFiles($ref, $targetDir);
}


sub processFiles {
    my $docRef = shift;
    my $targetDir = shift;
	
	my $tmmount = "/mnt/tmweb/PROD";
    
    my $tmpPath = sprintf("%s/tmp", $targetDir);
    
    makePaths($targetDir,$tmpPath);
    
    if (defined($docRef->{'s:Body'}->{'RetrieveCaseDocumentsResponse'}->
                {'RetrieveCaseDocumentsResult'}->{'a:RetrieveCaseDocsOutput'})) {
        my $objects = $docRef->{'s:Body'}->{'RetrieveCaseDocumentsResponse'}->
            {'RetrieveCaseDocumentsResult'}->{'a:RetrieveCaseDocsOutput'};
        $objects = [ $objects ] if ref($objects) ne "ARRAY";
        
        my %toConvert;
        
        foreach my $object (@{$objects}) {
            my $objectID = $object->{'a:objectIDField'};
            
            if ($object->{'a:statusField'} =~ /case is sealed/) {
                die "Unable to retrieve documents for sealed case.";
			}
            
            if ((defined($object->{'a:filePathSpecifiedField'})) && ($object->{'a:filePathSpecifiedField'} =~ /true/i)) {
                # We have to get the files from the image mount
                my @temp = split(/\\/,$object->{'a:filePathField'});
                my $path = $temp[scalar(@temp) - 1];
				$toConvert{$objectID}= "$tmmount/$path";
			} else {
                my $tifName = sprintf("%s/%s.tif", $tmpPath, $objectID);
                # Need to create the file if it doesn't already exist
                if (!-e $tifName) {
                    my $tifdata = decode_base64(decode_base64($object->{'a:fileField'}));
                    open(TIF, ">$tifName") ||
                        die "Unable to save TIF file '$tifName': $!\n\n";
                    print TIF $tifdata;
                    close TIF;
   
				}
                $toConvert{$objectID} = $tifName;
            }
		}
        
        my @childPids;
        
        foreach my $objId (keys %toConvert) {
            my $pid = fork;
            
            if ($pid) {
                push (@childPids, $pid);
                
                if (scalar(@childPids) == 5) {
                    my $finished = wait();
                    my $count = 0;
                    while ($count < scalar(@childPids)) {
                        if ($finished == $childPids[$count]) {
                            splice(@childPids, $count, 1);
                            last;
                        } else {
                            $count++;
                        }
                    }
                }
            } else {
                my $outFile = sprintf("%s/%s.pdf", $targetDir,$objId);
                my $tifCmd = "/usr/bin/tiff2pdf -o \"$outFile\" \"$toConvert{$objId}\" >/dev/null 2>&1";
                my $res = system($tifCmd);
                unlink $toConvert{$objId};
                exit;
            }
        }
        
        foreach my $child (@childPids) {
            my $finished = waitpid($child, 0);
        }
        
        remove_tree($tmpPath);
        return 0;
	} else {
        print "Got nothing for $targetDir...\n";
        remove_tree($targetDir);
        return 1;
    }
}
