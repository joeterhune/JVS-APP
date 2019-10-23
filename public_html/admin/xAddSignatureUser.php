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


$file = $_FILES['signature'];
$userId = $_POST['userId'];

$query = "
	SELECT 
		* 
	FROM
		portal_users
	WHERE
		portal_users.user_id = :userId
	ORDER BY
		judge_first_name, judge_last_name
";


$userArray = array();
getData($userArray, $query, $pdbh, array('userId'=>$userId));





$allowedFiles= array('image/jpeg'  );


if($file['error'] != 0){
	
	
	switch($file['error']){
		case 1:
			// PHP INI  size limit
			$msg = 'Upload too big.';
			break;
		case 2:
			// MAX_FILE_SIZE on form
			$msg = 'Upload too big ';
			break;
		case 3:
			$msg='Incomplete file upload';
			break;
		case 4:
			$msg ='No File uploaded';
			break;
		case 6:
			// Missing Temp folder to store File
			$msg = 'Internal error can\'t upload file';
			break;
		case 7:
			// Failed to write file to disk
			$msg = 'Unable to save file';
			break;
		case 8:
			$msg = 'Internal error can\'t upload file';
			break;
		default:
			// Some unknow error ! 
			$msg = 'Internal error can\'t upload file';
		
	}
	
	// enviamos error al usuario via XML
	header("location:addSignatureUser.php?Error=$msg");
	exit();
	
}

if( in_array($file['type'], $allowedFiles) == false){
	$msg = ' Invalid Image File';
	
	header("location:addSignatureUser.php?Error=$msg");
	exit();
}


$imageLocation = $file['tmp_name'];

$image = file_get_contents($imageLocation);



$jpg = unpack("H*", $image);

$signature =  $jpg[1];


// Lets get the values from portal_users..... 

$query = "
SELECT * FROM portal_users WHERE user_id = :userId
";

$userArray = array();
getData($userArray,$query, $pdbh, array("userId"=>$userId) ) ;

$user = $userArray[0];
 
// insert the value on the signatures table.
$query = "
	INSERT INTO
		signatures(
	 		user_id,
			user_sig,
			first_name,
			middle_name,
			last_name,
			suffix
		 )VALUES(
			 :userId,
			 :userSig,
			 :name,
			 :middleName,
			 :lastname,
			 :suffix
		 )
	
";

$arguments = array(
	'userId'=>$user["user_id"],
	'userSig'=>$signature,
	'name'=>$user["judge_first_name"],
	'middleName'=>$user["judge_middle_name"],
	'lastname'=>$user["judge_last_name"],
	'suffix'=>$user["judge_suffix"]
);

doQuery($query, $pdbh, $arguments ) ;


header("location:signatures.php?updated");
exit();








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
$smarty->assign('users', $userArray);
$smarty->display('top/header.tpl');
$smarty->display('admin/addSignatureUser.tpl');

 

?>