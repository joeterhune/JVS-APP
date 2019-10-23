<?php
require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/common.php");
require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/db_functions.php");
require_once($_SERVER['JVS_DOCROOT'] . "/workflow/wfcommon.php");
require_once($_SERVER['JVS_DOCROOT'] . "/icmslib.php");
require_once('Smarty/Smarty.class.php');

checkLoggedIn();

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);

$xml = simplexml_load_file($_SERVER['JVS_ROOT'] . "/conf/ICMS.xml");

foreach($xml->dbConfig as $dbc){
	if ($dbc->name == "vrb2") {
		$vrb_db = $dbc->dbName;
	}
}

$user = getSessVal('user');
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

if (!isset($division)) {
	echo "No division specified.";
    exit;
}

$query = "
    SELECT case_number, 
	sd.case_style,
	CASE
		WHEN m_title IS NOT NULL
		THEN m_title
		WHEN motion_title IS NOT NULL
		THEN motion_title
		ELSE document_title
	END AS title,
	file,
	IFNULL(DATE(start_date), \"\") as start_date,
	IFNULL(TIME(start_date), \"\") as start_time,
	IFNULL(comments, \"\") AS comments,
	event_name,
	ea.email_addr,
	creation_time AS creation_date,
	CASE
		WHEN ec.canceled = 1
		THEN 'Y'
		WHEN e.canceled = 1
		THEN 'Y'
		ELSE 'N'
	END AS Canceled,
	CASE
		WHEN ec.canceled = 1
	THEN 'canceled'
		WHEN e.canceled = 1
	THEN 'canceled'
	ELSE ''
	END AS canceledClass
	FROM olscheduling.supporting_documents sd 
	LEFT OUTER JOIN " . $vrb_db . ".events e
		ON e.event_id = sd.event_id
	LEFT OUTER JOIN " . $vrb_db . ".event_cases ec
		ON sd.event_cases_id = ec.event_cases_id
	INNER JOIN olscheduling.email_addresses ea
		ON ea.email_addr_id = sd.creation_user_id
	LEFT OUTER JOIN olscheduling.predefmotions p
		ON p.m_type = sd.document_title
		AND p.division = sd.division_id
	LEFT OUTER JOIN umc.umc_motion_types m
		ON m.motion_type = sd.document_title
		AND m.umc_div = sd.division_id
	WHERE division_id = :division
	AND (jvs_doc IS NULL OR jvs_doc = 0)	
	ORDER BY creation_time DESC";

$documents = array();
getData($documents, $query, $dbh, array('division' => $division));


if(!empty($documents)){
	foreach($documents as $key => $d){
		if(!empty($d['start_date'])){
			$documents[$key]['start_date'] = date("m/d/Y", strtotime($d['start_date']));
		}
		if(!empty($d['start_time'])){
			$documents[$key]['start_time'] = date("H:i", strtotime($d['start_time']));
		}
		if(!empty($d['creation_date'])){
			$documents[$key]['creation_date'] = date("m/d/Y", strtotime($d['creation_date']));
		}
	}
}

if($pagesize == "All"){
	$pagesize = count($documents);
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

	if($endrow > count($documents)){
		$endrow = count($documents);
	}
}

createTab("OLS e-Courtesy - " . $division, "/workflow/show_ols_docs.php?division=" . $division, 1, 1, "workflow");

$xml = simplexml_load_file($_SERVER['JVS_ROOT'] . "/conf/ICMS.xml");
$smarty->assign('olsURL', $xml->olsURL);
$smarty->assign('documents', $documents);
$smarty->assign('wfCount', $wfcount);
$smarty->assign('active', "workflow");
$smarty->assign('tabs', $_SESSION['tabs']);
$smarty->assign('division', $division);
$smarty->assign('pagesize', $pagesize);
$smarty->assign('pagenum', $pagenum);
$smarty->assign('pagerOptions', array('5', '10', '25', '50', '100', '250', '500', '1000', '2500', '5000', '10000', 'All'));
$smarty->assign('lastpage', ceil(count($documents) / $pagesize));
$smarty->assign('rowCount', count($documents));
$smarty->assign('showpage', $pagenum);
$smarty->assign('next', $pagenum + 1);
$smarty->assign('prev', $pagenum - 1);
$smarty->assign('begrow', $begrow);
$smarty->assign('endrow', $endrow);

$html = $smarty->fetch('workflow/showOLSDocs.tpl');

if(!$ajax){
	$smarty->display('top/header.tpl');

	echo $html;
}
else{
	$headerCount = 9;
	$dataArray = array();
	$rowCount = 0;

	$headers = array("case_number", "case_style", "title", "email_addr", "start_date", "start_time", "comments", "creation_date", "Canceled");
	$dataArray['headers'] = $headers;
	$headerInfo = array();
	
	$headerInfo[0]['name'] = "Case #";
	$headerInfo[0]['type'] = "L";
	$headerInfo[0]['colname'] = "case_number";
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
	
	$headerInfo[2]['name'] = "Document";
	$headerInfo[2]['type'] = "I";
	$headerInfo[2]['colname'] = "title";
	$headerInfo[2]['filter_placeholder'] = "Part of Document Title";
	$headerInfo[2]['filter_type'] = "";
	$headerInfo[2]['cellClass'] = "";
	$headerInfo[2]['class'] = "";
	
	$headerInfo[3]['name'] = "Submitted By";
	$headerInfo[3]['type'] = "S";
	$headerInfo[3]['colname'] = "email_addr";
	$headerInfo[3]['filter_placeholder'] = "Submitted By";
	$headerInfo[3]['filter_type'] = "filter-select";
	$headerInfo[3]['cellClass'] = "";
	$headerInfo[3]['class'] = "";
	
	$headerInfo[4]['name'] = "Hearing Date";
	$headerInfo[4]['type'] = "S";
	$headerInfo[4]['colname'] = "start_date";
	$headerInfo[4]['filter_placeholder'] = "Hearing Date";
	$headerInfo[4]['filter_type'] = "filter-select";
	$headerInfo[4]['cellClass'] = "";
	$headerInfo[4]['class'] = "";
	
	$headerInfo[5]['name'] = "Hearing Time";
	$headerInfo[5]['type'] = "S";
	$headerInfo[5]['colname'] = "start_time";
	$headerInfo[5]['filter_placeholder'] = "Hearing Time";
	$headerInfo[5]['filter_type'] = "filter-select";
	$headerInfo[5]['cellClass'] = "";
	$headerInfo[5]['class'] = "";
	
	$headerInfo[6]['name'] = "Comments";
	$headerInfo[6]['type'] = "I";
	$headerInfo[6]['colname'] = "comments";
	$headerInfo[6]['filter_placeholder'] = "Part of Comment";
	$headerInfo[6]['filter_type'] = "";
	$headerInfo[6]['cellClass'] = "";
	$headerInfo[6]['class'] = "";
	
	$headerInfo[7]['name'] = "Submitted Date";
	$headerInfo[7]['type'] = "S";
	$headerInfo[7]['colname'] = "creation_date";
	$headerInfo[7]['filter_placeholder'] = "Submitted Date";
	$headerInfo[7]['filter_type'] = "filter-select";
	$headerInfo[7]['cellClass'] = "";
	$headerInfo[7]['class'] = "";
	
	$headerInfo[8]['name'] = "Canceled";
	$headerInfo[8]['type'] = "S";
	$headerInfo[8]['colname'] = "Canceled";
	$headerInfo[8]['filter_placeholder'] = "Canceled";
	$headerInfo[8]['filter_type'] = "filter-select";
	$headerInfo[8]['cellClass'] = "";
	$headerInfo[8]['class'] = "";
	
	$dataArray['headerInfo'] = $headerInfo;
	
	$allDataRows = $documents;
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
						if(!existsInArray($dataRows, 'file', $rd['file'])){
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
				if(!existsInArray($dataRows, 'file', $rd['file'])){
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
		$dataArray['total_rows'] = count($documents);
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