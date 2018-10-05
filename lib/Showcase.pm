#!/usr/bin/perl
#
#  Showcase.pm -- shared subroutines for SHOWCASE
#
# 02/14/11 lms new file
# 07/28/11 lms new evironment variable for using Trakman Image Service using
#                  https

BEGIN {
   use lib $ENV{'PERL5LIB'};
}

package Showcase;
require Exporter;

use strict;
use ICMS;
use PBSO;
use File::Basename;
use Switch;
use MIME::Base64;
use Common qw (
    inArray
    today
    changeDate
    convertTimes
    escapeFields
    dumpVar
    ISO_date
    sanitizeCaseNumber
    buildName
    prettifyString
    doTemplate
    getArrayPieces
    returnJson
    getShowcaseDb
    createTab
    getUser
    getSession
    $templateDir
    $db
);

use DB_Functions qw(
   @SECRETTYPES
   dbConnect
   getData
   getDataOne
   getDbSchema
   inGroup
   $DEFAULT_SCHEMA
   ldapConnect
   getScCaseAge
   getWatchList
   getVrbEventsByCase
   getQueueItems
   getSubscribedQueues
	getSharedQueues
	getQueues
	log_this
);

use EService qw(
	getAttorneyAddresses
	getProSeAddresses
);

use PBSO2 qw (
    getMugshotWithJacketId
    getInmateIdFromBooking
);

use JSON;

use LWP::UserAgent;

use Images qw (createPDF);

use Date::Calc qw(:all);
use Date::Calendar::Profiles qw ($Profiles);
use Date::Calendar;
use POSIX qw (strftime);
use XML::Simple;

use Exporter();
our @ISA=qw(Exporter);
our @EXPORT_OK=qw(
    $ACTIVE
    $NOTACTIVE
    @SCINACTIVE
    @SCACTIVE
    @attorneyTypes
    @ctArray
    @juvDivs
    @partyTypes
    $proSeString
    buildTMImageList
    citationSearch
    convertCaseNumToDisplay
    getAliases
    getAppellantAddresses
    getArrests
    getAttorneys
    getBonds
    getCaseUsingLegacyCaseNumber
    getCaseUsingUCN
    getCharges
    getCourtEvents
    getDefendantAndAddress
    getDockets
    getDocketItems
    getFees
    getjudgefromdiv
    getLinkedCases
    getOtherCases
    getParties
    getReopenHistory
    getSCcasetype
    getWarrants
    showcaseSearch
    getScCaseInfo
    scGetDocketItems
    showcaseCivilSearch
    getScCivilCaseInfo
    getPropertyAddress
    getParties_civil
    getOtherCases_civil
    buildAddress
    lookupMailingAddress
    getjudgedivfromdiv
    getEvents
    getSCCaseNumber
    getCaseID
    getRegistry
    getEServiceAddresses
);

our $proSeString = qq {<span style="font-size: smaller; color: blue">(Pro Se)&nbsp;&nbsp;</span>};

#
# not sure about this.... casestatus can be:
# Closed, Consolidated, Incomplete, Disposed, Open, Reopen, Reopen VOP
our @SCACTIVE = (
   'Open',
   'Reopen',
   'Reopen VOP',
   'Incomplete',
   'Consolidated'
);

# No, join won't work here, because we need to enclose them in quotes
our $ACTIVE = "(";

for (my $count = 0; $count < scalar(@SCACTIVE);) {
   $ACTIVE .= "'$SCACTIVE[$count]'";
   $count++;
   if ($count < scalar(@SCACTIVE)) {
      $ACTIVE .= ", ";
   }
}
$ACTIVE .= ")";

#our $ACTIVE = "(" . join(",", @SCACTIVE) . ")";
#our $ACTIVE = "('Open','Reopen', 'Reopen VOP')";

our @SCINACTIVE = (
   'Closed',
   'Disposed'
);

# No, join won't work here, because we need to enclose them in quotes
our $NOTACTIVE = "(";

for (my $count = 0; $count < scalar(@SCINACTIVE);) {
    $NOTACTIVE .= "'$SCINACTIVE[$count]'";
    $count++;
    if ($count < scalar(@SCINACTIVE)) {
        $NOTACTIVE .= ", ";
    }
}
$NOTACTIVE .= ")";

# Global array of the valid court types (handy to use with inArray())
our @ctArray = ("CF","CO","CT","IN","MM","MO","TR","MI");

our $partyTypeString = "(select ctrptyp_code from ctrptyp)";

# When we're showing other cases, don't show them if the party has more than this number
# of cases
our $otherCaseMax = 100;

# for showcase, the case type is not always defined.  convert it using this...
sub getSCcasetype {
    my $courttype = shift;
    my $casetype = shift;

    # Map court types to case types
    my %ctMap = (
                 'CF' => 'CF',
                 'CO' => 'CO',
                 'CT' => 'IN',
                 'IN' => 'MI',
                 'MM' => 'MS',
                 'MO' => 'MO',
                 'TR' => 'TI'
    );

    if(($casetype eq '') && (defined($ctMap{$courttype}))) {
        return $ctMap{$courttype};
    }
    return $casetype;
}


# Showcase party types that should be included in search
our @partyTypes = (
    "'3RD PARTY DEFENDANT'",
    "'3RD PARTY PLAINTIFF'",
    "'4TH PARTY DEFENDANT'",
    "'4TH PARTY PLAINTIFF'",
    "'ALLEGED INCAPACITATED PERSON'",
    "'APPELLEE'",
    "'APPELLANT'",
    "'AUNT (MATERNAL)'",
    "'AUNT (PATERNAL)'",
    "'AUNT'",
    "'BROTHER'",
    "'CROSS APPELLEE'",
    "'CROSS APPELLANT'",
    "'CROSS CLAIMANT'",
    "'CROSS DEFENDANT'",
    "'COUNTER DEFENDANT'",
    "'CHILD'",
    "'CHILD (CJ)'",
    "'CONSERVATOR'",
    "'COUSIN'",
    "'COUNTER PLAINTIFF'",
    "'CUSTOMER'",
    "'CURATOR'",
    "'CUSTODIAN/GUARDIAN'",
    "'DECEDENT'",
    "'DEFENDANT'",
    "'DEFENDANT (PRO SE)'",
    "'DEFENDANT/RESPONDENT'",
    "'FOSTER PARENT'",
    "'FATHER'",
    "'GUARDIAN AD LITEM'",
    "'GARNISHEE'",
    "'GRANDFATHER'",
    "'GRANDFATHER (MATERNAL)'",
    "'GRANDFATHER (PATERNAL)'",
    "'GRANDMOTHER'",
    "'GRANDMOTHER (MATERNAL)'",
    "'GRANDMOTHER (PATERNAL)'",
    "'GODFATHER'",
    "'GODMOTHER'",
    "'GUARDIAN'",
    "'HYBRID'",
    "'INCAPACITATED PERSON'",
    "'INTERVENOR'",
    "'LIENOR'",
    "'MINOR'",
    "'MOTHER'",
    "'NON RELATIVE'",
    "'PARENT'",
    "'PATIENT'",
    "'PETITIONER'",
    "'PLAINTIFF'",
    "'PLAINTIFF/PETITIONER'",
    "'PERSONAL REPRESENTATIVE'",
    "'RESPONDENT'",
    "'STEPBROTHER'",
    "'DEFENDANT (PRO SE)'",
    "'STEPFATHER'",
    "'SISTER'",
    "'STEPMOTHER'",
    "'STEPSISTER'",
    "'SURPLUS TRUSTEE'",
    "'TRUSTEE'",
    "'UNCLE'",
    "'UNCLE (MATERNAL)'",
    "'UNCLE (PATERNAL)'",
    "'RELATIONSHIP NOT LISTED ON PCA'",
    "'VICTIM'",
    "'WARD'",
    "'WITNESS'"
);


# showcase attorney types
our @attorneyTypes = (
                      "'ASSISTANT ATTORNEY GENERAL'",
                      "'ASST GENERAL COUNSEL FOR DJJ'",
                      "'ATTORNEY FOR FC PROJECT'",
                      "'ATTORNEY AD LITEM'",
                      "'ASSISTANT PUBLIC DEFENDER'",
                      "'ASSISTANT STATE ATTORNEY'",
                      "'ATTORNEY FOR VICTIM'",
                      "'ATTORNEY'",
                      "'COURT APPOINTED ATTORNEY'",
                      "'CT APPTED/CONFLICT COUNSEL'",
                      "'CHILDRENS WELFARE LEGAL SVCS'",
                      "'PUBLIC DEFENDER'"
);

our @juvDivs = (
                "'DG'",
                "'JA'",
                "'JK'",
                "'JL'",
                "'JM'",
                "'JO'",
                "'JS'"
);

1;

my $activePhrase = "and c.CaseStatus in $ACTIVE ";
my $excludeSealed = "(c.Sealed = 'N') ";
my $showjSealed = "((c.Sealed = 'N') OR (c.Sealed = 'Y' AND c.CourtType in ('CJ','DP')))";
my $showpSealed = "((c.Sealed = 'N') OR (c.Sealed = 'Y' AND c.CourtType in ('GA','CP','MH')))";
my $excludeSecret = " and (c.CaseType not in (" . join(",", @SECRETTYPES) . ") or c.CaseType is null)";
my $criminalPhrase = " and c.CourtType in (" . join(",", @SCCODES, "'AP'") . ") ";

# expecting:  50-yyyy-XX-xxxxxx-AXXX-MB format
# case numbers are preceded by '50' in showcase...
# sc done
sub convertCaseNumToDisplay {
    my $casenum = shift;
	return $casenum;
}

sub citationSearch {
    my $citation = shift;
    my $caseref = shift;

    my $dbh = dbConnect($db);
    my $schema = getDbSchema($db);
    
    my $json = JSON->new->allow_nonref;

    my $query;

    if ($citation =~ /\*$/) {
        # Wildcard search
        my %citations;
        $citation =~ s/\*$//g;
        $query = qq {
            select
                CaseNumber,
                CitationNumber
            from
                $schema.vCitation with(nolock)
            where
                CitationNumber like '$citation%'
        };

        getData(\%citations,$query,$dbh,{ hashkey => "CaseNumber" });

        if (scalar(keys %citations) == 1) {
            my $casenum = (keys %citations)[0];
            print "Location:view.cgi?ucn=$casenum&amp;lev=2\n\n";
            exit;
        }

        # Now get some case details
        my @cases;
        foreach my $case (keys %citations) {
            push(@cases, "'$case'");
        }

        my $instring = "(" . join(",", @cases) . ")";

        $query = qq {
            select
                (vd.LastName + ', ' + vd.FirstName + ' ' + vd.MiddleName)
                    as FullName,
                CONVERT(varchar,FileDate,101) as FileDate,
                vc.CaseNumber,
                vc.DivisionID,
                vc.CourtType,
                vc.CaseStatus,
                vc.UCN,
                vc.CaseID
            from
                $schema.vCase vc with(nolock),
                $schema.vDefendant vd with(nolock)
            where
                vc.CaseNumber in $instring
                and vc.CaseID = vd.CaseID
            order by
                vc.CaseNumber
        };

        my %details;
        getData(\%details,$query,$dbh,{hashkey => "CaseNumber"});
        
        # Now combine the hashes
        foreach my $key (keys %citations) {
            foreach my $detail (keys %{$details{$key}}) {
                next if ($detail eq "CaseNumber");
                $citations{$key}->{$detail} = $details{$key}->{$detail};
            }
            # Convert to "old style" case numbers
            $citations{$key}->{CaseNumber} =~ s/^50-//g;
            $query = qq {
                select
                    CONVERT(varchar,max(EffectiveDate),101) as LastActivity
                from
                    $schema.vDocket with(nolock)
                where
                    CaseNumber = ?
            };
            
            my @lact;
            getData(\@lact,$query,$dbh, {valref => [$key]});
            my $lastactivity = $lact[0];
            
            $citations{$key}->{LastActivity} = $lastactivity->{LastActivity};
            
            push(@{$caseref}, $citations{$key});
        }
	} else {
		# Not a wild card - be explicit in the search. This will return at most
		# one row
		$query = qq {
			select
				CaseNumber,
				CaseID
			from
				$schema.vCitation with(nolock)
			where
				CitationNumber = ?
		};

		getData($caseref,$query,$dbh,{valref => [$citation]});
	};
}


sub getDefendantAndAddress {
    my $caseid = shift;
    my $dbh = shift;
    my $defendants = shift;
    my $pbsoconn = shift;
    my $pbsoFailed = shift;
    my $schema = shift;
    
    if (!defined($schema)) {
        $schema = $DEFAULT_SCHEMA
    };
    
    if (!defined($pbsoFailed)) {
        $pbsoFailed = 0;
    }
    
    if (!$SKIPPBSO) {
        if (!defined($pbsoconn) && (!$pbsoFailed)) {
            $pbsoconn = dbConnect("pbso2");
        }
    }

    my $query = qq {
        select
            PartyTypeDescription,
            FirstName,
            MiddleName,
            LastName,
            CONVERT(varchar(10),DOB,101) as DOB,
            CONVERT(varchar(10),DOD,101) as DOD,
            Race,
            Sex,
            CaseNumber,
            CountyID
        from
            $schema.vDefendant with(nolock)
        where
            CaseID = ?
	};

    my $defendant = getDataOne($query,$dbh,[$caseid]);

    if (!defined($defendant)) {
        return;
    }

    #getData($defendants,$query,$dbh,{valref => [$hcase]});

    if ($defendant->{'CountyID'} eq '') {
        # Don't have a jacket number.  Check PBSO for the case - perhaps they have one
        my $query = qq {
            select
                BookingSheetNumber
            from
                $schema.vArrest with(nolock)
            where
                CaseID = ?
        };

        my @bsns;
		getData(\@bsns,$query,$dbh, {valref => [$caseid]});
		if ((!$SKIPPBSO) && (scalar(@bsns) && (!$pbsoFailed))) {
			my $j = getInmateIdFromBooking($bsns[0]->{'BookingSheetNumber'},$pbsoconn);
			$defendant->{'CountyID'} = $j;
		}
	}

	# Now get the address (if there's an active/default one)
	$query = qq {
		select
			Address1,
			Address2,
			City,
			State,
			ZipCode,
			AddressType,
			PhoneNumber,
			BusinessPhone,
			PhoneCell,
			CaseNumber,
			PartyID,
			AddressActive
		from
			$schema.vDefendantAddress with(nolock)
		where
			CaseID = ?
		and 
			(AddressActive = 'Y' OR AddressActive = 'Yes') 
			
	};

	my @addresses;
	
	getData(\@addresses,$query,$dbh,{valref => [$caseid]});
	if (scalar(@addresses)) {
		# Should be no more than 1 matching record
		foreach my $key (keys %{$addresses[0]}) {
			$defendant->{$key} = $addresses[0]->{$key};
		}
	}

    # Calculate the defendant's age
    $defendant->{'Age'} = getageinyears($defendant->{'DOB'});

    # Does the defendant use any aliases?
    $defendant->{'Aliases'} = [];
    getAliases($defendant->{'Aliases'},$caseid,$dbh,$schema);

    # Get the URL of the most recent booking photo for this dft
    my $photoid = 'no conn';
    my $injail = 'no conn';
    if((!$SKIPPBSO) && (defined($pbsoconn))) {
		if($defendant->{'CountyID'} ne '') {
			# show the defendant and his/her most recent mugshot, and in
			#custody or not
			($photoid,$injail) = getMugshotWithJacketId($defendant->{'CountyID'},$pbsoconn);
		} else {
			$photoid = 'no jacket';
		}

		if ($photoid ne 'no jacket') {
			my $newpath = getBookingPhoto($photoid);
			if (defined($newpath)) {
				$photoid = $newpath;
			}
		}
    }
    $defendant->{'LastBookingPhoto'} = $photoid;
    $defendant->{'InJail'} = $injail;

    # Build address
    my $fulladdr;

    if ($defendant->{'AddressActive'} eq 'Yes' || ($defendant->{'AddressActive'} eq 'Y')) {
        $fulladdr = $defendant->{'AddressType'};

        if ($fulladdr ne "") {
            # Add a colon separator only if the PartyAddressType is defined
            $fulladdr .= ":";
        }

        if($defendant->{'Address1'} ne '') {
            $fulladdr .= "<br/>$defendant->{'Address1'}";
        }

        if($defendant->{'Address2'} ne '') {
            $fulladdr .= "<br/>$defendant->{'Address2'}";
        }

        $fulladdr.= qq{<br/>$defendant->{'City'}&nbsp;&nbsp;$defendant->{'State'}&nbsp;&nbsp;$defendant->{'ZipCode'}};

        $defendant->{'FullAddress'} = $fulladdr;
    }

    my $phones = "";
    if (($defendant->{'PhoneNumber'} eq '') and ($defendant->{'BusinessPhone'} eq '')
        and ($defendant->{'PhoneCell'} eq '')) {
        $phones = '&nbsp;';
    } else {
        if ($defendant->{'PhoneNumber'} ne '') {
            $phones .= "main: $defendant->{'PhoneNumber'}<br/>";
        }

        if ($defendant->{'BusinessPhone'} ne '') {
            $phones .= "bus: $defendant->{'BusinessPhone'}<br/>";
        }

        if ($defendant->{'PhoneCell'} ne '') {
            $phones .= "cell: $defendant->{'PhoneCell'}<br/>";
        }
    }
    $defendant->{'Phones'} = $phones;


    # Push this record onto the array of defendants - with SC Crim, there should only
    # be one per case
    push(@{$defendants}, $defendant);
}



# new with Showcase... showing aliases
sub getAliases {
    my $aliasref = shift;
    my $caseid= shift;
    my $dbh = shift;
    my $schema = shift;

	if (!defined($schema)) {
		$schema = $DEFAULT_SCHEMA
	};

    my $query = qq {
        select
            AKA
        from
            $schema.vAlias with(nolock)
        where
            CaseID = ?
    };

    getData($aliasref,$query,$dbh, {valref => [$caseid]});
}

sub showcaseNameSearch{
    my $fieldref = shift;
    my $caseref = shift;
    
    print "AND HERE!!!\n\n";
    
    my @charges;
    my $query;
    
    use Data::Dumper qw(Dumper);
    
    print Dumper $fieldref;
    
    # Temporary storage for the data
    my $temp = [];
    my %partyTemp;

    my $dbh = dbConnect($db);
    my $schema = getDbSchema($db);

    my $divLimitSearch;
    if (defined($fieldref->{'limitdiv'})) {
        my $inString = join(",", @{$fieldref->{'limitdiv'}});
        $divLimitSearch = "and c.DivisionID in ($inString) ";

        if ((defined($fieldref->{'limittype'})) && ($fieldref->{'limittype'} eq 'Traffic')) {
            $divLimitSearch = "and c.CourtType in ('CT','TR') ";
        }
    }
    
    my $causeSearch = "";
    if (defined($fieldref->{'causetype'})) {
		my $inString = join(",", @{$fieldref->{'causetype'}});
        $divLimitSearch = "and CaseType in ($inString) ";
    }
    
    # Start building the query.
    # Is it a name search?
    my $chargeJoin = "";
    my $chargeLimit = "";
    if ($fieldref->{'chargetype'}) {
        $chargeJoin = "left outer join $schema.vCharge vc with(nolock) on (c.CaseID = vc.CaseID)";
        my @conditions;
        foreach my $chapter(@{$fieldref->{'chargetype'}}) {
            my $string = sprintf("(vc.CourtStatuteNumber like '%s%%')", $chapter);
            push(@conditions,$string);
        }
        my $joinStr = join(" or ", @conditions);
        $chargeLimit = "and ($joinStr)";
    }
    
    my $nameQuery = qq {
            select
                p.LastName,
                p.FirstName,
                p.MiddleName,
                p.PartyTypeDescription,
                CASE when p.DOB is NULL
                    THEN '&nbsp;'
                    ELSE CONVERT(varchar,p.DOB,101)
                END as DOB,
                p.CaseID
	};
    
    my $from = qq {
        from
            $schema.vAllParties p with(nolock)
        where
            1=1
	};
        
    if ($fieldref->{'searchtype'} eq 'attorney') {
        $from .= qq{
            and p.PartyTypeDescription in (} .
            join(",", @attorneyTypes) . qq {)
        };
    } elsif ($fieldref->{'searchtype'} eq 'defendant') {
        $from .= qq {
            and p.PartyTypeDescription ='DEFENDANT'
        };
    } elsif ($fieldref->{'searchtype'} eq 'others') {
        my $pts = join(",", @{$fieldref->{'partyTypeLimit'}});
        $from .= qq {
            and p.PartyType in ($pts)
        }
    } 
    # LK - 1/9/17 - taking this out to search all party types?
    #else {
    #    $from .= qq {
    #        and p.PartyTypeDescription in (} .
    #        join(",", @partyTypes) . qq{)
    #    };
	#}
    
    if (defined($fieldref->{'DOB'})) {
        if ((defined($fieldref->{'fuzzyDOB'})) && ($fieldref->{'fuzzyDOB'})) {
            # A fuzzy DOB! get a 30-day range - 15 days before and 15 days after.
            my ($year, $month, $day) = split(/-/, $fieldref->{'DOB'});
            my ($syear, $smonth, $sday) = Add_Delta_Days($year, $month, $day, -15);
            my $sdate = sprintf("%04d-%02d-%02d", $syear, $smonth, $sday);
            my ($eyear, $emonth, $eday) = Add_Delta_Days($year, $month, $day, 15);
            my $edate = sprintf("%04d-%02d-%02d", $eyear, $emonth, $eday);
            $from .= qq {
                and p.DOB between '$sdate' and '$edate'
            };
        } else {
            $from .= qq {
                and p.DOB = '$fieldref->{DOB}'
            };
        }
    }

		my $nameOrderBy = qq {
			order by
				p.LastName,
				p.FirstName,
				p.MiddleName
		};
		
		if ($fieldref->{'nametype'} eq "firstandlast") {
			if (defined($fieldref->{'last2'})) {
                # Strip spaces for soundex searches.
                my $first = $fieldref->{'first'};
                $first =~ s/\s+//g;
                my $last = $fieldref->{'last2'};
                $last = s/\s+//g;

				# This is only defined in the case of a wildcard search
				if (length($fieldref->{'last2'}) < 1) {
					# Search all last names
					if ($fieldref->{'soundex'} == 1) {
						$query = qq {
                            $from
                            and (p.FirstNameSoundEx = soundex ('$first') or p.CurrentFirstNameSoundEx = soundex ('$first')) };
					} else {
						$query = qq {
                            $from
                            and p.FirstName like '$fieldref->{first}%' };
					}
				} else {
					if ($fieldref->{'soundex'} == 1) {
						$query = qq {
                            $from
                            and (p.LastNameSoundEx  = soundex('$last') or p.CurrentLastNameSoundEx = soundex('$last'))
                            and (p.FirstNameSoundEx = soundex('$first') or p.CurrentFirstNameSoundEx = soundex('$first')) 
                    	};
					} else {
						$query = qq {
                            $from
                            and p.LastName like '$fieldref->{last2}%'
                            and p.FirstName like '$fieldref->{first}%' 
                    	};
                    	
                    	if (defined($fieldref->{'middle'})) {
                    		$query .= " and p.MiddleName like '$fieldref->{middle}%' ";
                    	}
					}
				}
			} else {
                # Strip spaces for soundex searches.
                my $first = $fieldref->{'first'};
                $first =~ s/\s+//g;
                my $last = $fieldref->{'last'};
                $last =~ s/\s+//g;

				if ($fieldref->{'soundex'} == 1) {
					$query = qq {
                        $from
                        and  (p.LastNameSoundEx = soundex('$last') or p.CurrentLastNameSoundEx = soundex('$last'))
                        and (p.FirstNameSoundEx = soundex('$first') or p.CurrentFirstNameSoundEx = soundex('$first')) };
				} else {
					$query = qq{
                        $from
                        and p.LastName = '$fieldref->{last}' and p.FirstName like '$fieldref->{first}%' 
                    };
                        
                	if (defined($fieldref->{'middle'})) {
                    	$query .= " and p.MiddleName like '$fieldref->{middle}%' ";
                    }        
				}
			}

			# End of firstlast Search
		} else {
			if(defined($fieldref->{'name2'})) {
                # Strip spaces for soundex searches.
                my $name2 = $fieldref->{'name2'};
                $name2 =~ s/\s+//g;

				if ($fieldref->{'soundex'} == 1) {
					$query = qq {
                        $from
                        and (p.LastNameSoundEx = soundex('$name2') or p.CurrentLastNameSoundEx = soundex('$name2')) };
				} else {
					$query = qq {
                        $from
                        and p.LastName like '$fieldref->{name2}%' };
				}
			} else {
                my $name = $fieldref->{'name'};
                $name =~ s/\s+//g;

                if ($fieldref->{'soundex'} == 1) {
                    $query = qq {
                        $from
                        and (p.LastNameSoundEx = soundex('$name') or p.CurrentLastNameSoundEx = soundex('$name')) };
                } else {
                    $query = qq {
                        $from
                        and p.LastName = '$fieldref->{name}' };
                }
			}

			if ($fieldref->{'business'} == 1) {
				$query .= " and p.FirstName is null ";
			}
		}

		$query .= $nameOrderBy;
	
		getData(\%partyTemp,$nameQuery.$query,$dbh,{hashkey => "CaseID"});
		
		my @tempCases;
		foreach my $case (keys %partyTemp) {
            push(@tempCases, "'$case'");
        }
        
		if(scalar(@tempCases)){
			my $caseStr = "CaseID IN (" . join(",", @tempCases) . ") ";
			
			my $caseQuery = qq{
				SELECT 
					c.UCN,
		            c.CaseNumber,
		            c.CaseID,
		            CONVERT(varchar,c.FileDate,101) as FileDate,
		            ISNULL(c.CaseType,'&nbsp;') as CaseType,
		            c.CaseStatus,
					ISNULL(c.DivisionID,'&nbsp;') as DivisionID,
					c.CaseID
				FROM 
					$schema.vCase c with(nolock)
					$chargeJoin
				WHERE
		            1=1
		            AND c.Expunged = 'N'
		            AND $caseStr
		            $divLimitSearch $chargeLimit $causeSearch
			};
			
			if (defined($fieldref->{'searchStart'})) {
		        if (!defined($fieldref->{'searchEnd'})) {
		            $fieldref->{'searchEnd'} = ISO_date(today());
		        }
		        $caseQuery .= qq {
		            AND FileDate BETWEEN '$fieldref->{searchStart}' AND '$fieldref->{searchEnd}'
		        }
		    }
			
			if ($fieldref->{'active'} == 1) {
				$caseQuery .= $activePhrase;
			}
	
			if ($fieldref->{'criminal'} == 1) {
				$caseQuery .= $criminalPhrase;
			}
	
			my @exclusions;
			if (!($fieldref->{'sealeduser'})) {
				push(@exclusions,$excludeSealed);
			}
	
			if ($fieldref->{'jsealeduser'}) {
				push(@exclusions,$showjSealed);
			}
			
			if ($fieldref->{'psealeduser'}) {
				push(@exclusions,$showpSealed);
			}
	
			if (scalar(@exclusions)) {
				$caseQuery .= "and (" . join (" or ", @exclusions) . ")";
			}
	
			if (!($fieldref->{'secretuser'})) {
				$caseQuery .= $excludeSecret;
			}
	
			if (!$fieldref->{'secretuser'}) {
				$caseQuery .= $excludeSecret;
			}
			
			$caseQuery .= " ORDER BY c.UCN";
			my %caseTemp;
			getData(\%caseTemp,$caseQuery,$dbh,{hashkey => "CaseID"});
	
			foreach my $case (keys %caseTemp) {
	            foreach my $party (keys %partyTemp) {
	            	if($case eq $party){
	            		my $tempHash = {};
	            		$tempHash->{'UCN'} = $caseTemp{$case}->[0]->{'UCN'};
	            		$tempHash->{'CaseNumber'} = $caseTemp{$case}->[0]->{'CaseNumber'};
	            		$tempHash->{'CaseID'} = $caseTemp{$case}->[0]->{'CaseID'};
	            		$tempHash->{'FileDate'} = $caseTemp{$case}->[0]->{'FileDate'};
	            		$tempHash->{'CaseType'} = $caseTemp{$case}->[0]->{'CaseType'};
	            		$tempHash->{'CaseStatus'} = $caseTemp{$case}->[0]->{'CaseStatus'};
	            		$tempHash->{'DivisionID'} = $caseTemp{$case}->[0]->{'DivisionID'};
	            		$tempHash->{'LastName'} = $partyTemp{$case}->[0]->{'LastName'};
	            		$tempHash->{'FirstName'} = $partyTemp{$case}->[0]->{'FirstName'};
	            		$tempHash->{'MiddleName'} = $partyTemp{$case}->[0]->{'MiddleName'};
	            		$tempHash->{'PartyTypeDescription'} = $partyTemp{$case}->[0]->{'PartyTypeDescription'};
	            		$tempHash->{'DOB'} = $partyTemp{$case}->[0]->{'DOB'};
	            		push(@{$temp}, $tempHash);
	            	}
	            }
	        }
    	}
        
    my $pbsodbh = undef;
	my %inmates;
	if (($fieldref->{'photos'} == 1) && (!$SKIPPBSO)) {
		# Make the PBSO connection at this point if we need to get photos, instead of repeatedly
		# connecting and disconnecting
		$pbsodbh = dbConnect("pbso2",undef,1);
		if ($pbsodbh) {
			getInmateIds(\%inmates,$temp,$dbh,$pbsodbh,$schema);
		}
	}
	foreach my $case (@{$temp}) {
		$case->{'AGE'} = getageinyears($case->{'DOB'});
		$case->{'ChargeCase'} = $case->{'CaseNumber'};

		# Populate the full name at this time, if it exists.  We'll need
		# it later.
        if (defined($case->{'LastName'})) {
            $case->{'Name'} = buildName($case,1);
            #$case->{'Name'} = "$case->{LastName}, $case->{FirstName}";
            #if ((defined($case->{'MiddleName'})) && ($case->{'MiddleName'} ne "")) {
            #    $case->{'Name'} .= " $case->{MiddleName}";
            #}
        }
		
		# Are there open warrants for the case?
		my $query = qq {
			select
				WarrantNumber
			from
				$schema.vWarrant with(nolock)
			where
				CaseID = ?
				and Closed = 'N'
		};

		my @temp;
		getData(\@temp,$query,$dbh,{valref => [$case->{'CaseID'}]});
		$case->{OpenWarrants} = scalar(@temp) ? 1 : 0;

		# Photos?
		$case->{'Photo'} = "&nbsp;";
		if ($fieldref->{'photos'} == 1) {
			if ($case->{'PartyTypeDescription'} =~ /DEFENDANT/) {
				my $j = $inmates{$case->{'ChargeCase'}}->{'InmateId'};
				if (defined($j)) {
					my $mug = get_mugshot_incustody_usingInmateId($j,$pbsodbh);
					my ($photoid,$jailed) = split ';',$mug;

					if ($photoid =~ /no/) {
						$case->{'Photo'} = "n/a";
					} else {
						my $newpath = getBookingPhoto($photoid);
						if (defined($newpath)) {
							$photoid = $newpath;
						}
						$case->{'Photo'} = qq{<a href="$photoid"><img alt="most recent photo" src="$photoid" width="36" height="46"></a><br/>};
					}
				} else {
					$case->{'Photo'} = "n/a";
				}
			}
		}

		# Get the last activity date for the case
		my $aquery = qq {
			select
				max(EffectiveDate) as MaxEffectiveDate
			from
				$schema.vDocket with(nolock)
			where
				CaseID = ?
		};

		my $med = getDataOne($aquery,$dbh,[$case->{'CaseID'}]);

		$case->{'LACTIVITY'} = changeDate($med->{'MaxEffectiveDate'});

		# Get charge information for this case
		my @charges;
		if ($fieldref->{'charges'} == 1 || ($fieldref->{'charges'} eq "on")) {
			$query = qq {
				select
					CourtStatuteDescription
				from
					$schema.vCharge ch with(nolock)
				where
					ch.CaseID = ?
			};

			getData(\@charges,$query,$dbh,{valref => [$case->{'CaseID'}]});
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
		#$case->{'CaseNumber'} =~ s/^50-//g;
		push(@{$caseref}, $case);
	}
}


sub showcaseSearch {
   my $fieldref = shift;
   my $caseref = shift;
   
	my @charges;
	my $query;
   
   my $sancasenum = sanitizeCaseNumber($fieldref->{'name'});
	
	my $dbh = dbConnect($db);
   my $schema = getDbSchema($db);

	# Temp storage for data
	my $temp = [];
    
    my $divLimitSearch;
    if (defined($fieldref->{'limitdiv'})) {
        my $inString = join(",", @{$fieldref->{'limitdiv'}});
        $divLimitSearch = "and c.DivisionID in ($inString) ";

        if ((defined($fieldref->{'limittype'})) && ($fieldref->{'limittype'} eq 'Traffic')) {
            $divLimitSearch = "and c.CourtType in ('CT','TR') ";
        }
    }
    
    my $causeSearch = "";
    if (defined($fieldref->{'causetype'})) {
		my $inString = join(",", @{$fieldref->{'causetype'}});
        $divLimitSearch = "and CaseType in ($inString) ";
    }
    
    if (defined(sanitizeCaseNumber($fieldref->{'name'}))) {

		# Case Number Search
		#
		# looking for exact match.

		#my $casenum=$fieldref->{'name'};
      my $casenum = sanitizeCaseNumber($fieldref->{'name'});
		$casenum =~ s/-//g;
		if ($casenum !~ /^50/) {
			$casenum="50".$casenum;
		}
      
		$query = qq {
			select
				NULL as CaseStyle,
                p.LastName,
				p.FirstName,
				p.MiddleName,
				c.UCN,
				c.CaseNumber,
				CONVERT(varchar,c.FileDate,101) as FileDate,
				c.CaseType,
				c.CaseStatus,
                p.PartyTypeDescription,
                CASE when p.DOB is NULL
                    THEN '&nbsp;'
                    ELSE CONVERT(varchar,p.DOB,101)
                END as DOB,
				c.DivisionID,
				c.CaseID
			from
                $schema.vCase c with(nolock) left outer join $schema.vDefendant p with(nolock) on c.CaseID = p.CaseID
			where
		};
		if (length($casenum) == 20) {
			$query .= qq{
				c.UCN = '$casenum'
			};
		} else {
			$query .= qq{
				c.UCN like '$casenum%'
			};
		}
		
		$query .= " AND c.Expunged = 'N' ";

		if ($fieldref->{'active'} == 1) {
			$query .= $activePhrase;
		}

		if ($fieldref->{'criminal'} == 1) {
			$query .= $criminalPhrase;
		}

		my @exclusions;
		if (!($fieldref->{'sealeduser'})) {
			push(@exclusions,$excludeSealed);
			
			if ($fieldref->{'jsealeduser'}) {
				push(@exclusions,$showjSealed);
			}
			
			if ($fieldref->{'psealeduser'}) {
				push(@exclusions,$showpSealed);
			}
		}

		if (scalar(@exclusions)) {
			$query .= "and (" . join (" or ", @exclusions) . ")";
		}

		if (!($fieldref->{'secretuser'})) {
			$query .= $excludeSecret;
		}

		if (!($fieldref->{'secretuser'})) {
			$query .= $excludeSecret;
		}

		getData($temp,$query,$dbh);
      
		if (scalar(@{$temp}) == 1) {
         # We have a single match.  Redirect to scview.
         my $c = $temp->[0]->{'CaseNumber'};
         my $d = $temp->[0]->{'CaseID'};
         my $output = getScCaseInfo($c, $d);
         my $info = new CGI;
         print $info->header;
         print $output;
		}
	} elsif ($fieldref->{'name'}=~/(\d+)(\D+)(\d+)(\*)/ ||
			 $fieldref->{'name'}=~/(\d+)(\D+)(\d+)(\D+){0,3}/ ) {        
		my ($year, $type, $seq, $suffix);

		my $casenum;

		if ($fieldref->{'name'} =~ /^50/) {
			$fieldref->{'name'} =~ s/^50//g;
		}

		if ($fieldref->{'name'}=~/(\d+)(\D+)(\d+)(\*)/) {
			# Searches for yyyyttd* (NO PADDING ZEROS HERE!!)
			# Wildcard search on case number - yyyyttd*
			$year = $1;
			$type = $2;
			$seq = $3;
			$year = fixyear($year);
			# Be sure to convert to uppercase
			$casenum = uc(sprintf("50%04d%s%s",$year,$type,$seq));
		} else {
			# Wildcard search on case number - yyyyttdddddd
			# (padding dddddd with leading zeroes as needed)
			$year = $1;
			$type = $2;
			$seq = $3;
			$suffix = $4;
			$suffix =~ s/-//g;
			$year = fixyear($year);
			# Be sure to convert them to uppercase
			$casenum = uc(sprintf("50%04d%s%06d%s", $year, $type, $seq, $suffix));
		}

		$query = qq {
			select
				NULL as CaseStyle,
                p.LastName,
				p.FirstName,
				p.MiddleName,
				c.UCN,
				c.CaseNumber,
				CONVERT(varchar,c.FileDate,101) as FileDate,
				c.CaseType,
				c.CaseStatus,
                p.PartyTypeDescription,
				CONVERT(varchar,p.DOB,101) as DOB,
				c.DivisionID,
				c.CaseID
			from
                $schema.vCase c with(nolock) left outer join $schema.vDefendant p with(nolock) on c.CaseID = p.CaseID
            where
		};

		if (length($casenum) == 20) {
			$query .= qq{
				c.UCN = '$casenum'
			};
		} else {
			$query .= qq{
				c.UCN like '$casenum%'
			};
		}
		
		$query .= " AND c.Expunged = 'N' ";

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
		
		if ($fieldref->{'psealeduser'}) {
			push(@exclusions,$showpSealed);
		}

		if (scalar(@exclusions)) {
			$query .= "and (" . join (" or ", @exclusions) . ")";
		}

		if (!($fieldref->{'secretuser'})) {
			$query .= $excludeSecret;
		}

        $query .= $divLimitSearch;
        
        getData($temp, $query, $dbh);
        
        if (scalar(@{$temp}) == 1) {
            my $c = $temp->[0]->{'CaseNumber'};
            my $d = $temp->[0]->{'CaseID'};
            $c = substr($c,3);
            # We have a single match.  Redirect to scview.
            print "Location: view.cgi?ucn=$c&caseid=$d&lev=2\n\n";
            exit;
        }
    } else {
            print "Content-type: text/html\n\n";
            print "Wrong format used for the name or case number - couldn't ".
            "understand '$fieldref->{name}'.<p>\n";
            exit;
	}

   
	my $pbsodbh = undef;
	my %inmates;
	if (($fieldref->{'photos'} == 1) && (!$SKIPPBSO)) {
		# Make the PBSO connection at this point if we need to get photos, instead of repeatedly
		# connecting and disconnecting
		$pbsodbh = dbConnect("pbso2",undef,1);
		if ($pbsodbh) {
			getInmateIds(\%inmates,$temp,$dbh,$pbsodbh,$schema);
		}
	}
	foreach my $case (@{$temp}) {
		$case->{'AGE'} = getageinyears($case->{'DOB'});
		$case->{'ChargeCase'} = $case->{'CaseNumber'};

		# Populate the full name at this time, if it exists.  We'll need
		# it later.
        if (defined($case->{'LastName'})) {
            $case->{'Name'} = buildName($case,1);
            #$case->{'Name'} = "$case->{LastName}, $case->{FirstName}";
            #if ((defined($case->{'MiddleName'})) && ($case->{'MiddleName'} ne "")) {
            #    $case->{'Name'} .= " $case->{MiddleName}";
            #}
        }
		
		# Are there open warrants for the case?
		my $query = qq {
			select
				WarrantNumber
			from
				$schema.vWarrant with(nolock)
			where
				CaseID = ?
				and Closed = 'N'
		};

		my @temp;
		getData(\@temp,$query,$dbh,{valref => [$case->{'CaseID'}]});
		$case->{OpenWarrants} = scalar(@temp) ? 1 : 0;

		# Photos?
		$case->{'Photo'} = "&nbsp;";
		if ($fieldref->{'photos'} == 1) {
			if ($case->{'PartyTypeDescription'} =~ /DEFENDANT/) {
				my $j = $inmates{$case->{'ChargeCase'}}->{'InmateId'};
				if (defined($j)) {
					my $mug = get_mugshot_incustody_usingInmateId($j,$pbsodbh);
					my ($photoid,$jailed) = split ';',$mug;

					if ($photoid =~ /no/) {
						$case->{'Photo'} = "n/a";
					} else {
						my $newpath = getBookingPhoto($photoid);
						if (defined($newpath)) {
							$photoid = $newpath;
						}
						$case->{'Photo'} = qq{<a href="$photoid"><img alt="most recent photo" src="$photoid" width="36" height="46"></a><br/>};
					}
				} else {
					$case->{'Photo'} = "n/a";
				}
			}
		}

		# Get the last activity date for the case
		my $aquery = qq {
			select
				max(EffectiveDate) as MaxEffectiveDate
			from
				$schema.vDocket with(nolock)
			where
				CaseID = ?
		};

		my $med = getDataOne($aquery,$dbh,[$case->{'CaseID'}]);

		$case->{'LACTIVITY'} = changeDate($med->{'MaxEffectiveDate'});

		# Get charge information for this case
		my @charges;
		if ($fieldref->{'charges'} == 1) {
			$query = qq {
				select
					CourtStatuteDescription
				from
					$schema.vCharge ch with(nolock)
				where
					ch.CaseID = ?
			};

			getData(\@charges,$query,$dbh,{valref => [$case->{'CaseID'}]});
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
		$case->{'CaseNumber'} =~ s/^50-//g;
		push(@{$caseref}, $case);
	}
}

sub scGetDocketItems {
    my $ucn = getDocketItems(@_);
    
    return $ucn;
}

sub getDocketItems {
    # Get a list of docket items (not the images - just a list)
    # A reference to an existing CGI object - we need information on the
    # parameters
    my $info = shift;
    
    # A reference to the information on each object
    my $docketList = shift;
    
    my $dbh = shift;
    my $schema = shift;
    
    if (!defined($schema)) {
    	$schema = $DEFAULT_SCHEMA
    };
    
    # Subselect strings to be used for selecting appropriate rows
    my $cmsDocSelect = "";

    my $ucn;
    my $objid;
    my $caseid = $info->param("caseid");
    
    if(!defined($caseid)){
    	$caseid = getCaseID($info->param('casenum'));
    }

    if (!(defined($info->param("showmulti")))) {
        # Request for a single image
        my $objid = $info->param("objid");

        $cmsDocSelect = " CaseID='$caseid' and ObjectID = '$objid' ";
    } else {
        # Request for multiple checked images
        my @selected = $info->param("selected");
        if (!scalar(@selected)) {
            print $info->header();
            print "No docket items were selected.  Please try again.";
            exit;
        }
        
        my @objids;
        
        foreach my $item (@selected) {
            ($ucn, $objid) = split(/\|/, $item);
            push(@objids, $objid);
        }
        
        $cmsDocSelect = " CaseID=$caseid and ObjectID in (" . join(",", @objids) .") ";
    }
    
    if (!defined($dbh)) {
        $dbh=dbConnect($db);
    }
    
    if (!$dbh) {
        print $info->header();
        print "Sorry; can't connect to the images server...";
        exit;
    }
    
    my $query = qq {
        select
            CaseNumber,
            UCN,
            LegacyCaseNumber,
            SeqPos,
            DocketDescription,
            CONVERT(varchar(10),EffectiveDate,101) as EffectiveDate,
            ObjectId
        from
            $schema.vDocket with(nolock)
        where
            $cmsDocSelect
        order by
            SeqPos desc
    };
    
    getData($docketList,$query,$dbh);
    
    # Strip out bad characters from the description
    foreach my $image (@{$docketList}) {
    	$image->{'DocketDescription'} =~ s/[\@#]//g;
    }

    #my @temp;
    #foreach my $doc (@docketList) {
    #    push(@temp,$doc->{ObjectId});
    #}
    
    #my $selStr = " object_id in (".	join(",", @temp) . ")";
    
    #getDocketList($docketList,$selStr);
    
    #foreach my $image (@{$docketList}) {
    #    # Get the sequence ID to match it with the sequence ID in @docketItems
    #    my $seq_id = (split(/\|/, $image->{'cms_document_id'}))[1];
        
    #    foreach my $item (@docketItems) {
    #        next if ($item->{'ObjectId'} != $image->{'object_id'});
    #        # If we're here, we have a match
    #        $image->{'code'} = $item->{'DocketDescription'};
    #        $image->{'date'} = $item->{'EffectiveDate'};
    #        last;
    #    }
    #}
    
    return $ucn;
}


sub buildTMImageList {
    my $images = shift;
    my $docref = shift;
    my $showTif = shift;
    
    # The file to keep the information on the list of files used (boy, that
    # sure sounds convoluted).
    my $listfh = new File::Temp (
                                 UNLINK => 0,
                                 DIR => "/tmp"
                                 );
    my $listfn = $listfh->filename;
    
    my $pages = 1;

    foreach my $image (@{$images}) {
        my $objid = $image->{'object_id'};
        
        my $path = getImageFromServer($objid);
            
        if (! defined($path)) {
            next;
        } elsif ($path eq "TIMEOUT") {
            # We got a timeout retrieving images from the server.
            # Since further attempts for other images will just make
            # the system crawl, bail out and don't display anything
            return "TIMEOUT";
        }
            
        if ((defined($showTif)) && ($showTif)) {
            # Just create a symlink to the original and redirect the user.
            my $basefile = basename($path) . ".tif";
            if (!-e "/var/www/html/tmp/$basefile") {
                symlink($path,"/var/www/html/tmp/$basefile");
            }
            print "Location: http://$ENV{'HTTP_HOST'}/tmp/$basefile\n\n";
            exit;
        }
        
        my $xname = $path;
        my $tmpPath = "$xname.pdf";
            
        my %pdfdoc;
        
        createPDF($tmpPath,$path,\%pdfdoc);
        
        push (@{$docref}, {
                           file => $tmpPath,
                           page => $pages,
                           code => $image->{'code'},
                           date => $image->{'date'}
                           }
              );
        $pages += $pdfdoc{'pagecount'};
        print $listfh "$tmpPath\n";
    }
    close ($listfh);
    return $listfn;
}


sub getImageFromServer {
    my $objid = shift;

    my %first;
    my @bytes;

    my $url = "https://vcp02xweb.clerk.local/Services/SoptunnaService/".
		"Service.svc?wsdl";
    my $uri = 'http://tempuri.org/';

    # Setup Network Connection
    my $soap = SOAP::Lite
	-> uri($uri)
	-> on_action(sub { sprintf '%sIService/%s', @_ })
	-> proxy($url)
	-> autotype(0)
	-> readable(1);

    my $header = SOAP::Header->name(MyHeader => {
		MyName => "TIS"}
									)->uri('http://tempuri.org/')->prefix('');

	my $method = SOAP::Data->name('RetrieveDocument')
	->attr({xmlns => 'http://tempuri.org/'});

	my @params = ( $header,
				  SOAP::Data->name(ObjectID => $objid ),
				  SOAP::Data->name(UserID => "SVCCTADMIN") );

	my $result;

	eval {
		local $SIG{ALRM} = sub { die "timeout\n" };
		alarm 20;

		$result = $soap->call($method => @params);
		alarm 0;
	};

    if ($@) {
		if ($@ =~ /timeout/) {
			print STDERR "Image ID '$objid' TIMEOUT on retrieval\n";
			return "TIMEOUT";
		} else {
			print "There was an error retrieving the image from the TrakMan service.  Please try again later.\n";
			exit;
		}
    }

    # get the results - because RetrieveDocument returns a Document
    # object, which has
    # several output parameters:
    # FileContents, FilePath, FileType, PageCnt, Response
    # more test code...
    unless ($result->fault) {
		my $response=$result->valueof('//Response');


		if ($response eq 'Success') {
			@bytes = $result->valueof('//FileContents');

			if (!defined($bytes[0])) {
				print "Content-type: text/html\n\n";
				print "This item is too large to be retrieved from the image server.  Please contact ";
				print "the clerk's office for the physical document.<br><br>";
				print "We apologize for any inconvenience this may cause.";
				exit;
			}

			my $decoded2 = decode_base64(decode_base64($bytes[0]));

			# This should be a unique filename to prevent race conditions
			# and different users stomping on each other's images.
			# Automatically unlink the temp file when it goes out of scope
			# (it has already been converted to PDF at that point)
			#my $fh = File::Temp->new(
			#	UNLINK => 0,
			#	DIR => "/tmp"
			#);
			#
			#my $filename = $fh->filename;
			#print $fh $decoded2;
			#close $fh;
			my $filename = "/tmp/$objid.tif";
			open(TIF, ">$filename");
			print TIF $decoded2;
			close TIF;

			# since we think the file is a tif file...

			if($result->valueof('//FileType') eq 'TIF') {
				return $filename;
			} else {
				return undef;
			}
		} elsif ($response eq "AccessDenied") {
			print "Content-type: text/html\n\n";
			print "Access to view this image has been denied.<br>\n";
			exit;
		} else {
			return undef;
		}
	}
    return undef;
}


sub getLinkedCases {
    # Get a list of cases linked to this one.  Not the same thing as a
    # case being for the same defendant - linking is for things like appeals
    my $caseid = shift;
    my $dbh = shift;
    my $linkedRef = shift;
	my $schema = shift;

	if (!defined($schema)) {
		$schema = $DEFAULT_SCHEMA
	};

	my %linkedCases;
    my @lCases;
    my $query = qq {
		select 
			CASE WHEN ToCaseID = ?
				THEN FromCaseID
				ELSE ToCaseID
			END AS ToCaseID
		from
		    $schema.vLinkedCases l with(nolock)
		where
		    FromCaseID = ?
		    OR ToCaseID = ?
	};
	
	getData(\%linkedCases, $query, $dbh, {valref => [$caseid, $caseid, $caseid], hashkey => 'ToCaseID'});
	
	foreach my $c (keys %linkedCases){
		push(@lCases, "'$c'");
	}
	
	if(scalar(@lCases)){
		my $caseStr = "CaseID IN (" . join(",", @lCases) . ") ";
		
		my $moreInfoQuery = qq {
			SELECT c.CaseNumber AS ToCaseNumber,
				c.CaseType,
				c.CaseStatus,
				CONVERT(varchar, c.FileDate, 101) as FileDate,
				c.CaseStyle,
				DivisionID,
				CaseID
			FROM $schema.vCase c with(nolock)
			WHERE
				$caseStr
		};
		
		getData($linkedRef, $moreInfoQuery, $dbh);
	}
	
	foreach my $lc (@{$linkedRef}){
		my $query = qq {
			select
				WarrantNumber
			from
				$schema.vWarrant with(nolock)
			where
				CaseID = ?
				and Closed = 'N'
		};

		my @temp;
		getData(\@temp, $query, $dbh, {valref => [$lc->{'CaseID'}]});
		$lc->{'OpenWarrants'} = scalar(@temp) ? 1 : 0;
	}
}


sub getArrests {
    # case here is the one with hyphens!
    my $caseid = shift;
    my $dbh = shift;
    my $arrestRef = shift;
    my $schema = shift;
    
    if (!defined($schema)) {
        $schema = $DEFAULT_SCHEMA
    };
    
    my $query = qq {
        select
            BookingSheetNumber,
            CONVERT(varchar,ArrestDate,101) as ArrestDate,
            CountyID
        from
            $schema.vArrest with(nolock)
        where
            CaseID = ?
        order by
            ArrestDate desc
    };
    
    getData($arrestRef,$query,$dbh,{valref => [$caseid]});
}


sub getWarrants {
    my $caseid = shift;
    my $dbh = shift;
    my $warrantRef = shift;
    my $schema = shift;
    
    if (!defined($schema)) {
        $schema = $DEFAULT_SCHEMA
    };
    
    my $query = qq {
        select
            WarrantNumber,
            WarrantTypeDesc,
            CONVERT(varchar,CreateDate,101) as CreateDate,
            CONVERT(varchar,ModifyDate,101) as ModifyDate,
            CONVERT(varchar,ArrestDate,101) as ArrestDate,
            CONVERT(varchar,IssueDate,101) as IssueDate,
            CONVERT(money,BondAmount) as BondAmount,
            WarrantActionClosed,
            ActionCode,
            CONVERT(varchar,ActionDate,101) as ActionDate,
            AgencyName,
            Closed
        from
            $schema.vWarrant with(nolock)
        where
            CaseID = ?
        order by
            CreateDate desc
    };
    getData($warrantRef,$query,$dbh,{valref => [$caseid]});
}


sub getBonds {
    my $caseid = shift;
    my $dbh = shift;
    my $bondRef = shift;
    my $schema = shift;
    
    if (!defined($schema)) {
        $schema = $DEFAULT_SCHEMA
    };
    
    my $query = qq {
        select
            ArrestNumber,
            ISNULL(CONVERT(money,BondAmount),CONVERT(money,0)) as BondAmount,
            BondNumber,
            BondType,
            SuretyCompany,
            BondAgent,
            CONVERT(varchar,IssueDate,101) as IssueDate,
	    CONVERT(varchar,ForfeitureDate,101) as ForfeitureDate,
	    CONVERT(varchar,ClosedDate,101) as ClosedDate,
            ChargeCount
        from
            $schema.vBond with(nolock)
        where
            CaseID = ?
        order by
            IssueDate desc
	};

	getData($bondRef,$query,$dbh,{valref => [$caseid]});
}


sub getCharges {
    # case here is the one with hyphens!
    my $caseid = shift;
    my $dbh = shift;
    my $chargeRef = shift;
    my $schema = shift;
    
    if (!defined($schema)) {
        $schema = $DEFAULT_SCHEMA
    };
    
    my $query = qq {
        select
            ChargeCount,
            SACourtStatuteDescription AS CourtStatuteDescription,
            CourtStatuteLevel,
            CourtStatuteNumber,
            CASE CourtStatuteDegree
                WHEN 'F' THEN '1'
                WHEN 'S' THEN '2'
                WHEN 'T' THEN '3'
                ELSE CourtStatuteDegree
            END as CourtStatuteDegree,
            CitationNumber,
            CONVERT(varchar,ChargeDate,101) as ChargeDate,
            CourtAction,
            CASE 
            	WHEN Disposition IS NOT NULL AND Disposition <> ''
            		THEN Disposition
            	WHEN (Disposition IS NULL OR Disposition = '') AND (CourtAction <> '' AND CourtAction IS NOT NULL)
            		THEN CourtAction
            	WHEN (CourtAction IS NULL OR CourtAction = '') AND (ProsecutorAction <> '' AND ProsecutorAction IS NOT NULL)
            		THEN ProsecutorAction
            	ELSE ''
            END AS Disposition,
            CONVERT(varchar,DispositionDate,101) as DispositionDate,
            CONVERT(varchar,PleaDate,101) as PleaDate,
            Plea,
            CONVERT(varchar,CourtDecisionDate,101) as CourtDecisionDate,
            Sentence,
            SentenceStatus,
            CONVERT(varchar,SentenceEffectiveDate,101) as SentenceEffectiveDate
        from
            $schema.vCharge with(nolock)
        where
            CaseID = ?
        order by
            ChargeCount asc
    };
    
    getData($chargeRef,$query,$dbh,{valref => [$caseid]});
    
    return;
    
    my @citations;
    
    foreach my $charge (@{$chargeRef}) {
        # Check to see if we have statutes for all of the charges; if we don't,
        # use the citation number (if we have it) to look up what we need
        
        # First, strip leading/trailing space.
        $charge->{'CourtStatuteNumber'} =~ s/^\s+//g;
        $charge->{'CourtStatuteNumber'} =~ s/\s+$//g;
        $charge->{'CitationNumber'} =~ s/^\s+//g;
        $charge->{'CitationNumber'} =~ s/\s+$//g;
        if ($charge->{CourtStatuteNumber} eq "") {
            if ($charge->{CitationNumber} ne "") {
                $query = qq {
                    select
                        vc.StatuteNumber as CourtStatuteNumber,
                        vc.AggressiveDriving,
                        vc.CommercialDL,
                        CASE vc.ActualSpeed
                            WHEN 0 THEN null
                            ELSE vc.ActualSpeed
                        END as ActualSpeed,
                        CASE vc.PostedSpeed
                            WHEN 0 THEN null
                            ELSE vc.PostedSpeed
                        END as PostedSpeed,
                        vs.StatuteDescription as CourtStatuteDescription,
                        vs.StatuteLevel as CourtStatuteLevel,
                        vs.StatuteDegree as CourtStatuteDegree
                    from
                        $schema.vCitation vc with(nolock) left outer join $schema.vStatutes vs with(nolock) on vc.StatuteNumber=vs.StatuteNumber
                    where
                        vc.CitationNumber = ?
                };
                
                my $statutes = getDataOne($query,$dbh,[$charge->{'CitationNumber'}]);
                
                if (scalar(keys(%{$statutes}))) {
                    foreach my $key (keys %{$statutes}) {
                        $charge->{$key} = $statutes->{$key}
                    }
                    if (defined($charge->{'ActualSpeed'})) {
                        $charge->{'SpeedDiff'} = $charge->{'ActualSpeed'} - $charge->{'PostedSpeed'}
                    }
                }
            }
        } else {
            if ($charge->{CitationNumber} ne "") {
                push(@citations, "'$charge->{CitationNumber}'");
            }
        }
    }
    
    # Do we have citations where we need to look up the AggressiveDriving?
    if (scalar(@citations)) {
        my $citationString = join(",", @citations);
        $query = qq {
            select
                AggressiveDriving,
                CommercialDL,
                CASE ActualSpeed
                    WHEN 0 THEN null
                    ELSE ActualSpeed
                END as ActualSpeed,
                CASE PostedSpeed
                    WHEN 0 THEN null
                    ELSE PostedSpeed
                END as PostedSpeed,                       
                CitationNumber
            from
                $schema.vCitation with(nolock)
            where
                CitationNumber in ($citationString)
        };
        
        my @aggressive;
        getData(\@aggressive,$query,$dbh);
        
        # Now go through them and add them to the appropriate charge value
        foreach my $agg (@aggressive) {
            foreach my $charge (@{$chargeRef}) {
                next if ($charge->{'CitationNumber'} ne $agg->{'CitationNumber'});
                foreach my $key (keys %{$agg}) {
                    $charge->{$key} = $agg->{$key}
                }
                if (defined($charge->{'ActualSpeed'})) {
                    $charge->{'SpeedDiff'} = $charge->{'ActualSpeed'} - $charge->{'PostedSpeed'}
                }
                
                last;
            }
        }
    }
}


sub getCourtEvents {
    my $caseid = shift;
    my $dbh = shift;
    my $events = shift;
    my $schema = shift;
    my $startDate = shift;

    if (!defined($schema)) {
        $schema = $DEFAULT_SCHEMA
    };
    
    my @args = ($caseid);
    
    my $dateStr = "";
    if (defined($startDate)) {
        $startDate = ISO_date($startDate);
        $dateStr = " AND cast(CourtEventDate as DATE) >=  cast(? as DATE)";
        push(@args, $startDate);
    }

    my $query = qq {
        select
            CONVERT(varchar,CourtEventDate,101) as EventDate,
            CourtEventType,
            CourtLocation,
            CourtRoom,
            CONVERT(varchar,CAST(CourtEventDate as time),100) as CourtEventTime,
            CONVERT(varchar,CreateDate,101) as DocketDate,
            CourtEventNotes,
            JudgeName,
            CASE Cancelled
                WHEN 'Yes' THEN 'Y'
                ELSE 'N'
            END as Canceled
        from
            $schema.vCourtEvent with(nolock)
        where
            CaseID = ?
            $dateStr
        order by
            CourtEventDate desc
    };

    getData($events,$query,$dbh,{valref => \@args});
    
    foreach my $event (@{$events}) {
        $event->{'JudgeName'} =~ s/,\s+JUDGE/, /ig;
        my $time = (split(/\s+/,$event->{'CourtEventTime'}))[3];
        #my ($hour,$min,$sec,$mil) = split(":", $time);
        #$event->{'CourtEventTime'} = sprintf("%02d:%02d %s", $hour, $min, substr($mil,3));
        if ($event->{'Canceled'} eq 'Y') {
            $event->{'RowClass'} = "canceled";
        } else {
            $event->{'RowClass'} = '';
        }
    }
}


sub getDockets {
    my $case = shift;
    my $dbh = shift;
    my $docketRef = shift;
    my $schema = shift;
    my $caseid = shift;

    if (!defined($schema)) {
        $schema = $DEFAULT_SCHEMA
    };

    if (ref ($case) eq "ARRAY") {
        my @quoted;
        foreach my $casenum (@{$case}) {
            push(@quoted, "'$casenum'");
        }

        my $inString = join(",", @quoted);

        my $query = qq {
            select
                CaseNumber,
                DocketCode,
                CONVERT(varchar(10),EffectiveDate,101) as EffectiveDate,
                CONVERT(varchar(10),EnteredDate,101) as EnteredDate,
                DocketDescription,
                LegacyDocketText as DocketText,
                Image,
                SeqPos,
                (UCN + '|' + CONVERT(varchar(10),ObjectID)) as UCNObj,
                ObjectID,
                CASE
                    WHEN ((Book is null) or (Book = '')) THEN 'No Book Location Available'
                    ELSE 'Book ' + Book+ ', Page ' + Page
                END as BookLocation,
                CaseID
            from
                $schema.vDocket with(nolock)
            where
                CaseNumber in ($inString)
                AND DocketCode NOT IN ('INDIV')
            order by
                EffectiveDate desc,
                SeqPos desc
        };
        getData($docketRef,$query,$dbh,{hashkey => "CaseNumber"});

        foreach my $key (keys %{$docketRef}) {
            # Sanitize each case docket
            my $thisDocket = $docketRef->{$key};
            sanitizeDockets($thisDocket);
        }
    } else {
        my $query = qq {
            select
                DocketCode,
                CONVERT(varchar(10),EffectiveDate,101) as EffectiveDate,
                CONVERT(varchar(10),EnteredDate,101) as EnteredDate,
                EffectiveDate as OrderByEffDate,
                DocketDescription,
                LegacyDocketText as DocketText,
                Image,
                SeqPos,
                (UCN + '|' + CONVERT(varchar(10),ObjectID)) as UCNObj,
                ObjectID,
                CASE
                    WHEN ((Book is null) or (Book = '')) THEN 'No Book Location Available'
                    ELSE 'Book ' + Book+ ', Page ' + Page
                END as BookLocation,
                CaseID,
                CaseNumber
            from
                $schema.vDocket with(nolock)
            where
                CaseID = ?
                AND DocketCode NOT IN ('INDIV')
            order by
                OrderByEffDate desc,
                SeqPos desc
        };

        getData($docketRef,$query,$dbh,{valref => [$caseid]});

        sanitizeDockets($docketRef);
    }
}


sub sanitizeDockets {
    # A reference to an array of docket items
    my $docketRef = shift;

    foreach my $docket (@{$docketRef}) {
        # Fix long strings that are commas with no space
        # Replace comma/whitespace with just commas
        $docket->{'DocketDescription'} =~ s/,\s+/,/g;
        # Split it up at the commas
        my @pieces = split(",", $docket->{'DocketDescription'});
        # And then re-join them as comma, single space
        $docket->{'DocketDescription'} = join(", ", @pieces);
        
        if ($docket->{'DocketText'} =~ /(Filed by )([a-zA-Z\s\/.,'-]*)/) {
        	my $filedBy = $2;
        	$docket->{'FilerName'} = $filedBy;
        }
        elsif ($docket->{'DocketText'} =~ /(FILED BY )([a-zA-Z\s\/.,'-]*)/) {
        	my $filedBy = $2;
        	$docket->{'FilerName'} = $filedBy;
        }
        elsif ($docket->{'DocketText'} =~ /(F\/B )([a-zA-Z\s\/.,'-]*)/) {
        	my $filedBy = $2;
        	$docket->{'FilerName'} = $filedBy;
        }
        else{
        	$docket->{'FilerName'} = "";
        }

        if (inArray(\@ORDERS,$docket->{'DocketCode'})) {
            $docket->{'RowClass'} = "order";
        } elsif (inArray(\@MOTIONS, $docket->{'DocketCode'})) {
            $docket->{'RowClass'} = "motion";
        } elsif (inArray(\@JUDGMENTS, $docket->{'DocketCode'})) {
            $docket->{'RowClass'} = "judgment";
        } elsif (inArray(\@NOTICES, $docket->{'DocketCode'})) {
            $docket->{'RowClass'} = "notice";
        } elsif (inArray(\@PETITIONS, $docket->{'DocketCode'})) {
            $docket->{'RowClass'} = "petition";
        } elsif (inArray(\@VOPS, $docket->{'DocketCode'})) {
            $docket->{'RowClass'} = "vop";
        } elsif (inArray(\@ANSWERS, $docket->{'DocketCode'})) {
            $docket->{'RowClass'} = "answer";
        } elsif (inArray(['EVCAN','EVERR','EVRST'], $docket->{'DocketCode'})) {
            $docket->{'RowClass'} = 'canceled'
            } else {
            $docket->{'RowClass'} = '';
        }
    }
}


sub getOtherCases {
    my $case = shift;
    my $dbh = shift;
    my $caseRef = shift;
    my $countyid = shift;
    my $schema = shift;
    my $caseid = shift;
    
    if (!defined($schema)) {
        $schema = $DEFAULT_SCHEMA
    };

    # Since vOtherCasesForDefendant isn't particularly reliable (because a
    # person can have multiple pidms in Banner), we'll do it another way.

    my %tmpCases;
    
    my $query;
    my @args;
    if (!defined($countyid) || ($countyid eq '')) {
        $query = qq {
            select
                OtherCasesForDefendant as CaseNumber
            from
                $schema.vOtherCasesForDefendant with(nolock)
            where
                CaseID = ?
            order by
            CaseNumber desc
        };
        push(@args, $caseid);
    } else {
        $query = qq {
            select
                CaseNumber
            from
                $schema.vAllParties with(nolock)
            where
                CountyID = ?
                and CaseID <> ?
            union
            select
                OtherCasesForDefendant as CaseNumber
            from
                $schema.vOtherCasesForDefendant with(nolock)
            where
                CaseID = ?
            order by
                CaseNumber desc
        };
        push(@args,$countyid,$caseid,$caseid);
    }
    
    getData(\%tmpCases,$query,$dbh,{valref => \@args, hashkey => 'CaseNumber'});
    
    my @cases;
    foreach my $casenum (keys %tmpCases) {
        # Quote the casenumbers to build an "in" string for the query below
        push(@cases, "'$casenum'");
    }
    
    if (scalar(@cases)) {
        my $inString = join(",", @cases);
        
        # Get a little more information on the cases
        $query = qq {
            select
                CaseNumber,
                CaseStatus,
                CaseType,
                NULL AS CaseStyle,
                CourtType,
                CaseID
            from
                $schema.vCase with(nolock)
            where
                CaseNumber in ($inString)
            order by
                CaseNumber desc
        };
        
        my %caseinfo;
        getData(\%caseinfo,$query,$dbh,{hashkey => "CaseNumber"});
        
        foreach my $casenum (sort keys %caseinfo) {
            my $casehash = $caseinfo{$casenum}[0];
            $casehash->{'CaseType'} = getSCcasetype($casehash->{CourtType},$casehash->{CaseType});
            push(@{$caseRef}, $casehash);
        }
    }
}

sub getReopenHistory {
    my $caseid = shift;
    my $dbh = shift;
    my $reopenRef = shift;
    my $schema = shift;
    
    if (!defined($schema)) {
        $schema = $DEFAULT_SCHEMA
    };

    my $query = qq {
        select
            CountNo,
            ReOpenReason,
            CONVERT(varchar,ReOpenDate,101) as ReOpenDate,
            CONVERT(varchar,ReOpenCloseDate,101) as ReOpenCloseDate
        from
            $schema.vReopenHistory with(nolock)
        where
            CaseID = ?
        order by
            ReOpenDate desc
    };

    getData($reopenRef,$query,$dbh,{valref => [$caseid]});
}



sub getFees {
    my $caseid = shift;
    my $dbh = shift;
    my $feesRef = shift;
    my $schema = shift;
    
    if (!defined($schema)) {
        $schema = $DEFAULT_SCHEMA
    };

    my $query = qq {
        select
            CONVERT(money,Assessed) as Assessed,
            CONVERT(money,Paid) as Paid,
            ISNULL(CONVERT(money,Balance),CONVERT(money,0)) as Balance
        from
            $schema.vCaseBalance with(nolock)
        where
            CaseID = ?
    };

    getData($feesRef,$query,$dbh,{valref => [$caseid] });
}



sub getAttorneys {
    my $caseid = shift;
    my $dbh = shift;
    my $attorneyRef = shift;
    my $schema = shift;
    
    if (!defined($schema)) {
        $schema = $DEFAULT_SCHEMA
    };

    # Get the attorneys for the case.  Do NOT get their address information
    # here!!
    my $query = qq {
        select
            a.PartyType,
            a.AttorneyName,
            a.FirmName,
            a.BarNumber,
            a.Address1,
            a.Address2,
            a.City,
            a.State,
            a.Zip,
            a.PhoneNumber,
            a.PhoneBusiness,
            a.PhoneCell
        from
            $schema.vAttorney a with(nolock)
        inner join 
        	$schema.vAllParties p with(nolock)
        	ON a.CaseID = p.CaseID
        	AND a.AttorneyID = p.PersonID
        where
            a.CaseID = ?
    };
    
    getData($attorneyRef,$query,$dbh,{valref => [$caseid]});
    
    foreach my $attorney (@{$attorneyRef}) {
        # Unset this information for SA/PD
        if (inArray(['APD','ASA','PD','SA'], $attorney->{PartyType})) {
            foreach my $field ('Address1','Address2','City','State','Zip',
                               'PhoneNumber','PhoneBusiness','PhoneCell') {
                undef $attorney->{$field};
            }
            next;
        }

        $attorney->{'FullAddress'} = "";
        foreach my $field ('Address1','Address2','City','State','Zip',
                           'PhoneNumber','PhoneBusiness','PhoneCell') {
            $attorney->{$field} =~ s/^\s+//g;
            $attorney->{$field} =~ s/\s+$//g;
            $attorney->{$field} =~ s/\s+/ /g;
            if ($attorney->{$field} eq '') {
                $attorney->{$field} = undef;
            }

        }
        
        if (defined($attorney->{'Address1'})) {
            if ((defined($attorney->{'Address2'})) && ($attorney->{'Address2'} ne "")) {
                $attorney->{'FullAddress'} = sprintf("%s<br/>%s<br/>%s, %s %05d", $attorney->{'Address1'},
                                                     $attorney->{'Address2'}, $attorney->{'City'}, $attorney->{'State'},
                                                     $attorney->{'Zip'});
            } else {
                $attorney->{'FullAddress'} = sprintf("%s<br/>%s, %s %05d", $attorney->{'Address1'},$attorney->{'City'},
                                                     $attorney->{'State'}, $attorney->{'Zip'});
            }
        }

        $attorney->{'Phone'} = "";

        if (defined($attorney->{'PhoneBusiness'})) {
            $attorney->{'Phone'} .= qq{bus: $attorney->{'PhoneBusiness'}<br/>};
        }
        if (defined($attorney->{'PhoneCell'})) {
            $attorney->{'Phone'} .= qq{cell: $attorney->{'Phonecell'}<br/>};
        }
        if (defined($attorney->{'PhoneNumber'})) {
            $attorney->{'Phone'} .= qq{phone: $attorney->{'PhoneNumber'}};
        }
    }
}


sub getCaseUsingLegacyCaseNumber {
    my $lcn = shift;
    my $dbh = shift;

    my $query = qq {
        select
            CaseNumber,
            LegacyCaseFormat,
            UCN
        from
            vCase with(nolock)
        where
            LegacyCaseFormat = ?
    };
    
    my $caseInfo = getDataOne($query,$dbh,[$lcn]);
    return $caseInfo;
}


#--------------------------------------------
# get info routines for the case

sub getCaseUsingUCN {
    my $ucn = shift;
    my $lcn = shift;
    my $dbh = shift;
    my $schema = shift;
    
    if (!defined($schema)) {
        $schema = $DEFAULT_SCHEMA
    };
    
    my $query;
    
    if ($ucn =~ /(50)(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)(\D\D\D\D)(\D\D)/) {
        my $casenum = "$1-$2-$3-$4-$5-$6";
        
        $query = qq {
            select
            	CaseNumber,
            	LegacyCaseFormat,
            	UCN
            from
            	$schema.vCase with(nolock)
            where
            	CaseNumber = ?
        };
        
        my $r = getDataOne($query,$dbh,[$casenum]);
        
        if (defined($r)) {
            return $r;
        }
    }
    

    $query = qq {
        select
            CaseNumber,
            LegacyCaseFormat,
            UCN
        from
            $schema.vCase with(nolock)
        where
            UCN = ?
    };

    my $r = getDataOne($query,$dbh,[$ucn]);
    
    if (!defined($r)) {
        $query = qq {
            select
            	CaseNumber,
            	LegacyCaseFormat,
            	UCN
            from
            	$schema.vCase with(nolock)
            where
                LegacyCaseFormat = ?
        };
        
        $r = getDataOne($query,$dbh,[$lcn]);
    }
    
    return $r;
}


sub getParties {
    my $caseid = shift;
    my $dbh = shift;
    my $partyRef = shift;
    my $schema = shift;
    my $partyTypes = shift;
    
    if (!defined($schema)) {
        $schema = $DEFAULT_SCHEMA
    };
    
    # no address or phone info
    my $query = qq {
        select
            PartyTypeDescription,
            FirstName,
            MiddleName,
            LastName,
            CONVERT(varchar,DOB,101) as DOB,
            Race,
            Sex,
            PersonID
        from
            $schema.vAllParties with(nolock)
        where
            CaseID = ?
            and PartyTypeDescription NOT IN ('DEFENDANT', 'JUDGE', 'ASSISTANT STATE ATTORNEY', 'PUBLIC DEFENDER', 'ATTORNEY')
    };
    
    if (defined($partyTypes)) {
        my @types;
        foreach my $partyType (@{$partyTypes}) {
            push (@types, "'$partyType'");
        }
        my $andString = "and PartyTypeDescription in (" . join(",", @types) . ")";
        $query .= qq {
            $andString
        };
    }
    
    getData($partyRef,$query,$dbh,{valref => [$caseid]});
}


# get the judge name for this particular division
sub getjudgefromdiv {
    my $divid = shift;
    my $dbh = shift;
    my $schema = shift;
    
    if (!defined($schema)) {
        $schema = $DEFAULT_SCHEMA
    };
    
    if ((!defined($divid)) || ($divid eq "")) {
        return "";
    }

    my $query = qq {
        select
            judge_LN as LastName,
            judge_FN as FirstName,
            judge_MN as MiddleName
        from
            $schema.vDivision_Judge with(nolock)
        where
            DivisionID = ?
            and Division_Active='Yes'
            and EffectiveFrom <= GETDATE()
            and ((EffectiveTo is null) or (EffectiveTo >= GETDATE()))
    };
    
    my $judge = getDataOne($query,$dbh,[$divid]);
    
    $judge->{'FirstName'} =~ s/^JUDGE\s?//g;
    
    my $fullname;
    if ((defined($judge->{'MiddleName'})) && ($judge->{'MiddleName'} eq "")) {
        $fullname = sprintf("%s %s", $judge->{'FirstName'}, $judge->{'LastName'});
    } else {
        $fullname = sprintf("%s %s. %s", $judge->{'FirstName'}, $judge->{'MiddleName'}, $judge->{'LastName'});
    }
    
    return prettifyString($fullname);
}

sub getAppellantAddresses {
    my $caseid = shift;
    my $dbh = shift;
    my $appellantRef = shift;
    
    my $schema = shift;
    
    if (!defined($schema)) {
        $schema = $DEFAULT_SCHEMA
    };

    foreach my $appellant (@{$appellantRef}) {
	my $query = qq {
        select
            Address1,
            Address2,
            City,
            State,
            ZipCode,
            PhoneNumber,
            BusinessPhone,
            PhoneCell,
            PartyID,
            AddressType
        from
            $schema.vAllPartyAddress with(nolock)
        where
            CaseID = ?
            and PartyID = ?
            and DefaultAddress='Yes'
            and AddressActive='Yes'
            and PartyActive='Yes'
        };
	
	my $address = getDataOne($query,$dbh, [$caseid, $appellant->{'PersonID'}]);
	if (scalar(keys(%{$address}))) {
	    # We have a match.  Populate the appropriate row with the data
	    foreach my $person (@{$appellantRef}) {
		next if ($address->{PartyID} != $person->{PersonID});
		$person->{AddressType} = $address->{AddressType};
		$person->{Address} = $address->{Address1};
		if ($address->{Address2} ne "") {
		    $person->{Address} .= "<br/>$address->{Address2}";
		}
		
		$person->{Address} .= "<br>$address->{City}, $address->{State}  $address->{ZipCode}";
		
		if(($address->{PhoneNumber} eq '') &&
		   ($address->{BusinessPhone} eq '') && ($address->{PhoneCell} eq '')) {
		    $person->{Phones} = "&nbsp;";
		} else {
		    my $cellString = "";
		    
		    if ($address->{BusinessPhone} ne '') {
			$cellString .= "bus: $address->{BusinessPhone}<br/>";
		    }
		    if ($address->{PhoneCell} ne '') {
			$cellString .= "cell: $address->{PhoneCell}<br/>";
		    }
		    if ($address->{PhoneNumber} ne '') {
			$cellString .= "phone: $address->{PhoneNumber}";
		    }
		    $person->{Phones} = $cellString;
		}
		last;
	    }
	}
    }
}



sub getScCaseInfo {
   my $inUCN = shift;
   my $caseid = shift;
   
   my $crimflag=0;
   my $ucn=convertCaseNumToDisplay(clean($inUCN));
   my $casenum = $ucn;
   
   my $referer_host = (split("\/",$ENV{'HTTP_REFERER'}))[2];
   
   my %data;
   $data{'ucn'} = $ucn;
    
   my $icmsuser = getUser();
    
   log_this('JVS', 'caselookup', 'User ' . $icmsuser . ' viewed case ' . $inUCN, $ENV{'REMOTE_ADDR'});
    
   my $ldap = ldapConnect();
   my $secretuser = inGroup($icmsuser,'CAD-ICMS-SEC',$ldap);
   my $sealeduser = inGroup($icmsuser,'CAD-ICMS-SEALED',$ldap);
   my $jsealeduser = inGroup($icmsuser,'CAD-ICMS-SEALED-JUV',$ldap);
   my $psealeduser = inGroup($icmsuser,'CAD-ICMS-SEALED-PROBATE',$ldap);
   $data{'odpuser'} = inGroup($icmsuser,'CAD-ICMS-ODPS',$ldap);
   $data{'notesuser'} = inGroup($icmsuser,'CAD-ICMS-NOTES',$ldap);
    
   my $dbh = dbConnect($db);
   my $schema = getDbSchema($db);
    
   my $pbsoconn;
   my $pbsoFailed = 0;
    
   if (!$SKIPPBSO) {
      eval {
         local $SIG{ALRM} = sub { die "timeout\n" };
         alarm 2;
         $pbsoconn = dbConnect("pbso2",undef,1);
         alarm 0;
      };
      
      if ($@) {
         if ($@ eq 'timeout') {
            $pbsoconn = undef;
            $pbsoFailed = 1;
         }
      }
      
      if (!defined($pbsoconn)) {
         $pbsoFailed = 1;
      }
   }
   
   my @defendants;
   
   if (!$SKIPPBSO) {
      $pbsoFailed = 1;
   }
   
   getDefendantAndAddress($caseid, $dbh, \@defendants, $pbsoconn,$pbsoFailed, $schema);
   
   $data{'defendants'} = \@defendants;
   
   # TEMPORARY FIX UNTIL CLERK FIXES THIS ISSUE
   ########
   if ((defined($defendants[0]->{'CountyID'})) && ($defendants[0]->{'CountyID'} eq '0000000')) {
      $defendants[0]->{'CountyID'} = undef;
   }
   ########
   
   my $defjacket = $defendants[0]->{'CountyID'};
   $data{'MJID'} = $defjacket;
   
   $data{'parties'} = [];
   
   getParties($caseid,$dbh,$data{'parties'},$schema);
   
   my $query = qq {
        select
            CaseNumber,
            FileDate,
            Sealed,
            Expunged,
            CourtType,
            CourtTypeDescription,
            CaseType,
            CaseTypeDescription,
            DivisionName,
            DivisionID,
            CurrentJudgeName,
            CaseStatus,
            NULL AS CaseStyle,
            SpeedyTrialDemandDate,
            SpeedyTrialDueDate,
            SpeedyTrialWaivedDate,
            ReopenDate,
            DispositionDate,
            ReopenCloseDate,
            JudgeAtDisposition,
            CaseID
        from
            $schema.vCase with(nolock)
        where
            CaseID = ?
            AND Expunged = 'N'
    };
    
    my $caseref = getDataOne($query,$dbh,[$caseid]);
    
    $caseref->{'JudgeAtDisposition'} =~ s/^JUDGE//i;
    $caseref->{'JudgeAtDisposition'} = prettifyString($caseref->{'JudgeAtDisposition'});
    
    foreach my $key ("FileDate","SpeedyTrialDemandDate","SpeedyTrialDueDate","SpeedyTrialWaivedDate",
                     "ReopenDate","DispositionDate","ReopenCloseDate") {
        $caseref->{$key} = changeDate($caseref->{$key});
    }

    escapeFields($caseref);

    #
    #  what should be 'restricted'?
    #
    if((!$sealeduser) && (($caseref->{Sealed} eq 'Y') || ($caseref->{'Expunged'} eq 'Y'))) {
    	if (!($jsealeduser && inArray(['CJ','DP'], $caseref->{'CourtType'})) 
			&& !($psealeduser && inArray(['GA','CP','MH'], $caseref->{'CourtType'}))) {
	        print "<br/>Case number $ucn is a restricted case.  No information can be provided.\n";
	        exit(1);
        }
    }

    # showcase casetypes are not always defined in vCase
    $caseref->{CaseType} = getSCcasetype($caseref->{CourtType},$caseref->{CaseType});

    my $bncasenum = $caseref->{'CaseNumber'};
    $bncasenum =~s#-##g;
    $bncasenum = substr $bncasenum,2,15;
    $data{'bncasenum'} = $bncasenum;

    # don't let users that don't have access to secret cases see them.
    if(!$secretuser){
        if(inArray(["AD","AJ","TE","TP","TB"], $caseref->{CaseType})) {
            print "<br/>Case number $ucn is a restricted case.  No information can be provided.\n";
            $dbh->disconnect;
            exit(1);
        }
    }

    # set criminal flag based on court code - -
    if (inArray(\@ctArray, $caseref->{CourtType})) {
        $crimflag=1;
        $data{'crimflag'} = 1;
    }
    
    $data{'divjudge'} = prettifyString(getjudgefromdiv($caseref->{DivisionID},$dbh, $schema));
    $query = qq {
        select
            CONVERT(varchar,MAX(EffectiveDate),101) as MaxEffectiveDate
        from
            $schema.vDocket with(nolock)
        where
            CaseID = ?
    };

    my $med = getDataOne($query,$dbh,[$caseid]);
    $caseref->{'LastActivity'} = $med->{'MaxEffectiveDate'};
    $caseref->{'CaseAge'} = getScCaseAge($caseref,$dbh);

    my $ctanddesc = $caseref->{CaseType};
    if((defined $caseref->{CaseTypeDescription}) && ($caseref->{CaseTypeDescription} ne '')) {
        $ctanddesc.=" - $caseref->{CaseTypeDescription}";
    }
    
    $caseref->{'CaseTypeDesc'} = $ctanddesc;


    # Do this here so we know before showing the case number if we have
    # open warrants.
    my @warrants;

    getWarrants($caseid,$dbh,\@warrants, $schema);

    # Are any of the warrants open?
    $data{'openWarrants'} = 0;
    foreach my $warrant (@warrants) {
        if ($warrant->{Closed} eq "N") {
            $data{'openwarrants'} = 1;
            last;
        }
    }

    $data{'warrants'} = \@warrants;
    $data{'caseinfo'} = $caseref;
    
    $data{'shortcase'} = $casenum;
    #$data{'shortcase'} =~ s/^50-//g;
    
    if (!inArray(\@SCACTIVE,$caseref->{CaseStatus})) {
        if ($caseref->{'JudgeAtDisposition'} ne $data{divjudge}) {
            # Only show the disposition judge if different from the current judge.
            $data{'showDispJudge'} = 1;
        }
    }
    
    if (($caseref->{CaseStatus} =~ /Reopen/i) && ($caseref->{ReopenDate} ne "")) {
        $data{'reopened'} = 1;
    }
    
    if ($caseref->{'DispositionDate'} ne "") {
        $data{'disposed'} = 1;
        $data{'DispositionDate'} = $caseref->{'DispositionDate'};
    }
    
    $data{'attorneys'} = [];
    getAttorneys($caseid,$dbh,$data{'attorneys'},$schema);
    
    my $isProSe = 1;
    # If there is no PD or Attorney party, then the defendant is pro se
    foreach my $attorney (@{$data{'attorneys'}}) {
		if (inArray(['PD','Attorney'],$attorney->{'PartyType'})) {
		    $isProSe = 0;
		    last;
		}
    }
    
    $data{'defendants'}->[0]->{'IsProSe'} = $isProSe;

    #$data{'linkedCases'} = [];
    #getLinkedCases($caseid,$dbh,$data{'linkedCases'},$schema);

    $data{'arrests'} = [];
    getArrests($caseid,$dbh,$data{'arrests'},$schema);

    $data{'bonds'} = [];
    getBonds($caseid,$dbh,$data{'bonds'},$schema);

    $data{'charges'} = [];
    getCharges($caseid,$dbh,$data{'charges'},$schema);
    
    $data{'sentences'} = [];
    getSentences($caseid,$dbh,$data{'sentences'},$schema);
    
    # Are there citations?
    foreach my $charge (@{$data{'charges'}}) {
        if (defined($charge->{'CitationNumber'})) {
           $data{'hasCitations'} = 1;
           last;
        }
    }

    $data{'fees'} = [];
    getFees($caseid,$dbh,$data{'fees'},$schema);
    
    $data{'flags'} = [];
    $data{'casenotes'} = [];
    my $cnconn = dbConnect("icms");
    $cnconn->disconnect;
    
    $data{'events'} = [];
    
    my $vdbh = dbConnect("vrb2");
    getVrbEventsByCase($data{'events'},$casenum,$vdbh);
    
    $data{'showTif'} = (($ENV{'HTTP_USER_AGENT'} !~ /mobile/i) && (inGroup(getUser(), "CAD-ICMS-TIF", $ldap)));

    $data{'appellants'} = [];
    # We've already looked up the parties.  Get the appellants from that list
    foreach my $party (@{$data{'parties'}}) {
      if ($party->{PartyTypeDescription} eq "APPELLANT") {
         push(@{$data{'appellants'}},$party);
      }
   }
    # And look up the addresses
    getAppellantAddresses($caseid,$dbh,$data{'appellants'},$schema);
    
    $data{'reopens'} = [];
    getReopenHistory($caseid,$dbh,$data{'reopens'},$schema);
    
    $data{'bookingHistory'} = {};
    $data{'bookingNums'} = [];
    if (defined($pbsoconn)) {
		$pbsoconn->disconnect;
    }
    
    $dbh->disconnect;
    
    # Determine if this case is on the user's watch list
    $data{'watchList'} = getWatchList($casenum, $icmsuser);
    
    $data{'otherDocs'} = [];
    getQueueItems($casenum, $data{'otherDocs'});
    
    my $fdbh = dbConnect("icms");
    
    my $info = new CGI;
	my $user = getUser();

	createTab($casenum, "/cgi-bin/search.cgi?name=" . $casenum, 1, 1, "cases",
		{ 
			"name" => "Case Details",
			"active" => 1,
			"close" => 1,
			"href" => "/cgi-bin/search.cgi?name=" . $casenum,
			"parent" => $casenum
		}
	);

	my $session = getSession();
	my @myqueues = ($user);
	my @sharedqueues;
	
	getSubscribedQueues($user, $fdbh, \@myqueues);
	getSharedQueues($user, $fdbh, \@sharedqueues);
	my @allqueues = (@myqueues, @sharedqueues);
	my %queueItems;

	my $wfcount = getQueues(\%queueItems, \@allqueues, $fdbh);
	$data{'wfCount'} = $wfcount;
	$data{'active'} = "cases";
	$data{'tabs'} = $session->get('tabs');
   
   my $output = doTemplate(\%data,"$templateDir","casedetails/scCaseDetails.tt",0);
   
   return $output;
}

sub showcaseCivilSearch {
	my $fieldref = shift;
	my $caseref = shift;
    
	my @charges;
	my $query;
    
    my $sancasenum = sanitizeCaseNumber($fieldref->{'name'});
	
	my $dbh = dbConnect($db);
    my $schema = getDbSchema($db);
    
    my $divLimitSearch;
    if (defined($fieldref->{'limitdiv'})) {
        my $inString = join(",", @{$fieldref->{'limitdiv'}});
        $divLimitSearch = "and c.DivisionID in ($inString) ";

        if ((defined($fieldref->{'limittype'})) && ($fieldref->{'limittype'} eq 'Traffic')) {
            $divLimitSearch = "and c.CourtType in ('CT','TR') ";
        }
    }
    
    my $causeSearch = "";
    if (defined($fieldref->{'causetype'})) {
		my $inString = join(",", @{$fieldref->{'causetype'}});
        $divLimitSearch = "and CaseType in ($inString) ";
    }

	# Temp storage for data
	my $temp = [];
	
	if (defined(sanitizeCaseNumber($fieldref->{'name'}))) {
        #
		# Case Number Search
		#

		my $casenum = sanitizeCaseNumber($fieldref->{'name'});
        
        # If we can determine that this is a criminal case, short-circuit this
		# evaluation and move along.
		my $courtcode = (split(/-/,$casenum))[2];
		if (inArray(\@SCCODES,"'$courtcode'")) {
			return;
		}

		if ($courtcode eq "AP"){
			# It's an appeal. Is it a 9-series sequence?
			my $seq = (split(/-/,$casenum))[3];
			if ($seq =~ /^9/) {
				# Criminal appeal.  Don't want what we'll find here.
				return;
			}
		}
        
		$casenum =~ s/-//g;
		if ($casenum !~ /^50/) {
			$casenum="50".$casenum;
		}

        $query = qq {
			select
				DISTINCT c.CaseNumber,
				c.CaseID
			from
                $schema.vCase c with(nolock) 
			where
		};
		if (length($casenum) == 20) {
			$query .= qq{
				c.UCN = '$casenum'
			};
		} else {
			$query .= qq{
				c.UCN like '$casenum%'
			};
		}
		
		$query .= " AND c.Expunged = 'N' ";

		if ($fieldref->{'active'} == 1) {
			$query .= $activePhrase;
		}

		if ($fieldref->{'criminal'} == 1) {
			$query .= $criminalPhrase;
		}

		my @exclusions;
		if (!($fieldref->{'sealeduser'})) {
			push(@exclusions,$excludeSealed);

			if ($fieldref->{'jsealeduser'}) {
				push(@exclusions,$showjSealed);
			}
			
			if ($fieldref->{'psealeduser'}) {
				push(@exclusions,$showpSealed);
			}
		}

		if (scalar(@exclusions)) {
			$query .= "and (" . join (" or ", @exclusions) . ")";
		}

		if (!($fieldref->{'secretuser'})) {
			$query .= $excludeSecret;
		}

		if (!($fieldref->{'secretuser'})) {
			$query .= $excludeSecret;
		}

		getData($temp,$query,$dbh);

		if (scalar(@{$temp}) == 1) {
         
			# We have a single match.  Redirect to scview.
			my $c = $temp->[0]->{'CaseNumber'};
			my $d = $temp->[0]->{'CaseID'};
			my $output = getScCivilCaseInfo($c, $d);
            #my %result;
            #$result{'status'} = 'Success';
            #$result{'tab'} = sprintf('case-%s', $c);
            
            #$result{'html'} = $output;
            #$result{'tabname'} = $c;
            #print "Content-type: text/html\n\n";
            #my $json = JSON->new->allow_nonref;
            #print $json->encode(\%result);
            my $info = new CGI;
            print $info->header;
            print $output;
			exit;
		}
	} elsif ($fieldref->{'name'}=~/(\d+)(\D+)(\d+)(\*)/ ||
			 $fieldref->{'name'}=~/(\d+)(\D+)(\d+)(\D+){0,3}/ ) {        
		my ($year, $type, $seq, $suffix);

		my $casenum;

		if ($fieldref->{'name'} =~ /^50/) {
			$fieldref->{'name'} =~ s/^50//g;
		}

		if ($fieldref->{'name'}=~/(\d+)(\D+)(\d+)(\*)/) {
			# Searches for yyyyttd* (NO PADDING ZEROS HERE!!)
			# Wildcard search on case number - yyyyttd*
			$year = $1;
			$type = $2;
			$seq = $3;
			$year = fixyear($year);
			# Be sure to convert to uppercase
			$casenum = uc(sprintf("50%04d%s%s",$year,$type,$seq));

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
		} else {
			# Not a wildcard

			$year = $1;
			$type = $2;
			$seq = $3;
			$suffix = $4;
			$suffix =~ s/-//g;

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
			# Be sure to convert them to uppercase
			$casenum = uc(sprintf("50%04d%s%06d%s", $year, $type, $seq, $suffix));
		}

		$query = qq {
			select
				NULL AS CaseStyle,
                p.LastName,
				p.FirstName,
				p.MiddleName,
				c.UCN,
				c.CaseNumber,
				CONVERT(varchar,c.FileDate,101) as FileDate,
				c.CaseType,
				c.CaseStatus,
                p.PartyTypeDescription,
				CONVERT(varchar,p.DOB,101) as DOB,
				c.DivisionID,
				C.CaseID
			from
                $schema.vCase c with(nolock) 
                left outer join $schema.vAllParties p with(nolock) 
                on c.CaseID = p.CaseID
            where
		};

		if (length($casenum) == 20) {
			$query .= qq{
				c.UCN = '$casenum'
			};
		} else {
			$query .= qq{
				c.UCN like '$casenum%'
			};
		}
		
		$query .= " AND c.Expunged = 'N' ";

		if ($fieldref->{'active'} == 1) {
			$query .= $activePhrase;
		}

		if ($fieldref->{'criminal'} == 1) {
			$query .= $criminalPhrase;
		}

		my @exclusions;
		if (!($fieldref->{'sealeduser'})) {
			push(@exclusions,$excludeSealed);

			if ($fieldref->{'jsealeduser'}) {
				push(@exclusions,$showjSealed);
			}
			
			if ($fieldref->{'psealeduser'}) {
				push(@exclusions,$showpSealed);
			}
		}

		if (scalar(@exclusions)) {
			$query .= "and (" . join (" or ", @exclusions) . ")";
		}

		if (!($fieldref->{'secretuser'})) {
			$query .= $excludeSecret;
		}

        $query .= $divLimitSearch;
        
        getData($temp, $query, $dbh);

		if (scalar(@{$temp}) == 1) {
            my $c = $temp->[0]->{'CaseNumber'};
            $c = substr($c,3);
            my $d = $temp->[0]->{'CaseID'};
            # We have a single match.  Redirect to scview.
            print "Location: view.cgi?ucn=$c&caseid=$d&lev=2\n\n";
            exit;
        }
      } else {
               print "Content-type: text/html\n\n";
               print "Wrong format used for the name or case number - couldn't ".
               "understand '$fieldref->{name}'.<p>\n";
               exit;
      }

    foreach my $case (@{$temp}) {
		$case->{'AGE'} = getageinyears($case->{'DOB'});
		$case->{'ChargeCase'} = $case->{'CaseNumber'};

		# Populate the full name at this time, if it exists.  We'll need
		# it later.
        if (defined($case->{'LastName'})) {
            $case->{'Name'} = buildName($case,1);
            #$case->{'Name'} = "$case->{LastName}, $case->{FirstName}";
            #if ((defined($case->{'MiddleName'})) && ($case->{'MiddleName'} ne "")) {
            #    $case->{'Name'} .= " $case->{MiddleName}";
            #}
        }

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
				max(EffectiveDate) as MaxEffectiveDate
			from
				$schema.vDocket with(nolock)
			where
				CaseID = ?
		};

		my $med = getDataOne($aquery,$dbh,[$case->{'CaseID'}]);

		$case->{'LACTIVITY'} = changeDate($med->{'MaxEffectiveDate'});
		
		# Get charge information for this case
		my @charges;
		if ($fieldref->{'charges'} == 1) {
			$query = qq {
				select
					CourtStatuteDescription
				from
					$schema.vCharge ch with(nolock)
				where
					ch.CaseID = ?
			};

			getData(\@charges,$query,$dbh,{valref => [$case->{'CaseID'}]});
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
		$case->{'CaseNumber'} =~ s/^50-//g;
		push(@{$caseref}, $case);
	}
}

sub getScCivilCaseInfo {
    my $inUCN = shift;
    my $caseid = shift;
    
    my $icmsuser = getUser();
    
    log_this('JVS', 'caselookup', 'User ' . $icmsuser . ' viewed case ' . $inUCN, $ENV{'REMOTE_ADDR'});
	
    my $dbh = dbConnect($db);
    my $schema = getDbSchema($db);
    
    my $ldap = ldapConnect();
    my $secretuser = inGroup($icmsuser,'CAD-ICMS-SEC',$ldap);
    my $sealeduser = inGroup($icmsuser,'CAD-ICMS-SEALED',$ldap);
    my $jsealeduser = inGroup($icmsuser,'CAD-ICMS-SEALED-JUV',$ldap);
    my $psealeduser = inGroup($icmsuser,'CAD-ICMS-SEALED-PROBATE',$ldap);
    my $odpuser = inGroup($icmsuser,'CAD-ICMS-ODPS',$ldap);

    my $ucn=convertCaseNumToDisplay(clean($inUCN));
    my $casenum = $ucn;
	
    my $referer_host = (split("\/",$ENV{'HTTP_REFERER'}))[2];
    
    my %data;
    $data{'ucn'} = $ucn;
	$data{'notesuser'} = inGroup($icmsuser, 'CAD-ICMS-NOTES', $ldap);
	$data{'showTif'} = inGroup($icmsuser, 'CAD-ICMS-TIF', $ldap);
	$data{'odpuser'} = $odpuser;
    
    #my $sccasenum="50-".$ucn;

    #my $scucn=$sccasenum;
    #$scucn=~s#-##g;

    #my $sclcn=$ucn;
    #$sclcn=~s#-##g;
    #$sclcn=substr($sclcn,0,13)."XX";

    #$ucn=$scucn;
    #my $casenum=$sccasenum;
    
    # Because there is a new format (CaseNumber extension), we might not be
    # able to find the 'old' cases using that number.
    # If the case can't be found using the CaseNumber, try the LegacyCaseFormat.
    
    #my $cucn = getCaseUsingUCN($ucn,$sclcn,$dbh,$schema);
    
    #if (!defined($cucn)) {
    #    print "Content-type: text/html\n\n";
    #    print "<br/>No information was found for case number $ucn.\n";
    #    $dbh->disconnect;
    #    exit(1);
    #}
    
    #$sccasenum = $casenum = $cucn->{'CaseNumber'};
    #$sclcn = $cucn->{'LegacyCaseFormat'};
    #$scucn = $ucn = $cucn->{'UCN'};
    
    # don't look at sealed records!
	my $query = qq {
        select
            CaseType,
            CourtType as CourtCode,
            DivisionID,
			Sealed,
            CaseNumber,
            CaseStatus,
			CONVERT(varchar,FileDate,101) as FileDate,
			CaseTypeDescription as CaseTypeDesc,
			CaseID,
			CONVERT(varchar,ReopenDate,101) as ReopenDate,
			CONVERT(varchar,ReopenCloseDate,101) as ReopenCloseDate,
			CONVERT(varchar,DispositionDate,101) as DispositionDate
        FROM
            $schema.vCase
        WHERE
            CaseID = ?
            AND Expunged = 'N' 
	};

	my $caseinfo = getDataOne($query,$dbh,[$caseid]);
	
	if(($caseinfo->{'Sealed'} eq 'Y') && (!$sealeduser)) {
		if (!($jsealeduser && inArray(['CJ','DP'], $caseinfo->{'CourtCode'})) 
			&& !($psealeduser && inArray(['GA','CP','MH'], $caseinfo->{'CourtCode'}))) {
            $dbh->disconnect;
            my $info = new CGI;
            print $info->header;
            
            my $idbh = dbConnect("icms");
			my $session = getSession();
			my $user = getUser();
			my @myqueues = ($user);
			my @sharedqueues;
			
			getSubscribedQueues($user, $idbh, \@myqueues);
			getSharedQueues($user, $idbh, \@sharedqueues);
			my @allqueues = (@myqueues, @sharedqueues);
			my %queueItems;
			
			my $wfcount = getQueues(\%queueItems, \@allqueues, $idbh);
			$data{'wfCount'} = $wfcount;
			$data{'active'} = "cases";
		    $data{'denyReason'} = "sealed";
		    
		    doTemplate(\%data,"$templateDir","top/header.tt",1);
		    doTemplate(\%data,"$templateDir","noAccess.tt",1);
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
            my $info = new CGI;
            print $info->header;
            print "<br/>Case number $ucn is a restricted case.  No information can be provided.\n";
            exit;
		}
	}
	
	if ($caseinfo->{'DispositionDate'} ne "") {
        $data{'disposed'} = 1;
        $data{'DispositionDate'} = $caseinfo->{'DispositionDate'};
    }

	# Get property addresses
	$data{'propertyAddress'} = getPropertyAddress($caseid,$dbh);
    
    # Ok, the user has access to the case.
    $data{'parties'} = [];
    $data{'attorneys'} = [];
    getParties_civil($caseid, $dbh, $data{'parties'}, $data{'attorneys'}, $casenum);

    $data{'caseinfo'} = $caseinfo;

    # set criminal flag based on cort code
	my $crimflag = 0;
	if(inArray(['CJ'], $caseinfo->{'CourtCode'})) {
		$crimflag=1;
	}

	# get judge and division information
	my($div,$judge);
    
	$data{'judge'} = getjudgedivfromdiv($caseinfo->{'DivisionID'},$dbh);

	my $casesummary = $caseinfo;

	$query = qq {
		SELECT
			CONVERT(varchar,MAX(EffectiveDate),101) as LastEventDate
		FROM
			$schema.vDocket
		WHERE
			CaseID = ?
	};

	my $activity = getDataOne($query,$dbh,[$caseid]);
	$casesummary->{'LastActivity'} = $activity->{'LastEventDate'};

    $caseinfo->{'CaseAge'} = getScCaseAge($casesummary, $dbh);
	escapeFields($casesummary);

    foreach my $key (keys %{$casesummary}) {
        $caseinfo->{$key} = $casesummary->{$key};
    }
    
	#$data{'fees'} = [];
	#getFees($caseid,$dbh,$data{'fees'});
    
	$data{'flags'} = [];
	$data{'casenotes'} = [];
	#my $cnconn = dbConnect("icms");
	#getFlags($ucn,$cnconn,$data{'flags'});
	#getNotes($ucn,$cnconn,$data{'casenotes'});
	#
	#$cnconn->disconnect;
    
   	#$data{'linkedCases'} = [];
	#getLinkedCases($caseid,$dbh,$data{'linkedCases'},$schema);
    
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
		getWarrants($caseid, $dbh, $data{'warrants'});
		
		# Are any of the warrants open?
	    $data{'openWarrants'} = 0;
	    foreach my $warrant (@{$data{'warrants'}}) {
	        if ($warrant->{Closed} eq "N") {
	            $data{'openwarrants'} = 1;
	            last;
	        }
	    }

		$data{'charges'} = [];
		getCharges($caseid, $dbh, $data{'charges'});
		$data{'sentences'} = [];
    	getSentences($caseid,$dbh,$data{'sentences'},$schema);
	}
	
	if ($casenum=~/DP|CJ/i) {
		$data{'juv_data'} = {};
		getJuvenileCMData($casenum, $caseid, $dbh, $data{'juv_data'});
	}
    
	$dbh->disconnect;
    
    my $idbh = dbConnect("icms");
    my $info = new CGI;
	my $user = getUser();

	createTab($casenum, "/cgi-bin/case/search.cgi?name=" . $casenum, 1, 1, "cases",
		{ 
			"name" => "Case Details",
			"active" => 1,
			"close" => 1,
			"href" => "/cgi-bin/case/search.cgi?name=" . $casenum,
			"parent" => $casenum
		}
	);

	my $session = getSession();
	my @myqueues = ($user);
	my @sharedqueues;
	
	getSubscribedQueues($user, $idbh, \@myqueues);
	getSharedQueues($user, $idbh, \@sharedqueues);
	my @allqueues = (@myqueues, @sharedqueues);
	my %queueItems;
	
	my $wfcount = getQueues(\%queueItems, \@allqueues, $idbh);
	$data{'wfCount'} = $wfcount;
	$data{'active'} = "cases";
    $data{'watchList'} = getWatchList($casenum, $icmsuser, $idbh);
    $data{'tabs'} = $session->get('tabs');
    
    my $output = doTemplate(\%data,"$templateDir","casedetails/scCivilCaseDetails.tt",0);
    
    return $output;
}

sub getPropertyAddress {
	my $caseid = shift;
	my $dbh = shift;
    my $returnHtml = shift;
    
    if (!defined($returnHtml)) {
        $returnHtml = 1;
    }
    
   $dbh = dbConnect($db);
   my $schema = getDbSchema($db);
	
	my $query = qq {
		SELECT
			CaseNumber,
			PartyType,
			Address1,
			Address2,
			City,
			ZipCode as Zip,
			State,
			AddressType as AddrType
		FROM $schema.vAllPartyAddress
		WHERE
			CaseID = ?
			AND AddressType = ?
	};
    
	my $address;
	
	# Check for PA first, then AL
	foreach my $addrType ('Property Address','Alternative') {
		$address = getDataOne($query, $dbh, [$caseid, $addrType]);
		last if (defined($address));
	}
	
	if (defined($address)) {
		my $addr;
		
		my $line1 = sprintf("%s", $address->{'Address1'});
		my $line2 = sprintf("%s", $address->{'Address2'});
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
        
        
		if (($address->{'Address2'} eq "")) {
			$addr=sprintf("%s%s%s",$line1,$newline,$line3);
		} else {
			$addr=sprintf("%s%s%s%s%s",$line1,$newline,$line2,$newline,$line3);
		}
        return $addr;
	} else {
		return undef;
	}
}

sub getParties_civil {
    my $caseid = shift;
    my $dbh = shift;
    my $partyRef = shift;
    my $attorneyRef = shift;
    my $case = shift;
    
   $dbh = dbConnect($db);
   my $schema = getDbSchema($db);

    my $query = qq {
        SELECT
            CASE
               WHEN p.PartyTypeDescription = 'PLAINTIFF/PETITIONER'
                  THEN 1
               WHEN p.PartyType = 'PLT'
                  THEN 1
               WHEN p.PartyType = 'PET'
                  THEN 1
               WHEN p.PartyType = 'CHILD'
                  THEN 1
               WHEN p.PartyType = 'CHLD'
                  THEN 1
			   WHEN p.PartyTypeDescription = 'CHILD (CJ)'
                  THEN 1                  
               WHEN p.PartyType = 'FTH'
                  THEN 2
               WHEN p.PartyType = 'FATHER'
                  THEN 2
               WHEN p.PartyTypeDescription = 'DEFENDANT/RESPONDENT'
                  THEN 2
               WHEN p.PartyType = 'DFT'
                  THEN 2   
               WHEN p.PartyType = 'RESP'
                  THEN 2
               WHEN p.PartyType = 'MTH'
                  THEN 3
               WHEN p.PartyType = 'MOTHER'
                  THEN 3
               ELSE 4
            END as PartyOrder,      
            p.PersonID as PIDM,
            p.PartyType,
            p.CaseNumber as CaseNum,
            p.LastName,
            p.FirstName,
            p.MiddleName,
            p.PartyTypeDescription AS PartyTypeDesc,
            CASE when p.DOB is NULL
                    THEN '&nbsp;'
                    ELSE CONVERT(varchar,p.DOB,101)
                END as DOB,
            p.PhoneNo,
            p.Active,
            p.Discharged,
            p.BarNumber,
            CASE 
				WHEN p1.CourtAction LIKE '%Disposed%'
				THEN 1
				ELSE 0
			END AS Disposed,
			p.eMailAddress
        FROM
            $schema.vAllParties p
        LEFT OUTER JOIN 
			$schema.vParty p1
			ON p.CaseID = p1.CaseID
			AND p.PersonID = p1.PersonID    
        WHERE
            p.CaseID = ?
            AND p.Active = 'Yes'
            AND p.PartyType NOT IN ('JUDG','AFFP','ATTY')
        ORDER BY PartyOrder,
            p.Active DESC,
            p.Discharged ASC,
            p.DOB ASC,
            p.LastName
    };
    
	my @parties;
	getData(\@parties,$query,$dbh, {valref => [$caseid]});
	
	my $attQuery = "   SELECT a.BarNumber,
						Represented_PersonID,
						pa.PersonID as PIDM,
			            pa.PartyType,
			            a.CaseNumber as CaseNum,
			            pa.LastName,
			            pa.FirstName,
			            pa.MiddleName,
			            p.LastName AS Rep_PartyLastName,
			            p.FirstName as Rep_PartyFirstName,
			            p.MiddleName as Rep_PartyMiddleName,
			            pa.PartyTypeDescription AS PartyTypeDesc,
			            p.PartyTypeDescription AS Rep_PartyTypeDesc,
			            CASE when pa.DOB is NULL
			                    THEN '&nbsp;'
			                    ELSE CONVERT(varchar,pa.DOB,101)
			                END as DOB,
			            pa.PhoneNo,
			            pa.Active,
			            pa.Discharged,
			            CASE 
							WHEN p1.CourtAction LIKE '%Disposed%'
							THEN 1
							ELSE 0
						END AS Disposed,
						pa.eMailAddress
						FROM 
							$schema.vAttorney a
						INNER JOIN 
							$schema.vAllParties pa
							ON a.CaseID = pa.CaseID
							AND a.BarNumber = pa.BarNumber
							AND a.AttorneyID = pa.PersonID
						INNER JOIN 
							$schema.vAllParties p
							ON a.CaseID = p.CaseID
							AND a.Represented_PersonID = p.PersonID
							AND p.Active = 'Yes'
							AND (p.Discharged = 0 OR p.Discharged IS NULL)
						INNER JOIN 
							$schema.vParty p1
							ON a.CaseID = p1.CaseID
							AND a.Represented_PersonID = p1.PersonID
						WHERE a.CaseID = ?";
						
	my @attorneys;
	getData(\@attorneys, $attQuery, $dbh, {valref => [$caseid]});
	
	my $esdbh = dbConnect("eservice");
	
	my @associations;
	foreach my $att (@attorneys){
		my %attRep;
		$attRep{'FirstName'} = $att->{'Rep_PartyFirstName'};
		$attRep{'LastName'} = $att->{'Rep_PartyLastName'};
		$attRep{'MiddleName'} = $att->{'Rep_PartyMiddleName'};
		$att->{'Represents'} = {
	 		'PartyTypeDesc' => $att->{'Rep_PartyTypeDesc'},
	        'FullName' => buildName(\%attRep, 1)
	    };
	                
	    $associations[$att->{'PIDM'}] = 1;
	    
	    push(@parties, $att);
    }

    foreach my $party (@parties) {
    	$party->{'ProSe'} = 1;
    	foreach my $att (@attorneys){
    		if($party->{'PIDM'} eq $att->{'Represented_PersonID'}){
    			$party->{'ProSe'} = 0;
    		}
    	}
    	
    	if(($party->{'PartyType'} eq "DOR") || ($party->{'LastName'} eq "FL       STATE OF    DOR   OBO")){
    		$party->{'ProSe'} = 0;
    	}
    }
    
    # Build a list of attorney associations and other cases
    my %otherCases;
	foreach my $party (@parties) {
	
        $party->{'tdCols'} = 5; # Minimum to start
        $party->{'PartyTypeDesc'} = uc($party->{'PartyTypeDesc'});
        $party->{'FullName'} = buildName($party, 1);
		#$party->{'Phone'} = buildPhone($party->{'PIDM'}, $dbh);
        $party->{'Phone'} = $party->{'PhoneNo'};
        $party->{'Age'} = getageinyears($party->{'DOB'});

        if (defined($party->{'Age'})) {
            $party->{'tdCols'} += 2;
        }
        
        if ($party->{'BarNumber'} !~ /\D/) {
            $party->{'BarID'} = int($party->{'BarNumber'});
        } else {
            $party->{'BarID'} = '&nbsp;';
        }

		if (($party->{'Active'} ne "Yes") || ($party->{'Discharged'} eq '1') || ($party->{'Disposed'} eq '1')) {
            # Inactive party. Stop processing here.
            $party->{'Active'} = 'N';
            next;
        }

        $party->{'Active'} = 'Y';

        if ($party->{'PartyType'} !~ /ATTY|AGAL/) {
            $otherCases{$party->{'PIDM'}} = $party;
            next;
        }
	}

	#getOtherCases_civil(\%otherCases,$caseid);

    foreach my $party (@parties) {
        $party->{'isEservice'} = 0;
        if (defined($otherCases{$party->{'PIDM'}})) {
            $party->{'OtherCases'} = $otherCases{$party->{'PIDM'}}->{'OtherCases'};
        } else {
            $party->{'OtherCases'} = {};
        }

        ($party->{'Address'}, $party->{'Confidential'}) = buildAddress($party->{'PIDM'}, $caseid, $dbh);

        # And now decide where each goes
        if ($party->{'PartyType'} =~ /ATTY|AGAL/) {
            push(@{$attorneyRef}, $party);
        } else {
            push(@{$partyRef}, $party);
        }
    }

    $esdbh->disconnect;
}

sub getOtherCases_civil {
	my $caseid = shift;
	my $case = shift;
	my $parties = shift;
	my @partyRef;
	my @attorneyRef;
	my $partyRef;
	my @partyIds;
	
	my $dbh = dbConnect($db);
   my $schema = getDbSchema($db);
	
	getParties_civil($caseid, $dbh, \@partyRef, \@attorneyRef, $case);

	foreach my $p(@partyRef){
		push(@partyIds, $p->{'PIDM'});
	}
   
   return if (!scalar(@partyIds));

	my $inString = join(",", @partyIds);

#	$dbh = dbConnect($db);
#   $schema = getDbSchema($db);

	# First, find the number of cases for each party
	my $query = qq {
		SELECT
			PersonID,
			COUNT(*) as PartyCount
		FROM
			$schema.vAllParties
		WHERE
			PersonID in ($inString)
            AND CaseID <> ?
		GROUP BY
			PersonID
		ORDER BY
			PartyCount desc
	};
    
	my @counts;
	getData(\@counts,$query,$dbh, {valref => [$caseid]});

	my @usePidms;

	foreach my $count (@counts) {
		if ($count->{'PartyCount'} <= $otherCaseMax) {
			push(@usePidms,$count->{'PersonID'});
		}
	}

	# Now we having a listing of just the PIDMs that have fewer cases than the threshold.
	# Look up the cases for those parties
	return if (!scalar(@usePidms));

	foreach my $pidm (@usePidms) {

		$query = qq {
			SELECT
				c.CaseNumber,
				p.PersonID,
				p.PartyType as PartyType,
				c.CaseStyle,
				c.CaseStatus as Status,
				PartyTypeDescription as PartyTypeDesc,
				c.CaseType as CaseType,
				c.CaseID
			FROM
				$schema.vCase c
                INNER JOIN $schema.vAllParties p
                	ON c.CaseID = p.CaseID
			WHERE
				PersonID = ?
                AND c.CaseID <> ?
		};
        
		my @otherCases;
		getData(\@otherCases,$query,$dbh, {valref => [$pidm, $caseid]});
		foreach my $otherCase (@otherCases) {
			next if ($otherCase->{'CaseID'} eq $caseid);
			$otherCase->{'PartyTypeDesc'} = ucfirst(lc($otherCase->{'PartyTypeDesc'}));
			push(@{$partyRef->{$otherCase->{'PersonID'}}->{'OtherCases'}}, $otherCase);
		}
	}
	
	$parties = $partyRef;
}

# pass the pidm of the party
sub buildAddress {
    my $id = shift;
    my $caseid = shift;
	my $dbh = shift;

    my $addr;

    # look for 3 types of addresses - MA, BU, and RE
	my @addresses;
	lookupMailingAddress(\@addresses,$id,$caseid,$dbh);
	
	my @aTypes;
	foreach my $address (@addresses) {
		push(@aTypes, $address->{'AddrType'});
	}
	
	my %addrList;
	my $confidential = 0;
	foreach my $atype (@aTypes) {
		my $tmpAddr;
	
		#switch ($atype) {
		#	case "Mailing"		{$tmpAddr = qq{<span style="font-size: smaller; color: blue">Mailing Address<br/></span>}};
		#	case "Business"		{$tmpAddr = qq{<span style="font-size: smaller; color: blue">Business Address<br/></span>}};
		#	case "Residence"		{$tmpAddr = qq{<span style="font-size: smaller; color: blue">Residential Address<br/></span>}};
		#	case "Alternate"		{$tmpAddr = qq{<span style="font-size: smaller; color: blue">Alternate Address<br/></span>}};
		#}
		
		my $addDisp;
		if($atype eq "Residence"){
			$addDisp = "Residential";
		}
		elsif($atype eq "Property Address"){
			$addDisp = "Property";
		}
		else{
			$addDisp = $atype;
		}
		$tmpAddr = qq{<span style="font-size: smaller; color: blue">$addDisp Address<br/></span>};
	
		foreach my $address (@addresses) {
			if ($address->{'AddrType'} eq $atype) {
				if ($address->{'Confidential'}) {
					$tmpAddr =~ s/Address/Address (CONFIDENTIAL)/g;
				}
				
				my $line1 = sprintf("%s", $address->{'Address1'});
				my $line2 = sprintf("%s", $address->{'Address2'});
				my $line3 = sprintf("%s, %s %s", $address->{'City'}, $address->{'State'},
									$address->{'Zip'});
				foreach my $line ($line1, $line2, $line3) {
					$line =~ s/^\s+//g;
					$line =~ s/\s+$//g;
					$line =~ s/\s+ / /g;
				}
				if (($address->{'Address2'} eq "")) {
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
	foreach my $atype (@aTypes) {
		if (defined($addrList{$atype})) {
			$addrString .= $addrList{$atype};
		}
	}
	
    return ($addrString, $confidential);
}

sub lookupMailingAddress {
   # Looks up mailing address(es) for party.  If $addressType isn't specified, then it will return
	# the MA type address, is specified; if not, returns BU, then RE.

	# If $addressRef is a hash ref, then it will build the appropriate string and populate the hashj
	# element (based on the PIDM) with that string.  If it's an array ref, then it will simply
	# push all of the addresses onto the array and allow the caller to deal with it.
	my $addressRef = shift;
	my $pidm = shift;
   my $caseid = shift;
	my $dbh = shift;
	my $addressType = shift;
	my $partyId = shift;

	$dbh = dbConnect($db);
   my $schema = getDbSchema($db);

	my @valref = ($pidm);

    my $query = qq {
		SELECT
			PartyID as PersonID,
            Address1,
            Address2,
			City,
			State,
			ZipCode as Zip,
			CASE
               WHEN AddressType IS NULL
               THEN 'Business'
               ELSE
               AddressType
            END AS AddrType,
			PhoneNumber,
			CASE 
				WHEN ConfidentialAddress is NULL
                THEN 0
                WHEN ConfidentialAddress = 0
                THEN 0
				ELSE 1
			END as Confidential
		FROM
            $schema.vAllPartyAddress
		WHERE
			PartyID = ?
            AND CaseID = ?
			AND ( AddressActive = 'Yes' OR AddressActive IS NULL)
			AND ( DefaultAddress = 'Yes' 
				OR ( PartyType = 'ATTY' AND DefaultAddress IS NULL )
			)
	};
    
	if (!defined($addressType)) {
		#$query .= qq { and AddressType IN ('Mailing','Business','Residence','Alternate')};
	} else {
		$query .= qq { and AddressType = ? };
		# Need the type on the valref array
		push(@valref,$addressType);
	}
    
    push(@valref,$caseid);

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
				case 'Mailing'	{
					$hasMA = 1;
					$thisAddr = $address;
					last;
				}
				case 'Business'	{
					$hasBU = 1;
					$thisAddr = $address;
					next;
				}
				case 'Residence' {
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
		my $line1 = sprintf("%s", $thisAddr->{'Address1'});
		$line1 =~ s/^\s+//g;
		$line1 =~ s/\s+$//g;
		$line1 =~ s/\s+/ /g;

		my $line2 = sprintf("%s", $thisAddr->{'Address2'});
		$line2 =~ s/^\s+//g;
		$line2 =~ s/\s+$//g;
		$line2 =~ s/\s+/ /g;

		my %addr;
        $addressRef->{$partyId}->{'Address1'} = $line1;
        $addressRef->{$partyId}->{'Address2'} = $line2;
		$addressRef->{$partyId}->{'City'} = $thisAddr->{'City'};
		$addressRef->{$partyId}->{'State'} = $thisAddr->{'State'};
		$addressRef->{$partyId}->{'Zip'} = $thisAddr->{'Zip'};
		$addressRef->{$partyId}->{'Confidential'} = $thisAddr->{'Confidential'};

		# Do we have a phone number?
		if (defined($thisAddr->{'PhoneNumber'})) {
			$addressRef->{$partyId}->{'AreaCode'} = "";
			$addressRef->{$partyId}->{'PhoneNumber'} = $thisAddr->{'PhoneNumber'};
        } else {
			$addressRef->{$partyId}->{'AreaCode'} = "";
			$addressRef->{$partyId}->{'PhoneNumber'} = "";
		}
	} elsif (ref($addressRef) eq "ARRAY") {
		# Push all of the addresses onto the array
		push(@{$addressRef}, @addresses)
	}
}

# get the judge name for this particular division
sub getjudgedivfromdiv {
   my $thisdiv = shift;
	my $dbh = shift;
   
   $dbh = dbConnect($db);
   my $schema = getDbSchema($db);
   
   my $query = qq{
		SELECT
			Judge_FN as FirstName,
			Judge_LN as LastName,
			Judge_MN as MiddleName
		FROM
			$schema.vDivision_Judge
		WHERE
			DivisionID = ?
		AND 
			EffectiveFrom <= GETDATE()
		AND 
			( EffectiveTo >= GETDATE() OR EffectiveTo IS NULL )
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

sub getSCCaseNumber {
	my $case = shift;
	
	my $dbh = dbConnect($db);
    my $schema = getDbSchema($db);
    my $where;
    
    if ($case =~ /^50-/) {
    	if ($case =~ /(\d\d)-(\d\d\d\d)-(\D\D)-(\d\d\d\d\d\d)-(\D\D\D\D)-(\D\D)/) {
    		$where = " CaseNumber = '$case' ";
    	}
    	else{
    		$where = " CaseNumber LIKE '%$case%' ";
    	}
    }
    else{
    	$case =~ s/-//g;
	    if ($case =~ /(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)/) {
	    	$where = " LegacyCaseNumber = '$case' OR UCN LIKE '50$case%'";
	    }
	    else{
    		$where = " LegacyCaseNumber LIKE '%$case%' OR UCN LIKE '50$case%'";
    	}
    }
    
    my $query = qq {
	    			 SELECT CaseNumber
	    			 FROM $schema.vCase
	    			 WHERE $where
    			};
    			
    my $result = getDataOne($query, $dbh);
    
    return $result->{'CaseNumber'};
}

sub getCaseID {
	my $case = shift;
	
	my $dbh = dbConnect($db);
    my $schema = getDbSchema($db);
    
    my $query = qq {
	    			 SELECT CaseID
	    			 FROM $schema.vCase
	    			 WHERE CaseNumber = ?
    			};
    			
    my $result = getDataOne($query, $dbh, [$case]);
    
    return $result->{'CaseID'};
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
    
    my $shortCase = substr $casenum, 3, 14;
    my $shortCaseNoSlash = $shortCase;
    $shortCaseNoSlash =~ s/-//g;
    
    my $noSlashCase = $casenum;
    $noSlashCase =~ s/-//g;
    
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
				AND (
					ec.case_num = ?
					OR ec.case_num = ?
					or ec.case_num = ?
					OR ec.case_num = ?
				)

        };
        
        getData($olsRef, $query, $vdbh, {valref => [$div, $casenum, $shortCase, $shortCaseNoSlash, $noSlashCase]});
    
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

sub getRegistry {
    my $caseid = shift;
    my $dbh = shift;
    my $regRef = shift;
    my $schema = shift;
    
    if (!defined($schema)) {
        $schema = $DEFAULT_SCHEMA
    };
    
    my $regFeeQuery = qq {
    	SELECT ISNULL(CONVERT(money, SUM(Paid)), 0) AS TotalFees
		FROM $schema.vCaseGLBalance
		WHERE CaseID = ?
		AND ( GLDescription LIKE '%REGISTRY FEE%'
		OR FeeTypeDescription LIKE '%Registry Fee%' ) 
    };
    
    my $regFeeRow = getDataOne($regFeeQuery,$dbh,[$caseid]);
    
    my $totalDepQuery = qq {
    	SELECT ISNULL(CONVERT(money, SUM(Paid)), 0) AS TotalDeposits
		FROM $schema.vCaseGLBalance
		WHERE CaseID = ?
		AND ( FeeTypeDescription LIKE '%Registry Deposit%' 
		OR FeeTypeDescription LIKE '%Conversion Registry Posted%' )
    };
    
    my $totalDepRow = getDataOne($totalDepQuery,$dbh,[$caseid]);
    
    my $balanceQuery = qq {
    	SELECT ISNULL(CONVERT(money, SUM(Paid)), 0) AS TotalDisbursed
		FROM $schema.vCaseGLBalance
		WHERE CaseID = ?
		AND ( FeeTypeDescription LIKE '%Registry disbursement%' 
		OR GLDescription LIKE '%OVPG Overpayment%'
		)
    };
    
    my $balanceRow = getDataOne($balanceQuery,$dbh,[$caseid]);
    
   $regRef->[0]->{'TotalDeposits'} = $totalDepRow->{'TotalDeposits'};
   $regRef->[0]->{'Balance'} = sprintf("%.2f", $totalDepRow->{'TotalDeposits'} - $balanceRow->{'TotalDisbursed'});
   $regRef->[0]->{'TotalDepositsWithFees'} = sprintf("%.2f", $totalDepRow->{'TotalDeposits'} + $regFeeRow->{'TotalFees'});
}

sub getSentences {
    my $caseid = shift;
    my $dbh = shift;
    my $sentenceRef = shift;
    my $schema = shift;
    
    if (!defined($schema)) {
        $schema = $DEFAULT_SCHEMA
    };

    my $query = qq {
        select
            CONVERT(varchar, SentenceImposedDate, 101) as SentenceImposedDate,
            ChargeCount,
            Sentence,
            Confinement,
            CAST(JailTimeYears AS INT) AS JailTimeYears,
            CAST(JailTimeMonths AS INT) AS JailTimeMonths,
            CAST(JailTimeDays AS INT) AS JailTimeDays,
            CAST(ProbationTimeYears AS INT) AS ProbationTimeYears,
            CAST(ProbationTimeMonths AS INT) AS ProbationTimeMonths,
            CAST(ProbationTimeDays AS INT) AS ProbationTimeDays,
            CAST(MinMandatoryYears AS INT) AS MinMandatoryYears,
            CAST(MinMandatoryMonths AS INT) AS MinMandatoryMonths,
            CAST(MinMandatoryDays AS INT) AS MinMandatoryDays,
            CAST(CreditTimeYears AS INT) AS CreditTimeYears,
            CAST(CreditTimeMonths AS INT) AS CreditTimeMonths,
            CAST(CreditTimeDays AS INT) AS CreditTimeDays,
            SentenceConditions,
            ConfinementConditions,
            SentenceStatus,
            ConfinementSentenceTerm,
			ProbationSentenceTerm,
			CommunityControlSentenceTerm, 
			DLSuspensionSentenceTerm
        from
            $schema.vCharge with(nolock)
        where
            CaseID = ?
        AND ( 
        		( Sentence IS NOT NULL AND Sentence <> '' )
        		OR ( Confinement IS NOT NULL AND Confinement <> '' ) 
        	)
        ORDER BY
        	ChargeCount    
    };

    getData($sentenceRef, $query, $dbh, {valref => [$caseid]});
}

sub getEServiceAddresses {
	my $case = shift;
	my $caseid = shift;
	
	my $dbh = dbConnect($db);
	my $esdbh = dbConnect("eservice");
	
	my @parties;
    my @attorneys;
    getParties_civil($caseid, $dbh, \@parties, \@attorneys, $case);
    my @allParties = (@parties, @attorneys);
    my @portalEmails;
    
	foreach my $party (@allParties) {
        $party->{'isEservice'} = 0;

        $party->{'EmailAddresses'} = [];
        
        if ($party->{'PartyType'} =~ /ATTY|AGAL/) {
            EService::getAttorneyAddresses($case, $party->{'EmailAddresses'}, $esdbh, $party->{'BarNumber'}, \$party->{'isEservice'}, $caseid);
            my $portal_ucn = $case;
            if ($case =~ /^50/) {
		        $portal_ucn =~ s/-//g;
		    } 
		    
            EService::getPortalAddresses($portal_ucn, \@portalEmails);
            
            foreach my $portal_address (@portalEmails) {
            	$portal_address->{'bar_number'} =~ s/^FL//;
            	
           	 	my $partyBar = $party->{'BarNumber'};
           	 	$partyBar =~ s/^0+//;
           	 	
            	if($portal_address->{'bar_number'} eq $partyBar){
            		my $found = 0;
            		foreach my $existing (@{$party->{'EmailAddresses'}}) {
            			if(lc($existing->{'email_addr'}) eq lc($portal_address->{'email_addr'})){
            				$found = 1;
            			}
            		}
            		            		
            		if(!$found){
            			push(@{$party->{'EmailAddresses'}}, $portal_address);
            		}
            	}
            }
        } else {
            # Do this whether or not the party is pro se, because some represented parties register, anyway.
            EService::getProSeAddresses($case, $party->{'EmailAddresses'}, $esdbh, $party->{'PIDM'}, $caseid);
            if (scalar(@{$party->{'EmailAddresses'}})) {
                $party->{'tdCols'} += 1;
                $party->{'isEservice'} = 1;
            }
        }
        
        if($party->{'eMailAddress'} ne ""){
        	my $found2 = 0;
        	my %scEmail;
        	$scEmail{'bar_number'} = $party->{'BarNumber'};
        	$scEmail{'fullname'} = $party->{'FullName'};
        	$scEmail{'email_addr'} = $party->{'eMailAddress'};
        	foreach my $existing (@{$party->{'EmailAddresses'}}){
        		if(lc($existing->{'email_addr'}) eq lc($party->{'eMailAddress'})){
        			$found2 = 1;
        			
        		}
        	}
        	
        	if(!$found2){
            	push(@{$party->{'EmailAddresses'}}, \%scEmail);
           	}
        }
    }

    $esdbh->disconnect;
    
    my %eServiceEmails;
    foreach my $party (@allParties) {
    
    	my $person_id;
    	if ($party->{'PartyType'} =~ /ATTY|AGAL/) {
    		my $partyBar = $party->{'BarNumber'};
    		$partyBar =~ s/^0+//;
    		$person_id = $partyBar;
    	}
    	else{
    		$person_id = $party->{'PIDM'};
    	}
    	
    	my $emailAddress = "";
    	my $count = 0;
    	foreach my $email (@{$party->{'EmailAddresses'}}) {
    		if($count > 0){
    			$emailAddress .= "<br/>";
    		}
    		$emailAddress .= $email->{'email_addr'};
    		$count++;
    	}
    	
    	$eServiceEmails{$person_id} = $emailAddress;
    }
    
    return \%eServiceEmails;
}

sub getJuvenileCMData{
	my $casenum = shift;
	my $caseid = shift;
    my $dbh = shift;
    my $juvRef = shift;
    my $schema = shift;
	
	#Now let's check our own data....
	my $idbh = dbConnect("icms");
	
	my @children;
	my @mother;
	my @fathers;
	my @case_plans;
	my @orders;
	my @notes;
	
	#Get moms, dads, and children
	my $peopleQuery = qq{
		SELECT PersonID,
			CONCAT(FirstName, ' ', MiddleName, ' ', LastName) AS FullName,
			PartyTypeDescription AS PartyType,
			CONVERT(varchar(10), DOB, 101) as DOB
		FROM $schema.vAllParties
		WHERE CaseID = ?
		AND PartyType IN ('MTH', 'FTH', 'CHLD')
	};
	
	my @people;
	getData(\@people, $peopleQuery, $dbh, {hashkey => "PersonID", valref => [$caseid]}); 
	
	#Only because we allow additional fathers..
	my $fatherQuery = qq{
		SELECT person_id AS PersonID,
		father_name AS FullName,
		'FATHER' AS PartyType
		FROM case_management.juv_fathers
		WHERE case_id = ?
	};
	
	my @fatherPeople;
	getData(\@fatherPeople, $fatherQuery, $idbh, {hashkey => "PersonID", valref => [$caseid]}); 
	
	if(scalar(@fatherPeople)){
		foreach my $f (@fatherPeople) {
			my $found;
			foreach my $p (@people){
				if($p->{'PersonID'} eq $f->{'PersonID'}){
					$found = 1;
				}
			}
			
			if(!$found){
				my %person;
				$person{'PersonID'} = $f->{'PersonID'};
				$person{'FullName'} = $f->{'FullName'};
				$person{'PartyType'} = $f->{'PartyType'};
				push(@people, \%person);
			}
		}
	}
	
	#Attorneys
	my $attyQuery = qq{
			SELECT attorney_type,
			attorney_name,
			CASE WHEN active = 1
				THEN 'Yes'
			ELSE 'No'
			END AS active,
			juv_attorney_id,
			person_id
			FROM case_management.juv_attorneys
			WHERE case_id = ?
		};
					
		my %aRes;
		my @attorneys;
		getData(\%aRes, $attyQuery, $idbh, {hashkey => "juv_attorney_id", valref => [$caseid]});
		if(keys %aRes){
			foreach my $a (keys %aRes) {
				my %atty;
				$atty{'attorney_type'} = $aRes{$a}[0]->{'attorney_type'};
				$atty{'attorney_name'} = $aRes{$a}[0]->{'attorney_name'};
				$atty{'active'} = $aRes{$a}[0]->{'active'};
				
				foreach my $p (@people){
					if($p->{'PersonID'} eq $aRes{$a}[0]->{'person_id'}){
						$atty{'represents'} = $p->{'FullName'} . " (" . $p->{'PartyType'} . ")";
					}
				}
				
				push(@attorneys, \%atty);
			}
		}
	
	#Case Info
	my $ciQuery = qq{
		SELECT *
		FROM case_management.juv_case_info
		WHERE case_id = ?
	};
	
	my $ciRow = getDataOne($ciQuery, $idbh, [$caseid]);
	
	my $cls_attorney_name;
	my $gal_name;
	my $gal_attorney_name;
	my $dcm_name;
	if($ciRow){
		if($ciRow->{'cls_attorney_name'}){
			$cls_attorney_name = $ciRow->{'cls_attorney_name'};
		}
		if($ciRow->{'gal_name'}){
			$gal_name = $ciRow->{'gal_name'};
		}
		if($ciRow->{'gal_attorney_name'}){
			$gal_attorney_name = $ciRow->{'gal_attorney_name'};
		}
		if($ciRow->{'dcm_name'}){
			$dcm_name = $ciRow->{'dcm_name'};
		}
	}
	
	#Case Plans
	my $query = "	SELECT CASE 
						WHEN executed = '1'
							THEN 'Yes'
						WHEN executed = '0'
							THEN 'No'
						ELSE
						NULL 
					END AS executed,
					DATE_FORMAT(executed_date, '%m/%d/%Y') AS executed_date,
					DATE_FORMAT(goal_date, '%m/%d/%Y') AS goal_date,
					DATE_FORMAT(order_date, '%m/%d/%Y') AS order_date,
					docket_number,
					juv_case_plan_id,
					CONCAT(REPLACE(case_number, '-', ''), '|', trakman_object_id) AS UCNObj,
					DATE_FORMAT(file_date, '%m/%d/%Y') AS file_date
					FROM case_management.juv_case_plans
					WHERE case_id = ?
					ORDER BY file_date";
	
	my %cpRes;
	getData(\%cpRes, $query, $idbh, {hashkey => "juv_case_plan_id", valref => [$caseid]});

	my $executed;
	my $executed_date;
	if(keys %cpRes){
		foreach my $c (keys %cpRes) {
			if(!scalar($cpRes{$c}[0]->{'executed'})){
				$executed = "";
			}
			else{
				$executed = $cpRes{$c}[0]->{'executed'};
			}
			
			my $executed_date;
			if(!scalar($cpRes{$c}[0]->{'executed_date'}) || ($cpRes{$c}[0]->{'executed_date'} eq '00/00/0000')){
				$executed_date = "";
			}
			else{
				$executed_date = $cpRes{$c}[0]->{'executed_date'};
			}
			
			my $goal_date;
			if(!scalar($cpRes{$c}[0]->{'goal_date'}) || ($cpRes{$c}[0]->{'goal_date'} eq '00/00/0000')){
				$goal_date = "";
			}
			else{
				$goal_date = $cpRes{$c}[0]->{'goal_date'};
			}
			
			my $order_date;
			if(!scalar($cpRes{$c}[0]->{'order_date'}) || ($cpRes{$c}[0]->{'order_date'} eq '00/00/0000')){
				$order_date = "";
			}
			else{
				$order_date = $cpRes{$c}[0]->{'order_date'};
			}
			
			my $file_date;
			if(!scalar($cpRes{$c}[0]->{'file_date'}) || ($cpRes{$c}[0]->{'file_date'} eq '00/00/0000')){
				$file_date = "";
			}
			else{
				$file_date = $cpRes{$c}[0]->{'file_date'};
			}
			
			my $relQuery = qq{
				SELECT person_id
				FROM case_management.juv_related_case_plans
				WHERE case_plan_id = ?
			};
			
			my @relCpRes;
			getData(\@relCpRes, $relQuery, $idbh, {hashkey => "person_id", valref => [$cpRes{$c}[0]->{'juv_case_plan_id'}]});
			
			my @relCPPeople; 
			if(scalar(@relCpRes)){
				foreach my $r (@relCpRes) {
					push(@relCPPeople, $r->{'person_id'});
				}
			}
			
			my %cp;
			$cp{'cp_exec'} = $executed;
			$cp{'cp_exec_date'} = $executed_date;
			$cp{'cp_goal_date'} = $goal_date;
			$cp{'cp_order_date'} = $order_date;
			$cp{'cp_file_date'} = $file_date;
			$cp{'UCNObj'} = $cpRes{$c}[0]->{'UCNObj'};
			$cp{'RelatedCasePlans'} = \@relCPPeople;
			
			push(@case_plans, \%cp);
		}
	}
	
	my $orderQuery = qq{
		SELECT order_title,
		DATE_FORMAT(order_date, '%m/%d/%Y') AS order_date,
		DATE_FORMAT(due_date, '%m/%d/%Y') AS due_date,
		CASE 
			WHEN completed = '1'
				THEN 'Yes'
			WHEN completed = '0'
				THEN 'No'
			ELSE
				NULL 
		END AS completed,
		DATE_FORMAT(completed_date, '%m/%d/%Y') AS completed_date,
		juv_order_id
		FROM case_management.juv_orders
		WHERE case_id = ?
	};
		
	my @oRes;
	getData(\@oRes, $orderQuery, $idbh, {valref => [$caseid]});
	if(scalar(@oRes)){
		foreach my $o (@oRes) {
			my %order;
			$order{'order_title'} = $o->{'order_title'};
			$order{'juv_order_id'} = $o->{'juv_order_id'};
			my $due_date;
			if(!scalar($o->{'due_date'}) || ($o->{'due_date'} eq '00/00/0000')){
				$due_date = "";
			}
			else{
				$due_date = $o->{'due_date'};
			}
			my $order_date;
			if(!scalar($o->{'order_date'}) || ($o->{'order_date'} eq '00/00/0000')){
				$order_date = "";
			}
			else{
				$order_date = $o->{'order_date'};
			}
			my $completed_date;
			if(!scalar($o->{'completed_date'}) || ($o->{'completed_date'} eq '00/00/0000')){
				$completed_date = "";
			}
			else{
				$completed_date = $o->{'completed_date'};
			}
			$order{'order_title'} = $o->{'order_title'};
			$order{'due_date'} = $due_date;
			$order{'order_date'} = $order_date;
			$order{'completed'} = $o->{'completed'};
			$order{'completed_date'} = $completed_date;
			
			my $orderForQuery = qq{
				SELECT person_id
				FROM case_management.juv_order_parties
				WHERE case_id = ?
				AND juv_order_id = ?
			};
			
			my @people;
			my @ofRes;
			getData(\@ofRes, $orderForQuery, $idbh, {valref => [$caseid, $o->{'juv_order_id'}]});
			
			if(scalar(@ofRes)){
				foreach my $o (@ofRes) {
					push(@people, $o->{'person_id'});
				}
			}
			
			$order{'order_for'} = \@people;
			push(@orders, \%order);
		}
	}
	
	my $notesQuery = qq{
		SELECT DATE_FORMAT(event_date, '%m/%d/%Y') AS event_date,
		event_note,
		created_user
		FROM case_management.juv_event_notes
		WHERE case_id = ?
	};
		
	my @nRes;
	getData(\@nRes, $notesQuery, $idbh, {valref => [$caseid]});
	if(scalar(@nRes)){
		foreach my $n (@nRes) {
			my %note;
			my $entered_date;
			if(!scalar($n->{'event_date'}) || ($n->{'event_date'} eq '00/00/0000')){
				$entered_date = "";
			}
			else{
				$entered_date = $n->{'event_date'};
			}
			
			$note{'entered_date'} = $entered_date;
			$note{'note'} = $n->{'event_note'};
			$note{'created_by'} = $n->{'created_user'};

			push(@notes, \%note);
		}
	}

	#Children
	$query = "	SELECT 
					c.child_name,
					DATE_FORMAT(c.dob, '%m/%d/%Y') AS DOB,
					TIMESTAMPDIFF(YEAR, DATE_FORMAT(c.dob, '%Y-%m-%d'), CURDATE()) AS age,
					c.father_person_id,
					c.father_name,
					c.type_of_father,
					c.child_where,
					c.child_with,
					c.child_address,
					DATE_FORMAT(c.date_placed, '%m/%d/%Y') AS date_placed,
				 	CASE 
						WHEN c.tico = 1
						THEN 'Yes'
						WHEN c.tico = 0
							THEN 'No'
						ELSE NULL
					END AS tico,
					c.person_id,
					CASE 
						WHEN c.home_study_ind = 1
						THEN 'Yes'
						WHEN c.home_study_ind = 0
							THEN 'No'
						ELSE NULL
					END AS home_study_ind,
					DATE_FORMAT(c.home_study_approved_date, '%m/%d/%Y') AS home_study_approved_date,
					DATE_FORMAT(c.home_study_filed_date, '%m/%d/%Y') AS home_study_filed_date,
					CASE 
						WHEN in_custody_ind = 1
						THEN 'Yes'
						WHEN in_custody_ind = 0
							THEN 'No'
						ELSE NULL
					END AS in_custody_ind,
					in_custody_where,
					CASE 
						WHEN no_contact_order = 1
						THEN 'Yes'
						WHEN no_contact_order = 0
							THEN 'No'
						ELSE NULL
					END AS no_contact_ind,
					DATE_FORMAT(f.no_contact_entered, '%m/%d/%Y') AS no_contact_entered,
					DATE_FORMAT(f.no_contact_vacated, '%m/%d/%Y') AS no_contact_vacated,
					recom,
					c.notes
					FROM 
						case_management.juv_children c
					LEFT OUTER JOIN case_management.juv_fathers f
						ON c.case_id = f.case_id
						AND ( c.person_id = f.person_id
						OR c.father_name = f.father_name)
					WHERE c.case_id = ?
					ORDER BY c.dob";
	
	my %iRes;
	getData(\%iRes, $query, $idbh, {hashkey => "person_id", valref => [$caseid]});

	if(keys %iRes){
		foreach my $p (keys %iRes) {
			#foreach my $c (@children){
				#if($c->{'PersonID'} eq $iRes{$p}[0]->{'person_id'}){
					my %child;
					my $siQuery = qq{
						SELECT identifier_desc
						FROM case_management.juv_identifiers
						WHERE case_id = ?
						AND person_id = ?
					};
					
					my @siRes;
					my @specialIdentifiers;
					getData(\@siRes, $siQuery, $idbh, {valref => [$caseid, $iRes{$p}[0]->{'person_id'}]});
					if(scalar(@siRes)){
						foreach my $si (@siRes) {
							push(@specialIdentifiers, $si->{'identifier_desc'});
						}
					}
					
					my $pmQuery = qq{
						SELECT psych_meds_requested_by,
						DATE_FORMAT(psych_meds_requested_date, '%m/%d/%Y') AS psych_meds_requested_date,
						CASE 
							WHEN psych_meds_affidavit_ind = 1
							THEN 'Yes'
							ELSE 'No'
						END as psych_meds_affidavit_ind,
						psych_meds_order_ind,
						DATE_FORMAT(psych_meds_order_date, '%m/%d/%Y') AS psych_meds_order_date,
						psych_meds_trakman_object_id,
						psych_meds,
						juv_psych_meds_id
						FROM case_management.juv_psych_meds
						WHERE case_id = ?
						AND person_id = ?
					};
					
					my %pmRes;
					my @pms;
					getData(\%pmRes, $pmQuery, $idbh, {hashkey => "juv_psych_meds_id", valref => [$caseid, $iRes{$p}[0]->{'person_id'}]});
					if(keys %pmRes){
						foreach my $p (keys %pmRes) {
							my %pm;
							$pm{'psych_meds_requested_by'} = $pmRes{$p}[0]->{'psych_meds_requested_by'};
							
							my $pm_req_date;
							if(!scalar($pmRes{$p}[0]->{'psych_meds_requested_date'}) || ($pmRes{$p}[0]->{'psych_meds_requested_date'} eq '00/00/0000')){
								$pm_req_date = "";
							}
							else{
								$pm_req_date = $pmRes{$p}[0]->{'psych_meds_requested_date'};
							}
							
							$pm{'psych_meds_requested_date'} = $pm_req_date;
							
							$pm{'psych_meds_affidavit_ind'} = $pmRes{$p}[0]->{'psych_meds_affidavit_ind'};
							$pm{'psych_meds_order_ind'} = $pmRes{$p}[0]->{'psych_meds_order_ind'};
							
							my $pm_ord_date;
							if(!scalar($pmRes{$p}[0]->{'psych_meds_order_date'}) || ($pmRes{$p}[0]->{'psych_meds_order_date'} eq '00/00/0000')){
								$pm_ord_date = "";
							}
							else{
								$pm_ord_date = $pmRes{$p}[0]->{'psych_meds_order_date'};
							}
							
							$pm{'psych_meds_order_date'} = $pm_ord_date;
							
							$pm{'psych_meds'} = $pmRes{$p}[0]->{'psych_meds'};
							push(@pms, \%pm);
						}
					}
					
					$child{'psych_meds'} = \@pms;
					$child{'special_identifiers'} = join(', ', @specialIdentifiers);
					$child{'Name'} = $iRes{$p}[0]->{'child_name'};
					$child{'DOB'} = $iRes{$p}[0]->{'DOB'};
					$child{'age'} = $iRes{$p}[0]->{'age'};
					$child{'Age'} = getageinyears($iRes{$p}[0]->{'DOB'});
					#$child{'Sex'} = $iRes{$p}[0]->{'Sex'};
					$child{'PersonID'} = $iRes{$p}[0]->{'person_id'};
					$child{'FatherPersonID'} = $iRes{$p}[0]->{'father_person_id'};
					$child{'FatherName'} = $iRes{$p}[0]->{'father_name'};
					$child{'father_type'} = $iRes{$p}[0]->{'type_of_father'};
					$child{'ChildWhere'} = $iRes{$p}[0]->{'child_where'};
					$child{'ChildWith'} = $iRes{$p}[0]->{'child_with'};
					$child{'ChildAddress'} = $iRes{$p}[0]->{'child_address'};
					
					my $date_placed;
					if(defined($iRes{$p}[0]->{'date_placed'}) && ($iRes{$p}[0]->{'date_placed'} != "0000-00-00")){
						$date_placed = $iRes{$p}[0]->{'date_placed'};
					}
					else{
						$date_placed = "";
					}
					
					$child{'date_placed'} = $date_placed;
					$child{'home_study_ind'} = $iRes{$p}[0]->{'home_study_ind'};
					
					my $home_study_approved_date;
					if(defined($iRes{$p}[0]->{'home_study_approved_date'}) && ($iRes{$p}[0]->{'home_study_approved_date'} != "0000-00-00")){
						$home_study_approved_date = $iRes{$p}[0]->{'home_study_approved_date'};
					}
					else{
						$home_study_approved_date = "";
					}
					
					my $home_study_filed_date;
					if(defined($iRes{$p}[0]->{'home_study_filed_date'}) && ($iRes{$p}[0]->{'home_study_filed_date'} != "0000-00-00")){
						$home_study_filed_date = $iRes{$p}[0]->{'home_study_filed_date'};
					}
					else{
						$home_study_filed_date = "";
					}
					
					$child{'home_study_approved_date'} = $home_study_approved_date;
					$child{'home_study_filed_date'} = $home_study_filed_date;
					
					$child{'TICO'} = $iRes{$p}[0]->{'tico'};
					$child{'notes'} = $iRes{$p}[0]->{'notes'};
					
					push(@children, \%child);
				#}
			#}
			
		}
	}
	
	$query = "	SELECT 
						DATE_FORMAT(f.shelter_dos, '%m/%d/%Y') AS shelter_dos,
						DATE_FORMAT(f.supp_findings_dos, '%m/%d/%Y') AS supp_findings_dos,
						DATE_FORMAT(f.arraignment_dos, '%m/%d/%Y') AS arraignment_dos,
						DATE_FORMAT(f.dependency_dos, '%m/%d/%Y') AS dependency_dos,
						DATE_FORMAT(f.tpr_dos, '%m/%d/%Y') AS tpr_dos,
						DATE_FORMAT(f.shelter_order_filed, '%m/%d/%Y') AS shelter_order_filed,
						DATE_FORMAT(f.dependency_order_filed, '%m/%d/%Y') AS dependency_order_filed,
						DATE_FORMAT(f.supp_findings_order_filed, '%m/%d/%Y') AS supp_findings_order_filed,
						DATE_FORMAT(f.tpr_order_filed, '%m/%d/%Y') AS tpr_order_filed,
						DATE_FORMAT(f.arraignment_order_filed, '%m/%d/%Y') AS arraignment_order_filed,
						CASE 
							WHEN f.offending = 1
							THEN 'Yes'
							WHEN f.offending = 0
								THEN 'No'
							ELSE NULL
						END AS offending,
						CASE 
							WHEN in_custody_ind = 1
							THEN 'Yes'
							WHEN in_custody_ind = 0
								THEN 'No'
							ELSE NULL
						END AS in_custody_ind,
						in_custody_where,
						CASE 
							WHEN no_contact_order = 1
							THEN 'Yes'
							WHEN no_contact_order = 0
								THEN 'No'
							ELSE NULL
						END AS no_contact_ind,
						DATE_FORMAT(f.no_contact_entered, '%m/%d/%Y') AS no_contact_entered,
						DATE_FORMAT(f.no_contact_vacated, '%m/%d/%Y') AS no_contact_vacated,
						recom,
						f.person_id,
						f.father_name
					FROM 
						case_management.juv_fathers f
					WHERE case_id = ?";
	
	my %fRes;
	getData(\%fRes, $query, $idbh, {hashkey => "person_id", valref => [$caseid]});
	
	if(keys %fRes){
		foreach my $p (keys %fRes) {
			my %f;
			#foreach my $f (@fathers){
				my $fatherName = $fRes{$p}[0]->{'father_name'};
				#if($f->{'PersonID'} eq $fRes{$p}[0]->{'person_id'}){
					
					$f{'Name'} = $fatherName;
					$f{'PersonID'} = $fRes{$p}[0]->{'person_id'};
					$f{'Offending'} = $fRes{$p}[0]->{'offending'};
					$f{'in_custody_ind'} = $fRes{$p}[0]->{'in_custody_ind'};
					$f{'in_custody_where'} = $fRes{$p}[0]->{'in_custody_where'};
					$f{'no_contact_ind'} = $fRes{$p}[0]->{'no_contact_ind'};
					
					my $noContactWhoQuery = qq{
						SELECT no_contact_with_person_id
						FROM case_management.juv_no_contact_parties
						WHERE case_id = ?
						AND person_id = ?
					};
					
					my @people;
					my @ncRes;
					getData(\@ncRes, $noContactWhoQuery, $idbh, {valref => [$caseid, $f{'PersonID'}]});
					
					if(scalar(@ncRes)){
						foreach my $nc (@ncRes) {
							push(@people, $nc->{'no_contact_with_person_id'});
						}
					}
					
					$f{'no_contact_who'} = \@people;
					
					my $siQuery = qq{
						SELECT identifier_desc
						FROM case_management.juv_identifiers
						WHERE case_id = ?
						AND person_id = ?
					};
					
					my @siRes;
					my @specialIdentifiers;
					getData(\@siRes, $siQuery, $idbh, {valref => [$caseid, $f{'PersonID'}]});
					if(scalar(@siRes)){
						foreach my $si (@siRes) {
							push(@specialIdentifiers, $si->{'identifier_desc'});
						}
					}
					
					$f{'special_identifiers'} = join(', ', @specialIdentifiers);
					
					my $no_contact_entered;
					if(defined($fRes{$p}[0]->{'no_contact_entered'}) && ($fRes{$p}[0]->{'no_contact_entered'} != "0000-00-00")){
						$no_contact_entered = $fRes{$p}[0]->{'no_contact_entered'};
					}
					else{
						$no_contact_entered = "";
					}
					$f{'no_contact_entered'} = $no_contact_entered;
					
					my $no_contact_vacated;
					if(defined($fRes{$p}[0]->{'no_contact_vacated'}) && ($fRes{$p}[0]->{'no_contact_vacated'} != "0000-00-00")){
						$no_contact_vacated = $fRes{$p}[0]->{'no_contact_vacated'};
					}
					else{
						$no_contact_vacated = "";
					}
					$f{'no_contact_vacated'} = $no_contact_vacated;
					
					$f{'recom'} = $fRes{$p}[0]->{'recom'};
					
					my $shelter_dos;
					if(defined($fRes{$p}[0]->{'shelter_dos'}) && ($fRes{$p}[0]->{'shelter_dos'} != "0000-00-00")){
						$shelter_dos = $fRes{$p}[0]->{'shelter_dos'};
					}
					else{
						$shelter_dos = "";
					}
					$f{'shelter_dos'} = $shelter_dos;
					
					my $arraignment_dos;
					if(defined($fRes{$p}[0]->{'arraignment_dos'}) && ($fRes{$p}[0]->{'arraignment_dos'} != "0000-00-00")){
						$arraignment_dos = $fRes{$p}[0]->{'arraignment_dos'};
					}
					else{
						$arraignment_dos = "";
					}
					
					$f{'arraignment_dos'} = $arraignment_dos;
					
					my $dependency_dos;
					if(defined($fRes{$p}[0]->{'dependency_dos'}) && ($fRes{$p}[0]->{'dependency_dos'} != "0000-00-00")){
						$dependency_dos = $fRes{$p}[0]->{'dependency_dos'};
					}
					else{
						$dependency_dos = "";
					}
					$f{'dependency_dos'} = $dependency_dos;
					
					my $supp_findings_dos;
					if(defined($fRes{$p}[0]->{'supp_findings_dos'}) && ($fRes{$p}[0]->{'supp_findings_dos'} != "0000-00-00")){
						$supp_findings_dos = $fRes{$p}[0]->{'supp_findings_dos'};
					}
					else{
						$supp_findings_dos = "";
					}
					$f{'supp_findings_dos'} = $supp_findings_dos;
					
					my $tpr_dos;
					if(defined($fRes{$p}[0]->{'tpr_dos'}) && ($fRes{$p}[0]->{'tpr_dos'} != "0000-00-00")){
						$tpr_dos = $fRes{$p}[0]->{'tpr_dos'};
					}
					else{
						$tpr_dos = "";
					}
					
					$f{'tpr_dos'} = $tpr_dos;
					
					my $shelter_order_filed;
					if(defined($fRes{$p}[0]->{'shelter_order_filed'}) && ($fRes{$p}[0]->{'shelter_order_filed'} != "0000-00-00")){
						$shelter_order_filed = $fRes{$p}[0]->{'shelter_order_filed'};
					}
					else{
						$shelter_order_filed = "";
					}
					$f{'shelter_order_filed'} = $shelter_order_filed;
					
					my $arraignment_order_filed;
					if(defined($fRes{$p}[0]->{'arraignment_order_filed'}) && ($fRes{$p}[0]->{'arraignment_order_filed'} != "0000-00-00")){
						$arraignment_order_filed = $fRes{$p}[0]->{'arraignment_order_filed'};
					}
					else{
						$arraignment_order_filed = "";
					}
					
					$f{'arraignment_order_filed'} = $arraignment_order_filed;
					
					my $dependency_order_filed;
					if(defined($fRes{$p}[0]->{'dependency_order_filed'}) && ($fRes{$p}[0]->{'dependency_order_filed'} != "0000-00-00")){
						$dependency_order_filed = $fRes{$p}[0]->{'dependency_order_filed'};
					}
					else{
						$dependency_order_filed = "";
					}
					$f{'dependency_order_filed'} = $dependency_order_filed;
					
					my $supp_findings_order_filed;
					if(defined($fRes{$p}[0]->{'supp_findings_order_filed'}) && ($fRes{$p}[0]->{'supp_findings_order_filed'} != "0000-00-00")){
						$supp_findings_order_filed = $fRes{$p}[0]->{'supp_findings_order_filed'};
					}
					else{
						$supp_findings_order_filed = "";
					}
					$f{'supp_findings_order_filed'} = $supp_findings_order_filed;
					
					my $tpr_order_filed;
					if(defined($fRes{$p}[0]->{'tpr_order_filed'}) && ($fRes{$p}[0]->{'tpr_order_filed'} != "0000-00-00")){
						$tpr_order_filed = $fRes{$p}[0]->{'tpr_order_filed'};
					}
					else{
						$tpr_order_filed = "";
					}
					
					$f{'tpr_order_filed'} = $tpr_order_filed;
					
					
					push(@fathers, \%f);
					
				#}
			
			#}
		}
	}
	
	#Mother
	$query = "	SELECT CASE 
					WHEN offending = 1
					THEN 'Yes'
					WHEN offending = 0
						THEN 'No'
					ELSE NULL
					END AS offending,
					DATE_FORMAT(shelter_dos, '%m/%d/%Y') AS shelter_dos,
					DATE_FORMAT(dependency_dos, '%m/%d/%Y') AS dependency_dos,
					DATE_FORMAT(supp_findings_dos, '%m/%d/%Y') AS supp_findings_dos,
					DATE_FORMAT(tpr_dos, '%m/%d/%Y') AS tpr_dos,
					DATE_FORMAT(arraignment_dos, '%m/%d/%Y') AS arraignment_dos,
					DATE_FORMAT(shelter_order_filed, '%m/%d/%Y') AS shelter_order_filed,
					DATE_FORMAT(dependency_order_filed, '%m/%d/%Y') AS dependency_order_filed,
					DATE_FORMAT(supp_findings_order_filed, '%m/%d/%Y') AS supp_findings_order_filed,
					DATE_FORMAT(tpr_order_filed, '%m/%d/%Y') AS tpr_order_filed,
					DATE_FORMAT(arraignment_order_filed, '%m/%d/%Y') AS arraignment_order_filed,
					mother_name,
					person_id,
					CASE 
						WHEN in_custody_ind = 1
						THEN 'Yes'
						WHEN in_custody_ind = 0
							THEN 'No'
						ELSE NULL
					END AS in_custody_ind,
					in_custody_where,
					CASE 
						WHEN no_contact_order = 1
						THEN 'Yes'
						WHEN no_contact_order = 0
							THEN 'No'
						ELSE NULL
					END AS no_contact_ind,
					DATE_FORMAT(no_contact_entered, '%m/%d/%Y') AS no_contact_entered,
					DATE_FORMAT(no_contact_vacated, '%m/%d/%Y') AS no_contact_vacated,
					recom
				FROM case_management.juv_mothers
				WHERE case_id = ?";
	
	my $row = getDataOne($query, $idbh, [$caseid]);
	
	if(defined($row)){		
		my %mother;
		
		$mother{'Name'} = $row->{'mother_name'};
		$mother{'PersonID'} = $row->{'person_id'};
		$mother{'Offending'} = $row->{'offending'};
		$mother{'in_custody_ind'} = $row->{'in_custody_ind'};
		$mother{'in_custody_where'} = $row->{'in_custody_where'};
		$mother{'no_contact_ind'} = $row->{'no_contact_ind'};
		
		my $noContactWhoQuery = qq{
			SELECT no_contact_with_person_id
			FROM case_management.juv_no_contact_parties
			WHERE case_id = ?
			AND person_id = ?
		};
					
		my @people;
		my @ncRes;
		getData(\@ncRes, $noContactWhoQuery, $idbh, {valref => [$caseid, $row->{'person_id'}]});
					
		if(scalar(@ncRes)){
			foreach my $nc (@ncRes) {
				push(@people, $nc->{'no_contact_with_person_id'});
			}
		}
					
		$mother{'no_contact_who'} = \@people;
		
		my $siQuery = qq{
			SELECT identifier_desc
			FROM case_management.juv_identifiers
			WHERE case_id = ?
			AND person_id = ?
		};
					
		my @siRes;
		my @specialIdentifiers;
		getData(\@siRes, $siQuery, $idbh, {valref => [$caseid, $row->{'person_id'}]});
		if(scalar(@siRes)){
			foreach my $si (@siRes) {
				push(@specialIdentifiers, $si->{'identifier_desc'});
			}
		}
					
		$mother{'special_identifiers'} = join(', ', @specialIdentifiers);
		
		my $no_contact_entered;
		if(defined($row->{'no_contact_entered'}) && ($row->{'no_contact_entered'} != "0000-00-00")){
			$no_contact_entered = $row->{'no_contact_entered'};
		}
		else{
			$no_contact_entered = "";
		}
		$mother{'no_contact_entered'} = $no_contact_entered;
				
		my $no_contact_vacated;
		if(defined($row->{'no_contact_vacated'}) && ($row->{'no_contact_vacated'} != "0000-00-00")){
			$no_contact_vacated = $row->{'no_contact_vacated'};
		}
		else{
			$no_contact_vacated = "";
		}
		$mother{'no_contact_vacated'} = $no_contact_vacated;
		
		$mother{'recom'} = $row->{'recom'};
		
		my $shelter_dos;
		if(defined($row->{'shelter_dos'}) && ($row->{'shelter_dos'} != "0000-00-00")){
			$shelter_dos = $row->{'shelter_dos'};
		}
		else{
			$shelter_dos = "";
		}
		$mother{'shelter_dos'} = $shelter_dos;
		
		my $arraignment_dos;
		if(defined($row->{'arraignment_dos'}) && ($row->{'arraignment_dos'} != "0000-00-00")){
			$arraignment_dos = $row->{'arraignment_dos'};
		}
		else{
			$arraignment_dos = "";
		}
		
		$mother{'arraignment_dos'} = $arraignment_dos;
		
		my $dependency_dos;
		if(defined($row->{'dependency_dos'}) && ($row->{'dependency_dos'} != "0000-00-00")){
			$dependency_dos = $row->{'dependency_dos'};
		}
		else{
			$dependency_dos = "";
		}
		$mother{'dependency_dos'} = $dependency_dos;
		
		my $supp_findings_dos;
		if(defined($row->{'supp_findings_dos'}) && ($row->{'supp_findings_dos'} != "0000-00-00")){
			$supp_findings_dos = $row->{'supp_findings_dos'};
		}
		else{
			$supp_findings_dos = "";
		}
		$mother{'supp_findings_dos'} = $supp_findings_dos;
		
		my $tpr_dos;		
		if(defined($row->{'tpr_dos'}) && ($row->{'tpr_dos'} != "0000-00-00")){
			$tpr_dos = $row->{'tpr_dos'};
		}
		else{
			$tpr_dos = "";
		}
				
		$mother{'tpr_dos'} = $tpr_dos;
		
		my $shelter_order_filed;
		if(defined($row->{'shelter_order_filed'}) && ($row->{'shelter_order_filed'} != "0000-00-00")){
			$shelter_order_filed = $row->{'shelter_order_filed'};
		}
		else{
			$shelter_order_filed = "";
		}
		$mother{'shelter_order_filed'} = $shelter_order_filed;
		
		my $arraignment_order_filed;
		if(defined($row->{'arraignment_order_filed'}) && ($row->{'arraignment_order_filed'} != "0000-00-00")){
			$arraignment_order_filed = $row->{'arraignment_order_filed'};
		}
		else{
			$arraignment_order_filed = "";
		}
		
		$mother{'arraignment_order_filed'} = $arraignment_order_filed;
		
		my $dependency_order_filed;
		if(defined($row->{'dependency_order_filed'}) && ($row->{'dependency_order_filed'} != "0000-00-00")){
			$dependency_order_filed = $row->{'dependency_order_filed'};
		}
		else{
			$dependency_order_filed = "";
		}
		$mother{'dependency_order_filed'} = $dependency_order_filed;
		
		my $supp_findings_order_filed;
		if(defined($row->{'supp_findings_order_filed'}) && ($row->{'supp_findings_order_filed'} != "0000-00-00")){
			$supp_findings_order_filed = $row->{'supp_findings_order_filed'};
		}
		else{
			$supp_findings_order_filed = "";
		}
		$mother{'supp_findings_order_filed'} = $supp_findings_order_filed;
		
		my $tpr_order_filed;		
		if(defined($row->{'tpr_order_filed'}) && ($row->{'tpr_order_filed'} != "0000-00-00")){
			$tpr_order_filed = $row->{'tpr_order_filed'};
		}
		else{
			$tpr_order_filed = "";
		}
				
		$mother{'tpr_order_filed'} = $tpr_order_filed;
		
		push(@mother, \%mother);
	}
	
	@children = sort { $a->{'age'} <=> $b->{'age'} } @children;
	
	foreach my $c (@children){
	
		my $pastQuery = qq{
				SELECT juv_child_placement_id,
				child_where,
				child_with,
				child_address,
				DATE_FORMAT(date_placed, '%m/%d/%Y') AS date_placed,
				CASE 
					WHEN home_study_ind = 1
					THEN 'Yes'
					WHEN home_study_ind = 0
						THEN 'No'
					ELSE NULL
				END AS home_study_ind,
				DATE_FORMAT(home_study_approved_date, '%m/%d/%Y') AS home_study_approved_date,
				DATE_FORMAT(home_study_filed_date, '%m/%d/%Y') AS home_study_filed_date
				FROM case_management.juv_child_placement
				WHERE case_id = ?
				AND person_id = ?
				ORDER BY created_time
			};
			
		my %plRes;
		getData(\%plRes, $pastQuery, $idbh, {hashkey => "juv_child_placement_id", valref => [$caseid, $c->{'PersonID'}]});

		my @childPlacements;
		if(keys %plRes){
			foreach my $pl (keys %plRes) {
				my %placement;
				$placement{'ChildWhere'} = $plRes{$pl}[0]->{'child_where'};
				$placement{'ChildWith'} = $plRes{$pl}[0]->{'child_with'};
				$placement{'ChildAddress'} = $plRes{$pl}[0]->{'child_address'};
				
				my $date_placed;
				if(defined($plRes{$pl}[0]->{'date_placed'}) && ($plRes{$pl}[0]->{'date_placed'} != "0000-00-00")){
					$date_placed = $plRes{$pl}[0]->{'date_placed'};
				}
				else{
					$date_placed = "";
				}
				$placement{'date_placed'} = $plRes{$pl}[0]->{'date_placed'};
				
				$placement{'home_study_ind'} = $plRes{$pl}[0]->{'home_study_ind'};
					
				my $home_study_approved_date;
				if(defined($plRes{$pl}[0]->{'home_study_approved_date'}) && ($plRes{$pl}[0]->{'home_study_approved_date'} != "0000-00-00")){
					$home_study_approved_date = $plRes{$pl}[0]->{'home_study_approved_date'};
				}
				else{
					$home_study_approved_date = "";
				}
				$placement{'home_study_approved_date'} = $home_study_approved_date;
				
				my $home_study_filed_date;
				if(defined($plRes{$pl}[0]->{'home_study_filed_date'}) && ($plRes{$pl}[0]->{'home_study_filed_date'} != "0000-00-00")){
					$home_study_filed_date = $plRes{$pl}[0]->{'home_study_filed_date'};
				}
				else{
					$home_study_filed_date = "";
				}
				
				$placement{'home_study_filed_date'} = $home_study_filed_date;
				push(@childPlacements, \%placement);
			}
		}
		
		$c->{'RelatedCases'} = [];
		my $query = qq{
			SELECT related_to_case_id as case_id
			FROM case_management.juv_related_cases
			WHERE person_id = ?
			AND original_case_id = ?
		};
		
		my @rcRes;
		getData(\@rcRes, $query, $idbh, {valref => [$c->{'PersonID'}, $caseid]});
		
		if(scalar(@rcRes)){
			my @lCases;
			foreach my $c (@rcRes){
				if (!grep {$_ eq "'$c->{'case_id'}'"} @lCases){
					push(@lCases, "'$c->{'case_id'}'");
				}
			}
	
			my $caseStr = "CaseID IN (" . join(",", @lCases) . ") ";
			
			if(scalar(@lCases)){
				my $caseStr = "CaseID IN (" . join(",", @lCases) . ") ";
				
				my $moreInfoQuery = qq {
					SELECT c.CaseNumber AS ToCaseNumber,
						c.CaseType,
						c.CaseStatus,
						CONVERT(varchar, c.FileDate, 101) as FileDate,
						c.CaseStyle,
						DivisionID,
						CaseID
					FROM $schema.vCase c with(nolock)
					WHERE
						$caseStr
				};
				
				my @relCases;
				getData(\@relCases, $moreInfoQuery, $dbh);
				
				foreach my $rc (@relCases){
					my $checkWarrantsQuery = qq{
						SELECT COUNT(*) as WarrCount
						FROM $schema.vWarrant
						WHERE CaseID = ?
						AND Closed = 'N'
					};
					
					my $warRow = getDataOne($checkWarrantsQuery, $dbh, [$rc->{'CaseID'}]);
					if($warRow->{'WarrCount'} > 0){
						$rc->{'HasWarrant'} = "Yes";
					}
					else{
						$rc->{'HasWarrant'} = "No";
					}
				}
				
				$c->{'RelatedCases'} = \@relCases;
			}
			
		}
		
		$c->{'ChildPlacements'} = \@childPlacements;
	}
	
	foreach my $f (@fathers){
		
		if(scalar($f->{'no_contact_who'})){
			foreach my $nc (@{$f->{'no_contact_who'}}){
				if($nc eq "999"){
					$nc = "Non-Party";
				}
				
				foreach my $p (@people){
					if($p->{'PersonID'} eq $nc){
						$nc = $p->{'FullName'} . " (" . $p->{'PartyType'} . ")";
					}
				}
			}
		}
	
		$f->{'RelatedCases'} = [];
		my $query = qq{
			SELECT related_to_case_id as case_id
			FROM case_management.juv_related_cases
			WHERE person_id = ?
			AND original_case_id = ?
		};
		
		my @rcRes;
		getData(\@rcRes, $query, $idbh, {valref => [$f->{'PersonID'}, $caseid]});
		
		if(scalar(@rcRes)){
			my @lCases;
			foreach my $c (@rcRes){
				push(@lCases, "'$c->{'case_id'}'");
			}
	
			my $caseStr = "CaseID IN (" . join(",", @lCases) . ") ";
			
			if(scalar(@lCases)){
				my $caseStr = "CaseID IN (" . join(",", @lCases) . ") ";
				
				my $moreInfoQuery = qq {
					SELECT c.CaseNumber AS ToCaseNumber,
						c.CaseType,
						c.CaseStatus,
						CONVERT(varchar, c.FileDate, 101) as FileDate,
						c.CaseStyle,
						DivisionID,
						CaseID
					FROM $schema.vCase c with(nolock)
					WHERE
						$caseStr
				};
				
				my @relCases;
				getData(\@relCases, $moreInfoQuery, $dbh);
				
				foreach my $rc (@relCases){
					my $checkWarrantsQuery = qq{
						SELECT COUNT(*) as WarrCount
						FROM $schema.vWarrant
						WHERE CaseID = ?
						AND Closed = 'N'
					};
					
					my $warRow = getDataOne($checkWarrantsQuery, $dbh, [$rc->{'CaseID'}]);
					if($warRow->{'WarrCount'} > 0){
						$rc->{'HasWarrant'} = "Yes";
					}
					else{
						$rc->{'HasWarrant'} = "No";
					}
				}
				
				$f->{'RelatedCases'} = \@relCases;
			}
			
		}
	}
	
	foreach my $m (@mother){

		if(scalar($m->{'no_contact_who'})){
			foreach my $nc (@{$m->{'no_contact_who'}}){
				if($nc eq "999"){
					$nc = "Non-Party";
				}
				
				foreach my $p (@people){
					if($p->{'PersonID'} eq $nc){
						$nc = $p->{'FullName'} . " (" . $p->{'PartyType'} . ")";
					}
				}
			}
		}
	
		$m->{'RelatedCases'} = [];
		my $query = qq{
			SELECT related_to_case_id as case_id
			FROM case_management.juv_related_cases
			WHERE person_id = ?
			AND original_case_id = ?
		};
		
		my @rcRes;
		getData(\@rcRes, $query, $idbh, {valref => [$m->{'PersonID'}, $caseid]});
		
		if(scalar(@rcRes)){
			my @lCases;
			foreach my $c (@rcRes){
				push(@lCases, "'$c->{'case_id'}'");
			}
	
			my $caseStr = "CaseID IN (" . join(",", @lCases) . ") ";
			
			if(scalar(@lCases)){
				my $caseStr = "CaseID IN (" . join(",", @lCases) . ") ";
				
				my $moreInfoQuery = qq {
					SELECT c.CaseNumber AS ToCaseNumber,
						c.CaseType,
						c.CaseStatus,
						CONVERT(varchar, c.FileDate, 101) as FileDate,
						c.CaseStyle,
						DivisionID,
						CaseID
					FROM $schema.vCase c with(nolock)
					WHERE
						$caseStr
				};
				
				my @relCases;
				getData(\@relCases, $moreInfoQuery, $dbh);
				
				foreach my $rc (@relCases){
					my $checkWarrantsQuery = qq{
						SELECT COUNT(*) as WarrCount
						FROM $schema.vWarrant
						WHERE CaseID = ?
						AND Closed = 'N'
					};
					
					my $warRow = getDataOne($checkWarrantsQuery, $dbh, [$rc->{'CaseID'}]);
					if($warRow->{'WarrCount'} > 0){
						$rc->{'HasWarrant'} = "Yes";
					}
					else{
						$rc->{'HasWarrant'} = "No";
					}
				}
				
				$m->{'RelatedCases'} = \@relCases;
			}
			
		}
	}
	
	foreach my $p (@people){
	
		foreach my $cp (@case_plans){
			if(scalar($cp->{'RelatedCasePlans'})){
				foreach my $rc (@{$cp->{'RelatedCasePlans'}}){
				
					if($rc eq "999"){
						$rc = "N/A";
					}
					
					if($rc eq $p->{'PersonID'}){
						$rc = $p->{'FullName'} . " (" . $p->{'PartyType'} . ")";
					}
				}
			}
		}
			
		foreach my $o (@orders){
			if(scalar($o->{'order_for'})){
				foreach my $of (@{$o->{'order_for'}}){
					if($of eq $p->{'PersonID'}){
						$of = $p->{'FullName'} . " (" . $p->{'PartyType'} . ")";
					}
				}
			}
		}	
	}
	
	# Check to see if we have alerts on people we have no saved info about
	my $personFound;
	foreach my $p (@people){
		$personFound = 0;
		foreach my $c (@children){
			if($p->{'PersonID'} eq $c->{'PersonID'}){
				$personFound = 1;
			}
		}
		foreach my $f (@fathers){
			if($p->{'PersonID'} eq $f->{'PersonID'}){
				$personFound = 1;
			}
		}
		foreach my $m (@mother){
			if($p->{'PersonID'} eq $m->{'PersonID'}){
				$personFound = 1;
			}
		}
		
		if($personFound == 0){
			if($p->{'PartyType'} eq "FATHER"){
				my %f;
				$f{'Name'} = $p->{'FullName'};
				$f{'PersonID'} = $p->{'PersonID'};
				$f{'Offending'} = "";
				$f{'in_custody_ind'} = "";
				$f{'in_custody_where'} = "";
				$f{'no_contact_ind'} = "";
				$f{'no_contact_who'} = "";
					
				my $siQuery = qq{
					SELECT identifier_desc
					FROM case_management.juv_identifiers
					WHERE case_id = ?
					AND person_id = ?
				};
					
				my @siRes;
				my @specialIdentifiers;
				getData(\@siRes, $siQuery, $idbh, {valref => [$caseid, $p->{'PersonID'}]});
				if(scalar(@siRes)){
					foreach my $si (@siRes) {
						push(@specialIdentifiers, $si->{'identifier_desc'});
					}
				}
					
				$f{'special_identifiers'} = join(', ', @specialIdentifiers);
				$f{'no_contact_entered'} = "";
				$f{'no_contact_vacated'} = "";
				$f{'recom'} = "";
				$f{'shelter_dos'} = "";
				$f{'arraignment_dos'} = "";
				$f{'dependency_dos'} = "";
				$f{'supp_findings_dos'} = "";
				$f{'tpr_dos'} = "";
				$f{'shelter_order_filed'} = "";
				$f{'arraignment_order_filed'} = "";
				$f{'dependency_order_filed'} = "";
				$f{'supp_findings_order_filed'} = "";
				$f{'tpr_order_filed'} = "";
				
				$f{'RelatedCases'} = [];
				my $query = qq{
					SELECT related_to_case_id as case_id
					FROM case_management.juv_related_cases
					WHERE person_id = ?
					AND original_case_id = ?
				};
				
				my @rcRes;
				getData(\@rcRes, $query, $idbh, {valref => [$p->{'PersonID'}, $caseid]});
				
				my @relCases;
				if(scalar(@rcRes)){
					my @lCases;
					foreach my $c (@rcRes){
						if (!grep {$_ eq "'$c->{'case_id'}'"} @lCases){
							push(@lCases, "'$c->{'case_id'}'");
						}
					}
			
					my $caseStr = "CaseID IN (" . join(",", @lCases) . ") ";
					
					if(scalar(@lCases)){
						my $caseStr = "CaseID IN (" . join(",", @lCases) . ") ";
						
						my $moreInfoQuery = qq {
							SELECT c.CaseNumber AS ToCaseNumber,
								c.CaseType,
								c.CaseStatus,
								CONVERT(varchar, c.FileDate, 101) as FileDate,
								c.CaseStyle,
								DivisionID,
								CaseID
							FROM $schema.vCase c with(nolock)
							WHERE
								$caseStr
						};
						
						getData(\@relCases, $moreInfoQuery, $dbh);
						
						foreach my $rc (@relCases){
							my $checkWarrantsQuery = qq{
								SELECT COUNT(*) as WarrCount
								FROM $schema.vWarrant
								WHERE CaseID = ?
								AND Closed = 'N'
							};
							
							my $warRow = getDataOne($checkWarrantsQuery, $dbh, [$rc->{'CaseID'}]);
							if($warRow->{'WarrCount'} > 0){
								$rc->{'HasWarrant'} = "Yes";
							}
							else{
								$rc->{'HasWarrant'} = "No";
							}
						}
						
						$f{'RelatedCases'} = \@relCases;
					}
					
				}
				
				push(@fathers, \%f);
			}
			elsif($p->{'PartyType'} eq "CHILD"){
				my %child;
				my $siQuery = qq{
					SELECT identifier_desc
					FROM case_management.juv_identifiers
					WHERE case_id = ?
					AND person_id = ?
				};
					
				my @siRes;
				my @specialIdentifiers;
				getData(\@siRes, $siQuery, $idbh, {valref => [$caseid, $p->{'PersonID'}]});
				if(scalar(@siRes)){
					foreach my $si (@siRes) {
						push(@specialIdentifiers, $si->{'identifier_desc'});
					}
				}

				$child{'psych_meds'} = "";
				$child{'special_identifiers'} = join(', ', @specialIdentifiers);
				$child{'Name'} = $p->{'FullName'};
				$child{'DOB'} = $p->{'DOB'};
				$child{'age'} = "";
				$child{'Age'} = getageinyears($p->{'DOB'});
				#$child{'Sex'} = "";
				$child{'PersonID'} = $p->{'PersonID'};
				$child{'FatherPersonID'} = "";
				$child{'FatherName'} = "";
				$child{'father_type'} = "";
				$child{'ChildWhere'} = "";
				$child{'ChildWith'} = "";
				$child{'ChildAddress'} = "";
				$child{'date_placed'} =  "";
				$child{'home_study_ind'} = "";	
				$child{'home_study_approved_date'} = "";
				$child{'home_study_filed_date'} = "";		
				$child{'TICO'} = "";
				$child{'notes'} = "";
					
				my @relCases;
				$child{'RelatedCases'} = [];
				my $query = qq{
					SELECT related_to_case_id as case_id
					FROM case_management.juv_related_cases
					WHERE person_id = ?
					AND original_case_id = ?
				};
				
				my @rcRes;
				getData(\@rcRes, $query, $idbh, {valref => [$p->{'PersonID'}, $caseid]});
				
				if(scalar(@rcRes)){
					my @lCases;
					foreach my $c (@rcRes){
						if (!grep {$_ eq "'$c->{'case_id'}'"} @lCases){
							push(@lCases, "'$c->{'case_id'}'");
						}
					}
			
					my $caseStr = "CaseID IN (" . join(",", @lCases) . ") ";
					
					if(scalar(@lCases)){
						my $caseStr = "CaseID IN (" . join(",", @lCases) . ") ";
						
						my $moreInfoQuery = qq {
							SELECT c.CaseNumber AS ToCaseNumber,
								c.CaseType,
								c.CaseStatus,
								CONVERT(varchar, c.FileDate, 101) as FileDate,
								c.CaseStyle,
								DivisionID,
								CaseID
							FROM $schema.vCase c with(nolock)
							WHERE
								$caseStr
						};
						
						getData(\@relCases, $moreInfoQuery, $dbh);
						
						foreach my $rc (@relCases){
							my $checkWarrantsQuery = qq{
								SELECT COUNT(*) as WarrCount
								FROM $schema.vWarrant
								WHERE CaseID = ?
								AND Closed = 'N'
							};
							
							my $warRow = getDataOne($checkWarrantsQuery, $dbh, [$rc->{'CaseID'}]);
							if($warRow->{'WarrCount'} > 0){
								$rc->{'HasWarrant'} = "Yes";
							}
							else{
								$rc->{'HasWarrant'} = "No";
							}
						}
						
						$child{'RelatedCases'} = \@relCases;
					}
					
				}
				
				push(@children, \%child);
				
			}
			elsif($p->{'PartyType'} eq "MOTHER"){
				my %m;
				$m{'Name'} = $p->{'FullName'};
				$m{'PersonID'} = $p->{'PersonID'};
				$m{'Offending'} = "";
				$m{'in_custody_ind'} = "";
				$m{'in_custody_where'} = "";
				$m{'no_contact_ind'} = "";
				$m{'no_contact_who'} = "";
					
				my $siQuery = qq{
					SELECT identifier_desc
					FROM case_management.juv_identifiers
					WHERE case_id = ?
					AND person_id = ?
				};
					
				my @siRes;
				my @specialIdentifiers;
				getData(\@siRes, $siQuery, $idbh, {valref => [$caseid, $p->{'PersonID'}]});
				if(scalar(@siRes)){
					foreach my $si (@siRes) {
						push(@specialIdentifiers, $si->{'identifier_desc'});
					}
				}
					
				$m{'special_identifiers'} = join(', ', @specialIdentifiers);
				$m{'no_contact_entered'} = "";
				$m{'no_contact_vacated'} = "";
				$m{'recom'} = "";
				$m{'shelter_dos'} = "";
				$m{'arraignment_dos'} = "";
				$m{'dependency_dos'} = "";
				$m{'supp_findings_dos'} = "";
				$m{'tpr_dos'} = "";
				$m{'shelter_order_filed'} = "";
				$m{'arraignment_order_filed'} = "";
				$m{'dependency_order_filed'} = "";
				$m{'supp_findings_order_filed'} = "";
				$m{'tpr_order_filed'} = "";
				
				my @relCases;
				$m{'RelatedCases'} = [];
				my $query = qq{
					SELECT related_to_case_id as case_id
					FROM case_management.juv_related_cases
					WHERE person_id = ?
					AND original_case_id = ?
				};
				
				my @rcRes;
				getData(\@rcRes, $query, $idbh, {valref => [$p->{'PersonID'}, $caseid]});
				
				if(scalar(@rcRes)){
					my @lCases;
					foreach my $c (@rcRes){
						if (!grep {$_ eq "'$c->{'case_id'}'"} @lCases){
							push(@lCases, "'$c->{'case_id'}'");
						}
					}
			
					my $caseStr = "CaseID IN (" . join(",", @lCases) . ") ";
					
					if(scalar(@lCases)){
						my $caseStr = "CaseID IN (" . join(",", @lCases) . ") ";
						
						my $moreInfoQuery = qq {
							SELECT c.CaseNumber AS ToCaseNumber,
								c.CaseType,
								c.CaseStatus,
								CONVERT(varchar, c.FileDate, 101) as FileDate,
								c.CaseStyle,
								DivisionID,
								CaseID
							FROM $schema.vCase c with(nolock)
							WHERE
								$caseStr
						};
						
						getData(\@relCases, $moreInfoQuery, $dbh);
						
						foreach my $rc (@relCases){
							my $checkWarrantsQuery = qq{
								SELECT COUNT(*) as WarrCount
								FROM $schema.vWarrant
								WHERE CaseID = ?
								AND Closed = 'N'
							};
							
							my $warRow = getDataOne($checkWarrantsQuery, $dbh, [$rc->{'CaseID'}]);
							if($warRow->{'WarrCount'} > 0){
								$rc->{'HasWarrant'} = "Yes";
							}
							else{
								$rc->{'HasWarrant'} = "No";
							}
						}
						
						$m{'RelatedCases'} = \@relCases;
					}
					
				}
				
				push(@mother, \%m);
			}
		}
	}
	
	$juvRef->{'attorneys'} = \@attorneys;
	$juvRef->{'cls_attorney_name'} = $cls_attorney_name;
	$juvRef->{'gal_name'} = $gal_name;
	$juvRef->{'gal_attorney_name'} = $gal_attorney_name;
	$juvRef->{'dcm_name'} = $dcm_name;
	$juvRef->{'orders'} = \@orders;
	$juvRef->{'children'} = \@children;
	$juvRef->{'mother'} = \@mother;
	$juvRef->{'fathers'} = \@fathers;
	$juvRef->{'case_plans'} = \@case_plans;
	$juvRef->{'notes'} = \@notes;
	
}

1;