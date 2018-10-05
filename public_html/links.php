<?php 

require_once("php-lib/common.php");
require_once("php-lib/db_functions.php");
require_once('Smarty/Smarty.class.php');
require_once("workflow/wfcommon.php");

checkLoggedIn();

$config = simplexml_load_file($icmsXml);

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);

$user = $_SESSION['user'];
$fdbh = dbConnect("icms");

$myqueues = array($user);
$sharedqueues = array();

getSubscribedQueues($user, $fdbh, $myqueues);
getSharedQueues($user, $fdbh, $sharedqueues);
$allqueues = array_merge($myqueues, $sharedqueues);
$queueItems = array();

$wfcount = getQueues($queueItems, $allqueues, $fdbh);

$smarty->assign('wfCount', $wfcount);
$smarty->assign('active', "links");
$smarty->display('top/header.tpl');
$smarty->display('top/links.tpl');