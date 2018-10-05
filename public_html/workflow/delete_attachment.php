<?php

include "../php-lib/common.php";
include "../php-lib/db_functions.php";
include "../icmslib.php";

$doc_id = $_REQUEST['doc_id'];

$dbh = dbConnect("ols");
$idbh = dbConnect("icms");

$docQuery = "SELECT file
			FROM olscheduling.supporting_documents
			WHERE supporting_doc_id = :doc_id";

$row = getDataOne($docQuery, $dbh, array("doc_id" => $doc_id));

$query = "
	DELETE FROM olscheduling.supporting_documents
    WHERE supporting_doc_id = :doc_id
	AND jvs_doc = 1";

doQuery($query, $dbh, array ('doc_id' => $doc_id));

if(file_exists($row['file'])){
	unlink($row['file']);
}
    
$user = $_SESSION['user'];
$logMsg = "User $user removed attached document ID $doc_id";
$logIP = $_SERVER['REMOTE_ADDR'];
log_this('JVS', 'workflow', $logMsg, $logIP, $idbh);
    
$result['status'] = "Success";
$result['message'] = "This document was successfully deleted.";

returnJson($result);