<?php

require_once("../php-lib/common.php");
require_once("../php-lib/db_functions.php");
include "../icmslib.php";
require_once('Smarty/Smarty.class.php');
require_once("../workflow/wfcommon.php");
include "../caseinfo.php";

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);

$dbh = dbConnect("icms");
$close = getReqVal("close");
$user = $_SESSION['user'];

$locked = false;
$locked_user = "";
$editable = true;
$disable_reason = "";
$docInfo = array();
$docid = getReqVal('docid');
$ucn = getReqVal('ucn');
if(isset($docid) && !empty($docid)){
	//unsetQueueVars();
	$docInfo = getDocData($docid);
	
	if(empty($docid)){
		header("Location: igo.php?ucn=" . $ucn);
		die;
	}

	$ucn = $docInfo['ucn'];
	$docid = $docInfo['docid'];
	$form_name = $docInfo['form_name'];
	$form_id = $docInfo['form_id'];
	$sig_image = $docInfo['signature_img'];
	
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

$fromTemplate = false;
if(isset($_REQUEST['fromTemplate'])){
	$docInfo['formData'] = $_REQUEST;
	$docInfo['formid'] = $_REQUEST['form_id'];
	$docInfo['isOrder'] = 1;
	$isOrder = 1;
	$fromTemplate = true;
	$form_name = $_REQUEST['form_name'];
	$form_id = $_REQUEST['form_id'];
}

if(isset($_REQUEST['fromWF'])){
	$docInfo['docid'] = $_REQUEST['docid'];
	$docInfo['ucn'] = $_REQUEST['ucn'];
	$docInfo['isOrder'] = $_REQUEST['isOrder'];
	$isOrder = $_REQUEST['isOrder'];
	$docInfo['formData'] = "";
}

if(isset($_REQUEST['orderTitle'])){
	$_SESSION['generic_order_title'] = trim($_REQUEST['orderTitle']);
}
else{
	$_SESSION['generic_order_title'] = "";
}

//It's an IGO and no document was actually created yet
if(empty($docid) && empty($_REQUEST['fromTemplate'])){
	header("Location: /case/orders/igo.php?ucn=" . $ucn . "&new=Y");
	die;
}

if(empty($isOrder)){
	$isOrder = $docInfo['isOrder'];
}
$showclerk = getReqVal("showclerk"); # normally shows last order, then clerk...
$partypath = "/usr/local/icms/workflow/parties";
$sign = getReqVal('sign');

if(!empty($sign) && $sign == 'Y'){
	$sign = "Y";
}
else{
	$sign = "N";
}

$FORMDATA = array();

if(isset($_REQUEST['fromWF'])){
	# called from workflow?
	$query = "
        select
            ucn,
            data,
			form_id,
			doc_type,
			signature_img,
			signed_filename
        from
            workflow
        where
            doc_id = :docid
    ";

	$rec = getDataOne($query, $dbh, array('docid' => $docid));

	$ucn = $rec['ucn'];
	
	if($rec['doc_type'] == 'FORMORDER'){
		$existingIGO = true;
		$data = json_decode($rec['data'], true);
		
		if(!isset($data['form_data'])){
			$docInfo['formData'] = $data;
		}
		else{
			$docInfo['formData'] = $data['form_data'];
		}
		$docInfo['cc_list'] = $data['cc_list'];
		$docInfo['case_caption'] =  $data['case_caption'];
		$docInfo['signature_html'] =  $data['signature_html'];
		$docInfo['order_html'] = $data['order_html'];
		$docInfo['pdf_file'] =  $rec['signed_filename'];
		
		$formbody = $data['order_html'];
	}
	else{
		$formjson = $rec['data'];
		$form_info = json_decode($formjson, true);
		$formbody = $form_info['order_html'];
		
		$docInfo['form_data'] = $formbody;
		$docInfo['signature_html'] =  $rec['signature_img'];
		
		if(!empty($rec['signed_filename']) && file_exists("/var/www/html/tmp/" . $rec['signed_filename'])){
			$docInfo['pdf_file'] =  $rec['signed_filename'];
		}
	}
}
else{
	if(isset($docInfo['docid']) && !$fromTemplate){
		$form_info = @json_decode($docInfo['form_data'], true);
		if(json_last_error() !== JSON_ERROR_NONE){
			$form_info = $docInfo['form_data'];	
		}
		$formbody = $form_info['order_html'];
		
		if(empty($formbody)){
			$formbody = $docInfo['order_html'];
		}
	}
}

$formbody = rawurldecode($formbody);

$myqueues = array($user);
$sharedqueues = array();

# get parties from DB...
$clerkcclist = array();

build_cc_list($dbh, $ucn, $clerkcclist);

$clerkdata = "";

$lastdata = "";

list($fileucn,$type) = sanitizeCaseNumber($ucn);

$savedFile = sprintf("%s/%s.parties.json", $partypath, $fileucn);

if(!empty($showclerk) && ($showclerk == '1')){
	$casestyle = build_case_caption($ucn, $clerkcclist['Parties']);
	$cclist = $clerkcclist;
	$clerkdata="selected";
}

if (file_exists($savedFile)) {
	$jsondata = json_decode(file_get_contents($savedFile), true);

	$cclistobj = $jsondata['cclist'];

	$partycount = 0;
	foreach ($cclistobj as $key=>$value) {
		$cclist[$key] = array();
		foreach ($value as &$party) {
			$party['ServiceList'] = (array)$party['ServiceList'];
			array_push($cclist[$key], $party);
		}
	}
	
	$lastdata="selected";
	$casestyle = $jsondata['casestyle'];
} elseif ($docid != "" && ($isOrder)) {
	$cclist = $docInfo['cc_list'];

	if(empty($cclist)){
		$cclist = json_encode($clerkcclist);
	}

	$casestyle = build_case_caption($ucn, $clerkcclist['Parties']);
	$clerkdata="selected";
} else {
	# no saved data, no form data--just clerk data
	$casestyle = build_case_caption($ucn, $clerkcclist['Parties']);
	$cclist = $clerkcclist;
	$lastdata = "disabled";
}

if (!is_array($cclist)) {
	$cclist = $clerkcclist;
}

if(isset($docInfo['case_caption']) && !empty($docInfo['case_caption']) && $docInfo['case_caption'] != "MISSING(X)"){
	$casestyle = $docInfo['case_caption'];
}

if(isset($docInfo['cclist']) && !empty($docInfo['cclist']) && $docInfo['cclist'] != "MISSING(X)"){
	$cclist = $docInfo['cclist'];
	
	if(isset($cclist['Parties'])){
		ksort($cclist['Parties']);
	}
	
	if(isset($cclist['Attorneys'])){
		ksort($cclist['Attorneys']);
	}
	
}

if(is_string($cclist) && is_array(json_decode($cclist, true))){
	$cclist = $cclist;
}
else{
	$cclist = json_encode($cclist);
}

$schema = isset($_SERVER["HTTPS"]) ? "https:" : "http:";
$url = "$schema//$_SERVER[HTTP_HOST]/case/orders/merge.cgi";

if((!isset($docid) || empty($docid)) || (!empty($docid) && $fromTemplate) || (empty($formbody))){
	$curl = curl_init();
	curl_setopt_array($curl, array(
		CURLOPT_RETURNTRANSFER => 1,
		CURLOPT_URL => $url,
		CURLOPT_POST => 1,
		CURLOPT_POSTFIELDS => array(
			'cclist' => $cclist,
			'case_caption' => $casestyle,
			'formjson' => json_encode($docInfo['formData']),
			'encode' => 0
		),
		CURLOPT_SSL_VERIFYPEER => 0
	));
	
	$resp = curl_exec($curl);
	curl_close($curl);
	
	$json = json_decode($resp, true);
	$formbody = $json['html'];
}

//Replace case_caption/cc_list on an IGO?
if($isOrder){
	
	if(preg_match("/<p class=\"caseCaption\">(.*?)<\\/p>/is", $formbody, $case_caption_match)){
		$case_caption = $case_caption_match[1]; 
	}
	else{
		//I sure hope that the case caption is the first match....
		preg_match("/<p[^>]*class=\"left\">(.*?vs.*?)<\\/p>/is", $formbody, $case_caption_match);
		$case_caption = $case_caption_match[1]; 
	}
	
	//And I sure hope that the cc list is the first match for this, too
	preg_match("/<span style=\"font-weight: bold;\">COPIES TO:.*?<\\/table>/is", $formbody, $cc_list_match);
	$cc_list = $cc_list_match[0];
	
	//I don't really have a good way to do this, but the MH forms are messed up so I'm going to do it this way
	if(strpos($ucn, "MH") === false){
		$formbody = str_replace($case_caption, "[% case_caption %]", $formbody);
	}
	$formbody = str_replace($cc_list, "[% cc_list %]", $formbody);
	
	$post_fields = array(
		'cclist' => $cclist,
		'case_caption' => $casestyle,
		'formjson' => json_encode(
			array(
				"order_html" => $formbody
			)
		),
		'encode' => 1
	);
	
	if(!empty($docInfo['signature_html'])){
		$post_fields['sigdiv'] = $docInfo['signature_html'];
	}
	
	$curl = curl_init();
	curl_setopt_array($curl, array(
		CURLOPT_RETURNTRANSFER => 1,
		CURLOPT_URL => $url,
		CURLOPT_POST => 1,
		CURLOPT_POSTFIELDS => $post_fields,
		CURLOPT_SSL_VERIFYPEER => 0
	));
	
	$resp = curl_exec($curl);
	curl_close($curl);
	
	$json = json_decode($resp, true);
	$formbody = $json['html'];
}

$cclist_html = createCopiesToListHTML(json_decode($cclist, true));

getSubscribedQueues($user, $dbh, $myqueues);
getSharedQueues($user, $dbh, $sharedqueues);
$allqueues = array_merge($myqueues,$sharedqueues);
$wfcount = getQueues($queueItems,$allqueues,$dbh);

if($sign == 'Y'){
	$url = "/case/orders/preview.php?fromTabs=1&docid=" . $docid . "&sign=Y&ucn=" . $ucn;
}
else{
	$url = "/case/orders/preview.php?fromTabs=1&docid=" . $docid . "&ucn=" . $ucn;
}

createTab($ucn, $url, 1, 1, "cases",
	array(
		"name" => "Order Creation",
		"active" => 1,
		"close" => 1,
		"href" => $url,
		"parent" => $ucn
	)
);

# substitute the pagebreak back to a field...because ckeditor will wipe it otherwise
//$formbody=str_replace("<pagebreak />","[% pagebreak %]",$formbody);

$formbody = html_entity_decode($formbody);

$esigs = array();
$sigCount = getEsigs($esigs, $user);
foreach ($esigs as &$esig) {
	$esig['fullname'] = buildName($esig);
}

//Get rid of the double sig divs...
if(!isset($sig_image) || empty($sig_image)){
	$formbody = preg_replace("/<div class=\"sigdiv\">(.*?)<\\/div>/is", "<br/><br/>", $formbody);
	$formbody = preg_replace("/<div class=\"sigdiv right\">(.*?)<\\/div>/is", "<br/><br/>", $formbody);
}
else{
	preg_match("/(<div class=\"sigdiv\".*?>)(.*?)<\\/div>/is", $formbody, $sigDivs);
	if(count($sigDivs) > 2){
		$formbody = str_replace($sigDivs[1], "", $formbody);
	}
}

$smarty->assign('cclist_html', $cclist_html);
$smarty->assign('disable_reason', $disable_reason);
$smarty->assign('user', $user);
$smarty->assign('locked', $locked);
$smarty->assign('locked_user', $locked_user);
$smarty->assign('editable', $editable);
$smarty->assign('user_comments', $docInfo['user_comments']);
$smarty->assign('comments', $docInfo['comments']);
$smarty->assign('case_caption', $docInfo['case_caption']);
$smarty->assign('cclist', $docInfo['cclist']);
$smarty->assign('pdf_file', $docInfo['pdf_file']);
$smarty->assign('signature_html', $docInfo['signature_html']);
$smarty->assign('signature_img', $docInfo['signature_img']);
$smarty->assign('esigs', $esigs);
$smarty->assign('cansign', $sigCount);
$smarty->assign('sign', $sign);
$smarty->assign('isOrder', $isOrder);
$smarty->assign('docid', $docid);
$smarty->assign('form_name', $form_name);
$smarty->assign('form_id', $form_id);
$smarty->assign('formbody', $formbody);
$smarty->assign('ucn', $ucn);
$smarty->assign('wfCount', $wfcount);
$smarty->assign('active', "cases");
$smarty->assign('tabs', $_SESSION['tabs']);
$smarty->display('top/header.tpl');
echo $smarty->fetch("orders/preview.tpl");

function createCopiesToListHTML($cc_list){
	$cc_list_html = "";
	
	if ((isset($cc_list['Attorneys']) && !empty($cc_list['Attorneys'])) || (isset($cc_list['Parties']) && (!empty($cc_list['Parties'])))) {
		$cc_list_html = '<span style="font-weight: bold;">COPIES TO:</span><br/><br/><table id="cc_list_table" style="border: none; table-layout: fixed; max-width:6.5in;">';
		foreach($cc_list as $key => $cc) {
			foreach ($cc as $p => $party) {
				if(!$party['check']){
					continue;
				}
				
				$name = $party['FullName'];
				$address = $party['FullAddress'];
				$address = str_replace("\n", "<br/>", $address);
				
				if(empty($address)){
					$address = "No Address Available";
				}
				
				$svcList = "";
				if (empty($party['ServiceList']) || !isset($party['ServiceList'])) {
					$svcList = "No E-mail Address Available";
				}
				else if(count($party['ServiceList']) > 0){
					foreach($party['ServiceList'] as $sl){
						$sl = str_replace(";", "<br/>", $sl);
						$svcList .= $sl . "<br/>";
					}
					
					//explode?
				}
				else{
					$sl = str_replace(";", "<br/>", $sl);
					$svcList .= $sl;
				}
	
				$string = sprintf('<tr><td style="vertical-align:top; word-wrap:break-word; max-width:2.16in;">%s</td><td style="vertical-align:top; word-wrap:break-word; max-width:2.16in;">%s</td><td style="vertical-align:top; word-wrap:break-word; max-width:2.16in;">%s</td></tr>', $name, $address, $svcList);
				$cc_list_html .= $string;
			}
		}
	}
	
	$cc_list_html .= "</table>";
	return $cc_list_html;
}