<?php

require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/common.php");
require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/db_functions.php");
require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/col_maps.php");
require_once($_SERVER['JVS_DOCROOT'] . "/workflow/wfcommon.php");

checkLoggedIn();

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);

$months=array(1=>"January",2=>"February",3=>"March",4=>"April",5=>"May",6=>"June",7=>"July",8=>"August",9=>"September",10=>"October",11=>"November",12=>"December");

$config = simplexml_load_file($icmsXml);

// Set a default value, in case there is no reportPath element defined
$reportPath = isset($config->{'reportPath'}) ? (string) $config->{'reportPath'} : "/var/www/Palm";

#
# show is the main function of the report
#
function show($division) {
    global $reportPath,$months,$templateDir,$compileDir,$cacheDir,$type;
    
    $smarty = new Smarty;
    $smarty->setTemplateDir($templateDir);
    $smarty->setCompileDir($compileDir);
    $smarty->setCacheDir($cacheDir);
    
    $thisMonth = date('Y-m');
    
    $path = sprintf("%s/%s/div%s", $reportPath, $type, $division);
    
    $files = array_diff(scandir($path), array('.', '..', $thisMonth));
    
    rsort($files);
        
    $list = array();
    
    foreach ($files as $file) {
        if (is_dir("$path/$file")) {
            $temp = array('yearmonth' => $file);
            list($year, $month) = explode("-", $file);
            $month = intval($month); 
            $temp['words'] = sprintf("%s, %s", $months[$month], $year);
            array_push($list, $temp);
        }
    }
    
    $smarty->assign('archives',$list);
    $smarty->assign('divname', $division);
    $smarty->assign('type', $type);
    
    $output = $smarty->fetch("reports/archive.tpl");
    
    return $output;
}

// $rpath is relative to the top-level of the reports directory
$divName = getReqVal('div');
$type = getReqVal('type');

$tabStr = sprintf("%s?div=%s&type=%s", $_SERVER['SCRIPT_NAME'], $divName, $type);

createTab("Previous Reports for Division $divName", $tabStr, 1, 1, "cases");

$user = getSessVal('user');
$fdbh = dbConnect("icms");

$myqueues = array($user);
$sharedqueues = array();

getSubscribedQueues($user, $fdbh, $myqueues);
getSharedQueues($user, $fdbh, $sharedqueues);
$allqueues = array_merge($myqueues, $sharedqueues);

$queueItems = array();

$wfcount = getQueues($queueItems, $allqueues, $fdbh);


$output = show($divName);

$smarty->assign('wfCount', $wfcount);
$smarty->assign('active', "cases");
$smarty->assign('tabs', getSessVal('tabs'));

$smarty->display('top/header.tpl');

echo $output;

?>