<?php

require_once("php-lib/common.php");

session_start();
$sess_tabs = $_SESSION['tabs'];

$parent = getReqVal('parent');

$foundKey = "";
foreach($sess_tabs as $key => $t){
	if($t['parent'] == $parent){
		if(empty($foundKey) || ($key < $foundKey)){
			$foundKey = $key;
		}
	}
}

if(!empty($foundKey)){
	$url = $sess_tabs[$foundKey]['href'];
}
else{
	$url = "/tabs.php";
}

header("Location: " . $url);
die;