<?php
require_once("../php-lib/common.php");
require_once("../php-lib/db_functions.php");

extract($_REQUEST);

$result = array();

if ((!isset($casenum)) || (!isset($email))) {
    $result['status'] = "Failure";
    $result['message'] = "Either case number or email (or both) was not specified.";
} else {
    $dbh = dbConnect("ols");
    
    $query = "
        replace into
            reuse_emails (
                casenum,
                email_addr
            ) values (
                :casenum,
                :email
            )
    ";
    
    if($store){
    	doQuery($query, $dbh, array('casenum' => $casenum, 'email' => $email));
    }

    $result['status'] = "Success";
    $result['message'] = "The address '$email' was successfully added.";
}

returnJson($result);

?>