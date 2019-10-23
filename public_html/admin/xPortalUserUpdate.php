<?php

error_reporting (E_ALL ^ E_NOTICE);
ini_set('display_errors','On');

require_once("../php-lib/common.php");
require_once("../php-lib/db_functions.php");
require_once("../icmslib.php");
require_once("../php-lib/functions.php");
//require_once('../../Smarty/Smarty.class.php');
require_once("../workflow/wfcommon.php");
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
$userId = $_REQUEST['userId'];
// POST REQUEST
$portalId = $_REQUEST['portalId'];
$password = $_REQUEST['password'];
$barNumber = $_REQUEST['barNumber'];
$userType = $_REQUEST['userType'];
$name = $_REQUEST['name'];
$middleName = $_REQUEST['middleName'];
$lastname = $_REQUEST['lastname'];
$suffix = $_REQUEST['suffix'];
$judgeId = $_REQUEST['judgeId'];
			 
 
$pdbh = dbConnect('portal_info');
 
$query = "
	UPDATE
		portal_users
	SET
		portal_id = :portalId,
		password = :password,
		bar_num = :barNumber,
		portal_user_type_id = :userType,
		judge_first_name = :name,
		judge_middle_name = :middleName,
		judge_last_name = :lastname,
		judge_suffix = :suffix,
		judge_id = :judgeId
		
		
	WHERE
		user_id = :userId

";
 
$arguments = array(
	'userId'=>$userId,
	'portalId'=>$portalId,
	'password'=>$password,
	'barNumber'=>$barNumber,
	'userType'=>$userType,
	'name'=>$name,
	'middleName'=>$middleName,
	'lastname'=>$lastname,
	'suffix'=>$suffix,
	'judgeId'=>$judgeId
);

doQuery($query, $pdbh, $arguments);


 

header('location: portalUsers.php');
exit();
 


?>