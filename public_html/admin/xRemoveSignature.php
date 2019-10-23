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
 
$pdbh = dbConnect('portal_info');
$userId = $_REQUEST["u"];

// get post values.

$signatureUser = $_GET['s'];
$targetUser = $_GET['u'];





 
	
	$query = "
		DELETE FROM
			portal_alt_filers
		WHERE
			user_id = :user AND
			portal_user = :portalUser
		 
	";
	
	doQuery($query, $pdbh, array("user"=>$targetUser, "portalUser"=>$signatureUser));
	

 

header("location: signatureDetail.php?u=$signatureUser");
exit();

 


 
$smarty->assign('loginUser', $user);
 
$smarty->display('top/header.tpl');
$smarty->display('admin/signatureDetail.tpl');

 

?>