<?php
require_once("../php-lib/common.php");
require_once("../php-lib/db_functions.php");
require_once("../workflow/wfcommon.php");

checkLoggedIn();

require_once('Smarty/Smarty.class.php');

//require_once('FirePHPCore/fb.php');
//$firephp = FirePHP::getInstance(true);
//$firephp->setEnabled(true); 

extract($_REQUEST);

$user = $_SESSION['user'];
$fdbh = dbConnect("icms");

$myqueues = array($user);
$sharedqueues = array();

getSubscribedQueues($user, $fdbh, $myqueues);
getSharedQueues($user, $fdbh, $sharedqueues);
$allqueues = array_merge($myqueues, $sharedqueues);

createTab("My Case Watchlist", "/case/watchlist/showWatchList.php", 1, 1, "index");

$queueItems = array();

$wfcount = getQueues($queueItems, $allqueues, $fdbh);

$email = getEmailFromAD($user);

$dbh = dbConnect("icms");

// First get the listing of cases
$query = "
    select
        casenum as CaseNumber,
        casestyle as CaseStyle
    from
        watchlist
    where
        email = :email
";
$watchList = array();
getData($watchList, $query, $dbh, array('email' => $email));

$smarty = initSmarty();

$smarty->assign('watchList', $watchList);
$smarty->assign('wfCount', $wfcount);
$smarty->assign('active', "index");
$smarty->assign('tabs', $_SESSION['tabs']);

$smarty->display('top/header.tpl');
echo $smarty->fetch('watchlist/showWatchList.tpl');