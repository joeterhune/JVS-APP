#!/usr/bin/perl

package PBSO;

use strict;

use ICMS;
use Common qw(
	dumpVar
	inArray
	printCell
	convertDates
	escapeFields
	logToFile
);
use DB_Functions qw (
    dbConnect
    getData
    getDataOne
	$DEFAULT_SCHEMA
);
use CGI::Carp qw(fatalsToBrowser);
use File::Basename;
use File::Path qw {make_path};
use LWP::UserAgent;
use LWP::ConnCache;

use Exporter();
our @ISA=qw(Exporter);
our @EXPORT=qw (
	test_pbsoconnection
	get_allpbsocases
	get_allincustody
	get_mugshot_incustody
	get_mugshot_incustody_usingInmateId
	get_inmateid
	write_pbsobooking
	write_pbsoblock
	write_jacketIdentifier
	write_bookingHeader
	write_bookingArrestInformation
	write_bookingChargeBondInformation
	write_bookingSentencing
	get_pbsonames
	get_pbsomnames
	get_pbsodobs
	get_mostrecentbookingdate
	get_bookingHeader
	get_bookingArrestInformation
	get_bookingChargeBondInformation
	get_bookingSentencing
	write_testpbsoallinfo
	getBookingPhoto
	getInmateIds
	$view
	$ipview
	%raceMap
);

our %raceMap = (
	'A' => 'Asian',
	'B' => 'Black',
	'H' => 'Hispanic',
	'I' => 'Indian',
	'O' => 'Other',
	'W' => 'White'
);

# stay with this view after IMACS5 goes live
our $view="vw_PBSOQueryBookingInfo";

# for inmate photos (given to us 3/23/11)
our $ipview="IMACS_5_PBSO.dbo.objinmatephotos";
my $pbso="pbso2";
my $pbsoconn;

# Get the pbso view names.  If anyone needs them, they should get them from
# here!
# RLH - this is stupid.  Export the variables themselves.
#sub get_pbsodbview { return $view; }
#sub get_pbsoipview { return $ipview; }


sub test_pbsoconnection {
	my $pbsoconn=dbConnect($pbso);
	return $pbsoconn;
}

#
# Get all PBSO cases (may have multiple per booking) into a hash with PBSO Case # as key (which is the Banner booking number) and save inmateid (jacket), pbso
# booking id, and release date (a null release date signifies inmate is in
# jail, depending on assignedcellid).
#
# 06/17/11 - get assignedcellid for checking where the inmate is...
#
sub get_allpbsocases {
	my $caseref = shift;
	my $pbsodbh = shift;

	my $hasDBH = 1;
	if (!defined($pbsodbh)) {
		$pbsodbh = dbConnect("pbso2");
		$hasDBH = 0;
	}
	my $query = qq {
		select
			distinct casenumber as PBSOCase,
			BookingDate as BookingDate,
			inmateid as InmateID,
			BookingID as BookingID,
			CASE
				WHEN releasedate IS NULL
					THEN ''
				ELSE CONVERT(varchar(10),releasedate,110)
			END as ReleaseDate,
			ISNULL(assignedcellid,'') as AssignedCellID
		from
			$view
		order by
			casenumber desc
	};
	getData($caseref,$query,$pbsodbh,{ hashkey => "PBSOCase", flatten => 1 });

	if (!$hasDBH) {
		$pbsodbh->disconnect;
	}
	# Return the number of rows
	return scalar(keys(%{$caseref}));
}

# Get all distinct inmate ids that have a release date of null.
# This is the list of all inmates in jail!
# 06/16/11 - get assignedcellid for checking where the inmate is...
sub get_allincustody {
	my $hashref = shift;
	my $pbsodbh = shift;

	my $hasDBH = 1;
	if (!defined($pbsodbh)) {
		$pbsodbh = dbConnect("pbso2");
		$hasDBH = 0;
	}

	my $query = qq {
		select
			distinct inmateid as InmateID,
			bookingid as BookingID,
			assignedcellid as AssignedCellID,
			datediff(d,BookingDate,getdate()) as Days
		from
			$view
		where
			releasedate is null
		order by
			bookingid desc
	};

	getData($hashref,$query,$pbsodbh,{ hashkey => "InmateID", flatten => 1});

	if (!$hasDBH) {
		$pbsoconn->disconnect;
	}

	return scalar(keys(%{$hashref}));
}


# Get the mugshot url and incustody Yes, No, Escaped, House Arrest,
# Weekender Out for this defendant.
#
# Uses the bookingQuery database to get data.
#
# Will return "no arrests" if couldn't find any arrests,
#             "no booking number" if there were arrests, but no booking number
#                                 for any of them,
#              "no pbso data found" if couldn't find any pbso charges,
#          or  booking jpg string ; incustody string.
#
# assumes connection to the wpb-banner db, initially.
#
sub get_mugshot_incustody {
	my $def = shift;
	my $pbsodbh = shift;

	my $hasDBH = 1;
	if (!defined($pbsodbh)) {
		$pbsodbh = dbConnect("pbso2");
		$hasDBH = 0;
	}

	my $inmate;
	my $query = qq{
		select
			czrarst_seq_no,
			czrarst_booking_num
		from
			czrarst
		where
			czrarst_pidm='$def'
		order by
			czrarst_arrest_date desc,
			czrarst_seq_no desc,
			czrarst_booking_num desc
	};

	my @arrests = sqllist($query);

	$query = qq{
		select
			czrarst_seq_no,
			czrarst_booking_num
		from
			czrarst
		where
			czrarst_pidm='$def'
			and czrarst_booking_num is not null
		order by
			czrarst_arrest_date desc,
			czrarst_seq_no desc,
			czrarst_booking_num desc
	};

	my @arrestswithbn = sqllist($query);
	# If there are arrests for this defendant, see if any of them have the
	# booking number filled in so we can get the pbso info.
	if (scalar @arrests > 0) {
		if (scalar @arrestswithbn > 0) {
			# just use the first one to get what we need
			my($seqno,$booknum)=split('~',$arrestswithbn[0]);
			my $bannerbn = $booknum;

      # Get the inmate id for this defendant using a booking id.
      $inmate = getInmateIdCase($bannerbn);
      my $ans = get_mugshot_incustody_usingInmateId($inmate);
      return $ans;
    } else {
      return 'no booking number';
    }
  } else {
    return 'no arrests';
  }
}

# Get the mugshot url and incustody Yes, No, Escaped, House Arrest, Weekender
# Out for this defendant.
#
# Uses the bookingQuery database to get data.
#
# Will return "no pbso data found" if couldn't find any pbso charges,
#          or  booking jpg string ; incustody string.
#
# assumes connection to the wpb-banner db, initially.
#
# 2/4/11 modified for showcase integration
#
sub get_mugshot_incustody_usingInmateId {
    my $inmate = shift;
    my $pbsodb = shift;

    if (!defined($pbsodb)) {
        $pbsodb = dbConnect("pbso2");
    }

    my $jpg;
    my $incustody;

    # Determine if he/she's in jail
    # (A null release date means the defendant is still incarcerated.  Null will
    # be first.) This should have returned with the photolocation always using
    # forward slash, but didn't. Probably because it's in the string... so, for
    #Firefox, will have to fix in line...
    my $query = qq{
        select
            distinct BookingId,
            ReleaseDate,
            BookingDate,
            isnull(
                (select
                    top 1 'http:' + REPLACE(photolocation, '\','/')
                from
                    $ipview
                where
                    bookingid = $view.bookingid
                    and inmateid = $view.inmateid
                    and front=1 and activephoto=1),
                    'http://www.pbso.org/bkimages/star/star.jpg') as inmatephoto,
            AssignedCellId
        from
            $view
		where
            InmateId='$inmate'
			and BookingDate=(
				select
					max(BookingDate)
				from
					$view
				where
					InmateId='$inmate'
				)
        order by
            BookingDate desc
    };

    my $info = getDataOne($query,$pbsodb);

    # Get nt photo.
    if (scalar (keys(%{$info}))) {
        # replace \ with / in jpg - should have been done with the database call!
        $jpg = $info->{'inmatephoto'};
        $jpg =~ s/\\/\//g;
        if ($info->{'ReleaseDate'} eq '') {
            $incustody='Yes';
            if ($info->{'AssignedCellId'} eq 'ESCAPED') {
                $incustody='Escaped';
            } elsif ($info->{'AssignedCellId'} eq 'WEEKENDER OUT') {
                $incustody='Weekender Out';
            } elsif ($info->{'AssignedCellId'} eq 'IN-HOUSE ARREST') {
                $incustody='House Arrest';
            }
        } else {
            $incustody='No';
        }
    }
    if (scalar (keys(%{$info}))) {
        return $jpg.';'.$incustody;
    } else {
        return 'no pbso data found';
    }
}

#
#  Get the inmate id (jacket number) for this case number.
#
sub get_inmateid {
	my $casenumber = shift;
	my $pbsodbh = shift;

	my $hadDBH = 1;
	if (!defined($pbsodbh)) {
		$pbsodbh = dbConnect("pbso2");
		$hadDBH = 0;
	}

	my $query = qq {
		select
			distinct InmateId
		from
			$view
		where
			CaseNumber='$casenumber'
	};
	my @info;
	getData(\@info,$query,$pbsodbh);

	if (!$hadDBH) {
		$pbsodbh->disconnect;
	}

	if (scalar(@info)) {
		return $info[0]->{'InmateId'};
	} else {
		return '';
	}
}


sub get_mostrecentbookingdate {
	my $inmate = shift;
	my $pbsodbh = shift;
	
	if (!defined($pbsodbh)) {
		$pbsodbh = dbConnect("pbso2");
	}
	
	my $query = qq {
		select
			distinct BookingId,
			convert(varchar(10),BookingDate,101) as BookingDate
		from
			$view
		where
			InmateId = ?
		order by
			BookingDate desc
	};

	my @info;
	
	my @args = ($inmate);

	getData(\@info, $query, $pbsodbh, { valref => \@args, hashkey => 'BookingId' });
	
	if (!scalar(@info)) {
		return '';
	} else {
		return $info[0]->{'BookingDate'}
	}
}



#
#  Writes the html for the PBSO Booking Information block using the
#  bookingQuery database, making just one call to get all booking data at once.
#  Pass defendant pidm, banner case number and initial display indicator.
#  If initial display is 'none' the block isn't displayed, but it's there,
#  waiting to be toggled for display.
#
# assumes connection to the wpb-banner db, initially
#
# 2/4/11 modified for Showcase integration
#        if showcase is the current db, pass def as the jacket (inmate) #
#
sub write_pbsobooking {
	my $def = shift;
	my $bncasenum = shift;
	my $initialdisplay = shift;
	my $lev = shift;
	my $dbh = shift;
	my $pbsodbh = shift;
	my $schema = shift;

	if (!defined($schema)) {
		$schema = $DEFAULT_SCHEMA
	};

	if (!defined($pbsodbh)) {
		$pbsodbh = dbConnect("pbso2");
	}

	my($firstbannerbn,$thiscasebannerbn);
	my($inmate);

	my $style = "";

	if ($initialdisplay eq "none") {
		$style = qq{ style="display:none"};
	}

	print qq{
		<div id="pbsobookinginfo" $style>
	};

	$bncasenum =~s#-##g;
	$bncasenum = substr $bncasenum,2,15;
	write_pbsoblock($def,$bncasenum,$lev,$dbh,$pbsodbh,$schema);
	print qq{
		</div>
	};
}



sub new_write_pbsobooking {
	my $def = shift;
	my $bncasenum = shift;
	my $initialdisplay = shift;
	my $lev = shift;
	my $dbh = shift;
	my $pbsodbh = shift;
	my $schema = shift;

	if (!defined($schema)) {
		$schema = $DEFAULT_SCHEMA
	};

	if (!defined($pbsodbh)) {
		$pbsodbh = dbConnect("pbso2");
	}

	my($firstbannerbn,$thiscasebannerbn);
	my($inmate);

	my $style = "";

	if ($initialdisplay eq "none") {
		$style = qq{ style="display:none"};
	}

	print qq{
		<div id="pbsobookinginfo" $style>
	};

	$bncasenum =~s#-##g;
	$bncasenum = substr $bncasenum,2,15;
	write_pbsoblock($def,$bncasenum,$lev,$dbh,$pbsodbh);
	print qq{
		</div>
	};
}


#
# Write the pbso booking block div section
#
# 2/4/11 modified for showcase integration
#
sub write_pbsoblock {
	my $inmate = shift;
	my $bncasenum = shift;
	my $lev = shift;
	my $dbh = shift;
	my $pbsodbh = shift;
	my $schema = shift;
	my $ucn = shift;

	if (!defined($schema)) {
		$schema = $DEFAULT_SCHEMA
	};


	my $nextlev=$lev+1;
	my $incustody;
	my $injail;
	my $query;
	my @bookings;
	my @idstart;
	my @idend;
	my @cases;
	my @cstart;
	my @cend;
	my $thisid;
	my $thiscase;
	my $first;
	my $i;
	my $j;
	my $k;
	my @bnarrests;
	my @bncase;
	my @bnstatus;
	my $height;
	my $totaldays = 0;

	if (!defined($pbsodbh)) {
		$pbsodbh = dbConnect("pbso2");
	}

	# get all the pbso data for this inmate

	$query = qq {
		select
			distinct InmateId as InmateId,
			bookingdate as BookingDate,
			bookingdate as fBookingDate,
			BookingId,
			releasedate as ReleaseDate,
			AgeAtBooking,
			substring(convert(varchar,HeightFeet),1,1) as HeightFeet,
			HeightInches,
			Weight,
			datediff(d,BookingDate,ReleaseDate) as Days,
			datediff(d,BookingDate,getdate()) as SoFar,
			casenumber as PBSOCaseNumber,
			carrestdate as cArrestDate,
			chargedescription as ChargeDescription,
			chargesequence as ChargeSequence,
			isnull(
			(
				select
					top 1 'http:' + REPLACE(photolocation, '\\','/')
				from
					$ipview
				where
					bookingid = $view.bookingid
					and inmateid = $view.inmateid and front=1
					and activephoto=1
			),
			'http://www.pbso.org/bkimages/star/star.jpg') as InmatePhoto,
			AssignedCellId
		from
			$view
		where
			InmateId='$inmate'
	};

	# @charges will be an array of individual charges.  Each one will be associated with a PBSO Case
	# which will, in turn, be associated with a Booking ID
	my @charges;

	# A listing of all of the PBSO cases associated with this booking jacket
	my @pbsocases;
	getData(\@charges,$query,$pbsodbh);

	convertDates(\@charges,"fBookingDate","ReleaseDate","cArrestDate");

	my %bookings;

	foreach my $charge (@charges) {
		if (!defined($bookings{$charge->{BookingId}})) {
			# Create the top-level hash reference if it doesn't exist.
			$bookings{$charge->{BookingId}} = {};
			$bookings{$charge->{BookingId}}->{PBSOCases} = {};
		}

		my $bookingid = $charge->{BookingId};
		my $pbsocase = $charge->{PBSOCaseNumber};
		# Now, since there can be multiple PBSO cases per booking, we need to create another hash
		# there, based on the PBSO Case number, as needed
		if (!defined($bookings{$bookingid}->{PBSOCases}->{$pbsocase})) {
			$bookings{$bookingid}->{PBSOCases}->{$pbsocase} = {};
			foreach my $key (keys %{$charge}) {
				next if (inArray(["ChargeDescription","BookingId","PBSOCaseNumber"], $key));
				$bookings{$bookingid}->{$key} = $charge->{$key};
			}
			$bookings{$bookingid}->{PBSOCases}->{$pbsocase}->{Charges} = {};
			$bookings{$bookingid}->{PBSOCases}->{$pbsocase}->{ArrestDate} = $charge->{cArrestDate};
			# We'll need this later.
			push(@pbsocases,$pbsocase);
		}
		$bookings{$bookingid}->{PBSOCases}->{$pbsocase}->{Charges}->{$charge->{ChargeSequence}} =
			$charge->{ChargeDescription};
	}

	# Whew!  For those keeping score, that's a hash of hashes; of those last hashes, there is another
	# hash (PBSOCases) of hashes (keeping track of the charges)

	# We have every thing we need from pbso in that one table.
	$pbsodbh->disconnect();

	my %icmscases;

	# But wait!  There's more!  Now we need to get any applicable ICMS cases for each PBSO Case.

	if (scalar(@pbsocases)) {
		my @temp;
		foreach my $case (@pbsocases) {
			# Hate to have to do this, but it needs to be converted to a string
			push(@temp,"'$case'");
		}
		my $instring = join(",", @temp);
		my $query = qq {
			select
				c.UCN,
				c.LegacyCaseFormat,
				a.CaseNumber,
				c.CaseStatus,
				a.BookingSheetNumber as PBSOCaseNumber
			from
				$schema.vArrest a,
				$schema.vCase c with(nolock)
			where
				a.BookingSheetNumber in ($instring)
				and a.CaseNumber=c.CaseNumber
		};
		getData(\%icmscases,$query,$dbh,{hashkey => "PBSOCaseNumber"});
	}

	my @bookingids = reverse sort { $a <=> $b }(keys %bookings);

	if (scalar(@bookingids)) {
		if ($bookings{$bookingids[0]}->{'ReleaseDate'} eq '') {
			$incustody = "<font color=red>In PBSO Custody</font>";
			$injail=1;
			my $cell = $bookings{$bookingids[0]}->{'AssignedCellId'};
			if ($cell eq 'ESCAPED') {
				$incustody = "<font color=red>Escaped</font>";
			} elsif ($cell eq 'WEEKENDER OUT') {
				$incustody = "<font color=red>Weekender Out</font>";
			} elsif ($cell eq 'IN-HOUSE ARREST') {
				$incustody = "<font color=red>House Arrest</font>";
			}
		} else {
			$incustody = "Not In PBSO Custody ";
			$injail=0;
		}
		print qq {
			<table class="summary" border="10">
				<tr>
					<td colspan="6" class="title">
						All PBSO Booking Information for this Defendant - Jacket $bookings{$bookingids[0]}->{'InmateId'} - $incustody
					</td>
				</tr>
				<tr class="title" style="vertical-align: middle">
					<td class="vcenter" style="width: 8%">
						Booking Date
					</td>
					<td class="vcenter" style="width: 8%">
						Release Date
					</td>
					<td class="vcenter" style="width: 8%">
						Days<br/>Served
					</td>
					<td class="vcenter">
						Photo<br/>
						Height/Weight/Age
					</td>
					<td class="vcenter">
						PBSO Booking #
					</td>
					<td class="vcenter" style="width: 70%">
						Case Information
					</td>
				</tr>
		};

		# Now, we have the lists of booking ids and start and end indexes for each.
		# Process each booking id.
		$i = 0;
		my $conn_cache;
		my $ua;
		if (scalar(@bookingids)) {
			$conn_cache = LWP::ConnCache->new(
				'total_capacity' => 50
											 );
			$ua = LWP::UserAgent->new(
				'conn_cache' => $conn_cache
			);
		}

		foreach my $bookingid (@bookingids) {
			my $hashref = $bookings{$bookingid};
			if ($hashref->{InmatePhoto} ne "") {
				# Try to get a copy and store it locally
				my $newpath = getBookingPhoto($hashref->{InmatePhoto},$ua);
				if (defined($newpath)) {
					$hashref->{InmatePhoto} = $newpath;
				}
			}
			if ($hashref->{'ReleaseDate'} eq "") {
				$hashref->{'Days'} = $hashref->{'SoFar'};
			}
			if ($hashref->{'Days'} < 0) {
				$hashref->{'Days'} = 0;
				$hashref->{'ReleaseDate'} = $hashref->{'fBookingDate'};
			}

			$i += $hashref->{'Days'};
			print qq{
				<tr>
					<td class="vcenter">
						$hashref->{fBookingDate}
					</td>
					<td class="vcenter">
						$hashref->{ReleaseDate}
					</td>
					<td class="vcenter">
						$hashref->{Days}
					</td>
					<td class="vcenter">
						<a href='$hashref->{InmatePhoto}'>
						<img alt="booking photo" src="$hashref->{InmatePhoto}" width="36" height="46"/>
						</a>
						<br/>
						$hashref->{HeightFeet}' $hashref->{HeightInches}"
						&nbsp;/&nbsp;$hashref->{Weight}
						&nbsp;/&nbsp;$hashref->{AgeAtBooking}
					</td>
					<td class="vcenter">
						<a href="pbsobview.cgi?jacket=$hashref->{InmateId}&amp;booking=$bookingid&amp;lev=$nextlev&ucn=$ucn">
							$bookingid
						</a>
					</td>
			};

			# PBSO Case Breakdown
			print qq{
				<td>
					<table class="caseinfo">
						<thead>
						<tr>
							<td>
								Arrest Date
							</td>
							<td class="charges" style="text-align:center">
								Charges
							</td>
							<td>
								JVS Case # (Status)
							</td>
							<td>
								PBSO Case #
							</td>
						</tr>
						</thead>
						<tbody>
			};
			foreach my $case (reverse sort { $a <=> $b } (keys %{$hashref->{PBSOCases}})) {
				my $caseref = $hashref->{PBSOCases}->{$case};
				if ($caseref->{ArrestDate} eq '') {
					$caseref->{ArrestDate} = $hashref->{fBookingDate};
				}
				print "<tr>\n";
				printCell($caseref->{ArrestDate});
				my $chargeStr;
				escapeFields($caseref->{'Charges'});
				foreach my $chargeSeq (sort { $a <=> $b } (keys %{$caseref->{Charges}})) {
					$chargeStr .= " &bull; &nbsp; " . $caseref->{Charges}->{$chargeSeq} . "\n<br/>\n";
				}
				printCell($chargeStr,"class='charges'");
				if (defined($icmscases{$case})) {
					my $ucn = $icmscases{$case}[0]->{CaseNumber};
					my $legacy = $icmscases{$case}[0]->{LegacyCaseFormat};
					my $cellStr;
					if ($legacy eq $bncasenum) {
						$cellStr = qq{
							<span style="color: blue; float: left">&radic;&nbsp;</span>
						};
					#} else {
					#	$cellStr .= qq{
					#		<span style="float: left">&nbsp;&nbsp;&nbsp;</span>
					#	};
					}
					$cellStr .= qq{
						<a href="/cgi-bin/search.cgi?name=$ucn">
							$legacy
						</a>
						&nbsp;&#40;$icmscases{$case}[0]->{CaseStatus}&#41;&nbsp;
					};
					printCell($cellStr,qq{ style="text-align:center"});
				} else {
					printCell("&nbsp;");
				}
				printCell($case);
				print "</tr>\n";
			}
			print qq{
					</tbody>
				</table>
				</td>
				</tr>
			};
			$totaldays += $hashref->{Days};
		}
		#------------------------
		# show total days served
		#------------------------
		print qq{
			<tr>
				<td colspan="2" style="text-align: right">
					Total Days Served
		};
		if ($injail eq 1) {
			print qq{
				<span style="color: red; float: left">So Far<span>
			};
		}
		print qq{
			</td>
				<td class="center">
					$totaldays
				</td>
				<td colspan="8">
					&nbsp;
				</td>
				</tr>
			</table>
		};
	}
}


sub new_write_pbsoblock {
	my $inmate = shift;
	my $bncasenum = shift;
	my $lev = shift;
	my $dbh = shift;
	my $pbsodbh = shift;
	my $schema = shift;

	if (!defined($schema)) {
		$schema = $DEFAULT_SCHEMA
	};

	my $nextlev=$lev+1;
	my $incustody;
	my $injail;
	my $query;
	my @bookings;
	my @idstart;
	my @idend;
	my @cases;
	my @cstart;
	my @cend;
	my $thisid;
	my $thiscase;
	my $first;
	my $i;
	my $j;
	my $k;
	my @bnarrests;
	my @bncase;
	my @bnstatus;
	my $height;
	my $totaldays = 0;

	if (!defined($pbsodbh)) {
		$pbsodbh = dbConnect("pbso2");
	}

	# get all the pbso data for this inmate

	$query = qq {
		select
			distinct InmateId as InmateId,
			bookingdate as BookingDate,
			bookingdate as fBookingDate,
			BookingId,
			releasedate as ReleaseDate,
			AgeAtBooking,
			substring(convert(varchar,HeightFeet),1,1) as HeightFeet,
			HeightInches,
			Weight,
			datediff(d,BookingDate,ReleaseDate) as Days,
			datediff(d,BookingDate,getdate()) as SoFar,
			casenumber as PBSOCaseNumber,
			carrestdate as cArrestDate,
			chargedescription as ChargeDescription,
			chargesequence as ChargeSequence,
			isnull(
			(
				select
					top 1 'http:' + REPLACE(photolocation, '\\','/')
				from
					$ipview
				where
					bookingid = $view.bookingid
					and inmateid = $view.inmateid and front=1
					and activephoto=1
			),
			'http://www.pbso.org/bkimages/star/star.jpg') as InmatePhoto,
			AssignedCellId
		from
			$view
		where
			InmateId='$inmate'
	};

	# @charges will be an array of individual charges.  Each one will be associated with a PBSO Case
	# which will, in turn, be associated with a Booking ID
	my @charges;

	# A listing of all of the PBSO cases associated with this booking jacket
	my @pbsocases;

	getData(\@charges,$query,$pbsodbh);

	convertDates(\@charges,"fBookingDate","ReleaseDate","cArrestDate");

	my %bookings;

	foreach my $charge (@charges) {
		if (!defined($bookings{$charge->{BookingId}})) {
			# Create the top-level hash reference if it doesn't exist.
			$bookings{$charge->{BookingId}} = {};
			$bookings{$charge->{BookingId}}->{PBSOCases} = {};
		}

		my $bookingid = $charge->{BookingId};
		my $pbsocase = $charge->{PBSOCaseNumber};
		# Now, since there can be multiple PBSO cases per booking, we need to create another hash
		# there, based on the PBSO Case number, as needed
		if (!defined($bookings{$bookingid}->{PBSOCases}->{$pbsocase})) {
			$bookings{$bookingid}->{PBSOCases}->{$pbsocase} = {};
			foreach my $key (keys %{$charge}) {
				next if (inArray["ChargeDescription","BookingId","PBSOCaseNumber"], $key);
				$bookings{$bookingid}->{$key} = $charge->{$key};
			}
			$bookings{$bookingid}->{PBSOCases}->{$pbsocase}->{Charges} = {};
			$bookings{$bookingid}->{PBSOCases}->{$pbsocase}->{ArrestDate} = $charge->{cArrestDate};
			# We'll need this later.
			push(@pbsocases,$pbsocase);
		}
		$bookings{$bookingid}->{PBSOCases}->{$pbsocase}->{Charges}->{$charge->{ChargeSequence}} =
			$charge->{ChargeDescription};
	}

	# Whew!  For those keeping score, that's a hash of hashes; of those last hashes, there is another
	# hash (PBSOCases) of hashes (keeping track of the charges)

	# We have every thing we need from pbso in that one table.
	$pbsodbh->disconnect();

	my %icmscases;

	# But wait!  There's more!  Now we need to get any applicable ICMS cases for each PBSO Case.

	if (scalar(@pbsocases)) {
		my @temp;
		foreach my $case (@pbsocases) {
			# Hate to have to do this, but it needs to be converted to a string
			push(@temp,"'$case'");
		}
		my $instring = join(",", @temp);
		my $query = qq {
			select
				c.UCN,
				c.LegacyCaseFormat,
				a.CaseNumber,
				c.CaseStatus,
				a.BookingSheetNumber as PBSOCaseNumber
			from
				$schema.vArrest a,
				$schema.vCase c with(nolock)
			where
				a.BookingSheetNumber in ($instring)
				and a.CaseNumber=c.CaseNumber
		};
		getData(\%icmscases,$query,$dbh,{hashkey => "PBSOCaseNumber"});
	}

	my @bookingids = reverse sort { $a <=> $b }(keys %bookings);

	if (scalar(@bookingids)) {
		if ($bookings{$bookingids[0]}->{'ReleaseDate'} eq '') {
			$incustody = "<font color=red>In PBSO Custody</font>";
			$injail=1;
			my $cell = $bookings{$bookingids[0]}->{'AssignedCellId'};
			if ($cell eq 'ESCAPED') {
				$incustody = "<font color=red>Escaped</font>";
			} elsif ($cell eq 'WEEKENDER OUT') {
				$incustody = "<font color=red>Weekender Out</font>";
			} elsif ($cell eq 'IN-HOUSE ARREST') {
				$incustody = "<font color=red>House Arrest</font>";
			}
		} else {
			$incustody = "Not In PBSO Custody ";
			$injail=0;
		}
		print qq {
			<table class="summary" border="10">
				<tr>
					<td colspan="6" class="title">
						All PBSO Booking Information for this Defendant - Jacket $bookings{$bookingids[0]}->{'InmateId'} - $incustody
					</td>
				</tr>
				<tr class="title" style="vertical-align: middle">
					<td class="vcenter" style="width: 8%">
						Booking Date
					</td>
					<td class="vcenter" style="width: 8%">
						Release Date
					</td>
					<td class="vcenter" style="width: 8%">
						Days<br/>Served
					</td>
					<td class="vcenter">
						Photo<br/>
						Height/Weight/Age
					</td>
					<td class="vcenter">
						PBSO Booking #
					</td>
					<td class="vcenter" style="width: 70%">
						Case Information
					</td>
				</tr>
		};

		# Now, we have the lists of booking ids and start and end indexes for each.
		# Process each booking id.
		$i = 0;
		my $conn_cache;
		my $ua;
		if (scalar(@bookingids)) {
			$conn_cache = LWP::ConnCache->new(
				'total_capacity' => 50
											 );
			$ua = LWP::UserAgent->new(
				'conn_cache' => $conn_cache
			);
		}

		foreach my $bookingid (@bookingids) {
			my $hashref = $bookings{$bookingid};
			if ($hashref->{InmatePhoto} ne "") {
				# Try to get a copy and store it locally
				my $newpath = getBookingPhoto($hashref->{InmatePhoto},$ua);
				if (defined($newpath)) {
					$hashref->{InmatePhoto} = $newpath;
				}
			}
			if ($hashref->{'ReleaseDate'} eq "") {
				$hashref->{'Days'} = $hashref->{'SoFar'};
			}
			if ($hashref->{'Days'} < 0) {
				$hashref->{'Days'} = 0;
				$hashref->{'ReleaseDate'} = $hashref->{'fBookingDate'};
			}

			$i += $hashref->{'Days'};
			print qq{
				<tr>
					<td class="vcenter">
						$hashref->{fBookingDate}
					</td>
					<td class="vcenter">
						$hashref->{ReleaseDate}
					</td>
					<td class="vcenter">
						$hashref->{Days}
					</td>
					<td class="vcenter">
						<a href='$hashref->{InmatePhoto}'>
						<img alt="booking photo" src="$hashref->{InmatePhoto}" width="36" height="46"/>
						</a>
						<br/>
						$hashref->{HeightFeet}' $hashref->{HeightInches}"
						&nbsp;/&nbsp;$hashref->{Weight}
						&nbsp;/&nbsp;$hashref->{AgeAtBooking}
					</td>
					<td class="vcenter">
						<a href="pbsobview.cgi?jacket=$hashref->{InmateId}&amp;booking=$bookingid&amp;lev=$nextlev">
							$bookingid
						</a>
					</td>
			};

			# PBSO Case Breakdown
			print qq{
				<td>
					<table class="caseinfo">
						<thead>
						<tr>
							<td>
								Arrest Date
							</td>
							<td class="charges" style="text-align:center">
								Charges
							</td>
							<td>
								JVS Case # (Status)
							</td>
							<td>
								PBSO Case #
							</td>
						</tr>
						</thead>
						<tbody>
			};
			foreach my $case (reverse sort { $a <=> $b } (keys %{$hashref->{PBSOCases}})) {
				my $caseref = $hashref->{PBSOCases}->{$case};
				if ($caseref->{ArrestDate} eq '') {
					$caseref->{ArrestDate} = $hashref->{fBookingDate};
				}
				print "<tr>\n";
				printCell($caseref->{ArrestDate});
				my $chargeStr;
				escapeFields($caseref->{'Charges'});
				foreach my $chargeSeq (sort { $a <=> $b } (keys %{$caseref->{Charges}})) {
					$chargeStr .= " &bull; &nbsp; " . $caseref->{Charges}->{$chargeSeq} . "\n<br/>\n";
				}
				printCell($chargeStr,"class='charges'");
				if (defined($icmscases{$case})) {
					my $ucn = $icmscases{$case}[0]->{CaseNumber};
					my $legacy = $icmscases{$case}[0]->{LegacyCaseFormat};
					my $cellStr;
					if ($legacy eq $bncasenum) {
						$cellStr = qq{
							<span style="color: blue; float: left">&radic;&nbsp;</span>
						};
					#} else {
					#	$cellStr .= qq{
					#		<span style="float: left">&nbsp;&nbsp;&nbsp;</span>
					#	};
					}
					$cellStr .= qq{
						<a href="/cgi-bin/search.cgi?name=$ucn">
							$legacy
						</a>
						&nbsp;&#40;$icmscases{$case}[0]->{CaseStatus}&#41;&nbsp;
					};
					printCell($cellStr,qq{ style="text-align:center"});
				} else {
					printCell("&nbsp;");
				}
				printCell($case);
				print "</tr>\n";
			}
			print qq{
					</tbody>
				</table>
				</td>
				</tr>
			};
			$totaldays += $hashref->{Days};
		}
		#------------------------
		# show total days served
		#------------------------
		print qq{
			<tr>
				<td colspan="2" style="text-align: right">
					Total Days Served
		};
		if ($injail eq 1) {
			print qq{
				<span style="color: red; float: left">So Far<span>
			};
		}
		print qq{
			</td>
				<td class="center">
					$totaldays
				</td>
				<td colspan="8">
					&nbsp;
				</td>
				</tr>
			</table>
		};
	}
}



#
# The following subs write sections of the pbso booking details information.
#
# Many require the data to have been gotten and be present in an @alldata array.
#
sub write_jacketIdentifier {
	my $jacket = shift;
	my $dbh = shift;
	
	if (!defined($dbh)) {
		$dbh = dbConnect("pbso2");
	}
	
	print qq {
		<table class="summary" cellspacing="5">
			<tr>
				<td colspan="5" class="title">
					Person Identification Information for Jacket # $jacket
				</td>
				</tr>
			<tr class="title">
				<td class="left">
					Names
				</td>
				<td class="center">
					Birth Date(s)
				</td>
				<td class="center">
					Current Age(s)
				</td>
				<td>
					Maiden Name(s)
				</td>
				<td class="center">
					Most Recent<br/>Booking Photo<br/>and Booking Date
				</td>\n
			</tr>
	};
	my @names;
	my @dobs;
	my @mnames;
	
	get_pbsonames(\@names, $jacket, $dbh);
	get_pbsodobs(\@dobs, $jacket, $dbh);
	get_pbsomnames(\@mnames, $jacket, $dbh);
	
	my $mug = get_mugshot_incustody_usingInmateId($jacket, $dbh);
	
	my($photoid,$injail) = split ';',$mug;

	if ($photoid ne "") {
		my $newpath = getBookingPhoto($photoid);
		if (defined($newpath)) {
			$photoid = $newpath;
		}
	}

	my $mostrec = get_mostrecentbookingdate($jacket, $dbh);
	print "<tr>\n<td>\n";
	foreach my $name (@names) {
		my $n = $name->{'InmateName'};
		print "$n<br/>";
	}
	print "<td>";
	my @cages=();
	foreach my $dob (@dobs) {
		my $d = $dob->{'DOB'};
		
		my $a=getageinyears($d);
		
		my $ind = index($a, '.');
		if ($ind>-1) {
			$a = substr($a,0,$ind);
		}
		push(@cages,$a);
		print "$d<br/>";
	}
	print "<td align=center>";
	foreach my $age (@cages) {
		print "$age<br/>";	
	}
	print "<td>";
	
	foreach my $mname (@mnames) {
		my $n = $mname->{'MaidenName'};
		print "$n<br/>";
	}

	print "<td align=center>";
	if ($photoid eq 'no arrests') {
		print "no photo<br/>(no arrests on file)";
	} elsif ($photoid eq 'no booking number') {
		print "photo not available<br/>(arrests on file)";
	} elsif ($photoid eq 'no pbso data found') {
		print "photo not available<br/>(arrests on file)";
	} else {
		print "<a ";
		# replace \ with / in photo - should have been done with the database call!
		$photoid =~ s/\\/\//g;
		print "href='$photoid' >";
		print "<img alt='most recent photo' src=$photoid width=36 height=46></a>";
		print "<br/>";
		if ($injail eq 'Yes') {
			print "<font color=red>In PBSO Custody</font>";
		} elsif ($injail eq 'No') {
			print "Not In PBSO Custody";
		} else {
			print "<font color=red>$injail</font>";
		}
	}
	print "<br>$mostrec";
	print "</table>";
}


#
# Write Booking Header
#
sub write_bookingHeader {
	my $jacket = shift;
	my $bookingid = shift;
	my $dbh = shift;
	
	if (defined($dbh)) {
		$dbh = dbConnect("pbso2");
	}
	
	my $incustody;
	
	my @data = get_bookingHeader($jacket,$bookingid,$dbh);
	
	print qq {
		<table class="summary" cellspacing="5">
			<tr>
				<td colspan="6" class="title">
					Booking Information for Booking # $bookingid
				</td>
			</tr>
	};
	print qq{
		<tr class="title">
			<td class="center">
				Booking Date
			</td>
			<td class="center">
				Release Date
			</td>
			<td>
				Days Served
			</td>
			<td class="center">
				This Booking<br/>Photo<br/>Height/Weight/Age
			</td>
			<td>
				Race
				</td>
			<td>
				Inmate Status
			</td>
		</tr>
	};
	
	my $rec = $data[0];
	my $im = $rec->{'InmateId'};
	my $bd = $rec->{'FBD'};
	my $rd = $rec->{'ReleaseDate'};
	my $hf = $rec->{'HeightFeet'};
	my $hi = $rec->{'HeightInches'};
	my $w = $rec->{'Weight'};
	my $age = $rec->{'AgeAtBooking'};
	my $days = $rec->{'DaysServed'};
	my $sofar = $rec->{'DaysSoFar'};
	my $r = $rec->{'Race'};
	my $is = $rec->{'InmateStatus'};
	my $photoid = $rec->{'InmatePhoto'};
	my $cell = $rec->{'AssignedCellID'};
	
	# replace \ with / in photo - should have been done with the database call!
	$photoid =~ s/\\/\//g;

	if ($photoid ne "") {
		my $newpath = getBookingPhoto($photoid);
		if (defined($newpath)) {
			$photoid = $newpath;
		}
	}

	if ($rd eq '') {
		$incustody = "<font color=red>In PBSO Custody</font>";
		if ($cell eq "ESCAPED") {
			print "<font color=red>Escaped</font>";
		} elsif ($cell eq "WEEKENDER OUT") {
			print "<font color=red>Weekender Out</font>";
		} elsif ($cell eq "IN-HOUSE ARREST") {
			print "<font color=red>Under House Arrest</font>";
		}
	} else {
		$incustody = "Not In PBSO Custody ";
	}

	if ($age == 0) {
		$age = "&nbsp;";
	}
	if ($w == 0) {
		$w = "&nbsp;";
	}
	#if ($rd eq '') {
	#	$rdate= '&nbsp;';
	#	$days=$sofar;
	#} else {
	#	$rdate=$rd;
	#}
	if ($days < 0) {
		$days = 0;
	} elsif ($days eq '') {
		$days = '&nbsp;';
	}

	if ($rd eq '') {
		$days .= " so far";
	}

	if ($rd eq '01/01/1900') {
		$rd = $bd;
	}

	my $height;
	if ($hf < 4) {
		$height = '&nbsp;';
	} else {
		$height = "$hf' $hi\"";
	}

	if ($r eq 'A') {
		$r='Asian';
	} elsif ($r eq 'B') {
		$r='Black';
	} elsif ($r eq 'H') {
		$r='Hispanic';
	} elsif ($r eq 'I') {
		$r='Indian';
	} elsif ($r eq 'O') {
		$r='Other';
	} elsif ($r eq 'W') {
		$r='White';
	} else {
		$r='Unknown';
	}

	if ($is eq '') {
		$is="&nbsp;";
	}

	print "<tr><td align=center>$bd";
	print "<td align=center>$rd";
	print "<td align=right>$days&nbsp;&nbsp;&nbsp;";
	print "<td align=center><a ";
	print "href='$photoid' >";
	print "<img alt='booking photo for date $bd' src=$photoid width=36 ".
		"height=46></a>";
	print "<br/>";
	print $height;
	print "&nbsp;/&nbsp;$w";
	print "&nbsp;/&nbsp;$age";
	print "<td>$r<td align=center>$is";
	print "</table>";
}

# get all the booking header details
#
sub get_bookingHeader {
	my $inmate = shift;
	my $bookingid = shift;
	my $dbh = shift;
	
	if (!defined($dbh)) {
		$dbh = dbConnect("pbso2");
	}
	
	# get all the pbso data for this inmate
	# This should have returned with the photolocation always using forward
	# slash, but didn't. Probably because it's in the string... so, for Firefox,
	# will have to fix in line...

	my $query = qq {
		select
			distinct InmateId,
			convert(varchar(10),bookingdate,101) as FBD,
			convert(varchar(10),releasedate,101) as ReleaseDate,
			substring(convert(varchar,HeightFeet),1,1)as HeightFeet,
			HeightInches,
			Weight,
			AgeAtBooking,
			datediff(d,BookingDate,ReleaseDate) as DaysServed,
			datediff(d,BookingDate,getdate()) as DaysSoFar,
			Race,
			InmateStatus,
	        isnull(
				(select
					top 1 'http:' + REPLACE(photolocation, '\','/')
				from
					$ipview
				where
					bookingid = $view.bookingid
					and inmateid = $view.inmateid
					and front=1
					and activephoto=1),
					'http://www.pbso.org/bkimages/star/star.jpg'
			) as InmatePhoto,
			AssignedCellID
		from
			$view
		where
			InmateId = ?
			and Bookingid = ?
		};
		
	my @args = ($inmate, $bookingid);
	
	my @bookings;
	getData(\@bookings, $query, $dbh, { valref => \@args });
	
	return @bookings;
}

#
# Write Arrest Information Section - by booking id
#
sub write_bookingArrestInformation {
    my $jacket = shift;
    my $bookingid = shift;
    my $dbh = shift;
    
    if (!defined($dbh)) {
        $dbh = dbConnect("pbso2");
    }
    
    my @data = get_bookingArrestInformation($jacket,$bookingid, $dbh);
    
    print qq {
	<table class="summary" cellspacing="5">
		<tr>
			<td colspan="8" class="title">
				PBSO Arrest Information for Booking # $bookingid
			</td>
		</tr>
		<tr class="title">
			<td>
				Arrest<br/>Date
			</td>
			<td>
				PBSO Case Number
			</td>
			<td>
				Arresting Agency
			</td>
			<td>
				Arresting Officer
			</td>
			<td>
				Case Type
			</td>
			<td>
				Commit Document
			</td>
			<td>
				Commit Agency
			</td>
			<td>
				Conviction Date
			</td>
		</tr>
	};
    
    foreach my $row (@data) {
        my $im = $row->{'InmateID'};
        my $cn = $row->{'CaseNumber'};
        my $cardt = $row->{'CArrestDate'};
        my $aa = $row->{'ArrestingAgency'};
        my $ao = $row->{'ArrestingOfficer'};
        my $ct = $row->{'CaseType'};
        my $cd = $row->{'CommitDocument'};
        my $ca = $row->{'CommitAgency'};
        my $cdt = $row->{'ConvictionDate'};
        my $bd = $row->{'BookingDate'};
        
        # old data may not always have an arrest date.  if not, use the booking date.
        if ($cardt eq '') {
            $cardt=$bd;
        }
        
        print "<tr><td>$cardt<td>$cn<td>$aa<td>$ao<td>$ct";
        print "<td>$cd<td>$ca<td>$cdt";
    }
    print "</table>";
}

#
# Get all the Arrest Information for this booking.
#
sub get_bookingArrestInformation {
	my $inmate = shift;
	my $bookingid = shift;
    my $dbh = shift;
    
    if (!defined($dbh)) {
        $dbh = dbConnect("pbso2");
    }
	
	my @data;
	my $query = qq {
        select
            distinct InmateID,
            CaseNumber,
            convert(varchar(10),carrestdate,101) as CArrestDate,
            ArrestingAgency,
            ArrestingOfficer,
            CaseType,
            CommitDocument,
            CommitAgency,
            convert(varchar(10),convictiondate,101) as ConvictionDate,
            convert(varchar(10),bookingdate,101) as BookingDate
        from
            $view
        where
            InmateID = ?
            and BookingID = ?
        order by
            CArrestDate desc
    };
    
    my @args = ($inmate, $bookingid);
    
    getData(\@data, $query, $dbh, {valref => \@args});
    
    return @data;
}

#
# Write Charge/Bond Information Section - by booking id
#
sub write_bookingChargeBondInformation {
    my $jacket = shift;
    my $bookingid = shift;
    my $dbh = shift;
    
    if (!defined($dbh)) {
        $dbh = dbConnect("pbso2");
    }
    
    my @data = get_bookingChargeBondInformation($jacket,$bookingid, $dbh);
    
    print qq {
	<table class="summary" cellspacing="5">
		<tr>
			<td colspan="13" class="title">
				PBSO Charge/Bond Information for Booking # $bookingid
			</td>
		</tr>
		<tr class="title">
			<td>
				Arrest Date
			</td>
			<td>
				PBSO Case Number
			</td>
			<td>
				Charge Date
			</td>
			<td>
				Code
			</td>
			<td>
				Charge Description
			</td>
			<td>
				Dispostion Date
			</td>
			<td>
				Disposition Description
			</td>
			<td>
				Bond Amt
			</td>
			<td>
				Bond Amt<br/>Written
			</td>
			<td>
				Charge Bond<br/>Required Amt
			</td>
			<td>Bond Type</td>
			<td>
				Bond Return Date
			</td>
			<td>
				Current Bond
			</td>
		</tr>
	};
    
    # get the first case number
    my $thiscn = $data[0]->{'CaseNumber'};
    
    foreach my $row (@data) {
        my $im = $row->{'InmateID'};
        my $bd = $row->{'BookingDate'};
        my $cn = $row->{'CaseNumber'};
        my $cardt = $row->{'CArrestDate'};
        my $cs = $row->{'ChargeSequence'};
        my $cdt = $row->{'ChargeDate'};
        my $cc = $row->{'ChargeCode'};
        my $cdesc = $row->{'ChargeDescription'};
        my $cddt = $row->{'ChargeDispositionDate'};
        my $cddesc = $row->{'ChargeDispositionDesc'};
        my $ba = $row->{'BondAmount'};
        my $baw = $row->{'BondAmountWritten'};
        my $cbra = $row->{'ChargeBondRequiredAmt'};
        my $bt = $row->{'BondType'};
        my $brdt = $row->{'BondReturnDate'};
        my $cb = $row->{'CurrentBond'};
        
        if ($cn != $thiscn) {
            print "<tr><td colspan=13 align=center>";
            print "<hr>";
            $thiscn = $cn;
        }
        
        if ($cardt eq '') {
            $cardt = $bd;
        }
        
        print "<tr><td>$cardt<td>$cn<td>$cdt<td>$cc<td>$cdesc<td>$cddt<td>$cddesc";
        print "<td align=right>$ba<td align=right>$baw<td align=right>$cbra<td>$bt<td>$brdt<td align=right>$cb";
    }
    print "</table>";
}

#
# Get all the Charge/Bond Information for this booking.
#
sub get_bookingChargeBondInformation {
	my $inmate = shift;
	my $bookingid = shift;
    my $dbh = shift;
    
    if (!defined($dbh)) {
        $dbh = dbConnect("pbso2");
    }

	my @data;

	my $pbsodbh = dbConnect("pbso2");
	# get all the pbso data for this inmate
	my $query = qq {
		select
			distinct InmateID,
            convert(varchar(10),bookingdate,101) as BookingDate,
            CaseNumber,
            convert(varchar(10),carrestdate,101) as CArrestDate,
            ChargeSequence,
            convert(varchar(10),chargedate,101) as ChargeDate,
            ChargeCode,
            ChargeDescription,
            convert(varchar(10),chargedispositiondate,101) as ChargeDispositionDate,
            ChargeDispositionDesc,
            BondAmount,
            BondAmountWritten,
            ChargeBondRequiredAmt,
            BondType,
            convert(varchar(10),bondreturndate,101) as BondReturnDate,
            CurrentBond
        from
            $view
        where
            InmateId = ?
            and bookingid = ?
        order by
            BookingDate desc,
            CaseNumber desc,
            ChargeSequence asc
    };
    
    my @args = ($inmate, $bookingid);

    getData(\@data, $query, $dbh, {valref => \@args});
    
	return @data;
}

#
# Write Sentencing Information for this booking
#
sub write_bookingSentencing {
    my $jacket = shift;
    my $bookingid = shift;
    my $dbh = shift;;
    
    if (!defined($dbh)) {
        $dbh = dbConnect("pbso2");
    }
    
	my @data = get_bookingSentencing($jacket,$bookingid,$dbh);

	print qq {
		<table class="summary" cellspacing="5"
			<tr>
				<td colspan="15" class="title">
					Sentencing Information for Booking # $bookingid
				</td>
			</tr>
			<tr class="title">
				<td>
					Sentence<br/>Date
				</td>
				<td>
					Sentence<br/>Judge
				</td>
				<td>
					Sentence<br/>Start<br/>Date
				</td>
				<td>
					Sentence<br/>Original<br/>Date
				</td>
				<td>
					Sentence<br/>End<br/>Date
				</td>
				<td>
					Sentence<br/>Complete<br/>Date
				</td>
				<td>
					Sentence<br/>Description
				</td>
				<td>
					Sentence<br/>Days
				</td>
				<td>
					Court<br/>Credit<br/>Days
				</td>
				<td>
					State<br/>Credit<br/>Days
				</td>
				<td>
					Deduct<br/>Days
				</td>
				<td>
					Gain<br/>Days
				</td>
				<td>
					Net<br/>Days
				</td>
				<td>
					Revision<br/>Date
				</td>
				<td>
					Revision<br/>Number
				</td>
			</tr>
	};
    
    foreach my $row (@data) {
        my $im = $row->{'InmateID'};
        my $complete = $row->{'SentenceCompleteDate'};
        my $consec = $row->{'SentenceConsecutive'};
        my $ccd = $row->{'SentenceCourtCreditDays'};
        my $date = $row->{'SentenceDate'};
        my $days = $row->{'SentenceDays'};
        my $deduct = $row->{'SentenceDeductDays'};
        my $desc = $row->{'SentenceDescription'};
        my $end = $row->{'SentenceEndDate'};
        my $gain = $row->{'SentenceGainDays'};
        my $j = $row->{'SentenceJudge'};
        my $net = $row->{'SentenceNetDays'};
        my $order = $row-{'SentenceOrder'};
        my $revd = $row->{'SentenceRevisionDate'};
        my $revn = $row->{'SentenceRevisionNumber'};
        my $start = $row->{'SentenceStartDate'};
        my $orig = $row->{'SentenceStartOriginal'};
        my $scd = $row->{'SentenceStateCreditDays'};
        
        print "<tr><td>$date<td>$j<td>$start<td>$orig<td>$end";
        print "<td>$complete<td>$desc<td align=right>$days<td align=right>$ccd<td align=right>$scd";
        print "<td align=right>$deduct<td align=right>$gain<td align=right>$net<td>$revd<td align=right>$revn";
    }
    print "</table>";
}

#
# Get all the Sentencing Information for this booking.
# Not sure about this....  Shouldn't there only be one per booking?
# That's why I added the sentencedate is not null.
#
#
sub get_bookingSentencing {
    my $inmate = shift;
    my $bookingid = shift;
    my $dbh = shift;
    
    if (!defined($dbh)) {
        $dbh = dbConnect("pbso2");
    }
    
	my @sentences;
    
	# get all the pbso data for this inmate
	my $query = qq {
        select
            distinct InmateID,
            convert(varchar(10),sentencecompletedate,101) as SentenceCompleteDate,
            SentenceConsecutive,
            SentenceCourtCreditDays,
            convert(varchar(10),sentencedate,101) as SentenceDate,
            SentenceDays,
            SentenceDeductDays,
            SentenceDescription,
            convert(varchar(10),sentenceenddate,101) as SentenceEndDate,
            SentenceGainDays,
            SentenceJudge,
            SentenceNetDays,
            SentenceOrder,
            convert(varchar(10),sentencerevisiondate,101) as SentenceRevisionDate,
            SentenceRevisionNumber,
            convert(varchar(10),sentencestartdate,101) as SentenceStartDate,
            convert(varchar(10),sentencestartoriginal,101) as SentenceStartOriginal,
            SentenceStateCreditDays
        from
            $view
        where
            inmateid = ?
            and bookingid = ?
            and sentencedate is not null
        order by
            sentencestartdate desc
    };
    
    my @args = ($inmate, $bookingid);
    
    getData(\@sentences, $query, $dbh, { valref => \@args });
    
    return @sentences;
}


# get pbso inmate id based on pbso booking id
#
sub getInmateIdBooking {
  my($bookingid)=@_;
  dbdisconnect();
  dbconnect("pbso2");
  my $query = "select distinct InmateId
			     from $view
				 where BookingId='$bookingid'";
  my($inmateid) = sqllistone($query);
  dbdisconnect();
  return $inmateid;
}

#
# get pbso inmate id based on pbso casenumber
# (pbso case number is the banner booking #)
#
sub getInmateIdCase {
  my($pbsocasenum)=@_;
  my $savedb = $DB;
  dbdisconnect();
  dbconnect("pbso2");
  my $query = "select distinct InmateId
			     from $view
				 where CaseNumber='$pbsocasenum'";
  my($inmateid) = sqllistone($query);
  dbdisconnect();
  dbconnect($savedb);
  return $inmateid;
}

# should go in a common file....
sub casenumtoucn {
  my($casenum)=@_;
  my $x=substr($casenum,0,4)."-".substr($casenum,4,2)."-".substr($casenum,6,6);
  if (substr($casenum,12,1) ne "") {
    $x.="-".substr($casenum,12);
  }
  return $x;
}

# get distinct names for an inmate, given the inmateid
sub get_pbsonames {
	my $nameref = shift;
	my $inmate = shift;
	my $dbh = shift;
	if (!defined($dbh)) {
		$dbh = dbConnect("pbso2");
	}
	
	my $query = qq{
		select
			distinct (inmatename) as InmateName
		from
			$view
		where
			InmateId = ?
	};
	
	my @args = ($inmate);
	
	getData($nameref, $query, $dbh, { valref => \@args });
}

# get distinct maiden names for an inmate, given the inmateid
sub get_pbsomnames {
	my $nameref = shift;
	my $inmate = shift;
	my $dbh = shift;
	
	if (!defined($dbh)) {
		dbConnect("pbso2");
	};
	
	my $query = qq{
		select
			distinct maidenname as MaidenName
		from
			$view
		where
			InmateId = ?
	};
  
  	my @args = ($inmate);
	
	getData($nameref, $query, $dbh, { valref => \@args });
}

#get distinct dobs for an inmate, given the inmateid
sub get_pbsodobs {
	my $dbref = shift;
	my $inmate = shift;
	my $dbh = shift;
	
	if (!defined($dbh)) {
		$dbh = dbConnect("pbso2");
	}
	
	my $query = qq{
		select
			distinct convert(varchar(10),birthdate,101) as DOB
		from
			$view
		where
			InmateId = ?
	};
	
	my @args = ($inmate);
	
	getData($dbref, $query, $dbh, { valref => \@args });
}

# get all pbso booking case details (but no charge info)
#
# 2/4/11 modified for showcase integration
#
sub get_pbsobookingcaseinfo {
  my($inmate,$bookingid)=@_;
  my(@bookings);
  my $savedb = $DB;
  dbconnect("pbso2");
  # get all the pbso data for this inmate
  # This should have returned with the photolocation always using forward slash, but didn't.
  # Probably because it's in the string... so, for Firefox, will have to fix in line...
  my $query = "select distinct InmateId,
			  bookingid,bookingdate,
			  convert(varchar(10),bookingdate,101) as fbd,
			  convert(varchar(10),releasedate,101) as releasedate,
			  substring(convert(varchar,HeightFeet),1,1) as heightfeet,
			  heightinches,weight,ageatbooking,
			  datediff(d,BookingDate,ReleaseDate),
			  datediff(d,BookingDate,getdate()),
			  casenumber,
			  convert(varchar(10),carrestdate,101) as carrestdate,
			  chargedate,chargecode,chargeprimary,chargedescription,chargesequence,
			  chargedispostiondate,chargedispositiondesc,
			  arrestingagency,arrestingofficer,
			  casetype,commitdocument,convictiondate
	              ,isnull((select top 1 'http:' + REPLACE(photolocation, '\','/')
                     from $ipview
                     where  bookingid = $view.bookingid
                            and inmateid = $view.inmateid
                            and front=1
                            and activephoto=1),
					 'http://www.pbso.org/bkimages/star/star.jpg') as inmatephoto,
              assignedcellid
			  from $view
			  where InmateId='$inmate' and Bookingid='$bookingid'
			  order by bookingdate desc, casenumber desc, chargesequence asc";
  @bookings = sqllist($query);
  # We have every thing we need from pbso in that one table.
  dbdisconnect();
  dbconnect($savedb);
}


#
# -------------------------------------------------------------------------------------------------------
#
# for testing purposes - not formatted for icms....
# writes all pbso info for this jacket (inmate) #
sub write_testpbsoallinfo {
  my($inmate)=@_;
  my(@bookings);

  dbdisconnect();
  dbconnect("pbso2");

  # ---------------------------------------

  # get all the alert data for this inmate
  my $query = "select distinct InmateId,bookingdate, convert(varchar(10),".
    "bookingdate,101),bookingid,casenumber,chargesequence,alertflag,".
      "alertcode,alertseq,alertnarrative,alertsetdate,alertsetby,alertssort ".
	"from $view where InmateId='$inmate' ".
	  "order by bookingdate desc, casenumber desc, chargesequence asc";

  @bookings = sqllist($query);
  my $row=1;
  print "<table border=10><tr>";
  print "<td>&nbsp;<td>bookingdate<td>bookingid<td>casenumber<td>charge<br>".
    "sequence";
  print "<td>alertflag<td>alertcode<td>alertseq<td>alertnarrative<td>".
    "alertsetdate<td>alertsetby<td>alertssort";
  foreach (@bookings) {
    print "<tr>";
    my($im,$bookdate,$fbd,$bookid,$cn,$cseq,
       $aflag,$acode,$aseq,$anarr,$asd,$asetby,$asort)=split '~',$_;
    print "<td>$row<td>$fbd<td>$bookid<td>$cn<td>$cseq";
    print "<td>$aflag<td>$acode<td>$aseq<td>$anarr<td>$asd<td>$asetby<td>".
      "$asort";
    $row++;
  }
  print "</table>";

  #----------------------------------

  # next section stuff
  $query = "select distinct InmateId,bookingdate, convert(varchar(10),".
    "bookingdate,101),bookingid,casenumber,chargesequence,fbinumber,".
      "aliennumber,assignedcellid,assignedfacilityid,bookingstatus,".
	"custodylevel,fbi,gender,idstatus,inmatestatus ".
	  "from $view where InmateId='$inmate' ".
	    "order by bookingdate desc, casenumber desc, chargesequence asc";
  @bookings = sqllist($query);
  $row=1;
  print "<table border=10><tr>";
  print "<td>&nbsp;<td>bookingdate<td>bookingid<td>casenumber<td>charge".
    "<br>sequence";
  print "<td>fbinumber<td>aliennumber<td>cellid<td>facilityid";
  print "<td>bookingstatus<td>custodylevel<td>fbi<td>gender<td>idstatus<td>".
    "inmatestatus";
  foreach (@bookings) {
    print "<tr>";
    my($im,$bookdate,$fbd,$bookid,$cn,$cseq,
       $fbin,$an,$cell,$facility,$bs,$cl,$fbi,$gen,$ids,$ims)=split '~',$_;

    print "<td>$row<td>$fbd<td>$bookid<td>$cn<td>$cseq";
    print "<td>$fbin<td>$an<td>$cell<td>$facility<td>$bs";
    print "<td>$cl<td>$fbi<td>$gen<td>$ids<td>$ims";
    $row++;
  }
  print "</table>";

  #-------------------------------------------------------------------------

  $query = "select distinct InmateId,bookingdate, convert(varchar(10),".
    "bookingdate,101),bookingid,casenumber,chargesequence,ncicnumber,".
      "pfsdays,prisonertype,sid,arrestingagency,arrestingbadge,".
	"arrestingofficer ".
	  "from $view where InmateId='$inmate' order by bookingdate desc, ".
	    "casenumber desc, chargesequence asc";
  @bookings = sqllist($query);
  $row=1;
  print "<table border=10><tr>";
  print "<td>&nbsp;<td>bookingdate<td>bookingid<td>casenumber<td>charge<br>".
    "sequence";
  print "<td>ncic<td>pfs<td>prisonertype<td>sid<td>arrestingagency<td>".
    "badge<td>officer";
  foreach (@bookings) {
    print "<tr>";
    my($im,$bookdate,$fbd,$bookid,$cn,$cseq,
       $ncic,$pfs,$ptype,$sid,$aa,$ab,$ao)=split '~',$_;
    print "<td>$row<td>$fbd<td>$bookid<td>$cn<td>$cseq";
    print "<td>$ncic<td>$pfs<td>$ptype<td>$sid<td>$aa<td>$ab<td>$ao";
    $row++;
  }
  print "</table>";

  #-------------------------------------------------------------------------
  # bond stuff
  $query = "select distinct InmateId,bookingdate, convert(varchar(10),".
    "bookingdate,101),bookingid,casenumber,chargesequence,bondagentcode,".
      "bondagentname,bondamount,chargebondrequiredamt,bondamountwritten,".
	"bondblanketac,bondby,bondinsurercode ".
	  "from $view where InmateId='$inmate' ".
	    "order by bookingdate desc, casenumber desc, chargesequence asc";
  @bookings = sqllist($query);
  $row=1;
  print "<table border=10><tr>";
  print "<td>&nbsp;<td>bookingdate<td>bookingid<td>casenumber<td>charge<br>".
    "sequence";
  print "<td>bondagent<td>name<td>amount<td>reqdamt<td>amtwritten";
  print "<td>blanketac<td>bondby<td>insurercode";
  foreach (@bookings) {
    print "<tr>";
    my($im,$bookdate,$fbd,$bookid,$cn,$cseq,
       $a,$n,$amt,$ramt,$aw,$bac,$bb,$ic)=split '~',$_;
    print "<td>$row<td>$fbd<td>$bookid<td>$cn<td>$cseq";
    print "<td>$a<td>$n<td>$amt<td>$ramt<td>$aw<td>$bac<td>$bb";
    print "<td>$ic";
    $row++;
  }
  print "</table>";

  #-------------------------------------------------------------------------
  # bond stuff
  $query = "select distinct InmateId,bookingdate, convert(varchar(10),".
    "bookingdate,101),bookingid,casenumber,chargesequence,".
      "bondinsurerlimit,bondinsurername,bondpower,convert(varchar(10),".
	"bondreturndate,101),bondtype,currentbond ".
	  "from $view where InmateId='$inmate' ".
	    "order by bookingdate desc, casenumber desc, chargesequence asc";
  @bookings = sqllist($query);
  $row=1;

  print "<table border=10><tr>";
  print "<td>&nbsp;<td>bookingdate<td>bookingid<td>casenumber<td>charge".
    "<br>sequence";
  print "<td>limit<td>name<td>power<td>returndate<td>bondtype<td>currentbond";

  foreach (@bookings) {
    print "<tr>";
    my($im,$bookdate,$fbd,$bookid,$cn,$cseq,
       $l,$nm,$p,$rd,$t,$cb)=split '~',$_;
    print "<td>$row<td>$fbd<td>$bookid<td>$cn<td>$cseq";
    print "<td>$l<td>$nm<td>$p<td>$rd<td>$t<td>$cb";
    $row++;
  }
  print "</table>";


  #-------------------------------------------------------------------------
  # arrest stuff
  $query = "select distinct InmateId,bookingdate, convert(varchar(10),".
    "bookingdate,101),bookingid,casenumber,chargesequence,".
      "convert(varchar(10),carrestdate,101),caseby,caseflag,caseitn,".
	"casenumber,caseseq, casetype,commitdocument,convictiondate,".
	  "disposition,convert(varchar(10),dispositiondate,101),".
	    "convert(varchar(10),indictdate,101) ".
	      "from $view where InmateId='$inmate' ".
		"order by bookingdate desc, casenumber desc, chargesequence asc";
  @bookings = sqllist($query);

  $row=1;
  print "<table border=10><tr>";
  print "<td>&nbsp;<td>bookingdate<td>bookingid<td>casenumber<td>charge".
    "<br>sequence";
  print "<td>carrest<td>caseby<td>caseflag<td>caseitn<td>casenumber<td>".
    "caseseq";
  print "<td>casetype<td>commitdoc<td>convictiondate<td>disposition<td>".
    "date<td>indictdate";
  foreach (@bookings) {
    print "<tr>";
    my($im,$bookdate,$fbd,$bookid,$cn,$cseq,
       $a,$cb,$cf,$citn,$cn2,$cs,$ct,$cd,$cdt,$d,$dd,$id,$t)=split '~',$_;

    print "<td>$row<td>$fbd<td>$bookid<td>$cn<td>$cseq";
    print "<td>$a<td>$cb<td>$cf<td>$citn<td>$cn2<td>$cs<td>$ct<td>$cd".
      "<td>$cdt<td>$d<td>$dd<td>$id<td>$t";
    $row++;
  }
  print "</table>";

  #-------------------------------------------------------------------------
  # other arrest stuff - not doing address
  $query = "select distinct InmateId,bookingdate, convert(varchar(10),".
    "bookingdate,101),bookingid,casenumber,chargesequence,".
      "convert(varchar(10),arrestdate,101),arrestagency,arrestbadge,arrestby".
	"from $view where InmateId='$inmate' ".
	  "order by bookingdate desc, casenumber desc, chargesequence asc";
  @bookings = sqllist($query);
  $row=1;
  print "<table border=10><tr>";
  print "<td>&nbsp;<td>bookingdate<td>bookingid<td>casenumber<td>charge".
    "<br>sequence";
  print "<td>arrestdate<td>arrestagency<td>arrestbadge<td>arrestby";
  foreach (@bookings) {
    print "<tr>";
    my($im,$bookdate,$fbd,$bookid,$cn,$cseq,
       $a,$aa,$ab,$aby)=split '~',$_;
    print "<td>$row<td>$fbd<td>$bookid<td>$cn<td>$cseq";
    print "<td>$a<td>$aa<td>$ab<td>$aby";
    $row++;
  }
  print "</table>";

  #-------------------------------------------------------------------------
  # commit stuff
  $query = "select distinct InmateId,bookingdate, convert(varchar(10),".
    "bookingdate,101),bookingid,casenumber,chargesequence, commitagency,".
      "commitbadge,commitby,courtdefendantnumber,obts,priorobts ".
	"from $view where InmateId='$inmate' ".
	  "order by bookingdate desc, casenumber desc, chargesequence asc";
  @bookings = sqllist($query);
  $row=1;
  print "<table border=10><tr>";
  print "<td>&nbsp;<td>bookingdate<td>bookingid<td>casenumber<td>charge".
    "<br>sequence";
  print "<td>commitagency<td>commitbadge<td>commitby<td>".
    "courtdefendantnumber<td>obts<td>priorobts";
  foreach (@bookings) {
    print "<tr>";
    my($im,$bookdate,$fbd,$bookid,$cn,$cseq,
       $ca,$cb,$cby,$cdn,$obts,$pobts)=split '~',$_;

    print "<td>$row<td>$fbd<td>$bookid<td>$cn<td>$cseq";
    print "<td>$ca<td>$cb<td>$cby<td>$cdn<td>$obts<td>$pobts";
    $row++;
  }
  print "</table>";

  #-------------------------------------------------------------------------
  # sentence stuff
  $query = "select distinct InmateId,bookingdate, convert(varchar(10),".
    "bookingdate,101),bookingid,casenumber,chargesequence,".
      "convert(varchar(10),sentencedate,101),convert(varchar(10),".
	"sentencecompletedate,101),sentenceconsecutive,".
	  "sentencecourtcreditdays,sentencedays,sentencedeductdays,".
	    "sentencedescription,convert(varchar(10),sentenceenddate,101) ".
	      "from $view where InmateId='$inmate' ".
		"order by bookingdate desc, casenumber desc, chargesequence asc";
  @bookings = sqllist($query);
  $row=1;
  print "<table border=10><tr>";
  print "<td>&nbsp;<td>bookingdate<td>bookingid<td>casenumber<td>charge".
    "<br>sequence";
  print "<td>sentence<br>date<td>complete<td>consecutive<td>creditdays";
  print "<td>days<td>deductdays<td>description<td>enddate";
  foreach (@bookings) {
    print "<tr>";
    my($im,$bookdate,$fbd,$bookid,$cn,$cseq,
       $sd,$scd,$scon,$scrd,$days,$deddays,$desc,$end)=split '~',$_;

    print "<td>$row<td>$fbd<td>$bookid<td>$cn<td>$cseq";
    print "<td>$sd<td>$scd<td>$scon<td>$scrd<td>$days<td>$deddays<td>".
      "$desc<td>$end";
    $row++;
  }
  print "</table>";

  #-------------------------------------------------------------------------
  # sentence stuff
  $query = "select distinct InmateId,bookingdate, convert(varchar(10),".
    "bookingdate,101),bookingid,casenumber,chargesequence,".
      "sentencegaindays,sentencejudge,sentencemonths,sentencenetdays,".
	"sentenceyears,sentenceorder,".
	  "convert(varchar(10),sentencerevisiondate,101),".
	    "convert(varchar(10),sentencestartdate,101),".
	      "sentencerevisionnumber,".
		"convert(varchar(10),sentencestartoriginal,101),".
		  "sentencestatecreditdays ".
		    "from $view where InmateId='$inmate' ".
		      "order by bookingdate desc, casenumber desc, chargesequence asc";
  @bookings = sqllist($query);
  $row=1;
  print "<table border=10><tr>";
  print "<td>&nbsp;<td>bookingdate<td>bookingid<td>casenumber<td>charge".
    "<br>sequence";
  print "<td>gaindays<td>judge";
  print "<td>months<td>netdays<td>years<td>order";
  print "<td>revisiondate<td>startdate<td>revnumber<td>startoriginal<td>".
    "statecreditdays";
  foreach (@bookings) {
    print "<tr>";
    my($im,$bookdate,$fbd,$bookid,$cn,$cseq,
       $gaindays,$j,$m,$ndays,$y,$o,$rd,$ssd,$rn,$so,$scdays)=split '~',$_;

    print "<td>$row<td>$fbd<td>$bookid<td>$cn<td>$cseq";
    print "<td>$gaindays";
    print "<td>$j<td>$m<td>$ndays<td>$y<td>$o<td>$rd<td>$ssd<td>$rn".
      "<td>$so<td>$scdays";
    $row++;
  }
  print "</table>";


  #-------------------------------------------------------------------------
  # more stuff
  $query = "select distinct InmateId,bookingdate, convert(varchar(10),".
    "bookingdate,101),bookingid,casenumber,chargesequence,".
      "pouchnumber,usmarshalnumber,witness ".
	"from $view where InmateId='$inmate' ".
	  "order by bookingdate desc, casenumber desc, chargesequence asc";
  @bookings = sqllist($query);
  $row=1;
  print "<table border=10><tr>";
  print "<td>&nbsp;<td>bookingdate<td>bookingid<td>casenumber<td>charge".
    "<br>sequence";
  print "<td>pouchnumber<td>usmarshalnumber<td>witness";
  foreach (@bookings) {
    print "<tr>";
    my($im,$bookdate,$fbd,$bookid,$cn,$cseq,$p,$usm,$w)=split '~',$_;

    print "<td>$row<td>$fbd<td>$bookid<td>$cn<td>$cseq";
    print "<td>$p<td>$usm<td>$w";
    $row++;
  }
  print "</table>";


  # --------------------------------------------------

  $query = "select distinct InmateId,bookingdate, convert(varchar(10),".
    "bookingdate,101), bookingid,casenumber,chargesequence, ".
      "convert(varchar(10),releasedate,101),bondrequiredcheck,primarycharge,".
	"chargecode,chargecount,convert(varchar(10),chargedate,101),".
	  "chargedescription ".
	    "from $view where InmateId='$inmate' ".
	      "order by bookingdate desc, casenumber desc, chargesequence asc";
  @bookings = sqllist($query);
  $row=1;
  print "<table border=10><tr>";
  print "<td>&nbsp;<td>bookingdate<td>bookingid<td>casenumber<td>charge".
    "<br>sequence";
  print "<td>releasedate<td>bond<bt>required<br>check<td>primarycharge";
  print "<td>chargecode<td>chargecount<td>chargedate<td>chargedescription";
  foreach (@bookings) {
    print "<tr>";
    my($im,$bookdate,$fbd,$bookid,$cn,$cseq,
       $rd,$brc,$pc,$cc,$ccnt,$cd,$cdesc)=split '~',$_;
    print "<td>$row<td>$fbd<td>$bookid<td>$cn<td>$cseq";
    print "<td>$rd<td>$brc<td>$pc<td>$cc<td>$ccnt<td>$cd<td>$cdesc";
    $row++;
  }
  print "</table>";

  # --------------------------------------------------

  $query = "select distinct InmateId,bookingdate, convert(varchar(10),".
    "bookingdate,101),bookingid,casenumber,chargesequence,".
      "chargedispositionby,chargedispositioncode,chargedispositiondate,".
	"chargedispositiondesc,chargegroupselection,chargeprimary,".
	  "chargesequence ".
	    "from $view where InmateId='$inmate' ".
	      "order by bookingdate desc, casenumber desc, chargesequence asc";
  @bookings = sqllist($query);
  $row=1;
  print "<table border=10><tr>";
  print "<td>&nbsp;<td>bookingdate<td>bookingid<td>casenumber<td>charge<br>".
    "sequence";
  print "<td>charge<br>disposition<br>by<td>charge<br>disposition<br>code".
    "<td>date<td>dispdesc";
  print "<td>groupselection<td>chargeprimary<Td>chargesequence";
  foreach (@bookings) {
    print "<tr>";
    my($im,$bookdate,$fbd,$bookid,$cn,$cseq,
       $db,$dc,$dd,$ddesc,$gs,$cp,$cs)=split '~',$_;

    print "<td>$row<td>$fbd<td>$bookid<td>$cn<td>$cseq";
    print "<td>$db<td>$dc<td>$dd<td>$ddesc<td>$gs<td>$cp<td>$cs";
    $row++;
  }
  print "</table>";

  #--------------------------------------------
  dbdisconnect();
}

sub getBookingPhoto {
	my $photopath = shift;
	my $ua = shift;

	if ($photopath =~ /star.jpg$/) {
		return "/images/star.jpg";
	}

	my $imagebase = "$ENV{'JVS_DOCROOT'}/bookingimages";

	my @pieces = split(/Imacs_Images_5/,$photopath);

	if (!scalar(@pieces)) {
		return undef;
	}
	if (!defined($pieces[1])) {
		return undef;
	};
	my $filename = basename($pieces[1]);
	my $filedir = dirname($pieces[1]);

	my $targetDir = $imagebase . $filedir;
	if (!-d $targetDir) {
		make_path($targetDir, { mode => 0711 });
	}
	my $targetFile = "$targetDir/$filename";

	if (!-f $targetFile) {
		# Get the file and store it.
		if (!defined($ua)) {
			$ua = LWP::UserAgent->new;
		}

		my $req = HTTP::Request->new(
			GET => $photopath
		);
		my $res = $ua->request($req,$targetFile);
		if ($res->is_success) {
			return "/bookingimages" . $pieces[1];
		} else {
			return undef;
		}
	} else {
		# File already exists
		return "/bookingimages" . $pieces[1];
	}
}

sub getInmateIds {
	my $inmateids = shift;
	my $caseref = shift;
	my $dbh = shift;
	my $pbsodbh = shift;
	my $schema = shift;

	if (!defined($schema)) {
		$schema = $DEFAULT_SCHEMA
	};

	my @caselist;
	foreach my $case (@{$caseref}) {
		push (@caselist, "'$case->{'CaseNumber'}'");
	}

	my $inString = join(",", @caselist);

	# Build a list of the booking sheet numbers, keyed on the cases
	my $query = qq {
		select
			BookingSheetNumber,
			CaseNumber
		from
			$schema.vArrest with(nolock)
		where
			CaseNumber in ($inString);
	};
	my %temp;
	getData(\%temp,$query,$dbh,{ hashkey => "CaseNumber"});

	# We actually only want 1 per case
	foreach my $key (keys %temp) {
		$inmateids->{$key} = $temp{$key}[0];
	}

	# At this point, we have a hash, keyed on the case number, that contains
	# the booking sheet numbers.  Use those to get the inmate IDs from PBSO
	my @bsns;
	foreach my $case (keys %{$inmateids}) {
		push(@bsns,"'$inmateids->{$case}->{'BookingSheetNumber'}'");
	}

	$inString = join(",", @bsns);
	# Now we have an array of the booking sheet numbers.  Get the corresponding inmate IDs from PBSO
	$query = qq {
		select
			distinct InmateId,
			CaseNumber
		from
			$view
		where
			CaseNumber in ($inString)
	};
	my %ids;
	getData(\%ids,$query,$pbsodbh,{ hashkey => "CaseNumber"});

	# Ok, now we have a hash keyed on the booking sheet number.
	foreach my $case (keys %{$inmateids}) {
		my $bsn = $inmateids->{$case}->{'BookingSheetNumber'};
		$inmateids->{$case}->{'InmateId'} = $ids{$bsn}[0]->{'InmateId'};
	}
}


1;
