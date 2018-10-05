<?php

require_once("../php-lib/common.php");
require_once("../php-lib/db_functions.php");

include "../icmslib.php";

#
# main program...
#

extract($_REQUEST);

$dbh = dbConnect("icms");

if(!empty($docid)){
	if($lock && ($lock != "0")){
		$query = "	UPDATE workflow
					SET doc_lock_date = NOW(),
					doc_lock_user = :user,
					doc_lock_sessid = :sessid
					WHERE doc_id = :docid";
		
		doQuery($query, $dbh, array("user" => $_SESSION['user'], "docid" => $docid, "sessid" => session_id()));
	}
	else{
		$query = "	UPDATE workflow
					SET doc_lock_date = NULL,
					doc_lock_user = NULL,
					doc_lock_sessid = NULL
					WHERE doc_id = :docid";
		
		doQuery($query, $dbh, array("docid" => $docid));
	}
}

$result['status'] = "OK";
$result['docid'] = $docid;

header('Content-type: application/json');
print json_encode($result);