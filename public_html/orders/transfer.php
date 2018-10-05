<?php
require_once '../php-lib/common.php';
require_once '../php-lib/db_functions.php';
require_once "../icmslib.php";
require_once "../caseinfo.php";
require_once('Smarty/Smarty.class.php');
require_once("../workflow/wfcommon.php");

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);

$docInfo = array();
$docid = getReqVal('docid');
$ucn = getReqVal('ucn');
if(isset($docid) && !empty($docid)){
	//unsetQueueVars();
	$docInfo = getDocData($docid);
	$docid = $docInfo['docid'];
	$isOrder = $docInfo['isOrder'];
}

$dbh = dbConnect("icms");
$user = $_SESSION['user'];

$myqueues = array($user);
$sharedqueues = array();

getSubscribedQueues($user, $dbh, $myqueues);
getSharedQueues($user, $dbh, $sharedqueues);
$allqueues = array_merge($myqueues,$sharedqueues);
$wfcount = getQueues($queueItems,$allqueues,$dbh);

$url = "/case/orders/transfer.php?fromTabs=1&docid=" . $docid . "&ucn=" . $ucn;
	createTab($docInfo['ucn'], $url, 1, 1, "cases",
		array(
		"name" => "Order Creation",
		"active" => 1,
		"close" => 1,
		"href" => $url,
		"parent" => $docInfo['ucn']
	)
);
	
$dbh = dbConnect("icms");
$user = $_SESSION['user'];
	
$real_xferqueues = array();
getTransferQueues($user, $dbh, $real_xferqueues);
$smarty->assign('real_xferqueues', $real_xferqueues);

$smarty->assign('ucn', $docInfo['ucn']);
$smarty->assign('title', $docInfo['form_name']);
$smarty->assign('queueName', $docInfo['queue']);
$smarty->assign('user_comments', $docInfo['user_comments']);
//$smarty->assign('comments', preg_replace("/[^A-Za-z0-9 ^<>:$!#-+.\.\*]/", '', nl2br($docInfo['comments'])));
$smarty->assign('comments', $docInfo['comments']);
$smarty->assign('pdf_file', $docInfo['pdf_file']);
$smarty->assign('signature_html', $docInfo['signature_html']);
$smarty->assign('signature_img', $docInfo['signature_img']);
$smarty->assign('isOrder', $isOrder);
$smarty->assign('docid', $docid);
$smarty->assign('wfCount', $wfcount);
$smarty->assign('active', "cases");
$smarty->assign('tabs', $_SESSION['tabs']);
$smarty->display('top/header.tpl');
echo $smarty->fetch("orders/transfer.tpl");
