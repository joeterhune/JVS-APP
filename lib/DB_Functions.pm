#!/usr/bin/perl

# New package to contain new DB Functions; any new DB functionality should be implemented in this module
# and NOT in ICMS.pm.  Export only functions that are necessary to export, to avoid polluting namespaces,
# and always, always use strict pragma unless there's no other way.

package DB_Functions;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    checkCaseAccess
    dbConnect
    doQuery
    getData
    getDataOne
    getDbSchema
    getDivs
    getCustomQueues
    getDivsLDAP
    getCaseInfo
    getDivJudges
    ldapConnect
    ldapLookup
    getScCaseAge
    $LDAPBINDDN
    $LDAPHOST
    $LDAPBINDPW
    $LDAPBASE
    $LDAPSVCBASE
    $CAD_OU
    @SECRETTYPES
    @NAPTYPES
    findCaseType
    inGroup
    $DEFAULT_SCHEMA
    eFileInfo
    getDivInfo
    getVrbCases
    lastInsert
    getDocketCodes
    getWatchCases
    getWatchList
    getLastRun
    getEmailFromAD
    getVrbEventsByCase
    getInitDockets
    getQueueItems
    log_this
    getVrbEvents
    getSubscribedQueues
	getSharedQueues
	getQueues
	getFilingAccounts
	getDocData
	getEmergencyQueues
);

use Data::Dumper qw(Dumper);
use Date::Calc qw (:all Parse_Date);
use DBI;
use Switch;
use Net::LDAP;
use Time::HiRes qw (
	gettimeofday
	tv_interval
);
use XML::Simple;

use Common qw(
	logToFile
	dumpVar
	getAge
	inArray
	today
	ISO_date
    %courtTypes
    %portalTypes
    returnJson
    timeStamp
    convertCaseNumber
    sanitizeCaseNumber
    getArrayPieces
    getUser
);

use Carp qw (cluck longmess);

use CGI::Carp qw(fatalsToBrowser);
use JSON;

our $CAD_OU="Enterprise";
our $LDAPHOST = ["ldaps://pbcgccdc2.pbcgov.org", "ldaps://pbcgccdc1.pbcgov.org"];
our $LDAPBINDDN = "cn=cad icms,ou=Services,ou=CAD,ou=$CAD_OU,DC=PBCGOV,DC=ORG";
our $LDAPBINDPW = "password99";
our $LDAPBASE = "ou=Users,ou=CAD,ou=$CAD_OU,dc=PBCGOV,dc=ORG";
our $LDAPSVCBASE = "ou=Services,ou=CAD,ou=$CAD_OU,dc=PBCGOV,dc=ORG";

our $DEFAULT_SCHEMA = "dbo";

# Case types for "secret" cases (adoption, termination of parental rights,
# tuberculosis, etc.
our @SECRETTYPES = (
		    "'AD'",
		    "'AJ'",
			"'CJ'",
		    "'TE'",
		    "'TP'",
		    "'TB'"
		   );

# These are the same as @SECRETTYPES, but without the quotes
our @NAPTYPES = (
	'AD','AJ','CJ','TE','TP','TB'
);

our @JUVTYPES = ('DP','CJ');
our @PROTYPES = ('MH','CP','GA');
our @FAMTYPES = ('DA','DR');
our @CIRCCIVTYPES = ('CA');
our @CTYCIVTYPES = ('CC','SC');
our @CRIMTYPES = ('CF','MM');
our @CTYCRIMTYPES = ('CO','MO','CT');
our @TRAFTYPES = ('TR','TI');

my $BENCH = 0;

sub log_this {
    my $logApp = shift;
    my $logType = shift;
    my $logMsg = shift;
    my $logIP = shift;
    my $dbh = shift;
    
    if (!defined($dbh)) {
        $dbh = dbConnect("icms");
    }
    
    my $query = "
        insert into
            audit_log (
                log_app,
                log_date_time,
                log_type,
                log_msg,
                log_ip
            ) values (
                ?,?,?,?,?
            )
    ";
    doQuery($query, $dbh, [$logApp, undef, $logType, $logMsg, $logIP]);
}

sub dbConnect {
	# Not to be confused with dbconnect() in ICMS, this returns a DB handle, but does NOT define a global
	# $dbh handle.
	# Aside from that, most of the functionality is the same.

	my $dbname = shift;
	my $dbdb = shift;
	my $dontdie = shift;
	my $errorRef = shift;

	if (!defined($dontdie)) {
		$dontdie = 0;
	}
	
	my $configXml = $ENV{'APP_ROOT'} . "/conf/ICMS.xml";
	my $config = XMLin($configXml);

	if (!defined($config->{'dbConfig'}->{$dbname})) {
		if (!$dontdie) {
			warn "No database configuration '$dbname' found.\n\n";
			if (defined($errorRef)) {
				$$errorRef = "No database configuration '$dbname' found";
			}
			return undef;
		} else {
			warn "No database configuration '$dbname' found.\n\n";
			if (defined($errorRef)) {
				$$errorRef = "No database configuration '$dbname' found";
			}
		}
	}

	#exit;

	my $dbConfig = $config->{'dbConfig'}->{$dbname};

	my $dbtype = $dbConfig->{'dbType'};
	my $dbhost = $dbConfig->{'dbHost'};
	my $dbuser = $dbConfig->{'dbUser'};
	my $dbpass = $dbConfig->{'dbPass'};
	if (!defined($dbdb)) {
		$dbdb = $dbConfig->{'dbName'};
	}

	my $startTime;
	my $endTime;

	if ($BENCH) {
		$startTime = [gettimeofday];
	}

    switch($dbtype) {
		case "mysql" {
			my $dbstring = "";
			my $hoststring = "";
			my $portstring = "";
			if ((defined($dbdb )) && ($dbdb ne '')) {
				$dbstring = "database=$dbdb;";
			}
			if ($dbhost ne "localhost") {
				my $dbport = 3306;
				if ($dbhost =~ /:/) {
					# An alternate port was specified
					($dbhost,$dbport) = split(":", $dbhost);
				}
				$hoststring = "host=$dbhost";
				$portstring = "port=$dbport";
			} else {
				$hoststring = "host=$dbhost";
			}
			my $dsn = "DBI:mysql:" . join(";",$dbstring,$hoststring,$portstring);
			my $dbh;
			$dbh = DBI->connect(
								$dsn,
								$dbuser,
								$dbpass,
								{
									PrintError => 0
								}
								);
			
			if (!$dbh) {
				if ($dontdie) {
					warn "Unable to connect to database '$dbname': " . $DBI::errstr;
					if (defined($errorRef)) {
						$$errorRef = $DBI::errstr;
					}
					return undef;
				} else {
					die "Unable to connect to database '$dbname': " . $DBI::errstr . "\n\n";
				}
			} else {
				if ($BENCH) {
					$endTime = [gettimeofday];
					my $elapsed = tv_interval $startTime, $endTime;
					logToFile("It took $elapsed seconds to establish a database connection to a DB of type '$dbtype' on host '$dbhost'");
				}
				return $dbh;
			}
		}
		case "oracle" {
			my $dbstring = "";
			my $hoststring = "";
			my $portstring = "";
			my $dbh = DBI->connect("dbi:Oracle:$dbhost",$dbuser,$dbpass);

			if (!defined($dbh)) {
				if ($dontdie) {
					warn "Unable to connect to database '$dbhost': " . $DBI::errstr;
					if (defined($errorRef)) {
						$$errorRef = $DBI::errstr;
					}
					return undef;
				} else {
					die "Unable to connect to database '$dbhost': " . $DBI::errstr . "\n\n";
				}
			} else {
				if ($BENCH) {
					$endTime = [gettimeofday];
					my $elapsed = tv_interval $startTime, $endTime;
					logToFile("It took $elapsed seconds to establish a database connection to a DB of type '$dbtype' on host '$dbhost'");
				}
				$dbh->{'LongReadLen'} = 500000;
				$dbh->do("alter session set nls_date_format='MM/DD/YYYY'");
				return $dbh;
			}
		}
		case "mssql" {
			# the whole connection string must be in here.
			$dbname=~s/\|/;/g;

			my $dbh;

			my $dsn = "dbi:Sybase:$dbhost";
			
			eval {
				local $SIG{'ALRM'} = sub { die "timeout\n" };
				alarm(5);
				$dbh = DBI->connect("dbi:Sybase:$dbhost",$dbuser,$dbpass);
				alarm(0);
			};
			if ($@) {
				cluck "This is how we got here!";
				my $longmess = longmess("message from cluck()");
				print STDERR $longmess;
				if (($@ eq "timeout") && ($dontdie)) {
					return undef;
				}
			}
			
			if (!defined($dbh)) {
				if ($dontdie) {
					warn "Unable to connect to database '$dbhost': " . $DBI::errstr;
					if (defined($errorRef)) {
						$$errorRef = $DBI::errstr;
					}
					return undef;
				} else {
					die "Unable to connect to database '$dbhost': " . $DBI::errstr . "\n\n";
				}
			} elsif ($dbdb ne "") {
				# select a database
				$dbh->do("use $dbdb");
			}
			if ($BENCH) {
				$endTime = [gettimeofday];
				my $elapsed = tv_interval $startTime, $endTime;
				logToFile("It took $elapsed seconds to establish a database connection to a DB of type '$dbtype' on host '$dbhost'");
			}
			
			return $dbh;
		}
		case "postgres" {
			if (defined ($dbConfig->{'dbPort'})) {
				$dbhost .= ";port=$dbConfig->{'dbPort'}";
			}

			my $dbh = DBI->connect("dbi:Pg:dbname=$dbname;host=$dbhost",$dbuser,$dbpass);
			if (!defined $dbh) {
				if ($dontdie) {
					warn "Unable to connect to database '$dbhost': " . $DBI::errstr;
					return undef;
				} else {
					die "Unable to connect to database '$dbhost': " . $DBI::errstr . "\n\n";
				}
			}
			if ($BENCH) {
				$endTime = [gettimeofday];
				my $elapsed = tv_interval $startTime, $endTime;
				logToFile("It took $elapsed seconds to establish a database connection to a DB of type '$dbtype' on host '$dbhost'");
			}
			$dbh->do("set datestyle to 'SQL'"); # make Postgres dates look 'normal'
			return $dbh;
		} else {
			if ($dontdie) {
				warn "Unknown database type '$dbtype'\n\n";
				return undef;
			} else {
				die "Unknown database type '$dbtype'\n\n";
			}
		}
	}
}


sub getData {
    # This populates $dataref with the results of a query, with each row being a hash ref.  If $dataref is an
    # array ref, each element of the array will correspond to a single row.  If $dataref is a hash array,
    # it will use the value defined in $hashkey (which must also be a part of the query) as the key for the hash,
    # an it will itself be an array containing rows that correspond to that key
    my $dataref = shift;
    my $query = shift;
    my $dbh = shift;

    my $startTime;
    my $endTime;

    if ($BENCH) {
        $startTime = [gettimeofday];
        my $logString = sprintf ("Starting the following query: \n\t%s", $query);
        logToFile($logString);
    }
    
    # A reference to a hash containing attributes - like an array ref for values for substitutions ("valref"),
    # or a hash key ("hashkey") to be used if the $dataref is a hash ref, or whether or not to "flatten" the elements
    # returned if the $dataref is a hash ref, as opposed to returning each element as an array ref.
    my $attrs = shift;

    if ((ref $dataref) eq "HASH") {
        if (!defined($attrs->{'hashkey'})) {
            die "getData() called with a hash ref, but no key was specified.\n\n";
        }
    } elsif ((ref $dataref) ne "ARRAY") {
        die "getData() called with a reference that was neither hash nor array.\n\n";
    }

    my %attr;
    # Flatten single-element arrays into a scalar (only if $dataref is a hash ref)?
    my $flatten = 0;
    if ((defined($attrs->{'flatten'})) && ($attrs->{'flatten'})) {
        $flatten = 1;
    }

    my $sth;
    
    if (defined($attrs->{'nocache'})) {
        $sth = $dbh->prepare($query,\%attr) ||
            die "Unable to prepare query '$query': " . $dbh->errstr . "\n\n";
    } else {
        $sth = $dbh->prepare_cached($query,\%attr) ||
            die "Unable to prepare query '$query': " . $dbh->errstr . "\n\n";
    }
	
    my $rv;
    
    if (defined($attrs->{'valref'})) {
        $rv=$sth->execute(@{$attrs->{'valref'}}) ||
            die	"Unable to execute query '$query': " . $dbh->errstr . "\n\n";
    } else {
        $rv=$sth->execute ||
            die	"Unable to execute query '$query': " . $dbh->errstr . "\n\n";
    }

    if (!$rv) {
        die "Database error:" . $sth->errstr;
    }

    my $rowcount = 0;
    
    while (my $hashref = $sth->fetchrow_hashref) {
        # Strip leading and trailing spaces
        foreach my $key (keys %{$hashref}) {
            if (defined($hashref->{$key})) {
                $hashref->{$key} =~ s/^\s+//g;
                $hashref->{$key} =~ s/\s+$//g;
            }
        }
        
        if ((ref $dataref) eq "ARRAY") {
            # It's an array, so push it onto the array
            push (@{$dataref}, $hashref);
        } else {
            if (!defined($hashref->{$attrs->{'hashkey'}})) {
                next;
            }
            
            if (!defined($dataref->{$hashref->{$attrs->{'hashkey'}}})) {
                if ($flatten) {
                    # Don't build an array for the hash - point it to a single hash ref.
                    $dataref->{$hashref->{$attrs->{hashkey}}} = $hashref;
                } else {
                    # Define the array ref for the hashkey if it doesn't exist
                    $dataref->{$hashref->{$attrs->{hashkey}}} = [];
                }
            }
            
            if (!$flatten) {
                push(@{$dataref->{$hashref->{$attrs->{hashkey}}}},$hashref);
            }
        }
        $rowcount++;
    }

    $sth->finish;
    
    if ($BENCH) {
        $endTime = [gettimeofday];
        my $elapsed = tv_interval $startTime, $endTime;
        my $logString = sprintf ("It took %f seconds to execute the following query and retrieve %d records: \n\t%s",
                                 $elapsed, $rowcount, $query);
        logToFile($logString);
    }

    # Return the number of records retrieved
    return $rowcount;
}


sub getDataOne {
	# Like getData, but returns a single hash reference instead of an array of them.
	# Used for queries that will return a single record, so you don't need to muck about
	# with extracting the element from an array
	my $query = shift;
	my $dbh = shift;

	# $valRef is a reference to an optional array of arguments, which will be passed to the execute() statement to fill placeholders
	# that may be in the query.
	my $valRef = shift;
	
	# Optional scalar ref to put an error string into.
	my $errorRef = shift;

	my $sth;
	my $rv;

	my $startTime;
	my $endTime;

	my %attr;
	$sth=$dbh->prepare_cached($query,\%attr);
	if (!$sth) {
		print STDERR "Error: ",$dbh->errstr;
		print STDERR "On query: $query\n";
		if (defined($errorRef)) {
			$$errorRef = "Error preparing query: " . $DBI::errstr;
			return undef;
		} else {
			exit(1);	
		}
	}
	
	eval {
		if (defined($valRef)) {
			$rv=$sth->execute(@{$valRef});
		} else {
			$rv=$sth->execute;
		}
	};
	
	if (!$rv) {
		if (defined($errorRef)) {
			$$errorRef = "Error executing query: " . $DBI::errstr;
			return undef;
		} else {
			exit(1);	
		}
	}

	my $row;
	while (my $thisrow = $sth->fetchrow_hashref) {
		foreach my $key (keys %{$thisrow}) {
			next if (!defined($thisrow->{$key}));
			$thisrow->{$key} =~ s/^\s+//g;
			$thisrow->{$key} =~ s/\s+$//g;
			if (defined($thisrow->{$key})) {
				# trim any stray ~s.
				$thisrow->{$key}=~ s/~//g;	
			} else {
				$thisrow->{$key} = "";
			}
		}
		$row = $thisrow;
	}
	$sth->finish;

	return $row;
}


sub getDataOnePH {
	# Like getData, but returns a single hash reference instead of an array of them.
	# Used for queries that will return a single record, so you don't need to muck about
	# with extracting the element from an array
	my $query = shift;
	my $dbh = shift;
	my $vals;

	my $sth;
	my $rv;

	my $startTime;
	my $endTime;

	if ($BENCH) {
		$startTime = [gettimeofday];
	}

	my %attr;
	$sth=$dbh->prepare_cached($query,\%attr);
	if ($sth->err) {
		print STDERR "Error: ",$dbh->errstr;
		print STDERR "On query: $query\n";
		exit(1);
	}
	$rv=$sth->execute(@{$vals});

	if (!$rv) {
		print "Error: ",$dbh->errstr;
		exit(1);
	}

	my $row;
	while (my $thisrow = $sth->fetchrow_hashref) {
		foreach my $key (keys %{$thisrow}) {
			next if (!defined($thisrow->{$key}));
			$thisrow->{$key} =~ s/^\s+//g;
			$thisrow->{$key} =~ s/\s+$//g;
			if (defined($thisrow->{$key})) {
				$thisrow->{$key}=~ s/~//g;	# trim any stray ~s.
			} else {
				$thisrow->{$key} = "";
			}
		}
		$row = $thisrow;
	}
	$sth->finish;

	if ($BENCH) {
		$endTime = [gettimeofday];
		my $elapsed = tv_interval $startTime, $endTime;
		my $logString = sprintf ("It took %f seconds to execute the following query and retrieve 1 record: \n\t%s",
								 $elapsed, $query);
		logToFile($logString);
	}

	return $row;
}


sub ldapConnect {
	my $config = shift;
	my $errorRef = shift;

	if (!defined $config) {
		$config = {
			'ldapHost' => $LDAPHOST,
			'ldapBindDn' => $LDAPBINDDN,
			'ldapBindPw' => $LDAPBINDPW
 		}
	}

	my $ldap = Net::LDAP->new($config->{'ldapHost'});
	
	if (!defined($ldap)) {
		print STDERR "There was an error connecting to LDAP!";
		if (defined($errorRef)) {
			$$errorRef = "Unable to connect to LDAP server '$config->{ldapHost}'";
		}
		return undef;
	}
	

	my $mesg = $ldap->bind($config->{'ldapBindDn'},
						   password => $config->{'ldapBindPw'});

    if ($mesg->code) {
        print STDERR "There was an error binding to LDAP!";
		if (defined($errorRef)) {
			$$errorRef = $mesg->error;
		}
		return undef;
    }

	return $ldap;
}


sub getEmailFromAD {
    my $user = shift;
    if (!defined($user)) {
        $user = getUser();
     
        # Still not defined?  Return
        if (!defined($user)) {
            return undef;
        }
    }

    my $ldapFilter = "(sAMAccountName=$user)";

	my @userInfo;

	ldapLookup(\@userInfo,$ldapFilter,undef,['mail']);
    
    if (scalar(@userInfo)) {
        return $userInfo[0]->{'mail'};
    } else {
        return undef;
    }
}


sub ldapLookup {
    # Returns a list of LDAP entries
    # All of the stuff necessary to authenticate to LDAP to do the query should
    # be here.
    # A reference to an array of hashes
    my $dataRef = shift;
    # The LDAP filter
    my $filter = shift;
    # Optionally take a Net::LDAP object as an argument, to allow re-use of the
    # handle
    my $ldap = shift;
    # This is a list of the fields to be returned in the LDAP query.
    my $fields = shift;
	my $ldapBase = shift;
	my $ldapScope = shift;

	if (!defined($ldapBase)) {
		$ldapBase = $LDAPBASE;
	}

    my $hadLDAP = 1;
    if (!defined($ldap)) {
		$ldap = ldapConnect() || return undef;
    }

    my @args=(filter => $filter,
              base	=>	$ldapBase,
              attrs	=>	$fields);
	if (defined($ldapScope)) {
		push (@args, scope => $ldapScope);
	}


    my $lookup = $ldap->search(@args);
    
    foreach my $entry ($lookup->entries) {
        my %entryHash;
        foreach my $field (@{$fields}) {
            $entryHash{$field} = $entry->get_value($field);
        }
        push (@{$dataRef}, \%entryHash);
    }
    
    # If we created a handle here, uncreate it.
    if (!$hadLDAP) {
        $ldap->unbind;
        undef $ldap;
    }
}


sub getDivsLDAP {
	my $divs = shift;
	my $user = shift;
	my $ldap = shift;

	# Allow a user name to be passed in.  If one isn't passed in, set to REMOTE_USER if it's set;
	# otherwise, return.
	if (!defined($user)) {
		if (defined(getUser())) {
			$user = getUser();
		} else {
			return;
		}
	}

	my $ldapFilter = "(sAMAccountName=$user)";

	my @userInfo;

	ldapLookup(\@userInfo,$ldapFilter,$ldap,['personalTitle']);

	if (!scalar(\@userInfo)) {
		return;
	}

	my $temp = $userInfo[0]->{'personalTitle'};
	# This will be in the format "Division AA" (if more than one division, "Division AA, BB")
	$temp =~ s/^Division\s+//gi;
	$temp =~ s/\s+//g;
	my @tempdivs = split(",",$temp);
	foreach my $div (sort @tempdivs) {
		# Push each distinct division onto the @{$divs} array.
		push(@{$divs}, $div);
	}
	# All done
	return;
}


sub doQuery {
	# Performs an ad hoc query; will accept a reference to an array of values which can be substituted into
	# a parameterized query, for using cached query statement handles
	my $query = shift;
	my $dbh = shift;
	# $valRef is a reference to an optional array of arguments, which will be passed to the execute() statement to fill placeholders
	# that may be in the query.
	my $valRef = shift;

	my %attr;
	my $sth=$dbh->prepare_cached($query,\%attr);
	if ($sth->err) {
		print STDERR "Error: ",$dbh->errstr;
		print STDERR "On query: $query\n";
		exit(1);
	}

	my $rv;

	if (defined($valRef)) {
		$rv=$sth->execute(@{$valRef});
	} else {
		$rv=$sth->execute;
	}

	if (!$rv) {
		print "Error: ",$dbh->errstr;
		exit(1);
	}

	# Return the number of affected rows
	return $sth->rows;
}

sub getCaseInfo {
	# Gets the last activity date for a particular case
	my $casenum = shift;
	my $dbh = shift;
	my $schema = $DEFAULT_SCHEMA;
	my $caseid = shift;

	my $hadDbh = 1;
	
	if ($casenum =~ /(50)(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)(\D\D\D\D)(\D\D)/) {
		# We have a Showcase UCN; convert to a CaseNumber
		$casenum = sprintf("%02d-%04d-%s-%06d-%s-%s", $1, $2, $3, $4, $5, $6);
	}
	
	
	my $query;
	if (!defined ($dbh)) {
		$hadDbh = 0;
		if ($casenum =~ /^50-/) {
			$dbh = dbConnect("showcase-prod");
		} 
	}
	
	if(!defined($caseid)){
		$caseid = getCaseID($casenum);
	}
	
	my $caseInfo = {};

	my @vals = ($caseid);

	my $lastActivity;

	$query = qq {
			select
				CaseNumber,
				DivisionID,
				CaseStyle,
				convert(date,FileDate,101) as FileDate,
				CaseType,
				CaseStatus,
                CourtType
			from
				$schema.vCase
			where
				CaseID = ?
		};
		$caseInfo = getDataOne($query,$dbh,\@vals);
		$caseInfo->{'CaseAge'} = getScCaseAge($caseInfo,$dbh);

		$query = qq {
			select
				CaseNumber,
				convert(date,max(EffectiveDate),101) as LastActivity
			from
				$schema.vDocket with(nolock)
			where
				CaseID = ?
			group by
				CaseNumber
		};
		$lastActivity = getDataOne($query,$dbh,\@vals);

	if (defined $lastActivity) {
		$caseInfo->{'LastActivity'} = $lastActivity->{'LastActivity'};
	}

	return $caseInfo;
}


sub getScCaseAge {
    # Calculate the age of a case.  If a case is reopened, then the age is
    # calculated from the date of the reopen.  If a case is closed, then the age
    # calculation will stop with the close date.
    my $caseref = shift;  # A hash ref containing case info
    my $dbh = shift;
    
    my $openDate = $caseref->{'FileDate'};
    # Default to today.  Overrides below.
    my $endDate = today();
    
    if ((defined($caseref->{'ReopenDate'})) && ($caseref->{'ReopenDate'} ne '')) {
	# A reopened case
	$openDate = $caseref->{'ReopenDate'};
	if ((defined($caseref->{'ReopenCloseDate'})) && ($caseref->{'ReopenCloseDate'} ne '')) {
	    # A reopened and then re-disposed case with a reopen disposition date
	    if (inArray(['Closed','Disposed'],$caseref->{'CaseStatus'})) {
		$endDate = $caseref->{'ReopenCloseDate'};
	    }
	}
    } elsif ((defined($caseref->{'DispositionDate'})) && ($caseref->{'DispositionDate'}) ne '') {
	# A case that wasn't reopened but has been disposed.
	$endDate = $caseref->{'DispositionDate'};
    }
    
    # We want the dates in the same format
    if ($endDate =~ /(\d\d\d\d)-(\d\d)-(\d\d)/) {
	$endDate = sprintf("%02d/%02d/%04d", $2, $3, $1);
    }
    
    if ($openDate =~ /(\d\d\d\d)-(\d\d)-(\d\d)/) {
	$openDate = sprintf("%02d/%02d/%04d", $2, $3, $1);
    }
    
    my ($mt,$dt,$yt) = split(/[-\/]/,$endDate);
    my ($mc,$dc,$yc) = split(/[-\/]/,$openDate);
    
    my $days;

    if (defined $yc) {
	$days = Delta_Days($yc,$mc,$dc,$yt,$mt,$dt);
    } else {
	$days = 0;
    }
    
    return $days;
}


sub findCaseType {
	# Return the type of case - limited to Criminal, Civil, Family and Probate - in either County or Circuit
	my $casenum = shift;

	# Strip any dashes and leading 50.
	$casenum =~ s/-//g;
	$casenum =~ s/^50//g;

	my $type = undef;
	if ($casenum =~ /^(\d{1,6})(\D\D)(\d{0,6})(.*)/) {
		$type = $2;
	}

	if (defined($type)) {
		if (inArray(\@CRIMTYPES, $type)) {
			return "CIRCUIT CRIMINAL";
		} elsif (inArray(\@CTYCRIMTYPES,$type)) {
			return "COUNTY CRIMINAL";
		} elsif (inArray(\@CTYCIVTYPES,$type)) {
			return "COUNTY CIVIL";
		} elsif (inArray(\@CIRCCIVTYPES, $type)) {
			return "CIRCUIT CIVIL";
		} elsif (inArray(\@PROTYPES, $type)) {
			return "PROBATE";
		} elsif (inArray(\@JUVTYPES, $type)) {
			return "JUVENILE";
		} elsif (inArray(\@FAMTYPES, $type)) {
			return "FAMILY";
		} elsif (inArray(\@TRAFTYPES, $type)) {
            return "CIVIL TRAFFIC";
        }
	}
	return "CIRCUIT CIVIL";
}


sub checkCaseAccess {
	my $caseref = shift;
	my $type = shift;
	my $ldap = shift;

	if ($type eq "SEALED") {
		if ((!defined($caseref->{'Sealed'})) ||
			(($caseref->{'Sealed'} eq 'N'))) {
			return 1;
		}
	}

	# If we're here, it's a sealed case.  So, find out if this user can see it.
	my $user = getUser();
	#$user = 'ABorman';
	#$user = 'pdblanc';
	#$user = 'tbarkdul';
	#$user = 'ralvarez';
	my @accessList;

	my $group = "CAD-ICMS-SEALED";
	if ($type eq "NAP") {
		$group = "CAD-ICMS-SEC";
	}

	my $filter = "(&(sAMAccountName=$user)(memberOf=CN=$group,OU=Services,OU=CAD,OU=Enterprise,DC=pbcgov,DC=org))";

	ldapLookup(\@accessList,$filter,$ldap,['sAMAccountName']);

	if (!scalar(@accessList)) {
		# User doesn't have access to the selected case type at all
		return 0;
	}

	if ($type eq "NAP") {
		# Currently, if you have access to these, you have access to all of
		# these
		return 1;
	}

	# Check to see if the user has access to THIS sealed case.
	my @divs;
	getDivsLDAP(\@divs,$user,$ldap);
	if (!scalar(@divs)) {
		# No divs set up
		return 0;
	}

	if (inArray(\@divs,'AllDivs')) {
		# User is an AllDivs user - access to all sealed
		return 1;
	}

	if (inArray(\@divs, $caseref->{'DivisionID'})) {
		# This case is in a division for which the user has access
		return 1;
	}

	if (inArray(\@FAMTYPES,$caseref->{'DivisionID'})) {
		# Family case.  Does the user have access to family sealed?
		if (inArray(\@divs,'AllFamily')) {
			return 1;
		}
	}

	if (inArray(\@JUVTYPES,$caseref->{'DivisionID'})) {
		# Juvenile case.  Does the user have access to juvenile sealed?
		if (inArray(\@divs,'AllJuvenile')) {
			return 1;
		}
	}

	if (inArray(\@PROTYPES,$caseref->{'DivisionID'})) {
		# Probate case.  Does the user have access to juvenile sealed?
		if (inArray(\@divs,'AllProbate')) {
			return 1;
		}
	}

	if (inArray(\@CIRCCIVTYPES,$caseref->{'DivisionID'})) {
		# Criminal case.  Does the user have access to juvenile sealed?
		if (inArray(\@divs,'AllCircCiv')) {
			return 1;
		}
	}

	if (inArray(\@CTYCIVTYPES,$caseref->{'DivisionID'})) {
		# Criminal case.  Does the user have access to juvenile sealed?
		if (inArray(\@divs,'AllCtyCiv')) {
			return 1;
		}
	}

	if (inArray(\@CRIMTYPES,$caseref->{'DivisionID'})) {
		# Criminal case.  Does the user have access to juvenile sealed?
		if (inArray(\@divs,'AllCrim')) {
			return 1;
		}
	}

	# This case isn't in one of the user's divisions
	return 0;
}


sub inGroup {
    my $user = shift;
    my $group = shift;
	my $ldap = shift;

    if ((!defined $user) || (!defined $group)) {
        return 0;
    }

	my $hadLdap = 1;
	if (!defined($ldap)) {
		$hadLdap = 0;
		$ldap = ldapConnect() || return undef;
    }

    # First, look up the DN of the user - we'll need it later
    my $ldapFilter = "(sAMAccountName=$user)";
    my $ldapBase = "ou=Users,ou=CAD,ou=Enterprise,dc=PBCGOV,dc=ORG";

    my @fields = ('distinguishedName');
    my @users;

    ldapLookup(\@users,$ldapFilter,$ldap,\@fields,$ldapBase);

    if (!scalar(@users)) {
        # Didn't find a user
		if (!$hadLdap) {
			$ldap->unbind;
			undef $ldap;
		}

        return 0;
    }

    my $userDn = $users[0]->{'distinguishedName'};

    # Now get the DN for the group
    $ldapFilter = "(sAMAccountName=$group)";
    $ldapBase = "ou=CAD,ou=Enterprise,dc=PBCGOV,dc=ORG";

    my @groups;
    ldapLookup(\@groups,$ldapFilter,$ldap,\@fields,$ldapBase);

    if (!scalar(@groups)) {
        # Didn't find a group
		if (!$hadLdap) {
			$ldap->unbind;
			undef $ldap;
		}
        return 0;
    }

    my $groupDn = $groups[0]->{'distinguishedName'};

    # Ok, now that we have the user and group DNs, we can use the
    # AD extension LDAP_MATCHING_RULE_IN_CHAIN (OID 1.2.840.113556.1.4.1941)
    # to see if the user is a member of the group.  This will check for
    # nested groups (e.g., if the user is a member of a group that is a member
    # of the target group, this will catch that)

    $ldapFilter = "(memberof:1.2.840.113556.1.4.1941:=$groupDn)";
    $ldapBase = $userDn;
    my @matches;
    ldapLookup(\@matches,$ldapFilter,$ldap,\@fields,$ldapBase,'base');

	if (!$hadLdap) {
		$ldap->unbind;
		undef $ldap;
	}

    if (!scalar(@matches)) {
        # Didn't find a group
        return 0;
    }

    return 1;
}


sub getDbSchema {
    # Gets the schema defined for the database in ICMS.xml.  If not defined,
    # defaults to "dbo".
    my $dbname = shift;
    
    my $config = XMLin($ENV{'DOCUMENT_ROOT'} . "/../conf/ICMS.xml");
    my $dbConf = $config->{'dbConfig'}->{$dbname};
    if (!defined($dbConf)) {
        die "No database config found for '$dbname'\n\n";
    }
    
    if (defined($dbConf->{'schema'})) {
        return $dbConf->{'schema'};
    }
    # No schema defined; return DBO.
    return "dbo";
}


sub getDivs {
    my $divRef = shift;
    my $dbh = shift;
    
    if (!defined($dbh)) {
        $dbh = dbConnect("judge-divs");
    }
    
    my $query = qq {
        select
            division_id as DivisionID,
            division_type as CourtType,
            '0' AS CustomQueue
        from
            divisions
        where
            show_icms_list = 1
        order by
            DivisionID
    };

    my $attrs = {};
    if (ref($divRef) eq "HASH") {
        $attrs = {hashkey => 'DivisionID', flatten => 1};
    }
    getData($divRef,$query,$dbh,$attrs);   
}

sub getCustomQueues {
    my $divRef = shift;
    my $dbh = shift;
    
    if (!defined($dbh)) {
        $dbh = dbConnect("judge-divs");
    }
    
    my $query = qq {
        select
            queue_name as DivisionID,
            queue_type as CourtType,
            '1' AS CustomQueue
        from
            custom_queues
        order by
            queue_name
    };

    my $attrs = {};
    if (ref($divRef) eq "HASH") {
        $attrs = {hashkey => 'DivisionID', flatten => 1};
    }
    getData($divRef,$query,$dbh,$attrs);   
}


sub getDivJudges {
    my $divRef = shift;
    my $dbh = shift;
    
    if (!defined($dbh)) {
        $dbh = dbConnect("judge-divs");
    }
    
    my $query = qq {
        select
            CONCAT (j.last_name, ', ', j.first_name) as JudgeName,
            d.division_type as DivisionType,
            d.division_id as DivisionID,
            c.courthouse_nickname as Location
        from
            judges j,
            judge_divisions jd,
            divisions d,
            courthouses c
        where
            jd.judge_id = j.judge_id
            and d.division_id = jd.division_id
            and d.show_icms_list = 1
            and d.courthouse_id = c.courthouse_id
        order by
            last_name		
    };
    
    getData($divRef, $query, $dbh, {hashkey => 'DivisionID', flatten => 1});
    
    return;
}

sub eFileInfo {
    my $user = shift;
    my $dbh = shift;
    
    if (!defined($dbh)) {
        $dbh = dbConnect("portal_info");
    }
    
    my $query = qq {
        select
            p.user_id,
            p.portal_id,
            p.password,
            p.bar_num,
			pt.portal_user_type_name
        from
            portal_users p left outer join portal_user_types pt on (p.portal_user_type_id=pt.portal_user_type_id)
        where
            user_id = ?
    };
    
    my $userInfo = getDataOne($query, $dbh, [$user]);
        
    if (!defined($userInfo)) {
        # User isn't a "first line" filer.  Is this user authotized to file
        # on behalf of someone else?
        $query = qq {
            select
				p.user_id,
				p.portal_id,
				p.password,
				p.bar_num,
				pt.portal_user_type_name
            from
                portal_users p left outer join portal_user_types pt on (p.portal_user_type_id=pt.portal_user_type_id)
            where
                user_id in (
                    select
                        portal_user
                    from
                        portal_alt_filers
                    where
                        user_id = ?
                        and active = 1
                )
        };
        my @temp;
        getData(\@temp, $query, $dbh, {valref => [$user]});
        if (scalar @temp) {
            $userInfo = $temp[0];
            $user = $userInfo->{'user_id'};
        } else {
            return undef;
        }
    }
    
    my $ldapFilter = "(sAMAccountName=$user)";
    
    my @userInfo;
    ldapLookup(\@userInfo,$ldapFilter,undef,['givenName','sn']);
    
    if (!scalar(@userInfo)) {
        return undef;
    }
    
    $userInfo->{'first_name'} = $userInfo[0]->{'givenName'};
    $userInfo->{'last_name'} = $userInfo[0]->{'sn'};
    

    
    return $userInfo;
}

sub getDivInfo {
	my $division = shift;
	
	my $dbh = dbConnect("judge-divs");
	
	my $query = qq {
		select
			court_type_id,
			portal_court_type,
			portal_namespace
		from
			portal_info.court_type_map c,
			judge_divs.divisions d
		where
			c.icms_court_type = d.division_type
			and d.division_id = ?
	};
	
	my $mapping = getDataOne($query, $dbh, [$division]);
	$dbh->disconnect;
	return $mapping;
}

sub getVrbCases {
    my $caseList = shift;
    my $dbh = shift;
    my $startDate = shift;
    my $endDate = shift;
    
    if (!defined($startDate)) {
        $startDate = ISO_date(today());
    }
    
    if (!defined($endDate)) {
        $endDate = $startDate;
    }
    
    # First get a listing of events for the specified date range
    my $query = qq {
        select
            event_id as EventID
        from
            events
        where
            DATE(start_date) >= ?
            and DATE(end_date) <= ?
    };
    my @events;
    getData(\@events, $query, $dbh, {valref => [$startDate, $endDate]});
    
    foreach my $event (@events) {
        my $query = qq {
            select
                case_num as CaseNumber
            from
                event_cases
            where
                event_id = ?
        };
        my @cases;
        getData(\@cases, $query, $dbh, {valref => [$event->{'EventID'}]});
        foreach my $case (@cases) {
            if (!inArray($caseList, $case->{'CaseNumber'}, 0)) {
                push(@{$caseList}, uc($case->{'CaseNumber'}));
            }
        }
    }
}

sub getVrbEventsByCase {
    my $eventRef = shift;
    my $casenum = shift;
    my $dbh = shift;
    
    return if (!defined($casenum));
    
    # Banner case numbers are stored as YYYY-TT-SSSSSS - make sure we look them up like that.
    my $queryCase = convertCaseNumber($casenum);
    
    my $shortCase = substr $queryCase, 3, 14;
    my $shortCaseNoSlash = $shortCase;
    $shortCaseNoSlash =~ s/-//g;
    
    my $noSlashCase = $queryCase;
    $noSlashCase =~ s/-//g;
    
    if (!defined($dbh)) {
        $dbh = dbConnect("vrb2");
    }
    
    my $query = qq {
        select
            e.event_id as EventID,
            DATE_FORMAT(e.start_date,'%m/%d/%Y') as EventDate,
            DATE_FORMAT(e.start_date,'%Y-%m-%d') as ISODate,
            DATE_FORMAT(e.start_date,'%h:%i %p') as CourtEventTime,
            e.judge_name as JudgeName,
            e.import_source_id as SourceID,
            i.import_source_name as ImportSource,
            e.event_name as CourtEventType,
            CASE 
            	WHEN s_type IS NOT NULL
            		THEN s_type
            	WHEN h_type IS NOT NULL
            		THEN h_type
            	ELSE et.event_type_code 
            END as EventCode,
            e.location as Location,
            CASE 
                WHEN e.canceled = '1' 
                	THEN 'Y'
                WHEN ec.canceled = '1'
                	THEN 'Y'
                ELSE 'N'
            END as Canceled,
            CASE 
                WHEN e.canceled = 1 
                	THEN 'canceled'
                WHEN ec.canceled = '1'
                	THEN 'canceled'
                WHEN e.updated = 1 
                	THEN 'updated'
            END as RowClass,
            "" as ShowVRBLink,
            CASE e.updated
                WHEN 1 THEN 'Y'
                ELSE 'N'
            END as Updated,
            update_info,
            cancel_reason,
            ec.event_notes as CourtEventNotes,
            CASE 
            	WHEN date_event_docketed IS NULL
            	THEN DATE_FORMAT(ec.date_scheduled, '%m/%d/%Y') 
            	ELSE DATE_FORMAT(ec.date_event_docketed, '%m/%d/%Y') 
            END as DocketDate,
            CASE 
				WHEN p1.m_title IS NOT NULL
					THEN p1.m_title
				WHEN p2.m_title IS NOT NULL AND p2.m_title = 'Other'
					THEN em.m_othertitle
				WHEN p2.m_title IS NOT NULL AND p2.m_title <> 'Other'
					THEN p2.m_title
				ELSE NULL
			END AS Motion,
			CASE
				WHEN ec.ols_conf_num IS NOT NULL
					THEN ec.ols_conf_num
				WHEN ec.med_conf_num IS NOT NULL
					THEN ec.med_conf_num
				ELSE
					""
			END AS ConfNum
        from
            event_cases ec
                left outer join events e on (e.event_id = ec.event_id)
                left outer join event_types et on (e.event_type_id = et.event_type_id)
                left outer join import_sources i on (e.import_source_id = i.import_source_id)
                LEFT OUTER JOIN event_motions em
					ON em.event_id = ec.event_id
					AND em.ols_conf_num = ec.ols_conf_num
				LEFT OUTER JOIN olscheduling.predefmotions p1
					ON p1.m_type = ec.motion
					AND p1.division = e.division
				LEFT OUTER JOIN olscheduling.predefmotions p2
					ON p2.m_type = em.m_type
					AND p2.division = e.division
				LEFT OUTER JOIN olscheduling.hearingtype h
					ON e.hearingtype_id = h.hearingtype_id	
				LEFT OUTER JOIN olscheduling.sessiontype s
					ON e.sessiontype_id = s.sessiontype_id
        where
            (
            	ec.case_num = ?
				OR ec.case_num = ?
				or ec.case_num = ?
				OR ec.case_num = ?
            )
        order by
            start_date desc
    };
    
    #$queryCase =~ s/-//gi;
    getData($eventRef, $query, $dbh, {valref => [$queryCase, $shortCase, $shortCaseNoSlash, $noSlashCase]});
}


sub lastInsert {
    # Returns the ID of the last inserted ID for this client session. Only works
    # with auto_increment tables.
    my $dbh = shift;
    
    my $query = qq {
        select
            LAST_INSERT_ID() as lastid
    };
    
    my $inserts = getDataOne($query, $dbh);
    return ($inserts->{lastid});
}

sub getDocketCodes {
    my $docketList = shift;
    my $caseinfo = shift;
    my $dbh = shift;
	my $filerType = shift;
    
	if (!defined($filerType)) {
		$filerType = 'judge';
	}
	
	my $fileCol = sprintf("%s_file", $filerType);
    
    my $col_name = $portalTypes{$courtTypes{$caseinfo->{'CourtType'}}};
		
    if (!defined($col_name)) {
        if ($caseinfo->{'CaseNumber'} =~ /DP|DR/) {
            $col_name = "dependency";
        } elsif ($caseinfo->{'CaseNumber'} =~ /CJ/) {
            $col_name = "delinquency";
        }
    }
    
    if (!defined($dbh)) {
        $dbh = dbConnect("portal_info");
    }
    
    my $query = qq {
		select
			docket_desc,
			$col_name as portal_desc,
			file_group
		from
			order_type_map
		where
			$col_name is not null
			and $fileCol = 1
		order by
			docket_desc
    };
    
	getData($docketList, $query, $dbh);
}

sub getLastRun {
    my $appname = shift;
    my $dbh = shift;
    my $current = shift;
    
    if(!defined($dbh)) {
        $dbh = dbConnect("icms");
    }
    
    if (!defined($current)) {
        $current = timeStamp();
    }
    
    my $query = qq {
        select
            last_run
        from
            last_run
        where
            app_name = ?
    };

    my $lastRun = getDataOne($query, $dbh, [$appname]);
    
    # Update the value
    $query = "
        replace into
            last_run (
                app_name,
                last_run
            )
        values (
            ?,?
        )
    ";
    doQuery($query, $dbh, [$appname, $current]);
    
    if (!defined($lastRun)) {
        # If there wasn't previously a value, use the start of today
        my $day = ISO_date(today());
        return (sprintf('%s 00:00:00', $day));
    } else {
        return $lastRun->{'last_run'};
    }
}

sub getInitDockets {
    my $caseType = shift;
    my $initDockets = shift;
    my $dbh = shift;
    
    if (!defined($dbh)) {
        $dbh = dbConnect("icms");
    }
    
    # First, check to see if the user has defined specific types for this case type
    my $query = qq {
        select
            docket_code,
            load_order
        from
            user_docket_codes
        where
            userid = ?
            and case_type = ?
        order by
            load_order asc
    };
    
    my $user = getUser();
    
    getData($initDockets, $query, $dbh, {valref => [$user, $caseType]});
    
    if (!scalar(@{$initDockets})) {
        # No user-specified values.  Look for defaults.
        $query = qq {
            select
                docket_code,
                load_order
            from
                default_dockets
            where
                case_type = ?
            order by
                load_order asc
        };
        getData($initDockets, $query, $dbh, {valref => [$caseType]});
    }
}


sub getWatchCases {
    my $caseref = shift; 
    my $dbh = shift;
    
    if (!defined($dbh)) {
        $dbh = dbConnect("icms");
    }
    
    my $query = qq {
        select
            casenum as CaseNumber,
            email as Email,
            icms_user
        from
            watchlist
    };
    
    if (ref($caseref) eq 'HASH') {
        getData($caseref, $query, $dbh, {hashkey => 'CaseNumber'});
    } else {
        getData($caseref, $query, $dbh);
    }
    
}


sub getWatchList {
    my $casenum = shift;
    my $user = shift;
    my $dbh = shift;
    
    if (!defined($dbh)) {
        $dbh = dbConnect("icms");
    }
    
    my $email = getEmailFromAD($user);
    
    if (!defined($email)) {
        return undef;
    }
    
    my $query = qq {
        select
            casenum,
            email,
            casestyle
        from
            watchlist
        where
            casenum = ?
            and email = ?
    };
    my $watch = getDataOne($query, $dbh, [$casenum, $email]);
    
    my $string;
    
    if (defined($watch)) {
        $string = qq{
            <span style="color: green">This case is on your watch list</span>
            <button title="Remove from Watch List" type="button" class="changeWatch printHide" data-url="/cgi-bin/case/watchlist/removeWatch.cgi" data-casenum="$casenum">Remove From Watch List</button>
        };
    } else {
        $string = qq {<button title="Add to Watch List" type="button" class="changeWatch printHide" data-url="/cgi-bin/case/watchlist/addWatch.cgi" 
            data-casenum="$casenum">Add To Watch List</button>};
    }
    return $string;
}

sub getQueueItems {
    my $ucn = shift;
    my $itemRef = shift;
    my $dbh  = shift;
    
    if (!defined($dbh)) {
        $dbh = dbConnect("icms");
    }
    
    my $searchCase = sanitizeCaseNumber($ucn);
    
    my @ucns = ("'$searchCase'");
    
    if ($searchCase !~ /^50/) {
        $searchCase =~ s/-//g;
        push(@ucns, "'$searchCase'");
        push(@ucns, "'50$searchCase'");
    }
    my $ucnString = join(",", @ucns);
    
    my $query = qq {
        select
            doc_id as DocID,
            title as Title,
            DATE_FORMAT(creation_date,'%m/%d/%Y') as CreationDate,
            DATE_FORMAT(due_date,'%m/%d/%Y') as DueDate,
            comments as Comments,
            color as Color,
            CASE doc_type
            	WHEN 'FORMORDER'
            	THEN 1
            	ELSE 0
            END as is_order,
            CASE doc_type
                WHEN 'MISCDOC' then 'notesAttach'
                ELSE 'docLink'
            END as doc_type,
            NULL as file,
            queue,
            creator,
            CASE
            	WHEN efile_submitted = 1 AND finished = 1 AND filing_status = 'Pending Filing'
            		THEN 'e-Filed (Pending Filing)'
            	WHEN efile_submitted = 1 AND finished = 1 AND filing_status = 'Filed'
            		THEN 'e-Filed (Filed)'
            	WHEN efile_submitted = 1 AND finished = 1 AND filing_status = 'Correction Queue'
            		THEN 'e-Filed (Correction Queue)'
            	WHEN finished = 1 AND comments LIKE 'REJECT%'
					THEN 'Rejected'
				WHEN (efile_submitted = 0 OR efile_submitted IS NULL) AND finished = 1
					THEN 'Finished'
				WHEN deleted = 1
					THEN 'Deleted'
				WHEN (efile_submitted = 1 AND finished = 1 AND portal_filing_id IS NULL)
					THEN 'e-Filed (Filed)'
				ELSE
					'Pending'
			END as current_status,
			CASE
				WHEN creation_date > DATE_SUB(CURDATE(), INTERVAL 180 DAY)
					THEN 1
				ELSE
					0
			END AS dateShow
        from
            workflow w2
        left outer join
        	portal_info.portal_filings pf
        	on w2.portal_filing_id = pf.filing_id
        where
            ucn in ($ucnString)
		UNION
		select 
			workflow_id as DocID,
			document_title as Title,
			DATE_FORMAT(creation_time,'%m/%d/%Y') as CreationDate,
            NULL as DueDate,
            NULL as Comments,
            NULL as Color,
            0 as is_order,
            'suppDoc' as doc_type,
            file,
            NULL as queue,
            NULL as creator,
            NULL as current_status,
            CASE
				WHEN creation_time > DATE_SUB(CURDATE(), INTERVAL 180 DAY)
					THEN 1
				ELSE
					0
			END AS dateShow
		from 
			olscheduling.supporting_documents sd
		inner join 
			workflow w
			on workflow_id = w.doc_id
			and ucn in ($ucnString)
		ORDER BY DocID
    };
    
    getData($itemRef, $query, $dbh);
    
    my $configXml = "$ENV{'DOCUMENT_ROOT'}/../conf/ICMS.xml";
	my $config = XMLin($configXml);
	
	#Prepend OLS URL to file paths
	foreach my $row (@{$itemRef}){
	
		if(inArray(['e-Filed (Filed)', 'Deleted', 'Finished', 'Rejected'], $row->{'current_status'})){	
			$row->{'style'} = "display:none";
		}
		elsif($row->{'dateShow'} eq "0"){
			$row->{'style'} = "display:none";
		}
		else{
			$row->{'style'} = "";
		}
	
		if($row->{'doc_type'} eq 'suppDoc'){
			if($row->{'file'} !~ /case\/uploads/){
				$row->{'file'} = $config->{'olsURL'} . "/" . $row->{'file'};
			}
		}
	}
}

sub getVrbEvents {
	# Used by the report generation scripts; since all events live in VRB, this is one-stop shopping.  Returns
	# a hash, keyed on the case number, of all cases with future-scheduled events.
	
	# If $past is setm it'll return the most recently past event that wasn't canceled.
    my $eventHash = shift;
	my $past = shift;
	my $caselist = shift;
	
	my $whereStr = "e.start_date >= CURDATE()";
	
	if ((defined($past)) && ($past != 0)) {
		$whereStr = "e.start_date < CURDATE()";
	}
	
	my $dbh = dbConnect("vrb2");
	
	if (defined($caselist)) {
		my $count = 0;
		my $perQuery = 1000;
		
		while ($count < scalar(@{$caselist})) {
			my @temp;
			getArrayPieces($caselist, $count, $perQuery, \@temp, 0);
			
			my @newTemp;
			foreach my $case (@temp) {
				if ($case =~ /(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)/) {
					$case = sprintf("%04d-%s-%06d", $1, $2, $3)
				}
				push(@newTemp, "'$case'");
			}
			
			my $inString = join(",", @newTemp);
            
            my @newTemp_vrb;
            foreach my $case (@temp) {
				if ($case =~ /(\d\d)-(\d\d\d\d)-(\D\D)-(\d\d\d\d\d\d)-(\D\D\D\D)-(\D\D)/) {
					$case = sprintf("%04d-%s-%06d", $2, $3, $4);
				}
				push(@newTemp_vrb, "'$case'");
			}
            
            my $inString_vrb = join(",", @newTemp_vrb);
			
			my $query = qq {
				select
					ec.case_num as CaseNumber,
					e.event_name as CourtEventType,
					DATE_FORMAT(e.start_date,'%m/%d/%Y') as CourtEventDate
				from
					event_cases ec left outer join events e on (ec.event_id=e.event_id)
				where
					$whereStr
					and e.canceled = 0
					and ( case_num in ($inString) OR case_num IN ($inString_vrb) )
				order by
					CourtEventDate desc
			};
            
			getData($eventHash, $query, $dbh, {hashkey => "CaseNumber", flatten => 1});
            
			$count += $perQuery;
		}
        
        foreach my $casenum (@{$caselist}) {
            my $caseCopy = $casenum;
            my $checkCase_vrb;
            if ($caseCopy =~ /(\d\d)-(\d\d\d\d)-(\D\D)-(\d\d\d\d\d\d)-(\D\D\D\D)-(\D\D)/) {
				$checkCase_vrb = sprintf("%04d-%s-%06d", $2, $3, $4);
			}
            
            if (defined($eventHash->{$checkCase_vrb})) {
                $eventHash->{$casenum} = $eventHash->{$checkCase_vrb};
                delete $eventHash->{$checkCase_vrb};
                $eventHash->{$casenum}->{'CaseNumber'} = $casenum;
            }
        }
	} else {
		my $query = qq {
			select
				ec.case_num as CaseNumber,
				e.event_name as CourtEventType,
				DATE_FORMAT(e.start_date,'%Y-%m-%d') as CourtEventDate
			from
				event_cases ec left outer join events e on (ec.event_id=e.event_id)
			where
				$whereStr
				-- e.start_date >= CURDATE()
				and e.canceled = 0
			order by
				CourtEventDate desc
		};
		getData($eventHash, $query, $dbh, {hashkey => "CaseNumber", flatten => 1});
	}
}

sub getCaseID {
	my $case = shift;
	
	my $db = "showcase-prod";
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

sub getSubscribedQueues {
	my $user = shift;
	my $dbh = shift;
	my $myqueues = shift;
		
	my $query = qq{
		select
            json
        from
            config
        where
            user = ?
            and module = 'config'
	};

	my $json = JSON->new->allow_nonref;
	my $row = getDataOne($query, $dbh, [$user]);
	my $chash;
	my $queues;
	if(defined($row)){
		$chash = $json->decode($row->{'json'});
		$queues = $chash->{'queues'};
	}
		
    if (defined($queues) && ($queues ne '')) {
    	foreach my $q (split(/,/, $queues)){
    		push(@{$myqueues}, $q);
    	}
    }
	
}		

sub getSharedQueues {
	my $user = shift;
	my $dbh = shift;
	my $sharedqueues = shift;

    my $query = qq {
        select
            json
        from
            config
        where
            user = ?
            and module='sharedqueues'
    };
    
    my $config = getDataOne($query, $dbh, [$user]);
    
   	if (defined($config->{'json'})) {
   		foreach my $q (split(/,/, $config->{'json'})){
    		push(@{$sharedqueues}, $q);
		}
    }
}

sub	getQueues {
	my $queueItems = shift;
	my $queueList = shift;
	my $dbh = shift;
	my $inString;
	
    my @temp;
    foreach my $queue (@{$queueList}) {
        push(@temp, "'$queue'");
    }
    $inString = join(',', @temp);
    my $query = qq {
        select
            doc_id,
            queue,
            ucn,
            title,
            color,
            creator,
            DATE_FORMAT(due_date,'%m/%d/%Y') as due_date,
            DATE_FORMAT(creation_date, '%m/%d/%Y') as creation_date,
            CASE
                WHEN due_date < CURDATE() then 'pastDue'
                WHEN due_date < (DATE_ADD(CURDATE(), INTERVAL 3 day)) then 'dueSoon'
                ELSE ''
            END as dueDateClass,
            CASE doc_type
                WHEN 'FORMORDER' then 'IGO'
                WHEN 'DVI' then 'DVI'
                WHEN 'MISCDOC' then 'Task'
                WHEN 'OLSORDER' then 'PropOrd'
        		WHEN 'WARRANT' then 'Warrant'
        		WHEN 'EMERGENCYMOTION' then 'EmerMot'
            END as doc_type,
            CASE
                WHEN signature_img is null then 'N'
                ELSE 'Y'
            END as esigned,
            CASE mailing_confirmed
                WHEN 0 then 'N'
                ELSE 'Y'
            END as mailed,
            CASE flagged
                WHEN 0 then 'N'
                ELSE 'Y'
            END as flagged,
            DATEDIFF(CURDATE(),DATE(creation_date)) as Age,
            CASE efile_completed
                WHEN 1 THEN 'Y'
                ELSE
                    CASE efile_submitted
                        WHEN 1 then 'S'
                        ELSE
                            CASE efile_queued
                                WHEN 1 then 'Q'
                                ELSE
                                    CASE efile_pended
                                        WHEN 1 then 'PQ'
                                        ELSE 'N'
                                    END
                            END
                    END
            END as efiled,
            comments,
            signed_filename
        from
            workflow
        where
            queue in ($inString)
        and
            finished = 0
        and
        	deleted = 0
    };

    getData($queueItems, $query, $dbh, {hashkey => 'queue'});
    
    my $count = 0;
    foreach my $queue (keys %{$queueItems}) {
        $count += scalar(@{$queueItems->{$queue}});
    }

    foreach my $queue ($queueList) {
        if (!defined($queueItems->{$queue})) {
            $queueItems->{$queue} = [];
        }
    }
    
    return $count;
}

sub getFilingAccounts {
	my $user = shift;
	my $dbh = shift;
	my %accounts;

    my $query = qq {
        select
        	CASE
        		WHEN portal_id = 'nchessman'
					THEN NULL
				WHEN portal_user_type_id = '1'
					THEN 'Judge'
				WHEN portal_user_type_id = '2'
					THEN 'Magistrate'
				WHEN portal_user_type_id = '5'
					THEN 'Traffic Hearing Officer'
				ELSE NULL
			END AS user_title,
            pu.user_id as portal_id,
            judge_first_name, 
            judge_middle_name, 
            judge_last_name, 
            judge_suffix,
            default_account
        from
            portal_alt_filers pf
        inner join
        	portal_users pu
        on 
        	pf.portal_user = pu.user_id
        where
            pf.user_id = ?
        and 
        	active = 1
        union
		select 		
			CASE
				WHEN portal_id = 'nchessman'
					THEN NULL
				WHEN portal_user_type_id = '1'
					THEN 'Judge'
				WHEN portal_user_type_id = '1'
					THEN 'Magistrate'
				WHEN portal_user_type_id = '5'
					THEN 'Traffic Hearing Officer'
				ELSE NULL
			END AS user_title,
			user_id as portal_id,
            judge_first_name, 
            judge_middle_name, 
            judge_last_name, 
            judge_suffix,
            1 AS default_account
        from
            portal_users
        where
            user_id = ?
    };
    
    getData(\%accounts, $query, $dbh, {hashkey => 'portal_id', valref => [$user, $user]});
    return \%accounts;
}

sub getDocData{
	my $doc_id = shift;
	my $dbh = dbConnect("icms");
	
	my $query = qq {
				SELECT 
					title,
					doc_id,
					data,
					doc_type,
					ucn,
					form_id,
					signed_filename AS pdf_file,
					signature_img,
					queue,
					portal_filing_id
				FROM
					workflow
				WHERE
					doc_id = ?
	};
	
	my $row;
	$row = getDataOne($query, $dbh, [$doc_id]);
	
	my $docInfo = {};
	if(defined($row)){
		if(defined($row->{'data'})){
			my $data = decode_json($row->{'data'});
				
			if(defined($data->{'form_data'})){
				$docInfo->{'formData'} = $data->{'form_data'};
			}
			if(defined($data->{'cc_list'})){
				$docInfo->{'cc_list'} = $data->{'cc_list'};
			}
			if(defined($data->{'case_caption'})){
				$docInfo->{'case_caption'} = $data->{'case_caption'};
			}
			if(defined($data->{'signature_html'})){
				$docInfo->{'signature_html'} = $data->{'signature_html'};
			}
			if(defined($data->{'order_html'})){
				$docInfo->{'order_html'} = $data->{'order_html'};
				$docInfo->{'form_data'} = $data->{'form_data'};
			}
		}
		
		if(defined($row->{'doc_id'})){
			$docInfo->{'docid'} = $row->{'doc_id'};
		}
		if(defined($row->{'ucn'})){
			$docInfo->{'ucn'} = $row->{'ucn'};
		}
		if(defined($row->{'form_id'})){
			$docInfo->{'form_id'} = $row->{'form_id'};
		}
		if(defined($row->{'doc_type'})){
			if($row->{'doc_type'} == "FORMORDER"){
				$docInfo->{'isOrder'} = 1;
			}
			else{
				$docInfo->{'isOrder'} = 0;
			}
		}
		if(defined($row->{'pdf_file'})){
			$docInfo->{'pdf_file'} = "/tmp/" . $row->{'pdf_file'};
		}
		if(defined($row->{'signature_img'})){
			$docInfo->{'signature_img'} = $row->{'signature_img'};
		}
		if(defined($row->{'title'})){
			$docInfo->{'title'} = $row->{'title'};
		}
		if(defined($row->{'queue'})){
			$docInfo->{'queue'} = $row->{'queue'};
		}
		if(defined($row->{'portal_filing_id'})){
			$docInfo->{'filing_id'} = $row->{'portal_filing_id'};
		}
	}	
	return $docInfo;
}

sub getEmergencyQueues{
	my $dbh = dbConnect("judge-divs");
	
	my $query = qq {
		SELECT queue_name
		FROM custom_queues
		WHERE queue_type LIKE '%Emergency%'
	};
	
	
	my @emergencyQueues;
	getData(\@emergencyQueues, $query, $dbh);
	
	return @emergencyQueues;
}

1;
