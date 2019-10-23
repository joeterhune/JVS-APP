<?php
require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/common.php");
require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/db_functions.php");
require_once($_SERVER['JVS_DOCROOT'] . "/icmslib.php");
require_once($_SERVER['JVS_DOCROOT'] . "/caseinfo.php");
require_once($_SERVER['JVS_DOCROOT'] . "/workflow/wfcommon.php");

require_once('Smarty/Smarty.class.php');

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
}

$dbh = dbConnect("icms");
$user = $_SESSION['user'];

$myqueues = array($user);
$sharedqueues = array();

getSubscribedQueues($user, $dbh, $myqueues);
getSharedQueues($user, $dbh, $sharedqueues);
$allqueues = array_merge($myqueues,$sharedqueues);
$wfcount = getQueues($queueItems,$allqueues,$dbh);

$docid = $docInfo['docid'];

$url = "/orders/reject.php?fromTabs=1&docid=" . $docid . "&ucn=" . $ucn;
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

$doc_info = getWFDocInfo($docid);

$smarty->assign('pdf_file', $docInfo['pdf_file']);
$smarty->assign('signature_html', key_exists('signature_html', $docInfo) ? $docInfo['signature_html'] : null);
$smarty->assign('signature_img', key_exists('signature_img', $docInfo) ? $docInfo['signature_img'] : null);
$smarty->assign('ucn', $doc_info['ucn']);
$smarty->assign('creator', $doc_info['creator']);
$smarty->assign('current_queue', $doc_info['queue']);
$smarty->assign('isOrder', $docInfo['isOrder']);
$smarty->assign('docid', $docInfo['docid']);
$smarty->assign('wfCount', $wfcount);
$smarty->assign('active', "cases");
$smarty->assign('tabs', getSessVal('tabs'));
$smarty->display('top/header.tpl');
echo $smarty->fetch("orders/reject.tpl");
