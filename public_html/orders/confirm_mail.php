<?php
require_once("../php-lib/common.php");
require_once("../php-lib/db_functions.php");

extract($_REQUEST);

$query = "
    update
        workflow
    set
        mailing_confirmed = 1,
        mailing_confirmed_by = :user,
        mailing_confirmed_time = NOW()
    where
        doc_id = :docid
";

$dbh = dbConnect("icms");
$rows = doQuery($query, $dbh, array('user' => $_SESSION['user'], 'docid' => $docid));
        
$result = array();
$result['status'] = "Success";
header("Content-type: application/json");
print json_encode($result);

?>