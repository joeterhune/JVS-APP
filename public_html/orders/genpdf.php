<?php
#
# genpdf.php - generates a pdf from the html data posted to it...
#

ini_set("max_execution_time", 300);

require_once "php-lib/common.php";
require_once "php-lib/db_functions.php";
include "icmslib.php";
require_once('Smarty/Smarty.class.php');
require_once("workflow/wfcommon.php");
include "caseinfo.php";

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);

extract($_REQUEST);

$options = getopt("e:d:u:");

if(!empty($options)){
	if(isset($options['e']) && !empty($options['e'])){
		$env = "Y";
	}
	if(isset($options['d']) && !empty($options['d'])){
		$docid = $options['d'];
	}
	else{
		$docid = getReqVal('docid');
	}
	if(isset($options['u']) && !empty($options['u'])){
		$ucn = $options['u'];
	}
	else{
		$ucn = getReqVal('ucn');
	}
}

$docInfo = array();

$dbh = dbConnect("icms");
$user = $_SESSION['user'];

if(isset($docid) && !empty($docid)){
	//unsetQueueVars();
	$docInfo = getDocData($docid);
	$ucn = $docInfo['ucn'];
	$docid = $docInfo['docid'];
	
	if($docInfo['creator'] == $user || ($docInfo['queue'] == $user)){
		$editable = true;
	}
	else{
		$subscribed_queues = array();
		getSubscribedQueues($user, $dbh, $subscribed_queues);
		$shared_queues = array();
		getSharedQueues($user, $dbh, $shared_queues);
	
		//if(in_array($docInfo['creator'], $subscribed_queues) || (in_array($docInfo['creator'], $shared_queues)) ||
		//(in_array($docInfo['queue'], $subscribed_queues)) || (in_array($docInfo['queue'], $shared_queues))){
		if(in_array($docInfo['queue'], $subscribed_queues) || (in_array($docInfo['queue'], $shared_queues))){
			$editable = true;
		}
		else{
			$editable = false;
			$disable_reason = "Because you do not have access to this queue, this document will open in read-only mode.";
		}
	}
	
	if(isset($docInfo['portal_filing_id'])){
		$fsQuery = "SELECT
						filing_status
					FROM
						portal_info.portal_filings
					WHERE
						filing_id = :filing_id";
	
		$pdbh = dbConnect("portal_info");
		$fsRow = getDataOne($fsQuery, $pdbh, array("filing_id" => $docInfo['portal_filing_id']));
	
		if($fsRow['filing_status'] != "Correction Queue"){
			$editable = false;
			$disable_reason = "This document has already been e-filed.  It will open in read-only mode.";
		}
	}
	
	if($editable && isset($docInfo['doc_lock_date'])){
		date_default_timezone_set('America/New_York');
		$dock_lock_date = strtotime($docInfo['doc_lock_date']);
		$now = strtotime(date("Y-m-d H:i:s"));
	
		if(($now - $dock_lock_date) <= 10){
			$locked_user = $docInfo['doc_lock_user'];
			$locked_sess_id = $docInfo['doc_lock_sessid'];
				
			//The person holding the lock is the person trying to open it
			if($locked_sess_id == session_id()){
				$locked = false;
				$editable = true;
			}
			else{
				$locked = true;
				$editable = false;
			}
		}
	}
}

$myqueues = array($user);
$sharedqueues = array();

getSubscribedQueues($user, $dbh, $myqueues);
getSharedQueues($user, $dbh, $sharedqueues);
$allqueues = array_merge($myqueues,$sharedqueues);
$wfcount = getQueues($queueItems,$allqueues,$dbh);

if($env && ($env == 'Y')){
	$showJson = true;
}
else{
	$showJson = false;
}

if(empty($isOrder)){
	$isOrder = $docInfo['isOrder'];
}

$url = "/case/orders/genpdf.php?fromTabs=1&docid=" . $docid . "&ucn=" . $ucn;
	createTab($docInfo['ucn'], $url, 1, 1, "cases",
	array(
		"name" => "Order Creation",
		"active" => 1,
		"close" => 1,
		"href" => $url,
		"parent" => $docInfo['ucn']
	)
);

$formhtml = $docInfo['order_html'];

if(empty($formhtml)){
	$formhtml = $docInfo['form_data'];
}

//Convert from JSON if it's JSON
if(is_string($formhtml) && is_array(json_decode($formhtml, true))){
	$html = json_decode($formhtml, true);
	$formhtml = $html['order_html'];
}

if (isset($htmlfile)) {
    $formhtml=file_get_contents($htmlfile);
}  else {
    file_put_contents("/tmp/order-" . $ucn .".html", $formhtml);
}

# replace that pagebreak tag with the actual html
$formhtml=str_replace("[% pagebreak %]","<pagebreak />",$formhtml);
$formhtml=str_replace("style=\"color: blue;\""," ",$formhtml);

$query = " SELECT CASE WHEN form_id = '' OR form_id IS NULL
			THEN 'No'
			ELSE 'Yes'
		   END AS isTemplate,
		   title
		   FROM workflow
		   WHERE doc_id = :doc_id";

$row = getDataOne($query, $dbh, array("doc_id" => $docid));

if($row['isTemplate'] == 'Yes'){
	$isTemplate = 1;
}
else{
	$isTemplate = 0;
}

$formname = $row['title'];

$fname = createOrderPDF($formhtml, $ucn, $formname, $isTemplate);
$fname = sprintf(str_replace("/var/www/html", "", $fname));

//Check to see if attachments were added....
$suppQuery = "SELECT 
					CASE WHEN jvs_doc = 1
						THEN file
					ELSE jvs_file_path
					END AS file,
					document_title,
					order_merge
				FROM 
					olscheduling.supporting_documents
				WHERE 
					workflow_id = :doc_id
				AND 
					efile_attach = 1";

$suppDocs = array();
getData($suppDocs, $suppQuery, $dbh, array("doc_id" => $docid));

$docInfo['pdf_file'] = $fname;

//We will only show merged docs on preview screen
$pdfList = $docInfo['pdf_file'];
if(!empty($suppDocs)){
	foreach($suppDocs as $sd){
		
		if($sd['order_merge'] == '1'){
			$path = $sd['file'];
			$pdfList .= " /var/www/html" . $path;
		}
		
		if($pdfList != $docInfo['pdf_file']){
			$fname = "/tmp/comb-" . $docid . "-" . $ucn . ".pdf";
				
			if(file_exists($fname)){
				unlink($fname);
			}
				
			$command = "gs -q -dBATCH -dNOPAUSE -sDEVICE=pdfwrite -sOUTPUTFILE=/var/www/html$fname /var/www/html$pdfList > /dev/null 2>&1";
			$res = system($command);
			$docInfo['pdf_file'] = $fname;
		}
	}
}

$sigdiv = $docInfo['signature_html'];

//Let's save this anyway....
//if ((isset($sigdiv)) && ($sigdiv != "")) {
    // It's a signed doc.  Save the PDF to the workflow table
    $filestat = stat("/var/www/html" . $fname);
    $bsize = $filestat[7];
    $query = "
        update
            workflow
        set
            signed_pdf = :pdfdata,
            signed_filename = :filename,
            signed_binary_size = :binarysize
        where
            doc_id = :docid
    ";
    doQuery($query, $dbh, array('pdfdata' => encodeFile("/var/www/html" . $fname), 'filename' => basename($fname), 'binarysize' => $bsize, 'docid' => $docid));
//}

$user = $_SESSION['user'];
$logMsg = "User $user generated PDF for document ID $docid";
$logIP = $_SERVER['REMOTE_ADDR'];

$isSigned = isSigned($docid);

if(!$showJson){
	log_this('JVS','workflow',$logMsg,$logIP,$dbh);
	$smarty->assign('disable_reason', $disable_reason);
	$smarty->assign('user', $user);
	$smarty->assign('locked', $locked);
	$smarty->assign('locked_user', $locked_user);
	$smarty->assign('editable', $editable);
	$smarty->assign('isSigned', $isSigned);
	$smarty->assign('isOrder', $isOrder);
	$smarty->assign('docid', $docid);
	$smarty->assign('ucn', $ucn);
	$smarty->assign('wfCount', $wfcount);
	$smarty->assign('active', "cases");
	$smarty->assign('tabs', $_SESSION['tabs']);
	$smarty->assign('filename', sprintf(str_replace("/var/www/html","",$fname)));
	$smarty->display('top/header.tpl');
	echo $smarty->fetch("orders/pdf.tpl");
}
else{
	$results = array();
	$results['filename'] = sprintf(str_replace("/var/www/html","",$fname));
	returnJson($results);
}