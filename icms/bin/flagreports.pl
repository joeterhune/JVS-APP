#!/usr/bin/perl
#
# flagreports.pl - Produces a report for each flagtype in ICMS
# 06/13/11 lms New code.

BEGIN {
	use lib "$ENV{'PERL5LIB'}";
}

use strict;
use ICMS;
use SRS;
use Banner;
use Showcase;
use Showcase qw (
	$NOTACTIVE
	@SCINACTIVE
);
use Common qw(
	dumpVar
	getArrayPieces
	changeDate
	convertDates
	inArray
	ISO_date
    US_date
    today
);

use DB_Functions qw(
	dbConnect
	doQuery
	getData
	getDataOne
	getScCaseAge
);

use File::Path qw(make_path);

my $DEBUG=0;
my $MSGS=1;

# No output buffering
$| = 1;

my $outpath;
my $webpath;
my $county="Sarasota";

my $icmsdb='ok'; # status of icms database when run - 'ok' or 'bad'

# ----- my global vars

my @flagtypes;
my %casesicms;

my $activephrase = "and nvl(SRS_STATUS_CODE(cdbcase_id),'none') not in $INACTIVECODES ";
my $scactivephrase = "and CaseStatus not in $NOTACTIVE";

sub casenumtoucn {
    my($casenum)=@_;
    my $x=substr($casenum,0,4)."-".substr($casenum,4,2)."-".substr($casenum,6,6);
    if (substr($casenum,12,1) ne "") { $x.="-".substr($casenum,12); }
    return $x;
}

# get all the info for this flagtype and keep it.
sub processFlag {
	my $ft = shift;
	my $dscr = shift;
	my $icmsconn = shift;

	my $query = qq {
		select
			distinct(casenum) as "CaseNumber"
		from
			flags
		where
			flagtype=$ft
		order by
			casenum desc
	};

	if($DEBUG) {
		print "Processing flagtype $ft\n";
	}

	my @a;
	getData(\@a, $query, $icmsconn);
	$casesicms{$ft} = \@a;
	if($DEBUG){
		print "Found ".scalar(@a)." cases for flag $ft - $dscr\n";
	}
}

sub showCases {
	my $ft = shift;
	my $dscr = shift;
	if($DEBUG) {
		print "...in showCases for $ft \n";
		my $thissize = scalar @{$casesicms{$ft}};
		print "... this size is $thissize \n";
		print "doing flagtype $ft ($dscr)...\n";
		for my $i (0 .. $#{$casesicms{$ft}} ) {
			print "$i case is: $casesicms{$ft}[$i] \n";
		}
	}
}

sub addNotesCases {
	# Add files that have notes but no flags, so they get put into the summaries table
	my $allcases = shift;
	my $icmsconn = shift;
	my $bdbh = shift;
	my $scdbh = shift;

	my $query = qq {
		select
			distinct(casenum) as "CaseNumber"
		from
			casenotes
		where
			casenum <> ''
	};

	my @cases;
	getData(\@cases, $query, $icmsconn);

	my @bannerCases;
	my @scCases;

	foreach my $case (@cases) {
		if (defined($allcases->{$case->{'CaseNumber'}})) {
			# We've already looked this up.  Don't do it again
			next;
		} else {
			# Need to look this case up
			if ($case->{'CaseNumber'} =~ /^50-/) {
				push(@scCases, $case->{'CaseNumber'});
			} else {
				push(@bannerCases, $case->{'CaseNumber'})
			}
		}
	}

	my $count = 0;
	my $perquery = 100;
    my $today = US_date(today());

	while ($count < scalar(@bannerCases)) {
	    my @temp;
	    getArrayPieces(\@bannerCases, $count, $perquery, \@temp, 1);

		if (scalar(@temp)) {
			my @newArray;
			foreach my $case (@temp) {
				# Strip dashes - they're there in casenotes, but not in Banner.
				$case =~ s/-//g;
				push(@newArray,$case);
			}
			my $inString = join(",", @newArray);

			my $query = qq {
				select
					cdbcase_id as "CaseNumber",
					cdbcase_division_id as "DivisionID",
					cdbcase_desc as "CaseStyle",
					cdbcase_init_filing as "FileDate",
					cdbcase_ctyp_code as "CaseType",
					SRS_STATUS_CODE(cdbcase_id) as "CaseStatus"
				from
					cdbcase
				where
					cdbcase_id in ($inString)
					and  cdbcase_sealed_ind <> 3
			};

			my @caseinfo;
			sqlHashArray($query,$bdbh,\@caseinfo);
            
			# Get the last activity date
            foreach my $case (@caseinfo) {
                $query = qq {
                    select
                        NVL(max(cdrdoct_filing_date),'') as "LastActivity"
                    from
                        cdrdoct
                    where
                        cdrdoct_case_id = ?
                };
                my $lastActivity = getDataOne($query,$bdbh,[$case->{'CaseNumber'}]);
                $case->{'LastActivity'} = $lastActivity->{'LastActivity'};
                
                my @events;
                Banner::getEvents($case->{'CaseNumber'}, $bdbh, \@events, $today);
                
                # The array is in reverse order; we need to get the most recent event that is NOT canceled
                $case->{'NextEvent'} = "";
                my $index = scalar(@events) - 1;
                while ($index >= 0) {
                    if ($events[$index]->{'Canceled'} eq 'N') {
                        $case->{'NextEvent'} = $events[$index]->{'EventDate'};
                        last;
                    }
                    $index--;
                }
            }

            foreach my $case (@caseinfo) {
                # Put it into YYYY-TT-SSSSSS format.
                $case->{'CaseNumber'} =~ /(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)/;
                $case->{'CaseNumber'} = sprintf("%04d-%s-%06d", $1, $2, $3);
                # And add each case to the %allcases hash so we don't look it up again.
                $allcases->{$case->{'CaseNumber'}} = $case;
                # We'll need this, too.
                $case->{'CaseAge'} = getage($case->{'FileDate'});
                $case->{'FileString'} = sprintf("%s~%s~%s~%s~%s~%s~%s~%s~%s", $case->{'CaseNumber'}, $case->{'DivisionID'},
                                     $case->{'CaseStyle'}, $case->{'FileDate'}, $case->{'CaseType'},
                                     $case->{'CaseStatus'},$case->{'LastActivity'},$case->{'NextEvent'},$case->{'CaseAge'});
            }
            $count += $perquery;
        }
    }

    $count = 0;

    # And do the same thing for Showcase
    while ($count < scalar(@scCases)) {
        my @temp;
        getArrayPieces(\@scCases, $count, $perquery, \@temp, 1);
    
        if (scalar(@temp)) {
            my $inString = join(",", @temp);
    
            my $query = qq {
                select
                    CaseNumber,
                    DivisionID,
                    CaseStyle,
                    FileDate,
                    CaseType,
                    CaseStatus,
                    ReopenDate,
                    ReopenCloseDate,
                    DispositionDate
                from
                    vCase with(nolock)
                where
                    CaseNumber in ($inString)
                    and Sealed='N'
            };
    
            my @caseinfo;
            sqlHashArray($query,$scdbh,\@caseinfo);
    
            # Get the last activity date
            foreach my $case (@caseinfo) {
                $query = qq {
                    select
                        max(EffectiveDate) as LastActivity
                    from
                        vDocket with(nolock)
                    where
                        CaseNumber = ?
                };
                my @vals = ($case->{'CaseNumber'});
                my $lastActivity = getDataOne($query,$scdbh,\@vals);
                $case->{'LastActivity'} = changeDate($lastActivity->{'LastActivity'});
                
                my @events;
                Showcase::getCourtEvents($case->{'CaseNumber'}, $scdbh, \@events, undef, $today);       
                
                # The array is in reverse order; we need to get the most recent event that is NOT canceled
                $case->{'NextEvent'} = "";
                my $index = scalar(@events) - 1;
                while ($index >= 0) {
                    if ($events[$index]->{'Canceled'} eq 'N') {
                        $case->{'NextEvent'} = $events[$index]->{'EventDate'};
                        last;
                    }
                    $index--;
                }
    
                # Convert Dates
                foreach my $field ("FileDate","DispositionDate","ReopenDate","ReopenCloseDate") {
                    $case->{$field} = changeDate($case->{$field});
                };
    
                # And add each case to the %allcases hash so we don't look it up again.
                $allcases->{$case->{'CaseNumber'}} = $case;
                # We'll need this, too.
                $case->{'CaseAge'} = getScCaseAge($case,$scdbh);
                $case->{'FileString'} = sprintf("%s~%s~%s~%s~%s~%s~%s~%s~%s", $case->{'CaseNumber'}, $case->{'DivisionID'},
                                     $case->{'CaseStyle'}, $case->{'FileDate'}, $case->{'CaseType'},
                                     $case->{'CaseStatus'},$case->{'LastActivity'},$case->{'NextEvent'},$case->{'CaseAge'});
            }
            $count += $perquery;
        }
    }
}


# Build data and write file - expects 'active' or 'all' as which.
sub writeFile {
    my $ft = shift;
    my $dscr =shift;
    my $allcases = shift;
    my $icmsconn = shift;
    my $bdbh = shift;
    my $scdbh = shift;
    
    print "In writeFile '$dscr'!!\n";
    
    my @flagCases;
    my @bannerCases;
    my @scCases;
    my $which;
    
    # Make arrays of the Showcase and Banner cases, to reduce the number of individual
    # queries we need to run.
    foreach my $case (@{$casesicms{$ft}}) {
        if (defined($allcases->{$case->{'CaseNumber'}})) {
            # We've already looked this up.  Don't do it again
            push(@flagCases,$allcases->{$case->{'CaseNumber'}});
        } else {
            # Need to look this case up
            if ($case->{'CaseNumber'} =~ /^50-/) {
                push(@scCases, $case->{'CaseNumber'});
            } else {
                push(@bannerCases, $case->{'CaseNumber'})
            }
        }
    }

    my $count = 0;
    my $perquery = 100;
    
    my $today = today();
    
    while ($count < scalar(@bannerCases)) {
        my @temp;
        getArrayPieces(\@bannerCases, $count, $perquery, \@temp, 1);
    
        if (scalar(@temp)) {
            my @newArray;
            foreach my $case (@temp) {
                # Strip dashes - they're there in casenotes, but not in Banner.
                $case =~ s/-//g;
                push(@newArray,$case);
            }
            my $inString = join(",", @newArray);
    
            my $query = qq {
                select
                    cdbcase_id as "CaseNumber",
                    cdbcase_division_id as "DivisionID",
                    cdbcase_desc as "CaseStyle",
                    cdbcase_init_filing as "FileDate",
                    cdbcase_ctyp_code as "CaseType",
                    SRS_STATUS_CODE(cdbcase_id) as "CaseStatus"
                from
                    cdbcase
                where
                    cdbcase_id in ($inString)
                    and  cdbcase_sealed_ind <> 3
            };
    
            my @caseinfo;
            sqlHashArray($query,$bdbh,\@caseinfo);
            
            # Get the last activity date
            foreach my $case (@caseinfo) {
                $query = qq {
                    select
                        NVL(max(cdrdoct_filing_date),'') as "LastActivity"
                    from
                        cdrdoct
                    where
                        cdrdoct_case_id = ?
                };
                my $lastActivity = getDataOne($query,$bdbh,[$case->{'CaseNumber'}]);
                $case->{'LastActivity'} = $lastActivity->{'LastActivity'};
                
                my @events;
                Banner::getEvents($case->{'CaseNumber'}, $bdbh, \@events, $today);
                
                # The array is in reverse order; we need to get the most recent event that is NOT canceled
                $case->{'NextEvent'} = "";
                my $index = scalar(@events) - 1;
                while ($index >= 0) {
                    if ($events[$index]->{'Canceled'} eq 'N') {
                        $case->{'NextEvent'} = ISO_date($events[$index]->{'EventDate'});
                        last;
                    }
                    $index--;
                }
            }

			foreach my $case (@caseinfo) {
				# Put it into YYYY-TT-SSSSSS format.
				$case->{'CaseNumber'} =~ /(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)/;
				$case->{'CaseNumber'} = sprintf("%04d-%s-%06d", $1, $2, $3);
				# Add each case to the list of cases for this flag.
				push(@flagCases, $case);
				# And add each case to the %allcases hash so we don't look it up again.
				$allcases->{$case->{'CaseNumber'}} = $case;
				# We'll need this, too.
				$case->{'CaseAge'} = getage($case->{'FileDate'});
				$case->{'FileString'} = sprintf("%s~%s~%s~%s~%s~%s~%s~%s~%s", $case->{'CaseNumber'}, $case->{'DivisionID'},
									 $case->{'CaseStyle'}, $case->{'FileDate'}, $case->{'CaseType'},
									 $case->{'CaseStatus'},$case->{'LastActivity'},$case->{'NextEvent'},$case->{'CaseAge'});
			}
			$count += $perquery;
		}
	}

	$count = 0;

	# And do the same thing for Showcase
	while ($count < scalar(@scCases)) {
	    my @temp;
	    getArrayPieces(\@scCases, $count, $perquery, \@temp, 1);

		if (scalar(@temp)) {
			my $inString = join(",", @temp);

			my $query = qq {
				select
					CaseNumber,
					DivisionID,
					CaseStyle,
					FileDate,
					CaseType,
					CaseStatus,
					ReopenDate,
					ReopenCloseDate,
					DispositionDate
				from
					vCase with(nolock)
				where
					CaseNumber in ($inString)
					and Sealed='N'
			};

			my @caseinfo;
			sqlHashArray($query,$scdbh,\@caseinfo);

			# Get the last activity date
			foreach my $case (@caseinfo) {
				$query = qq {
					select
						max(EffectiveDate) as LastActivity
					from
						vDocket with(nolock)
					where
						CaseNumber = ?
				};
				my @vals = ($case->{'CaseNumber'});
				my $lastActivity = getDataOne($query,$scdbh,\@vals);
				$case->{'LastActivity'} = changeDate($lastActivity->{'LastActivity'});
                
                my @events;
                Showcase::getCourtEvents($case->{'CaseNumber'}, $scdbh, \@events, undef, $today);       
                
                # The array is in reverse order; we need to get the most recent event that is NOT canceled
                $case->{'NextEvent'} = "";
                my $index = scalar(@events) - 1;
                while ($index >= 0) {
                    if ($events[$index]->{'Canceled'} eq 'N') {
                        $case->{'NextEvent'} = $events[$index]->{'EventDate'};
                        last;
                    }
                    $index--;
                }
                
				# Convert Dates
				foreach my $field ("FileDate","DispositionDate","ReopenDate","ReopenCloseDate") {
					$case->{$field} = changeDate($case->{$field});
				};

				# Add each case to the list of cases for this flag.
				push(@flagCases, $case);
				# And add each case to the %allcases hash so we don't look it up again.
				$allcases->{$case->{'CaseNumber'}} = $case;
				# We'll need this, too.
				$case->{'CaseAge'} = getScCaseAge($case,$scdbh);
				$case->{'FileString'} = sprintf("%s~%s~%s~%s~%s~%s~%s~%s~%s", $case->{'CaseNumber'}, $case->{'DivisionID'},
									 $case->{'CaseStyle'}, $case->{'FileDate'}, $case->{'CaseType'},
									 $case->{'CaseStatus'},$case->{'LastActivity'},$case->{'NextEvent'},$case->{'CaseAge'});
			}
			$count += $perquery;
		}
	}

	# write the files - do both active and all at the same time
	# Check to be sure the directory exists first.  If not, make it.
	my $filepath = "$outpath/$ft";
	if (!-d "$filepath") {
		print "Making directory '$filepath'...";
		make_path("$filepath", {
			verbose => 1,
			mode => 0755,
			error => \my $err
								  });
		if (@$err) {
			for my $diag (@$err) {
				my ($file, $message) = %$diag;
				if ($file eq '') {
					print "general error: $message\n";
				} else {
					print "problem creating $filepath: $message\n";
				}
			}
			exit;
		}
	}
	my $allfile = "$outpath/$ft/all.txt";
	open(ALLFILE,">$allfile") or die "Couldn't open output file '$allfile': $!\n\n";
	print ALLFILE <<EOS;
DATE=$TODAY
TITLE1=Flagged Case Search for Flag $dscr, All Divisions, All Cases
TITLE2=
VIEWER=view.cgi
FIELDNAMES=Case #~Div~Name~Initial File~Age~Last Activity~Next Event~Type~Status~Flags~Notes
FIELDTYPES=L~A~I~D~D~D~D~S~A~A~A
EOS

	my $activefile = "$outpath/$ft/active.txt";
	open(ACTIVEFILE,">$activefile") or die "Couldn't open output file '$activefile': $!\n\n";
	print ACTIVEFILE <<EOS;
DATE=$TODAY
TITLE1=Flagged Case Search for Flag $dscr, All Divisions, Active Cases Only
TITLE2=
VIEWER=view.cgi
FIELDNAMES=Case #~Div~Name~Initial File~Age~Last Activity~Next Event~Type~Status~Flags~Notes
FIELDTYPES=L~A~I~D~D~D~D~S~A~A~A
EOS

	my $activecount = 0;
	my $allcount = 0;
	foreach my $flagCase (@flagCases) {
		my $string = $flagCase->{'FileString'};
		my($case,$divid,$desc,$date,$code,$status,$ladate,$nextevent,$age)=split("~", $string);

		my $query = qq {
			select
				date as "FlagDate",
				dscr as "FlagDesc",
				userid as "FlagUser"
			from
				flags a,
				flagtypes b
			where
				a.flagtype=b.flagtype
				and casenum = ?
			order by
				date desc
		};
		my @flags;
		getData(\@flags,$query,$icmsconn, {'valref' => [$case]});
		my @dscrs;
		foreach my $flag (@flags){
			my $spanstyle = "";
			if($flag->{'FlagDesc'} =~ /Action|Judge/) {
				$spanstyle = qq { style="color: red"};
			}
			my $showflag = sprintf("<span $spanstyle>%s:%s:%s</span>", $flag->{'FlagDate'}, $flag->{'FlagDesc'}, $flag->{'FlagUser'});
			push(@dscrs, $showflag);
		}
		my $dscrs = join("<br/>", @dscrs);

		# show casenotes, too
		my @listnotes;
		$query = qq {
			select
				date as "NoteDate",
				note as "Note"
			from
				casenotes
			where
				casenum = ?
			order by
				seq desc
		};
		getData(\@listnotes,$query,$icmsconn, { 'valref' => [$case] });

		my @notes;
		foreach my $note (@listnotes){
			my $shownote = sprintf("%s:%s", $note->{'NoteDate'}, $note->{'Note'});
			push (@notes, $shownote);
		}
		my $notes = join("<br/>", @notes);

		$allcount++;
		if ($case =~ /^50-/) {
			my $outString = qq{$case~$divid~$desc~$date~$age~$ladate~$nextevent~$code~$status~<span style="color: green">$dscrs</span>~$notes};
			print ALLFILE $outString . "\n";
			if (!defined($allcases->{$case}->{'outString'})) {
				$allcases->{$case}->{'outString'} = $outString;
			}
			if (!inArray(\@SCINACTIVE, $flagCase->{'CaseStatus'})) {
				print ACTIVEFILE $outString . "\n";
				$allcases->{$case}->{'active'} = 1;
				$activecount++;
			} else {
				$allcases->{$case}->{'active'} = 0;
			}
		} else {
			my $outString = qq{$case~$divid~$desc~$date~$age~$ladate~$nextevent~$code~$status~<span style="color: green">$dscrs</font>~$notes};
			print ALLFILE $outString . "\n";
			if (!defined($allcases->{$case}->{'outString'})) {
				$allcases->{$case}->{'outString'} = $outString;
			}
			if (!inArray(\@INACTIVECODES, $flagCase->{'CaseStatus'})) {
				print ACTIVEFILE $outString . "\n";
				$allcases->{$case}->{'active'} = 1;
				$activecount++;
			} else {
				$allcases->{$case}->{'active'} = 0;
			}
		}
	}
	close(ACTIVEFILE);
	close (ALLFILE);
	return ($activecount,$allcount);
}

sub writeReports {
	my $ft = shift;
	my $dscr = shift;
	my $allcases = shift;
	my $icmsconn = shift;
	my $bdbh = shift;
	my $scdbh = shift;

	if($MSGS) {
		print "Writing Flag File Reports for flagtype $ft ($dscr)...\n";
	}
	if (!-d "$outpath") {
		print "making directory $outpath \n"; mkdir "$outpath",0777;
	}
	if (!-d "$outpath/$ft") {
		print "making directory $outpath/$ft \n"; mkdir "$outpath/$ft",0777;
	}
	#
	# get all active case data first, then all
	my ($active,$all) = writeFile($ft,$dscr,$allcases,$icmsconn,$bdbh,$scdbh);
	return "$active~$all";
}


sub doit() {
	if($MSGS) {
		print "starting flag reports flagreports ".timestamp()."\n";
	}

    if (@ARGV==1 and $ARGV[0] eq "DEBUG") {
		$DEBUG=1; print "DEBUG!\n";
	}
    $outpath="/var/www/html/case/$county/flags";
    $webpath="/case/$county/flags";
	my $icmsconn = dbConnect("icms");

	# Read all flags from icms flags table.
	if($DEBUG) {
		print "Finding icms database case info...\n";
	}
	my $query = qq {
		select
			distinct(flagtype) as "FlagType",
			dscr as "FlagDesc"
		from
			flagtypes
		order by
			dscr
	};

	getData(\@flagtypes,$query,$icmsconn);
	#my %temp = ("FlagType" => 21, "FlagDesc" => "Bankruptcy");
	#push(@flagtypes, \%temp);

	if($DEBUG) {
		print "Found ".scalar @flagtypes." flags.\n";
	}

	# Write all flags to flagtypes.conf in the etc folder.
	open OUTFILE,"+>/usr/local/icms/etc/flagtypes.conf";
    foreach my $flagtype (@flagtypes) {
		print OUTFILE "$flagtype->{'FlagType'}~$flagtype->{'FlagDesc'}\n";
	}
    
    if($MSGS) {
		print "Deleting expired flags ".timestamp()."\n";
	}
    $query = qq {
        delete from
            flags
        where
            expires < CURRENT_DATE
    };;
    doQuery($query, $icmsconn);

	# Find all cases for each flag.
	if($DEBUG) {
		print "Processing each flag type... \n"
	}
	foreach my $flagtype (@flagtypes) {
		processFlag($flagtype->{'FlagType'},$flagtype->{'FlagDesc'},$icmsconn);
		showCases($flagtype->{'FlagType'},$flagtype->{'FlagDesc'});
	}

	# Write the Flagged Cases Reports....
	if($MSGS) {
		print "About to write nightly reports...\n";
	}
	my $bdbh = dbconnect("wpb-banner-rpt");
	my $scdbh = dbconnect("showcase-rpt");

    # Use this to prevent repeatedly looking up the case in multiple calls of writeFile	()
	my %allcases;

	foreach my $flagtype (@flagtypes) {
        #next if ($flagtype->{'FlagType'} != 111);
        #next if ($flagtype->{'FlagType'} == 44);
		my $cnts;
		print "Writing for $flagtype->{'FlagDesc'}...\n";
		$cnts = writeReports($flagtype->{'FlagType'},$flagtype->{'FlagDesc'},\%allcases,$icmsconn,$bdbh,$scdbh);
		my($active,$all)=split '~',$cnts;
		print "Done - wrote $active active, $all all.\n\n";
		# write the summary file for this flag
		open OUTFILE,"+>$outpath/$flagtype->{'FlagType'}/index.txt" or die "Couldn't open $outpath/$flagtype->{'FlagType'}/index.txt: $!\n\n";
		print OUTFILE <<EOS;
DATE=$TODAY
TITLE1=$county Beach County
TITLE2=Flagged Cases for Flag $flagtype->{'FlagDesc'}
PATH=case/$county/flags/$flagtype->{'FlagType'}/
HELP=
All cases~$all~1~all
Active only~$active~1~active
EOS
	   close(OUTFILE);
	}

	print "Now getting information on cases that have notes but no flags.";
	addNotesCases(\%allcases, $icmsconn, $bdbh, $scdbh);

	# Keep summary information for all cases
	$icmsconn->begin_work;
	$query = qq {
		delete from
			summaries
	};
	doQuery($query,$icmsconn);

	foreach my $key (sort keys %allcases) {
		next if (length($key) >= 30);
        # Convert dates to ISO format for the DB
		foreach my $field ('FileDate', 'LastActivity','DispostionDate','ReopenCloseDate','ReopenDate','NextEvent') {
			if (defined($allcases{$key}->{$field})) {
				$allcases{$key}->{$field} = ISO_date($allcases{$key}->{$field});
			}
		}
		if(defined($allcases{$key}->{'outString'})) {
			my @valArgs = split(/~/, $allcases{$key}->{'outString'});

			# In case the first element has a viewer attached (we don't want that here)
			my @temp = split(/;/, $valArgs[0]);
			$valArgs[0] = $temp[0];
			if (scalar(@valArgs) == 10) {
            	# Empty notes.
				push(@valArgs,"");
			}
			push(@valArgs,$allcases{$key}->{'active'});
			# Fix format for the 2 date strings (elements 3 and 5)
			foreach my $pos (3,5) {
				if ($valArgs[$pos] eq "") {
					$valArgs[$pos] = undef;
				} else {
					$valArgs[$pos] = ISO_date($valArgs[$pos]);
				}
			}

			$query = qq {
				insert into
					summaries (
						casenum,
						division,
						style,
						filedate,
						caseage,
						lastactdate,
                        nextactdate,
						casetype,
						casestatus,
						flagdescs,
						notes,
						active
					)
					values (
						?,?,?,?,?,?,?,?,?,?,?,?
					)
			};

            doQuery($query,$icmsconn,\@valArgs);
		}
	}
	$icmsconn->commit;

	if($MSGS) {
		print "finished flag reports flagreports ".timestamp()."\n";
	}
}

#
# MAIN PROGRAM STARTS HERE!
#

doit();
