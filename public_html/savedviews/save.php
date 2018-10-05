<?php
require_once("../php-lib/common.php");
require_once("../php-lib/db_functions.php");

$casetype = "";
$docketCodes = "";

extract($_REQUEST, EXTR_IF_EXISTS);

$user = $_SERVER['PHP_AUTH_USER'];

$result = array();

if (($casetype == "") || ($user == "")) {
    $result['status'] = "Failure";
    $result['message'] = "Either case type or user ID is not specified.";
} else {
    $docketList = explode(",", $docketCodes);
    $dbh = dbConnect("icms");
    $dbh->beginTransaction();
    
    # First, delete the existing settings for this user and case type
    $query = "
        delete from
            user_docket_codes
        where
            case_type = :casetype
            and userid = :user
    ";
    doQuery($query, $dbh, array('casetype' => $casetype, 'user' => $user));
    
    # Now add the new ones.
    $count = 1;
    foreach ($docketList as $docket) {
        if ($docket == "") {
            continue;
        }
        $query = "
            insert into
                user_docket_codes (
                    userid,
                    case_type,
                    docket_code,
                    load_order
                ) values (
                    :user,
                    :casetype,
                    :docket,
                    :loadorder
                )
        ";
        doQuery($query, $dbh, array('user' => $user, 'casetype' => $casetype, 'docket' => $docket, 'loadorder' => $count));
        $count++;
    }
    $dbh->commit();
    $result['status'] = "Success";
    $result['message'] = "Added docket codes $docketCodes to case type $casetype for user $user";
}

returnJson($result);

?>