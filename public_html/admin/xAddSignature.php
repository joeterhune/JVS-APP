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

$signatureUser = $_POST['signature'];
$targetUser = $_POST['user'];


 
	$query = "
		INSERT INTO
			portal_alt_filers
			(
				user_id,
				portal_user,
				active,
				default_account
			)VALUES(
				'$targetUser',
				'$signatureUser',
				1,
				1
			)
	";
	doQuery($query, $pdbh);
	
 

 

header("location: signatureDetail.php?u=$signatureUser");
exit();

 



?>