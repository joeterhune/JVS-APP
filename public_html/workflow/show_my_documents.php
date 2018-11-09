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
		IFNULL(DATE_FORMAT(transfer_date,'%m/%d/%Y'), \"\") as TransferDate,
		IFNULL(comments, \"\") as Comments,
		doc_id,
		case_style,
		CASE doc_type
        	WHEN 'FORMORDER' then 'IGO'
            WHEN 'DVI' then 'DVI'
            WHEN 'MISCDOC' then 'Task'
            WHEN 'OLSORDER' then 'PropOrd'
        	WHEN 'WARRANT' then 'Warrant'
        	WHEN 'EMERGENCYMOTION' then 'EmerMot'
        END as doc_type,
		creator,
		CASE 
			WHEN doc_type = 'FORMORDER'
				THEN 1
			ELSE 0
		END AS isOrder,
		queue,
		CASE
            WHEN efile_submitted = 1 AND finished = 1
            	THEN 'e-Filed'
            WHEN finished = 1 AND comments LIKE 'REJECT%'
				THEN 'Rejected'
			WHEN efile_submitted = 0 AND finished = 1
				THEN 'Finished'
			WHEN deleted = 1
				THEN 'Deleted'
			ELSE
				'Pending'
		END as current_status
    from
        workflow
    where
        REPLACE(creator, '@jud12.flcourts.org', '') = :queue
		and queue <> REPLACE(creator, '@jud12.flcourts.org', '')
    order by
        creation_date desc
";

$my_docs = array();
getData($my_docs, $query, $dbh, array('queue' => $queue));

if($pagesize == "All"){
	$pagesize = count($my_docs);
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

	if($endrow > count($my_docs)){
		$endrow = count($my_docs);
	}
}

createTab("Documents I've Created - " . $queue, "/workflow/show_my_documents.php?queue=" . $queue, 1, 1, "workflow");

$smarty->assign('my_docs', $my_docs);
$smarty->assign('wfCount', $wfcount);
$smarty->assign('active', "workflow");
$smarty->assign('tabs', $_SESSION['tabs']);
$smarty->assign('queue', $queue);
$smarty->assign('pagesize', $pagesize);
$smarty->assign('pagenum', $pagenum);
$smarty->assign('pagerOptions', array('5', '10', '25', '50', '100', '250', '500', '1000', '2500', '5000', '10000', 'All'));
$smarty->assign('lastpage', ceil(count($my_docs) / $pagesize));
$smarty->assign('rowCount', count($my_docs));
$smarty->assign('showpage', $pagenum);
$smarty->assign('next', $pagenum + 1);
$smarty->assign('prev', $pagenum - 1);
$smarty->assign('begrow', $begrow);
$smarty->assign('endrow', $endrow);

$html = $smarty->fetch('workflow/showMyDocuments.tpl');

if(!$ajax){
	$smarty->display('top/header.tpl');

	echo $html;
}
else{
	$headerCount = 9;
	$dataArray = array();
	$rowCount = 0;
	
	$headers = array("doc_type", "UCN", "case_style", "Title", "CreationDate", "queue", "current_status", "TransferDate", "Comments");
	$dataArray['headers'] = $headers;
	$headerInfo = array();
	
	$headerInfo[0]['name'] = "Type";
	$headerInfo[0]['type'] = "S";
	$headerInfo[0]['colname'] = "doc_type";
	$headerInfo[0]['filter_placeholder'] = "Part of Type";
	$headerInfo[0]['filter_type'] = "filter-select";
	$headerInfo[0]['cellClass'] = "";
	$headerInfo[0]['class'] = "";
	
	$headerInfo[1]['name'] = "UCN";
	$headerInfo[1]['type'] = "L";
	$headerInfo[1]['colname'] = "UCN";
	$headerInfo[1]['filter_placeholder'] = "Part of Case #";
	$headerInfo[1]['filter_type'] = "";
	$headerInfo[1]['cellClass'] = "";
	$headerInfo[1]['class'] = "caseLink";
	
	$headerInfo[2]['name'] = "Case Style";
	$headerInfo[2]['type'] = "I";
	$headerInfo[2]['colname'] = "case_style";
	$headerInfo[2]['filter_placeholder'] = "Part of Case Style";
	$headerInfo[2]['filter_type'] = "";
	$headerInfo[2]['cellClass'] = "";
	$headerInfo[2]['class'] = "";
	
	$headerInfo[3]['name'] = "Title";
	$headerInfo[3]['type'] = "I";
	$headerInfo[3]['colname'] = "Title";
	$headerInfo[3]['filter_placeholder'] = "Part of Title";
	$headerInfo[3]['filter_type'] = "";
	$headerInfo[3]['cellClass'] = "";
	$headerInfo[3]['class'] = "";
	
	$headerInfo[4]['name'] = "Creation Date";
	$headerInfo[4]['type'] = "S";
	$headerInfo[4]['colname'] = "CreationDate";
	$headerInfo[4]['filter_placeholder'] = "Creation Date";
	$headerInfo[4]['filter_type'] = "filter-select";
	$headerInfo[4]['cellClass'] = "";
	$headerInfo[4]['class'] = "";
	
	$headerInfo[5]['name'] = "Current Queue";
	$headerInfo[5]['type'] = "S";
	$headerInfo[5]['colname'] = "queue";
	$headerInfo[5]['filter_placeholder'] = "Current Queue";
	$headerInfo[5]['filter_type'] = "filter-select";
	$headerInfo[5]['cellClass'] = "";
	$headerInfo[5]['class'] = "";
	
	$headerInfo[6]['name'] = "Current Status";
	$headerInfo[6]['type'] = "S";
	$headerInfo[6]['colname'] = "current_status";
	$headerInfo[6]['filter_placeholder'] = "Current Status";
	$headerInfo[6]['filter_type'] = "filter-select";
	$headerInfo[6]['cellClass'] = "";
	$headerInfo[6]['class'] = "";
	
	$headerInfo[7]['name'] = "Last Transfer Date";
	$headerInfo[7]['type'] = "S";
	$headerInfo[7]['colname'] = "TransferDate";
	$headerInfo[7]['filter_placeholder'] = "Transfer Date";
	$headerInfo[7]['filter_type'] = "filter-select";
	$headerInfo[7]['cellClass'] = "";
	$headerInfo[7]['class'] = "";
	
	$headerInfo[8]['name'] = "Comments";
	$headerInfo[8]['type'] = "I";
	$headerInfo[8]['colname'] = "Comments";
	$headerInfo[8]['filter_placeholder'] = "Part of Comment";
	$headerInfo[8]['filter_type'] = "";
	$headerInfo[8]['cellClass'] = "";
	$headerInfo[8]['class'] = "";
	
	
	$dataArray['headerInfo'] = $headerInfo;
	
	$allDataRows = $my_docs;
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
		$dataArray['total_rows'] = count($my_docs);
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