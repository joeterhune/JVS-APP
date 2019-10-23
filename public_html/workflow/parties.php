<?php
require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/common.php");
require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/db_functions.php");
require_once($_SERVER['JVS_DOCROOT'] . "/workflow/wfcommon.php");
include $_SERVER['JVS_DOCROOT'] . "/icmslib.php";
include $_SERVER['JVS_DOCROOT'] . "/caseinfo.php";

checkLoggedIn();

require_once("Smarty/Smarty.class.php");

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);

$docInfo = array();
$docid = getReqVal('docid');
$ucn = getReqVal('ucn');
if(isset($docid) && !empty($docid)){
	$docInfo = getDocData($docid);
	$ucn = $docInfo['ucn'];
	$docid = $docInfo['docid'];
}

$smarty->assign("clerkOnly", "0");
$clerkOnly = false;
if(isset($_REQUEST['clerkOnly'])){
	$clerkOnly = true;
	$smarty->assign("clerkOnly", "1");
}

#
# parties.php - displays a form to view/save party information
#               designed for both workflow AND order gen purposes...
#

$dbh = dbConnect("icms");
$user = $_SESSION['user'];
$close = getReqVal("close");
$isOrder = $docInfo['isOrder'];
$partypath = $_SERVER['JVS_ROOT'] . "/workflow/parties";

if($isOrder){
	$showclerk = 1;
}
else{
	$showclerk = 0;
}

$myqueues = array($user);
$sharedqueues = array();

// This will later be set in the form definition
$ck='checked="checked"';

list($ucn, $type) = sanitizeCaseNumber($ucn);

$icms = dbConnect("icms");

//$FORMDATA=new stdClass();
$FORMDATA = array();

if ($docid!="") {
    # called from workflow?
    $query = "
        select
            ucn,
            data
        from
            workflow
        where
            doc_id = :docid
    ";
    
    $rec = getDataOne($query, $icms, array('docid' => $docid));
    
    $ucn = $rec['ucn'];
    $formjson = $rec['data'];
    $FORMDATA=json_decode($formjson,true);
}

if ($ucn=="") {
    $result['Status'] = "Failure";
    $result['message'] = "Error: the case # for this document is blank! Please fill it in!";
    returnJson($result);
    exit; 
}

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
			$party['ServiceList'] = (array)$party['ServiceList'];
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
	$lastdata = "";
}

if(empty($docid)){
	$isOrder = 1;
}
    
if (!is_array($cclist)) {
    $cclist = $clerkcclist;
}

$FORMDATA['cc_list'] = $cclist;

getSubscribedQueues($user, $dbh, $myqueues);
getSharedQueues($user, $dbh, $sharedqueues);
$allqueues = array_merge($myqueues,$sharedqueues);
$wfcount = getQueues($queueItems,$allqueues,$dbh);

$url = "/workflow/parties.php?fromTabs=1&docid=" . $docid . "&ucn=" . $ucn;

createTab($ucn, $url, 1, 1, "cases",
		  array(
				"name" => "Order Creation",
				"active" => 1,
				"close" => 1,
				"href" => $url,
				"parent" => $ucn
		)
);

$smarty->assign('caption', $casestyle);

$smarty->assign('ucn', $ucn);
$smarty->assign('clerkdata', $clerkdata);
$smarty->assign('lastdata', $lastdata);
$smarty->assign('isorder', $isOrder);
$smarty->assign('ck', $ck);

$needsnail=0; # set to 1 if snail-mail required...
$needemail=0; # set to 1 if e-mail required...
$emails = array(); # list of addresses
foreach (array('Attorneys','Parties') as $type) {
    if (!array_key_exists($type, $cclist)) {
        continue;
    }
    
    foreach ($cclist[$type] as &$party) {
        $ck="checked";
        if ((array_key_exists('ServiceList', $party)) && (!sizeof($party['ServiceList']))) {
            $needsnail=1;
        } else {
            $needemail=1;
            if (array_key_exists('ServiceList', $party)) {
                $emails = array_merge($emails, $party['ServiceList']);
				
                if (sizeof($party['ServiceList']) == 1) {
                    if ($party['ServiceList'][0] == "") {
                        unset($party['ServiceList'][0]);
                        $needsnail = 1;
                    }
                }
            }
        }
    }    
}

$smarty->assign('cclist', $cclist);
$ccjson = htmlentities(json_encode($cclist));
$smarty->assign('ccjson', $ccjson);

$smarty->assign('needsnail', $needsnail);
$smarty->assign('needemail', $needemail);
$smarty->assign('emails', implode(",", $emails));
$smarty->assign('close', $close);

$smarty->assign('pdf_file', key_exists('pdf_file',$docInfo) ? $docInfo['pdf_file'] : null);
$smarty->assign('signature_html', key_exists('signature_html', $docInfo) ? $docInfo['signature_html'] : null);
$smarty->assign('signature_img', key_exists('signature_img', $docInfo) ? $docInfo['signature_img'] : null);
$smarty->assign('ucn', $docInfo['ucn']);
$smarty->assign('docid', $docInfo['docid']);
$smarty->assign('isOrder', $docInfo['isOrder']);
$smarty->assign('ucn', $ucn);
$smarty->assign('wfCount', $wfcount);
$smarty->assign('active', "cases");
$smarty->assign('tabs', $_SESSION['tabs']);

if(isset($_REQUEST['json'])){
	$smarty->assign('refresh', 1);
}
else{
	$smarty->assign('refresh', 0);
	$smarty->display('top/header.tpl');
}

echo $smarty->fetch("workflow/parties.tpl");
