<?php

include "../php-lib/common.php";
include "../php-lib/db_functions.php";
include "../icmslib.php";

$doc_id = $_REQUEST['doc_id'];

$dbh = dbConnect("icms");

$query = "
	UPDATE
   		workflow
    SET
    	finished = 0,
		deleted = 0,
		deletion_date = NULL
    WHERE
        doc_id = :doc_id
    ";

doQuery($query, $dbh, array ('doc_id' => $doc_id));
    
$user = $_SESSION['user'];
$logMsg = "User $user un-finished/un-deleted document ID $doc_id";
$logIP = $_SERVER['REMOTE_ADDR'];
log_this('JVS', 'workflow', $logMsg, $logIP, $dbh);
    
$result['status'] = "Success";
$result['message'] = "This document was successfully updated.";

returnJson($result);

?>
