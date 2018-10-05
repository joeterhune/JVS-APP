#!/usr/bin/perl
#
#

package Banner;

require Exporter;

use strict;
use ICMS;
use File::Temp;
use Common qw(
    inArray
    dumpVar
    getArrayPieces
    ISO_date
    buildName
    US_date
    today
    sanitizeCaseNumber
    prettifyString
    escapeFields
    doTemplate
    returnJson
    convertCaseNumber
);
use Images qw(
    createPDF
    getDocketList
);
use DB_Functions qw (
    inGroup
    dbConnect
    getData
    getDataOne
    doQuery
    @SECRETTYPES
    ldapConnect
    getWatchList
    getVrbEventsByCase
    getQueueItems
);

use Data::Dumper qw(Dumper);

#use Casenotes qw (
#    getFlags
#	getNotes
#);

use EService qw(
	getAttorneyAddresses
	getProSeAddresses
);

use File::Basename;
use Switch;
use Date::Calc qw (
    Add_Delta_Days
);

our @ISA=qw(Exporter);
our @EXPORT;
our @EXPORT_OK=qw(
    $ACTIVE
    $NOTACTIVE
    $partyTypeString
    @attorneyTypes
    $otherCaseMax
    bannerSearch
    buildPhone
    casenumtoucn
    getDocketItems
    buildImageList
    lookupMailingAddress
    buildAddress
    buildStyles
    getCaseDocket
    getExtCaseId
    getFees
    getLinkedCases
    getWarrants
    getCharges
    getEvents
    getOLSEvents
    getDockets
    getOtherCases
    getPropertyAddress
    getBannerCaseInfo
    getParties
    casenumtoucn
    getjudgename
    getjudgedivfromdiv
    bannerGetDocketItems
);
use Carp qw(cluck);

BEGIN {
    $ENV{HTTPS_CERT_FILE} = '/var/www/html/case/vcp02xweb_lms.pem';
}

# When we're showing other cases, don't show them if the party has more than this number
# of cases
our $otherCaseMax = 100;

our @attorneyTypes=(
					"'AAG'",
					"'ADJJ'",
					"'AFCP'",
					"'AGAL'",
					"'APD'",
					"'ASA'",
					"'ATTY'",
					"'CAAT'",
					"'CTAP'",
					"'CWLS'"
					);

our $partyTypeString = "(select ctrptyp_code from ctrptyp)";

my $activePhrase = qq {
	and nvl(SRS_STATUS_CODE(cdbcase_id),'none') not in $INACTIVECODES
};
my $excludeSealed = qq {(cdbcase_sealed_ind <> 3)};
my $showjSealed = qq {(cdbcase_ctyp_code in ('CJ','DP'))};
my $excludeSecret = qq {
	and cdbcase_ctyp_code not in (} .
	join(",", @SECRETTYPES) . qq {)
};

my $criminalPhrase = qq {
	and cdbcase_cort_code in (} .
	join(",", @CRIMCODES) . qq {)
};


sub casenumtoucn {
    my($casenum)=@_;
    my $x=substr($casenum,0,4)."-".substr($casenum,4,2)."-".
	substr($casenum,6,6);
    if (substr($casenum,12,1) ne "") { $x.="-".substr($casenum,12); }
    return $x;
}

# get the judge name from spriden using the judge's pidm
sub getjudgename {
    my $judge = shift;
	my $dbh = shift;

    if ((!defined($judge)) || ($judge eq "")) {
		return "";
	}
    my $query = qq{
		select
			spriden_id,
			spriden_last_name as "LastName",
			spriden_first_name as "FirstName",
			spriden_mi as "MiddleName"
		from
			spriden
		where
			spriden_pidm = ?
			and spriden_change_ind is null
	};

	my $judgeinfo = getDataOne($query,$dbh,[$judge]);
	if (defined($judgeinfo->{'FirstName'})) {
		$judgeinfo->{'FirstName'} =~ s/^JUDGE\s+//g;
	}
	my $judgename = buildName($judgeinfo);
	return $judgename;
    #my @list2 = list($query);
    #my($div,$last,$first,$mi)=split '~',$list2[0];
    #$first=~s/JUDGE//;
    #return "$first $mi $last";
}

# get the judge name for this particular division
sub getjudgedivfromdiv {
    my $thisdiv = shift;
	my $dbh = shift;

    my $query = qq{
		select
			spriden_id as "SpridenID",
			spriden_last_name as "LastName",
			spriden_first_name as "FirstName",
			spriden_mi as "MiddleName"
		from
			spriden
		where
			spriden_id = ?
			and spriden_change_ind is null
		order by
			spriden_change_ind desc
	};

	my $judgename = getDataOne($query,$dbh,[$thisdiv]);
    #my @list2 = sqllist($query);
    #my($div,$last,$first,$mi,$newid)=split '~',$list2[0];
    $judgename->{'FirstName'} =~ s/JUDGE/HON./;

	# Strip leading/trailing whitespace from name pieces
	foreach my $field (['FirstName','MiddleName','LastName']) {
        next if (!defined($judgename->{$field}));
		$judgename->{$field} =~ s/^\s+//g;
		$judgename->{$field} =~ s/\s+$//g;
	}
	my $name;
	if ((defined($judgename->{'MiddleName'})) && ($judgename->{'MiddleName'} ne '')) {
		$name = sprintf("%s %s %s", $judgename->{'FirstName'}, $judgename->{'MiddleName'},$judgename->{'LastName'});
	} else {
		$name = sprintf("%s %s", $judgename->{'FirstName'}, $judgename->{'LastName'});
	}
    return $name;
}


sub lookupMailingAddress {
	# Looks up mailing address(es) for party.  If $addressType isn't specified, then it will return
	# the MA type address, is specified; if not, returns BU, then RE.

	# If $addressRef is a hash ref, then it will build the appropriate string and populate the hashj
	# element (based on the PIDM) with that string.  If it's an array ref, then it will simply
	# push all of the addresses onto the array and allow the caller to deal with it.
	my $addressRef = shift;
	my $pidm = shift;
	my $dbh = shift;
	my $addressType = shift;
	my $partyId = shift;

	if (!defined($dbh)) {
		$dbh = dbConnect("wpb-banner-rpt");
	}

	my @valref = ($pidm);

    my $query = qq {
		select
			spraddr_pidm as "PIDM",
			NVL(spraddr_strt_no,' ') as "StreetNumber",
			NVL(spraddr_strt_frct,' ') as "Direction",
			NVL(spraddr_strt_pda,' ') as "PDA",
			NVL(spraddr_strt_name,' ') as "StreetName",
			NVL(spraddr_strt_sufa,' ') as "Suffix",
			NVL(spraddr_strt_poda,' ') as "PODA",
			NVL(spraddr_sec_ada,' ') as "SecAddress",
			NVL(spraddr_sec_add_unit,' ') as "Unit",
			NVL(spraddr_bldf_sec_name,' ') as "SecName",
			spraddr_city as "City",
			spraddr_stat_code as "State",
			spraddr_zip as "Zip",
			spraddr_atyp_code as "AddrType",
			spraddr_activity_date as "AddrDate",
			spraddr_phone_area as "SpraddrAreaCode",
			spraddr_phone_number as "SpraddrPhoneNumber",
			sprtele_phone_area as "SprteleAreaCode",
			sprtele_phone_number as "SprtelePhoneNumber",
			CASE 
				WHEN cprconf_addr_seqno is null THEN 0
				ELSE 1
			END as "Confidential"
		from
			spraddr left outer join sprtele on (spraddr_pidm = sprtele_pidm) left outer join cprconf on (spraddr_pidm=cprconf_pidm)
		where
			spraddr_pidm = ?
			and spraddr_status_ind is null
			and spraddr_to_date is null
	};
	if (!defined($addressType)) {
		$query .= qq { and spraddr_atyp_code in ('MA','BU','RE','AL')};
	} else {
		$query .= qq { and spraddr_atyp_code = ? };
		# Need the type on the valref array
		push(@valref,$addressType);
	}
	$query .= qq {
		order by
			spraddr_seqno desc
	};

	my @addresses;
	getData(\@addresses,$query,$dbh, {valref => \@valref});
	
	if (!scalar(@addresses)) {
		return;
	}


	if (ref($addressRef) eq "HASH") {
		# Keyed on the PIDM.  We only want 1 address.  Preference is for mailing address, then
		# business address, then residential
		my $hasMA = 0;
		my $hasBU = 0;
		my $hasRE = 0;
		my $thisAddr;
		foreach my $address (@addresses) {
			switch ($address->{'AddrType'}) {
				case 'MA'	{
					$hasMA = 1;
					$thisAddr = $address;
					last;
				}
				case 'BU'	{
					$hasBU = 1;
					$thisAddr = $address;
					next;
				}
				case 'RE' {
					$hasRE = 1;
					if (!$hasBU) {
						$thisAddr = $address;
					}
					next;
				}
				else 		{
					if (!$hasRE) {
						# Don't stomp on a business address.  We won't be here if
						# we've found an MA address
						$thisAddr = $address;
					}
					next;
				}
			}
		}

		# Now we know which is the highest.  Build the string
		my $line1 = sprintf("%s %s %s %s %s %s", $thisAddr->{'StreetNumber'},
							$thisAddr->{'Direction'},
							$thisAddr->{'PDA'}, $thisAddr->{'StreetName'}, $thisAddr->{'Suffix'},
							$thisAddr->{'PODA'});
		$line1 =~ s/^\s+//g;
		$line1 =~ s/\s+$//g;
		$line1 =~ s/\s+/ /g;

		my $line2 = sprintf("%s %s %s", $thisAddr->{'SecAddress'}, $thisAddr->{'Unit'},
							$thisAddr->{'SecName'});
		$line2 =~ s/^\s+//g;
		$line2 =~ s/\s+$//g;
		$line2 =~ s/\s+/ /g;

		my %addr;

		$addressRef->{$partyId}->{'Address1'} = $line1;
		$addressRef->{$partyId}->{'Address2'} = $line2;

		if ($line2 =~ /^$/) {
			$addressRef->{$partyId}->{'StreetAddress'} = $line1;
		} else {
			$addressRef->{$partyId}->{'StreetAddress'} = sprintf ("%s\n%s", $line1, $line2);
		}
		$addressRef->{$partyId}->{'StreetAddress'} =~ s/^\s+//g;
		$addressRef->{$partyId}->{'StreetAddress'} =~ s/\s+$//g;
		$addressRef->{$partyId}->{'StreetAddress'} =~ s/\s+/ /g;
		$addressRef->{$partyId}->{'City'} = $thisAddr->{'City'};
		$addressRef->{$partyId}->{'State'} = $thisAddr->{'State'};
		$addressRef->{$partyId}->{'Zip'} = $thisAddr->{'Zip'};
		$addressRef->{$partyId}->{'AddrDate'} = ISO_date($thisAddr->{'AddrDate'});
		$addressRef->{$partyId}->{'Confidential'} = $thisAddr->{'Confidential'};

		# Do we have a phone number?
		if (defined($thisAddr->{'SpraddrAreaCode'})) {
			$addressRef->{$partyId}->{'AreaCode'} = $thisAddr->{'SpraddrAreaCode'};
			$addressRef->{$partyId}->{'PhoneNumber'} = $thisAddr->{'SpraddrPhoneNumber'};
		} elsif (defined($thisAddr->{'SprteleAreaCode'})) {
			$addressRef->{$partyId}->{'AreaCode'} = $thisAddr->{'SprteleAreaCode'};
			$addressRef->{$partyId}->{'PhoneNumber'} = $thisAddr->{'SprtelePhoneNumber'};
		} else {
			$addressRef->{$partyId}->{'AreaCode'} = "";
			$addressRef->{$partyId}->{'PhoneNumber'} = "";
		}
	} elsif (ref($addressRef) eq "ARRAY") {
		# Push all of the addresses onto the array
		push(@{$addressRef}, @addresses)
	}
}


# pass the pidm of the party
# could be in either spraddr or sprtele table
sub buildPhone {
    my $id = shift;
	my $dbh = shift;
    my $phone = "&nbsp;";

    my $query = qq{
		select
			spraddr_phone_area as "AreaCode",
			spraddr_phone_number as "PhoneNumber",
			spraddr_phone_ext as "PhoneExtension",
			cprconf_addr_seqno as "ConfSeq"
		from
			spraddr left outer join cprconf on spraddr_seqno=cprconf_addr_seqno
		where
			spraddr_pidm = ?
			and spraddr_status_ind is null
		order by
			spraddr_seqno desc
	};

	my $phoneInfo = getDataOne($query,$dbh,[$id]);

    if ((defined($phoneInfo->{'PhoneNumber'})) && (length($phoneInfo->{'PhoneNumber'}) ne 0)) {
		if ((defined($phoneInfo->{'AreaCode'})) && ($phoneInfo->{'AreaCode'} ne "")) {
			$phone="(".$phoneInfo->{'AreaCode'}.") ";
		}

		if ((defined($phoneInfo->{'PhoneNumber'})) && ($phoneInfo->{'PhoneNumber'} =~ /(\d\d\d)(\d\d\d\d)/)) {
			$phone .= sprintf("%s-%s", $1, $2);
		} elsif (defined($phoneInfo->{'PhoneNumber'})) {
			$phone .= $phoneInfo->{'PhoneNumber'}
		}

		if((defined($phoneInfo->{'PhoneExtension'})) && ($phoneInfo->{'PhoneExtension'} ne "")) {
		    $phone.=" ext. $phoneInfo->{PhoneExtension}";
		}
    } else { # try other table
		$query = qq{
			select
				sprtele_phone_area as "AreaCode",
				sprtele_phone_number as "PhoneNumber",
				sprtele_phone_ext as "PhoneExtension"
			from
				sprtele
			where
				sprtele_pidm = ?
				and sprtele_primary_ind = 'Y'
				and sprtele_tele_code <> 'FAX'
				and sprtele_status_ind is null
			order by
				sprtele_seqno desc
		};

		$phoneInfo = getDataOne($query,$dbh,[$id]);

		if ((defined($phoneInfo->{'PhoneNumber'})) && (length($phoneInfo->{'PhoneNumber'}) ne 0)) {
			if ((defined($phoneInfo->{'AreaCode'})) && ($phoneInfo->{'AreaCode'} ne "")) {
				$phone="(".$phoneInfo->{'AreaCode'}.") ";
			}

			if ((defined($phoneInfo->{'PhoneNumber'})) && ($phoneInfo->{'PhoneNumber'} =~ /(\d\d\d)(\d\d\d\d)/)) {
				$phone .= sprintf("%s-%s", $1, $2);
			} elsif (defined($phoneInfo->{'PhoneNumber'})) {
				$phone .= $phoneInfo->{'PhoneNumber'}
			}

			if((defined($phoneInfo->{'PhoneExtension'})) && ($phoneInfo->{'PhoneExtension'} ne "")) {
			    $phone.=" ext. $phoneInfo->{PhoneExtension}";
			}
		}
	}
    return $phone;
}

sub bannerSearch {
	my $fieldref = shift;
	my $caseref = shift;
    
	my @charges;
	my $query;
    
    my $sancasenum = sanitizeCaseNumber($fieldref->{'name'});
	
	my $dbh = dbConnect("wpb-banner-prod");
	$dbh->do("alter session set nls_date_format='MM/DD/YYYY'");

	# Temp storage for data
	my $temp = [];

	my $divLimitSearch = "";
    if (defined($fieldref->{'limitdiv'})) {
		my $inString = join(",", @{$fieldref->{'limitdiv'}});
        $divLimitSearch = "and cdbcase_division_id in ($inString) ";
    }
    my $causeSearch = "";
    if (defined($fieldref->{'causetype'})) {
		my $inString = join(",", @{$fieldref->{'causetype'}});
        $divLimitSearch = "and cdbcase_ctyp_code in ($inString) ";
    }

	# Start building the query.
	# Is it a name search?
	if ($fieldref->{'namesearch'}) {
		# Indeed it is.

		# Why am I enclosing the field names in double quotes?  So I can
		# force them to match the fields that will eventually be selected
		# from Showcase, which doesn't automatically force everything
		# in the data dictionary to UPPERCASE, like Oracle does.  It'll make
		# things much cleaner in the end.

		my $nameQuery = qq {
			select
				spriden_last_name as "LastName",
				spriden_first_name as "FirstName",
				spriden_mi as "MiddleName",
				spriden_pidm as pidm,
				cdrcpty_case_id as "CaseNumber",
				cdbcase_init_filing as "FileDate",
				NVL(cdbcase_ctyp_code, '&nbsp;') as "CaseType",
				SRS_STATUS_CODE(cdbcase_id) as "CaseStatus",
				ctrptyp_desc as "PartyTypeDescription",
				NVL(to_char(spbpers_birth_date), '&nbsp;') as "DOB",
				NVL(cdbcase_division_id,'&nbsp;') as "DivisionID"
		};

		# Need to exclude Showcase case types, too
		my $excludecodes = "(" . join(",", @SCCODES) . ")";
		my $from = qq {
			from
				cdbcase,
				cdrcpty,
				ctrptyp,
				spriden left outer join spbpers on spriden_pidm=spbpers_pidm
			where
				cdrcpty_pidm=spriden_pidm
				and cdrcpty_ptyp_code=ctrptyp_code
				and cdrcpty_case_id=cdbcase_id
				and spriden_change_ind is null
				and cdbcase_cort_code not in $excludecodes
				$divLimitSearch $causeSearch
		};

		if ($fieldref->{'searchtype'} eq 'attorney') {
			my $attyTypeString = "(" . join(",", @attorneyTypes) . ")";
			$from .= qq {
				and cdrcpty_ptyp_code in $attyTypeString
			};
		} elsif ($fieldref->{'searchtype'} eq 'defendant') {
			$from .= qq {
				and cdrcpty_ptyp_code ='DFT'
			};
        } elsif ($fieldref->{'searchtype'} eq 'others') {
            my $pts = join(",", @{$fieldref->{'partyTypeLimit'}});
            $from .= qq {
                and cdrcpty_ptyp_code in ($pts)
            }
		} else {
			$from .= qq{
				and cdrcpty_ptyp_code in $partyTypeString
			};
		}
		
		if (defined($fieldref->{'DOB'})) {
            if ((defined($fieldref->{'fuzzyDOB'})) && ($fieldref->{'fuzzyDOB'})) {
                # A fuzzy DOB! get a 30-day range - 15 days before and 15 days after.
                my ($year, $month, $day) = split(/-/, $fieldref->{'DOB'});
                my ($syear, $smonth, $sday) = Add_Delta_Days($year, $month, $day, -15);
                my $sdate = sprintf("%04d-%02d-%02d", $syear, $smonth, $sday);
                my ($eyear, $emonth, $eday) = Add_Delta_Days($year, $month, $day, 15);
                my $edate = sprintf("%04d-%02d-%02d", $eyear, $emonth, $eday);
                $from .= qq {
                    and spbpers_birth_date between to_date('$sdate','YYYY-MM-DD') and to_date('$edate','YYYY-MM-DD')
                };
            } else {
                $from .= qq {
                    and spbpers_birth_date = to_date('$fieldref->{DOB}','YYYY-MM-DD')
                };   
            }
		}
        
        if (defined($fieldref->{'searchStart'})) {
            if (!defined($fieldref->{'searchEnd'})) {
                $fieldref->{'searchEnd'} = ISO_date(today());
            }
            $from .= qq {
                and cdbcase_init_filing between TO_DATE('$fieldref->{searchStart}','YYYY-MM-DD') and TO_DATE('$fieldref->{searchEnd}','YYYY-MM-DD')
            }
        }

		my $nameOrderBy = qq {
			order by
				spriden_last_name,
				spriden_first_name,
				spriden_mi,
				cdrcpty_case_id
		};

		if ($fieldref->{'nametype'} eq "firstandlast") {
			if (defined($fieldref->{'last2'})) {
				# This is only defined in the case of a wildcard search
				if (length($fieldref->{'last2'}) < 1) {
					# Search all last names
					if ($fieldref->{'soundex'} == 1) {
						$query = $from . qq {
							and spriden_soundex_first_name = soundex ('$fieldref->{first}%')
						};
					} else {
						$query = $from . qq {
							and spriden_first_name like '$fieldref->{first}%'
						};
					}
				} else {
					if ($fieldref->{'soundex'} == 1) {
						$query = $from . qq {
							and spriden_soundex_last_name = soundex('$fieldref->{last2}%')
							and spriden_soundex_first_name = soundex('$fieldref->{first}%')
						};
					} else {
						$query = $from . qq {
							and spriden_last_name like '$fieldref->{last2}%'
							and spriden_first_name like '$fieldref->{first}%'
						};
					}
				}
			} else {
				if ($fieldref->{'soundex'} == 1) {
					$query = $from . qq {
						and spriden_soundex_last_name = soundex('$fieldref->{last}%')
						and spriden_soundex_first_name = soundex('$fieldref->{first}%')
					};
				} else {
					$query = $from . qq {
						and spriden_last_name = '$fieldref->{last}'
						and spriden_first_name like '$fieldref->{first}%'
					};
				}
			}
			# End of firstlast Search
		} else {
			if(defined($fieldref->{'name2'})) {
				if ($fieldref->{'soundex'} == 1) {
					$query = $from . qq {
						and spriden_soundex_last_name = soundex('$fieldref->{name2}%')
					};
				} else {
					$query = $from . qq {
						and spriden_last_name like '$fieldref->{name2}%'
					};
				}
			} else {
				if ($fieldref->{'soundex'} == 1) {
					$query = $from . qq {
						and spriden_soundex_last_name = soundex('$fieldref->{name}')
					};
				} else {
					$query = $from . qq {
						and spriden_last_name = '$fieldref->{name}'
					};
				}
			}

			if ($fieldref->{'business'} == 1) {
				$query .= qq {
					and spriden_first_name is null
				};
			}
		}

		if ($fieldref->{'active'} == 1) {
			$query .= $activePhrase;
		}

		if ($fieldref->{'criminal'} == 1) {
			$query .= $criminalPhrase;
		}

		my @exclusions;
		if (!($fieldref->{'sealeduser'})) {
			push(@exclusions,$excludeSealed);
		}

		if ($fieldref->{'jsealeduser'}) {
			push(@exclusions,$showjSealed);
		}

		if (scalar(@exclusions)) {
			$query .= "and (" . join (" or ", @exclusions) . ")";
		}

		if (!($fieldref->{'secretuser'})) {
			$query .= $excludeSecret;
		}

		$query .= $nameOrderBy;
        
		getData($temp, "$nameQuery $query", $dbh);
     	
		# Check for rogue appeals cases that should be coming out of Showcase.
		foreach my $case (@{$temp}) {
			my $cn = $case->{'CaseNumber'};
			my ($year,$type,$seq) = ($cn =~ /(\d+)(\D+)(\d+)/);
			if (($type eq "AP") && ($seq =~ /^9/)) {
				# This is a criminal appeal. Drop it here and get it from Showcase.
				undef $case;
			}
		}
    } elsif (defined($sancasenum)) {
        #
		# Case Number Search
		#

		# looking for exact match.
		# try query first to make sure the record exists (with correct
		# "active" phrase) before redirecting to bannerview. (before,
		# went directly to bannerview.)

		my $casenum = $sancasenum;

		# If we can determine that this is a criminal case, short-circuit this
		# evaluation and move along.
		my $courtcode = (split(/-/,$casenum))[1];
		if (inArray(\@SCCODES,"'$courtcode'")) {
			return;
		}

		if ($courtcode eq "AP"){
			# It's an appeal. Is it a 9-series sequence?
			my $seq = (split(/-/,$casenum))[2];
			if ($seq =~ /^9/) {
				# Criminal appeal.  Don't want what we'll find here.
				return;
			}
		}

        my $ucn = $casenum;
		$casenum =~ s/-//g;
		
		$query = qq {
			select
				*
			from
				cdbcase
			where
				cdbcase_id='$casenum'
		};

		if ($fieldref->{'active'} == 1) {
			$query .= $activePhrase;
		}

		if ($fieldref->{'criminal'} == 1) {
			$query .= $criminalPhrase;
		}

		my @exclusions;
		if (!($fieldref->{'sealeduser'})) {
			push(@exclusions,$excludeSealed);
		}

		if ($fieldref->{'jsealeduser'}) {
			push(@exclusions,$showjSealed);
		}

		if (scalar(@exclusions)) {
			$query .= "and (" . join (" or ", @exclusions) . ")";
		}

		if (!($fieldref->{'secretuser'})) {
            $query .= $excludeSecret;
		}
		
		getData($temp, $query, $dbh);

		if (!scalar(@{$temp})) {
            # No matches were found - try with an appended "XX"
            my $newcase = $casenum . "XX";
            $query =~ s/$casenum/$newcase/;
			getData($temp, $query, $dbh);
		}
        
		if (scalar(@{$temp}) == 1) {
            # We have a single match.  Redirect to bannerview.
            my $c = $temp->[0]->{'CDBCASE_ID'};
			my $output = getBannerCaseInfo($c);
            my %result;
            $result{'status'} = 'Success';
            $result{'tab'} = sprintf('case-%s', $c);
            $result{'html'} = $output;
            $result{'tabname'} = $c;
            
            returnJson(\%result);
            exit;
		}
	} elsif ($fieldref->{'name'}=~/(\d+)(\D+)(\d+)(\*)/ ||
			 $fieldref->{'name'}=~/(\d+)(\D+)(\d+)(\D+){0,3}/ ) {
		my ($year, $type, $seq, $suffix);

		my $casenum;
		my $ucn;

		if ($fieldref->{'name'}=~/(\d+)(\D+)(\d+)(\*)/) {
			# Searches for yyyyttd* (no zero padding here!!)
			# Wildcard search on case number - yyyyttd*
			$year = $1;
			$type = $2;
			$seq = $3;

			# If we can determine that this is a criminal case, short-circuit this
			# evaluation and move along.
			my $courtcode = (split(/-/,$casenum))[1];
			if (inArray(\@SCCODES,"'$type'")) {
				return;
			}

			if (($type eq "AP") && ($seq =~ /^9/)) {
				# Criminal appeal.  Don't want what we'll find here.
				return;
			}

			$year = fixyear($year);
			# Be sure to convert to uppercase
			$casenum = uc(sprintf("%04d%s%s%s",$year,$type,$seq,$suffix));
			if ($suffix ne "") {
				$ucn = uc(sprintf("%04d-%s-%s-%s",$year,$type,$seq,$suffix));
			} else {
				$ucn = uc(sprintf("%04d-%s-%s",$year,$type,$seq));
			}
		} else {
			# Not a wildcard

			$year = $1;
			$type = $2;
			$seq = $3;

			if (($type eq "AP") && ($seq =~ /^9/)) {
				# Criminal appeal.  Don't want what we'll find here.
				return;
			}

			# If we can determine that this is a criminal case, short-circuit
			# this evaluation and move along.
			my $courtcode = (split(/-/,$fieldref->{'name'}))[1];
			if (inArray(\@SCCODES,"'$type'")) {
				return;
			}

			$year = fixyear($year);
			# No padding with leading zeroes here!
			# Be sure to convert them to uppercase
			$casenum = uc(sprintf("%04d%s%06d", $year, $type, $seq));
			$ucn = uc(sprintf("%04d-%s-%06d", $year, $type, $seq)) . "*";
		}

		$query = qq {
			from
				cdbcase
			where
				cdbcase_id like '$casenum%'
		};

		if ($fieldref->{'active'} == 1) {
			$query .= $activePhrase;
		}

		if ($fieldref->{'criminal'} == 1) {
			$query .= $criminalPhrase;
		}

		my @exclusions;
		if (!($fieldref->{'sealeduser'})) {
			push(@exclusions,$excludeSealed);
		}

		if ($fieldref->{'jsealeduser'}) {
			push(@exclusions,$showjSealed);
		}

		if (scalar(@exclusions)) {
			$query .= "and (" . join (" or ", @exclusions) . ")";
		}

		if (!($fieldref->{'secretuser'})){
			$query .= $excludeSecret;
		}

		my $dbh = dbConnect("wpb-banner-prod");
		doQuery("alter session set nls_date_format='MM/DD/YYYY'", $dbh);
		my $dquery = "select cdbcase_id " . $query;
		
		getData($temp,$dquery,$dbh);

		if (scalar(@{$temp}) == 1) {
			$ucn = casenumtoucn($temp->[0]->{'CDBCASE_ID'});
            my $output = getBannerCaseInfo($ucn);
            my %result;
            $result{'status'} = 'Success';
            $result{'tab'} = sprintf('case-%s', $ucn);
            $result{'html'} = $output;
            $result{'tabname'} = $ucn;
            
            returnJson(\%result);
            exit;
		} else {
			$query = qq {
				select
					cdbcase_desc as "LastName",
					'' as first,
					'' as mi,
					'' as pidm,
					cdbcase_id as "CaseNumber",
					cdbcase_init_filing as "FileDate",
					cdbcase_ctyp_code as "CaseType",
					SRS_STATUS_CODE(cdbcase_id) as "CaseStatus",
					'' as pdesc,
					'' as "DOB",
					cdbcase_division_id as "DivisionID"
				from
					cdbcase
				where
					cdbcase_id like '$casenum%'
			};

			if ($fieldref->{'active'} == 1) {
				$query .= $activePhrase;
			}

			if ($fieldref->{'criminal'} == 1) {
				$query .= $criminalPhrase;
			}

			my @exclusions;
			if (!($fieldref->{'sealeduser'})) {
				push(@exclusions,$excludeSealed);
			}

			if ($fieldref->{'jsealeduser'}) {
				push(@exclusions,$showjSealed);
			}

			if (scalar(@exclusions)) {
				$query .= "and (" . join (" or ", @exclusions) . ")";
			}

			if (!($fieldref->{'secretuser'})) {
				$query .= $excludeSecret;
			}

			$query .= "order by cdbcase_id";
			getData($temp, $query, $dbh);
		}
	} elsif ($fieldref->{citationsearch}) {
		print "Need to do a citation search!!!";
		exit;
	} else {
		print "Content-type: text/html\n\n";
		print "Wrong format used for the name or case number - couldn't ".
			"understand '$fieldref->{'name'}.<p>\n";
		exit;
	}

    foreach my $case (@{$temp}) {
		next if ($case->{CaseNumber} eq "");
		$case->{'AGE'} = getageinyears($case->{'DOB'});
		
		$case->{'UCN'} = casenumtoucn($case->{'CaseNumber'});
		$case->{'CaseNumber'} = $case->{'UCN'};
		$case->{'StripCase'} = $case->{'UCN'};
		$case->{'StripCase'} =~ s/-//g;

		# Populate the full name at this time, if it exists.  We'll need
		# it later.
		if ($fieldref->{'namesearch'}) {
            $case->{'Name'} = buildName($case,1);
			#$case->{'Name'} = "$case->{LastName}, $case->{FirstName}";
			#if ($case->{'MiddleName'} ne "") {
			#	$case->{'Name'} .= " $case->{MiddleName}";
			#}
		}

		# Get the last activity date for the case
		my $aquery = qq {
			select
				NVL(to_char(max(cdrdoct_filing_date)),'&nbsp;') as "LastActivity"
			from
				cdrdoct
			where
				cdrdoct_case_id = ?
		};

		my $lastAct = getDataOne($aquery, $dbh, [$case->{StripCase}]);
		$case->{'LACTIVITY'} = $lastAct->{'LastActivity'};
		
		# Get charge information for this case

		my @charges;
		if (($fieldref->{'charges'} == 1) && ($case->{'UCN'} =~ /CJ/)) {
			$query = qq {
				select
					cdrccpt_desc as "CourtStatuteDescription"
				from
					cdrccpt
				where
					cdrccpt_case_id = ?
					and cdrccpt_maint_code is null
			};

			getData(\@charges, $query, $dbh, {valref => [$case->{StripCase}]});
			$case->{'Charges'} = \@charges;
			if (scalar(@charges)) {
				$fieldref->{'hadCharges'} = 1;
			}
			
		}

		# Is it a juvenile case?
		if ($case->{'UCN'} =~ /DP|CJ|JD|JJ/) {
			$case->{'UCN'} .= ";juv/view.cgi";
		}

		# And add it to the "final" array
		push(@{$caseref}, $case);
	}
}

sub bannerGetDocketItems {
    my $ucn = getDocketItems(@_);
    
    return $ucn;
}


sub getDocketItems {
	# Get a list of docket items (not the images - just a list)

	# A reference to an existing CGI object - we need information on the
	# parameters
    my $info = shift;
    
    my %params = $info->Vars;
    
	# A reference to the information on each object
	my $docketList = shift;
    
    my $dbh = shift;
    if (!defined($dbh)) {
        $dbh = dbConnect("wpb-banner-prod");
    }
    
    # Subselect strings to be used for selecting appropriate
	# rows from both Banner and Images
	my $bannerSelStr = "";
    my $cmsDocSelect = "";
    my $ucn;
    my @objids;
    
    if (!(defined($params{'showmulti'}))) {
        # Request for a single image
        my $objid;
        if (defined($params{'ucnobj'})) {
            my $ucnobj = $params{'ucnobj'};
            ($ucn,$objid) = split(/\|/,$ucnobj);
        } else {
            $ucn = $params{'ucn'};
            $objid = $params{'objid'};
        }
        
        push(@objids,$objid);
        $cmsDocSelect = "object_id = $objid ";
    } else {
        # Request for multiple checked images
        my @selected = $info->param("selected");
        if (!scalar(@selected)) {
            print $info->header();
            print "No docket items were selected.  Please try again.";
            exit;
        }
        
        my $objid;
        foreach my $item (@selected) {
            ($ucn, $objid) = split(/\|/, $item);
            push(@objids,"$objid");
        }
        $ucn =~ s/-//g;
        $cmsDocSelect = " object_id in (" . join(",", @objids) .") ";
    }
    
    print $info->header;
    
    
    if (!scalar(@objids)) {
        print $info->header;
        
    }
    
    my $count = 0;
    my $perQuery = 100;
    
    # We need to take all of these object IDs and get their sequence numbers, and then look up those sequences
    # in Banner to get the name and stuff for the doc
    my $bobdbh = dbConnect("wpb-images");
    
    #print $info->header;
    my @docketItems;
    while ($count < scalar(@objids)) {
        my $temp = [];
        getArrayPieces(\@objids, $count, $perQuery, $temp, 0);
        
        my $inString = join(",", @{$temp});
        
        my $query = qq {
            select
                cms_document_id as "cms_document_id",
                object_id as "ObjectId"
            from
                dbotr.edocument
            where
                object_id in ($inString)
        };
        
        my %ids;
        getData(\%ids, $query, $bobdbh, {hashkey => "cms_document_id", flatten => 1});
        
        # For each of these, look up information on the document from Banner
        my @bannerSeqs;
        foreach my $docid (keys %ids) {
            my ($casenum, $seq) = split(/\|/, $docid);
            push(@bannerSeqs, $seq);
        }
        
        $inString = join(",", @bannerSeqs);
        $bannerSelStr = " and cdrdoct_seq_no in ($inString)";
        
        $query = qq {
            select
                cdrdoct_case_id as "CaseNumber",
                ctrdtyp_desc as "DocketDescription",
                cdrdoct_filing_date as "EffectiveDate",
                cdrdoct_seq_no as "SeqPos",
                czrcidx_ext_case_id as "UCN"
            from
                cdrdoct
                    left outer join ctrdtyp on cdrdoct_dtyp_code=ctrdtyp_code
                    left outer join czrcidx on cdrdoct_case_id=czrcidx_case_id
            where
                cdrdoct_case_id = ?
                and cdrdoct_image_ind='Y'
                $bannerSelStr
            order by
                cdrdoct_filing_date desc,
                cdrdoct_seq_no desc
        };
        
        my @tempArr;
        
        getData(\@tempArr, $query, $dbh, {valref => [$ucn]});
        
        foreach my $item (@tempArr) {
            my $docid = sprintf("%s|%i", $item->{'CaseNumber'}, $item->{'SeqPos'});
            $item->{'ObjectId'} = $ids{$docid}->{'ObjectId'};
            push(@docketItems, $item);
        }
        
        my $selStr = " object_id in (".	join(",", @{$temp}) . ")";
        getDocketList($docketList,$selStr);
        
        $count += $perQuery;
    }
    
    foreach my $image (@{$docketList}) {
        # Get the sequence ID to match it with the sequence ID in @docketItems
        my $seq_id = (split(/\|/, $image->{'cms_document_id'}))[1];
        
        foreach my $item (@docketItems) {
            next if ($item->{'ObjectId'} != $image->{'object_id'});
            # If we're here, we have a match
            $image->{'code'} = $item->{'DocketDescription'};
            $image->{'date'} = $item->{'EffectiveDate'};
            last;
        }
    }

	foreach my $image (@{$docketList}) {
		# Get the sequence ID to match it with the sequence ID in @docketItems
		my $seq_id = (split(/\|/, $image->{'cms_document_id'}))[1];

		foreach my $item (@docketItems) {
			next if ($item->{'cdrdoct_seq_no'} != $seq_id);
			# If we're here, we have a match
			$image->{'code'} = $item->{'ctrdtyp_desc'};
			$image->{'date'} = $item->{'cdrdoct_filing_date'};
            $image->{'iso_date_created'} = ISO_date($image->{'date'});
			last;
		}
	}
}


sub buildImageList {
	my $images = shift;
	my $docref = shift;
	my $showTif = shift;
	my $startpage = shift;
	my $pdforder = shift;
	
	if (!defined($pdforder)) {
		$pdforder = "desc"
	}
    
	# # of seconds for the image creation to time out
	my $IMGTIMEOUT = 10;

	if (!defined($startpage)) {
		$startpage = 1;
	}
	
	# The file to keep the information on the list of files used (boy, that
	# sure sounds convoluted).
	my $listfh = new File::Temp (
		UNLINK => 0,
		DIR => "/tmp"
	);

	my $listfn = $listfh->filename;

	my $pages = $startpage;

	foreach my $image (sort { if ($pdforder eq 'asc') {$a->{'iso_date_created'} cmp $b->{'iso_date_created'} } else {$b->{'iso_date_created'} cmp $a->{'iso_date_created'}}} @{$images}) {
		# get dir1 and compute dir2
		my $fname = $image->{'fname'};

		my $dir1=substr $fname,1,3;
		my $intdir1 = $dir1 + 0;
		my $dir2 = 0;

		if ( $intdir1 == 0 ) {
			$dir2 = substr $fname,4,3;
		} elsif ( $intdir1 <= 9 ) {
			$dir2 = substr $fname,3,4;
		} elsif ( $intdir1 < 99) {
			$dir2 = substr $fname,2,5;
		} else {
			$dir2 = substr $fname,1,6;
		}

		my $path="/mnt/images/$dir1/$dir2/$fname";

		if (!-e $path) {
			print "Content-type: text/html\n\n";
			print "Error: file $path not found!\n";
			exit;
		}

		if ((defined($showTif)) && ($showTif)) {
			# Just create a symlink to the original and redirect the user.
			my $basefile = basename($path);
			if (!-e "/var/www/html/tmp/$basefile") {
				symlink($path,"/var/www/html/tmp/$basefile");
			}
			print "Location: http://$ENV{'HTTP_HOST'}/tmp/$basefile\n\n";
			exit;
		}

		my $xname = $fname;
		$xname =~ s/\.tif//gi;
		my $tmpPath = "/tmp/$xname.pdf";

		my %pdfdoc;

		createPDF($tmpPath,$path,\%pdfdoc);

		push (@{$docref}, {
			file => $tmpPath,
			page => $pages,
			code => $image->{'code'},
			date => $image->{'date'},
			object_id => $image->{'object_id'}
		}
			  );

		$pages += $pdfdoc{'pagecount'};
		print $listfh "$tmpPath\n";
		}
	close ($listfh);
    return $listfn;
}


# pass the pidm of the party
sub buildAddress {
    my $id = shift;
	my $dbh = shift;

    my $addr;

    # look for 3 types of addresses - MA, BU, and RE
	my @addresses;
	lookupMailingAddress(\@addresses,$id,$dbh);
	
	my %addrList;
	my $confidential = 0;
	foreach my $atype ('MA','BU','RE','AL') {
		my $tmpAddr;
	
		switch ($atype) {
			case "MA"		{$tmpAddr = qq{<span style="font-size: smaller; color: blue">Mailing Address<br/></span>}};
			case "BU"		{$tmpAddr = qq{<span style="font-size: smaller; color: blue">Business Address<br/></span>}};
			case "RE"		{$tmpAddr = qq{<span style="font-size: smaller; color: blue">Residential Address<br/></span>}};
			case "AL"		{$tmpAddr = qq{<span style="font-size: smaller; color: blue">Alternate Address<br/></span>}};
		}
	
		foreach my $address (@addresses) {
			if ($address->{'AddrType'} eq $atype) {
				if ($address->{'Confidential'}) {
					$tmpAddr =~ s/Address/Address (CONFIDENTIAL)/g;
				}
				
				my $line1 = sprintf("%s %s %s %s %s %s", $address->{'StreetNumber'},
									$address->{'Direction'}, $address->{'PDA'},
									$address->{'StreetName'}, $address->{'Suffix'},
									$address->{'PODA'});
				my $line2 = sprintf("%s %s %s", $address->{'SecAddress'}, $address->{'Unit'},
									$address->{'SecName'});
				my $line3 = sprintf("%s, %s %s", $address->{'City'}, $address->{'State'},
									$address->{'Zip'});
				foreach my $line ($line1, $line2, $line3) {
					$line =~ s/^\s+//g;
					$line =~ s/\s+$//g;
					$line =~ s/\s+ / /g;
				}
				if (($address->{'SecAddress'} eq "") && ($address->{'Unit'} eq "") && ($address->{'SecName'} eq "")) {
					$addr=$tmpAddr."$line1<br/>$line3<br/>";
				} else {
					$addr=$tmpAddr."$line1<br/>$line2<br/>$line3<br/>";
				}
				$confidential = $address->{'Confidential'};
				$addrList{$atype} = $addr;
			}
		}
	}
	
	my $addrString;
	foreach my $atype ('MA','BU','RE','AL') {
		if (defined($addrList{$atype})) {
			$addrString .= $addrList{$atype};
		}
	}
	
    return ($addrString, $confidential);
}


sub getCaseDocket {
	my $docketRef = shift;
	my $casenum = shift;
	my $bdbh = shift;

	my $query = qq {
		select
			cdrdoct_entered_date as "EnteredDate",
			cdrdoct_filing_date as "FileDate",
			cdrdoct_seq_no as "Sequence",
			cdrdoct_dtyp_code as "DocketCode",
			ctrdtyp_desc as "DocketDescription",
			cdrdoct_text as "DocketText",
			cdrdoct_number as "ImageNumber",
			cdrdoct_case_id || '|' || cdrdoct_seq_no as "Document_ID"
		from
			cdrdoct
				left outer join ctrdtyp on cdrdoct_dtyp_code=ctrdtyp_code
		where
			cdrdoct_case_id = ?
			and cdrdoct_image_ind is not null
		order by
			cdrdoct_seq_no desc
	};

	getData($docketRef, $query, $bdbh, {valref => [$casenum]});
}


sub getFees {
    my $case = shift;
    my $dbh = shift;
    my $feesRef = shift;

    my $query = qq {
        select
            NVL(to_char(sum(cbraccd_balance),'99999999999999999999.99'),'0.00') as "Balance",
            NVL(to_char(sum(cbraccd_amt) + sum(cbraccd_adj_amount),'99999999999999999999.99'),'0.00') as "Total"
        from
            cbraccd
        where
            cbraccd_case_id = ?
            and cbraccd_detc_code in ('ORCK','ORCA','ODCK','BDCK')
    };

    my $fees = getDataOne($query, $dbh, [$case]);
    foreach my $key (keys %{$fees}) {
        $feesRef->{$key} = $fees->{$key};
    }

    undef $fees;
}

sub getLinkedCases {
    my $casenum = shift;
    my $lev = shift;
    my $dbh = shift;
    my $linkedRef = shift;

    my $nlev = $lev+1;
    my $query = qq {
        select
            cdrrelc_case_id as "CaseNum",
            cdrrelc_related_case_id as "RelatedCase",
            cdrrelc_activity_date as "ActivityDate"
        from
            cdrrelc
        where
            cdrrelc_case_id = ?
        UNION
        select
            cdrrelc_related_case_id as "CaseNum",
            cdrrelc_case_id as "RelatedCase",
            cdrrelc_activity_date as "ActivityDate"
        from
            cdrrelc
        where
            cdrrelc_related_case_id = ?
        order by
            "RelatedCase" desc,
            "ActivityDate" desc
	};

	getData($linkedRef,$query,$dbh,{valref => [$casenum, $casenum]});

    foreach my $linked (@{$linkedRef}) {
        $query = qq {
            select
                SRS_STATUS_CODE(?) as "SRS",
                cdbcase_desc as "CaseDescription",
                cdbcase_init_filing as "FileDate",
                cdbcase_ctyp_code as "CaseType",
                CASE cdbcase_sealed_ind
                    WHEN '3' THEN 'Y'
                    ELSE 'N'
                END as "Sealed"
            from
                cdbcase
            where
                cdbcase_id = ?
        };
        my $linkData = getDataOne($query,$dbh,[$linked->{'RelatedCase'},$linked->{'RelatedCase'}]);

        foreach my $key (keys %{$linkData}) {
            $linked->{$key} = $linkData->{$key};
        }
        undef $linkData;
    }
}


sub getWarrants {
    my $casenum = shift;
    my $dbh = shift;
    my $warrantRef = shift;
    
    my $eCodes = "('ALBW','ALCP','ALWT','ARWT','BWIS','CFWT','CISS','CPWT','DFCW','DFW','WTIS','JPU')";
    
    my $query = qq{
        select
            cobdreq_id as "WarrantID",
            cobdreq_signed_date as "SignedDate",
            -- If codbtra_server_ind is 'N' (the warrant wasn't served), then we should return an empty
            -- string for the ServeDate
            CASE cobdtra_served_ind
                WHEN 'N' then ''
                ELSE to_char(cobdtra_date)
            END as "ServedDate",
            cobdtra_served_ind as "ServeInd",
            cobdtra_serv_code as "ServedCode",
            cobdtra_rtd_date as "ReturnedDate",
            cobdreq_evnt_code as "EventCode",
            ctrevnt_desc as "EventDescription",
            ctvserv_desc as "ServiceDescription"
        from
            cobdreq left outer join cobdtra left outer join ctvserv on cobdtra_serv_code=ctvserv_code on cobdreq_id=cobdtra_dreq_id,
            ctrevnt
        where
            cobdreq_case_id = ?
            and cobdreq_evnt_code in $eCodes
            and ctrevnt_code = cobdreq_evnt_code
        order by
            cobdreq_signed_date desc
    };
    
    getData($warrantRef,$query,$dbh, {valref => [$casenum]});
}


sub getCharges {
    my $casenum = shift;
	my $dbh = shift;
    my $chargeRef = shift;

    my $query = qq {
		select
		    cdrccpt_chrg_no as "ChargeNumber",
		    cdrccpt_filing_date as "FileDate",
		    cdrccpt_statute_code as "Statute",
		    cdrccpt_sub_sect as "SubSection",
		    cdrccpt_desc as "ChargeDescription",
			cdrccpt_level as "ChargeLevel",
		    CASE cdrccpt_degree
                WHEN 'F' then '1'
                WHEN 'S' then '2'
                WHEN 'T' then '3'
                ELSE null
            END as "ChargeDegree",
		    cdrccpt_citation_no as "CitationNumber",
		    cdrccpt_disp_code as "DispCode",
		    cdrccpt_disp_date as "DispDate",
            CASE cdrccpt_statute_code
                WHEN 'VOP' then 'vop'
                ELSE ''
            END as "RowClass"
		from
		    cdrccpt
		where
		    cdrccpt_case_id = ?
		    and cdrccpt_maint_code is null
		order by
		    cdrccpt_chrg_no,
		    cdrccpt_non_chrg_no
	};

	getData($chargeRef,$query,$dbh, {valref => [$casenum]});
}


sub getEvents {
    my $casenum = shift;
    my $dbh = shift;
    my $eventRef = shift;
    my $startDate = shift;
    
    my @args = ($casenum);
    
    my $dateStr = "";
    if (defined($startDate)) {
        $startDate = US_date($startDate);
        $dateStr = "and csrcsev_sched_date >= to_date(?,'MM/DD/YYYY')";
        push(@args, $startDate);
    }
    
    my $query = qq {
        select
            csrcsev_case_id as "UCN",
            csrcsev_csev_seq as "Sequence",
            csrcsev_evnt_code as "EventCode",
            ctrevnt_desc as "EventDescription",
            csrcsev_sched_date as "EventDate",
            csrcsev_room_code as "EventRoom",
            to_char(to_date('1970-01-01 ' || csrcsev_start_time, 'YYYY-MM-DD HH24:MI:SS'),'HH:MI AM') as "StartTime",
            csrcsev_judge_pidm as "JudgeID",
            csrcsev_locn_code as "Location",
            csrcsev_doct_date as "DocketDate",
            spriden_last_name as "LastName",
            spriden_first_name as "FirstName",
            spriden_mi as "MiddleName"
        from
            csrcsev,
            ctrevnt,
            spriden
        where
            csrcsev_evnt_code=ctrevnt_code
            and csrcsev_case_id = ?
            and spriden_pidm = csrcsev_judge_pidm
            and spriden_change_ind is null $dateStr
        order by
            csrcsev_sched_date desc
    };
    
    getData($eventRef,$query,$dbh,{valref => \@args});
    
    foreach my $event (@{$eventRef}) {
        # Construct the Judge's name
        if (defined($event->{'FirstName'})) {
            $event->{'FirstName'} =~ s/^JUDGE\s+//g;
        }
        
        $event->{'Judge'} = buildName($event);
        
        # Find out if the event is canceled
        $query = qq {
            select
                cdrdoct_csev_seq
            from
                cdrdoct
            where
                cdrdoct_dtyp_code in ('EVCAN','EVERR','EVRST')
                and cdrdoct_csev_seq = ?
                and cdrdoct_case_id = ?
        };
        
        my $canc = getDataOne($query,$dbh,[$event->{'Sequence'}, $event->{'UCN'}]);
        if (defined($canc)) {
            $event->{'Canceled'} = 'Y';
            if (defined($event->{'RowClass'})) {
                $event->{'RowClass'} .= ' canceled';
            } else {
                $event->{'RowClass'} = 'canceled';
            }
        } else {
            $event->{'Canceled'} = 'N';
        }
        undef $canc;
    }
}

sub getOLSEvents {
    my $casenum = shift;
    my $dbh = shift;
    my $olsRef = shift;
    my $div = shift;
    my $loc = shift;
    
    return if (!defined($div));
    
    # This is an OLS division.  Are/were there any hearings scheduled for this case?
    my $vdbh = dbConnect("vrb2");
    
    my $query;
    
    if ($div eq 'AW') {
        # Not yet
        return;
    } else {
        $query = qq{
            SELECT 
            	ec.case_num as UCN, 
				ec.ols_conf_num AS ConfNum,
				h_type AS EventCode,
				h_description AS EventDescription,
				DATE_FORMAT(CAST(e.start_date as DATE),'%m/%d/%Y') as EventDate,
				NULL as EventRoom,
				TIME_FORMAT(e.start_date,'%h:%i %p') as StartTime,
				DATE_FORMAT(ec.date_scheduled, '%m/%d/%Y') as DocketDate,
				j.judge_lastname as LastName,
				j.judge_middlename as MiddleName,
				j.judge_firstname as FirstName,
				j.judge_suffix as Suffix,
				CASE(ec.canceled)
					WHEN 1 THEN 'Y'
				  ELSE 'N'
				END as Canceled
            FROM 
            	events e
				INNER JOIN event_cases ec
					ON e.event_id = ec.event_id
				INNER JOIN olscheduling.hearingtype h
					ON e.hearingtype_id = h.hearingtype_id
				INNER JOIN olscheduling.judge j
					ON e.ols_judge_id = j.judge_code
				WHERE e.division = ?
					AND REPLACE(ec.case_num, '-', '') = ?

        };
        getData($olsRef, $query, $vdbh, {valref => [$div, $casenum]});
    
        foreach my $ols (@{$olsRef}) {
            $ols->{'Motions'} = [];
            $query = qq {
                SELECT 
					CASE 
					WHEN p1.m_title IS NOT NULL
						THEN p1.m_title
					WHEN p2.m_title IS NOT NULL AND p2.m_title = 'Other'
						THEN em.m_othertitle
					WHEN p2.m_title IS NOT NULL AND p2.m_title <> 'Other'
						THEN p2.m_title
					ELSE NULL
				END AS Motion
				FROM 
					event_cases ec
					LEFT OUTER JOIN event_motions em
					ON em.event_id = ec.event_id
					AND em.ols_conf_num = ec.ols_conf_num
				LEFT OUTER JOIN olscheduling.predefmotions p1
					ON p1.m_type = ec.motion
					AND p1.division = ?
				LEFT OUTER JOIN olscheduling.predefmotions p2
					ON p2.m_type = em.m_type
					AND p2.division = ?
				WHERE ec.ols_conf_num = ?
            };
            getData($ols->{'Motions'}, $query, $vdbh, {valref => [$div, $div, $ols->{'ConfNum'}]});
        }
    }
    
    $vdbh->disconnect;
    
    foreach my $event (@{$olsRef}) {
        $event->{'Judge'} = buildName($event);
        $event->{'Location'} = $loc;
    
        if ($event->{'Canceled'} eq 'Y') {
            if (defined($event->{'RowClass'})) {
                $event->{'RowClass'} .= ' canceled';
            } else {
                $event->{'RowClass'} = 'canceled';
            }
        } else {
            $event->{'RowClass'} = '';
        }
    }
}


sub getDockets {
    my $casenum = shift;
    my $dbh = shift;
    my $docketRef = shift;
    
    my $query = qq {
        select
            cdrdoct_entered_date as "EnteredDate",
            cdrdoct_filing_date as "FileDate",
            cdrdoct_seq_no as "Sequence",
            cdrdoct_dtyp_code as "DocketCode",
            ctrdtyp_desc as "DocketDescription",
            cdrdoct_text as "DocketText",
            cdrdoct_number as "ImageNumber",
            CASE
                WHEN cdrdoct_book_nmb is NULL THEN 'No Book Location Available'
                ELSE 'Book ' || cdrdoct_book_nmb || ', Page ' || cdrdoct_page_nmb
            END as "BookLocation",
            NVL(cdrdoct_image_ind,'N') as "Image",
            spriden_first_name as "FirstName",
            spriden_last_name as "LastName"
        from
            cdrdoct
                left outer join ctrdtyp on cdrdoct_dtyp_code=ctrdtyp_code
                left outer join spriden on cdrdoct_filing_pidm=spriden_pidm
        where
            cdrdoct_case_id = ?
            and spriden_change_ind is null
        order by
            cdrdoct_filing_date desc,
            cdrdoct_seq_no desc
    };
    
    getData($docketRef, $query, $dbh, {valref => [$casenum]});
    
    # Now get the information on the object IDs for all of these beasts, from the BOB db
    my %cmsIDs;
    my $idbh = dbConnect("wpb-images");
    $query = qq {
        select
            object_id as "object_id",
            substr(cms_document_id, instr(cms_document_id, '|', -1, 1) +1) as "seq"
        from
            dbotr.edocument a,
            dbotr.repo001 b
        where
            bob_guid=ds_guid and
            cms_document_id like '$casenum|%'
        order by
            dt_created desc
    };
    
    getData(\%cmsIDs, $query, $idbh, {hashkey =>'seq', flatten => 1});
    
    foreach my $docket (@{$docketRef}) {
        if (inArray(\@ORDERS,$docket->{'DocketCode'})) {
            $docket->{'RowClass'} = "order";
            $docket->{'LastName'} = "COURT";
            $docket->{'FirstName'} = undef;
        } elsif (inArray(\@MOTIONS, $docket->{'DocketCode'})) {
            $docket->{'RowClass'} = "motion";
        } elsif (inArray(\@JUDGMENTS, $docket->{'DocketCode'})) {
            $docket->{'RowClass'} = "judgment";
            $docket->{'LastName'} = "COURT";
            $docket->{'FirstName'} = undef;
        } elsif (inArray(\@NOTICES, $docket->{'DocketCode'})) {
            $docket->{'RowClass'} = "notice";
        } elsif (inArray(\@VOPS, $docket->{'DocketCode'})) {
            $docket->{'RowClass'} = "vop";
        } elsif (inArray(\@PETITIONS, $docket->{'DocketCode'})) {
            $docket->{'RowClass'} = "petition";
        } elsif ($docket->{'DocketCode'} eq 'EVCAN') {
            $docket->{'RowClass'} = "canceled";
        } else {
            $docket->{'RowClass'} = "";
        }
    
        # Build the Filer name (if there is one)
        if (defined($docket->{'LastName'})) {
            if (defined($docket->{'FirstName'})) {
                $docket->{'FilerName'} = sprintf("%s, %s", $docket->{'LastName'}, $docket->{'FirstName'})
            } else {
                $docket->{'FilerName'} = $docket->{'LastName'}
            }
        } else {
            $docket->{'FilerName'} = '&nbsp;';
        }
        
        # And add the CMS Doc ID to the array if there's an image
        if ($docket->{'Image'} eq 'Y') {
            if (defined($cmsIDs{$docket->{'Sequence'}})) {
                $docket->{'ObjectID'} = $cmsIDs{$docket->{'Sequence'}}->{'object_id'};
                $docket->{'UCNObj'} = sprintf("%s|%d", $casenum, $cmsIDs{$docket->{'Sequence'}}->{'object_id'});
            }
        }
    }
}



sub getOtherCases {
	my $partyRef = shift;
	my $thisCase = shift;

	my @partyIds = keys(%{$partyRef});
    return if (!scalar(@partyIds));

	my $inString = join(",", @partyIds);

	my $dbh = dbConnect("wpb-banner-prod");

	# First, find the number of cases for each party
	my $query = qq {
		select
			cdrcpty_pidm as "PIDM",
			count(*) as "PartyCount"
		from
			cdrcpty
		where
			cdrcpty_pidm in ($inString)
		group by
			cdrcpty_pidm
		order by
			"PartyCount" desc
	};

	my @counts;
	getData(\@counts,$query,$dbh);

	my @usePidms;

	foreach my $count (@counts) {
		if ($count->{'PartyCount'} <= $otherCaseMax) {
			push(@usePidms,$count->{'PIDM'});
		}
	}

	# Now we having a listing of just the PIDMs that have fewer cases than the threshold.
	# Look up the cases for those parties
	return if (!scalar(@usePidms));

	foreach my $pidm (@usePidms) {
		$query = qq {
			select
				cdrcpty_case_id as "CaseNumber",
				cdrcpty_pidm as "PIDM",
				cdrcpty_ptyp_code as "PartyType",
				cdbcase_desc as "CaseStyle",
				SRS_STATUS_CODE(cdrcpty_case_id) as "Status",
				ctrptyp_desc as "PartyTypeDesc",
				cdbcase_ctyp_code as "CaseType"
			from
				cdrcpty,
				cdbcase,
				ctrptyp
			where
				cdrcpty_pidm = ?
				and cdbcase_id = cdrcpty_case_id
				and ctrptyp_code = cdrcpty_ptyp_code
		};

		my @otherCases;
		getData(\@otherCases,$query,$dbh, {valref => [$pidm]});
		foreach my $otherCase (@otherCases) {
			next if ($otherCase->{'CaseNumber'} eq $thisCase);
			$otherCase->{'PartyTypeDesc'} = ucfirst(lc($otherCase->{'PartyTypeDesc'}));
			push(@{$partyRef->{$otherCase->{'PIDM'}}->{'OtherCases'}}, $otherCase);
		}
	}
}


sub getPropertyAddress {
	my $casenum = shift;
	my $dbh = shift;
    my $returnHtml = shift;
    
    if (!defined($returnHtml)) {
        $returnHtml = 1;
    }
    
	
	my $query = qq {
		select
			cdrcpty_case_id as "CaseNumber",
			cdrcpty_seq_no as "Seq",
			cdrcpty_ptyp_code as "PartyType",
			spraddr_strt_no as "StreetNumber",
			spraddr_strt_frct as "Direction",
			spraddr_strt_pda as "PDA",
			spraddr_strt_name as "StreetName",
			spraddr_strt_sufa as "Suffix",
			spraddr_strt_poda as "PODA",
			spraddr_sec_ada as "SecAddress",
			spraddr_sec_add_unit as "Unit",
			spraddr_bldf_sec_name as "SecName",
			spraddr_city as "City",
			spraddr_zip as "Zip",
			spraddr_stat_code as "State",
			spraddr_atyp_code as "AddrType",
			spraddr_seqno as "AddrSeq"
		from
			cdrcpty,
			spriden left outer join spraddr on spriden_pidm = spraddr_pidm
		where
			cdrcpty_case_id = ?
			and cdrcpty_end_date is null
			and cdrcpty_pidm=spriden_pidm
			and spraddr_atyp_code = ?
			and spriden_change_ind is null
			and ROWNUM <= 1
	};
	
	my $address;
	
	# Check for PA first, then AL
	foreach my $addrType ('PA','AL') {
		$address = getDataOne($query, $dbh, [$casenum, $addrType]);
		last if (defined($address));
	}
	
	if (defined($address)) {
		my $addr;
		
		my $line1 = sprintf("%s %s %s %s %s %s", $address->{'StreetNumber'},
							$address->{'Direction'}, $address->{'PDA'},
							$address->{'StreetName'}, $address->{'Suffix'},
							$address->{'PODA'});
		my $line2 = sprintf("%s %s %s", $address->{'SecAddress'}, $address->{'Unit'},
							$address->{'SecName'});
		my $line3 = sprintf("%s, %s %s", $address->{'City'}, $address->{'State'},
							$address->{'Zip'});
		foreach my $line ($line1, $line2, $line3) {
			$line =~ s/^\s+//g;
			$line =~ s/\s+$//g;
			$line =~ s/\s+ / /g;
		}
		
        my $newline = "<br/>";
        if (!$returnHtml) {
            $newline = "\n";
        }
        
        
		if (($address->{'SecAddress'} eq "") && ($address->{'Unit'} eq "") && ($address->{'SecName'} eq "")) {
			$addr=sprintf("%s%s%s",$line1,$newline,$line3);
		} else {
			$addr=sprintf("%s%s%s%s%s",$line1,$newline,$line2,$newline,$line3);
		}
        return $addr;
	} else {
		return undef;
	}
}


sub getExtCaseId {
	my $dbh = shift;
	my $caseid = shift;
    
    $caseid =~ s/-//g;

	my $query = qq {
		select
			czrcidx_ext_case_id as "ExtCaseID"
		from
			czrcidx
		where
			czrcidx_case_id = ?
	};
	my $case = getDataOne($query,$dbh,[$caseid]);
	if (defined($case)) {
		return $case->{'ExtCaseID'};
	} else {
		return undef;
	}
}

sub getBannerCaseInfo {
    my $inUCN = shift;
    
    my $icmsuser = $ENV{'REMOTE_USER'};
	
    my $ldap = ldapConnect();
    my $secretuser = inGroup($icmsuser,'CAD-ICMS-SEC',$ldap);
    my $sealeduser = inGroup($icmsuser,'CAD-ICMS-SEALED',$ldap);
    my $jsealeduser = inGroup($icmsuser,'CAD-ICMS-SEALED-JUV',$ldap);
    my $odpuser = inGroup($icmsuser,'CAD-ICMS-ODPS',$ldap);

    my $ucn=uc(clean($inUCN));
    
    $ucn =~ s/^50//g;
	
    my $referer_host = (split("\/",$ENV{'HTTP_REFERER'}))[2];
    
    my %data;
    $data{'ucn'} = $ucn;
	$data{'notesuser'} = inGroup($icmsuser, 'CAD-ICMS-NOTES', $ldap);
	$data{'showTif'} = inGroup($icmsuser, 'CAD-ICMS-TIF', $ldap);
	$data{'odpuser'} = $odpuser;

	# UCN should be of format YYYY-CF-NNNNNN-A
	# banner case # YYYYCFNNNNNNAXX
	my $casenum=$ucn;
	$casenum =~ s/-//g;
    $data{'casenum'} = $casenum;

	my $dbh = dbConnect("wpb-banner-prod");
	doQuery("alter session set nls_date_format='MM/DD/YYYY'",$dbh);

    # don't look at sealed records!
	my $query = qq {
        select
            cdbcase_ctyp_code as "CaseType",
            cdbcase_cort_code as "CourtCode",
            cdbcase_division_id as "DivisionID",
			CASE cdbcase_sealed_ind
				WHEN '3' THEN 'Y'
				ELSE 'N'
			END as "Sealed",
            cdbcase_id as "CaseNumber"
        from
            cdbcase
        where
            cdbcase_id = ?
	};

	my $caseinfo = getDataOne($query,$dbh,[$casenum]);
	
	if(($caseinfo->{'Sealed'} eq 'Y') && (!$sealeduser)) {
		if (!($jsealeduser && inArray(['CJ','DP'],$caseinfo->{'CaseType'}))) {
            $dbh->disconnect;
            $data{'denyReason'} = "sealed";
            doTemplate(\%data,$templateDir,"noAccess.tt",1);
            exit;
		}
	}

	# don't let users that don't have access to secret cases see them.
    if(!$secretuser){
		if(inArray(['AD','AJ','CJ','DP','TE','TP','TB'], $caseinfo->{'CaseType'})) {
            $dbh->disconnect;
            $data{'denyReason'} = "restricted";
            
            my $c = $ucn;
            
            my %result;
            $result{'status'} = 'NO ACCESS';
            $result{'tab'} = sprintf('case-%s', $c);
            $result{'html'} = "<br/>Case number $ucn is a restricted case.  No information can be provided.\n";
            $result{'tabname'} = $c;
            
            returnJson(\%result);
            exit;
		}
	}

	# Get property addresses
	$data{'propertyAddress'} = getPropertyAddress($casenum,$dbh);
	
    # Ok, the user has access to the case.
    $data{'parties'} = [];
    $data{'attorneys'} = [];
    getParties($casenum, $dbh, $data{'parties'}, $data{'attorneys'});

    $data{'caseinfo'} = $caseinfo;

	# set criminal flag based on cort code
	my $crimflag = 0;
	if(inArray(['CJ'], $caseinfo->{'CourtCode'})) {
		$crimflag=1;
	}

	# get judge and division information
	my($div,$judge);

	$data{'judge'} = getjudgedivfromdiv($caseinfo->{'DivisionID'},$dbh);

	$query = qq {
		select
			SRS_STATUS_CODE('$casenum') as "CaseStatus",
			cdbcase_dtyp_code_status as "Status",
			cdbcase_init_filing as "FileDate",
			ctvctyp_code as "CaseType",
			ctvctyp_desc as "CaseTypeDesc"
		from
			cdbcase,
			ctvctyp
		where
			cdbcase_id = ?
			and cdbcase_ctyp_code=ctvctyp_code
	};

	my $casesummary = getDataOne($query,$dbh,[$casenum]);

	$query = qq {
		select
			max(cdrdoct_filing_date) as "LastEventDate"
		from
			cdrdoct
		where
			cdrdoct_case_id = ?
	};

	my $activity = getDataOne($query,$dbh,[$casenum]);
	$casesummary->{'LastActivity'} = $activity->{'LastEventDate'};

    $caseinfo->{'CaseAge'} = getage($casesummary->{'FileDate'});
	escapeFields($casesummary);

    foreach my $key (keys %{$casesummary}) {
        $caseinfo->{$key} = $casesummary->{$key};
    }

	$data{'fees'} = {};
	getFees($casenum,$dbh,$data{'fees'});

	$data{'flags'} = [];
	$data{'casenotes'} = [];
	#my $cnconn = dbConnect("icms");
	#getFlags($ucn,$cnconn,$data{'flags'});
	#getNotes($ucn,$cnconn,$data{'casenotes'});
	#
	#$cnconn->disconnect;

	$data{'linkedCases'} = [];
	getLinkedCases($casenum, 0, $dbh, $data{'linkedCases'});
    
    my $vdbh = dbConnect("vrb2");
    $data{'events'} = [];
    getVrbEventsByCase($data{'events'}, $casenum, $vdbh);
    
    # Check to see if any of these events have specified motions
    $data{'hasMotions'} = 0;
    foreach my $event (@{$data{'events'}}) {
        if ((defined($event->{'Motion'})) && ($event->{'Motion'} ne "")) {
            $data{'hasMotions'} = 1;
            last;
        }
    }
    
    $data{'otherDocs'} = [];
    getQueueItems($casenum, $data{'otherDocs'});
    
    ## Get OLS events for those divisions that participate
    #my $jdbh = dbConnect("judge-divs");
    #$query = qq {
    #    select
    #        d.division_id,
    #        c.courthouse_abbr
    #    from
    #        divisions d,
    #        courthouses c
    #    where
    #        division_id = ?
    #        and has_ols = 1
    #        and d.courthouse_id = c.courthouse_id
    #};
    #my $hasols = getDataOne($query,$jdbh,[$caseinfo->{'DivisionID'}]);
    #$jdbh->disconnect;

    #if (defined($hasols)) {
    #    $data{'olsevents'} = [];
    #    getOLSEvents($casenum, $dbh, $data{'olsevents'}, $caseinfo->{'DivisionID'}, $hasols->{'courthouse_abbr'});
    #}

	if ($casenum=~/DP|CJ|DR/i) {
		$data{'showCrim'} = 1;
		$data{'warrants'} = [];
		getWarrants($casenum, $dbh, $data{'warrants'});
		$data{'charges'} = [];
		getCharges($casenum, $dbh, $data{'charges'});
	}
    
	$dbh->disconnect;
    
    my $idbh = dbConnect("icms");
    $data{'watchList'} = getWatchList($casenum, $icmsuser, $idbh);
    
    my $output = doTemplate(\%data,"$templateDir/casedetails","bannerCaseDetails.tt",0);
    
    return $output;
}



sub getParties {
    my $case = shift;
    my $dbh = shift;
    my $partyRef = shift;
    my $attorneyRef = shift;

    my $query = qq {
        select
            cdrcpty_pidm as "PIDM",
            cdrcpty_ptyp_code as "PartyType",
            cdrcpty_start_date as "StartDate",
            cdrcpty_end_date as "EndDate",
            cdrcpty_csev_seq_no as "CsevSeq",
            cdrcpty_assoc_with as "AssocWith",
            cdrcpty_case_id as "CaseNum",
            cdrcpty_seq_no as "Seq",
            spriden_last_name as "LastName",
            spriden_first_name as "FirstName",
            spriden_mi as "MiddleName",
            spriden_id as "spriden_id",
            cdrcpty_ptyp_code as "AssocPartyType",
            cdrcpty_pidm as "AssocPartyPIDM",
            ctrptyp_desc as "PartyTypeDesc",
            spbpers_birth_date as "DOB"
        from
            cdrcpty,
            spriden left outer join spbpers on (spriden_pidm = spbpers_pidm),
            ctrptyp
        where
            cdrcpty_case_id = ?
            and cdrcpty_pidm = spriden_pidm
            and cdrcpty_ptyp_code = ctrptyp_code
            and spriden_change_ind is null
            and cdrcpty_ptyp_code not in ('JUDG','AFFP')
        order by
            decode(cdrcpty_ptyp_code,
                'PLT',1,
                'PET',1,
                'CHLD',1,
                'FTH',2,
                'DFT',2,
                'RESP',2,
                'MTH',3,
                '3PLT',3,
                '3DFT',4,
                '4PLT',5,
                '4DFT',6,
                7),
            spbpers_birth_date asc,
            cdrcpty_end_date desc,
            spriden_last_name
    };
	
	my @parties;
	getData(\@parties,$query,$dbh, {valref => [$case]});
	
	my $esdbh = dbConnect("eservice");

	# Build a list of attorney associations and other cases
    my %otherCases;
	my @associations;
	foreach my $party (@parties) {
        $party->{'tdCols'} = 5; # Minimum to start
        $party->{'PartyTypeDesc'} = uc($party->{'PartyTypeDesc'});
        $party->{'FullName'} = buildName($party,1);
		$party->{'Phone'} = buildPhone($party->{'PIDM'}, $dbh);
        $party->{'Age'} = getageinyears($party->{'DOB'});

        if (defined($party->{'Age'})) {
            $party->{'tdCols'} += 2;
        }


		if (((defined($party->{'EndDate'})) && ($party->{'EndDate'} ne "")) || (defined($party->{'CsevSeq'}))) {
            # Inactive party. Stop processing here.
            $party->{'Active'} = 'N';
            next;
        }

        $party->{'Active'} = 'Y';

        if ($party->{'PartyType'} !~ /ATTY|AGAL/) {
            $otherCases{$party->{'PIDM'}} = $party;
            next;
        }

        if ($party->{'spriden_id'} !~ /\D/) {
            $party->{'BarID'} = int($party->{'spriden_id'});
        } else {
            $party->{'BarID'} = '&nbsp;';
        }
		if (defined($party->{'AssocWith'})) {
            foreach my $assocParty (@parties) {
                next if ($assocParty->{'Seq'} != $party->{'AssocWith'});
                $party->{'Represents'} = {
                    'PartyTypeDesc' => $assocParty->{'PartyTypeDesc'},
                    'FullName' => $assocParty->{'FullName'}
                };
            }
			$associations[$party->{'AssocWith'}] = 1;
		}
	}

    foreach my $party (@parties) {
        if ((!defined($associations[$party->{'Seq'}])) &&
            (inArray(['PET','RESP','PLT','DFT'],$party->{'PartyType'}))) {
            $party->{'ProSe'} = 1;
        } else {
            $party->{'ProSe'} = 0;
        }
	}

	getOtherCases(\%otherCases,$case);

    foreach my $party (@parties) {
        $party->{'isEservice'} = 0;
        if (defined($otherCases{$party->{'PIDM'}})) {
            $party->{'OtherCases'} = $otherCases{$party->{'PIDM'}}->{'OtherCases'};
        } else {
            $party->{'OtherCases'} = {};
        }

        $party->{'EmailAddresses'} = [];
        if ($party->{'PartyType'} =~ /ATTY|AGAL/) {
            getAttorneyAddresses($case, $party->{'EmailAddresses'}, $esdbh, $party->{'spriden_id'}, \$party->{'isEservice'});
        } else {
            # Do this whether or not the party is pro se, because some represented parties register, anyway.
            getProSeAddresses($case, $party->{'EmailAddresses'}, $esdbh, $party->{'spriden_id'});
            if (scalar(@{$party->{'EmailAddresses'}})) {
                $party->{'tdCols'} += 1;
                $party->{'isEservice'} = 1;
            }
        }

        ($party->{'Address'}, $party->{'Confidential'}) = buildAddress($party->{'PIDM'}, $dbh);

        # And now decide where each goes
        if ($party->{'PartyType'} =~ /ATTY|AGAL/) {
            push(@{$attorneyRef}, $party);
        } else {
            push(@{$partyRef}, $party);
        }
    }

    $esdbh->disconnect;
}

1;
