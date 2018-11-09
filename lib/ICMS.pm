#!/usr/bin/perl
#
#  ICMS.pm -- shared subroutines for ICMS
#


package ICMS;
require Exporter;

use DBI qw(:sql_types);
use Date::Calc qw(:all Month_to_Text);
use Date::Manip;
use File::Basename;
use Time::Piece;
use Time::Seconds;
use File::Temp;
use File::Path qw (make_path);
use POSIX qw(strftime);
use Template;
use Carp qw(cluck);
use DB_Functions qw (
	dbConnect
	getData
);
use Common qw (
	dumpVar
);

#use Exporter();
our @ISA=qw(Exporter);
our @EXPORT=qw (
    dbconnect dbdisconnect dbtables dbsetlong sqlin sqldel sqlhash sqllookup
    sqllist sqllistone sqltables ping mashdate sortlist writehash readhash
    writetable readtable compdate monthname month2num buildarchive ncicdesc
    ask getline getsth prettyage prettydate prettytime time_24_to_ampm
    time_24_to_ampm_list time_ampm_to_24 decimaltime  prettyfaccciv
    prettyfacccrim urlencode urldecode htmllist
    outrow outrowh outtable outpair  getcount dependdesc getage getageinyears
    getdiff moddate pct clean trim fixname fixyear fixdate fixdatelist
    fixtimelist $TODAY $YEAR $MONTH $DAY $MTEXT $M2 $D2 $EVTDATE $NOW $HOUR
    $MINUTE $SECOND $TIMESTAMP @DIVNAME %CIVILDIVNAME %COUNTY $PIVOTYEAR
    $UTILSFILEPATH $ROOTPATH $SQLPROFILE @DATABASES %DBXREF %CODES %ACCESS @OLSCHEDULING $CIRCUIT
    timestamp loadconffile dumpconffile onlinediv reportheader reportfooter tabletitle
    tableline tableline2 tableblank tabletotal groupcheck $INACTIVECODES $WARRANTCODES
    @CRIMCODES
    @SCCODES
    $SQLEVTDATE
    $DB
    $LIMIT
    $PHOTOLIMIT
    $TMPDIR
    sqlHashArray
    sqlHashHash
    %formats
    %reportHeaders
    %fieldOrder
    $htmlTemp
    writeHashFromArray
    writeHashFromHash
    readHashArray
    readHashHash
    sortHashArray
    @ORDERS
    @JUDGMENTS
    @MOTIONS
    @NOTICES
    @PETITIONS
    @INACTIVECODES
    @VOPS
    @ANSWERS
    sqlHashOne
    sqlArrayHash
    $MAX_IMG_SIZE
    $templateDir
    $SKIPPBSO
);

BEGIN {
    our $DEBUG = 0;
}

our $SKIPPBSO = 0;

our $EVTDATE;
our $SQLEVTDATE;
our $M2;
our $D2;

our $DB="";			   # currently open database, set in dbconnect
our $PIVOTYEAR=30;		   # pivot year for any YY->YYYY conversions
our $SQLPROFILE=0;		   # set to 1 to output SQL query time data

my $CLINE="#EEFFCC";	     # both used by tabletitle,line,blank subs
my $TLINE="#D0FFD0";	     #

our $CIRCUIT=15;			# change as appropriate

# This is the list of "CLOSED" types - if this list changes, also update the inactive.html file to match!
our $INACTIVECODES="('AS','CFDS','CLSD','DA','DADR','DAM','DAO','DAS','DB','DBDR','DBM','DBO','DBS','DD','DE','DJ','DM','DO','DY','GC','JC','JDF','JDIV','JNF','JPD','NJ','OPROB','OTCD','OTDF','PCA','PDAJ','PDC','PDDP','PDU','RD','TC','XX','ZVDS','PDAD','PDCF','PDCFN','PDSH','PDTPR')";

# Build @INACTIVECODES from $INACTIVECODES - I like working with arrays better
# than strings (more slexible), but there are a lot of pieces of code that
# use $INACTIVECODES.  Do this until they can all be fixed.
my $string = $INACTIVECODES;
# Strip the parens and quotes
$string =~ s/[\(\)\']//g;
# And split it up
our @INACTIVECODES = split(/,/, $string);

our $WARRANTCODES="('ALBW', 'ALCP', 'ALWT', 'ARWT', 'BWIS', 'CFWT', 'CISS', 'CPWT', 'DFCW', 'DFW', 'WTIS', 'JPU')";

our @CRIMCODES=(
    "'CF'",
    "'MM'",
    "'MO'",
    "'CO'",
    "'CT'",
    "'IN'",
    "'TR'"
);

# Court codes that are currently looked up from Showcase and therefore
# not in Banner.  For this phase, it's the same as @CRIMCODES, with the addition
# of TR (since TR doesn't get included in criminal reports)
our @SCCODES = (@CRIMCODES);


# Orders & motions types, to be used for highlighting
our @ORDERS = (
    'AAAB','ADNG','AGOR','AO','AOPC','AOPD','AORD','AOTC','CEWO','COIS','CRO','CSPO','DCAO',
    'DVDIS','DVEIS','DVNIS','DVOIS','DVSIS','EOPU','FORD','IDO','IDOD','IDOI','IWO',
    'JRPUP','MHCIS','MHPIS','MHPRT','MNCO','NFRCO','OAAA','OAAF','OAC1','OAC2',
    'OAC3','OAC4','OAC5','OACC','OACL','OACN','OACP','OADP','OADT','OAEC',
    'OAEXP','OAFC','OAFCP','OAFN','OAGL','OAGP','OAGR','OAII','OAIS','OAJAP',
    'OAMA','OAP','OAPD','OAPR','OARR','OASC','OAWP','OCCR','OCFP','OCMT','OCS',
    'OCNT','OCON','OCPU','OCS','ODAP','ODAR','ODCC','ODCE','ODCH','ODCL',
    'ODCN','ODCP','ODDP','ODET','ODFN','ODFT','ODGL','ODIC','ODIR','ODIS',
    'ODMC','ODMO','ODNC','ODPC','ODPCA','ODPE','ODPR','ODPW','ODS','ODSP','ODST',
    'ODTP','ODTPR','ODTS','ODVP','OEIJ','OEST','OETG','OFCI','OFCP','OFDC',
    'OFDCA','OGAL','OGER','OGNC','OGPC','OGPCA','OGPN','OGPP','OGPR','OGTP','OGMC',
    'OGW','OHCD','OIAC','OILR','OINC','OJOA','OLPR','OMCD','OMOD','ONG','ONVA','OOFA',
    'OOI','OOP','OPCH','OPD','OPE','OPROB','ORA','ORAC','ORAD','ORAG','ORAP','ORAT',
    'ORCM','ORCR','ORCS','ORD','ORDA','ORDCC','ORDD','ORDEC','ORDG','ORDH','ORDI','ORDIS',
    'ORDP','OREP','OREST','ORET','ORETA','OREV','OREVO','ORGA','ORGCC','ORGCF',
    'ORGM','ORHS','ORIA','ORIC','ORIE','ORIN','ORIP','ORIT','ORME','ORNOH',
    'ORRA','ORRC','ORRGM','ORSA','ORSD','ORSG','ORSH','ORSL','ORSP','ORST','ORTR',
    'ORWF','ORWV','OSC','OSCL','OSFH','OSH','OSHC','OSJT','OSMH','OSNT','OSR','OSSH',
    'OTCC','OTCD','OTD','OTDF','OTDP','OTFCD','OTFD','OTFR','OTIV','OTJ',
    'OTJF','OTJS','OTJSF','OTJST','OTJU','OTP','OTRE','OTS','OTSC','OTSF',
    'OTSU','OTT','OUFC','OVAC','OVOL','OWAF','OWCN','OWDP','OWFN','OWIF',
    'PAO','PEDD','PUEO','PUISG','PUISS','PWOT','QDRO','RFPU','RNCO',
    'SORC','SORD','SOSC','STOR','UFCL','UFCT','VFJD','WETC','WODV','WONC','WOPC','WOSP','WBAT','STORD',
    'STORI'
);


our @MOTIONS = (
    'AMWF','CORS','DAPP','EMOT','FURL','GCMN','JMNOH','LIMI','MACP','MCC',
    'MCIJ','MCMP','MCMT','MCNT','MCON','MCPT','MCSNT','MDCH','MDFT','MDIS',
    'MEXT','MFC','MFD','MFFJ','MFP','MFSJ','MFWR','MITE','MITS','MJCRD','MMP',
    'MMPRO','MMSNT','MNJD','MNOH','MOMD','MONIS','MONRT','MOT','MOTD','MOTDC',
    'MOTR','MRAD','MREH','MRH','MRSC','MSAJ','MSBD','MSID','MSJT','MSLT',
    'MSNJ','MSOP','MSTR','MTJR','MTP','MTRC','MTS','MTSJ','MTSV','MTWD',
    'OPCB','POST','REDS','RMAN','SCOU','VENU','VMTN','ZPOST','MFORD',
    'MFPO','MORD','MWPU','MCONCIV'
);

our @JUDGMENTS = (
    'DFFJ','EOFJ','FJCO','FJDM','FJFC','FJPA','FJUD','GCMN','GUIL','JUD',
    'STOJ','VER','ZJMNT'
);

our @PETITIONS = (
    'PEMO','PET','PSUP', 'PECN', 'PEPA', 'PECU', 'PETI','PEAN','PEAJ','PFO'
);

our @NOTICES = (
    'ANOA','ANTD','ANTM','ASWNC','CNNC','CNOH','COMP','CRNOH','DFD','DLFN','DSNA','FORF',
    'GANDL','JNOD','JNSI','MHIIS',
    'NADD','NAFD','NAGL','NARR','NAST','NCAN','NCCS','NCHG','NCOM','NCPA','NDCA',
    'NDDR','NDIS','NDNE','NDRC','NDVD','NEXP','NFRD','NFSF','NHIS','NHRT','NIN','NINQ',
    'NITP','NJRH','NLPR','NNAC','NNJT','NOA','NOAC','NOAD','NOAP','NOC','NOCA','NOCO',
    'NOD','NODP','NOED','NOF','NOFC','NOFH','NOFI','NOH','NOHP','NOI','NOIC','NOIDP','NOJA',
    'NOJT','NOMA','NOME','NONA','NONC','NOPR','NORC','NORD','NORE','NORIS','NORO','NOS',
    'NOSA','NOSC','NOT','NOTCF','NOTD','NOTIS','NOTR','NOUN','NOVD','NPAY','NPNP','NREI',
    'NRFC','NSDL','NSFE','NTA','NTCR','NTCV','NTDC','NTE','NTJN','NTP','NTRA','NTSAO',
    'NTSF','NTTR','NUSF','PBUN','PNAD','PNCR','PSUN','RFJN','RNOH',
    'RNOT','RNTD','SDIV','SNTD','UDIV','UNOA','UNTCR','VOSWN','WNAD','WNOT','ZNOA','ZNOAD'
);

our @VOPS = (
    'APVOP','AVOP','AVOPN','VOPCC','VOPR','VOPRO','VOPWN','VOPWS'
);

our @ANSWERS = (
	'ANS','ANAD','ANCP','ANSAR'
);

# Limit the number of cases to be shown for the specified search criteria
our $LIMIT=15000;

# Limit the number of photos to be shown
our $PHOTOLIMIT = 200;

# Temporary directory for file storage
our $TMPDIR = "/tmp";

# HTML temp directory
our $htmlTemp = "/var/www/html/tmp";

# Hash of format specifiers for case listings
our %formats = (
    "singlecasewithcharges" => "W~L~I~D~D~A~S~A~D~A~A~D",
    "multicasewithcharges" => "W~I~C~D~A~A~L~D~D~A~S~A~D~A~A~D",
    "singlecasenocharges" => "W~L~I~D~D~A~S~A",
    "multicasenocharges" => "W~I~C~D~A~A~L~D~D~A~S~A"
);

# Headers for the output reports for case listings.  These keys need to be
# exactly the same as the keys for %formats, above.
our %reportHeaders = (
    "singlecasewithcharges" => "~Case #~Description~File ".
    "Date~Last Activity~Division~Type~Status~Charge Date~".
    "Citation~Charge Description~Charge Dispostion Date",
    
    "multicasewithcharges" =>  "~Name~Photo~DOB~Age~Party ".
    "Type~Case #~File Date~Last Activity~Division~".
    "Type~Status~Charge Date~Citation~Charge ".
    "Description~Charge Dispostion Date",

    "singlecasenocharges" => "~Case #~Description~File ".
    "Date~Last Activity~Division~Type~Status",

    "multicasenocharges" => "Open<br/>Warrant?~Name~Photo~DOB~Age~Party ".
    "Type~Case #~File Date~Last Activity~Division~Type~Status"
);


our %fieldOrder = (
  "multicasewithcharges" => [
    "OpenWarrants",
    "Name",
    "Photo",
    "DOB",
    "AGE",
    "PartyTypeDescription",
    "CaseNumber",
    "FileDate",
    "LACTIVITY",
    "DivisionID",
    "CaseType",
    "CaseStatus",
    "ChargeDate",
    "Citation",
    "ChargeDescription",
    "ChargeDisposition"
  ],
  "multicasenocharges" => [
    "OpenWarrants",
    "Name",
    "Photo",
    "DOB",
    "AGE",
    "PartyTypeDescription",
    "CaseNumber",
    "FileDate",
    "LACTIVITY",
    "DivisionID",
    "CaseType",
    "CaseStatus"
  ],
  "singlecasewithcharges" => [
    "OpenWarrants",
    "CaseNumber",
    "LastName",
    "FileDate",
    "LACTIVITY",
    "DivisionID",
    "CaseType",
    "CaseStatus",
    "ChargeDate",
    "Citation",
    "ChargeDescription",
    "ChargeDisposition"
  ],
  "singlecasenocharges" => [
    "OpenWarrants",
    "CaseNumber",
    "LastName",
    "FileDate",
    "LACTIVITY",
    "DivisionID",
    "CaseType",
    "CaseStatus"
  ],
  "citation" => [
    "CitationNumber",
    "CaseNumber",
    "FullName",
    "FileDate",
    "LastActivity",
    "DivisionID",
    "CourtType",
    "CaseStatus"
  ]
);


our $MAX_IMG_SIZE = 4096000;

# The directory to store templates for use with the Perl Template Toolkit
our $templateDir = "/usr/local/icms/templates";

sub fatal {
  my($mess)=@_;
  print "Content-Type: text/html; charset=ISO-8859-1\n";
  print $mess,"\n";
  exit;
}
#
# dumpconffile shows what loadconffile loaded.
#
sub dumpconffile {
  print "%ACCESS:\n";
  foreach (sort keys %ACCESS) {
    print "   $_: $ACCESS{$_}\n";
  }
  print "\@OLSCHEDULING:\n";
  foreach (@OLSCHEDULING) {
    print "   $_\n";
  }
  print "%CODES:\n";
  foreach (sort keys %CODES) {
    print "   $_: $CODES{$_}\n";
  }
  print "\@DATABASES:\n";
  foreach (@DATABASES) {
    print "   $_\n";
  }
  print "%DBXREF:\n";
  foreach (sort keys %DBXREF) {
    print "   $_: $DBXREF{$_}\n";
  }
}

# see if this division is an online scheduling division
sub onlinediv {
  if (scalar @OLSCHEDULING > 0) {
    my($thisdiv)=@_;
    foreach my $d (@OLSCHEDULING) {
      if (uc $d eq uc $thisdiv) {
	return "true";
      }
    }
  }
  return "false";
}

#
# Check if user belongs to particular group by reading ldapgroups.txt.
# Almost the same as the one in AuthSarasota.
#
sub groupcheck {
	my($user,$group)=@_;
	my $auth_flag = 0;
	if ($group ne "" && $user ne "") {
		if (!open(INFILE,"/var/tmp/ldapgroups.txt")) {
			return 0;
		}

		while (<INFILE>) {
			chomp;
			if (/^$group~/) {
				if (/;$user;/i) {
					$auth_flag++; last;
				}
			}
		}

		close(INFILE);
	}
	if ($auth_flag == 0) {
		return 0;
	}
	return 1;
}



#
#  dbconnect makes a connection to the database passed it
#            is uses the %ACCESS hash to get connection information
#
sub dbconnect {
  our $DB=shift;

  if ($ACCESS{$DB}) {
    ($dbname,$user,$pass,$dbhost,$dbpath)=split ';',$ACCESS{$DB};
  } else {
    die "dbconnect: Unknown database '$DB'\n";
  }
  if (!defined $dbpath) {
    $dbpath="";
  }

  if (defined $dbhost) {
    $ENV{INFORMIXSERVER}=$dbhost;
    $ENV{DBPATH}=$dbpath;
  }

  if (defined $optdb) {
    $i=index($dbname,"\@");
    $dbname=$optdb.substr($dbname,$i,255);
  }

  if ($dbname=~/:/) {		# db name include :, type specified
    $dbh=DBI->connect("dbi:$dbname",$user,$pass);
  } elsif ($dbhost eq "mssql") {
    # the whole connection string must be in here.
    $dbname=~s/\|/;/g;
    $dbh=DBI->connect("dbi:Sybase:$dbname",$user,$pass);
    if (!defined $dbh) {
      # connect failed, return a 0 value to caller to handle
      return 0;
    } elsif ($dbpath ne "") {
      # select a database
      ask("use $dbpath");
    }
    $dbh->do("set textsize 500000");
  } elsif ($dbhost eq "oracle") {
    $dbh=DBI->connect("dbi:Oracle:$dbname",$user,$pass) ||
      fatal("Couldn't connect to Oracle DB");
    $dbh->{LongReadLen}=500000;
    if (!$dbh) {
      return 0;
    }			  # connect failed, return a 0 value to caller
    ask("alter session set nls_date_format='MM/DD/YYYY'");
  } elsif ($dbhost eq "postgres") {
    $realhost="";
    if ($dbname=~/@/) {
      ($dbname,$realhost)=split '@',$dbname;
    }

    if ($realhost ne "") {
      $realhost=";host=$realhost;port=5432";
    }

    $dbh=DBI->connect("dbi:Pg:dbname=$dbname$realhost",$user,$pass);

    if (!defined $dbh) {
      return 0;
    }

    ask("set datestyle to 'SQL'"); # make Postgres dates look 'normal'
  } elsif ($DB eq "ala-mug") {
    $dbh=DBI->connect("dbi:Advantage:DataDirectory=/mnt/smartcop/".
		      "SMARTCOP.DAT/ops/mni","","");
    if (!defined $dbh) {
      print "dbconnect: failed trying to connect to $dbname.  Server ".
	"is $dbhost, Path is $dbpath\n";
    }
  } else {
    $dbh=DBI->connect("dbi:Informix:$dbname",$user,$pass);
    if (!defined $dbh) {
      print "dbconnect: failed trying to connect to $dbname, server ".
	"is $dbhost, path is $dbpath\n";
    }
  }
  return $dbh;
}


sub dbdisconnect {
  my $dbhandle  = shift;

  if (!defined($dbhandle)) {
    # Since making $dbh not global would break so many calls, allow $dbhandle to
    # be passed as null, causing it to use $dbh; other DBI-type DB handles (for
    # other databases) can also be passed, however
    $dbhandle = $dbh;
  }

  if (defined $sth) {
    $sth->finish;
  }
  $dbhandle->disconnect;
}

sub dbtables {
  return $dbh->tables;
}

sub dbsetlong {
  $dbh->{LongReadLen}=$_[0];
  print "LongReadLen now ",$dbh->{LongReadLen},"\n";
  $dbh->{'LongTruncOK'}='true';
  print "LongTruncOK now ",$dbh->{LongTruncOK},"\n";
}



#
#  sqlhash is a new version of gethashtable that trims and
#  de-nullifies input from SQL
# usage: sqlhash(query,N);


sub sqlhash {
	my $qry = shift;
	my $keysize = shift;
	my $dbhandle = shift;

	if ($DEBUG) {
		logQuery($qry,"FILE" . __FILE__ . ", LINE " . __LINE__ . "\n\n");
	}

	my %loclist;

	if (!defined($dbhandle)) {
		$dbhandle = $dbh;
	}

	my $time0;
	if ($SQLPROFILE) {
		print STDERR "sqlhash: $qry\n";
		$time0=time();
	}
	if (!defined $keysize || $keysize<1) {
		$keysize=1;
	}

	my $sth=$dbhandle->prepare($qry);
	if (!$sth) {
		print "Error: ",$dbhandle->errstr;
		print STDERR "On query: $qry\n";
		exit(1);
	}
	my $rv=$sth->execute;
	if (!$rv) {
		print "Error: ",$dbhandle->errstr;
		print STDERR "On query: $qry\n";
		exit(1);
	}
	while (@ary=$sth->fetchrow_array) {
		for (my $i=0;$i<@ary;$i++) {
			if (!defined $ary[$i]) {
				$ary[$i]="";
			}
			$ary[$i]=trim($ary[$i]);
			$ary[$i]=~s/\~//g;	# trim any stray ~s.
		}
		$rec=join '~',@ary;
		$key="";
		for (my $i=0;$i<$keysize;$i++) {
			$key.=$ary[$i];
			if ($i!=$keysize-1) {
				$key.=';';
			}
		}
		$loclist{$key}=$rec;
	}
	if ($SQLPROFILE) {
		print STDERR scalar keys %loclist," Records found\n";
		print STDERR "Query took ",time()-$time0," Seconds\n";
	}
	return %loclist;
}


#
#  sqllookup is like sqlhash, but the key isn't included in the
#            value.
# usage: sqlhash(query,N);


sub sqllookup {
	local($qry,$sth,$rv,%loclist,$i);

	my $qry = shift;
	my $dbconn = shift;

	if (!defined($dbconn)) {
		$dbconn = $dbh;
	}

  	if ($DEBUG) {
		logQuery($qry,"FILE" . __FILE__ . ", LINE " . __LINE__ . "\n\n");
	}

	$keysize=$_[1];
	my $time0;

	if ($SQLPROFILE) {
		print STDERR "sqlhash: $qry\n";
		$time0=time();
	}

	if (!defined $keysize || $keysize<1) {
		$keysize=1;
	}

	$sth=$dbconn->prepare($qry);
	if (!$sth) {
		print "Error: ",$dbconn->errstr;
		print STDERR "On query: $qry\n";
		exit(1);
	}

	$rv=$sth->execute;
	if (!$rv) {
		print "Error: ",$dbconn->errstr;
		print STDERR "On query: $qry\n";
		exit(1);
	}

	while (@ary=$sth->fetchrow_array) {
		for ($i=0;$i<@ary;$i++) {
			if (!defined $ary[$i]) {
				$ary[$i]="";
			}
			$ary[$i]=trim($ary[$i]);
			$ary[$i]=~s/\~//g;	# trim any stray ~s.
		}

		$rec=join '~',@ary[$keysize..@ary-1];
		$key="";
		for ($i=0;$i<$keysize;$i++) {
			$key.=$ary[$i];
			if ($i!=$keysize-1) {
				$key.=';';
			}
		}
		$loclist{$key}=$rec;
	}

	if ($SQLPROFILE) {
		print STDERR scalar keys %loclist," Records found\n";
		print STDERR "Query took ",time()-$time0," Seconds\n";
	}
	return %loclist;
}


sub sqldel {
  local($qry,$sth,$rv);
  $qry=$_[0];

  	if ($DEBUG) {
		logQuery($qry,"FILE" . __FILE__ . ", LINE " . __LINE__ . "\n\n");
	}

  my $time0;
  if ($SQLPROFILE) {
    print STDERR "sqldel: $qry\n";
    $time0=time();
  }
  $sth=$dbh->prepare($qry);
  if (!$sth) {
    print "Error: ",$dbh->errstr;
    print STDERR "On query: $qry\n";
    exit(1);
  }
  $rv=$sth->execute;
  if (!$rv) {
    print "Error: ",$dbh->errstr;
    print STDERR "On query: $qry\n";
    exit(1);
  }
  $sth->finish();
  if (!($dbh->{'AutoCommit'})) {
    $dbh->commit;
  }
  if (!$dbh) {
    print "dbdelete: failed trying to commit delete to icms flags\n";
    print STDERR "On query: $qry\n";
    exit(1);
  }
}				# end sqldel

sub sqlin {
  local($qry,$sth,$rv);
  $qry=$_[0];

  if ($DEBUG) {
	logQuery($qry,"FILE" . __FILE__ . ", LINE " . __LINE__ . "\n\n");
	}

  my $time0;
  if ($SQLPROFILE) {
    print STDERR "sqlin: $qry\n";
    $time0=time();
  }
  $sth=$dbh->prepare($qry);
  if (!$sth) {
    print "Error: ",$dbh->errstr;
    print STDERR "On query: $qry\n";
    exit(1);
  }
  $rv=$sth->execute;
  if (!$rv) {
    print "Error: ",$dbh->errstr;
    print STDERR "On query: $qry\n";
    exit(1);
  }
  $sth->finish();
  if (!($dbh->{'AutoCommit'})) {
    $dbh->commit;
  }
  if (!$dbh) {
    print "dbinsert: failed trying to commit insert to icms flags\n";
    print STDERR "On query: $qry\n";
    exit(1);
  }
}				# end sqlin




#
#  sqllist is a new version of gettable that trims & de-nullifies
#

sub sqllist {
	my $qry = shift;
	my $limit = shift;
	my $dbhandle  = shift;

	if ($DEBUG) {
		logQuery($qry,"FILE" . __FILE__ . ", LINE " . __LINE__ . "\n\n");
	}

	if (!defined($dbhandle)) {
		# Since making $dbh not global would break so many calls, allow $dbhandle to
		# be passed as null, causing it to use $dbh; other DBI-type DB handles (for
		# other databases) can also be passed, however
		$dbhandle = $dbh;
	}

	my $count=0;
	my $sth;
	my $rv;
	my @loclist;
	my $i;

	my $time0;
	if ($SQLPROFILE) {
		print STDERR "sqllist: $qry\n";
		$time0=time();
	}
	$sth=$dbhandle->prepare($qry);
	if ($sth->err) {
		print STDERR "Error: ",$dbhandle->errstr;
		print STDERR "On query: $qry\n";
		exit(1);
	}
	$rv=$sth->execute;
	if (!$rv) {
		print "Error: ",$dbhandle->errstr;
		exit(1);
	}
	while (@ary=$sth->fetchrow_array) {
		for ($i=0;$i<@ary;$i++) {
			if (!defined $ary[$i]) {
				$ary[$i]="";
			}
			$ary[$i]=trim($ary[$i]);
			$ary[$i]=~s/\~//g;	# trim any stray ~s.
		}
		push @loclist,join '~',@ary;
		if (defined $limit) {
			$count++;
			if ($count==$limit) {
				last;
			}
		}
	}
	if ($SQLPROFILE) {
		print STDERR scalar @loclist," Records found\n";
		print STDERR "Query took ",time()-$time0," Seconds\n";
	}
	return @loclist;
}


sub sqlHashArray {
	# Kind of like sqllist, but instead of returning an array of formatted
	# data, it accepts an array reference as an argument, and then populates
	# # that array with hash references.  Each referenced hash is keyed with the
	# columns returned in the query.  This makes the data a little more
	# readily accessible and flexible.

	my $qry = shift;
	my $dbhandle = shift;
	my $data = shift;

	if ($DEBUG) {
		logQuery($qry,"FILE" . __FILE__ . ", LINE " . __LINE__ . "\n\n");
	}

	if (!defined($dbhandle)) {
		# Since making $dbh not global would break so many calls, allow $dbhandle to
		# be passed as null, causing it to use $dbh; other DBI-type DB handles (for
		# other databases) can also be passed, however
		$dbhandle = $dbh;
	}

	my $sth;
	my $rv;

	$sth=$dbhandle->prepare($qry);
	if ($sth->err) {
		print STDERR "Error: ",$dbhandle->errstr;
		print STDERR "On query: $qry\n";
		exit(1);
	}
	$rv=$sth->execute;
	if (!$rv) {
		print "Error: ",$dbhandle->errstr;
		exit(1);
	}
	while ($row=$sth->fetchrow_hashref) {
		foreach my $key (keys %{$row}) {
			$row->{$key}=trim($row->{$key});
			if (defined($row->{$key})) {
				$row->{$key}=~ s/~//g;	# trim any stray ~s.
			} else {
				$row->{$key} = "";
			}
		}
		push(@{$data}, $row);
	}
}

sub sqlHashOne {
	# Like sqlHashArray, but returns a single hash reference instead of an array of them.
	# Used for queries that will return a single record, so you don't need to muck about
	# with extracting the element from an array

	my $qry = shift;
	my $dbhandle = shift;

	if ($DEBUG) {
		logQuery($qry,"FILE" . __FILE__ . ", LINE " . __LINE__ . "\n\n");
	}

	if (!defined($dbhandle)) {
		# Since making $dbh not global would break so many calls, allow $dbhandle to
		# be passed as null, causing it to use $dbh; other DBI-type DB handles (for
		# other databases) can also be passed, however
		$dbhandle = $dbh;
	}

	my $sth;
	my $rv;

	$sth=$dbhandle->prepare($qry);
	if ($sth->err) {
		print STDERR "Error: ",$dbhandle->errstr;
		print STDERR "On query: $qry\n";
		exit(1);
	}
	$rv=$sth->execute;

	if (!$rv) {
		print "Error: ",$dbhandle->errstr;
		exit(1);
	}

	my $row=$sth->fetchrow_hashref;

	foreach my $key (keys %{$row}) {
		$row->{$key}=trim($row->{$key});
		if (defined($row->{$key})) {
			$row->{$key}=~ s/~//g;	# trim any stray ~s.
		} else {
			$row->{$key} = "";
		}
	}
	return $row;
}


sub sqlHashHash {
	# Similar to sqlHashArray, but returns a reference to a hash, with each hash
	# element being another hash reference, keyed on the specified field
	my $qry = shift;
	my $dbhandle = shift;
	my $hashref = shift;
	my $keyfield = shift;

	if ($DEBUG) {
		logQuery($qry,"FILE" . __FILE__ . ", LINE " . __LINE__ . "\n\n");
	}

	if (!defined($dbhandle)) {
		# Since making $dbh not global would break so many calls, allow $dbhandle to
		# be passed as null, causing it to use $dbh; other DBI-type DB handles (for
		# other databases) can also be passed, however
		$dbhandle = $dbh;
	}

	my $sth;
	my $rv;

	$sth=$dbhandle->prepare($qry);
	if ($sth->err) {
		print STDERR "Error: ",$dbhandle->errstr;
		print STDERR "On query: $qry\n";
		exit(1);
	}
	$rv=$sth->execute;
	if (!$rv) {
		print "Error: ",$dbhandle->errstr;
		exit(1);
	}
	while ($row=$sth->fetchrow_hashref) {
		foreach my $key (keys %{$row}) {
			$row->{$key}=trim($row->{$key});
			next if (!defined($row->{$key}));
			$row->{$key}=~s/\~//g;	# trim any stray ~s.
		}
		$hashref->{$row->{$keyfield}} = $row;
	}
}



sub sqlArrayHash {
	# Similar to sqlHashArray, but returns a reference to a hash, with each hash
	# element being an array reference
	my $qry = shift;
	my $dbhandle = shift;
	my $hashref = shift;
	my $keyfield = shift;

	if ($DEBUG) {
		logQuery($qry,"FILE" . __FILE__ . ", LINE " . __LINE__ . "\n\n");
	}

	if (!defined($dbhandle)) {
		# Since making $dbh not global would break so many calls, allow $dbhandle to
		# be passed as null, causing it to use $dbh; other DBI-type DB handles (for
		# other databases) can also be passed, however
		$dbhandle = $dbh;
	}

	my $sth;
	my $rv;

	$sth=$dbhandle->prepare($qry);
	if ($sth->err) {
		print STDERR "Error: ",$dbhandle->errstr;
		print STDERR "On query: $qry\n";
		exit(1);
	}
	$rv=$sth->execute;
	if (!$rv) {
		print "Error: ",$dbhandle->errstr;
		exit(1);
	}
	while ($row=$sth->fetchrow_hashref) {
		foreach my $key (keys %{$row}) {
			next if (!defined($row->{$key}));
			$row->{$key}=trim($row->{$key});
			$row->{$key}=~s/\~//g;	# trim any stray ~s.
		}
		if (!defined($hashref->{$row->{$keyfield}})) {
			# Define an array if it doesn't exist.
			$hashref->{$row->{$keyfield}} = [];
		}

		push (@{$hashref->{$row->{$keyfield}}},$row);
	}
}




#
#  sqllistone asks a query, and returns the first response as a list
#

sub sqllistone {
  my $qry = shift;
  my $dbhandle = shift;

    	if ($DEBUG) {
		logQuery($qry,"FILE" . __FILE__ . ", LINE " . __LINE__ . "\n\n");
	}

  if (!defined($dbhandle)) {
    # Since making $dbh not global would break so many calls, allow $dbhandle to
    # be passed as null, causing it to use $dbh; other DBI-type DB handles (for
    # other databases) can also be passed, however
    $dbhandle = $dbh;
  }

  my $sth;
  my $rv;
  my $i;

  my $time0;
  if ($SQLPROFILE) {
    print STDERR "sqllist: $qry\n";
    $time0=time();
  }

  $sth=$dbhandle->prepare($qry);
  if ($sth->err) {
    print "Error: ",$dbhandle->errstr;
    exit(1);
  }

  $rv=$sth->execute;
  @ary=$sth->fetchrow_array;
  for ($i=0;$i<@ary;$i++) {
    if (!defined $ary[$i]) {
      $ary[$i]="";
    }
    $ary[$i]=trim($ary[$i]);
    $ary[$i]=~s/\~//g;		# trim any stray ~s.
  }
  if ($SQLPROFILE) {
    print STDERR scalar @ary," Records found\n";
    print STDERR "Query took ",time()-$time0," Seconds\n";
  }
  return @ary;
}


#
#  sqltables returns a lists the tables in a database
#

sub sqltables {
  return $dbh->tables;
}

#
# ping justs checks to see if a given host is up or not, returning
#      1 if the host is up, 0 otherwise
#
sub ping {
  my($host)=@_;
  my @pingout=`ping -q -c 1 -W 1 $host 2>/dev/null`;
  if ($pingout[3]=~/1 packets received|1 received/) {
    return(1);
  }
  return 0;			# a problem
}



my $SORTBY;

sub mashdate {
  my($date)=@_;
  my($month,$day,$year)=split '/',$date;
  return sprintf("%04d%02d%02d",$year,$month,$day);
}


sub complist {
  my @list=split ',',$SORTBY;
  my $result=0;
  foreach (@list) {
    my($fnum,$ftype,$aord)=split '~',$_;
    my $aval=(split '~',$a)[$fnum];
    my $bval=(split '~',$b)[$fnum];
    if ($aord eq "D") {
      my $c=$aval; $aval=$bval; $bval=$c;
    }
    if ($ftype eq "A") {
      $result=$aval cmp $bval;
    } elsif ($ftype eq "D") {
      $aval=mashdate($aval);
      $bval=mashdate($bval);
      $result=$aval cmp $bval;
    } elsif ($ftype eq "N") {
      $result=$aval <=> $bval;
    } else {
      die "complist: invalid ftype of $ftype";
    }
    if ($result!=0) {
      return $result;
    }
    # if first key field matches, check next one until done
  }
  return $result;
}
#
# sortlist returns a sorted list; it's assumed fields
#          are separated with ~.
#
# you specify the order like this:
# field#~type~A|D
# where type is:
#   A - alpha
#   D - Date
#   N - Numeric
#
# we do this for FACC stuff rather than order by or group by
#    since their sql servers are rather lame...
#
sub sortlist {
  my($order,@list)=@_;
  $SORTBY=$order;
  return sort complist @list;
}

#
#  hash writes a hash table to a file--now handles hashes of arrays
#            as well as hashes of strings.

sub writehash {
	my $fname=shift;
	my $hashfile=shift;

	# Check for the existence of the directory; create it if it doesn't exist.
	my $targetDir = dirname($fname);
	if (!-d $targetDir) {
		my $err = undef;
		make_path($targetDir, {
			mode => 0755,
			error => \$err
		});
		if (@$err) {
			for my $diag (@$err) {
				my ($file, $message) = %$diag;
				if ($file eq '') {
					warn "general error: $message\n\n";
				} else {
					warn "Problem creating directory '$file': $message\n\n";
				}
			}
			return;
		}
	}


	open(HASHOUT,">$fname") ||
		die "Unable to open hash file '$fname': $!\n\n";
	foreach $key (sort keys(%$hashfile)) {
    if (not ref $$hashfile{$key}) {
      print HASHOUT $key,'`',$$hashfile{$key},"\n";
    } elsif (ref $$hashfile{$key} eq "ARRAY") {
      $flag=0;
      print HASHOUT $key,'`';
      foreach (@{$$hashfile{$key}}) {
	if ($flag) {
	  print HASHOUT ";";
	}
	print HASHOUT $_;
	$flag=1;
      }
      print HASHOUT "\n";
    } else {
      die "writehash: can't handle ref $$hashfile{$key})\n";
    }
  }
  close(HASHOUT);
}

sub writeHashFromArray {
	# Improved version of writehash.  Instead of accepting a hash, it accepts
	# a reference to an array of hashes, as returned from sqlHashArray().  This
	# offers greater flexibility - instead of having a pre-built hash, keyed on
	# a single element and having a lot of tilde-delimited strings, it iterates
	# through the array and builds the strings as it likes (allowing reuse of
	# arrays)
	# Arguments are the array reference, and then the name of the file to be
	# created, and then hash fields that we'll want to deal with, in the order
	# we'd like to deal with them
	my $arrayref = shift;
	my $hashfile = shift;
	my $keep = shift;
	my $first = shift;
	my @fields = @_;

	if (defined($first)) {
		# Create a temporary file in the target directory, to avoid race conditions
		my $dir = dirname($hashfile);

		my $fh = File::Temp->new(
			DIR => $dir,
			UNLINK => 0
		);

		my $fname = $fh->filename;

		# No sense trying to process them if we don't have any field names
		foreach my $row (@{$arrayref}) {
			print $fh $row->{$first} . "`";
			my @stringArray;
			foreach my $field (@fields) {
				push(@stringArray,$row->{$field});
			}
			print $fh join("~",@stringArray) . "\n";
		}
		close ($fh);

		# Make the file readable
		chmod(0644,$fname);
		# Clean up
		if ($keep) {
			# We've been asked to keep the original file.  Back it up using the
			# old file's mtime
			if (!keepOldFile($hashfile)) {
				print "Backup of original file '$hashfile' was requested, but the ".
				"backup failed.  No action taken.\n";
				return 0;
			}
		} else {
			# Not asked to keep the old file.  Remove it.
			if ((-e $hashfile) && (!unlink($hashfile))) {
				print "Unable to remove original file '$hashfile'.  No action ".
					"taken.\n";
				return 0;
			}
		}
		# Rename the temp file.
		if (!rename($fname, $hashfile)) {
			print "Unable to rename temp file '$fname' to '$hashname'.  You ".
				"should manually rename the file if you need it.\n";
			return 0;
		} else {
			return 1;
		}
	} else {
		# Nothing was done
		return 0;
	}
}



sub writeHashFromHash {
	# Improved version of writehash.  Instead of accepting a hash, it accepts
	# a reference to an array of hashes, as returned from sqlHashArray().  This
	# offers greater flexibility - instead of having a pre-built hash, keyed on
	# a single element and having a lot of tilde-delimited strings, it iterates
	# through the array and builds the strings as it likes (allowing reuse of
	# arrays)
	# Arguments are the array reference, and then the name of the file to be
	# created, and then hash fields that we'll want to deal with, in the order
	# we'd like to deal with them
	my $hashref = shift;
	my $hashfile = shift;
	my $keep = shift;
	my $first = shift;
	my @fields = @_;

	if ((defined($first)) && scalar(@fields)) {
		# Create a temporary file in the target directory, to avoid race conditions
		my $dir = dirname($hashfile);

		my $fh = File::Temp->new(
			DIR => $dir,
			UNLINK => 0
		);

		my $fname = $fh->filename;

		# No sense trying to process them if we don't have any field names
		foreach my $row (sort keys %{$hashref}) {
			print $fh $hashref->{$row}->{$first} . "`";
			my @stringArray;
			foreach my $field (@fields) {
				push(@stringArray,$hashref->{$row}->{$field});
			}
			print $fh join("~",@stringArray) . "\n";
		}
		close ($fh);

		# Make the file readable
		chmod(0644,$fname);
		# Clean up
		if ($keep) {
			# We've been asked to keep the original file.  Back it up using the
			# old file's mtime
			if (!keepOldFile($hashfile)) {
				print "Backup of original file '$hashfile' was requested, but the ".
					"backup failed.  No action taken.\n";
				return 0;
			}
		} else {
			# Not asked to keep the old file.  Remove it.
			if ((-e $hashfile) && (!unlink($hashfile))) {
				print "Unable to remove original file '$hashfile'.  No action ".
					"taken.\n";
				return 0;
			}
		}
		# Rename the temp file.
		if (!rename($fname, $hashfile)) {
			print "Unable to rename temp file '$fname' to '$hashname'.  You ".
				"should manually rename the file if you need it.\n";
			return 0;
		} else {
			return 1;
		}
	} else {
		# Nothing was done
		return 0;
	}
}


sub sortHashArray {
   # Sorts an array of hash refs on the specified key.  First arg is a reference
   # to the original array. Second is the field on which to sort.
   my $orig = shift;
   my $sortField = shift;

   print "Starting sort of " . scalar(@{$orig}) . " records: " . timestamp() . "\n\n";
   @{$orig} = sort { $a->{$sortField} <=> $b->{$sortField} } @{$orig};
   print "Finished sorting: ". timestamp() . "\n\n";
}


sub keepOldFile {
      # Creates a backup copy of the specified file, using the file's mtime as
      # a filename extension (in the form YYYYMMDDHHMMSS)
      # Returns 1 for success, 0 for failure
      my $filename = shift;
      if (-f $filename) {
         my @filestat = stat($filename);
         if (@filestat) {
            my $fileext = strftime("%Y%m%d-%H%M%S", localtime($filestat[9]));
            my $newfile = $filename . ".$fileext";
            if (rename($filename, $newfile)) {
               # The rename was successful
               return 1;
            } else {
               # The rename failed
               return 0;
            }
         } else {
            # Couldn't stat file, so it's unlikely we'll be able to rename it,
            # either.  Fail.
            return 0;
         }
      } else {
         # The file doesn't exist.  We'll call that success, since there was
         # nothing to back up.
         return 1;
      }
}

# Reads an array of hashes from a tilde-delimited file (in the same format that
# would be returned by sqlHashArray). Arguments are the name of the file, the
# reference to the array to be populated, the delimiter, and then the field
# names, in order
sub readHashArray {
   my $hashfile = shift;
   my $arrayref = shift;
   my $delimiter = shift;
   my @fields = @_;

   if (!open (INFILE, $hashfile)) {
      print "Unable to open input file '$hashfile': $!\n";
      return 0;
   }

   while (my $line = <INFILE>) {
      chomp $line;
      my @temp = split(/$delimiter/, $line);
      my $count = 0;
      my $hashref = {};
      foreach my $field (@fields) {
         $hashref->{$field} = $temp[$count++];
      }
      push(@{$arrayref}, $hashref);
   }
   close INFILE;
   return 1;
}


# Similar to the difference between sqlHashArray() and sqlHashHash(), this
# function performs essentially the same function as readHashArray(), but
# instead of populating an array of hash references, it populates a hash ref
# with additional hash refs, keyed on the $hashkey value.
sub readHashHash {
	my $hashfile = shift;
    my $hashref = shift;
    my $delimiter = shift;
    my @fields = @_;

    my $hashkey = $fields[0];

    if (!open (INFILE, $hashfile)) {
        print "Unable to open input file '$hashfile': $!\n";
        return 0;
    }

    while (my $line = <INFILE>) {
        chomp $line;
        my @temp = split(/$delimiter/, $line);
        my $count = 0;
        my $datahash = {};
        foreach my $field (@fields) {
            $datahash->{$field} = $temp[$count++];
        }
        $hashref->{$datahash->{$hashkey}} = $datahash;
    }
    close INFILE;
    return 1;
}




#
#  readhash reads a hash table from a file
#

sub readhash {
    my $fname = shift;
    my %hashlist;
    open(HASHIN,$fname);
    foreach $line (<HASHIN>) {
        chomp($line);
        ($key,$rec)=split('`',$line);
		next if ($key eq "");
        $hashlist{$key}=$rec;
    }
    close(HASHIN);
    return %hashlist;
}

#
#  ask executes a query; future getlines will pull lines from it.
#


sub ask {
  local($rv,@loclist);
  my $qry = shift;
  $sth=$dbh->prepare($qry);
  if (!$sth) {
    print "Error: ",$dbh->errstr;
    print "Bad Query:$qry:\n";
    exit(1);
  }
  $rv=$sth->execute;
  #   $sth->finish;
  if (!$rv) {
    print "Error: ",$dbh->errstr;
    exit(1);
  }
}

#
#  Getline returns a single line from a query as a list
#

sub getline {
  return $sth->fetchrow_array;
}



#
#  GetCount asks a single-value query and returns it as a whatever..
#

sub getcount {
  local($qry,$sth,$rv,@ary);
  $qry=$_[0];
  ask($qry);
  if (@ary=getline) {
    return int $ary[0];
  } else {
    return "Query Error";
  }
  ;
}


#
#  getsth returns a statement handle for a query
#         (a low-level routine used by genqry.cgi)
#

sub getsth {
  my($qry,$sth,$rv);
  $qry=$_[0];
  $sth=$dbh->prepare($qry) or return 0;
  if ($sth->err) {
    print $dbh->errstr; return 0;
  }
  $rv=$sth->execute;
  if (!$rv) {
    print $dbh->errstr; return 0;
  }
  return $sth;
}



#
#  writetable writes an array to a file
#

sub writetable {
  my $fname = shift;
  my $arr = shift;

  open(LISTOUT,">$fname") or die "Couldn't open $fname\n";
  foreach (@$arr) {
    print LISTOUT "$_\n";
  }
  close(LISTOUT);
}

#
#  readtable reads an array from a file
#

sub readtable {
  my $fname = shift;
  local (@arr);

  open(LISTOUT,"$fname");
  while (<LISTOUT>) {
    push(@arr,$_);
  }
  close(LISTOUT);
  return @arr;
}


#
#  htmllist displays a list as an html table
#           use a ~ betweeen fields


sub htmllist {
  my $list=$_[0];
  my $title=$_[1];
  print "<table border=1>";
  if (defined $title) {
    @tlist=split('~',$title);
    print "<tr>";
    foreach (@tlist) {
      print "<td><b>$_</b></td>";
    }
    print "</tr>";
  }
  foreach (@$list) {
    @ary=split '~';
    print "<tr>";
    foreach (@ary) {
      $_=~s/\r/<br>/g;
      print "<td>$_</td>";
    }
    print "</tr>";
  }
  print "</table>";
  return;
}


#
#  reportheader generates a standard header for ICMS case reports
#

sub reportheader {
  my($fh,$county,$divname,$helppage,$icmslevel)=@_;
  my $icmsback;
  if ($icmslevel==0) {
    $icmslevel=2; $icmsback=1;
  } else {
    $icmsback=$icmslevel-1;
  }
  print $fh <<EOS;
    <title>$county County: $divname Summary</title>
<link rel="stylesheet" type="text/css" name="stylin" href="$ROOTPATH/icms1.css"><script src="$ROOTPATH/icms.js" language="javascript" type="text/javascript"></script>
<body onload=SetBack("ICMS_$icmslevel");>
    <a href=$ROOTPATH/index.php><img src=$ROOTPATH/icmslogo.jpg border=0></a><p>
    <input type=button name=Back value=Back onClick=GoBack('ICMS_$icmsback');>&nbsp;<input type=button name=Help value=Help onClick=PopUp('$ROOTPATH/help/$helppage.html','Help');><p><div class=h1>$county County</div><p>
$MTEXT $DAY, $YEAR<p>
<table>
EOS
}

#
#  reportfooter generates a standard footer for ICMS case reports
#

sub reportfooter {
  my($fh,$outpath2)=@_;
  $outpath2=~s#/var/www/html##;
  $outpath2=~s#/\d\d\d\d\-\d\d##;
  print $fh <<EOS;
</table>
<p><font size=-1><a href=$outpath2/archive.html>Older Reports</a></font><p><font size=-2><i>Court Technology Department, 15th Judicial Circuit of Florida</i></font>
EOS
}


#
# tabletitle puts a two-column label at the top of the table
#
sub tabletitle {
  my($fh,$title)=@_;
  print $fh "<tr><td colspan=2 bgcolor=$TLINE><div class=h2>$title</div>";
}


#
# tableline displays a category & # of entries with a clickable link
#
sub tableline {
  my($fh,$name,$sub,$num,$cnum,$path)=@_;
  $path=~s#/var/www/html/##;
  $path="$path/$name.txt";
  my $href="$ROOTPATH/genlist.php?rpath=$path";
  if ($path=~/sec/ || $path=~/divAD/) {
    $href="$ROOTPATH/secret/genlist.php?rpath=$path";
  }
  print $fh "<tr><td bgcolor=$CLINE><span class=rptlabel$cnum><a href=$href>$sub</a></span><td bgcolor=$CLINE align=right><span class=rptnum$cnum>$num</span>";
}


#
# tableline2 displays a category & # of entries (w/ pct) with a clickable link
#
sub tableline2 {
  my($fh,$name,$sub,$num,$pct,$cnum,$path)=@_;
  $path=~s#/var/www/html/##;
  $path="$path/$name.txt";
  my $href="$ROOTPATH/genlist.php?rpath=$path";
  if ($path=~/sec/) {
    $href="$ROOTPATH/secret/genlist.php?rpath=$path";
  }
  print $fh "<tr><td bgcolor=$CLINE><span class=rptlabel$cnum><a href=$href>$sub</a></span><td bgcolor=$CLINE align=right><span class=rptnum$cnum>$num</span><td bgcolor=$CLINE align=right><span class=rptnum$cnum>$pct</span>";
}

sub tableblank {
  my($fh)=@_;
  print $fh "<tr><td colspan=2 bgcolor=$CLINE>&nbsp;";
}

#
# Tabletotal is like tableline, but without the link.
#
sub tabletotal {
  my($fh,$tot)=@_;
  print $fh "<tr><td bgcolor=$CLINE><span class=rptlabel><b>Total</b></span><td bgcolor=$CLINE align=right><span class=rptnum>$tot</span>";
}


#
#  Outrow outputs one line of a table from a ; separated list to a filehandle
#
#  style sets attributes (b)old is the only attribute recognized now)

sub outrowh {
  my $handle = shift;
  my $dat = shift;
  my $style = shift;
  my $sep = shift;

  print $handle "<tr valign=top>";
  if (not defined $sep or $sep eq "") {
    $sep=";";
  }
  foreach (split $sep,$dat) {
    if ((defined $style) and (length($style)>0)) {
      print $handle "<td><$style>$_</$style></td>";
    } else {
      print $handle "<td>$_</td>";
    }
  }
  print $handle "</tr>";
  return;
}

#
#  Outrow outputs one line of a table from a ; separated list
#
#  style sets attributes (b)old is the only attribute recognized now)
#  sep is the separator used between fields (defaults to ; )

sub outrow {
  my $dat = shift;
  my $style = shift;
  my $sep = shift;

  outrowh(STDOUT,$dat,$style,$sep);
}


#
#  Outpair takes a "desc;value" pair and outputs it as a line of a table,
#          boldfacing the description

sub outpair {
  my $desc = shift;
  my $val = shift;

  print "<tr><td><b>$desc</b></td><td>$val</td></tr>";
}

#
#  Outtable takes a ; separated list of values, along with an optional
#           ; separated list of titles, and outputs a table containing
#           said values & titles, bold facing the titles; nice for
#           outputting certain kinds of stuff.
#

sub outtable {
  my $datx = shift;
  my $titl = shift;

  print "<table border=1><tr>";
  outrow($titl,"b");
  outrow($datx);
  print "</table>";
}



#
# dependdesc gives a description for a given dependency code;
#            it does this by looking it up in depend.txt
#

sub dependdesc {
  local($key,$value);
  if (!$DEPEND_FILE_FLAG) {
    open(DEPENDFILE,"$UTILSFILEPATH/depend.txt") ||
      die "Couldn't open $UTILSFILEPATH/depend.txt";
    foreach (<DEPENDFILE>) {
      chomp;
      ($key,$value)=split ';';
      $DEPENDLIST{$key}=$value;
    }
    $DEPEND_FILE_FLAG++;
    close(DEPENDFILE);
  }
  return $DEPENDLIST{$_[0]};
}

#
# ncicdesc gives a description for a given NCIC code
#          (really, for the Category of that code)
#            it does this by looking it up in ncic.conf
#

sub ncicdesc {
  local($key,$value,$codecat);
  if (!$NCIC_FILE_FLAG) {
    open(NCICFILE,"$UTILSFILEPATH/ncic.conf") ||
      die "Couldn't open $UTILSFILEPATH/ncic.conf";
    foreach (<NCICFILE>) {
      if (/^#/) {
	next;
      }				# skip comments
      chomp;
      ($key,$value)=split ';';
      $NCICLIST{$key}=$value;
    }
    $NCIC_FILE_FLAG++;
    close(NCICFILE);
  }
  if (!defined $_[0] || $_[0] eq "?") {
    return "";
  }
  $codecat=substr($_[0],0,2)."00"; #  - ($_[0] % 100);
  return $NCICLIST{$codecat};
}


#
# sub parsedate
#
sub parsedate {
  my ($indate)=@_;
  if ($indate=~m#(\d+)/(\d+)/(\d+)#) {
    return ($1,$2,$3);
  } else {
    return "";
  }
}



#
#  compdate(date1,date2) compares to date strings, returning a C-style comparision result
#
# since I always forget this:
#   if (date1 and/or date2 are blank, or invalid) returns -2
#   if (date1<date2) returns -1
#   if (date1==date2) returns 0
#   if (date1>date2 returns 1


sub compdate {
  $date1=$_[0];
  $date2=$_[1];
  ($m1,$d1,$y1)=parsedate($date1);
  ($m2,$d2,$y2)=parsedate($date2);
  if (!defined $y1 || !defined $y2) {
    return -2;
  }
  $v1=$y1*10000+$m1*100+$d1;
  $v2=$y2*10000+$m2*100+$d2;
  if ($v1==$v2) {
    return 0;
  }
  return ($v1<$v2 ? -1: 1);
}


sub monthname {
  my($month)=@_;
  if ($month eq "") {
    return $month;
  }
  return Date::Calc::Month_to_Text($month);
}

sub month2num {
  my($mname)=@_;
  my $mdate = ParseDateString($mname);
  my @format="%D";
  $mdate=UnixDate($mdate,@format);
  return $mdate;
}
#
#  buildarchive makes an archive page for a directory, excluding the current
#   report.
# assumes a global OUTFILE

sub buildarchive {
  my($outpath,$div,$divcat);
  $outpath=$_[0];
  $div=$_[1];
  $divcat=$_[2];
  opendir THISDIR,"$outpath/div$div" || die "Can't open directory $outpath/div$div";
  @allfiles=reverse sort( grep !/^\.\.?$/, readdir THISDIR);
  closedir THISDIR;
  open OUTFILE,">$outpath/div$div/archive.html" || die "Can't open archive outfile";
  print OUTFILE "<title>Alachua County: $divcat Division Reports Archive</title>";
  print OUTFILE "<h1>Alachua County: $divcat Division Reports Archive</h1>";
  print OUTFILE "<h2>Division $div:</h2>";
  foreach $fname (@allfiles) {
    if (!($fname=~/^[0-9]/)) {
      next;
    }
    if (!$flag) {
      $flag++; next;
    }				# skip the current report
    ($year,$month)=split '-',$fname;
    $mtext=monthname($month);
    print OUTFILE "<h3><a href=$fname>$mtext, $year</a></h3>";
  }
  print OUTFILE "<p><hr><i>Court Technology Department, 15th Judicial Circuit of Florida</i>";
  close(OUTFILE);
}


#
# pct is a little percent-printing routine
#

sub pct {
  if ($_[1]!=0) {
    return sprintf "(%5.2f%%)",($_[0]/$_[1])*100;
  }
}

#
#  clean removes bad characters from a string
#
sub clean {
  my $foo = shift;

  $foo=~s/[\&\;\`\'\\\"\|\?\~\<\>\^\(\)\[\]\{\}\$\n\r]//g;
  return $foo;
}

#
# trim removes trailing spaces from a string
#

sub trim {
	my $foo = shift;
	return undef if (!defined($foo));

	$foo =~ s/\s+$//g;
	# Also remove leading newlines
	$foo =~ s/^\n+//g;

	return $foo;
}

#
# fixname tidies up several common name problems:
#      trailing spaces, extra spaces inside name, space before comma
#      and also converts to uppercase for matching purposes

sub fixname {
  my $name= shift;
  $name=~tr/a-z/A-Z/;
  $name=trim($name);
  $name=~s/ ,/,/;
  $name=~s/[ ]+/ /g;
  return $name;
}


#
# fixyear converts a 2-digit year to a 4-digit year
#      using PIVOTYEAR
#

sub fixyear {
  my $year=$_[0];
  if (length($year)==4) {
    return $year;
  }
  if ($year<$PIVOTYEAR) {
    return $year+=2000;
  }
  return $year+=1900;
}



#
# Fixdate needed by MS SQL with freetds, darn it.
#         no matter what I do, I can't get MS SQL to format dates
#         in mm/dd/yy format.

sub fixdate {
  my($in,$yc,$mc,$dc);
  $in=$_[0];
  if ($in eq "") {
    return "";
  }
  ($yc,$mc,$dc)=Decode_Date_US(substr($in,0,11));
  return sprintf "%02d/%02d/%04d",$mc,$dc,$yc;
}



#
# fixdatelist takes a list and fixes the dates whose columns are supplied
#

sub fixdatelist {
  my ($list,$ind,@arr,$line,$yc,$mc,$dc,$i,$newdate);
  $list=$_[0];
  $ind=$_[1];
  for ($i=0;$i< scalar @$list;$i++) {
    @arr=split '~',$$list[$i];
    ($yc,$mc,$dc)=Decode_Date_US(substr($arr[$ind],0,11));
    $newdate=sprintf "%02d/%02d/%04d",$mc,$dc,$yc;
    if ($newdate ne "00/00/0000") {
      $arr[$ind]=$newdate;
    }
    $$list[$i]=join '~',@arr;
  }
}


#
# fixtimelist needed for Microsoft SQL via freetds, since convers
#

sub fixtimelist {
  my ($list,$ind,@arr,$line,$i,$newtime);
  $list=$_[0];
  $ind=$_[1];
  for ($i=0;$i< scalar @$list;$i++) {
    @arr=split '~',$$list[$i];
    $newtime=substr($arr[$ind],11,255);
    $arr[$ind]=$newtime;
    $$list[$i]=join '~',@arr;
  }
}


#
# PrettyDate makes dates in the future green (no doubt, with envy)
#

sub prettydate {
  my $dt = shift;
  local ($dt2,$today,$month,$day,$year);
  if ($dt=~/(\d\d)\/(\d\d)\/(\d\d\d\d)/) {
    # clean input, ignore suffixes, etc.
    $dt2="$1/$2/$3";
  } else {
    $dt2=$dt;
  }
  ($year,$month,$day)=Date::Calc::Today();
  $today=sprintf("%02d/%02d/%02d",$month,$day,$year);
  if (compdate($dt2,$today)>-1) { # a future date
    return "<font color=green>$dt</font>";
  } else {
    return $dt;
  }
}


#
# prettytime takes a "1800 hours" style time and converts it to
#            non-military-human readable.
#

sub prettytime {
  my $tim2=$_[0];
  if ($tim2<800) {
    $tim2+=1200;
  }
  if ($tim2>=1200) {
    if ($tim2>1200) {
      $tim2-=1200;
    }
    $sig="P.M.";
  } else {
    $sig="A.M.";
  }
  $tim3=sprintf("%d:%02d $sig",$tim2/100,$tim2 % 100);
  return $tim3;
}

#
# time_24_to_ampm
#
sub time_24_to_ampm {
  my($time)=@_;
  my($hour,$min)=split ':',$time;
  if ($hour==0) {
    return sprintf("12:%02d AM",$min);
  } elsif ($hour<12) {
    return sprintf("%d:%02d AM",$hour,$min);
  } elsif ($hour==12) {
    return sprintf("12:%02d PM",$min);
  } elsif ($hour>12) {
    return sprintf("%d:%02d PM",$hour-12,$min);
  }
}


#
# does the same as time_24_to_ampm for list $$list, index $ind.
#
sub time_24_to_ampm_list {
  my($list,$ind)=@_;
  my($i,$newtime,@arr);
  for ($i=0;$i<scalar @$list;$i++) {
    @arr=split '~',$$list[$i];
    $newtime=time_24_to_ampm($arr[$ind]);
    $arr[$ind]=$newtime;
    $$list[$i]=join '~',@arr;
  }
}


sub time_ampm_to_24 {
  my($time)=@_;
  if ($time=~/(\d+)\:(\d+)( ){0,1}(am|pm|A\.M\.|P\.M\.|)/i) {
    my($h,$m,$ampm)=($1,$2,$4);
    if ($ampm=~/a/i) {		# an AM time
      if ($h==12) {
	$h=0;
      }
      return sprintf("%02d:%02d",$h,$m);
    } else {
      if ($h!=12) {
	$h+=12;
      }
      return sprintf("%02d:%02d",$h,$m);
    }
  } else {
    return "ERROR: $time";
  }
}


sub decimaltime {
  my($time)=@_;
  if ($time=~/a|p/i) {
    $time=time_ampm_to_24($time);
  }
  my($h,$m)=split ':',$time;
  return $h+$m/60;
}


#
# PrettyAge makes dates turn green, amber, red, then brown with age
#

sub prettyage {
  my $age = shift;
  if (!defined $age || not ($age=~/\d+/)) {
    return $age;
  }
  if ($age<180) {
    return $age;
  } elsif ($age<210) {
    return "<font color=green>$age</font>";
  } elsif ($age<240) {
    return "<font color=#BBBB00>$age</font>";
  } elsif ($age<290) {
    return "<font color=red>$age</font>";
  }
  return "<font color=brown>$age</font>";
}


#
#  getage returns age in days from today, or 0 if there's trouble
#

sub getage {
	my $indate = shift;

	local($yc,$mc,$dc);
	if (defined $indate) {
		($yc,$mc,$dc)=Decode_Date_US($indate);
		if (defined $yc) {
			return Delta_Days($yc,$mc,$dc,$YEAR,$MONTH,$DAY);
		}
  }
  return 0;
}


#
#  getageinyears returns age in years & months from today
#

sub getageinyears {
  my $indate = shift;

  return "&nbsp;" if ((!defined($indate)) || ($indate eq "") || ($indate eq "&nbsp;"));

  # A hack because Time::Piece (strptime) can't handle those old years
  my ($month, $day, $year) = split(/\//, $indate, 3);
  return undef if ((!defined $year) || ($year <= 1901));

  my $dob_time = Time::Piece->strptime($indate, '%m/%d/%Y');

  my $now = localtime(time);

  my $diff = $now - $dob_time;

  my $years = int($diff->years);
  $diff -= $years * ONE_YEAR;

  my $months = int($diff->months);

  return "$years years, $months months";
}


#
#  getdiff returns difference between two dates
#

sub getdiff {
  my $indate = shift;
  my $indate2 = shift;

  local($yc,$mc,$dc,$cage);
  ($yc,$mc,$dc)=Decode_Date_US($indate);
  ($yc2,$mc2,$dc2)=Decode_Date_US($indate2);
  if (defined $yc) {
    $cage=Delta_Days($yc,$mc,$dc,$yc2,$mc2,$dc2);
  } else {
    $cage=0;
  }
  return $cage;
}


#
# moddate changes a date by N days forward or backward
#

sub moddate {
  my($indate,$delta)=@_;
  my($yc,$mc,$dc)=Decode_Date_US($indate);
  ($yc,$mc,$dc)=Add_Delta_Days($yc,$mc,$dc,$delta);
  return sprintf("%02d/%02d/%4d",$mc,$dc,$yc);
}


#
# prettyfaccciv prettifies a case type from the FACC civil system
#

sub prettyfaccciv {
  my ($year,$countynum,$rawcase);
  ($countynum,$rawcase)=@_;
  $year=substr($rawcase,0,2);
  if ($year<$PIVOTYEAR) {
    $year+=2000;
  } else {
    $year+=1900;
  }
  ;
  return "$countynum-$year-".substr($rawcase,8,2)."-".substr($rawcase,2,6);
}


#
# prettyfaccciv prettifies a case type from the FACC civil system
#

sub prettyfacccrim {
  my ($year,$countynum,$rawcase);
  ($countynum,$rawcase)=@_;
  $year=substr($rawcase,0,2);
  if ($year<$PIVOTYEAR) {
    $year+=2000;
  } else {
    $year+=1900;
  }
  ;
  return "$countynum-$year-".substr($rawcase,8,2)."-".substr($rawcase,2,6)."-".substr($rawcase,11,1);
}



sub urlencode {
  my($str)=@_;
  $str =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
  return $str;
}

sub urldecode {
  my($str)=@_;
  $str =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
  return $str;
}


#
# Timestamp returns the current timestamp, also updates all the time & date globals
#
sub timestamp {
  ($YEAR,$MONTH,$DAY)=Today();
  ($HOUR,$MINUTE,$SECOND)=Now();
  $MTEXT=monthname($MONTH);
  $TODAY=sprintf("%02d/%02d/%02d",$MONTH,$DAY,$YEAR);
  my($evy,$evm,$evd)=Add_Delta_Days($YEAR,$MONTH,$DAY,-10);
  $EVTDATE=sprintf("%02d/%02d/%02d",$evm,$evd,$evy);
  $SQLEVTDATE=sprintf("%02d/%02d/%04d",$evm,$evd,$evy);
  $NOW=sprintf("%02d:%02d:%02d",$HOUR,$MINUTE,$SECOND);
  $M2=sprintf("%02d",$MONTH);
  $D2=sprintf("%02d",$DAY);
  $TIMESTAMP="$TODAY $NOW";
  return $TIMESTAMP;
}




sub logQuery {
	my $query = shift;
	my $other = shift;
	my $logFile = shift;

	if (!defined($logFile)) {
		$logFile = "/tmp/query.log";
	}

	if (!open (LOGFILE, ">>$logFile")) {
		print STDERR "Error opening query log file '$logFile': $!\n";
		return;
	}
	print LOGFILE "$query\n\n";
	if (defined($other)) {
		print LOGFILE "$other\n\n";
	}
	close LOGFILE;
}

### BEGIN MAIN PROGRAM BODY ###

timestamp();
if (-d "/usr/local/icms") {
  $UTILSFILEPATH="/usr/local/icms/etc";
} else {
  $UTILSFILEPATH="../etc";
}

#loadconffile();

if (!(defined($ENV{'PWD'}) && $ENV{'PWD'}=~/caseX|exp/) &&  !($0=~/caseX|exp/)) {
  $ROOTPATH="/case";
} else {
  $ROOTPATH="/caseX";
}

1;
