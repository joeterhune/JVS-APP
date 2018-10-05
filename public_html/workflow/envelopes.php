<?php
require_once '../php-lib/common.php';
require_once '../php-lib/db_functions.php';
require_once "../icmslib.php";
require_once "../caseinfo.php";
require_once "mpdf60/mpdf.php";
require_once('Smarty/Smarty.class.php');
require_once("../workflow/wfcommon.php");

checkLoggedIn();

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);

$dbh = dbConnect("icms");
$user = $_SESSION['user'];

$docInfo = array();
$docid = getReqVal('docid');
$ucn = getReqVal('ucn');
if(isset($docid) && !empty($docid)){
	//unsetQueueVars();
	$docInfo = getDocData($docid);
	$ucn = $docInfo['ucn'];
	$docid = $docInfo['docid'];
	$isOrder = $docInfo['isOrder'];
	
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

#
# envelopes.php - displays a form to view/save party information
#               designed for both workflow AND order gen purposes...
#

$signedDoc = getReqVal('signed');

$url = "/case/workflow/envelopes.php?fromTabs=1&docid=" . $docid . "&ucn=" . $ucn;
	createTab($docInfo['ucn'], $url, 1, 1, "cases",
	array(
		"name" => "Order Creation",
		"active" => 1,
		"close" => 1,
		"href" => $url,
		"parent" => $docInfo['ucn']
	)
);

if($isOrder){
	$showclerk = 1;
}
else{
	$showclerk = 0;
}
    
$protocol = "http";
if ($_SERVER['HTTPS'] == 'on') {
	$protocol = "https";
}

$url = sprintf("%s://%s/case/orders/genpdf.php?env=Y", $protocol, $_SERVER['HTTP_HOST']);

$strCookie = 'PHPSESSID=' . $_COOKIE['PHPSESSID'] . '; path=/';
session_write_close();
$curl = curl_init();
curl_setopt_array($curl, array(
	CURLOPT_RETURNTRANSFER => 1,
	CURLOPT_URL => $url,
	CURLOPT_POST => 1,
	CURLOPT_POSTFIELDS => array(
		'ucn' => urlencode($ucn),
		'docid' => $docid
	),
	CURLOPT_SSL_VERIFYPEER => 0,
	CURLOPT_COOKIE => $strCookie
));

$resp = curl_exec($curl);
curl_close($curl);

$ofile = json_decode($resp, true);
$orderfname = sprintf("/var/www/html%s", $ofile['filename']);

$partypath="/usr/local/icms/workflow/parties";

$dbh = dbConnect("icms");

# get parties from DB...
$clerkcclist = array();

build_cc_list($icms,$ucn,$clerkcclist);

$clerkdata = "";

$lastdata = "";

list($fileucn,$type) = sanitizeCaseNumber($ucn);

$savedFile = sprintf("%s/%s.parties.json", $partypath, $fileucn);

if(!empty($showclerk) && ($showclerk == '1')){
	$casestyle = build_case_caption($ucn, $clerkcclist['Parties']);
	$cclist = $clerkcclist;
	$clerkdata="selected";
}

if (file_exists($savedFile) && !$clerkOnly) {
	$jsondata = json_decode(file_get_contents($savedFile), true);

	$cclistobj = $jsondata['cclist'];

	$partycount = 0;
	foreach ($cclistobj as $key=>$value) {
		$cclist[$key] = array();
		foreach ($value as &$party) {
			$party['ServiceList'] = (array)trim($party['ServiceList']);
			array_push($cclist[$key], $party);
		}
	}
	
	$lastdata="selected";
	$casestyle = $jsondata['casestyle'];
} elseif ($docid != "" && ($isOrder) && !$clerkOnly) {
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

if(is_array($cclist['Attorneys']) && is_array($cclist['Parties'])){
	$cclist = array_merge($cclist['Attorneys'], $cclist['Parties']);
}

$mpdf=new mPDF('c',array(241,105),0,'',120,15,51,16,9,9,'P');
# 9.5 x 4.125
# 241 x 105
$count=0;

$data['DivisionID'] = getCaseDiv($ucn);
$division = $data['DivisionID'];

$jdbh = dbConnect("judge-divs");

$query = "
    select
    	d.division_id,
    	UPPER(d.division_type) as DivisionType,
    	UPPER(j.first_name) as FirstName,
    	UPPER(j.middle_name) as MiddleName,
    	UPPER(j.last_name) as LastName,
    	UPPER(j.suffix) as Suffix,
        UPPER(c.courthouse_name) as CourthouseName,
    	UPPER(c.courthouse_addr) as Address,
    	UPPER(c.courthouse_city) as City,
    	UPPER(c.courthouse_state) as State,
    	UPPER(c.courthouse_zip) as ZIP
    from
    	divisions d 
    		left outer join judge_divisions jd on (d.division_id = jd.division_id)
    		left outer join judges j on (j.judge_id = jd.judge_id)
    		left outer join courthouses c on (d.courthouse_id=c.courthouse_id)
    where
    	d.division_id = :division
";

$divAddr = getDataOne($query, $jdbh, array('division' => $division));
$divAddr['FullName'] = buildName($divAddr);
$divAddr['CourthouseName'] = preg_replace('/COUNTY /','',$divAddr['CourthouseName']);

$divType = (preg_match('/CIRCUIT|FAMILY|JUVENILE|PROBATE|FELONY|FORECLOSURE/', $divAddr['DivisionType'])) ? 'CIRCUIT' : 'COUNTY COURT';

if(empty($_POST)){
	$sName = $divAddr['FullName'] . ", " . $divType . " JUDGE";
	$sAdd = "PALM BEACH COUNTY " . $divAddr['CourthouseName'] . "<br/>" . $divAddr['Address'] . "<br/>" . $divAddr['City'] . ", " . $divAddr['State'] . " " . $divAddr['ZIP'];
	$sAddOrig = "PALM BEACH COUNTY " . $divAddr['CourthouseName'] . "\r\n" . $divAddr['Address'] . "\r\n" . $divAddr['City'] . ", " . $divAddr['State'] . " " . $divAddr['ZIP'];;
}
else{
	$sender = trim($_REQUEST['custom_sender_name']);
	if(!empty($sender)){
		$sName = $sender;
	}
	else{
		$sName = $divAddr['FullName'] . ", " . $divType . " JUDGE";
	}
	
	$senderAdd = trim($_REQUEST['custom_sender_address']);
	
	if(!empty($senderAdd)){
		$sAdd = nl2br($senderAdd);
		$sAddOrig = $senderAdd;
	}
	else{
		$sAdd = "PALM BEACH COUNTY " . $divAddr['CourthouseName'] . "<br/>" . $divAddr['Address'] . "<br/>" . $divAddr['City'] . ", " . $divAddr['State'] . " " . $divAddr['ZIP'];
		$sAddOrig = $sAdd;
	}
}

$returnAddr = sprintf('<div style="position:absolute;top:5mm;left:5mm;width:120mm;"><strong>%s</strong><br/>%s</div>',
                      $sName, $sAdd);

if(isset($cclist['Parties'])){
	$cclist = $cclist['Parties'];
}

foreach ($cclist as $key => $cc) {
	
    if (sizeof($cc['ServiceList']) && !empty($cc['ServiceList']) && (!empty($cc['ServiceList'][0]))) {
        // This is an e-Service user.  No envelope here.
        continue;
    }
    
    //I'm not sure why we wouldn't want Pro Se parties...?
    /*if (($cc['BarNumber'] == "") && (!$cc['ProSe'])) {
        // Party that is NOT pro se.
        continue;
    }*/
    
	//Only print the checked ones...
    if(isset($cc['check']) && ($cc['check'] == '1')){
	    $name = $cc['FullName'];
	    $address = $cc['FullAddress'];
	    $address=str_replace("\n","<br>",$address);
	    $address=str_replace("\r","",$address);
	    $mpdf->AddPage();
	    $mpdf->writeHTML("$name<br>$address<p>");
	    $mpdf->writeHTML($returnAddr);
	    $count++;
    }
}

$envname = tempnam("/var/www/html/tmp","env");
$mpdf->Output($envname);
rename($envname,"$envname.pdf");

$mailjob = tempnam("/var/www/html/tmp","mail");
rename($mailjob,"$mailjob.pdf");
$mailjob .= ".pdf";

# and concatenate the appropriate # of orders
for ($i = 0; $i < $count; $i++) {
    $cat .= "$orderfname ";
    
    //If there are non-merged supporting docs, merge those too
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
    				order_merge <> 1
				AND
					efile_attach = 1";
    
    $suppDocs = array();
    getData($suppDocs, $suppQuery, $dbh, array("doc_id" => $docid));
    
    if(!empty($suppDocs)){
    	foreach($suppDocs as $sd){
    		$path = "/var/www/html" . $sd['file'];
    		$cat .= "$path ";
    	}
    }
}

`gs -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -sOutputFile=$mailjob $envname.pdf $cat`;
$result = array();

$user = $_SESSION['user'];
$logMsg = "User $user generated mailing envelopes and printed copies for document ID $docid";
$logIP = $_SERVER['REMOTE_ADDR'];
log_this('JVS','workflow',$logMsg,$logIP,$dbh);

$smarty->assign('disable_reason', $disable_reason);
$smarty->assign('user', $user);
$smarty->assign('locked', $locked);
$smarty->assign('locked_user', $locked_user);
$smarty->assign('editable', $editable);
$smarty->assign('s_name', $sName);
$smarty->assign('s_add', $sAddOrig);
$smarty->assign('pdf_file', $docInfo['pdf_file']);
$smarty->assign('signature_html', $docInfo['signature_html']);
$smarty->assign('signature_img', $docInfo['signature_img']);
$smarty->assign('isOrder', $isOrder);
$smarty->assign('docid', $docid);
$smarty->assign('ucn', $ucn);
$smarty->assign('wfCount', $wfcount);
$smarty->assign('active', "cases");
$smarty->assign('tabs', $_SESSION['tabs']);
$smarty->assign('file', str_replace("/var/www/html","", $mailjob));
$smarty->display('top/header.tpl');
echo $smarty->fetch("orders/envelopes.tpl");
