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

if (!isset($queue)) {
	echo "No queue specified.";
    exit;
}

$query = "
    select
        ucn as UCN,
        title as Title,
        DATE_FORMAT(creation_date,'%m/%d/%Y') as CreationDate,
		IFNULL(comments, \"\") as Comments,
		doc_id,
		doc_id as ReturnItemtoQueue,
		case_style,
		doc_type,
		creator,
		CASE 
			WHEN doc_type = 'FORMORDER'
				THEN 1
			ELSE 0
		END AS isOrder
    from
        workflow
    where
        queue = :queue
        and finished = 1
    order by
        creation_date desc
";
$finished = array();
getData($finished, $query, $dbh, array('queue' => $queue));

if($pagesize == "All"){
	$pagesize = count($finished);
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

	if($endrow > count($finished)){
		$endrow = count($finished);
	}
}

createTab("Finished Items - " . $queue, "/workflow/showfinished.php?queue=" . $queue, 1, 1, "workflow");

$smarty->assign('finished', $finished);
$smarty->assign('wfCount', $wfcount);
$smarty->assign('active', "workflow");
$smarty->assign('tabs', $_SESSION['tabs']);
$smarty->assign('queue', $queue);
$smarty->assign('pagesize', $pagesize);
$smarty->assign('pagenum', $pagenum);
$smarty->assign('pagerOptions', array('5', '10', '25', '50', '100', '250', '500', '1000', '2500', '5000', '10000', 'All'));
$smarty->assign('lastpage', ceil(count($finished) / $pagesize));
$smarty->assign('rowCount', count($finished));
$smarty->assign('showpage', $pagenum);
$smarty->assign('next', $pagenum + 1);
$smarty->assign('prev', $pagenum - 1);
$smarty->assign('begrow', $begrow);
$smarty->assign('endrow', $endrow);

$html = $smarty->fetch('workflow/showFinished.tpl');

if(!$ajax){
	$smarty->display('top/header.tpl');

	echo $html;
}
else{
	$headerCount = 9;
	$dataArray = array();
	$rowCount = 0;
	
	$headers = array("UCN", "case_style", "Title", "creator", "CreationDate", "Comments", "ReturnItemtoQueue");
	$dataArray['headers'] = $headers;
	$headerInfo = array();
	
	$headerInfo[0]['name'] = "UCN";
	$headerInfo[0]['type'] = "L";
	$headerInfo[0]['colname'] = "UCN";
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
	$headerInfo[2]['colname'] = "Title";
	$headerInfo[2]['filter_placeholder'] = "Part of Title";
	$headerInfo[2]['filter_type'] = "";
	$headerInfo[2]['cellClass'] = "";
	$headerInfo[2]['class'] = "";
	
	$headerInfo[3]['name'] = "Creator";
	$headerInfo[3]['type'] = "S";
	$headerInfo[3]['colname'] = "creator";
	$headerInfo[3]['filter_placeholder'] = "Creator";
	$headerInfo[3]['filter_type'] = "filter-select";
	$headerInfo[3]['cellClass'] = "";
	$headerInfo[3]['class'] = "";
	
	$headerInfo[4]['name'] = "Creation Date";
	$headerInfo[4]['type'] = "S";
	$headerInfo[4]['colname'] = "CreationDate";
	$headerInfo[4]['filter_placeholder'] = "Creation Date";
	$headerInfo[4]['filter_type'] = "filter-select";
	$headerInfo[4]['cellClass'] = "";
	$headerInfo[4]['class'] = "";
	
	$headerInfo[5]['name'] = "Comments";
	$headerInfo[5]['type'] = "I";
	$headerInfo[5]['colname'] = "comments";
	$headerInfo[5]['filter_placeholder'] = "Part of Comment";
	$headerInfo[5]['filter_type'] = "";
	$headerInfo[5]['cellClass'] = "";
	$headerInfo[5]['class'] = "";
	
	$headerInfo[6]['name'] = "Return Item to Queue";
	$headerInfo[6]['type'] = "S";
	$headerInfo[6]['colname'] = "ReturnItemtoQueue";
	$headerInfo[6]['filter_placeholder'] = "";
	$headerInfo[6]['filter_type'] = "filter-disabled";
	$headerInfo[6]['cellClass'] = "";
	$headerInfo[6]['class'] = "";
	
	
	$dataArray['headerInfo'] = $headerInfo;
	
	$allDataRows = $finished;
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
						if(!existsInArray($dataRows, 'doc_id', $rd['doc_id'])){
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
				if(!existsInArray($dataRows, 'doc_id', $rd['doc_id'])){
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
		$dataArray['total_rows'] = count($finished);
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