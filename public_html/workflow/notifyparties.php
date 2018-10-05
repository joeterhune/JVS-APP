<?php
# notifyparties is called by the calendar/scheduling function 
# to send an e-mail to the parties on a case, and any "subscribers"
# doesn't do anything but log the post event...
#
$ucn=$_REQUEST[ucn];
$subject=$_REQUEST[subject];
$message=$_REQUEST[message];
$ts=date("m/d/Y h:i:s A");
file_put_contents('php://stderr',"$ts: notifyparties: ($ucn,$subject,$message)\n");
echo "OK";
?>