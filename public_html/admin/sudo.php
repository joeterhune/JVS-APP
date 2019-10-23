<?php

error_reporting (E_ALL ^ E_NOTICE);
ini_set('display_errors','On');

require_once("../php-lib/common.php");
require_once("../php-lib/db_functions.php");
require_once("../icmslib.php");
//require_once('../../Smarty/Smarty.class.php');
require_once("../workflow/wfcommon.php");
require_once("../php-lib/functions.php");
checkLoggedIn();
onlyAdmins();
// Init Smarty Template manager
/* $smarty = new Smarty;
$smarty->setTemplateDir("/usr/local/icms/templates");
$smarty->setCompileDir("/var/www/smarty/templates_c");
$smarty->setCacheDir("/var/www/smarty/cache");
$smarty->setConfigDir("/var/www/smarty/config");

 */
 $smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);


$user = $_SESSION['user'];
$fdbh = dbConnect("icms");


$query = "
	SELECT 
		userid, 
		first_name, 
		middle_name, 
		last_name,
		email
	FROM
		users
	GROUP BY
		userid
";

$userArray = array();
getData($userArray, $query, $fdbh);



// Queue Items
$myqueues = array($user);
$sharedqueues = array();

getSubscribedQueues($user, $fdbh, $myqueues);
getSharedQueues($user, $fdbh, $sharedqueues);
$allqueues = array_merge($myqueues, $sharedqueues);

$queueItems = array();
$wfcount = getQueues($queueItems, $allqueues, $fdbh);
$smarty->assign('wfCount', $wfcount);

 
$smarty->assign('users', $userArray);
$smarty->display('top/header.tpl');
$smarty->display('admin/sudo.tpl');

 

?>