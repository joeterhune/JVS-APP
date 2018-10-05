<?php

# wfupload.php - receives data from a workflow upload dialog...
include "../php-lib/common.php";
include "../php-lib/db_functions.php";

include "../icmslib.php";

$wf_id = $_REQUEST['add_comment_wf_id'];
$comment = $_REQUEST['wf_add_comment_comments'];
$queue = $_REQUEST['add_comment_queue'];

if(!empty($comment)){
	$comment = $comment . " (" . $_SESSION['user'] . ")";
}

$dbh = dbConnect("icms");

$query = "
	update
   		workflow
    set
    	comments = :comments
    where
        doc_id = :docid
    ";
    doQuery($query, $dbh, array ('comments' => $comment, 'docid' => $wf_id));
    
    $user = $_SESSION['user'];
    $logMsg = "User $user updated comment for document ID $docnum";
    $logIP = $_SERVER['REMOTE_ADDR'];
    log_this('JVS','workflow',$logMsg,$logIP,$dbh);
    
    $result['status'] = "Success";
    $result['message'] = "This comment was successfully updated.";

$query = "
    update
        workqueues
    set
        last_update=now()
    where
        queue = :queue
";

doQuery($query, $dbh, array('queue' => $queue));

returnJson($result);

?>
