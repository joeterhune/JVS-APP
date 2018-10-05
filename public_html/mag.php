<?php

require_once("php-lib/common.php");
require_once("php-lib/db_functions.php");
require_once("./icmslib.php");
require_once("Smarty/Smarty.class.php");
require_once("workflow/wfcommon.php");

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

# 11/04/09 lms fixed code that counts the number of pending, repopended and other cases.
#              was reading lines 6, 9, and 12, which used to be the same in every index.txt file,
#              but that's no longer true.

$val = getReqVal('val');
$tab = getReqVal('tabname');

list($name,$divs)=explode("~",$val);

createTab("MAGISTRATE " . $name, "/case/mag.php?val=" . $val, 1, 1, "cases");

$smarty->assign('magName', $name);

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

$divs=substr($divs,0,-1);
$divarr=explode(";",$divs);

$divList = array();

foreach ($divarr as $adiv) {
	list($ydiv,$ydesc)=explode(",",$adiv);
	$divInfo = array();
	# line 6 of the index.txt file, 1st param name, 2nd param count
	$civpath= "/var/www/html/case/Palm/civ/div$ydiv/index.txt";
	$crimpath="/var/www/html/case/Palm/crim/div$ydiv/index.txt";
	$juvpath="/var/www/html/case/Palm/juv/div$ydiv/index.txt";
	$propath="/var/www/html/case/Palm/pro/div$ydiv/index.txt";
	if (file_exists($civpath) && ($ydesc == "Civil") || ($ydesc == "Family") || ($ydesc == "DOR")) {
		$path=$civpath;
		$divInfo['divType'] = "civ";
	} else if  (file_exists($crimpath) && ($ydesc == "Criminal")) {
		$path=$crimpath;
		$divInfo['divType'] = "crim";
	} else if  (file_exists($juvpath) && ($ydesc == "Juvenile"))  {
		$path=$juvpath;
		$divInfo['divType'] = "juv";
	} else if  (file_exists($propath) && ($ydesc == "Probate"))  {
		$path=$propath;
		$divInfo['divType'] = "pro";
	} else {
		$path="";
		$divInfo['divType'] = "";
	}

	if ($path!="") {
		$spath=str_replace("/var/www/html/","",$path);
		$fp=fopen($path,"r");
		$total_num = 0;
        
    	while( $line = fgets($fp)) {
			//$line=fgets($fp,1024);
			if (!preg_match('/~/', $line)) {
				continue;
			}
			list($foo,$num)=explode("~",$line);
			if (substr($foo,0,7)=="Pending" || substr($foo,0,8)=="Reopened" ||
					substr($foo,0,5)=="Other" || (substr($foo,0,6)=="Closed")) {
				$total_num = $total_num + $num;
			}
		}

		fclose($fp);
        
        
        $divInfo['path'] = $spath;
        $divInfo['divName'] = $ydiv;
        $divInfo['divDesc'] = $ydesc;
        $divInfo['total_num'] = $total_num;
        
        array_push($divList, $divInfo);
	}
}

$smarty->assign('divList', $divList);

$html = $smarty->fetch('reports/magReport.tpl');
$smarty->assign('wfCount', $wfcount);
$smarty->assign('active', "cases");
$smarty->assign('tabs', $_SESSION['tabs']);
$smarty->display('top/header.tpl');
echo $html;
