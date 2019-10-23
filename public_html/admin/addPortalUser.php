<?php

error_reporting (E_ALL ^ E_NOTICE);
ini_set('display_errors','On');

require_once("../php-lib/common.php");
require_once("../php-lib/db_functions.php");
require_once("../icmslib.php");
require_once("../php-lib/functions.php");
require_once("../workflow/wfcommon.php");
require_once('Smarty/Smarty.class.php');

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
$pdbh = dbConnect('portal_info');
 
// Get all the portal user types.
$query = "
	SELECT 
		*
	FROM
		portal_user_types
	ORDER BY
		portal_user_type_desc
";

$portalUserTypes = array();
getData($portalUserTypes, $query, $pdbh, array("userId"=> $userId) );
$smarty->assign('userType', $portalUserTypes);



// Queue Items
$myqueues = array($user);
$sharedqueues = array();

getSubscribedQueues($user, $fdbh, $myqueues);
getSharedQueues($user, $fdbh, $sharedqueues);
$allqueues = array_merge($myqueues, $sharedqueues);

$queueItems = array();
$wfcount = getQueues($queueItems, $allqueues, $fdbh);
$smarty->assign('wfCount', $wfcount);


$smarty->assign('authorizedUsers', $authorizeUsers);
$smarty->assign('loginUser', $user);
$smarty->assign('signature', $sigImage);
$smarty->assign('sigUser', $signatureArray);
$smarty->assign('users', $userArray);
$smarty->display('top/header.tpl');
$smarty->display('admin/addPortalUser.tpl');

 

?>