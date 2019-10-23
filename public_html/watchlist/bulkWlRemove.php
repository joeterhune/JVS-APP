<?php
require_once("../php-lib/common.php");
require_once("../php-lib/db_functions.php");

extract($_REQUEST);

$result = array();
$unQuotedCases = array();
$cases = array();

if (!isset($removeCases)) {
    $result['status'] = "Failure";
    $result['message'] = "No case numbers to remove were specified.";
} else {
    $temp = explode(",", $removeCases);
    foreach ($temp as $case) {
        if (preg_match("/^58/", $case)) {
            $str = sprintf("'%s'", $case);   
        } else {
            //$stripped = preg_replace("/-/", "", $case);
            $str = sprintf("'%s'", $case);
        }
        array_push($cases, $str);
        array_push($unQuotedCases, $case);
    }
    
    $inString = implode(",", $cases);
    $user = $_SESSION['user'];
    $email = getEmailFromAD($user);
    
    $query = "
        delete from
            watchlist
        where
            casenum in ($inString)
            and email = :email
    ";
    $dbh = dbConnect("icms");
    doQuery($query, $dbh, array('email' => $email));
    $result['removed'] = $unQuotedCases;
}

returnJson($result);

?>