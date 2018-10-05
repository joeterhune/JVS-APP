<?php
require_once("../php-lib/common.php");
require_once("../php-lib/db_functions.php");

extract($_REQUEST);

$result = array();
if (!isset($flagid)) {
    $result['status'] = "Failure";
    $result['message'] = "No Flag ID specified."; 
} else {
    $dbh = dbConnect("icms");
    
    # Get info on the flag for logging before it's deleted
    $query = "
        select
            f.casenum,
            f.flagtype,
            ft.dscr
        from
            flags f
                left outer join flagtypes ft on (f.flagtype = ft.flagtype)
        where
            idnum = :flagid
    ";
    $rec = getDataOne($query, $dbh, array('flagid' => $flagid));
    
    $query = "
        delete from
            flags
        where
            idnum = :flagid
    ";
    doQuery($query, $dbh, array('flagid' => $flagid));
    
    if (array_key_exists('casenum',$rec)) {  // Just in case the flag didn't exist for some reason
        $user = $_SESSION['user'];
        $logMsg = sprintf("User %s deleted flag ID %d (%s) from case %s", $user, $flagid, $rec['dscr'], $rec['casenum']);
        log_this("JVS","flagsnotes",$logMsg,$_SERVER['REMOTE_ADDR'],$dbh);
    }
    
    $result['status'] = "Success";
}

returnJson($result);

?>