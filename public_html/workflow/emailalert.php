<?php

# emailalert.php - send an e-mail alert to all parties notifying of a 
#                  event schedule, reschedule
# (or cancellation?  should add)

# ucn, event date, time, location, type (new event|reschule) | old date, time location (if a reschedule)

include "../icmslib.php";
include "../caseinfo.php";


# get_user_email gets the user's email address from the workflow users list;
# if it can't find, it gracefully degrades to $user$emailhost
#

function get_user_email($user,$icmsdb,$emailhost) {
   if (strpos($user,"@")!==false) { return $user; } # user IS email
   # (true for alerts from schedcase-save.php)
   $json=sqlgetonep($icmsdb,"select json from config where module='config' and user=?",array($user));
   $config=json_decode($json);
   list($email)=explode(",",$config->{email}); # use first email address.
   if ($email=="") { # they didn't set one--degrade gracefully
      $email="$user$emailhost";
   }
   return $email;
}

#
# get_all_emails_easy gets all email addresses for a case, just from a UCN
#                    
#

function get_all_emails_easy($ucn,$icmsdb,$emailhost) {
   $countynum=substr($ucn,0,2);
   $dbh=db_connect($countynum);
   $counties=load_conf_file("county_db_info.json");
   $dbtype=$counties->{$countynum}->{database_type};
   $dbtype=strtolower($dbtype);
#   $case=case_base_info($icsmdb,$dbh,$ucn,$dbtype);
#$case[id];
   $id=find_case_id($icmsdb,$dbh,$ucn,$dbtype);
   # was 
   $ccisucn=sqlgetonep($icmsdb,"select ucn_src from search where ucn=? top 1",array($ucn));
   $schedb=db_connect("eservice");
   $parties=get_parties($dbh,$schedb,$id,$dbtype,$unused);
   if (count($parties)>0) {
      foreach ($parties as $party) {
         $disdate=$party[12];
         if ($disdate!="") { next; }
         $email=$party[7];
         if ($email!="") { $allemails=add_email($allemails,$email); }
      }
   }
   $attorneys=get_attorneys($dbh,$schedb,$id,$dbtype,$ccisucn); 
   # gets clerk, bar, and portal
   if (count($attorneys)>0) {
      foreach ($attorneys as $atty) {
         # NOTE: no dismissal date for attorneys in this array?
         $clerkemail=$atty[6];
         $baremail=$atty[7];
         $portalemails=$atty[8];
         if ($portalemails!="") { # if present, ignore clerk and bar
             $portalarr=explode(",",$portalemails);
             foreach ($portalarr as $portalemail) {
                $allemails=add_email($allemails,$portalemail);
             }
         } else {
            if ($clerkemail!="") { $allemails=add_email($allemails,$clerkemail); }
            if ($baremail!="") { $allemails=add_email($allemails,$baremail); }
         }
      }
   }
   # 
   # NOW, get email addresses for all folks who've subscribed to alerts 
   #      for this division
   #
   $div=sqlgetonep($icmsdb,"select division from search where ucn=? limit 1",array($ucn));
   $division="$countynum-$div";
   $setlist=sqlarrayp($icmsdb,"select user,json from config where module='config'",array());
   if (count($setlist)>0) {
      foreach ($setlist as $set) {
         list($user,$json)=$set;
         $stuff=json_decode($json);
         list($email)=explode(",",$stuff->{email}); # use first email address.
         if ($email=="") { # they didn't set one--degrade gracefully
            $email="$user$emailhost";
         }
         $alerts=$stuff->{alerts};
         if ($alerts && strpos($division,$alerts)!==false) {  # add this email...
            $allemails=add_email($allemails,$email);
         }
      }
   }
   $allemails=str_replace(";",",",$allemails);
   return substr($allemails,0,-1); # remove final ;
}


#
# MAIN PROGRAM
#
if (php_sapi_name()=="cli") {
   # populate $_REQUEST from command line
   for ($i=0;$i<count($argv);$i++) {
      $param=$argv[$i];
      list($key,$val)=explode("=",$param);
      $val=urldecode($val);
      $_REQUEST[$key]=$val;
   }
}
$ucn=$_REQUEST[ucn];
$evdate=$_REQUEST[event_dt];
$evtime=$_REQUEST[event_tm];
$location=$_REQUEST[location];
$isresched=$_REQUEST[is_reschedule];
$iscancel=$_REQUEST[is_cancel];
$isdenied=$_REQUEST[is_denied];
$sendemail=$_REQUEST[send_email];
$name=$_REQUEST[name];
$phone=$_REQUEST[phone];
if ($isresched==1) {
   $oldevdate=$_REQUEST[old_event_dt];
   $oldevtime=$_REQUEST[old_event_tm];
   $oldlocation=$_REQUEST[old_location];
}
$user=$_REQUEST[author];
if (!$user) {
   $user=strtolower($_SESSION['user']);
}
$icmsdb=db_connect("icms");
$emailhost=emailhost();
$useremail=get_user_email($user,$icmsdb,$emailhost);
$ts=date("m/d/Y h:i:s A");
logerr("emailalert: ($ucn,$evdate,$evtime,$location,isresched=$isresched,iscancel=$iscancel,is_denied=$isdenied,$oldevdate,$oldevtime,$oldlocation,$user,$emailhost,$name,$phone,sendemail=$sendemail)");
if ($ucn=="" || $evdate=="" || $evtime=="" || $location=="") {
   echo "ERROR: missing arguments ($ucn,$evdate,$evtime,$location)";
   exit;
}
$evdate=pretty_date($evdate);
$evtime=pretty_timeX($evtime);
$oldevdate=pretty_date($oldevdate);
$oldevtime=pretty_timeX($oldevtime);

$division=get_division_text($ucn);
$case_style=get_case_style_easy($ucn);
if ($name=="" || $phone=="") {
   list($nameX,$phoneX)=sqlgetonerowp($icmsdb,"select name,phone from users where userid=?",array($user));
   if ($nameX!="") { $name=$nameX; }
   if ($phoneX!="") { $phone=$phoneX; }
}
if ($isresched=="1") {
   $subject="HEARING RE-SCHEDULED FOR CASE $ucn";
   $message="A hearing set for case\n\n$case_style\n$ucn\n\nin the $division division has been RE-SCHEDULED FROM $oldevdate $oldevtime at $oldlocation TO $evdate $evtime at $location. An order setting this new hearing will follow. If you have any questions, please contact $name and $useremail or $phone";
   $note="HEARING RE-SCHEDULED: FROM $oldevdate $oldevtime $oldlocation TO $evdate $evtime $location";
} elseif ($iscancel=="1") {
   $subject="HEARING CANCELLED FOR CASE $ucn";
   $message="The hearing formerly set for case\n\n$case_style\n$ucn\n\nin the $division division for $evdate $evtime at $location has BEEN CANCELLED. An order reflecting this cancellation MAY follow. If you have any questions, please contact $name and $useremail or $phone";
   $note="HEARING CANCELLED: $evdate $evtime $location";
} elseif ($isdenied=="1") {
   $subject="HEARING DENIED FOR CASE $ucn";
   $message="The hearing request for case\n\n$case_style\n$ucn\n\nin the $division division for $evdate $evtime at $location has BEEN DENIED. If you have any questions, please contact $name and $useremail or $phone";
   $note="HEARING CANCELLED: $evdate $evtime $location";
} else {
   $subject="HEARING SET FOR CASE $ucn";
   $message="A hearing has been set for case\n\n$case_style\n$ucn\n\nin the $division division ON $evdate $evtime at $location. An order setting this hearing will follow. If you have any questions, please contact $name at $useremail or $phone.";
   $note="HEARING SET: $evdate $evtime $location";
}
##################################
# add case note for this case...
#################################
$noteuser=$USER;
if ($USER=="") { $noteuser="e-service"; }
$sql="insert into docketnotes (casenum,userid,date,note) values (?,?,CURRENT_TIMESTAMP,?)";
sqlexecp($icmsdb,$sql,array($ucn,$noteuser,$note));
#
# send e-mail alert to all parties and alert subscribers...
#
if ($sendemail==1) {
   $all_emails=get_all_emails_easy($ucn,$icmsdb,$emailhost);
   $headers = "From: eservice$emailhost\r\nReply-To: $name <$useremail>\r\n";
   if ($SETTINGS[WORKFLOW]=="LIVE") {
      # send to the $all_emails list...
      $to="$all_emails,$useremail";
      mail($to,$subject,$message,$headers);
   } else if ($SETTINGS[WORKFLOW]=="TEST") {
      $to=$useremail;
      $subject.=" (TEST)";
      $message="NOTE: This ICMS3 system is in TEST mode; this e-mail was therefore just sent to you and not to the e-mail addresses associated with this case: $all_emails\n\n$message";
      mail($to,$subject,$message,$headers);
   } else {
     echo "ERROR: WORKFLOW setting needs to be set for this server (TEST or LIVE)"; exit;
   }
}
echo "OK";
?>