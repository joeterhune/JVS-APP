<?php
require_once '../php-lib/common.php';
require_once '../php-lib/db_functions.php';
require_once 'wfcommon.php';

$docid = getReqVal('docid');
$ts=date("m/d/Y h:i:s A"); # current timestamp...
if ($docid=="") {
    file_put_contents("php://stderr","$ts: finish: ERROR: blank docid\n",FILE_APPEND);
    echo "ERROR";
    exit;
}

$dbh = dbConnect("icms");

# get current queue
# get current queue
$query = "
    select
        queue
    from
        workflow
    where
        doc_id = :docid
";

$rec = getDataOne($query, $dbh, array("docid" => $docid));
$queue = $rec['queue'];

# are we flagging or unflagging?
$query = "
    select
        flagged
    from
        workflow
    where
        doc_id = :docid
";

$flagRow = getDataOne($query, $dbh, array("docid" => $docid));
$flag = $flagRow['flagged'];

if($flag == "1"){
	$flagged = "0";
}
else{
	$flagged = "1";
}


# mark it finished
$query = "
    update
        workflow
    set
        flagged=:flagged
    where
        doc_id = :docid
";

doQuery($query, $dbh, array('flagged' => $flagged, 'docid' => $docid));

# set last_updated for that queue
updateQueue($queue, $dbh);

$user = $_SESSION['user'];
$logMsg = "User $user flagged document ID $docid.";
$logIP = $_SERVER['REMOTE_ADDR'];
log_this('JVS','workflow',$logMsg,$logIP,$dbh);

$result = array();
$result['status'] = "Success";
header('application/json');
print json_encode($result);
?>