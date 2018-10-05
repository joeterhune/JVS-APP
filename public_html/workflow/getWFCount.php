<?php 

require_once("../php-lib/common.php");
require_once("../php-lib/db_functions.php");
require_once("../icmslib.php");
require_once("wfcommon.php");

$dbh = dbConnect("icms");
$user = $_SESSION['user'];

$myqueues = array($user);
getSubscribedQueues($user, $dbh, $myqueues);
$sharedqueues = array();
getSharedQueues($user, $dbh, $sharedqueues);
$allqueues = array_merge($myqueues,$sharedqueues);
$wfcount = getQueues($queueItems,$allqueues,$dbh);

$dbh = null;

echo $wfcount;