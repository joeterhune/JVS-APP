<?php
# addorderfromcal.php - takes calendar data+form data and creates an
# already-filled-in order (we hope).

include "../icmslib.php";
include "../caseinfo.php";

#
# MAIN PROGRAM
#
# first snag what we're passed, storing in in our $data hash...
$ucn=$_REQUEST[ucn];
$data[ucn]=$ucn;
$data[event_date]=pretty_date($_REQUEST[event_dt]);  # need mm/dd/yyyy
$data[event_time]=pretty_timeX($_REQUEST[event_tm]); # need nn:nnam
$data[event_location]=$_REQUEST[location];
$formname=$_REQUEST["order"];
$data[formname]=$formname;
$queue=$_REQUEST[workqueue];    # not needed for ordergen, but...
$data[queue]=$queue;
$data[block_id]=$_REQUEST[block_id];  # not needed for ordergen, but...
$data[block_dscr]=$_REQUEST[evdescr]; # not needed for ordergen, but...
logerr("addorderfromcal: $ucn,$formname");
if ($_REQUEST[is_cancel]==1 || $_REQUEST[is_reschedule]==1) {
   # for now, no order for you...later use custom cancel and resched
   # (if user selects "generate order" checkbox on cancel and reschedule dialog
   logerr("addorderfromcal: (iscancel="+$_REQUEST[is_cancel]+",is_reschedule="+$_REQUEST[is_reschedule]+")");
   echo "OK";
   exit;
}   
if ($ucn!="" && $formname=="") { # no form specified=no order generated
   echo "OK";
   exit;
}
if ($ucn=="" || $formname=="") {
   echo "ERROR: need ucn and formname\n";
   exit;
}
# skipping send_email
# skipping is_reschedule (FOR NOW), should change form name and everything
# skippin def_order
# skipping parent_block_id
# skipping evtype


#
# get some form values from county_db_info...
#
$countynum=substr($data[ucn],0,2);
$data[countynum]=$countynum;
$counties=load_conf_file("county_db_info.json");
$data[county]=$counties->{$countynum}->{name};
$dbtype=$counties->{$countynum}->{database_type};
$data[database_type]=$dbtype;
$data[commserv_agency]=$counties->{$countynum}->{commserv_agency}; # contact point for community service.
$data[order_location]=$counties->{$countynum}->{order_location}; # city, county, state where order signed
$data[courthouse_address]=$counties->{$countynum}->{courthouse_address}; # physical address for courthouse (no zip)
$data[courthouse_mail_address]=$counties->{$countynum}->{courthouse_mail_address}; # mailing address for courthouse (with zip)
$data[clerk_phone]=$counties->{$countynum}->{clerk_phone}; # clerk's office phone #
$data[ada_phone]=$counties->{$countynum}->{ada_phone}; # ada contact phone #

# and from the SETTINGS DB...

$data[circuit]=get_setting("CIRCUIT");

#
# if this case had a previous set of parties used in a order, use them...
#
if (file_exists("/var/www/icmsdata/workflow/parties/$ucn.parties.json")) {
   $data[useaddress]="old";
} else {
   $data[useaddress]="clerk";
}

#
# generate the case style
#
$icms=db_connect("icms");
$dbh=db_connect($countynum);
$caseid=find_case_id($icms,$dbh,$ucn,$dbtype);
$parties=get_parties($dbh,"",$caseid,$dbtype,$unused);
$style=xml_case_style($ucn,$parties);
$data[parties]=$style;

# set the division
$data[division]=strtoupper(get_division_text($ucn));


#
# Now pull stuff from the form
#

# xmlfields looks for filled in stuff in $ucn.$formname.json; 
#    that stuff is already in $data as far as we go here.

# from the saved forme data, needsmail,mailedby,needsemail,emailedby, efiledby
# some of which would be blank or set appropriately dependent on 


# there's an "include_talking_to_judges" in xmlfields...
# and the judge and ja sig stuff, also blank at this point.

function get_tag_text($file,$tagname) {
   $i=stripos($file,"<$tagname>");
   if ($i===false) { return ""; }
   $j=$i+=strlen("<$tagname>");
   $k=stripos($file,"</$tagname>");
   $len=$k-$j;
   return substr($file,$j,$len);
} 

$data[formfile]="/var/icms/conf/orders/$data[formname].form.xml";
$file=file_get_contents($data[formfile]);
# meed formtitle,esigs required

$formtitle=get_tag_text($file,"title");
$data[formtitle]=$formtitle;
$data[esigs]=get_tag_text($file,"esigs");

#
# list blank signature files for wfshow to find..
#
foreach (explode(",",$data[esigs]) as $esig) {
   $lowsig=strtolower($esig);
   $data["${esig}_signature_file"]="/var/icms/conf/signatures/${lowsig}BlankSignature.png";
}

#
# save CC list to a file.
#
$clerkcclist=build_cc_list($icms,$data[ucn]);
save_party_address("/var/www/icmsdata/tmp/$ucn.$formname.clerkaddr.json",$clerkcclist);
# and as an element in $data...
$data[clerk_cc_cclist]=$clerkcclist;
$datajson=json_encode($data);
file_put_contents("/var/www/icmsdata/tmp/$ucn.$formname.json",$datajson);

#
# now create an XML file from all that so that wfshow.php can see it (and populate the signature field properly)
#
`/var/www/icms/orders/xmlgen.pl $ucn $formname 1`;  # final 1 means "don't generate a PDF"

# and now, let's create the order in the queue

$ftescape=urlencode($formtitle);
$creator=$_SERVER[PHP_AUTH_USER];
logerr("addorderfromcal.php: trying to run wfaddformorder");
$resp=`php /var/www/icms/workflow/wfaddformorder.php ucn=$ucn formname=$formname formtitle=$ftescape queue=$queue creator=$creator`;
logerr("addorderfromcal.php: ran it, response $resp");
if (substr($resp,0,2)!="OK") { 
   echo "ERROR: $resp\n";
   exit;
} else {
   echo "OK";
}
?>