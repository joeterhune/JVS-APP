#!/usr/bin/perl 
#
# 08/25/10 lms testing out connection to pbso IMACS database/view 
# 10/25/10 lms change 'in custody' to 'in jail'
# 11/29/10 lms don't attempt pbso search if there's no database connection
# 03/23/11 lms New way to get PBSO booking photos (from pbso).
# 06/17/11 lms Found out way to determine 'Escaped' inmate, so expanding on what 
#              in custody means... In Custody includes:  in a cell, waiting for a cell,
#              in transit to main detention center, and in the MDC intake area. 
#              If there is a release date, the inmate is Released.
#              Will show:  PBSO Custody, Escaped, House Arrest, Weekender, or Released date.
#              Also, now allowing '*' for name when user wants all inmates.
# 07/28/11 lms PBSO photos not showing in Firefox - database call returns backslashes when it shouldn't.
# 

BEGIN {
   use lib "$ENV{'PERL5LIB'}";
}

use strict;
use CGI;
use ICMS;
use POSIX;
use PBSO;
use DB_Functions qw (
    dbConnect
    getData
    getDataOne
    getSubscribedQueues
	getSharedQueues
	getQueues
);
use Common qw (
    dumpVar
    doTemplate
    returnJson
    $templateDir
    createTab
    getUser
    getSession
    checkLoggedIn
);

checkLoggedIn();

#
#  MAIN PROGRAM
#
my $info=new CGI;
my $user = getUser();

my %params = $info->Vars;

my $fdbh = dbConnect("icms");

my @myqueues = ($user);
my @sharedqueues;

my $url = "/cgi-bin/case/PBSO/pbsosearch.cgi";
my $count = 0;
foreach my $p(keys %params){
	if($count < 1){
		$url .= "?" . $p . "=" . $params{$p};
	}
	else{
		$url .= "&" . $p . "=" . $params{$p};
	}
	$count++;
}

createTab("PBSO Search Results", $url, 1, 1, "index");
my $session = getSession();

getSubscribedQueues($user, $fdbh, \@myqueues);
getSharedQueues($user, $fdbh, \@sharedqueues);
my @allqueues = (@myqueues, @sharedqueues);
my %queueItems;

my $wfcount = getQueues(\%queueItems, \@allqueues, $fdbh);

my $dbview = $view;
my $photosView = $ipview;

my $query;

my $name = $params{'name'};
my $mugshots = $params{'mugshots'};
my $custody = $params{'custody'};
my $type="";

my $tname=tmpnam();
my $tname2="/var/www/html$tname.txt";

my $limit=15000;	# limit of returned cases to show
my $photolimit=500; # limit number of photos to show

$name=~tr/a-z/A-Z/;
$name=clean($name);
$name=$info->param("name");
$name=trim($name);
$name=~tr/a-z/A-Z/;
$name=~s/'//g;

# if * is passed for name, user wants all.
sub buildnamequery {
    my ($name,$lname,$rest,$j,$fname,$mname);
    my $wascomma=0;
    $name=$_[0];
    if ($name eq '*') {
        return " 1=1 ";
    }
    
    #$i=index($name,",");
    if ($name =~ /,/) {  # comma found, break into parts
        $wascomma++;
        ($lname, $rest) = split(/,/, $name, 2);
        $lname =~ s/^\s+//g;
        $lname =~ s/\s$//g;
        
        $rest =~ s/^\s+//g;
        $rest =~ s/\s$//g;;
        $rest =~ s/\s+/ /g;
        ($fname, $mname) = split(/\s+/, $rest, 2);
    } else {
        $fname=$mname="";
        $lname=$name;
    }
    
    my $fstr = "";
    my $mstr="";
    my $lstr = "";
    if ($fname ne "" or $wascomma) {
        $lstr="inmatelast like '$lname'";
        if ($mname ne "") {
            $fstr="and inmatefirst like '$fname'";
            $mstr="and inmatemiddle like '$mname%'";
        } else {
            $fstr="and inmatefirst like '$fname%'";
        }
    } else {
        $lstr="inmatelast like '$lname%'";
    }
    return " $lstr $fstr $mstr ";		     		   
}

# build the first part of the result query
sub getResQry {
    # this should have returned with the photolocation always using forward slash, but didn't.  
	# probably because it's in the string... so, for Firefox, will have to fix in line...
    my $qry= qq{
        select
            distinct(bookingdate) as BookingDate,
            convert(varchar(10),bookingdate,101) as FormattedBookingDate,
            inmatename as InmateName,
            inmateid as InmateID,
	 	    convert(varchar(10),birthdate,101) as DOB,
            bookingid as BookingID,
	 	    convert(varchar(10),releasedate,101) as ReleaseDate,
			datediff(d,BookingDate,ReleaseDate) as DaysServed,
			datediff(d,BookingDate,getdate()) as ServedSoFar,
			race as Race,
            inmatestatus as Status,
            isnull((
                select
                    top 1 'http:' + REPLACE(photolocation, '\','/')
                from
                    $photosView
                where
                    bookingid = $dbview.bookingid
                    and inmateid = $dbview.inmateid
                    and front=1
                    and activephoto=1),
                'http://www.pbso.org/bkimages/star/star.jpg')  as PhotoURL,
            assignedcellid as AssignedCellID
        from
            $dbview
        where };
	return $qry;
}

sub getCustodyPhrase {
	my($cust)=@_;
	my $p;
	if($cust eq "incustody") {
        $p = qq{
            and releasedate is null
            and (assignedcellid='' or assignedcellid not in ('ESCAPED','IN-HOUSE ARREST', 'WEEKENDER OUT'))
        };
    } elsif($cust eq "inhouse") {
        $p = qq{
            and releasedate is null
            and assignedcellid='IN-HOUSE ARREST'
        };
    } elsif($cust eq "escaped") {
        $p = qq {
            and releasedate is null
            and assignedcellid='ESCAPED'
        };
    } elsif($cust eq "weekender") {
        $p = qq{
            and releasedate is null
            and assignedcellid='WEEKENDER OUT'
        };
    } elsif($cust eq "released") {
        $p = qq{
            and releasedate is not null
        };
    }	
	return $p;
}

# here we go!

# test the pbso connection.  if can't connect, don't do anything!
my $pbsoconn = dbConnect("pbso2");
if(!defined($pbsoconn)) {
    print $info->header();
	print "No connection can be made to the PBSO database at this time.  Please try later.<br/>";
	print "Press the browser Back button to continue.";
	exit;
}

if($name eq "") {
	print $info->header();
	print "Please enter a name or a jacket number and try again...";
	print "Press the browser Back button to continue.";	
	exit;	
}

my $resqry;

if($name=~/^\d+$/){
	# ------------------------  Jacket Search  ----------------------------
    $type = "Jacket";
	if (length($name)<3 and $name ne '*') {
		print $info->header;
		print "The jacket number must be at least 3 characters long.";
		exit;
	} 
	
    my $cntqry = qq {
        select
            count(distinct bookingid) as IdCount
        from
            $dbview
        where
            inmateid like '$name%'
    };
	$cntqry.=getCustodyPhrase($custody);

    my $rowCount = getDataOne($cntqry,$pbsoconn);
	if($rowCount->{'IdCount'} > $limit) {
		print $info->header();
		print "There are $rowCount->{'IdCount'} jacket numbers that match this jacket search ($name).<br/>
			   The maximum allowable number of jackets to show for this search is $limit.<br/>
			   Please refine your search and try again.<br/>";
		exit;
	}
    $resqry = getResQry();
	$resqry .= qq{
        inmateid like '$name%'
    };
    
	$resqry .= getCustodyPhrase($custody);
    $resqry .= qq{
        order by
            inmateid,
            bookingdate desc
    };
} else {
	#
	# ------------------------  Name Search  ----------------------------
	$type="Name";	
	if (length($name)<3 and $name ne '*') {
		print $info->header;
		print "The search name must be at least 3 characters long.";
		exit;
	}	
    my $namestr = buildnamequery($name);
	my $cntqry = qq{
        select
            count(distinct bookingid) as IdCount
        from
            $dbview
        where
    };
    $cntqry .= $namestr;
	$cntqry .= getCustodyPhrase($custody);
    
    my $rowCount = getDataOne($cntqry,$pbsoconn);
	if($rowCount->{'IdCount'} > $limit) {
		print $info->header();
		print "There are $rowCount->{'IdCount'} names that match this name search ($name).<br/>
			   The maximum allowable number of names to show for this search is $limit.<br/>
			   Please refine your search and try again.<br/>";
		exit;
	}
    
    $resqry = getResQry();
	$resqry .= $namestr;
	$resqry .= getCustodyPhrase($custody);
    $resqry .= qq{
        order by
            inmatename,
            bookingdate desc
    };	 
}

my @list;

getData(\@list,$resqry,$pbsoconn);

my $rows = scalar(@list);

my $dtitle1 = qq{Sarasota County Sheriff's Office Booking Information<br/>for $type matching: $name};

if($custody eq "incustody") {
    $dtitle1 .= " and In PBSO Custody ";
} elsif($custody eq "inhouse") {
    $dtitle1.=" and Under House Arrest ";
} elsif($custody eq "escaped") {
    $dtitle1.=" and Escaped ";
} elsif($custody eq "weekender") {
    $dtitle1.=" and Weekender Out ";
} elsif($custody eq "released") {
    $dtitle1.=" and Released From PBSO Custody ";
}	
	
if ($mugshots eq "on" and $rows > $photolimit) { 
   $dtitle1.="<br/>Photos are not included when there are more than $photolimit results.<br/>";
}

my %data;
$data{'title'} = $dtitle1;

if (scalar(@list)) {
	foreach my $record (@list) {
		# replace \ with / in photoid - should have been done with the database call!
		$record->{'PhotoURL'} =~ s/\\/\//g;
		$record->{'Age'} = getageinyears($record->{'DOB'});
		my $ind = index($record->{'Age'}, '.');
		if($ind>-1) {
            $record->{'Age'} = substr($record->{'Age'},0,$ind);
        }
        if (defined($raceMap{$record->{'Race'}})) {
            $record->{'Race'} = $raceMap{$record->{'Race'}};
        } else {
            $record->{'Race'} = "Unknown";
        }
        
		my $photo="&nbsp;";
		if ($mugshots eq "on" and $rows <= $photolimit) {
			$photo = qq{
                <a href="$record->{'PhotoURL'}">
                <img alt="booking photo dated $record->{'FormattedBookingDate'}"
                src="$record->{'PhotoURL'}" width="36" height="46">
                </a>
            };
		}	
		$record->{'JacketLink'} = qq{
            <a class="mjidLink" href="/cgi-bin/case/pbsojview.cgi?jacket=$record->{'InmateID'}">
                $record->{'InmateID'}
            </a>
        };
		$record->{'BookingLink'} = qq {
            <a class="bookingLink" href="/cgi-bin/case/pbsobview.cgi?jacket=$record->{'InmateID'}&booking=$record->{'BookingID'}">
                $record->{'BookingID'}
            </a>
        };
		if($record->{'DaysServed'} < 0){
            $record->{'DaysServed'} = 0;
        }
		if($record->{'ReleaseDate'} eq "") {
			$record->{'DaysServed'} = $record->{'ServedSoFar'};
			if ($record->{'AssignedCellID'} eq "ESCAPED") {
                $record->{'ReleaseDate'} = qq{
                    <span style="color: red">Escaped</span>
                };
            } elsif ($record->{'AssignedCellID'} eq "IN-HOUSE ARREST") {
                $record->{'ReleaseDate'} = qq{
                    <span style="color: red">House Arrest</span>
                };
            } elsif ($record->{'AssignedCellID'} eq "WEEKENDER OUT") {
                $record->{'ReleaseDate'} = qq{
                    <span style="color: red">Weekender Out</span>
                };
            } else {
                $record->{'ReleaseDate'} = qq{
                    <span style="color: red">PBSO Custody</span>
                };
            }
		}
		if($record->{'ReleaseDate'} eq '01/01/1900') {
            $record->{'ReleaseDate'} = $record->{'FormattedBookingDate'};
        }								
		if ($record->{'Status'} eq "") {
            $record->{'Status'}="&nbsp;";
        }
	}
    $data{'bookings'} = \@list;
    
    $data{'wfCount'} = $wfcount;
    $data{'active'} = "index";
	$data{'tabs'} = $session->get('tabs');
	
	print $info->header;
	doTemplate(\%data, "$templateDir/top", "header.tt", 1);
    doTemplate(\%data,"$templateDir/PBSO/", "pbsoResults.tt",1);
    exit;
} else {
	print $info->header();
	print "No PBSO cases were found that match the entry $name";
	if($custody eq "incustody") {
        print " that are in PBSO custody.<br/>";
    } elsif($custody eq "inhouse") {
        print " that are under house arrest.<br/>";
    } elsif($custody eq "escaped") {
        print " that have escaped.<br/> ";
    } elsif($custody eq "weekender") {
        print " that are weekender out.<br/> ";
    } elsif($custody eq "released") {
        print " that have been released from PBSO custody.<br/> ";
    } else {
        print ".<br/>";
    }
	exit;
}