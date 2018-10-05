<?php

require_once("/usr/local/icms-web/case/php-lib/common.php");
require_once("../php-lib/db_functions.php");
require_once("Smarty/Smarty.class.php");

checkLoggedIn();

$dbh = dbConnect("icms");

if(!isset($_REQUEST['order_id'])){
	return false;
}
else{
	$order_id = $_REQUEST['order_id'];
}

$query = "UPDATE case_management.juv_orders
			SET completed = 1,
			completed_date = NOW()
			WHERE juv_order_id = :order_id";

doQuery($query, $dbh, array("order_id" => $order_id));

return "Success";