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
$pdbh = dbConnect('portal_info');
$userId = $_REQUEST["u"];


$query = "
	SELECT 
		user_id, 
		first_name, 
		middle_name, 
		last_name,
		user_sig
		 
	FROM
		signatures
	WHERE
		user_id = :userId
";

$signatureArray = array();
getData($signatureArray, $query, $pdbh, array("userId"=> $userId) );

$signatureArray = $signatureArray[0];

$sigImage = getSignature($userId);

 
// Users with access to that signature.

$query = "
	SELECT
		user_id,
		portal_user,
		default_account
	FROM
		portal_alt_filers
	WHERE
		portal_user = :userId
";

$authorizeUsers = array();
getData($authorizeUsers, $query, $pdbh, array("userId"=> $userId) );


// Get all users that can be authorized to use the signature.
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


$smarty->assign('authorizedUsers', $authorizeUsers);
$smarty->assign('loginUser', $user);
$smarty->assign('signature', $sigImage);
$smarty->assign('sigUser', $signatureArray);
$smarty->assign('users', $userArray);
$smarty->display('top/header.tpl');
$smarty->display('admin/signatureDetail.tpl');

 

?>