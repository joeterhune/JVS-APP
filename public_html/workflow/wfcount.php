<?php
# wfcount.php - return # of pending item's a a users's workflow queue,
# and other subscribed queues
require_once("../php-lib/db_functions.php");
require_once("wfcommon.php");

include "../icmslib.php";

//
//if ($argv[1]) {
//    $USER=$argv[1];
//}
if ($USER=="") {
   echo "Error: no userid specified!";
   exit;
}
$dbh = dbConnect("icms");

$myqueues = array($USER);
$sharedqueues = array();

getSubscribedQueues($USER, $dbh, $myqueues);
getSharedQueues($USER, $dbh, $sharedqueues);
$allqueues = array_merge($myqueues,$sharedqueues);

$queueItems = array();

$wfcount = getQueues($queueItems,$allqueues,$dbh);

$result = array();
$result['status'] = "Success";
$result['wfcount'] = $wfcount;

header('application/json');
print json_encode($result);
exit;
?>