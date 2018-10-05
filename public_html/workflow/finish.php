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


# mark it finished
$query = "
    update
        workflow
    set
        finished=1
    where
        doc_id = :docid
";

doQuery($query, $dbh, array('docid' => $docid));

# set last_updated for that queue
updateQueue($queue, $dbh);

$user = $_SESSION['user'];
$logMsg = "User $user marked document ID $docid as finished.";
$logIP = $_SERVER['REMOTE_ADDR'];
log_this('JVS','workflow',$logMsg,$logIP,$dbh);

$result = array();
$result['status'] = "Success";
header('application/json');
print json_encode($result);
?>