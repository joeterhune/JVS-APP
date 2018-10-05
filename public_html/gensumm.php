<?php

require_once("./icmslib.php");
require_once('Smarty/Smarty.class.php');
require_once("workflow/wfcommon.php");
require_once("php-lib/common.php");
require_once("php-lib/db_functions.php");
//include 'icms.php';

checkLoggedIn();

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);

$user = $_SESSION['user'];
$fdbh = dbConnect("icms");

$myqueues = array($user);
$sharedqueues = array();

getSubscribedQueues($user, $fdbh, $myqueues);
getSharedQueues($user, $fdbh, $sharedqueues);
$allqueues = array_merge($myqueues, $sharedqueues);

$queueItems = array();

$wfcount = getQueues($queueItems, $allqueues, $fdbh);

# gensumm.php - creates a summary page from text files
#

function hasCalendar($div,$title2, &$divDesc) {
	$dbh = dbConnect("judge-divs");

	$query = "
		select
			division_type,
			IFNULL(has_ols,0) as has_ols
		from
			divisions
		where
			division_id = :div
	";
	
    $calDivs = getDataOne($query, $dbh, array('div' => $div));
	
	if (!array_key_exists('division_type', $calDivs)) {
		return 0;
	};

    $divDesc = $calDivs['division_type'];
    
	// Is this an OLS division OR is it a division where the clerk schedules events?
	if (($calDivs['has_ols']) ||
		(preg_match('/Felony|Misdemeanor|VA|Mental Health|Juvenile/', $calDivs['division_type']))) {
		return 1;
	}

	return 0;
}

function getval($varname,$infile) {
	$x=fgets($infile,5120);
	list($vx,$val)=explode("=",$x);
	$vx=rtrim($vx);
	$val=rtrim($val);

	if ($vx!=$varname) {
		print "gensumm.php: Error: variable $varname not encountered--(saw $vx instead)!\n";
		return("");
	}
	return($val);
}


function prettydate($date) {
	list($month,$day,$year)=explode('/',$date);
	return "As of ".date('l, F jS, Y',mktime(0,0,0,$month,$day,$year));
}


function loaddata($rpath, $smarty) {
	global $rptdate,$title1,$title2,$res,$path,$multvalues,$htlp;
    
    //$dpath = "$rpath/index.txt";
    $dpath = $rpath;
    
    if (!file_exists("/var/www/html/$dpath")) {
		return;
	}
	$infile=fopen("/var/www/html/$dpath","r");
	if (!$infile) {
		echo "Couldn't open /var/www/html/$dpath";
		return;
	}

	$file_str = fread($infile,5120);
    // echo $file_str;
    $flag=0;
    if(strstr($file_str,"MULTVALUES")) {
		$flag = 1;
    }
    // echo $flag;
    fclose($infile);

	$infile=fopen("/var/www/html/$dpath","r");
	if (!$infile) {
		echo "Couldn't open /var/www/html/$dpath";
		return;
	}

	$rptdate=getval("DATE",$infile);
	
	$yearMonth = date("Y-m", strtotime($rptdate));
	if (empty($yearMonth)) {
		$yearMonth = date('Y-m');
	}
	$smarty->assign('yearMonth', $yearMonth);
	
	$rptdate=prettydate($rptdate);
    
    $smarty->assign('prettyDate', $rptdate);
    
	$title1=getval("TITLE1",$infile);
	$title2=getval("TITLE2",$infile);
	$path=getval("PATH",$infile);
	$htlp=getval("HELP",$infile);
	//echo $htlp;
	if($flag) {
		$multvalues=getval("MULTVALUES",$infile);
	}
	$i=0;
	while ($line=fgets($infile,5120)) {
		$line=substr($line,0,-1);
		$res[$i++]=explode("~",$line);
	}
	fclose($infile);
    
    $smarty->assign('title1', $title1);
    $smarty->assign('title2', $title2);
}


#
# show is the main function of the report
#
function show($rpath,$older,$div,$smarty) {
	global $res,$path,$multvalues,$title2,$htlp;
    
    loaddata($rpath, $smarty);
    
	$smarty->assign('title2', $title2);
    
    $caseTypes = array();
    
    if($multvalues != NULL) {
		$fields = array();
		$fields = explode(',',$multvalues);
		for($i=0;$i<count($fields);$i++) {
			//echo "<td id=rptname bgcolor=#D0FFD0><div class=h2>$fields[$i]</div>";
		}

		//print "</tr>";
		for ($i=0;$i<count($res);$i++) {
			list($heading,$count_0,$count_1,$level,$xpath)=$res[$i];
			if ($heading=="BLANK") {
				//print "<tr><td id=label1 colspan=2>&nbsp";
			} else {
				if ($level==1) {
					$tot=$count_0;
				} else {
					if ($tot>0) {
						$pct=sprintf("%5.2f%%",$count_0/$tot*100);
					} else {
						$pct="";
					}
				}
			}
		}
	} else if($multvalues == NULL){
		for ($i=0;$i<count($res);$i++) {
            $thisType = array();
			if ($res[$i][0] == "BLANK") {
                $thisType['blank'] = 1;
				//print "<tr>\n<td id=label1 colspan=2>\n&nbsp;\n</td>\n</tr>\n";
			} else {
				list($heading,$count,$level,$xpath)=$res[$i];
                $thisType['path'] = $path;
                $thisType['xpath'] = $xpath;
                $thisType['desc'] = $heading;
                $thisType['count'] = $count;
                
                if ($level==1) {
					$tot=$count;
					//echo "<a href=\"genlist.php?rpath=$path$xpath.txt&order=5\" />\n$heading\n</a>\n</td>\n";
					//echo "<td id=data$level>\n$count\n</td>\n</tr>\n";
				} else {
					if ($tot>0) {
						$pct=sprintf("%5.2f%%",$count/$tot*100);
					} else {
						$pct="";
					}
					//echo "<tr>\n<td id=label$level>\n";
					//echo "<a href=\"genlist.php?rpath=$path$xpath.txt&order=5\" />\n$heading\n</a>\n</td>\n";
					//echo "<td id=data$level>\n$count\n</td>\n<td id=data2>\n&nbsp;&nbsp;\n$pct\n</td>\n</tr>\n";
				}
			}
            array_push($caseTypes, $thisType);
		}
		//echo "</table><td>";
	}
    $divDesc = "";
	if (hasCalendar($div,$title2,$divDesc)) {
        $smarty->assign('hasCalendar', 1);
	}
    
    $smarty->assign('divDesc', $divDesc);
    $smarty->assign('caseTypes', $caseTypes);
    
    return $smarty->fetch("reports/genSumm.tpl");
}




// Main body

$rpath = getReqVal('rpath');
$divName = getReqVal('divName');

//P in Palm was causing issues with division P....
if($divName != "P"){
	$archPath = substr($rpath, 0, strpos($rpath, $divName)) . $divName;
}
else{
	$archPath = substr($rpath, 0, strpos($rpath, "/index.txt"));
}

$yearMonth = getReqVal('yearmonth');

if(!empty($yearMonth)){
	$rpath = $archPath . "/" . $yearMonth . "/index.txt";
}

createTab("Division " . $divName, "/case/gensumm.php?rpath=" . $rpath . "&divName=" . $divName, 1, 1, "cases");

if (isset($_REQUEST['divxy'])) {
    list($div,$type) = explode("~",$_POST['divxy']);
    $rpath = "case/Palm/$type/div$div/index.txt";
} else if (isset($_REQUEST['flagxy'])) {
    list($num,$type) = explode("~", $_POST['flagxy']);
    $rpath = "case/Palm/flags/$num/index.txt";
    $older="no";
}

$older = getReqVal('older');

$smarty->assign('divName', $divName);
$smarty->assign('rpath',$rpath);
$smarty->assign('archPath', $archPath);
$smarty->assign('wfCount', $wfcount);
$smarty->assign('active', "cases");
$smarty->assign('tabs', $_SESSION['tabs']);

$output = show($rpath,$older,$divName,$smarty);

$result = array();

$smarty->display('top/header.tpl');

echo $output;
