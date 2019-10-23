<?php
# transfer.php - transfers a given document to someone else's workflow queue
require_once $_SERVER['JVS_DOCROOT'] . "/php-lib/common.php";
require_once $_SERVER['JVS_DOCROOT'] . "/php-lib/db_functions.php";
require_once $_SERVER['JVS_DOCROOT'] . "/icmslib.php";

$ts=date("m/d/Y h:i:s A");

extract($_REQUEST);

if ((!isset($docid)) || (!isset($toqueue))) {
    $result['status'] = "Failure";
    $result['message'] = "All of doc ID, queue and new queue must be specified.";
    header("Content-type: application/json");
    print json_encode($result);
    exit;
}

$icms = dbConnect("icms");

$query = "
    select
        queue,
		ucn
    from
        workflow
    where
        doc_id = :docid
";
$rec = getDataOne($query, $dbh, array('docid' => $docid));
$fromqueue = $rec['queue'];
$ucn = $rec['ucn'];

$query = "
    update
        workflow
    set
        queue = :queue,
		transfer_date = NOW()
    where
        doc_id = :docid
";
doQuery($query, $dbh, array('queue' => $toqueue, 'docid' => $docid));

$query = "
    update
        workqueues
    set last_update=CURRENT_TIMESTAMP
        where queue = :queue
";
doQuery($query, $dbh, array('queue' => $toqueue));
doQuery($query, $dbh, array('queue' => $fromqueue));

$jdbh = dbConnect("judge-divs");

$cqQuery = "
	SELECT 
		email_address,
		queue_type,
		queue_name
	FROM
		custom_queues
	WHERE
		queue_name = :toqueue
				
";

$cqRow = getDataOne($cqQuery, $jdbh, array("toqueue" => $toqueue));

if(!empty($cqRow) && !empty($cqRow['email_address'])){
	if(strpos($cqRow['queue_type'], "Emergency") !== false){
        $recips = $cqRow['email_address'];
        $uid = md5(uniqid(time()));
        $text = "An emergency filing has been received for review. Please follow the instructions below:<br/>";
		$text .= "<ul>";
		$text .= "<li><strong>PLEASE NOTE:</strong>You must be connected to the County network (either at a courthouse, or by VPN) <u>to access the emergency filing in Step 3 below</u>.</li>";
		$text .= "<li>If you are away from a courthouse, you will be required to log into your VPN to access JVS.</li>";
		$text .= "<ul>";
		$text .= "<li>For instructions on how to log into your VPN from your Judicial iPad, click <a href=\"https://e-services.co.palm-beach.fl.us/scheduling/style/images/ipad-vpn.png\" target=\"_blank\">here</a>.</li>";
		$text .= "<li>If you are using a Windows-based desktop or laptop away from a courthouse, <a href=\"https://vpn.co.palm-beach.fl.us/my.policy\" target=\"_blank\">click here to access the VPN login page</a>.</li>";
		$text .= "</ul>";
		$text .= "</ul>";
		$text .= "<u>To access the <span style=\"color:red\"><strong>" . $cqRow['queue_type'] . " Queue</strong></span></u>:";
		$text .= "<ol>";
		$text .= "<li>(Once connected to the County network) <a href=\"https://jvs.jud12.org/workflow.php?queueName=" . $cqRow['queue_name'] . "\" target=\"_blank\">Click here to access the " . $cqRow['queue_type'] . " Queue in JVS</a>.</li>";
		$text .= "<li>You will be prompted to log into JVS.</li>";
		$text .= "<li>Once logged in, view the " . $cqRow['queue_type'] . " Queue to access and review the filing. </li>";
		$text .= "<li>After review, e-sign and e-file/e-serve the pleading.</li>";
		$text .= "</ol>";
		$text .= "<em>If you have any questions or require assistance (including after-hours), please e-mail <a href=\"mailto:webhelp@jud12.flcourts.org\">webhelp@jud12.flcourts.org</a> or call 561-318-1012.</em>";
		
		$plaintext = str_replace("<br>", "\r\n", $text);
	
		//$from_mail = $fromqueue . "@pbcgov.org";
		$from_mail = $cqRow['email_address'];
		
		$header = "From: ".$from_mail."\r\n";
		//$header .= "cc: nchessman@pbcgov.org\r\n";
		$header .= "MIME-Version: 1.0\r\n";
		$header .= "X-Priority: 1 (Highest)\r\n";
		$header .= "X-MSMail-Priority: High\r\n";
		$header .= "Importance: High\r\n";
		$header .= "Content-Type: multipart/alternative; boundary=\"".$uid."\"\r\n\r\n";
		//$header .= "This is a multi-part message in MIME format.\r\n";
	
		$mMessage .= "--".$uid."\r\n";
		$mMessage .= "Content-type:text/plain; charset=iso-8859-1\r\n";
		$mMessage .= "Content-Transfer-Encoding: quoted-printable\r\n\r\n";
		$mMessage .= $plaintext."\r\n\r\n";
		$mMessage .= "--".$uid."\r\n";
	
		$mMessage .= "Content-type:text/html; charset=iso-8859-1\r\n";
		$mMessage .= "Content-Transfer-Encoding: 7bit\r\n\r\n";
		$mMessage .= $text."\r\n\r\n";
		$mMessage .= "--".$uid."\r\n";
	
		mail($recips, "Emergency Filing - " . $cqRow['queue_type'] . " Queue", $mMessage, $header);
	}
}

$user = $_SESSION['user'];
$logMsg = "User $user transferred document ID $docid from queue '$fromqueue' to queue '$toqueue'";
$logIP = $_SERVER['REMOTE_ADDR'];
log_this('JVS','workflow',$logMsg,$logIP,$dbh);

$result = array();
$result['status'] = "Success";
$result['message'] = "Document ID $docid was moved from queue '$fromqueue' to queue '$toqueue'.";

// Unset all this stuff - we're done with the order
unsetQueueVars();

//And remove the Order Creation tab if we transferred this from within the order
foreach($_SESSION['tabs'] as $key1 => $t){
	if($t['name'] == $ucn){
		foreach($t['tabs'] as $key2 => $t2){
			if($t2['name'] == "Order Creation"){
				if(count($_SESSION['tabs'][$key1]['tabs']) > 1){
					unset($_SESSION['tabs'][$key1]['tabs'][$key2]);
					$_SESSION['tabs'][$key1]['href'] = "/cgi-bin/search.cgi?name=" . $ucn;
				}
				else{
					unset($_SESSION['tabs'][$key1]);
				}
			}
		}
	}
}

header("Content-type: application/json");
print json_encode($result);
?>