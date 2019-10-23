<?php

require_once $_SERVER['JVS_DOCROOT'] . "/php-lib/common.php";
require_once $_SERVER['JVS_DOCROOT'] . "/php-lib/db_functions.php";
require_once $_SERVER['JVS_DOCROOT'] . "/icmslib.php";
require_once $_SERVER['JVS_DOCROOT'] . "/caseinfo.php";
require_once($_SERVER['JVS_DOCROOT'] . "/workflow/wfcommon.php");

require_once('Smarty/Smarty.class.php');

checkLoggedIn();

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);

$uploadDir = $_SERVER['JVS_DOCROOT'] . "/uploads";

$docInfo = array();
$docid = getReqVal('docid');
$ucn = getReqVal('ucn');
if(isset($docid) && !empty($docid)){
	//unsetQueueVars();
	$docInfo = getDocData($docid);
	$docid = $docInfo['docid'];
	$isOrder = $docInfo['isOrder'];
}

$olsdbh = dbConnect("ols");
$dbh = dbConnect("icms");
$user = $_SESSION['user'];

if(!empty($_POST)){
	$supportingCount = 1;
	while(!empty($_FILES['customSupportingDoc_' . $supportingCount]['name'])){
		$suppInfo = pathinfo($_FILES['customSupportingDoc_' . $supportingCount]['name']);	
		$supportingCount++;
	}
	
	$caseInfo = getCaseDivAndStyle($ucn);
	$div = $caseInfo[0];
	$cs = $caseInfo[1];
	
	$suppDocs = array();
	for($i = 1; $i < $supportingCount; $i++){
		$fName = preg_replace('/[^a-zA-Z0-9-_\.]/','', $_FILES['customSupportingDoc_' . $i]['name']);
		$suppName = "$uploadDir/$user/$ucn" . "_" . $fName;
		
		$title = htmlentities($_POST['customSupportingTitle_' . $i], ENT_QUOTES);
			
		if(empty($title)){
			$title = "Attachment " . $i;
		}
		
		if(!file_exists("$uploadDir/$user")) {
			mkdir("$uploadDir/$user", 0755, true);
		}
			
		move_uploaded_file($_FILES['customSupportingDoc_' . $i]['tmp_name'], $suppName);
			
		if(!file_exists($suppName)){
			$suppError = true;
		}
		else{
			
			$suppName = "/uploads/$user/$ucn" . "_" . $fName;
			$iQuery = "INSERT INTO olscheduling.supporting_documents
						(
							workflow_id,
							case_number,
							case_style,
							division_id,
							document_title,
							file,
							jvs_doc,
							creation_time,
							jvs_user
						)
						VALUES 
						(
							:doc_id,
							:ucn,
							:case_style,
							:division_id,
							:title,
							:file,
							1,
							NOW(),
							:user
						)";
			
			$args = array();
			$args['doc_id'] = $docid;
			$args['ucn'] = $ucn;
			$args['case_style'] = $cs;
			$args['division_id'] = $div;
			$args['title'] = $title;
			$args['file'] = $suppName;
			$args['user'] = $user;
			
			doQuery($iQuery, $olsdbh, $args);
		}
	}
}

$oaQuery = " SELECT document_title,
			 file,
			 supporting_doc_id,
			 efile_attach
			 FROM olscheduling.supporting_documents
			 WHERE workflow_id = :doc_id
			 AND (jvs_doc IS NULL OR jvs_doc = 0)";

$olsDocs = array();
getData($olsDocs, $oaQuery, $olsdbh, array("doc_id" => $docid));

$jaQuery = " SELECT document_title,
			 file,
			 supporting_doc_id,
			 efile_attach
			 FROM olscheduling.supporting_documents
			 WHERE workflow_id = :doc_id
			 AND jvs_doc = 1";

$jvsDocs = array();
getData($jvsDocs, $jaQuery, $olsdbh, array("doc_id" => $docid));

$omQuery = " SELECT document_title,
			 CASE
				WHEN jvs_file_path IS NOT NULL
					THEN jvs_file_path
				ELSE
					file
			 END AS file,
			 supporting_doc_id,
			 efile_attach
			 FROM olscheduling.supporting_documents
			 WHERE workflow_id = :doc_id
			 AND order_merge = 1";

$mergeDocs = array();
getData($mergeDocs, $omQuery, $olsdbh, array("doc_id" => $docid));

$myqueues = array($user);
$sharedqueues = array();

getSubscribedQueues($user, $dbh, $myqueues);
getSharedQueues($user, $dbh, $sharedqueues);
$allqueues = array_merge($myqueues,$sharedqueues);
$wfcount = getQueues($queueItems,$allqueues,$dbh);

$url = "/workflow/attachments.php?fromTabs=1&docid=" . $docid . "&ucn=" . $ucn;
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

$xml = simplexml_load_file($icmsXml);

$smarty->assign('olsURL', $xml->olsURL);
$smarty->assign('merge_docs', $mergeDocs);
$smarty->assign('jvs_docs', $jvsDocs);
$smarty->assign('ols_docs', $olsDocs);
$smarty->assign('pdf_file', $docInfo['pdf_file']);
$smarty->assign('signature_html', key_exists('signature_html', $docInfo) ? $docInfo['signature_html'] : null);
$smarty->assign('signature_img', key_exists('signature_img', $docInfo) ? $docInfo['signature_img'] : null);
$smarty->assign('isOrder', $isOrder);
$smarty->assign('ucn', $ucn);
$smarty->assign('docid', $docid);
$smarty->assign('wfCount', $wfcount);
$smarty->assign('active', "cases");
$smarty->assign('tabs', $_SESSION['tabs']);
$smarty->display('top/header.tpl');
echo $smarty->fetch("workflow/attachments.tpl");
