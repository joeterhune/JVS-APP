<?php 

require_once("php-lib/common.php");

$config = simplexml_load_file($icmsXml);
$error = "";
$errorText = "";

if(isset($_REQUEST['ref'])){
	$reqPage = $_REQUEST['ref'];
}
else{
	$reqPage = "";
}

if(!empty($_POST)){
	
	$reqPage = $_REQUEST['ref'];
	$pass = 0;
	
	if(session_id() == '') {
		session_start();
	}
	
	/*if(isset($_SESSION['user'])){
		$host = $_SERVER['HTTP_HOST'];
		header("Location: " . $host . "/case/tabs.php");
		die;
	}*/
	
	$ldapURL = $config->ldapConfig->ldapHost[0];
	
	if(isset($_GET['ref'])){
		$ref = $_GET['ref'];
	}
	
	$ui_login = strtolower(trim($_POST['user']));
	$ui_pw = trim($_POST['password']);
	
	//Now verify their AD credentials
	$ldaprdn  = "cn=cad icms,ou=Services,ou=CAD,ou=Enterprise,DC=PBCGOV,DC=ORG";
	$ldappass = 'password99';
		
	$ldapconn = ldap_connect($ldapURL);

	if(!$ldapconn){
		$error = true;
		$errorText = "There was an error connecting to the authentication server.<br/><br/>";
	}
		
	ldap_set_option($ldapconn, LDAP_OPT_PROTOCOL_VERSION, 3);
	ldap_set_option($ldapconn, LDAP_OPT_REFERRALS, 0);
		
	if ($ldapconn) {
		$ldapbind = @ldap_bind($ldapconn, $ldaprdn, $ldappass);
	}
		
	$ad = $ldapconn;
		
	$attrs = array("description", "name", "mail");
	$result = ldap_search($ad, 'ou=Users,ou=CAD,ou=Enterprise,DC=PBCGOV,DC=ORG',
			"(&(sAMAccountName=".$ui_login.")(memberof:1.2.840.113556.1.4.1941:=CN=CAD-ICMS-GROUP,OU=Services,OU=CAD,OU=Enterprise,DC=pbcgov,DC=org))", $attrs);
	$info = ldap_get_entries($ad, $result);
		
	$loginString = isset($info[0]['dn']) ? $info[0]['dn'] : null;
	
	if(empty($loginString)){
		$error = true;
		$errorText = "You have entered an incorrect username or password.<br/><br/>";
	}
	else{
		
		$ldaprdn = $loginString;
		$ldappass = $ui_pw;
			
		$ldapconn = ldap_connect($ldapURL);
		if(!$ldapconn){
			$error = true;
			$errorText = "There was an error connecting to the authentication server.<br/><br/>";
		}
			
		ldap_set_option($ldapconn, LDAP_OPT_PROTOCOL_VERSION, 3);
		ldap_set_option($ldapconn, LDAP_OPT_REFERRALS, 0);
	
		if ($ldapconn) {
			$ldapbind = @ldap_bind($ldapconn, $ldaprdn, $ldappass);
			$pass = ($ldapbind) ? 1 : 0;
		}
			
		if(!$pass){
			$error = true;
			$errorText = "You have entered an incorrect username or password.<br/><br/>";
		}
		else {
			session_regenerate_id(true);
			$_SESSION['user'] = $ui_login;
			$_SESSION['tabs'] = array(
					array(
							"name" => "Main Form",
							"active" => 1,
							"close" => 0,
							"href" => "/tabs.php",
							"parent" => "index"
					)
			);
			
			if(!empty($reqPage) && (strpos($reqPage, "close.cgi") === false)
				&& (strpos($reqPage, "logout.cgi") === false)
				&& ($reqPage != "/")){
				header("Location: " . $reqPage);
			}
			else{
				header("Location: /tabs.php");
			}
			
			die;
		}
	}
}

require_once('Smarty/Smarty.class.php');

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);

$smarty->assign("error", $error);
$smarty->assign("errorText", $errorText);
$smarty->assign("ref", $reqPage);
$smarty->display('top/login.tpl');