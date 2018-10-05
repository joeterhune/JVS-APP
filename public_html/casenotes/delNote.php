<?php
require_once("../php-lib/common.php");
require_once("../php-lib/db_functions.php");

extract($_REQUEST);

$result = array();
if (!isset($noteid)) {
    $result['status'] = "Failure";
    $result['message'] = "No Note ID specified."; 
} else {
    $dbh = dbConnect("icms");
    
    # Get info on the flag for logging before it's deleted
    $query = "
        select
            casenum,
            note
        from
            casenotes
        where
            seq = :noteid
    ";
    $rec = getDataOne($query, $dbh, array('noteid' => $noteid));
    
    # Delete any attachments
    $query = "
        delete from
            casenote_attachments
        where
            note_id = :noteid
    ";
    doQuery($query, $dbh, array('noteid' => $noteid));
    
    # And then delete the note.
    $query = "
        delete from
            casenotes
        where
            seq = :noteid
    ";
    doQuery($query, $dbh, array('noteid' => $noteid));
        
    if (array_key_exists('casenum',$rec)) {  // Just in case the flag didn't exist for some reason
        $user = $_SESSION['user'];
        $logMsg = sprintf("User %s deleted note '%s' from case %s", $user, $rec['note'], $rec['casenum']);
        log_this("JVS","flagsnotes",$logMsg,$_SERVER['REMOTE_ADDR'],$dbh);
    }
    
    
    $result['status'] = "Success";
}

$result['html'] = "Note ID $noteid was deleted.";
returnJson($result);

?>