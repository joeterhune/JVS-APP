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

$url = "/orders/transfer.php?fromTabs=1&docid=" . $docid . "&ucn=" . $ucn;
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
$smarty->assign('user_comments', key_exists('user_comments', $docInfo) ? $docInfo['user_comments'] : null);
$smarty->assign('comments', key_exists('comments', $docInfo) ? $docInfo['comments'] : null);
$smarty->assign('pdf_file', key_exists('pdf_file', $docInfo) ? $docInfo['pdf_file'] : null);
$smarty->assign('signature_html', key_exists('signature_html', $docInfo) ? $docInfo['signature_html'] : null);
$smarty->assign('signature_img', key_exists('signature_img', $docInfo) ? $docInfo['signature_img'] : null);
$smarty->assign('isOrder', $isOrder);
$smarty->assign('docid', $docid);
$smarty->assign('wfCount', $wfcount);
$smarty->assign('active', "cases");
$smarty->assign('tabs', $_SESSION['tabs']);
$smarty->display('top/header.tpl');
echo $smarty->fetch("orders/transfer.tpl");
