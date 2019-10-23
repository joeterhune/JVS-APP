<?php

require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/common.php");
require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/db_functions.php");
require_once("Smarty/Smarty.class.php");

checkLoggedIn();

$dbh = dbConnect("icms");

if(!isset($_REQUEST['note_id'])){
	return false;
}
else{
	$note_id = $_REQUEST['note_id'];
}

$query = "	DELETE FROM case_management.juv_event_notes
			WHERE juv_event_note_id = :note_id";

doQuery($query, $dbh, array("note_id" => $note_id));

return "Success";