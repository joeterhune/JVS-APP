<?php

error_reporting (E_ALL ^ E_NOTICE);
ini_set('display_errors','On');

require_once("../php-lib/common.php");
require_once("../php-lib/db_functions.php");
require_once("../icmslib.php");
require_once("../php-lib/functions.php");

require_once('Smarty/Smarty.class.php');

//require_once('../../Smarty/Smarty.class.php');
require_once("../workflow/wfcommon.php");
checkLoggedIn();
onlyAdmins();
// Init Smarty Template manager
//$smarty = new Smarty;
//$smarty->setTemplateDir("/usr/local/icms/templates");
//$smarty->setCompileDir("/var/jvs/templates_c");
//$smarty->setCacheDir("/var/jvs/smarty/cache");
//$smarty->setConfigDir("/var/jvs/smarty/config");

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);


$user = $_SESSION['user'];
$fdbh = dbConnect("icms");



 

 




// Queue Items
$myqueues = array($user);
$sharedqueues = array();

getSubscribedQueues($user, $fdbh, $myqueues);
getSharedQueues($user, $fdbh, $sharedqueues);
$allqueues = array_merge($myqueues, $sharedqueues);

$queueItems = array();
$wfcount = getQueues($queueItems, $allqueues, $fdbh);
$smarty->assign('wfCount', $wfcount);




 
$smarty->assign('loginUser', $user);

$smarty->display('top/header.tpl');
$smarty->display('admin/home.tpl');

 


?>