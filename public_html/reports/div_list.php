<?php

ini_set('max_execution_time','0');	// no time limit

require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/common.php");
require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/db_functions.php");
require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/col_maps.php");
require_once($_SERVER['JVS_DOCROOT'] . "/workflow/wfcommon.php");
require_once($_SERVER['JVS_DOCROOT'] . "/ldapfunctions.php");

require_once("Smarty/Smarty.class.php");

checkLoggedIn();

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);

$user = $_SESSION['user'];
$fdbh = dbConnect("icms");

if(isset($_REQUEST['ajax'])){
	$ajax = true;
}
else{
	$ajax = false;
}

$myqueues = array($user);
$sharedqueues = array();

getSubscribedQueues($user, $fdbh, $myqueues);
getSharedQueues($user, $fdbh, $sharedqueues);
$allqueues = array_merge($myqueues, $sharedqueues);

$queueItems = array();

$wfcount = getQueues($queueItems, $allqueues, $fdbh);


global $secuserid,$secuser;
global $classMaps;

$classMaps = array(
    "L" => 'caseLink'
);


# supports these data types:
# N=numeric, G=age, D=Date, A=Alpha, R=group (for UFC), L=Link, T = Time (right aligns)
# new for ACL - S = case type field identifier - will be checked for AD, AJ, TE, TP, and TB
#             and I = Identifying info - - will be replaced with "- - restricted - -" when
#             appropriate.  Only one field can be marked as "S".
# new for photos, etc - C - align center

$rptdate="";

# pagination variables
# pagesize:  number of rows per page
# pagenum:  current page number
# lastpage:  last page number
# begrow:	beginning row on this page
# endrow:  ending row on this page
# finalrow:  last possible row (row count)
global $pagenum, $pagesize, $lastpage, $begrow, $endrow, $finalrow;


function prettydate($date) {
     $ax=substr($date,6,4).substr($date,0,2).substr($date,3,2);
     $bx=date("Ymd");
     if ($ax>$bx) {
        return "<font color=green>$date</font>";
        }
     return $date;
     }


function getval($varname,$infile) {
    $x=fgets($infile);
    list($vx,$val)=explode("=",$x);
    $vx=rtrim($vx);
    $val=rtrim($val);
    if ($vx!=$varname) {
        print "/reports/div_list.php: Error: variable $varname not encountered--(saw $vx instead)!\n";
        return("");
    }
    return($val);
}


function loaddata($rpath, &$data, $ageRange = null) {
    global $classMaps;
    global $colMaps;
    global $ranges;
	
	$inData = array();
	$config = array();
	
	readJsonFile($inData, $rpath);
	
    $report_date = $inData['date'];
	$config['rptdate'] = date_format(date_create($report_date), 'l, F jS, Y');
    
	$config['title1'] = $inData['title'];
    $config['title2'] = $inData['subtitle'];

    if ($ageRange != NULL) {
        $config['title2'] = sprintf("%s (Case Age %s)", $config['title2'], $ranges[$ageRange]['rangeString']);
    }
    
    $config['viewer'] = "/reports/div_list.php";
	$fldnames = $inData['reportCols'];
	
	$config['fields'] = array();
	
	$index = 0;
	$config['CaseAgeColumn'] = $index;
	
	foreach ($fldnames as $fieldName) {
		if (!key_exists($fieldName, $colMaps) || (!key_exists('type', $colMaps[$fieldName]))) {
			continue;
		}
		$map = $colMaps[$fieldName];
		$field = array();
		$field['name'] = key_exists('colHeader', $map) ? $map['colHeader'] : $fieldName;
		$field['type'] = $map['type'];
		$field['colname'] = $fieldName;
		$field['filter_placeholder'] = key_exists('filterPlaceholder', $map) ? $map['filterPlaceholder'] : '';
		$field['filter_type'] = key_exists('filter-type', $map) ? $map['filter-type'] : '';
		$field['cellClass'] = key_exists('cellClass', $map) ? $map['cellClass'] : '';
		$field['class'] = key_exists($map['type'], $classMaps) ? $classMaps[$map['type']] : '';
		
		$config['fields'][$fieldName] = $field;
		
		if ($fieldName == 'CaseAge') {
			$config['CaseAgeColumn'] = $index;
		}
		$index++;
	}
	
    # see if there's a secret type to check
    $secexists = 0;
    $secindex = 0;
    
    //for ($j=0;$j<count($fldtypes);$j++) {
    //    if((isset($fldtypes[$j])) && ($fldtypes[$j]=="S")) {
    //        $secexists = 1;
    //        $secindex = $j;
    //        break;
    //    }
    //}
    
    $config['secretUser'] = 1;
    if ($secexists) {
        $secuserid = $_SESSION['user'];
        $config['secretUser'] = inGroup($secuserid,'CAD-ICMS-SEC');
    }
	
	$data['reportData'] = $inData['reportData'];
    $data['config'] = $config;
	
    //$i=0;
    //while ($line = fgets($infile)) {
    //    $res[$i] = array();
    //    $pieces = explode("~", $line);
    //    for ($j = 0; $j < count($pieces); $j++) {
    //        //var_dump($colMaps[$fldnames[$j]]);
    //        $res[$i][$colMaps[$fldnames[$j]]['colName']] = $pieces[$j];
    //    }
    //    
    //    if ($ageRange != null) {
    //        if (($res[$i]['CaseAge'] < $ranges[$ageRange]['lower']) || ($res[$i]['CaseAge'] > $ranges[$ageRange]['upper'])) {
    //            // This one isn't in the specified range.  Remove from the stack and DON'T increment the counter
    //            unset($res[$i]);
    //            continue;
    //        }
    //    }
    //    
    //    if (($secexists) && (!$config['secretUser'])) {
    //        if (isset($res[$i]['CaseType'])) {
    //            if (in_array($res[$i]['CaseType'],array('AD','AJ','TE','TP','TB','CJ','VC','DP'))) {
    //                $res[$i]['CaseStyle'] = '-- restricted case --';
    //            }
    //        }
    //    }
    //    
    //    $i++;
    //}
}


#
# browse returns a sortable, clickable list of records
#
function browse($rpath, &$data, $ageRange = null) {
    global $order,$HTTP_GET_VARS,$QUERY_STRING,$viewer,$fldarr,$res,$fldnames,$county,$ROOTPATH,$VIEWPATH,$lev,$datnav;
    global $begrow,$endrow;	# for pagination
    global $secuserid,$secuser;
    
    $data['config'] = array();
    $data['reportData'] = array();
    
    loaddata($rpath, $data, $ageRange);
	
    return;
}


#
# MAIN PROGRAM
#

extract($_REQUEST);

$config = simplexml_load_file($icmsXml);
// Set a default value, in case there is no reportPath element defined
$reportPath = isset($config->{'reportPath'}) ? (string) $config->{'reportPath'} : "/var/www/Palm";
$type = getReqVal('type');
$divName = getReqVal('divName');

if (!isset($rpath)) {
	$rpath = '';
}

if(!isset($pagenum)){
	$pagenum = 1;
}

if(!isset($pagesize)){
	$pagesize = 100;
}

//Previous reports contain yearmonth inside of rpath...
//if (preg_match('/\b\d{4}-\d{2}\b/', $rpath, $matches)) {
//	$yearmonth = $matches[0];
//}

$slashCount = substr_count($rpath, "/");
while($slashCount >= 4){
	$removeThis = end(explode("/", $rpath));
	$rpath = str_replace($removeThis, "", $rpath);
	$rpath = trim($rpath, "/");
	$slashCount = substr_count($rpath, "/");
}	

$rptPath = sprintf("%s/%s/%s.json", $rpath, $yearmonth, $rpttype);

createTab("Division " . $divname . " Case Report", 
	"/reports/div_list.php?type=$type&divname=$divname&rpttype=$rpttype&yearmonth=$yearmonth", 1, 1, "cases");

$reportFile = sprintf("%s/%s/div%s/%s", $reportPath, $type, $divname, $rptPath);
	
$data = array();
	
if (isset($ageRange) && ($ageRange >= 0)) {
    browse("$reportFile", $data, $ageRange);
} else {
    browse("$reportFile", $data);
}

$data['divname'] = $divname;
$data['yearmonth'] = $yearmonth;
$data['rpttype'] = $rpttype;
$data['rpath'] = $rptPath;
$data['courttype'] = $type;

if (isset($lop)) {
    $smarty->assign('lop', 1);
}

if($pagesize == "All"){
	$pagesize = count($data['reportData']);
}

if($pagenum == 0){
	$begrow = 1;
}
else{
	$begrow = (($pagenum) * $pagesize) + 1;
}

if($pagenum == 0){
	$endrow = $pagesize;
} else {
	$endrow = (($pagenum) * $pagesize) + $pagesize;
	
	if($endrow > count($data['reportData'])){
		$endrow = count($data['reportData']);
	}
}

//The plus was causing a space at the end...
$data['rpttype'] = trim($data['rpttype']);

$smarty->assign('courttype', $type);
$smarty->assign('data', $data);
$smarty->assign('wfCount', $wfcount);
$smarty->assign('active', "cases");
$smarty->assign('tabs', $_SESSION['tabs']);
$smarty->assign('pagesize', $pagesize);
$smarty->assign('pagenum', $pagenum);
$smarty->assign('pagerOptions', array('5', '10', '25', '50', '100', '250', '500', '1000', '2500', '5000', '10000', 'All'));
$smarty->assign('lastpage', ceil(count($data['reportData']) / $pagesize));
$smarty->assign('rowCount', count($data['reportData']));
$smarty->assign('showpage', $pagenum);
$smarty->assign('next', $pagenum + 1);
$smarty->assign('prev', $pagenum - 1);
$smarty->assign('begrow', $begrow);
$smarty->assign('endrow', $endrow);
$smarty->assign('rpath', "/" . $rpath . "/index.txt");
$smarty->assign('divname', $divname);
$smarty->assign('rpttype', $rpttype);
$smarty->assign('yearmonth', $yearmonth);

$html = utf8_encode($smarty->fetch('reports/div_list.tpl'));

$result = array();

if(!$ajax){
	$smarty->display('top/header.tpl');
	
	echo $html;
} else {
	$headerCount = 12;
	$dataArray = array();
	$rowCount = 0;

	$dataArray['headers'] = array();
	$headers = array();
	$headerInfo = array();
	foreach($data['config']['fields'] as $key => $f){
		$headers[] = $f['colname'];
		$headerInfo[$key] = $f;
	}
	$dataArray['headers'] = $headers;
	$dataArray['headerInfo'] = $headerInfo;
	
	$allDataRows = $data['reportData'];
	$dataRows = array();
	$totalRowCount = 0;
	$actualRowCount = 1;
	
	$allDataRows = array_values($allDataRows);
	
	if(!empty($_REQUEST['column'])){
		foreach($_REQUEST['column'] as $key => $c){
			$field = $headers[$key];
			if($c == 0){
				usort($allDataRows, sortAsc($field));
			} else {
				usort($allDataRows, sortDesc($field));
			}
		}
	}
	
	//Check headers first....
	foreach($allDataRows as $key => $rd){
		foreach($headers as $hd){
			if(!isset($rd[$hd])){
				$allDataRows[$key][$hd] = "";
			}
		}
	}
	
	foreach($allDataRows as $key => $rd){
		
		//If a filter was set
		if(!empty($_REQUEST['filter'])){
			//Let's walk through all the filters
			foreach($_REQUEST['filter'] as $key2 => $rf){
				$field = $headers[$key2];
				//Special handling for case age
				if($field == 'CaseAge'){
					if($rf == "0-120 days"){
						if($rd[$field] <= 120){
							if($actualRowCount >= $begrow && ($actualRowCount < ($endrow + 1))){
								if(!existsInArray($dataRows, 'CaseNumber', $rd['CaseNumber'])){
									$dataRows[] = $rd;
									$actualRowCount++;
								}
							}
							else{
								$actualRowCount++;
							}
							
							$totalRowCount++;
						}
					} else if($rf == "121-180 days") {
						if($rd[$field] > 120 && ($rd[$field] <= 180)){
							if($actualRowCount >= $begrow && ($actualRowCount < ($endrow + 1))){
								if(!existsInArray($dataRows, 'CaseNumber', $rd['CaseNumber'])){
									$dataRows[] = $rd;
									$actualRowCount++;
								}
							}
							else{
								$actualRowCount++;
							}
							
							$totalRowCount++;
						}
					} else if($rf == "180+ days") {
						if($rd[$field] > 180){
							if($actualRowCount >= $begrow && ($actualRowCount < ($endrow + 1))){
								if(!existsInArray($dataRows, 'CaseNumber', $rd['CaseNumber'])){
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
				//Otherwise do the normal stuff
				else if(stripos($rd[$field], $rf) !== false) {
					if($actualRowCount >= $begrow && ($actualRowCount < ($endrow + 1))){
						if(!existsInArray($dataRows, 'CaseNumber', $rd['CaseNumber'])){
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
				if(!existsInArray($dataRows, 'CaseNumber', $rd['CaseNumber'])){
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
				if($field == 'CaseAge'){
					if($f == "0-120 days"){
						if($d[$field] > 120){
							unset($dataRows[$key2]);
							$actualRowCount--;
						}
					}
					else if($f == "121-180 days days"){
						if($d[$field] < 121 || ($d[$field] < 180)){
							unset($dataRows[$key2]);
							$actualRowCount--;
						}
					}
					else if($f == "180+ days"){
						if($d[$field] < 180){
							unset($dataRows[$key2]);
							$actualRowCount--;
						}
					}
				}
				else if(stripos($d[$field], $f) === false){
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
		$dataArray['total_rows'] = count($data['reportData']);
	} else{
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
		if(is_numeric($a[$key]) && is_numeric($b[$key])){
			return $a[$key] - $b[$key];
		}
		else if(stripos($key, "date") !== false){
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
		if(is_numeric($a[$key]) && is_numeric($b[$key])){
			return $b[$key] - $a[$key];
		} else if(stripos($key, "date") !== false) {
			$d1 = date("Y-m-d", strtotime($a[$key]));
			$d2 = date("Y-m-d", strtotime($b[$key]));
			return strcmp($d2, $d1);
		} else {
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