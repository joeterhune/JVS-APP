<?php

require_once("php-lib/common.php");
require_once("php-lib/db_functions.php");
require_once("php-lib/col_maps.php");
require_once("workflow/wfcommon.php");

checkLoggedIn();

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);

# genarchive.php - creates a archive page from a directory
#
# derived from genlist.php
# 5/6/05

$months=array(1=>"January",2=>"February",3=>"March",4=>"April",5=>"May",6=>"June",7=>"July",8=>"August",9=>"September",10=>"October",11=>"November",12=>"December");

#
# show is the main function of the report
#
function show($rpath, $division) {
    
    global $res,$path,$months;
    $dh=opendir("/var/www/html/$rpath/");
    
    while (($file=readdir($dh))!=false) {
        if (substr($file,0,1)=="2") {
            $list[]=$file;
	   
        }
    }
    
    rsort($list);
    foreach ($list as $file) {
        list($year,$month)=explode('-',$file);
        $month=$month+0;
        $monthNo = str_pad($month, 2, "0", STR_PAD_LEFT);
        $ym = $year . "-" . $monthNo;
        if (file_exists("/var/www/html/$rpath/$file/index.txt")) {
            $output .= "<a href=\"/case/gensumm.php?rpath=$rpath/index.txt&divName=$division&yearmonth=$ym\">$months[$month], $year</a><br>";
        }
    }
    
    return $output;
}

createTab("Previous Reports for Division " . $_REQUEST['div'], "/case/genarchive.php?rpath=" . $_REQUEST["rpath"] . "&div=" . $_REQUEST['div'], 1, 1, "cases");

$user = $_SESSION['user'];
$fdbh = dbConnect("icms");

$myqueues = array($user);
$sharedqueues = array();

getSubscribedQueues($user, $fdbh, $myqueues);
getSharedQueues($user, $fdbh, $sharedqueues);
$allqueues = array_merge($myqueues, $sharedqueues);

$queueItems = array();

$wfcount = getQueues($queueItems, $allqueues, $fdbh);

$rpath = $_REQUEST["rpath"];
$output = show($rpath, $_REQUEST['div']);

$smarty->assign('wfCount', $wfcount);
$smarty->assign('active', "cases");
$smarty->assign('tabs', $_SESSION['tabs']);

$smarty->display('top/header.tpl');

echo $output;
