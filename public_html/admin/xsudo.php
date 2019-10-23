<?php

// Change the session value to login as another user.

require_once("../php-lib/common.php");
require_once("../php-lib/functions.php");

checkLoggedIn();
onlyAdmins();

session_start(); 
$_SESSION['user'] = $_REQUEST['u'];
header("location:index.php");

 

?>