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

// Get Values from POST
$userId = $_REQUEST["signatureUser"];
$file = $_FILES['signature'];




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
	header("location:signatureDetail.php?u=$userId&Error=$msg");
	exit();
	
}

if( in_array($file['type'], $allowedFiles) == false){
	$msg = ' Invalid Image File';
	
	header("location:signatureDetail.php?u=$userId&Error=$msg");
	exit();
}


$imageLocation = $file['tmp_name'];

$image = file_get_contents($imageLocation);



$jpg = unpack("H*", $image);

$signature =  $jpg[1];
// print $jpg[1] ;


// ok we have the image, now we save it on the database...
$query = "
	UPDATE 
		signatures
	SET 
		user_sig = '$signature'
	WHERE 
		user_id = :userId
	
";
 
doQuery($query, $pdbh, array("userId"=>$userId) ) ;


header("location:signatureDetail.php?u=$userId&updated");
exit();

