<?php
require_once("../php-lib/common.php");
require_once("../php-lib/db_functions.php");
# wfaddformorder.php - posted from order/index.php

include "../icmslib.php";

#
# main program...
#

extract($_REQUEST);

$keepsigned = true;

$formdata['ucn'] = $ucn;

//fix_request(); # if called via command line, populate $_REQUEST anyway...
$ts=date("m/d/Y h:i:s A");

$result = array();

if(!empty($docid) && $isOrder){
	
	$docInfo = getDocData($docid);
	
	$orderData = array(
		"form_data" => $docInfo['formData'],
		"order_html" => $_REQUEST['order_html'],
		"cc_list" => $docInfo['cclist'],
		"case_caption" => $docInfo['case_caption'],
		"signature_html" => $docInfo['signature_html']
	);
	
	$data = json_encode($orderData);
}
else{
	$orderData = array(
		"ucn" => $ucn,
		"order_html" => $_REQUEST['order_html']
	);
	$data = json_encode($orderData);
}


$dbh = dbConnect("icms");

$creator = $_SESSION['user'];
$queue = getReqVal('queue');

if ($queue=="" || (empty($queue))) {
    $queue=$creator;
}

$color = "Red"; # hard-coded for now...
$duedate = date("Y-m-d" ,strtotime("+1 week")); # hard coded here too.

if(strpos(strtolower($form_name), "domestic violence") !== false){
	$doctype = "DVI";
}
else if ($isOrder) {
    $doctype="FORMORDER";
} else {
    $doctype = "OLSORDER";
}

$form_name = mb_convert_encoding($form_name, "HTML-ENTITIES", "UTF-8");

if(strpos($form_name, "Generic (Blank) Order") !== false){
	if(isset($_SESSION['generic_order_title']) && !empty($_SESSION['generic_order_title'])){
		$form_name = $_SESSION['generic_order_title'];
	}
}

$result = array();
$result['ORIGDOCID'] = $docid;

if ((!isset($docid)) || ($docid == "")) {
	
	list($div, $style) = getCaseDivAndStyle($ucn);
	
    #
    # ADD NEW
    #
    $query = "
        insert into
            workflow (
                queue,ucn,case_style,title,due_date,creator,creation_date,color,doc_type,formname,data,form_id, doc_lock_date, doc_lock_user, doc_lock_sessid
            )
            values (
                :queue, :ucn, :case_style, :formname, :due_date, :creator, CURRENT_TIMESTAMP,
                :color, :doctype, :formname, :data, :formid, NOW(), :user, :sessid
            )
    ";
    
    $args = array('queue' => $queue, 'ucn' => $ucn, 'case_style' => $style, 'due_date' => $duedate, 'creator' => $creator,
                  'color' => $color, 'doctype' => $doctype, 'formname' => $form_name, 'data' => $data,
                  'formid' => $form_id, 'user' => $_SESSION['user'], 'sessid' => session_id());
    
    if(!empty($form_name) && !empty($ucn)){
    	doQuery($query, $dbh, $args);
    	$new_doc_id = getLastInsert($dbh);
    	
    	foreach($_SESSION['tabs'] as $key => $t){
    		if($t['name'] == $ucn){
    			if(strpos($t['href'], "docid=&") !== false){
    				$href = str_replace("docid=&", "docid=" . $new_doc_id . "&", $t['href']);
    				$_SESSION['tabs'][$key]['href'] = $href;
    			}
    			
    			if(is_array($t['tabs'])){
    				foreach($t['tabs'] as $key2 => $t2){
    					if(strpos($t2['href'], "docid=&") !== false){
    						$href = str_replace("docid=&", "docid=" . $new_doc_id . "&", $t2['href']);
    						$_SESSION['tabs'][$key]['tabs'][$key2]['href'] = $href;
    					}
    				}
    			}
    		}
    	}
    }
    
    $result['PLACE'] = 'A';
    
    $docid = getLastInsert($dbh);
    $logMsg = "User $creator created document ID $docid ('$form_name') in workflow queue '$queue'";
    $logIP = $_SERVER['REMOTE_ADDR'];
    log_this('JVS','workflow',$logMsg,$logIP,$dbh);
} else {
    #
    # an UPDATE
    #
    
    $args = array('data' => $data, 'docid' => $docid, 'formid' => $form_id);
    
    $extra = "";
    /*if (!$keepsigned) {
        $extra = "
            ,
            signer_name = null,
            signer_title = null,
            signed_time = null,
            signature_file = null,
            signature_img = null,
            conformed_sig_file = null,
            conformed_sig_img = null,
            efile_queued = 0,
            efile_submitted = 0,
            efile_pended = 0,
            efile_completed = 0,
            mailing_confirmed = 0,
            mailing_confirmed_by = null,
            mailing_confirmed_time = null,
            finished = 0,
            signed_pdf = null,
            signed_filename = null,
            signed_binary_size = null,
            emailed = 0,
            emailed_time = null,
            emailed_from_addr = null
        ";
    }*/
    
    $query = "
        update
            workflow
        set
            data = :data,
            doc_lock_date = NOW(),
            doc_lock_user = :user,
            doc_lock_sessid = :sessid
            $extra
        where
            doc_id = :docid
    ";
    $result['PLACE'] = 'B';
    doQuery($query, $dbh, array("data" => $data, "docid" => $docid, "user" => $_SESSION['user'], "sessid" => session_id()));
    
    if(isset($form_id) && !empty($form_id)){
	    $query = "
		    update
		    	workflow
		    set
		    	form_id = :formid,
	    		title = :title,
	    		doc_lock_date = NOW(),
	    		doc_lock_user = :user,
	    		doc_lock_sessid = :sessid
		    where
		    	doc_id = :docid
		";
		$result['PLACE'] = 'B';
		doQuery($query, $dbh, array("formid" => $form_id, "docid" => $docid, "title" => $form_name, "user" => $_SESSION['user'], "sessid" => session_id()));
    }
    
    # Also delete the record from queued_filings
    $query = "
        delete from
            queued_filings
        where
            doc_id = :docid
    ";
    doQuery($query, $dbh, array('docid' => $docid));
    
    $user = $_SESSION['user'];
    $logMsg = "User $user saved changes to document ID $docid";
    $logIP = $_SERVER['REMOTE_ADDR'];
    //log_this('JVS','workflow',$logMsg,$logIP,$dbh);
}
# in either case, set last_update in the workqueue...
#
$query = "
    update
        workqueues
    set
        last_update=now()
    where
        queue = :queue
";
doQuery($query, $dbh, array('queue' => $queue));


$result['status'] = "OK";
$result['docid'] = $docid;

header('Content-type: application/json');
print json_encode($result);
?>
