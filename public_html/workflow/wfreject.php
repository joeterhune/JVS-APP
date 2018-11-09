<?php
require_once '../php-lib/common.php';
require_once '../php-lib/db_functions.php';
require_once 'wfcommon.php';
require_once '../icmslib.php';

#
# MAIN PROGRAM
#
$docid = getReqVal('wf_reject_id');
$ts=date("m/d/Y h:i:s A");
if ($docid=="") {
    file_put_contents("php://stderr","$ts: wfreject.php ERROR: docid blank!\n",FILE_APPEND);
    exit;
}
$creator = getReqVal('wf_reject_creator');
$queue = getReqVal('wf_reject_queue');
$comments = getReqVal('wf_reject_comments');
$ucn = getReqVal('wf_reject_ucn');

$dbh = dbConnect("icms");

list($caseNo, $casetype) = sanitizeCaseNumber($ucn);

if ($casetype == "showcase") {
	if (!preg_match("/^50/", $ucn)) {
		$caseNo = sprintf("50-%s",$ucn);
	}
} 

$div = getCaseDiv($caseNo, $casetype);

if (strpos($creator, "@") === false) { # not an e-mail address; work queue user!
    ##############################################
    #  LOCAL USER--KICK BACK TO THEIR QUEUE
    ##############################################
    $comments = "REJECTED - REASON: $comments"; # a prefix for the local user's comment section
    $query = "
        update
            workflow
        set
            queue = :queue,
            comments = :comments
        where
            doc_id = :docid
    ";
    doQuery($query, $dbh, array('queue' => $creator, 'comments' => $comments, 'docid' => $docid));
    
    updateQueue($queue, $dbh);
    updateQueue($creator, $dbh);
    
    $user = $_SESSION['user'];
    $logMsg = "User $user rejected document ID $docid and returned it to $creator";
    $logIP = $_SERVER['REMOTE_ADDR'];
    log_this('JVS','workflow',$logMsg,$logIP,$dbh);
} else {
    ##############################################
    #  EXTERNAL USER--E-MAIL THE FILE BACK AND REMOVE FROM WORKFLOW
    ##############################################
    #
    # external user: e-mail the file back to the origin, remove it from workflow
    #
 	  
	$query = "
            SELECT 
				CASE WHEN form_id = '' OR form_id IS NULL
				THEN 'No'
				ELSE 'Yes'
			   END AS isTemplate,
				formname,
				data,
				queue
           	FROM
            	workflow
            WHERE doc_id = :docid
        ";
	$row = getDataOne($query, $dbh, array('docid' => $docid));
	
	$form_json = json_decode($row['data'], true);
	$formhtml = $form_json['order_html'];
	
	if($row['isTemplate'] == 'Yes'){
		$isTemplate = 1;
	}
	else{
		$isTemplate = 0;
	}
	
	$ffile = createOrderPDF($formhtml, $ucn, $row['formname'], $isTemplate);
	
	$from = "CAD-Division" . $div . "@jud12.flcourts.org";
	//$from = "lkries@jud12.flcourts.org";
	
    if (mail_attachment($ffile, $creator, $from, "", "REJECTED PROPOSED ORDER: $ucn", "The attached order has been rejected by the court for the following reason:<br><br>$comments<br><br>")) {
        #
        # now remove from workflow...
        #
        /*$query = "
            delete
                from
            workflow
                where doc_id = :docid
        ";*/
    	
    	//Update as finished with reject comment.. don't delete it
    	$comments = "REJECTED - REASON: $comments"; # a prefix for the local user's comment section
    	$query = "
        update
            workflow
        set
            comments = :comments,
    		finished = 1
        where
            doc_id = :docid";
    	doQuery($query, $dbh, array('comments' => $comments, 'docid' => $docid));
    
        updateQueue($queue, $dbh);
        
    } else {
        # e-mail error-log it!
        file_put_contents("php://stderr","$ts: wfreject.php E-MAIL ERROR: ($docid,$creator,$queue,$ucn,$comments,$ffile)\n",FILE_APPEND);
        echo "ERROR";
        exit();
    }
}

$result = array();
$result['status'] = "Success";
header('application/json');
print json_encode($result);
?>