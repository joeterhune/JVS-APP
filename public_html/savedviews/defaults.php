<?php
include_once("../php-lib/common.php");
include_once("../php-lib/db_functions.php");

$dbh = dbConnect("icms");
$user = $_SERVER['PHP_AUTH_USER'];
$defaults = load_module_config($user, 'default_views', $dbh);
returnJson($defaults);

?>