<?php 

session_start();

unset($_SESSION['tabs']);

$_SESSION['tabs'] = array(
	array(
		"name" => "Main Form",
		"active" => 1,
		"close" => 0,
		"href" => "/tabs.php",
		"parent" => "index"
	)
);

header("Location: /tabs.php");
die;