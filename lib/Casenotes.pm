package Casenotes;
use strict;
use warnings;

use ICMS;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    buildnotes
    buildNotes
    calcExpire
    casenotes
    getFlags
    getFlagTypes
    getNotes
    mergenotesandflags
    mergeNotesAndFlags
    mergenotcurrent
    updateCaseNotes
    updateSummaries
);

use Common qw (
    dumpVar
    readHash
    today
    ISO_date
    getUser
);

use DB_Functions qw (
    dbConnect
    getData
    doQuery
    getCaseInfo
    inGroup
    getDbSchema
);

use Showcase qw (
    getCourtEvents
    $db
    getEvents
    getSCCaseNumber
    getCaseID
);

use Date::Calc qw (:all Parse_Date);

sub getFlags {
    my $casenum = shift;
    my $dbh = shift;
    my $flagref = shift;
    
    if (!defined($dbh)) {
        $dbh = dbConnect("icms") ||
            return;
    }
    
    if ($casenum =~ /(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)/) {
        # It's a banner-type casenum, without dashes.  Convert it.
        $casenum = sprintf("%04d-%s-%06d", $1, $2, $3);
    }
    
    my $query = qq {
        select
            date as "FlagDate",
            userid as "FlagUser",
            dscr as "FlagDesc",
            IFNULL(DATE_FORMAT(expires, '%m/%d/%Y'),'&nbsp;') as "Expires"
        from
            flags a,
            flagtypes b
        where
            a.flagtype=b.flagtype
            and casenum = ?
        order by
            idnum desc
    };
    
    getData($flagref,$query,$dbh,{valref => [$casenum]});
    
    foreach my $flag (@{$flagref}) {
        if ($flag->{'FlagDesc'} =~ /Requires Action|Judge/) {
            $flag->{'Image'} = "flag-red.gif";
        } elsif ($flag->{'FlagDesc'} =~ /CM Action/) {
            $flag->{'Image'} = "flag-cm.gif";
        } elsif ($flag->{'FlagDesc'} =~ /Quarantine/) {
            $flag->{'Image'} = "flag-jr.gif";
        } else {
            $flag->{'Image'} = "flag.gif";
        }
    }
}


sub getNotes {
    my $casenum = shift;
    my $dbh = shift;
    my $noteref = shift;
    
    if (!defined($dbh)) {
        $dbh = dbConnect("icms") ||
            return;
    }
    
    if ($casenum =~ /(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)/) {
        # It's a banner-type casenum, without dashes.  Convert it.
        $casenum = sprintf("%04d-%s-%06d", $1, $2, $3);
    }
    
    my $query = qq {
        select
            date as "NoteDate",
            userid as "NoteUser",
            note as "Note"
        from
            casenotes
        where
            casenum = ?
        order by
            seq desc
    };
    
    getData($noteref,$query,$dbh,{valref => [$casenum]});
}


#
# casenotes is called by case lookup routines to display any casenotes for
#    a given UCN and allow authorized users to make changes
#    second parameter, $db, is database to reconnect to afterwards, if
#    defined.

sub casenotes {
    my $ucn = shift;
    my $db = shift;
    my $lev = shift;
    my $div = shift;
    my $ldap = shift;
    
    my $notesuser = inGroup(getUser(),'CAD-ICMS-NOTES',$ldap);
    my @flaglist;
    my @noteslist;
    
    my $cnconn = dbConnect("icms");
    
    if ($ucn =~ /(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)/) {
        # It's a banner-type casenum, without dashes.  Convert it.
        $ucn = sprintf("%04d-%s-%06d", $1, $2, $3);
    }
    
    print qq {
    <div id="flagsnotes">
    };
    
    if (defined ($cnconn)) {
        getFlags($ucn,$cnconn,\@flaglist);
        getNotes($ucn,$cnconn,\@noteslist);
    
    print qq{
        <!-- Opens main table -->
        <table>
            <tr valign="top">
            <td>
            <!-- Opens flags table -->
                        <table class="summary" id="flags">
                            <tr>  <!-- Flags table header -->
                                <td class="title">Flags</td>
                            </tr>
    };
    
    if (!scalar(@flaglist)) {
        print qq {
                            <tr>
                            <td>No flags set for this case</td>
                            </tr>
                        </table>
                    </td>
        }
    } else {
        print qq{
                <tr>
                    <td class="tableholder">
                        <table>  <!-- If there are rows to show, open table -->
                            <thead>
                                <tr class="title">
                                    <th>&nbsp;</th>
                                    <th>Date</th>
                                    <th>User</th>
                                    <th>Flag</th>
                                    <th>Expires</th>
                                </tr>
                            </thead>
                            <tbody>
        };
    
        foreach my $flag (@flaglist) {
            print qq{
                <tr class="note">
                    <td style="height: 25px"><img src="/case/images/$flag->{'Image'}" alt="flag"/></td>
                    <td>$flag->{'FlagDate'}</td>
                    <td>$flag->{'FlagUser'}</td>
                    <td><b>$flag->{'FlagDesc'}</b><br/></td>
                    <td>$flag->{'Expires'}</td>
                </tr>
        }
            }
        print qq{
                        </tbody>
                    </table>
                    </td>
                    </tr>
                    </table>
                </td>  <!-- Closed cell with flags table -->
        };
    }
    
    print qq {
            <td>
                <table class="summary" id="casenotes">
                    <tr>
                        <td class="title">
                            Case Notes
                        </td>
                    </tr>
    };
    
    if (!scalar (@noteslist)) {
        print qq{
                            <tr>
                            <td>No notes set for this case</td>
                            </tr>
                        </table>
                    </td>
                    </tr>
                </table>
                </div>
        };
    
        if ($notesuser) {
            print qq{
                    <div>
                    <input type="button" name="casenotes" value="Flags/Case Notes" onclick="document.location='$ROOTPATH/casenotes/index.cgi?ucn=$ucn&amp;div=$div&amp;lev=$lev';"/>
                    </div>
            };
        }
        return;
    } else {
        print qq{
                <tr>
                <td class="tableholder">
                    <table>
                        <thead>
                            <tr class="title">
                                <td>Date</td>
                                <td>User</td>
                                <td style="width: 600px">Note</td>
                            </tr>
                        </thead>
                        <tbody>
        };
    
        foreach my $note (@noteslist) {
            print qq{
                    <tr class="note">
                        <td style="height: 25px">$note->{'NoteDate'}</td>
                        <td>$note->{'NoteUser'}</td>
                        <td style="width: 600px">$note->{'Note'}</td>
                    </tr>
            };
        }
        print qq{
                                </tbody>
                            </table>
                        </td> <!-- Closed cell with inner table -->
                    </tr>
                </table>
                </td>  <!-- Closed cell with casenotes table -->
            </tr>
            </table>
        };
    
        if ($notesuser) {
            print qq{<input type="button" name="casenotes" value="Flags/Case Notes" onclick="document.location='$ROOTPATH/casenotes/index.cgi?ucn=$ucn&amp;div=$div&amp;lev=$lev';"/>};
        }
    }
    } else {			# tell user casenotes db is down
        print qq{<table>
            <tr valign="top">
                <td>
                    <table class="summary" id="notesdown">
                    <tr>
                        <td class="title">Flags and Case Notes</td>
                    </tr>
                    <tr>
                        <td><font color="red">
                            The Flags / Case Notes database is not available at this time.
                        </font></td>
                    </tr>";
                </td>
            </tr>
        </table>
        };
    }
    
    print qq {
        </div>  <!-- End of flagnotes div -->
    };
}

#
# mergenotesandflags merges the casenotes and flags hashes in an easily-displayable way.
#
# NOTE:  we want to show only the most recent Note, although there may be more than one.
#
sub mergenotesandflags {
    my $notes = shift;
    my $flags = shift;
    my $flagtypes = shift;
    my $merged = shift;
    
    foreach my $casenum (keys %{$notes}) {
        $merged->{$casenum}=(split '~',$notes->{$casenum})[1]; # just the note
    }
    
    foreach my $key (sort(keys %{$flags})) {
        my ($casenum,$flagtype)=split ';',$key;
    
        my @temp = split(/~/,$flagtypes->{$flagtype});
    
        next if (!defined($temp[1]));
    
        if (!defined($merged->{$casenum})) {
            $merged->{$casenum} = "";
        }
    
        if ($temp[1]=~/Requires Action|Judge/) {
            $merged->{$casenum}="<img src=$ROOTPATH/flag-red.gif><font color=green><b>".
                $temp[1]."</font></b>$merged->{$casenum}";
        } elsif ($temp[1]=~/CM Action/) {
            $merged->{$casenum}="<img src=$ROOTPATH/flag-cm.gif><font color=green><b>".
                $temp[1]."</font></b>$merged->{$casenum}";
        } else {
            $merged->{$casenum}="<font color=green>&Dagger; ".
                $temp[1]."</font> $merged->{$casenum}";
        }
    }
}

sub mergeNotesAndFlags {
    # Does the same thing as mergenotesandflags() above, but uses memory more efficiently. Will eventually remove
    # mergenotesandflags() when none of the routines still use it.
    my $notes = shift;
    my $flags = shift;
    my $flagtypes = shift;
    my $merged = shift;
    
    foreach my $casenum (keys %{$notes}) {
        # Stopgap to fix improperly-formatted case numbers from Showcase (which use UCN instead of CaseNumber)
        if ($casenum =~ /(\d\d)(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)(\D\D\D\D)(\D\D)/) {
            $casenum = sprintf("%02d-%04d-%s-%06d-%s-%s", $1, $2, $3, $4, $5, $6);
        }
        elsif($casenum =~ /(\d\d\d\d)-(\D\D)-(\d\d\d\d\d\d)/){
        	my $newCaseNum = $casenum; 
        	$newCaseNum =~ s/-//g;
        	$casenum = getSCCaseNumber($newCaseNum);
        }
        
        $merged->{$casenum}=$notes->{$casenum}->[0]->{'CaseNote'}; # just the note
    }
    
    foreach my $casenum (sort(keys %{$flags})) {
        # Stopgap to fix improperly-formatted case numbers from Showcase (which use UCN instead of CaseNumber)
        if ($casenum =~ /(\d\d)(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)(\D\D\D\D)(\D\D)/) {
            $casenum = sprintf("%02d-%04d-%s-%06d-%s-%s", $1, $2, $3, $4, $5, $6);
        }
        elsif($casenum =~ /(\d\d\d\d)-(\D\D)-(\d\d\d\d\d\d)/){
        	my $newCaseNum = $casenum; 
        	$newCaseNum =~ s/-//g;
        	$casenum = getSCCaseNumber($newCaseNum);
        }
        
        my $caseflags = $flags->{$casenum}; # An array ref
    
        foreach my $caseflag (@{$caseflags}) {
            if (!defined($merged->{$casenum})) {
                $merged->{$casenum} = "";
            }
    
            my $flagdesc = $flagtypes->{$caseflag->{'FlagType'}}[0]->{'FlagDesc'};
    
            if ($flagdesc =~ /Requires Action|Judge/) {
                $merged->{$casenum} = qq{<img src="$ROOTPATH/flag-red.gif"><span style="font-color: red; font-weight: bold">$flagdesc</span>$merged->{$casenum}};
            } elsif ($flagdesc =~ /CM Action/) {
                $merged->{$casenum} = qq{<img src="$ROOTPATH/flag-cm.gif"><span style="font-color: green; font-weight: bold">$flagdesc</span>$merged->{$casenum}};
            } else {
                $merged->{$casenum} = qq{<span style="font-color: green; font-weight: bold">&Dagger; $flagdesc</span>$merged->{$casenum}};
            }
        }
    }
}


#
# mergenotcurrent    attaches text to each merged flags/notes hash
#                    to indicate the merge isn't current
#                    (most likely because no icms database connection was available)
#
sub mergenotcurrent{
    my $merged = shift;

    foreach my $k (sort(keys %$merged)) {
    $merged->{$k}="$merged->{$k} <font color=red> - not current </font>";
  }
}

sub updateCaseNotes {
    # This function will parse through the case list for cases with the specified case types,
    # and will first set ALL of them in the casenotes that match to inactive, and then will
    # mark those in the case list as active, and set their divisions, too.
    
    # Reference to the case hash
    my $casehash = shift;
    # Reference to the array of case types (CA, CC, etc.)
    my $types = shift;
    
    my $icmsconn = dbConnect("icms");
    if (!defined($icmsconn)) {
        return;
    }
    
    my @keys = sort(keys(%{$casehash}));
    
    # Check to see if this is the "old style" of hash (tilde-delimited values) or "new style" (ref to array of hash refs).
    # If it's the old style, convert to the new style
    my $test = $casehash->{$keys[0]};
    
    my $newHash;
    
    if (ref($test) eq "") {
        # It's old style.  Convert it.
        foreach my $key (@keys) {
            my $casenum;
            if ($key =~ /^(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)$/) {
                # Put the case number into the same format that it's stored in the
                # casenotes database
                # Banner?
                $casenum = sprintf("%04d-%s-%06d", $1, $2, $3);
            } elsif ($key =~ /^(\d\d)(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)(\D\D\D\D)(\D\D)$/) {
                # Showcase?
                $casenum = sprintf("%02d-%04d-%s-%06d-%s-%s", $1, $2, $3, $4, $5, $6);
            } else {
                $casenum = $key;
            }
            $newHash->{$casenum} = [];
            my %temp;
            my ($div,$junk) = split("~", $casehash->{$key}, 2);
            $temp{'CaseNumber'} = $casenum;
            $temp{'DivisionID'} = $div;
            push(@{$newHash->{$casenum}},\%temp);
        }
    } else {
        $newHash = $casehash;
    }
    
    # Ok, now we should, regardless of how the hash was built, have a hash that is keyed
    # on the case number, and then each element is an array of hash refs - like we would
    # get from getData().
    
    # First, mark all of the cases that match $types as inactive. This whole thing should
    # be a transcation without autocommit; commit when we're done.  Faster this way.
    $icmsconn->begin_work;
    foreach my $casetype (@{$types}) {
        my @vals = ("%-$casetype-%");
        my $query = qq {
            update
                casenotes
            set
                active=0
            where
                casenum like ?
        };
        doQuery($query,$icmsconn,\@vals);
    
        $query = qq {
            update
                flags
            set
                active=0
            where
                casenum like ?
        };
        doQuery($query,$icmsconn,\@vals);
    
        $query = qq {
            update
                summaries
            set
                active=0
            where
                casenum like ?
        };
        doQuery($query,$icmsconn,\@vals);
    }
    
    foreach my $casenum (sort keys (%{$newHash})) {
        # OK, now we want to set the division for the cases, and mark them active.
        my $caseDiv = (ref $newHash->{$casenum} eq "ARRAY") ?
            $newHash->{$casenum}[0]->{DivisionID} :
            $newHash->{$casenum}->{DivisionID};
        my @vals;

        my $caseCopy = $casenum;
        if ($caseCopy =~ /(\d\d)-(\d\d\d\d)-(\D\D)-(\d\d\d\d\d\d)-(\D\D\D\D)-(\D\D)/) {
			my $casenum_vrb = sprintf("%04d-%s-%06d", $2, $3, $4);
            @vals = ($caseDiv, $casenum, $casenum_vrb);
		}
        else{
            @vals = ($caseDiv, $casenum, $casenum);
        }
        
        my $query = qq {
            update
                casenotes
            set
                division = ?,
                active = 1
            where
                casenum = ?
                OR casenum = ?
        };
        doQuery($query,$icmsconn,\@vals);
    
        $query = qq {
            update
                flags
            set
                division = ?,
                active = 1
            where
                casenum = ?
                OR casenum = ?
        };
        doQuery($query,$icmsconn,\@vals);
    
        $query = qq {
            update
                summaries
            set
                division = ?,
                active = 1
            where
                casenum = ?
                OR casenum = ?
        };
        doQuery($query,$icmsconn,\@vals);
    }
    
    # Done!  Commit the change
    $icmsconn->commit;
    $icmsconn->disconnect;
    return;
}

# New version of buildnotes() (as buildNotes()) for the new, db-based reports
#
sub buildNotes {
	my $caseRef = shift;
	my $casetypes = shift;

	my $flags = {};
	my $merged = {};

	my $icmsconn = dbConnect("icms");

	my $query = qq {
		select
			casenum as "CaseNumber",
			note as "CaseNote"
		from
			casenotes
		where
			substr(casenum,6,2) in $casetypes
			or substr(casenum,9,2) in $casetypes
			and active = 1
		order by
			date desc
	};

	my %notes;
	getData(\%notes,$query,$icmsconn,{hashkey => "CaseNumber"});

	$query = qq {
		select
			casenum as "CaseNumber",
			flagtype as "FlagType",
			idnum as "FlagID"
		from
			flags
		where
		    substr(casenum,6,2) in $casetypes
			or substr(casenum,9,2) in $casetypes
			and active = 1
		order by
			casenum desc,
			idnum
	};

	getData($flags,$query,$icmsconn,{hashkey => "CaseNumber"});

	my %flagtypes;
	$query = qq {
		select
			flagtype as "FlagType",
			dscr as "FlagDesc"
		from
		    flagtypes
	};
	getData(\%flagtypes,$query,$icmsconn,{hashkey => "FlagType"});

	mergeNotesAndFlags(\%notes,$flags,\%flagtypes,$merged);

	foreach my $casenum (keys %{$merged}) {
		my $ucn = $casenum;
		$ucn =~ s/-//g;

		if (defined ($caseRef->{$ucn})) {
			$caseRef->{$ucn}->{'FlagsAndNotes'} = $merged->{$casenum};
		}
	}

	$icmsconn->disconnect;
}


#
#
# buildnotes fills the %notes hash with appropriate casenotes for this division.
#
#
sub buildnotes {
	my $merged = shift;
	my $flags = shift;
	my $casetypes = shift;
	my $outpath = shift;
	my $DEBUG = shift;

    if ($DEBUG) {
        print "DEBUG: Reading icmsmerged.txt\n";
		readHash("$outpath/icmsmerged.txt", $merged);
    } else {
		my $icmsconn = dbConnect("icms");
		if(!defined($icmsconn)){
			print "no connection to the icms database!\nreading last successful run to get merged notes and flags...\n";
			readHash("$outpath/icmsmerged.txt",$merged);
			mergenotcurrent($merged);
			return -1;
		} else {
			my $query = qq {
				select
				    casenum as "CaseNumber",
				    note as "CaseNote"
				from
				    casenotes
				where
				    substr(casenum,6,2) in $casetypes
					or substr(casenum,9,2) in $casetypes
				order by
				    date desc
				};
			my %notes;
			getData(\%notes,$query,$icmsconn,{hashkey => "CaseNumber"});

			$query = qq {
				select
					casenum as "CaseNumber",
					flagtype as "FlagType",
					idnum as "FlagID"
				from
				    flags
				where
				    substr(casenum,6,2) in $casetypes
					or substr(casenum,9,2) in $casetypes
				order by
				    casenum desc,
				    idnum
			};
			getData($flags,$query,$icmsconn,{hashkey => "CaseNumber"});

			my %flagtypes;
			$query = qq {
				select
				    flagtype as "FlagType",
				    dscr as "FlagDesc"
				from
				    flagtypes
			};
			getData(\%flagtypes,$query,$icmsconn,{hashkey => "FlagType"});

			mergeNotesAndFlags(\%notes,$flags,\%flagtypes,$merged);

			writehash("$outpath/icmsmerged.txt",$merged);
	    	$icmsconn->disconnect;
		}
    }
}


sub updateSummaries {
	my $casenum = shift;
	my $dbh = shift;

	my $hadDBH = 1;
	if (!defined($dbh)) {
		$dbh = dbConnect("icms");
		$hadDBH = 0;
	}

	my $cdbh;

	# Showcase
	$cdbh = dbConnect($db);
	
	my $caseID = getCaseID($casenum);

	my $caseInfo = getCaseInfo($caseID,$cdbh);
    my @events;
    my $startDate = today();
    my $schema = getDbSchema($db);
    getCourtEvents($caseID, $cdbh, \@events, $schema, $startDate);
    
    # The array is in reverse order; we need to get the most recent event that is NOT canceled
    $caseInfo->{'NextEvent'} = "";
    my $index = scalar(@events) - 1;
    while ($index >= 0) {
        if ($events[$index]->{'Canceled'} eq 'N') {
            $caseInfo->{'NextEvent'} = ISO_date($events[$index]->{'EventDate'});
            last;
        }
        $index--;
    }

	my $flagSumm = "";
	my $noteSumm = "";

	my @vals = ($casenum);

	# Get a listing of the flag types
	my $flagtypes = {};
	my $query = qq {
			select
				flagtype as "FlagType",
				dscr as "FlagDesc"
			from
			    flagtypes
	};
	getData($flagtypes,$query,$dbh,{hashkey => "FlagType"});

	# Then get a listing of the notes and flags set for this case.
	$query = qq {
		select
			note as "CaseNote"
		from
			casenotes
		where
			casenum = ?
		order by
			date desc
	};

	my $notes = [];
	getData($notes,$query,$dbh,{valref => \@vals});

	my @temp;

	foreach my $note (@{$notes}) {
		my $string = "&bull;&nbsp;".$note->{'CaseNote'};
		push (@temp, $string);
	}

	$noteSumm = join("<br>", @temp);

	$query = qq {
		select
			flagtype as "FlagType",
			idnum as "FlagID"
		from
			flags
		where
		    casenum = ?
		order by
			casenum desc,
			idnum
	};

	my $flags = [];
	getData($flags,$query,$dbh,{valref => \@vals});

	my @flagSummPieces;

	foreach my $caseflag (@{$flags}) {
		my $flagdesc = $flagtypes->{$caseflag->{'FlagType'}}[0]->{'FlagDesc'};

		my $string;
		if ($flagdesc =~ /Requires Action|Judge/) {
			$string = qq{<img src="$ROOTPATH/flag-red.gif"><span style="color: red; font-weight: bold">$flagdesc</span>};
		} elsif ($flagdesc =~ /CM Action/) {
			$string = qq{<img src="$ROOTPATH/flag-cm.gif"><span style="color: green; font-weight: bold">$flagdesc</span>};
		} else {
			$string = qq{<span style="color: green; font-weight: bold">&Dagger; $flagdesc</span>};
		}

		push (@flagSummPieces, $string);
	}

	$flagSumm = join("<br>", @flagSummPieces);

	# Delete any existing summary record
	$query = qq {
		delete from
			summaries
		where
			casenum = ?
	};
	doQuery($query,$dbh,[$casenum]);

	# And add a new one
	$query = qq {
		insert into
			summaries
			(
				casenum,
				division,
				active,
				style,
				filedate,
				caseage,
				lastactdate,
                nextactdate,
				casetype,
				casestatus,
				flagdescs,
				notes
			)
			values (
				?,?,?,?,?,?,?,?,?,?,?,?
			)
	};

	@vals = (
        $casenum,
        $caseInfo->{'DivisionID'},
        1,
        $caseInfo->{'CaseStyle'},
        ISO_date($caseInfo->{'FileDate'}),
        $caseInfo->{'CaseAge'},
        ISO_date($caseInfo->{'LastActivity'}),
        ISO_date($caseInfo->{'NextEvent'}),
        $caseInfo->{'CaseType'},
        $caseInfo->{'CaseStatus'},
        $flagSumm,
        $noteSumm
	);

	doQuery($query,$dbh,\@vals);

	if (!$hadDBH) {
		$dbh->disconnect;
	}
	return;
}

sub getFlagTypes {
    my $flagTypes = shift;
    my $dbh = shift;
    
    if (!defined($dbh)) {
        $dbh = dbConnect("icms");
    }
    
    my $query = qq {
        select
            flagtype as FlagType,
            dscr as FlagDescription
        from
            flagtypes
        order by
            FlagDescription
    };
    
    if (ref($flagTypes) eq 'ARRAY') {
        getData($flagTypes, $query, $dbh);
    } elsif (ref($flagTypes) eq 'HASH') {
        getData($flagTypes, $query, $dbh, {hashkey => "FlagDescription"});
    }
}

sub calcExpire {
	my $params = shift;

	if ($params->{'exptype'} eq 'never') {
		return undef;
	} elsif ($params->{'exptype'} eq 'ondate') {
		return ISO_date($params->{'localexpdate'});
	} elsif ($params->{'exptype'} eq 'xtime') {
		my $count = $params->{'timecount'};
		my $type = $params->{'timetype'};
		if ($type eq "months") {
			return sprintf("%04d-%02d-%02d",Add_Delta_YM(Today(), 0, $count));
		} else {
			if ($type eq "weeks") {
				$count = $count * 7;
			}
			return sprintf("%04d-%02d-%02d",Add_Delta_Days(Today(), $count));
		}
	} else {
		return undef;
	}
}

1;
