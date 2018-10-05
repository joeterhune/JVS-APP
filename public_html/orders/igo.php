<?php

require_once("../php-lib/common.php");
require_once("../php-lib/db_functions.php");
require_once('Smarty/Smarty.class.php');
require_once("../workflow/wfcommon.php");

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);

$docInfo = array();
$docid = getReqVal('docid');
$ucn = getReqVal('ucn');
$user = $_SESSION['user'];
$USER = $user;
$new = getReqVal('new');

if(isset($docid) && !empty($docid)){
	//unsetQueueVars();
	$docInfo = getDocData($docid);
	$ucn = $docInfo['ucn'];
	$docid = $docInfo['docid'];
}
else{
	$new = "Y";
}

if(!empty($new) && ($new == 'Y')){
	unsetQueueVars();
}

$case_id = getReqVal('caseid');
if(empty($case_id)){
	$case_id = $docInfo['caseid'];
}

$formid = getReqVal('formid');
if(empty($formid)){
	$formid = $docInfo['formid'];
}

$division = getCaseDiv($ucn);
$myqueues = array($user);
$sharedqueues = array();

$dbh = dbConnect("icms");

getSubscribedQueues($user, $dbh, $myqueues);
getSharedQueues($user, $dbh, $sharedqueues);
$allqueues = array_merge($myqueues,$sharedqueues);
$wfcount = getQueues($queueItems,$allqueues,$dbh);

$url = "/case/orders/igo.php?fromTabs=1&docid=" . $docid . "&ucn=" . $ucn;

createTab($ucn, $url, 1, 1, "cases",
	array(
		"name" => "Order Creation",
		"active" => 1,
		"close" => 1,
		"href" => $url,
		"parent" => $ucn
	)
);


$smarty->assign('DivisionID',$division);
$smarty->assign('DivCheck',"!".$division);
$smarty->assign('ucn', $ucn);

$shortcase = preg_replace('/-/','',$ucn);
if (preg_match("/^(\d{1,6})(\D\D)(\d{0,6})(.*)/", $shortcase, $matches)) {
	$casetype = $matches[2];
}
#
# first, make a dropdown with a list of all possible forms
#
#
$dbh = dbConnect("icms");

$query = "
	select
		form_id,
		form_name,
		case_div
	from
		forms
	where
		case_types like '%$casetype%'
		and (is_private is null OR (is_private=1 and shared_with like '%$USER%'))
		and ols_form = 0
	order
		by form_name
	";

$forms = array();

getData($forms, $query, $dbh);

$smarty->assign('forms', $forms);

if ($docid != "") { # get the formid
		$query = "
			select
				data,
				form_id
		        from
		            workflow
		        where
		            doc_id = :docid
		    ";
	
	    $doc = getDataOne($query, $dbh, array('docid' => $docid));
	    $formdata = json_decode($doc['data'],true);
	    $formid=$formdata['form_id'];
	    $smarty->assign('formid', $formid);
}

$smarty->assign('docid', $docid);

if(!empty($_SESSION['formData'])){
	$smarty->assign('formData', json_encode($docInfo['formData']));
	$smarty->assign('formid', $docInfo['formData']['form_id']);
}
else{
	$smarty->assign('formData', "");
	$smarty->assign('formid', $formid);
}

$docInfo['isOrder'] = 1;
$docInfo['ucn'] = $ucn;
$docInfo['docid'] = $docid;

$smarty->assign('isOrder', $docInfo['isOrder']);
$smarty->assign('ucn', $docInfo['ucn']);
$smarty->assign('docid', $docInfo['docid']);
$smarty->assign('wfCount', $wfcount);
$smarty->assign('active', "cases");
$smarty->assign('tabs', $_SESSION['tabs']);
$smarty->display('top/header.tpl');
$smarty->display('orders/igo.tpl');