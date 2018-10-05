#!/usr/bin/perl
#
# icmssearch.cgi - 	searches the icms flags database first, looking for all
#			case numbers with a particular flag, then Banner Case
#			Search Function

BEGIN {
	use lib $ENV{'PERL5LIB'};
};

use strict;
use CGI;
use ICMS;
use POSIX;
use Showcase qw (
    @SCINACTIVE
    $NOTACTIVE
    @SCACTIVE
    $ACTIVE
);
use Common qw (
    dumpVar
    inArray
);
use DB_Functions qw (
	dbConnect
	getData
	getDataOne
	inGroup
	ldapConnect
);

sub casenumtoucn {
    my($casenum)=@_;
    my $x=substr($casenum,0,4). "-" . substr($casenum,4,2). "-" .substr($casenum,6,6);
    if (substr($casenum,12,1) ne "") {
		$x.="-".substr($casenum,12);
    }
    return $x;
}

my @casesicms;
my $results;

# Combine Banner and Showcase inactive codes
my @FULLINACTIVE = (@INACTIVECODES,@SCINACTIVE);

# if more than this, tell user to refine search.
my $limit=17500;

#
#  MAIN PROGRAM
#
my $info=new CGI;

# flag if this user is a SECRET group user - can see adoptions, termination of
# parental rights, and tuberculosis cases
my $ldap = ldapConnect();
my $secretuser = inGroup($info->remote_user(),'CAD-ICMS-SEC',$ldap);
my $sealeduser = inGroup($info->remote_user(),'CAD-ICMS-SEALED',$ldap);

print $info->header();

my %params = $info->Vars;

# Since flagtype comes from a multi-select, it'll be an array
my @flags = $info->param('flagtype');
my $div = $params{'division'};
my $startDate = $params{'startDate'};
my $endDate = $params{'endDate'};
my $active=$params{'active'};
my $lev=$params{'lev'};

# Do we need to get all flag types?
my $allFlagTypes = 0;
foreach my $ft (@flags) {
	next if ($ft ne 'all');
	$allFlagTypes = 1;
	last;
}

if ($lev=="") {
	$lev=2;
}

my $excludesecret = qq {
    and cdbcase_ctyp_code not in ('AD','AJ','TE','TP','TB')
};

my $excludesealed = qq {
   and cdbcase_sealed_ind <> 3
};

my $scexcludesecret = qq {
    and CaseType not in ('AD','AJ','TE','TP','TB')
};

my $scexcludesealed = qq {
    and Sealed = 'N'
};

my $tname=tmpnam();
my $tname2="/var/www/html$tname.txt";
my ($casenum,$ucn);

my $icmsconn = dbConnect("icms");

if(!defined($icmsconn)){
    print $info->header();
    print "The Flags/Case Notes database is not available at this time.<br/>";
    print "Press the browser Back button to continue.";
    exit;
}

my $dscr = "All";
my $dates = "All";
my $showdiv = "";

print $info->header();
print "Finding icms database case info...<br/>";

#  Pull from icms database first.
my $query = qq{
	select
		distinct(casenum)
	from
		flags
};

if(!$allFlagTypes) {
    # build flagtype string
	my $inString = join(",", @flags);

	$query .= qq {
		and flagtype in ($inString)
	};

    $dscr = "unknown";
    if(@flags eq 1) {
	    my $query = qq {
			select
			    dscr as Description
			from
			    flagtypes
			where
			    flagtype in ($inString)
		};
		my @flagDescriptions;
	    getData(\@flagDescriptions,$query,$icmsconn);
	} else {
	    $dscr = "multiple selected";
	}
}

my $sd;
my $ed;
my $q;
if(($sd ne "all") && ($ed ne "all")) {
    $q .= "and date >= '$sd' and date <= '$ed' ";
    $dates = (substr $sd,5,2)."/".(substr $sd,8,2)."/".
	(substr $sd,0,4)." through ". (substr $ed,5,2)."/".(substr $ed,8,2)."/".
	(substr $ed,0,4);
    }

$q .= " order by casenum";

@casesicms=sqllist($q,undef,$icmsconn);

if ($div eq "") {
    $showdiv = "Not Assigned";
} elsif ($div eq "all") {
    $showdiv = "All";
} else {
    $showdiv = $div;
}

$results = scalar @casesicms;

if($results == 0) {
    print "<br/><big>There are currently no cases that meet the search ".
	"criteria for Flagged Cases.<br/><br/>";
    print "Requested flag: $dscr<br/><br/>Division: $showdiv<br/><br/>Flagged ".
	"date range: $dates<br/><br/>";
    print "Press the browser Back button to continue.<br/></big>";
    exit;
}

if($results > $limit) {
    print "<big><br/>There are currently $results cases that meet the entered ".
	"search criteria for Flagged Cases, excluding the division.<br/><br/>";
    print "Requested flag: $dscr<br/><br/>Division: $showdiv<br/><br/>Flagged ".
	"date range: $dates<br/><br/>";
    print "This search is limited to $limit cases.<br/><br/>";
    print "Press the browser Back button and change the criteria to reduce ".
	"the number of resulting cases.<br/></big>";
    exit;
}

# get rid of hyphens in each and add XX where needed
foreach my $case (@casesicms) {
    $case =~ s/-//g;
    if(length($_)==13) {
	$_.="XX";
    }
}

# can't process more than 1000 elements at a time in the sql IN clause
my $p = 1000;
my $idstrings=1;
if($results > $p) {
    $idstrings = int($results/$p);
}

my $remainder = 0;
if($results > $p) {
    $remainder = $results%($p*$idstrings);
}

# build search strings - - - sql "in" clause is limited to 1000 elements
my $i;
my $j;
my $end;
my @inID;

my $scdbh = dbconnect("showcase-prod");

for ($i=0; $i < $results; $i=$i+$p ) {
    $end = $i + $p;
    if($end > $results) {
	$end = $results;
    }
    my $ids = "(";

    for ($j = $i; $j < $end; $j++) {
	my $casenum = $casesicms[$j];
	$ids.="'$casenum',";
    }
    chop($ids);
    $ids.=")";
    $inID[$i/$p]=$ids;
    }

    # build in phrases of search string
    # we know there's at least one string of ids
    my $inphrase = " cdbcase_id in ".$inID[0];
    my $scinphrase = " UCN in " . $inID[0];
    for ($i=1; $i < scalar @inID; $i++) {
	$inphrase .= " or cdbcase_id in ".$inID[$i];
	$scinphrase .= " or UCN in " . $inID[$i];
    }

    $inphrase = "(".$inphrase.")";
    $scinphrase = "(". $scinphrase . ")";

    dbdisconnect($icmsconn);

    print "About to get cases from the Clerk's database... <br/>";

    $q = qq {
	select
	    CaseNumber as caseid,
	    DivisionID as div,
	    CaseStyle as casedesc,
	    convert(varchar,FileDate,101) as filedate,
	    CaseType as ctype,
	    CaseStatus as status
	from
	    vCase
	where
	    $scinphrase
	    and Sealed <> 'Y'
    };

    if($div eq "all"){
		$q=$q;
    } elsif ($div eq "") {
		$q.=" and DivisionID is null ";
    } else {
		$q.=" and DivisionID='$div' ";
    }

	if(!$sealeduser) {
		$q.=$scexcludesealed;
    }

    if(!$secretuser) {
		$q.=$scexcludesecret;
    }

    $q.="order by CaseNumber";

    sqlHashArray($q,$scdbh,\@caselist);

    my @cases;
    # For now, take the data from sqlHashArray (an array of hash refs) and
    # put it into the "old" tilde-delimited format so I don't need to rewrite
    # all of that code right now.
    my $formatString = "%s~%s~%s~%s~%s~%s~%s";
    foreach my $case (@caselist) {
	my $add = 1;
	if ($active eq "true") {
	    # Only push them on if the code is active
	    if (inArray(\@FULLINACTIVE,$case->{status})) {
	        $add = 0;
	    }
	}
	if ($add) {
	    # Build the string and push it onto @cases if needed.
	    my $string = sprintf($formatString, $case->{caseid},
				 $case->{div},
				 $case->{casedesc},
				 $case->{filedate},
				 $case->{ctype},
				 $case->{status}
				 );
	    push(@cases,$string);
	}
    }

    print "Cases found: ".scalar @cases."<br/>";

    #
    #  Show the cases, retrieving the dates and descriptions from icms.
    #
    if (@cases) {
	# build the last activity date hash (couldn't do this within
        # the cdbcase query...)
	my %lastactivity;
        foreach (@cases) {
	    my($case,$divid,$desc,$date,$code,$status,$lactivity)=split '~';
		# Showcase
		my $query = qq {
		    select
		        convert(varchar,max(EffectiveDate),101)
		    from
		        vDocket
		    where
		        CaseNumber='$case'
		    };

		    ($lastactivity{$case})=sqllistone($query,$scdbh);
	    }

	$icmsconn = dbconnect("icms");
	open OUTFILE,">$tname2" or die "Nope!";
	print OUTFILE <<EOS;
DATE=
TITLE1=Flagged Case Search for Flag $dscr, Division $showdiv, Flagged Dates $dates
TITLE2=
VIEWER=bannerview.cgi
FIELDNAMES=Case #~Div~Name~Initial File~Age~Last Activity~Type~Status~Flags~Notes
FIELDTYPES=L~A~I~D~D~D~S~A~A~A
EOS
	my $cnt=1;
	foreach (@cases) {
	    my($case,$divid,$desc,$date,$code,$status)=split '~';
	    my $ladate='&nbsp;';  # for now...
	    if( defined $lastactivity{$case} ) {
		$ladate=$lastactivity{$case};
	    }

	    if ($case !~ /^50-/) {
		$ucn=casenumtoucn($case);
	    } else {
		$ucn = $case;
	    }
	    my $age = getage($date);
#	    print "$cnt - $ucn <br/>";
	    $cnt++;
	    my $query = qq {
		select
		    date,
		    dscr,
		    userid
	        from
		    flags a,
		    flagtypes b
		where
		    a.flagtype=b.flagtype
		    and casenum='$ucn'
		order by
		    date desc
	    };

	    my @list=sqllist($query,undef,$icmsconn);
	    my $dscrs = "";
	    if(scalar @list!=0){
		foreach(@list){
		    chomp;
		    my($d,$dscr,$user)=split '~';
		    my $showflag = $d.":".$user.":".$dscr;
		    if($dscr =~ /Action|Judge/) {
			$showflag = "<font color=red>".$showflag."</font>";
		    }
		    $dscrs.=$showflag.',<br/> ';
		}
		$dscrs=substr($dscrs,0,length($dscrs)-7);
	    }
	    # show casenotes, too
	    $query = qq {
		select
		    date,
		    note
		from
		    casenotes
		where
		    casenum='$ucn'
		order by
		    seq desc
	    };
	    my @listnotes=sqllist($query,undef,$icmsconn);
	    my $notes = "";
	    if(scalar @listnotes!=0){
		foreach(@listnotes){
		    chomp;
		    my($d,$note)=split '~';
		    my $shownote = $d.": ".$note;
		    $notes.=$shownote.',<br/> ';
		}
		$notes=substr($notes,0,length($notes)-7);
	    }
	    if ($ucn =~ /^50-/) {
		print OUTFILE "$ucn;scview.cgi~$divid~$desc~$date~$age~$ladate~$code~".
		    "$status~<font color=green>$dscrs</font>~$notes\n";
	    } else {
		print OUTFILE "$ucn~$divid~$desc~$date~$age~$ladate~$code~".
		    "$status~<font color=green>$dscrs</font>~$notes\n";
	    }
	}
	close OUTFILE;

	print <<EOF
<script language="javascript">
location.replace("/case/genlist.php?rpath=$tname.txt&lev=$lev&order=5");
</script>
EOF

    } else {
	if($active eq "true") {
	    print "<br><big>No active ";
	} else {
	    print "<br><big>No ";
	}

	print "flagged cases were found for flag $dscr in division ".
	    "$showdiv.<p>";
	if(($secretuser) && (!$sealeduser)) {
		print "(Note that sealed records were excluded from this ".
			"search.)";
	} else {
	    print "(Note that sealed records, adoptions, termination of ".
		"parental rights, and tuberculosis records were excluded ".
	        "from this search.)";
        }
	print "<br/><br/>Press the browser Back button to continue.<br/></big>";
        exit;
    }


    	dbdisconnect($bdbh);
	dbdisconnect($scdbh);
