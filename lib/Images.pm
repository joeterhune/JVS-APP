package Images;
use strict;
use warnings;
use File::Basename;
use XML::Simple;
use MIME::Base64;
use Date::Manip;
use File::Temp qw (tempfile);

use Common qw (
	dumpVar
	doTemplate
	$templateDir
	makePaths
    getArrayPieces
);

use DB_Functions qw (
    dbConnect
    getData
);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
	buildImageFile
	createPDF
	getImagesFromNewTM
	pdf_info
);

use File::Copy;

my $tmmount = "/mnt/tmweb/PROD";

sub createPDF {
	# The path of the PDF to be created
	my $outPath = shift;
	# The path of the TIF to use to create the PDF
	my $tifPath = shift;
	
	$outPath =~ s/^$tmmount/\/tmp/;
	
	my $outDir = dirname($outPath);
	if (!-d $outDir) {
		makePaths($outDir);
	}
	
	#my $tifCmd = "convert $tifPath $outPath >/dev/null 2>&1";
	my $tifCmd = "tiff2pdf -o $outPath $tifPath >/dev/null 2>&1";
	
	if (! -e $outPath) {
		# No sense running the conversion if it already exists
		my $res = system($tifCmd);
		
		# Run tiff2pdf again if there was an error
		if($res != 0){
			$res = system($tifCmd);
		}
		
		# Clean up the TIF file.
		#unlink $tifPath;
	}
}

sub pdf_info {
	my $file = shift;
	
	my @results = `pdfinfo $file`;
	return \@results;
}

sub buildImageFile {
	my $pdfListFile = shift;
	my $imageref = shift;
	my $docref = shift;
	my $case = shift;
	my $templateFile = shift;
	my $tmpFileDir = shift;
	my $withEnv = shift;
	
	if (!defined($withEnv)) {
		$withEnv = 0;
	}
	
	if (!defined($templateFile)) {
		$templateFile = "latex-casefile.tt";
	}

	my $hadTmpDir = 1;
	if (!defined($tmpFileDir)) {
		$tmpFileDir = "$ENV{'JVS_ROOT'}/tmp";
		$hadTmpDir = 0;
	}

	my ($cfgfh, $cfgfile) = tempfile (
		DIR => "$ENV{'JVS_ROOT'}/tmp",
		UNLINK => 0
	);

	# We don't actually need the filehandle here, just a unique filename
	close $cfgfh;

	my $rdfile = basename($cfgfile) . ".pdf";

	my $command;
	my $filename;
	my $usePdfTex = 0;
	
	if (((!defined($imageref)) || (scalar(@{$imageref}) > 1)) && (!$withEnv)) {
		my %data;
		$data{'CaseNumber'} = $case;
		$data{'CaseDocs'} = $docref;
		
		my $texinfo = doTemplate(\%data, $templateDir, $templateFile, 0);
		my $fh = File::Temp->new(
								 DIR => "/tmp",
								 UNLINK => 0
								 );
		my $texFile= $fh->filename;
		print $fh $texinfo;
		close $fh;
		#
		my $pdflatex = `which pdflatex`;
		chomp $pdflatex;
	
		$command = "$pdflatex -output-directory /tmp -interaction batchmode $texFile";
		$filename = basename("$texFile.pdf");
		$usePdfTex = 1;
	} else {
		$command = "gs -q -dBATCH -dNOPAUSE -sDEVICE=pdfwrite -sOUTPUTFILE=".
		"$tmpFileDir/$rdfile \@$pdfListFile > /dev/null 2>&1";
		$filename = $rdfile;
	}
	
	#print "Content-type: text/plain\n\n"; print "COMMAND: '$command'"; exit;
	
	my $res = system($command);
	if ((($usePdfTex) && (($res >> 8) > 1)) || ((!$usePdfTex) && $res)) {
		print "Content-type: text/html\n\n";
		print "There was a problem creating the PDF. Please try again later.";
		return undef;
		exit;
	}
	
	my $pdfFile = sprintf("%s/%s", $tmpFileDir, $filename);
	rename("/tmp/$filename", $pdfFile);
    
	if (!$hadTmpDir) {
		return "tmp/$filename";
	} else {
		return "$tmpFileDir/$filename";
	}
}

sub getImagesFromNewTM {
    my $images = shift;
	my $docref = shift;
	my $user = shift;
	my $pass = shift;
	my $showTif = shift;
    my $tmpPath = shift;
	my $casenum = shift;
	my $workPath = shift;
	my $pdforder = shift;
	
    if (!defined($tmpPath)) {
        $tmpPath = $ENV{'JVS_ROOT'} . "/tmp";
    }
	
	if (! -d $tmpPath) {
		# The tmpPath directory doesn't exist. Make it.
		makePaths(($tmpPath));
	}
	
	if (! -d "$ENV{'JVS_DOCROOT'}/tmp") {
		makePaths("$ENV{'JVS_DOCROOT'}/tmp");
	}
	
	if (!defined($pdforder)) {
		$pdforder = "desc";
	}

	my $listfh = new File::Temp (
		UNLINK => 0,
		DIR => $tmpPath
	);
	
	my $listfn = $listfh->filename;
	
	my $tempPath = $ENV{'JVS_DOCROOT'} . "/tmp";
	if (defined($workPath)) {
		$tempPath = $workPath;
	}
	
	# Build a listing of all of the objectIDs that have been requested.  If the file already exists
	# in $tmpPath, skip it - no sense retrieving something we already have
	my @objects;

	# A hash, keyed on the object ID, of the TIF files to be converted
	my %toConvert;
	
	foreach my $image (@{$images}) {
		my $objid = $image->{'ObjectId'};
		
		next if (!defined($objid));
		
		$image->{'date'} = UnixDate(ParseDate((split(/\s+/,$image->{'EffectiveDate'}))[0]),'%Y-%m-%d');
		$image->{'code'} = $image->{'DocketDescription'};
		$image->{'object_id'} = $image->{'ObjectId'};
		
		if (!-e "$tmpPath/$objid.tif"){
			# The file doesn't already exist, so we want to grab it.
			push(@objects,$objid);
		} else {
			# We already have the file. Do we have a corresponding PDF?
			if (!-e "$tempPath/$objid.pdf") {
				$toConvert{$objid} = "$tmpPath/$objid.tif";
			} else {
				$image->{'pdf_file'} = "$tempPath/$objid.pdf";
			}
		}
	}
	
	if (scalar(@objects) || (defined($casenum))) {
		# No sense in retrieving files we already have - if we're here, there is at least
		# one object ID requested
		my $objids = join(",", @objects);

		my $xml;
		if (!defined($casenum)) {
			$xml = qq {<?xml version="1.0"?>
			  <RetrieveCaseDocsInput xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
			      xmlns:xsd="http://www.w3.org/2001/XMLSchema"
			      xmlns="http://www.csisoft.com/2010/1.0/RetrieveCaseDocsInput.xsd">
			          <UserID>$user</UserID>
			          <Password>$pass</Password>
			          <ObjectID>$objids</ObjectID>
			  </RetrieveCaseDocsInput>
			};
		} elsif (scalar(@objects)) {
			$xml = qq {<?xml version="1.0"?>
			  <RetrieveCaseDocsInput xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
			      xmlns:xsd="http://www.w3.org/2001/XMLSchema"
			      xmlns="http://www.csisoft.com/2010/1.0/RetrieveCaseDocsInput.xsd">
			          <UserID>$user</UserID>
			          <Password>$pass</Password>
			          <CaseNumber>$casenum</CaseNumber>
			  </RetrieveCaseDocsInput>
			};
		}
		
		
		my $fh = File::Temp->new(DIR => $tmpPath,UNLINK => 0,SUFFIX => '.meta');
		my $filename = $fh->filename;
		print $fh $xml;
		
		my $retfile = `export JVS_ROOT=$ENV{'JVS_ROOT'}; /usr/bin/php $ENV{'JVS_ROOT'}/bin/getTmImages.php -f $filename`;
		
		my $docRef;

		eval {
			$docRef = XMLin($retfile);
		};
		if ($@) {
			print "Content-type: text/html\n\n";
			print qq {
				We have experienced an error retrieving the image from the TrakMan service.  We
				apologize for the inconvenience.
				<br/>
				<br/>
				We are working to resolve the issue at this time, and we appreciate
				your patience.
			};

			# Send the actual error to STDERR
			print STDERR $@;
			exit;
		}

		if (defined($docRef->{'s:Body'}->{'RetrieveCaseDocumentsResponse'}->
					{'RetrieveCaseDocumentsResult'}->{'a:RetrieveCaseDocsOutput'})) {
		    my $objects = $docRef->{'s:Body'}->{'RetrieveCaseDocumentsResponse'}->
		        {'RetrieveCaseDocumentsResult'}->{'a:RetrieveCaseDocsOutput'};

		    $objects = [ $objects ] if ref($objects) ne "ARRAY";

			foreach my $object (@{$objects}) {
		        my $objectID = $object->{'a:objectIDField'};

				if ($object->{'a:statusField'} =~ /case is sealed/) {
					print "Content-type: text/html\n\n";
					#print $object->{'a:statusField'};
					print "This document is sealed by court order. Access is denied.";
					exit;
				}
				
				if ($object->{'a:statusField'} =~ /Access is denied/) {
					print "Content-type: text/html\n\n";
					#print $object->{'a:statusField'};
					print "This document is restricted. Access is denied.";
					exit;
				}


		        if ($object->{'a:statusField'} !~ /Success/i) {
		            $toConvert{'objectID'} = 'FAILED';
		            next;
		        }

				if ((defined($object->{'a:filePathSpecifiedField'})) && ($object->{'a:filePathSpecifiedField'} =~ /true/i)) {
				    # We have to get the files from the image mount
					my @temp = split(/\\/,$object->{'a:filePathField'});
					my $pieces = scalar(@temp);
					my $path = $temp[$pieces-1];
                    # Copy the image from the filesystem to /tmp on this server
					copy("$tmmount/$path", "$tmpPath/$objectID.tif");
					$toConvert{$objectID} = "$tmpPath/$objectID.tif";
				} else {
				    # Need to create the file if it doesn't already exist
				    if (!-e "$tmpPath/$objectID.tif") {
				        my $tifdata = decode_base64(decode_base64($object->{'a:fileField'}));
				        open(TIF, ">$tmpPath/$objectID.tif");
				        print TIF $tifdata;
				        close TIF;
				    }
				    $toConvert{$objectID} = "$tmpPath/$objectID.tif";
				}
				if (defined($casenum)) {
					# Since this is a listing of all case docs for a particular case, then
					# we need to put stuff into the $images hash
					my %temp = (
						'file_size' => $object->{'a:fileSizeField'},
						'date' => UnixDate(ParseDate($object->{'a:eventDateField'}), '%Y-%m-%d'),
						'f_name' => $toConvert{$objectID},
						'object_id' => $objectID,
						'cms_document_id' => $object->{'a:cmsDocumentIDField'},
						'code' => $object->{'a:eventDescriptionField'}
					);
					push(@{$images}, \%temp);
				}

			}
		}
	}
	
	# Be sure the images are sorted by date - newest first!
	#foreach my $image (sort { $a->{'date'} cmp $b->{'date'} } @{$images}) {
	
	foreach my $image (sort { if ($pdforder eq 'asc') {$a->{'date'} cmp $b->{'date'} } else {$b->{'date'} cmp $a->{'date'}}} @{$images}) {
		# Find the appropriate
		my $obj = $image->{'ObjectId'};
        my $path;
		if (defined($toConvert{$obj})) {
			$path = $toConvert{$obj};
		} else {
			$path = sprintf("$tmpPath/%s.tif", $image->{'ObjectId'});
		}

		my $pdfPath;

		if (!defined($workPath)) {
			$pdfPath = "$tmpPath/$obj.pdf";
			$pdfPath =~ s/^$tmmount/\/tmp/;
		} else {
			# We were given a directory name from the system call.
			my $filename = basename($obj);
			$pdfPath = sprintf("%s/%s.pdf", $workPath, $filename);
		}
		
		if ((defined($showTif)) && ($showTif)) {
			# Just create a symlink to the original and redirect the user.
            #print "Content-type: text/html\n\n"; dumpVar($image); exit;
			my $basefile = basename($path);
			
			if (!-e "$ENV{'JVS_DOCROOT'}/tmp/$basefile") {
				symlink($path,"$ENV{'JVS_DOCROOT'}/tmp/$basefile");
			}
			print "Location: http://$ENV{'HTTP_HOST'}/tmp/$basefile\n\n";
			exit;
		}

		if (defined($path)) {
			createPDF($pdfPath,$path);
		}
	
		# Determine the page orientation so we can specify correctly with pdflatex
		my $pdfinfo = pdf_info($pdfPath);
		
		#Check to see if PDF has any issues... 
		foreach my $line (@{$pdfinfo}) {
			if($line =~ /^Error/){
				#Create it again if there's an error
				unlink $pdfPath;
				createPDF($pdfPath, $path);
				
				#Get new pdfinfo
				$pdfinfo = pdf_info($pdfPath);
			}
		}

		foreach my $line (@{$pdfinfo}) {
			next if ($line !~ /^Page size/);
			my @pieces = split(/\s+/, $line);
			# If x dimension > y dimension, it's landscape.
			$image->{'landscape'} = ($pieces[2] > $pieces[4]) ? 1 : 0;
		}
		
		# If the image is landscaped, then we need to get the page count so we rotate
		# all of the pages.
		$image->{'pagelist'} = "-";
		#if ($image->{'landscape'}) {
			foreach my $line (@{$pdfinfo}) {
				next if ($line !~ /^Pages/);
				chomp($line);
				my $pagecount = (split(/\s+/,$line))[1];
				$image->{'pagecount'} = $pagecount;
				if ($pagecount > 1) {
					$image->{'pagelist'} = "1-$pagecount";
				}
			}
		#}
		
		push (@{$docref}, {
			landscape => $image->{'landscape'},
			tiff => $path,
			file => $pdfPath,
			pagecount => $image->{'pagecount'},
			code => $image->{'code'},
			date => $image->{'date'},
			object_id => $image->{'object_id'}
			}
		);
		if (defined($path)) {
			print $listfh "$pdfPath\n";
		} else {
			print $listfh "$image->{'pdf_file'}\n";
		}
	}
		
	close ($listfh);
	return $listfn;
}

1;
