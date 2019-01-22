package EService;

BEGIN {
	use lib "$ENV{'PERL5LIB'}";
};

use strict;
use warnings;

use CGI::Carp qw(fatalsToBrowser);
use XML::Simple;
use JSON;

use Mail::RFC822::Address qw(valid validlist);

use DB_Functions qw(
	dbConnect
	getData
	getDataOne
    eFileInfo
    getCaseInfo
    getDivInfo
    getDbSchema
);

use Common qw(
	dumpVar
	inArray
    encodeFile
    getFileType
    $templateDir
    doTemplate
    makePaths
    %courtTypes
    %portalTypes
    returnJson
	getShowcaseDb
);

use Showcase qw (
    $db
);
use Data::Dumper;
use File::Temp qw (tempfile);

use MIME::Base64;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
	getAttorneyAddresses
	getProSeAddresses
	getAllAddresses
    getPortalAddresses
    createFilingXml
    getRefileDocs
    getAgencyAddresses
);

our @EXCLUDETYPES = (7,8,10,11,12,14,15,16,18,20,21,22);
our $db = getShowcaseDb();

sub getPortalAddresses {
    my $ucn = shift;
    my $portalAddresses = shift;
    
    return if (!defined($ucn));
        
    my $portalXml = `/usr/bin/php $ENV{'APP_ROOT'}/icms/bin/portal/getServiceList.php -x -u $ucn`;
    
    my $ref = XMLin(
                    $portalXml,
                    ForceArray => ['esd:Filers','esd:OtherServiceRecipients']
                    );

    my $esc = $ref->{'s:Body'}->{'GetElectronicServiceListCaseResponse'}->{'GetElectronicServiceListCaseResult'}->
        {'esm:ElectronicServiceListCase'}->{'esd:Filers'};
        
    my @emails;
         
    if (defined($esc)) {
        foreach my $filer (@{$esc}) {
            next if (($filer->{'esd:Active'} eq "false") ||
                     (inArray(\@EXCLUDETYPES, $filer->{'esd:UserTypeCode'})));
            
            foreach my $atype ('PrimaryEmailAddress','AlternateEmailAddress1','AlternateEmailAddress2') {
                my $esd = "esd:$atype";
                next if (inArray(\@emails, lc($filer->{$esd})));
                if ((defined($filer->{$esd})) && (ref($filer->{$esd}) ne "HASH")) {
                	my @filer_emails = split /;/, $filer->{$esd};
					foreach my $e (@filer_emails){
	                    my %addr = (
	                                'fullname' => $filer->{'esd:Name'},
	                                'bar_number' => $filer->{'esd:BarNumber'},
	                                'email_addr' => $e
	                                );
	                    push(@{$portalAddresses}, \%addr);
	                    push(@emails, lc($e));
                    }
                }
            }

            # Are there unaffiliated addresses associated with this user?
            my $others = $filer->{'esd:OtherServiceRecipients'};
            if (defined($others)) {
                foreach my $other (@{$others}) {
                    next if ($other->{'esd:RemovalRequested'} eq "true");
                    
                    foreach my $atype ('PrimaryEmailAddress','AlternateEmailAddress1','AlternateEmailAddress2') {
                        my $esd = "esd:$atype";
                        next if (inArray(\@emails, lc($other->{$esd})));
                        if ((defined($other->{$esd})) && (ref($other->{$esd}) ne "HASH")) {
                            my @oth_filer_emails = split /;/, $other->{$esd};
							foreach my $o (@oth_filer_emails){
		                    	my %addr = (
		                        	'fullname' => $other->{'esd:Name'},
		                            'email_addr' => $o
		                        );
		                        push(@{$portalAddresses}, \%addr);
		                        push(@emails, lc($o));
		                    }
                        }
                    }
                }
            }
        }
    }
    
    @{$portalAddresses} = sort {lc($a->{'email_addr'}) cmp lc($b->{'email_addr'})} @{$portalAddresses};

    return;
}


sub getAllAddresses {
	my $casenum = shift;
	my $addressRef = shift;
	my $dbh = shift;
	my $caseid = shift;
    
	getProSeAddresses($casenum,$addressRef,$dbh,undef,$caseid);
	getAttorneyAddresses($casenum,$addressRef,$dbh,undef,undef,$caseid);

	my $qcasenum = $dbh->quote($casenum);

	foreach my $address(@{$addressRef}) {
		my $fullname;
		if (!defined($address->{'first_name'})) {
			$address->{'first_name'} = "";
		}
		if (!defined($address->{'middle_name'})) {
			$address->{'middle_name'} = "";
		}
		if (!defined($address->{'last_name'})) {
			$address->{'last_name'} = "";
		}
		if (!defined($address->{'suffix'})) {
			$address->{'suffix'} = "";
		}
		# Build a full name string
		if ($address->{'middle_name'} eq "") {
			$fullname = sprintf ("%s %s", $address->{'first_name'}, $address->{'last_name'});
		} else {
			$fullname = sprintf ("%s %s %s", $address->{'first_name'}, $address->{'middle_name'},
								 $address->{'last_name'});
		}

		if ($address->{'suffix'} ne "") {
			$fullname .= ", $address->{'suffix'}";
		}
		$address->{'fullname'} = $fullname;
	}
    
    @{$addressRef} = sort {lc($a->{'fullname'}) cmp lc($b->{'fullname'})} @{$addressRef};
}


sub getProSeAddresses {
	my $casenum = shift;
	my $addressRef = shift;
	my $dbh = shift;
	my $partyid = shift;
	my $caseid = shift;
	my $bToSC;

	if ((!defined($casenum)) || ($casenum eq "")) {
		return;
	}
	
	if($casenum =~ /(\d\d)-(\d\d\d\d)-(\D\D)-(\d\d\d\d\d\d)-(\D\D\D\D)-(\D\D)/){
		$bToSC = sprintf("%04d%s%06d", $2, $3, $4);
	}

	my @vals = ($casenum, $bToSC);

	my $query = qq {
		select
			u.first_name,
			u.middle_name,
			u.last_name,
			u.suffix,
			u.pref_name,
			e.email_addr,
			e.email_addr_id,
			'' as bar_num,
			0 as FromShowcase
		from
			case_emails ce,
			email_addresses e,
			users u
		where
			( ce.casenum = ?
			OR ce.casenum = ? )
			and ce.email_addr_id = u.login_id
			and u.login_id = e.email_addr_id
			and u.user_type = 3
	};
	
	my $sc_dbh = dbConnect(getShowcaseDb());
	my $schema = getDbSchema(getShowcaseDb());

	if (defined($partyid)) {
		my $scQuery;
		$scQuery = qq{
			SELECT 
				FirstName,
				LastName
			FROM 
				$schema.vAllParties
			WHERE 
				PersonID = ?
		};
			
		my $scRow;
		$scRow = getDataOne($scQuery, $sc_dbh, [$partyid]);
			
		if(scalar($scRow->{'LastName'})){
			$query .= qq{
				AND u.first_name = ?
				AND u.last_name = ?
			};
				
			push(@vals, $scRow->{'FirstName'});
			push(@vals, $scRow->{'LastName'});
		}
	}
	
	getData($addressRef,$query,$dbh, {valref => \@vals});
	
	my $eCount = 0;
	my $emails = "";
	if(scalar(@{$addressRef}) > 0){
		foreach my $e_email (@{$addressRef}) {
			if($eCount > 1){
				$emails .= ", ";
			}
			$emails .= "'" . $e_email->{'email_addr'} . "'";
			$eCount++;
		}
	}
	
	my @vals2;
	push(@vals2, $caseid);
	
	$query = qq {
		SELECT FirstName as first_name,
			MiddleName as middle_name,
			LastName as last_name,
			NameSuffixCode as suffix,
			Name as pref_name,
			eMailAddress AS email_addr,
			NULL email_addr_id,
			PersonID as bar_num,
			1 as FromShowcase
		FROM 
			$schema.vAllParties
		WHERE 
			CaseID = ?
		AND 
			EmailAddress IS NOT NULL AND EmailAddress <> ''
	};
	
	if($emails){
		$query .= qq{ AND EmailAddress NOT IN ( $emails ) };
	}
	
	if (defined($partyid)) {
		push(@vals2, $partyid);
		$query .= qq {
			and PersonID = ?
		};
	}
	
	getData($addressRef, $query, $sc_dbh, {valref => \@vals2});
}


sub getAttorneyAddresses {
	my $casenum = shift;
	my $addressRef = shift;
	my $dbh = shift;
	my $bar_in = shift;
	my $isEservice = shift;
	my $bToSC;
	my $caseid = shift;

	if ((!defined($casenum)) || ($casenum eq "")) {
		return;
	}
	
	if($casenum =~ /(\d\d)-(\d\d\d\d)-(\D\D)-(\d\d\d\d\d\d)-(\D\D\D\D)-(\D\D)/){
		$bToSC = sprintf("%04d%s%06d", $2, $3, $4);
	}

	my @emailIds;

	# First, get a list of attorney parties on the case

	my @attyParties;
	if (defined($bar_in)) {
		# We got it as a parameter.  Build the structure.
		my %barhash = (
			"bar_num" => $bar_in
		);
		push(@attyParties, \%barhash)
	} else {
		my $query = qq {
			select
				distinct(bar_num)
			from
				case_parties
			where
				( casenum = ?
				OR casenum = ? )
				and partytype = 'ATTY'
		};

		getData(\@attyParties,$query,$dbh,{valref => [$casenum, $bToSC]});
	}
	
	my $sc_dbh = dbConnect(getShowcaseDb());
	my $schema = getDbSchema(getShowcaseDb());

	if(!scalar(@attyParties)) {
		# No parties listed - this is probably a closed case.  Get the attorney parties from Banner

		# Keep the returned values in the same array, so the code still works.
		my $query = qq {
			SELECT 
				BarNumber as "bar_num"
			FROM 
				$schema.vAllParties
			WHERE 
				CaseID = ?
			AND 
				PartyType IN ('ATTY', 'PD', 'APD', 'PPD', 'SA', 'ASA')
			AND 
				Active = 'Yes'
		};
		getData(\@attyParties,$query,$sc_dbh, { valref => [$caseid]});
		$sc_dbh->disconnect();
	}

	foreach my $party (@attyParties) {
		next if (!defined($party->{'bar_num'}));
		my @caseEmails = ();
		my $found = 0;
		my $bar_num = $party->{'bar_num'};
		my $query = qq {
			select
				email_addr,
				bar_num,
				e.email_addr_id,
				0 as FromShowcase
			from
				email_addresses e,
				case_emails c,
				users u
			where
				( casenum = ?
				OR casenum = ? )
				and c.user_id=u.user_id
				and u.bar_num = ?
				and c.email_addr_id = e.email_addr_id
		};

		getData(\@caseEmails, $query, $dbh, { valref => [$casenum, $bToSC, $bar_num] });

		if (scalar(@caseEmails)) {
			# Get name information for each person
			foreach my $row (@caseEmails) {
				if (inArray(\@emailIds, $row->{'email_addr_id'})) {
					next;
				}
				push (@emailIds, $row->{'email_addr_id'});

				$query = qq {
					select
						first_name,
						middle_name,
						last_name,
						suffix
					from
						users
					where
						login_id = $row->{'email_addr_id'}
				};
				my $name = getDataOne($query,$dbh);
				if (defined($name)) {
					$row->{'first_name'} = $name->{'first_name'};
					$row->{'middle_name'} = $name->{'middle_name'};
					$row->{'last_name'} = $name->{'last_name'};
					$row->{'suffix'} = $name->{'suffix'};
					$row->{'assoc_bar'} = $bar_num;
				}
				push(@{$addressRef}, $row);
			}
			$found = 1;
		} else {
			# Didn't find anything in caseEmails; check default_addresses
			$query = qq {
				select
					email_addr,
					bar_num,
					e.email_addr_id,
					0 as FromShowcase
				from
					email_addresses e,
					default_addresses d,
					users u
				where
					u.bar_num = ?
					and u.user_id = d.user_id
					and d.email_addr_id = e.email_addr_id
			};
			getData(\@caseEmails,$query,$dbh,{valref => [$bar_num]});

			if (scalar(@caseEmails)) {
				# Get name information for each person
				foreach my $row (@caseEmails) {
					if (inArray(\@emailIds, $row->{'email_addr_id'})) {
						next;
					}
					push (@emailIds, $row->{'email_addr_id'});

					$query = qq {
						select
							first_name,
							middle_name,
							last_name,
							suffix
						from
							users
						where
							login_id = ?
					};
					my $name = getDataOne($query,$dbh, [$row->{'email_addr_id'}]);
					if (defined($name)) {
						$row->{'first_name'} = $name->{'first_name'};
						$row->{'middle_name'} = $name->{'middle_name'};
						$row->{'last_name'} = $name->{'last_name'};
						$row->{'suffix'} = $name->{'suffix'};
						$row->{'assoc_bar'} = $bar_num;
					}
					push(@{$addressRef}, $row);
				}
				$found = 1;
			};
		}

		if (!$found) {
			# This attorney is NOT registered.
			$query = qq {
				select
					first_name,
					middle_name,
					last_name,
					suffix,
					email_addr,
					bar_num,
					u.email_addr_id,
					0 as FromShowcase
				from
					unreg_bar_members u,
					email_addresses e
				where
					bar_num = ?
					and u.email_addr_id = e.email_addr_id
			};
			my @unreg;
			getData(\@unreg,$query,$dbh, {valref => [$bar_num]});
			push(@{$addressRef}, @unreg);
		} else {
			$$isEservice = 1;
		}
	}

	foreach my $address(@{$addressRef}) {
		# Take the email address apart for people who put stupid stuff in their email field
		my @temp = split(/[;,\ ]+/, $address->{'email_addr'});
		foreach my $piece (@temp) {
			if (valid($piece)) {
				$address->{'email_addr'} = $piece;
				last;
			}
		}
	}
	
	# This is a one-off... remove Carey Haughwout's e-mail from e-service on MH cases
    if ($casenum =~ /MH/) {
    	@{$addressRef} = grep {$_->{'bar_num'} ne '375675'} @{$addressRef};
    }
    
    # Another one-off.. remove Magistrate Fanelli's e-mail address from e-service
    @{$addressRef} = grep {$_->{'bar_num'} ne '510335'} @{$addressRef};
    
    # Last check - let's remove attorneys representing disposed parties 
	foreach my $party (@attyParties) {
		my @disposedAttorneys;
		next if (!defined($party->{'bar_num'}));
		my $query = qq {
			SELECT 
			 	COUNT(Represented_PersonID) AS PartyCount,
				COALESCE(
					SUM(
						CASE 
							WHEN p.CourtAction LIKE '%Disposed%'
							THEN 1
							ELSE 0
						END
					), 
				0) AS DisposedCount
			FROM 
				$schema.vAttorney a
			INNER JOIN
				$schema.vParty p
				ON a.CaseID = p.CaseID
				AND a.Represented_PersonID = p.PersonID
			WHERE 
				a.CaseID = ?
			AND 
				a.BarNumber = ?
		};
		
		my $countRow = getDataOne($query, $sc_dbh, [$caseid, $party->{'bar_num'}]);
		$sc_dbh->disconnect();
		
		if(($countRow->{'DisposedCount'} >= $countRow->{'PartyCount'}) && ($countRow->{'DisposedCount'} > 0)){
			$party->{'bar_num'} =~ s/^0+//;
			@{$addressRef} = grep {$_->{'bar_num'} ne $party->{'bar_num'}} @{$addressRef};
		}
	}
}

sub getAgencyAddresses {
    my $casenum = shift;
    my $addressRef = shift;
	my $dbh = shift;
	my $caseid = shift;
    my $hasPD = 0;
    my $hasSA = 0;
    my $hasORCC = 0;
    if (!defined($dbh)) {
        $dbh = dbConnect("ols");
    }

    my $caseinfo = getCaseInfo($casenum,$dbh);
    my $div = $caseinfo->{'DivisionID'};
    my $case_type = $caseinfo->{'CaseType'};
    
    if (!defined($div)) {
        return;
    }
    
    my $divinfo = getDivInfo($div);
    
    my $pdbh;
    my $parties = [];
    my $query;
    $pdbh = dbConnect($db);
        my $schema = getDbSchema($db);
        $query = qq {
            select
                PartyType,
                BarNumber,
                LastName
            from
                $schema.vAllParties with(nolock)
            where
                CaseID = ?
                and Active = 'Yes'
        };
    
    getData($parties, $query, $pdbh, {valref => [$caseid]});
    
    my $includePD = 0;
    foreach my $party (@{$parties}) {
    	if($party->{'BarNumber'} eq '0375675'){
    		$includePD = 1;
    	}
    	
        if (inArray(['PD','APD','PPD'], $party->{'PartyType'})) {
            $hasPD = 1;
        } 
        
        if (inArray(['SA','ASA'], $party->{'PartyType'}) || ($caseinfo->{'CaseNumber'} !~ /DP/)) {
            $hasSA = 1;
        } 
        
        if (inArray(['ORCC'], $party->{'PartyType'}) || ($party->{'BarNumber'} eq 'ORCC' || ($party->{'LastName'} eq 'REGIONALCONFLICTCOUNSEL'))) {
            $hasORCC = 1;
        }
    }
    
    my @types;
    if ($hasPD) {
        push(@types,"'PD'");
    }
    if ($hasSA) {
        push(@types,"'SA'");
    }
    
    if (scalar(@types)) {
        my $inString = join(",", @types);
        my $query = qq {
            select
                email_addr,
                0 as from_portal,
                1 as agency
            from
                agency_div_addresses
            where
                division = ?
                and agency in ($inString)
        };
        
        getData($addressRef, $query, $dbh, {valref => [$div]});
    }
    
    #PD wants certain addresses copied on MH cases
    if ($casenum =~ /MH/ && ($includePD eq '1')) {
    	my %pdAdd;
    	$pdAdd{'email_addr'} = "mentalhealth\@pd15.org";
    	$pdAdd{'from_portal'} = 0;
    	$pdAdd{'agency'} = 1;
    	push(@{$addressRef}, \%pdAdd);
	}
	
	#I'm going to do ORCC separately...
	if($hasORCC){
		
		#Civil e-mail address for juvenile dependency, mental health, and guardianship cases
		if($caseinfo->{'CaseNumber'} =~ /DP/ || ($caseinfo->{'CaseNumber'} =~ /MH/) || ($caseinfo->{'CaseNumber'} =~ /GA/)){
			my %orccAdd;
	    	$orccAdd{'email_addr'} = "WPBCivilDocket\@rc-4.com";
	    	$orccAdd{'from_portal'} = 0;
	    	$orccAdd{'agency'} = 1;
	    	push(@{$addressRef}, \%orccAdd);
		}
		#Appellate e-mail address for appellate cases (duh)
		elsif($caseinfo->{'CaseNumber'} =~ /AP/){
			my %orccAdd;
	    	$orccAdd{'email_addr'} = "RC4AppellateFilings\@rc-4.com";
	    	$orccAdd{'from_portal'} = 0;
	    	$orccAdd{'agency'} = 1;
	    	push(@{$addressRef}, \%orccAdd);
		}
		#Criminal address for the rest (criminal and juvenile delinquency)
		else{
			my %orccAdd;
	    	$orccAdd{'email_addr'} = "WPBCriminalDocket\@rc-4.com";
	    	$orccAdd{'from_portal'} = 0;
	    	$orccAdd{'agency'} = 1;
	    	push(@{$addressRef}, \%orccAdd);
		}
	}
	
	#Baker Acts
	if($case_type eq "BA" && ($casenum =~ /MH/)){
		my %baPDAdd;
	    $baPDAdd{'email_addr'} = "E-BakerAct\@pd15.org";
	    $baPDAdd{'from_portal'} = 0;
	    $baPDAdd{'agency'} = 1;
	    push(@{$addressRef}, \%baPDAdd);
	    
	    my %baSAAdd;
	    $baSAAdd{'email_addr'} = "E-BakerAct\@sa15.org";
	    $baSAAdd{'from_portal'} = 0;
	    $baSAAdd{'agency'} = 1;
	    push(@{$addressRef}, \%baSAAdd);
	}
}

sub getPartyEserviceAddresses {
	my $party = shift;
	my $ucn = shift;
	my $dbh = shift;

	if (!defined($ucn)) {
		return;
	}

	if (!defined($dbh)) {
		$dbh = database('eservice');
	}

	my @emailArray;

	if ($party->{'PartyType'} eq 'ATTY') {
		# Ok, it's an attorney.
		# First look in the case_emails table
		my $query = qq {
			select
                email_addr
			from
                email_addresses ea,
                case_emails ce,
				users u
			where
                casenum = ?
                and u.bar_num = ?
                and u.user_id = ce.user_id
				and ce.email_addr_id = ea.email_addr_id
		};

		getData(\@emailArray, $query, $dbh, {valref => [$ucn, $party->{'spriden_id'}]});

		if (!scalar(@emailArray)) {
			# We didn't find any case-specific emails.  Check the default_addresses table
			$query = qq {
				select
                    email_addr
				from
                    email_addresses ea,
					default_addresses da,
                    users u
                where
					u.bar_num = ?
                    and u.user_id = da.user_id
					and da.email_addr_id = ea.email_addr_id
			};

			getData(\@emailArray, $query, $dbh, {valref => [$party->{'spriden_id'}]});
		}

		# Still none?  Must be an unregistered member
		if (!scalar(@emailArray)) {
			$query = qq {
				select
                    email_addr
				from
                    email_addresses ea,
					unreg_bar_members u
                where
					u.bar_num = ?
                    and u.email_addr_id = ea.email_addr_id
			};
			getData(\@emailArray, $query, $dbh, {valref => [$party->{'spriden_id'}]});
		}

	} else {
		if ($party->{'ProSe'}) {
			print "Need to look up pro se address\n\n";
			dumpVar($party);
		}

	}

	my @emails;
	foreach my $email (@emailArray) {
		push(@emails, $email->{'email_addr'});
	}

	$party->{'EmailAddresses'} = \@emails;
}


sub createFilingXml {
    my $files = shift;
    my $user = shift;
    my $casenum = shift;
    my $ucn = shift;
    my $dbh = shift;
    my $eFileInfo = shift;
    my $caseInfo = shift;
    #my $divInfo = shift;
    my $filetime = shift;
    my $docID = shift;
    
    if (!defined($dbh)) {
        $dbh = dbConnect("portal_info");
    }
    
    if (!defined($eFileInfo)) {
        $eFileInfo = eFileInfo($user,$dbh);
    }
    
    my %data;
    if (defined($filetime)) {
        $data{'filetime'} = $filetime;
    } else {
        $data{'filetime'} = `/bin/date +"%FT%H:%M:%S.%N%:z"`;
        chomp $data{'filetime'};
    }
    
    if (defined($docID)) {
        $data{'docID'} = $docID;
    }

    $data{'emergency'} = $eFileInfo->{'emergency'};
    $data{'firstname'} = $eFileInfo->{'first_name'};
    $data{'lastname'} = $eFileInfo->{'last_name'};
    $data{'logonname'} = $eFileInfo->{'portal_id'};
    $data{'password'} = $eFileInfo->{'password'};
    $data{'bar_id'} = $eFileInfo->{'bar_num'} . "FL";
    $data{'ClerkCase'} = $casenum;
    $data{'UCN'} = $ucn;
    $data{'county_id'} = 50;
    $data{'judicial_circuit'} = "Twelfth Circuit";
    $data{'county'} = "Sarasota";

    if (!defined($caseInfo)) {
        $caseInfo = getCaseInfo($casenum);
    }
    
    # Escape any ampersand in the case style
    $caseInfo->{'CaseStyle'} =~ s/&/&amp;/g;
    
    $data{'CaseStyle'} = $caseInfo->{'CaseStyle'};
    
    #if (!defined($divInfo)) {
    #    # Didn't get passed by the caller?
    #my $divInfo = getDivInfo($caseInfo->{'DivisionID'});
    #}
    
    my $query = qq {
        select
            portal_namespace,
            court_type_id
        from
            court_type_map
        where
            portal_court_type = ?
    };
    
    my $divInfo = getDataOne($query, $dbh, [$courtTypes{$caseInfo->{'CourtType'}}]);
    
    $data{'case_type'} = $divInfo->{'portal_namespace'};	
    $data{'court_id'} = $divInfo->{'court_type_id'};
    $data{'court_type'} = $courtTypes{$caseInfo->{'CourtType'}};
    
    # The resulting data structure from this next part may be more complex than is strictly necessary for
    # this, but it allows us to use the same template that we'd use for filing multiple documents.
    $data{'doc_info'} = {};

    my $imgCount = 1;
    
    #my %image;
    my $firstFile = $files->[0];
    
    $firstFile->{'encodedBase64'} = encodeFile($firstFile->{'filename'});
    $firstFile->{'docID'} = sprintf("DOC%05d", $imgCount);
    $firstFile->{'attachID'} = sprintf("ATT%05d", $imgCount);
    $firstFile->{'attachSeq'} = $imgCount;
    $firstFile->{'binary_size'} = (stat($firstFile->{'filename'}))[7];
    $firstFile->{'file_type'} = getFileType($firstFile->{'shortname'});
    
    $data{'doc_info'}{'FilingLeadDocument'} = $firstFile;
    $data{'doc_info'}{'FilingConnectedDocuments'} = [];
    
    
    # Now, do the same thing for additional files, but attach them to the FilingConnectedDocuments element.
    for (my $i=1; $i < scalar(@{$files}); $i++) {
        $imgCount++;
        my $file = $files->[$i];
        
        $file->{'encodedBase64'} = encodeFile($file->{'filename'});
        $file->{'docID'} = sprintf("DOC%05d", $imgCount);
        $file->{'attachID'} = sprintf("ATT%05d", $imgCount);
        $file->{'attachSeq'} = $imgCount;
        $file->{'binary_size'} = (stat($file->{'filename'}))[7];
        $file->{'file_type'} = getFileType($file->{'shortname'});
        
        push(@{$data{'doc_info'}{'FilingConnectedDocuments'}}, $file);
    }
    
    my $meta = doTemplate(\%data, "$templateDir/portal", "ReviewFiling.tt", 0);
    
    my ($fh, $tmpfile) = tempfile(DIR => "/tmp","SUFFIX" => "-efile.xml");
    print $fh $meta;
    close($fh);

    return $tmpfile;
}


sub getRefileDocs {
    my $filingid = shift;
    my $fileRef = shift;
    my $origDate = shift;
    my $docketCodes = shift;
    my $user = shift;
    my $dbh = shift;
    
    return if ((!defined($filingid)) || (!defined($fileRef)));
    
    if (!defined($user)) {
        $user = getUser();
    }
    
    if (!defined($dbh)) {
        $dbh = dbConnect("portal_info");
    }
    
    my $query = qq {
        select
            filing_id as FilingID,
            filing_status as FilingStatus,
            DATE_FORMAT(filing_date,'%m/%d/%Y') as FilingDate
        from
            portal_filings
        where
            filing_id = ?
            and filing_status in ('Correction Queue','Abandoned Filing Queue')
            and user_id = ?
    };
    my $filingInfo = getDataOne($query, $dbh, [$filingid, $user]);
    
    return if (!defined($filingInfo));
    
    $$origDate = $filingInfo->{'FilingDate'};
    
    # Ok, it's a valid Pending Queue filing, owned by the user. Move on. Get the data on the filings.
    $query = qq {
        select
            file_name as shortname,
            document_group as documentgroup,
            document_type as docketdesc,
            document_id as docID,
            attachment_id as attachID,
            base64_attachment as encodedBase64
        from
            pending_filings
        where
            filing_id = ?
    };
    
    my %files;
    getData(\%files, $query, $dbh, {valref => [$filingid], hashkey => 'docID', flatten => 1});
    
    if (scalar(keys %files)) {
        my $outDir = "/var/www/html/tmp/refiles/$filingid";
        my $linkDir = "/tmp/refiles/$filingid";
        # create the files from the encodedBase64
        makePaths($outDir);
        foreach my $key (sort keys %files) {
            my $file = $files{$key};
            
            my $outFile = sprintf("%s/%s", $outDir, $file->{'shortname'});
            open (OUTFILE, ">$outFile") || die "Can't create $outFile: $!\n\n";
            binmode(OUTFILE);
            print OUTFILE decode_base64($file->{'encodedBase64'});
            close OUTFILE;
            $file->{'filename'} = $outFile;
            $file->{'link'} = sprintf("%s/%s", $linkDir, $file->{'shortname'});
            $file->{'portaldesc'} = $docketCodes->{$file->{'docketdesc'}}->{'portal_desc'};
            delete($file->{'encodedBase64'});
            push(@{$fileRef}, $file);
        }
    }
}


1;
