<?php

include "../php-lib/common.php";
include "../php-lib/db_functions.php";
include "../icmslib.php";

$doc_id = $_REQUEST['doc_id'];

$dbh = dbConnect("ols");
$idbh = dbConnect("icms");

$query = "
	UPDATE olscheduling.supporting_documents
    SET order_merge = 0
	WHERE supporting_doc_id = :doc_id";

doQuery($query, $dbh, array ('doc_id' => $doc_id));
    
$user = $_SESSION['user'];
$logMsg = "User $user removed merged document ID $doc_id";
$logIP = $_SERVER['REMOTE_ADDR'];
log_this('JVS', 'workflow', $logMsg, $logIP, $idbh);
    
$result['status'] = "Success";
$result['message'] = "This document was successfully un-merged.";

returnJson($result);