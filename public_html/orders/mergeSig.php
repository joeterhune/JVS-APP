<?php

require_once("../php-lib/common.php");
require_once("../php-lib/db_functions.php");
include "../icmslib.php";

extract($_REQUEST);

$html = json_decode($formData, true);
$signature = json_decode($sig, true);
$html = str_replace("[% judge_signature %]", $signature, $html); 

$result = array();
$result['order_html'] = $html;

$_SESSION['form_data'] = $html;
$_SESSION['order_html'] = $html;
header('Content-Type: application/json');
print json_encode($result);

exit;

?>
