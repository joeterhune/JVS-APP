package PBSO2;

BEGIN {
    use lib "/usr/local/icms/bin";
}

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    getMugshotWithJacketId
    getInmateIdFromBooking
    getBookingHistory
);

use DB_Functions qw (
    dbConnect
    getData
    getDataOne
    $DEFAULT_SCHEMA
);

use Common qw (
    inArray
);

use File::Basename;

use File::Path qw {make_path};
use LWP::UserAgent;
use LWP::ConnCache;

# stay with this view after IMACS5 goes live
our $view="vw_PBSOQueryBookingInfo";

# for inmate photos (given to us 3/23/11)
our $ipview="IMACS_5_PBSO.dbo.objinmatephotos";

sub getMugshotWithJacketId {
    my $inmate = shift;
    my $dbh = shift;

    if (!defined($dbh)) {
        $dbh = dbConnect("pbso2");
    }

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
                    and front = 1
                    and activephoto = 1
                ), 'http://www.pbso.org/bkimages/star/star.jpg') as inmatephoto,
            AssignedCellId
        from
            $view
        where
            InmateId = ?
            and BookingDate=(
                select
                    max(BookingDate)
                from
                    $view
                where
                    InmateId = ?
            )
        order by
            BookingDate desc
    };

    my $inmateInfo = getDataOne($query, $dbh, [$inmate, $inmate]);

    my $jpg;
    my $incustody;

    # Get nt photo.
    if (defined($inmateInfo)) {
        # replace \ with / in jpg - should have been done with the database call!
        my $jpg = $inmateInfo->{'inmatephoto'};
        $jpg =~ s/\\/\//g;
        if ((!defined($inmateInfo->{'ReleaseDate'})) || ($inmateInfo->{'ReleaseDate'} eq '')) {
            $incustody='Yes';
            if ($inmateInfo->{'AssignedCellId'} eq 'ESCAPED') {
                $incustody='Escaped';
            } elsif ($inmateInfo->{'AssignedCellId'} eq 'WEEKENDER OUT') {
                $incustody='Weekender Out';
            } elsif ($inmateInfo->{'AssignedCellId'} eq 'IN-HOUSE ARREST') {
                $incustody='House Arrest';
            }
        } else {
            $incustody='No';
        }
        return ($jpg,$incustody);
    } else {
        return ('no pbso data found',undef);
    }
}



#
#  Get the inmate id (jacket number) for this case number.
#
sub getInmateIdFromBooking {
    my $casenumber = shift;
    my $dbh = shift;

    my $hadDBH = 1;
    if (!defined($dbh)) {
        $dbh = dbConnect("pbso2");
        $hadDBH = 0;
    }

    my $query = qq {
        select
            distinct InmateId
        from
            $view
        where
            CaseNumber = ?
    };

    my $inmateInfo = getDataOne($query,$dbh,[$casenumber]);

	if (!$hadDBH) {
		$dbh->disconnect;
	}

	if (defined($inmateInfo)) {
		return $inmateInfo->{'InmateId'};
	} else {
		return '';
	}
}


sub getBookingHistory {
    my $inmateID = shift;
    my $casenum = shift;
    my $bookingRef = shift;
    my $bookingNums = shift;
    my $dbh = shift;
    my $pbsodbh = shift;
    my $schema = shift;
	
	return if (!defined($inmateID));

	if (!defined($schema)) {
		$schema = $DEFAULT_SCHEMA
	};

	if (!defined($pbsodbh)) {
		$pbsodbh = dbConnect("pbso2");
	}

    $bookingRef->{'Bookings'} = {};

    my $query = qq {
		select
			distinct InmateId as InmateId,
			CONVERT(varchar,bookingdate,101) as BookingDate,
			CONVERT(varchar,bookingdate,101) as fBookingDate,
			BookingId,
            CONVERT(date,bookingdate,126) as sBookingDate,
			CONVERT(varchar,releasedate,101) as ReleaseDate,
			AgeAtBooking,
			substring(convert(varchar,HeightFeet),1,1) as HeightFeet,
			HeightInches,
			Weight,
            CASE (ISNULL(releasedate,-1))
                WHEN -1 THEN datediff(d,BookingDate,getdate())
                ELSE datediff(d,bookingdate,ReleaseDate)
            END as Served,
			casenumber as PBSOCaseNumber,
			CONVERT(varchar,carrestdate,101) as cArrestDate,
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
			InmateId = ?
        order by
            sBookingDate desc
	};

    my @charges;
    getData(\@charges, $query, $pbsodbh, { valref => [$inmateID]});

    my @pbsocases;

    foreach my $charge (@charges) {
        my $bookingID = $charge->{'BookingId'};
        if (!defined($bookingRef->{'Bookings'}->{$bookingID})) {
            $bookingRef->{'Bookings'}->{$bookingID} = {};
			$bookingRef->{'Bookings'}->{$bookingID}->{'PBSOCases'} = {};
        }
        my $pbsocase = $charge->{'PBSOCaseNumber'};

        if (!defined($bookingRef->{'Bookings'}->{$bookingID}->{'PBSOCases'}->{$pbsocase})) {
			$bookingRef->{'Bookings'}->{$bookingID}->{'PBSOCases'}->{$pbsocase} = {};
			foreach my $key (keys %{$charge}) {
				next if (inArray(["ChargeDescription","BookingId","PBSOCaseNumber"], $key));
				$bookingRef->{'Bookings'}->{$bookingID}->{$key} = $charge->{$key};
			}
			$bookingRef->{'Bookings'}->{$bookingID}->{'PBSOCases'}->{$pbsocase}->{'Charges'} = {};
            if (defined($charge->{'cArrestDate'})) {
                $bookingRef->{'Bookings'}->{$bookingID}->{'PBSOCases'}->{$pbsocase}->{'ArrestDate'} = $charge->{'cArrestDate'};
            } else {
                $bookingRef->{'Bookings'}->{$bookingID}->{'PBSOCases'}->{$pbsocase}->{'ArrestDate'} =
                    $bookingRef->{'Bookings'}->{$bookingID}->{'fBookingDate'};
            }

			# We'll need this later.
			push(@pbsocases,$pbsocase);
		}
        $bookingRef->{'Bookings'}->{$bookingID}->{'PBSOCases'}->{$pbsocase}->{'Charges'}->{$charge->{'ChargeSequence'}} =
            $charge->{'ChargeDescription'};
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
				and a.CaseID = c.CaseID
		};
		
		getData(\%icmscases,$query,$dbh,{hashkey => "PBSOCaseNumber", flatten => 1});
	}

    # Now look at the last booking and see if the inmate is still in custody
    my @bookingids = reverse sort { $a <=> $b }(keys %{$bookingRef->{'Bookings'}});

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

    $bookingRef->{'TotalServed'} = 0;

    foreach my $key (keys %{$bookingRef->{'Bookings'}}) {
        my $booking = $bookingRef->{'Bookings'}->{$key}->{'PBSOCases'};
        my $casetop = $bookingRef->{'Bookings'}->{$key};
        foreach my $pbsocase (keys %{$booking}) {
            $booking->{$pbsocase}->{'ICMSCase'} = {};
            $booking->{$pbsocase}->{'ICMSCase'}->{'CaseNumber'} = $icmscases{$pbsocase}->{'LegacyCaseFormat'};
            $booking->{$pbsocase}->{'ICMSCase'}->{'CaseStatus'} = $icmscases{$pbsocase}->{'CaseStatus'};
        }

        my $newpath = getBookingPhoto($casetop->{'InmatePhoto'},$ua);
        if (defined($newpath)) {
            $casetop->{'InmatePhoto'} = $newpath;
        }

        $bookingRef->{'TotalServed'} += $casetop->{'Served'};
    }

	if (scalar(@bookingids)) {
		if ((!defined($bookingRef->{'Bookings'}->{$bookingids[0]}->{'ReleaseDate'})) ||
            ($bookingRef->{'Bookings'}->{$bookingids[0]}->{'ReleaseDate'} eq '')) {
            $bookingRef->{'Custody'} = 'In PBSO Custody';
            $bookingRef->{'CustodyClass'} = 'incustody';

			my $cell = $bookingRef->{'Bookings'}->{$bookingids[0]}->{'AssignedCellId'};
			if ((defined ($cell)) && ($cell eq 'ESCAPED')) {
				$bookingRef->{'Custody'} = 'Escaped';
			} elsif ((defined ($cell)) && ($cell eq 'WEEKENDER OUT')) {
                $bookingRef->{'Custody'} = 'Weekender Out';
			} elsif ((defined ($cell)) && ($cell eq 'IN-HOUSE ARREST')) {
                $bookingRef->{'Custody'} = 'House Arrest';
			}
		} else {
			$bookingRef->{'Custody'} = "Not In PBSO Custody ";
			$bookingRef->{'CustodyClass'} = "";
		}
    }

    foreach my $bookingID (@bookingids) {
        push(@{$bookingNums}, $bookingID);
    }
}


sub getBookingPhoto {
    my $photopath = shift;
    my $ua = shift;

	if ($photopath =~ /star.jpg$/) {
		return "/images/star.jpg";
	}

	my $imagebase = "$ENV{'DOCUMENT_ROOT'}/bookingimages";

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

1;
