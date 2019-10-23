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


 
// Values from Post
$username = $_POST['userId'];
$password = $_POST['password'];
$portalId = $_POST['portalId'];
$barNumber= $_POST['barNumber'];
$userType = $_POST['userType'];


// We also need other values....
// name
// middle name
// lastname
// userID ex.99



$config = simplexml_load_file("/usr/local/icms/etc/ICMS.xml");
$ldapConf = $config->{'ldapConfig'};
$filter = "(sAMAccountName=$username)";
$userdata = array();
$adFields = array('givenname','initials','sn','title','telephonenumber','mail' );

// let's get the user information from AD
ldapLookup($userdata, $filter, $ldapConf, null, $adFields, (string) $ldapConf->{'userBase'});

// let's save the values
if(count($userdata) > 0 ){
	
	$name = $userdata[0]['givenname'][0];
	
	$lastname = $userdata[0]['sn'][0];
	
	if(isset($userdata[0]['initials'][0])){
		$middlename = $userdata[0]['initials'][0];
	}else{
		$middlename = '';
	}
	
}


 
//Let's find the userid (number) from 
 
$judgeConnectionString = dbConnect("judge-divs");

 $query = "
 	SELECT 
		* 
	FROM
		judges
	WHERE 
		first_name = :name AND
		last_name = :lastname  
		
 ";
 
$arguments = array(
	"name"=> strtoupper($name),
	"lastname"=> strtoupper($lastname) 
);


$judgeDivs = array();
getData($judgeDivs, $query, $judgeConnectionString, $arguments );
//lets get the id of a judge or add a new one.

 
if(count($judgeDivs) > 0){
	// We got an id ! let's insert the portal user
	$query = "
		INSERT INTO portal_users
		(
			user_id,
			portal_id,
			password,
			bar_num,
			portal_user_type_id,
			judge_first_name,
			judge_middle_name,
			judge_last_name,
			judge_id
		
		)VALUES(
			:userId,
			:portalId,
			:password,
			:barNumber,
			:userType,
			:firstName,
			:middleName,
			:lastname,
			:judgeId
			
		)
	";
	
	$arguments = array(
		'userId'=>$username,
		'portalId'=>$portalId,
		'password'=>$password,
		'barNumber'=>$barNumber,
		'userType'=>$userType,
		'firstName'=>$name,
		'middleName'=>$middlename,
		'lastname'=>$lastname,
		'judgeId'=>$judgeDivs['judge_id']
	);
	
	$portalDb = dbConnect('portal_info');
	doQuery($query,$portalDb,$arguments);
	
	
}else{
	//User does not exists, we have to add him/her first and then add the portal_user...
	
	
	$query = "
		INSERT 
		INTO
		judges(
			last_name,
			first_name,
			middle_name 
		)VALUES(
			:lastname,
			:name,
			:middlename
		)
	";
	
	
	$arguments = array(
		'lastname'=>strtoupper($lastname),
		'name'=>strtoupper($name),
		'middlename'=>strtoupper($middlename)
	);
	doQuery($query, $judgeConnectionString, $arguments );
	// Get last inserted Id to be used in next insert.
	$lastId = getLastInsert($judgeConnectionString);
	
		
	$query = "
		INSERT INTO portal_users
		(
			user_id,
			portal_id,
			password,
			bar_num,
			portal_user_type_id,
			judge_first_name,
			judge_middle_name,
			judge_last_name,
			judge_id
		
		)VALUES(
			:userId,
			:portalId,
			:password,
			:barNumber,
			:userType,
			:firstName,
			:middleName,
			:lastname,
			:judgeId
			
		)
	";
	
	$arguments = array(
		'userId'=>$username,
		'portalId'=>$portalId,
		'password'=>$password,
		'barNumber'=>$barNumber,
		'userType'=>$userType,
		'firstName'=>$name,
		'middleName'=>$middlename,
		'lastname'=>$lastname,
		'judgeId'=>$lastId
	);
	
	$portalDb = dbConnect('portal_info');
	doQuery($query,$portalDb,$arguments);
	
	
}


// let's redirect the user back..

header("location: portalUsers.php");
exit();


?>