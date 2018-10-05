<?php
include "../php-lib/common.php";
include "../php-lib/db_functions.php";
require_once('Smarty/Smarty.class.php');
require_once("wfcommon.php");
require_once "../icmslib.php";

checkLoggedIn();

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);

$user = $_SESSION['user'];
$dbh = dbConnect("icms");

extract($_REQUEST);

if(!isset($pagenum)){
	$pagenum = 1;
}

if(!isset($pagesize)){
	$pagesize = 100;
}

$myqueues = array($user);
$queueItems = array();
$sharedqueues = array();

getSubscribedQueues($user, $dbh, $myqueues);
$smarty->assign('queues',$myqueues);

getSharedQueues($user, $dbh, $sharedqueues);
$smarty->assign('sharedqueues', $sharedqueues);

$allqueues = array_merge($myqueues,$sharedqueues);
$smarty->assign('allqueues',$allqueues);

$wfcount = getQueues($queueItems,$allqueues,$dbh);

extract($_REQUEST);

if (!isset($doc_id)) {
	echo "No document specified.";
    exit;
}

$query = "
    SELECT 	DATE_FORMAT(log_date_time, '%m/%d/%y %r') as log_date_time, 
			log_ip, 
			log_msg, 
			CASE
				WHEN w.ucn IS NULL
				THEN ''
				ELSE w.ucn
			END as ucn,
			CASE
				WHEN w.case_style IS NULL
				THEN ''
				ELSE w.case_style
			END as case_style,
			CASE
				WHEN w.title IS NULL
				THEN ''
				ELSE w.title
			END as title,
			CASE
				WHEN w.doc_id IS NULL
				THEN ''
				ELSE w.doc_id
			END as doc_id,
			CASE 
				WHEN w.doc_type = 'FORMORDER'
					THEN 1
				ELSE 0
			END AS isOrder,
			log_id
	FROM audit_log al
	LEFT OUTER JOIN workflow w
		ON substring_index(substring_index(al.log_msg, 'document ID ', -1), ' ', 1) = w.doc_id
	WHERE 
		log_app = 'JVS'
	AND
		log_type = 'workflow'
	AND 
		log_msg NOT LIKE '%saved changes%'
	AND 
		substring_index(substring_index(log_msg, 'document ID ', -1), ' ', 1) LIKE '%" . $doc_id . "%'
	AND 
		log_msg NOT LIKE '%attached to e-filing'
	ORDER BY
		log_date_time DESC
";

$doc_log = array();
getData($doc_log, $query, $dbh);

if($pagesize == "All"){
	$pagesize = count($doc_log);
}

if($pagenum == 0){
	$begrow = 1;
}
else{
	$begrow = (($pagenum) * $pagesize) + 1;
}

if($pagenum == 0){
	$endrow = $pagesize;
}
else{
	$endrow = (($pagenum) * $pagesize) + $pagesize;

	if($endrow > count($doc_log)){
		$endrow = count($doc_log);
	}
}

createTab("Document Log - Document ID " . $doc_id, "/case/workflow/view_doc_activity.php?doc_id=" . $doc_id, 1, 1, "workflow");

$smarty->assign('doc_log', $doc_log);
$smarty->assign('wfCount', $wfcount);
$smarty->assign('active', "workflow");
$smarty->assign('tabs', $_SESSION['tabs']);
$smarty->assign('doc_id', $doc_id);
$smarty->assign('pagesize', $pagesize);
$smarty->assign('pagenum', $pagenum);
$smarty->assign('pagerOptions', array('5', '10', '25', '50', '100', '250', '500', '1000', '2500', '5000', '10000', 'All'));
$smarty->assign('lastpage', ceil(count($doc_log) / $pagesize));
$smarty->assign('rowCount', count($doc_log));
$smarty->assign('showpage', $pagenum);
$smarty->assign('next', $pagenum + 1);
$smarty->assign('prev', $pagenum - 1);
$smarty->assign('begrow', $begrow);
$smarty->assign('endrow', $endrow);

$html = $smarty->fetch('workflow/viewDocActivity.tpl');

if(!$ajax){
	$smarty->display('top/header.tpl');

	echo $html;
}
else{
	$headerCount = 9;
	$dataArray = array();
	$rowCount = 0;
	
	$headers = array("ucn", "case_style", "title", "log_msg", "log_date_time");
	$dataArray['headers'] = $headers;
	$headerInfo = array();
	
	$headerInfo[0]['name'] = "UCN";
	$headerInfo[0]['type'] = "L";
	$headerInfo[0]['colname'] = "ucn";
	$headerInfo[0]['filter_placeholder'] = "Part of Case #";
	$headerInfo[0]['filter_type'] = "";
	$headerInfo[0]['cellClass'] = "";
	$headerInfo[0]['class'] = "caseLink";
	
	$headerInfo[1]['name'] = "Case Style";
	$headerInfo[1]['type'] = "I";
	$headerInfo[1]['colname'] = "case_style";
	$headerInfo[1]['filter_placeholder'] = "Part of Case Style";
	$headerInfo[1]['filter_type'] = "";
	$headerInfo[1]['cellClass'] = "";
	$headerInfo[1]['class'] = "";
	
	$headerInfo[2]['name'] = "Title";
	$headerInfo[2]['type'] = "I";
	$headerInfo[2]['colname'] = "title";
	$headerInfo[2]['filter_placeholder'] = "Part of Title";
	$headerInfo[2]['filter_type'] = "";
	$headerInfo[2]['cellClass'] = "";
	$headerInfo[2]['class'] = "";
	
	$headerInfo[3]['name'] = "Log Message";
	$headerInfo[3]['type'] = "I";
	$headerInfo[3]['colname'] = "log_msg";
	$headerInfo[3]['filter_placeholder'] = "Part of Message";
	$headerInfo[3]['filter_type'] = "";
	$headerInfo[3]['cellClass'] = "";
	$headerInfo[3]['class'] = "";
	
	$headerInfo[4]['name'] = "Activity Date and Time";
	$headerInfo[4]['type'] = "S";
	$headerInfo[4]['colname'] = "log_date_time";
	$headerInfo[4]['filter_placeholder'] = "Part of Date and Time";
	$headerInfo[4]['filter_type'] = "";
	$headerInfo[4]['cellClass'] = "";
	$headerInfo[4]['class'] = "";
	
	
	$dataArray['headerInfo'] = $headerInfo;
	
	$allDataRows = $doc_log;
	$dataRows = array();
	$totalRowCount = 0;
	$actualRowCount = 1;
	
	$allDataRows = array_values($allDataRows);
	
	if(!empty($_REQUEST['column'])){
		foreach($_REQUEST['column'] as $key => $c){
			$field = $headers[$key];
			if($c == 0){
				usort($allDataRows, sortAsc($field));
			}
			else{
				usort($allDataRows, sortDesc($field));
			}
		}
	}
	
	foreach($allDataRows as $key => $rd){
		//If a filter was set
		if(!empty($_REQUEST['filter'])){
			//Let's walk through all the filters
			foreach($_REQUEST['filter'] as $key2 => $rf){
				$field = $headers[$key2];
				//Otherwise do the normal stuff
				if(stripos($rd[$field], $rf) !== false){
					if($actualRowCount >= $begrow && ($actualRowCount < ($endrow + 1))){
						if(!existsInArray($dataRows, 'log_id', $rd['log_id'])){
							$dataRows[] = $rd;
							$actualRowCount++;
						}
					}
					else{
						$actualRowCount++;
					}
						
					$totalRowCount++;
				}
			}
		}
		//No filter set
		else{
			if($actualRowCount >= $begrow && ($actualRowCount < $endrow + 1)){
				if(!existsInArray($dataRows, 'log_id', $rd['log_id'])){
					$dataRows[] = $rd;
					$actualRowCount++;
				}
			}
			else{
				$actualRowCount++;
			}
				
			$totalRowCount++;
		}
	}
	
	//Another pass through
	if(!empty($_REQUEST['filter'])){
		//Let's walk through all the filters
		foreach($_REQUEST['filter'] as $key => $f){
			foreach($dataRows as $key2 => $d){
				$field = $headers[$key];
				if(stripos($d[$field], $f) === false){
					unset($dataRows[$key2]);
					$actualRowCount--;
				}
			}
		}
	
		if((count($dataRows) < $pagesize) && ($pagenum < 1)){
			$totalRowCount = count($dataRows);
		}
	}
	
	if(empty($_REQUEST['filter'])){
		$dataArray['total_rows'] = count($doc_log);
	}
	else{
		$dataArray['total_rows'] = $totalRowCount;
	}
	
	$dataRows = array_values($dataRows);
	$dataArray['totalPages'] = ceil($totalRowCount / $pagesize);
	$dataArray['pagenum'] = $pagenum + 1;
	$dataArray['rows'] = $dataRows;
	echo json_encode($dataArray);
}

function sortAsc($key) {
	return function ($a, $b) use ($key) {
		if(stripos($key, "date") !== false){
			$d1 = date("Y-m-d", strtotime($a[$key]));
			$d2 = date("Y-m-d", strtotime($b[$key]));
			return strcmp($d1, $d2);
		}
		else{
			return strcmp($a[$key], $b[$key]);
		}
	};
}

function sortDesc($key) {
	return function ($a, $b) use ($key) {
		if(stripos($key, "date") !== false){
			$d1 = date("Y-m-d", strtotime($a[$key]));
			$d2 = date("Y-m-d", strtotime($b[$key]));
			return strcmp($d2, $d1);
		}
		else{
			return strcmp($b[$key], $a[$key]);
		}
	};
}

function existsInArray($array, $key, $val) {
	foreach ($array as $item){
		if (isset($item[$key]) && $item[$key] == $val){
			return true;
		}
	}
	return false;
}