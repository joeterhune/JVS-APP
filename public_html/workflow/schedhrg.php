<?php

# schedhrg - if is_accepted=1, schedules a hearing,
#            then triggers emailalert.php to alert all interested parties
#            if is_accepted=0, e-mails the requestor that the request was denied
#            in either case, marks this workflow item as finished...

include "../icmslib.php";

$accepted=$_REQUEST[accepted];
$docid=$_REQUEST[doc_id];
$email=$_REQUEST[email];
$division=$_REQUEST[division];
$ucn=$_REQUEST[ucn];
$blockid=$_REQUEST[block_id];
$dscr=$_REQUEST[dscr];
$dscr=urlencode($dscr);
$ealert=$_REQUEST[ealert];
if (!$ucn) {
   echo "Error: $ucn required!";
   exit;
}
if ($accepted==1) { # save this 
   logerr("schedhrg.php: ($accepted,$docid,$email,$division,$ucn,$blockid,$dscr,$ealert)\n");
   logerr("schedhrg.php: calling /var/www/icms/calendar/save_block_ext.cgi email=$email division=$division ucn=$ucn block_id=$blockid dscr=$dscr ealert=1");
   $res=`/var/www/icms/calendar/save_block_ext.cgi email=$email division=$division ucn=$ucn block_id=$blockid dscr="$dscr" ealert=1`;
   list($x,$json)=explode("\r\n\r\n",$res);
   $rawjson=$json;
   $json=json_decode($json);
   $url="";
   if ($json->{error}) {
      echo "ERROR: ",$json->{error};
      exit;
   } elseif ($json->{success}) {
     $icmsdb=db_connect("icms");
     sqlexecp($icmsdb,"update workflow set finished=1 where doc_id=?",array($docid));     
     sqlexecp($icmsdb,"update workqueues set lastupdate=now() where queue=?",array($division));
     $url=$json->{success_ealert};
     list($url,$data)=explode("?",$url);
     $data.="&author=$USER";
     $data=str_replace(" ","%20",$data);
     $data=str_replace("&"," ",$data);
     $res=`php /var/www$url $data`; # call this here
     echo "$res"; 
   } else {
      echo "ERROR: $res";
   }
} else {  # DENIED
     $icmsdb=db_connect("icms");
     # remove from queue
     sqlexecp($icmsdb,"update workflow set finished=1 where doc_id=?",array($docid));     
     sqlexecp($icmsdb,"update workqueues set lastupdate=now() where queue=?",array($division));
     # get hearing info from the doc_id
     $data=sqlgetonep($icmsdb,"select data from workflow where doc_id=?",array($docid));
     $data=json_decode($data);
     $location=urlencode($data->{location});
     $evdate=urlencode($data->{date});
     $evtime=urlencode($data->{time});
     # this will send back to the denier if we're in test mode...
     $res=`php /var/www/icms/workflow/emailalert.php ucn=$ucn event_dt=$evdate event_tm=$evtime location=$location is_denied=1 send_email=1 author=$USER`;
     echo "OK";
}
?>