<?php
require_once '../php-lib/common.php';
require_once '../php-lib/db_functions.php';
require_once '../icmslib.php';
require_once 'wfcommon.php';

$docid = getReqVal('docid');

$ts=date("m/d/Y h:i:s A"); # current timestamp...
if ($docid=="") {
    file_put_contents("php://stderr","$ts: delete.php ERROR: blank docid\n",FILE_APPEND);
    echo "ERROR";
    exit;
}

$dbh = dbConnect("icms");

# get current queue
$query = "
    select
        queue,
        formname,
        ucn
    from
        workflow
    where
        doc_id = :docid
";

$rec = getDataOne($query, $dbh, array("docid" => $docid));
$queue = $rec['queue'];
$formname = $rec['formname'];
$ucn = $rec['ucn'];

foreach($_SESSION['tabs'] as $key => $t){
	if($t['name'] == $ucn){
		if(isset($t['tabs']) && !empty($t['tabs'])){
			foreach($t['tabs'] as $key2 => $it){
				if($it['name'] == "Order Creation"){
					unset($_SESSION['tabs'][$key]['tabs'][$key2]);
				}
			}
		}
	}
}

# delete from that queue
$query = "
    update 
		workflow
	set 
		deleted = 1,
		deletion_date = NOW(),
		signed_pdf = NULL,
		signature_img = NULL
    where
    	doc_id = :docid
";

doQuery($query, $dbh, array('docid' => $docid));

$user = $_SESSION['user'];
$logMsg = "User $user deleted document ID $docid from workflow queue '$queue'";
$logIP = $_SERVER['REMOTE_ADDR'];
log_this('JVS','workflow',$logMsg,$logIP,$dbh);

updateQueue($queue, $dbh);

echo `/bin/rm $DOCPATH/$docid.*`;
if ($formname!="") {
   echo `/bin/rm /var/www/icmsdata/tmp/$ucn.$formname.*`;
}

$result = array();
$result['status'] = "Success";

header('application/json');
print json_encode($result);
?>