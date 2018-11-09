package Orders;
use strict;
use warnings;
use ICMS;
use File::Temp ();
use PDF::Create;
use File::Basename;
use Common qw(
	dumpVar
	buildName
	getShowcaseDb
);
use Images qw (
	pdf_info
);
use GD;
use GD::Text::Align;
use MIME::Base64;
use Crypt::CBC;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT_OK = qw(
	buildAddrList
	buildChildren
	buildRelCases
	buildReturnAddr
	checkSignature
	createEnvelopes
	getCaseDiv
	getCaseInfo
	getExtraParties
	getLinkedCases
	getParties
	getDocInfo
	getSigPerms
	getSignature
	$SIGXTWIPS
	$SIGYTWIPS
	$SIGXPIXELS
	$SIGYPIXELS
);

use DB_Functions qw (
	dbConnect
	getData
	getDataOne
	ldapLookup
);

# A few globals
our $leading=15;
our $fontsize=12;
our $regfont=12;
our $adafont=14;

our $db = getShowcaseDb();
our $dbh = dbConnect($db);
our $schema = getDbSchema($db);


my $orderTemplateDir = "/usr/local/icms/cgi-bin/orders/templates";

our $SIGXTWIPS = 4000;
our $SIGYTWIPS = 1000;
our $SIGXPIXELS = 400;
our $SIGYPIXELS = 100;

sub getExtraParties {
	# Find any extra parties (delimited by /extraparties and /endextras) and add them to
	# the party array.
	my $partyRef = shift;
	my $fieldRef = shift;

	for (my $i=0; $i < scalar @{$fieldRef}; $i++) {
		if ($fieldRef->[$i] =~ /^\/extraparties/) {
			$i++;
			while (($fieldRef->[$i] !~ /^\/endextras/) &&  ($i < scalar @{$fieldRef})) {
				chomp($fieldRef->[$i]);
				my ($name,$addr1,$addr2,$city,$state,$zip,$junk) = split("~",$fieldRef->[$i],7);
				my %temp = (
					'FullName' => $name,
					'Address1' => $addr1,
					'Address2' => $addr2,
					'City' => $city,
					'State' => $state,
					'Zip' => $zip
				);

				push(@{$partyRef},\%temp);
				$i++;
			}
			last;
		}
	}
}

#sub getExtraParties {
#	# Find any extra parties (delimited by /extraparties and /endextras) and add them to
#    # the party array.
#	my $partyRef = shift;
#    my $fieldRef = shift;
#	for (my $i=0; $i < scalar @{$fieldRef}; $i++) {
#		if ($fieldRef->[$i] =~ /^\/extraparties/) {
#			$i++;
#			while (($fieldRef->[$i] !~ /^\/endextras/) &&  ($i < scalar @{$fieldRef})) {
#				push(@{$partyRef},$fieldRef->[$i]);
#                $i++;
#			}
#			last;
#        }
#	}
#}


sub getCaseInfo {
	# Populates the referenced hash with requested information from DB
	my $casenum = shift;
	my $dbh = shift;
	my $hashRef = shift;
	my $schema = shift;
    my $DB = shift;

	my $query;
	$DB = "showcase";

	if ($DB =~ /showcase/i) {
		$query = qq {
			select
				CaseNumber,
				CaseStyle,
				DivisionID,
				Location
			from
				$schema.vCase
			where
				CaseNumber = ?
		}
	} else {
		# What the heck kind of DB is this??
		return;
	}

	my $results = getDataOne($query,$dbh,[$casenum]);

	foreach my $key (keys %{$results}) {
		$hashRef->{$key} = $results->{$key};
	}
}


sub buildChildren {
	# Takes a CGI object reference and an array reference.  The CGI object reference will be
	# used to find the sk* parameters to determine which children should be included.
	#
	# The array will be an array of hash refs, each has containing a child's name and (as
	# appropriate) DOB
	my $info = shift;
	my $kidref = shift;

	my $params = $info->Vars;

	# For a child to be included, the checkbox (skcheck*) needs to be selected.  So,
	# first get a listing of those.
	my @checked;
	foreach my $param (keys %{$params}) {
		next if ($param !~ /^skcheck/);
		my $number = $param;
		$number =~ s/skcheck//g;
		# Ok, we have the number.  Get the skname and skdob values that correspond.
		my $namevar = "skname" . $number;
		my $dobvar = "skdob" . $number;
		my %child;
		if ($params->{$namevar} ne "") {
			$child{'Name'} = $params->{$namevar};
			if ($params->{$dobvar} ne "") {
				$child{'DOB'} = $params->{$dobvar};
			}
			# This hash is only built if we have a name.  Push that hash onto the $kidref array
			push (@{$kidref}, \%child);
		}
	}
}


sub getParties {
	my $casenum = shift;
	my $dbh = shift;
	my $partyRef = shift;
	my $schema = shift;
    my $DB = shift;
    $DB = "showcase";

	my @parties;

	my $query;

	my @vals = ($casenum);

	if ($DB =~ /showcase/i) {
		$query = qq {
			select
				upper(FirstName) as FirstName,
				upper(MiddleName) as MiddleName,
				upper(LastName) as LastName,
				-- PartyType,
				CASE 
					WHEN PartyTypeDescription = 'PLAINTIFF'
						THEN 'PLT'
					WHEN PartyTypeDescription = 'PLAINTIFF/PETITIONER'
						THEN 'PLT'
					WHEN PartyTypeDescription = 'DEFENDANT'
						THEN 'DFT'
					WHEN PartyTypeDescription = 'DEFENDANT/RESPONDENT'
						THEN 'DFT'
					WHEN PartyTypeDescription = 'PETITIONER'
						THEN 'PET'
					WHEN PartyTypeDescription = 'RESPONDENT'
						THEN 'RESP'			
					WHEN PartyTypeDescription = 'CHILD (CJ)'
						THEN 'CHLD'		
					WHEN PartyTypeDescription = 'FATHER'
						THEN 'FTH'	
					WHEN PartyTypeDescription = 'MOTHER'
						THEN 'MTH'	
					END AS PartyType
			from
				$schema.vAllParties
			where
				CaseNumber = ?
				and Active='Yes'
		};
	} else {
		return;
	}
	
	getData(\@parties,$query,$dbh,{valref => \@vals});

	foreach my $party (@parties) {
		my $partyType = $party->{'PartyType'};

		my $fullname;

		if ((defined($party->{'MiddleName'})) && ($party->{'MiddleName'} ne "")) {
			if (length($party->{'MiddleName'}) > 1){
				$fullname = sprintf ("%s %s %s", $party->{'FirstName'}, $party->{'MiddleName'},
									 $party->{'LastName'});
			} else {
				$fullname = sprintf ("%s %s. %s", $party->{'FirstName'}, $party->{'MiddleName'},
									 $party->{'LastName'});
			}
		} else {
			if (!defined($party->{'FirstName'})) {
				$fullname = $party->{'LastName'};
			} else {
				$fullname = sprintf ("%s %s", $party->{'FirstName'}, $party->{'LastName'});
			}
		}

		# Strip any leading or trailing whitespace
		$fullname =~ s/^\s+//g;
		$fullname =~ s/\s+$//g;

		if (defined($partyRef->{$partyType})) {
			# What? Already defined? Is it a scalar?
			if (ref(\($partyRef->{$partyType})) eq "SCALAR") {
				# It is, indeed. Convert it to an array.
				my $temp = $partyRef->{$partyType};
				$partyRef->{$partyType} = [];
				# And put this value onto it.
				push(@{$partyRef->{$partyType}}, $temp);
			}
			push(@{$partyRef->{$partyType}}, $fullname);
		} else {
			$partyRef->{$partyType} = $fullname;
		}
	}
}

sub getLinkedCases {
	my $casenum = shift;
	my $dbh = shift;
	my $dataRef = shift;
	my $DBTYPE = shift;
	my $schema = shift;
	$DBTYPE = "showcase";
	my @linked;

	my $query;

	if ($DBTYPE =~ /showcase/i) {
		$query = qq {
			select
				FromCaseNumber,
				ToCaseNumber
			from
				$schema.vLinkedCases
			where
				ToCaseNumber = ?
		};
	} 

	getData(\@linked,$query,$dbh,{valref => [$casenum]});

	$dataRef->{'LinkedCases'} = [];

	foreach my $link (@linked) {
		# If they're Banner numbers, format them
		if ($link->{'FromCaseNumber'} =~ /(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)/) {
			$link->{'FromCaseNumber'} = sprintf("%04d-%s-%06d", $1, $2, $3);
		}

		push(@{$dataRef->{'LinkedCases'}}, $link->{'FromCaseNumber'});
	}
}

sub buildRelCases {
	# Takes a CGI object reference and an array reference.  The CGI object reference will be
	# used to find the relcase* parameters to determine which related cases should be included.
	#
	# The array will be an array of hash refs, each has containing related information on the cases
	my $info = shift;
	my $caseref = shift;

	my %params = $info->Vars;

	# For a child to be included, the checkbox (skcheck*) needs to be selected.  So,
	# first get a listing of those.
	my @checked;
	foreach my $param (keys %params) {
		next if ($param !~ /^relcase\d+cType$/);
		next if ($params{$param} eq "");
		my $number = $param;
		$number =~ s/relcase//g;
		$number =~ s/cType//g;
		# Move along if there's no case number.
		my $casenum = "relcase" . $number . "CaseNum";
		my %case;
		if ($params{$casenum} ne "") {
			foreach my $type ("cType","CaseNum","Mother","Father","Child","Status","Note") {
				my $key = "relcase" . $number . $type;
				$case{$type} = $params{$key};
			}
			my $datevar = "relcase" . $number . "CloseDate";
			if ($params{$datevar} ne " ") {
				$case{'CloseDate'} = $params{$datevar};
			}
			# This hash is only built if we have a name.  Push that hash onto the $kidref array
			push (@{$caseref}, \%case);
		}
	}
}

sub createEnvelopes {
	# Creates a PDF of containing the envelopes for the included parties.  Returns
	# the full path to the PDF file
	my $addrlist = shift;
	my $tmpdir = shift;
	my $returnAddress = shift;

	my @retAddr;
	if (defined($returnAddress)) {
		@retAddr = split(/~/, $returnAddress);
	}

	if (!defined($tmpdir)) {
		$tmpdir = "/var/www/html/tmp";
	}

	my $handle = File::Temp->new(
		DIR => $tmpdir,
		UNLINK => 0,
		SUFFIX => '.pdf'
	);
	my $pdfname = $handle->filename;
	# We just wanted a filename at this point.
	close $handle;

	my $pdf=new PDF::Create('filename'=>$pdfname,
							'Version' =>1.2,
                            'PageMode'=>'UseNone',
                            'Author' => 'ICMS',
                            'Title' => 'Envelopes',
                            );

	my $f1 = $pdf->font('Subtype'  => 'Type1',
						'Encoding' => 'WinAnsiEncoding',
						'BaseFont' => 'Times-Roman');

	# loop through all addresses
	foreach my $addr (@{$addrlist}) {
		my $root=$pdf->new_page('MediaBox'=>[0,0,679,279]);
		my $page=$root->new_page;

		# Return address (if defined)
		if (scalar(@retAddr)) {
			my $x = 25;
			my $y = 250;
			foreach my $line (@retAddr) {
				chomp $line;
				$page->string($f1,$fontsize-2,$x,$y,$line);
				$y -= $leading;
			}
		}

		my $x=288;
		my $y=153;
		my @parr=split(/~/, $addr);
		foreach my $line (@parr) {
			$page->string($f1,$fontsize-2,$x,$y,$line);
			$y-=$leading;
		}
	}

	$pdf->close;
	return $pdfname;
}


sub buildAddrList {
    my $info = shift;
    my $addrlist = shift;
    my $ccaddrlist = shift;

    my $numparties = $info->param('numparties');
    my($i,$addrline,$x,$realcount,$ta);
    
    for ($i=0;$i<$numparties;$i++) {
        if ((defined ($info->param("check$i"))) && ($info->param("check$i") eq "on")) {
            # build addr list for envelopes
            $addrline=$info->param("name$i");
            $addrline.="~".$info->param("addr1$i");
            $x=$info->param("addr2$i");
            if ((defined ($x)) && ($x ne "")) {
                $addrline.="~$x";
            }
			$x=$info->param("addr3$i");
            if ((defined ($x)) && ($x ne "")) {
                $addrline.="~$x";
            }
			$addrline.="~".$info->param("csz$i");
            $addrline=trim($addrline);
            $ta = $addrline;
            $ta=~s/,| //g;  # remove all commas and blanks
            if($ta ne '') {
                push(@{$addrlist},$addrline);
            }

            my $confidential = $info->param("conf$i");
            if ($confidential) {
                my $addrname = $info->param("name$i");
                $addrline = "$addrname  <ADDRESS CONFIDENTIAL>";
            } else {
                # build addr list for cc section
                $addrline=$info->param("name$i");
                $x=trim($info->param("addr1$i"));
                if ($x ne "") {
                    $addrline.=", $x";
                }
                $x=trim($info->param("addr2$i"));
                if ((defined ($x)) && ($x ne "")) {
                    $addrline.=", $x";
                }
                $x=trim($info->param("addr3$i"));
                if ((defined ($x)) && ($x ne "")) {
                    $addrline.=", $x";
                }
                $x=trim($info->param("csz$i"));
                if ((defined ($x)) && ($x ne "")) {
                    $addrline.=", $x";
                }
            }
            
            if($addrline ne '') {
                push(@{$ccaddrlist},$addrline);
            }
        }
    }
}


sub getDocInfo {
	# Populates a hash with information on a PDF file that ICMS.pm's buildImageFile()
	# subroutine wants
	my $pdfFile = shift;
	my $docref = shift;
	my $itemDesc = shift;

	my $pdfInfo = pdf_info($pdfFile);
	if ( grep { /^Error/ } @{$pdfInfo}) {
		print STDERR "PDF Error: [$pdfFile]\n";
		return;
	}

	# Find the number of pages for the document, to properly set bookmarks
	my $pagecount;
	foreach my $line (@{$pdfInfo}) {
		next if ($line !~ /^Pages/);
		$pagecount = (split(/\s+/, $line))[1];
		last;
	}

	if (int($pagecount) == 0) {
		print STDERR "PDF: $pdfFile gives page count of 0.\n";
		return;
	}

	my %thisItem;
	# Where does the last one leave off?
	my $lastElement = scalar(@{$docref}) - 1;

	if (($lastElement >= 0) && (defined($docref->[$lastElement]->{lastPage}))) {
		$thisItem{page} = $docref->[$lastElement]->{lastPage} + 1;
	} else {
		$thisItem{page} = 1;
	}
	# What's the last page for this item?  Remember to back out 1.
	$thisItem{lastPage} = $thisItem{page} + $pagecount - 1;
	$thisItem{date} = $TODAY;
	$thisItem{file} = $pdfFile;
	if (defined($itemDesc)) {
		$thisItem{code} = $itemDesc;
	}

	push(@{$docref}, \%thisItem);
}


sub getCaseDiv {
	my $dbh = shift;
	my $caseid = shift;
	my $DBTYPE = shift;
	my $schema = shift;
	my $DBTYPE = "showcase";
	my $query;

	if ($DBTYPE =~ /showcase/i){
		$query = qq {
			select
				DivisionID
			from
				$schema.vCase with(nolock)
			where
				CaseNumber = ?
		};
	} 
	my $case = getDataOne($query,$dbh,[$caseid]);
	if (defined($case)) {
		return $case->{'DivisionID'};
	} else {
		return undef;
	}
}

sub getSigPerms {
	# Gets a listing of what judicial signatures the user may insert; if the user has his
	# own signature on file, it is included in the list
	my $useRef = shift;
	my $user = shift;

	my $dbh = dbConnect("signatures");
	my $query = qq {
		select
			judge_id
		from
			sig_users
		where
			user_id = ?
		UNION
		select
			judge_id
		from
			judge_signatures
		where
			judge_id = ?
	};

	my @userArray;

	my @judgeids;
	my @vals = ($user, $user);
	getData(\@judgeids, $query, $dbh, {valref => \@vals});

	return if (!scalar(@judgeids));

	foreach my $judge (@judgeids) {
		push(@userArray, "'$judge->{judge_id}'");
	};

	my $inString = join(",", @userArray);

	$query = qq {
		select
			judge_id,
			first_name,
			last_name
		from
			judge_signatures
		where
			judge_id in ($inString);
	};

	getData($useRef,$query,$dbh);

	$dbh->disconnect;
}

sub getSignature {
	# Gets encrypted signature for the specified judge (if we have one on file) and applies
	# a case number/date watermark, returning the new image in JPEG format
	my $casenum = shift;
	my $judgeid = shift;
    my $config = shift;

	my $dbh= dbConnect("signatures");

	my $query = qq {
		select
			judge_sig
		from
			judge_signatures
		where
			judge_id = ?
	};

	my $sigRef = getDataOne($query,$dbh,[$judgeid]);

	if (!defined($sigRef)) {
		return undef;
	}

	# Look up the name and title from AD
	my @fields = ("givenName","initials","sn","title");;
	my @users;
	my $ldapFilter = "(sAMAccountName=$judgeid)";
	ldapLookup(\@users,$ldapFilter,undef,\@fields);


	if (scalar(@users)) {
		my $user = $users[0];
		if (defined($user->{'initials'})) {
			my $middleName = $user->{'initials'};
			if (length($middleName) == 1) {
				$middleName .= ".";
			}
			$sigRef->{'judgeName'} = sprintf("%s %s %s", $user->{'givenName'},
											 $middleName, $user->{'sn'});
		} else {
			$sigRef->{'judgeName'} = sprintf("%s %s", $user->{'givenName'}, $user->{'sn'});
		}
		$sigRef->{'title'} = $user->{'title'};
	}


	# The crypt and the key are base 64 encoded in the DB.
	my $crypt = decode_base64($sigRef->{'judge_sig'});
    
	my $key = $config->{'signKey'};
    
	# Decrypt the stored signature, which will yield a packed hex representation of the
	# signature
	my $cipher = Crypt::CBC->new(
								 -key => $key,
								 -cipher => 'Crypt::OpenSSL::AES'
								 );

	my $sig = $cipher->decrypt($crypt);

	# Pack it into binary format (it's currently hex)
	my $unpacked = pack("H*", $sig);

	# And do the magic
	my $origImg = GD::Image->new($unpacked);
	my ($width, $height) = $origImg->getBounds();

	my $img = GD::Image->new($SIGXPIXELS,$SIGYPIXELS,1);
	$img->copyResized($origImg,0,0,0,0,$SIGXPIXELS,$SIGYPIXELS,$width,$height);
	# Find height/width of current image

	my $textHeight = 10;

	# The top/right of the watermark box
	my $wmTop = 35;
	my $wmMargin = 20;

	# Top/right corners of the name box
	my $nameTop = $SIGYPIXELS - $textHeight - 15;

	# Set the colors
	my $black = $img->colorAllocate(0,0,0);
	my $gray = $img->colorAllocateAlpha(181,181,181,80);

	$img->transparent($gray);

	my $now = POSIX::strftime( "%m/%d/%Y", localtime );

	my $ucnString = sprintf("%s      %s", $casenum, $now);
	my $judgeString = sprintf("%s    %s", $sigRef->{'judgeName'}, $sigRef->{'title'});

	# Draw the UCN/Timestamp watermark
	my $ucnBox = GD::Text::Align->new($img,
									 valign => 'top',
									 halign => 'center'
									 );

	# Create the watermark and put it into the center of the rectangle
	$ucnBox->set_font('/usr/share/fonts/liberation/LiberationSans-Bold.ttf',$textHeight);
	$ucnBox->set_text($ucnString);
	my @ucnBounds = $ucnBox->bounding_box($wmMargin, $wmTop, 0);
	my $ucnWidth = $ucnBounds[2] - $ucnBounds[0];
	my $ucnHeight = $ucnBounds[1] - $ucnBounds[7];

	$img->filledRectangle($wmMargin,$wmTop,$wmMargin+$ucnWidth, $wmTop+$textHeight,
						  $gray);
	$ucnBox->set(color => $black);
	$ucnBox->draw($wmMargin + ($ucnWidth/2), $wmTop ,0);

	# Draw the name/Title watermark
	my $nameBox = GD::Text::Align->new($img,
									 valign => 'top',
									 halign => 'center'
									 );

	# Create the watermark and put it into the center of the rectangle
	$nameBox->set_font('/usr/share/fonts/liberation/LiberationSans-Bold.ttf',$textHeight);
	$nameBox->set_text($judgeString);
	my @nameBounds = $nameBox->bounding_box($wmMargin, $wmTop, 0);
	my $nameWidth = $nameBounds[2] - $nameBounds[0];
	my $nameHeight = $nameBounds[1] - $nameBounds[7];

	# Rectangle should be near the lower right
	$img->filledRectangle($SIGXPIXELS - $nameWidth - $wmMargin, $SIGYPIXELS - $wmTop - $textHeight,
						  $SIGXPIXELS - $wmMargin, $SIGYPIXELS - $wmTop, $gray);
	$nameBox->set(color => $black);
	$nameBox->draw($SIGXPIXELS - $wmMargin - ($nameWidth/2),
				   $SIGYPIXELS - $wmTop - $textHeight,0);

	my $jpegdata = $img->jpeg();
    
	# All done!
	$sigRef->{'sig'} = $jpegdata;
	return $sigRef;
}

sub checkSignature {
	# Just check to see if the specified user has a signature on file
	my $userid = shift;

	my $dbh = dbConnect("signatures");

	my $query = qq {
		select
			judge_id
		from
			judge_signatures
		where
			judge_id = ?
	};
	my $judge = getDataOne($query,$dbh,[$userid]);

	if (defined($judge)) {
		# Signature on file
		return 1;
	}
	# Didn't find one
	return 0;
}


sub buildReturnAddr {
	# Get the return address for the courthouse where this division is
	my $div = shift;

	return if (!defined($div));

	my $dbh = dbConnect("judge-divs");
	my $query = qq {
		select
			division_id,
			courthouse_name,
			courthouse_addr,
			courthouse_city,
			courthouse_state,
			courthouse_zip
		from
			divisions d,
			courthouses c
		where
			division_id = ?
			and d.courthouse_id = c.courthouse_id
	};

	my $addrinfo = getDataOne($query,$dbh,[uc($div)]);

	my $addr = sprintf("Sarasota Beach Couty %s - Division %s~%s~%s, %s %s", $addrinfo->{courthouse_name}, $div,
					   $addrinfo->{'courthouse_addr'}, $addrinfo->{'courthouse_city'}, $addrinfo->{'courthouse_state'},
					   $addrinfo->{'courthouse_zip'});

	return $addr;
}

1;
