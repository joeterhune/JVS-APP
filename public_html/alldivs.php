<?php
require_once("php-lib/common.php");
require_once("php-lib/db_functions.php");
require_once("./icmslib.php");
require_once('Smarty/Smarty.class.php');
require_once("workflow/wfcommon.php");

$config = simplexml_load_file($_SERVER['JVS_ROOT'] . ".conf/ICMS.xml");

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

$listType = $_REQUEST['type'];
$data = array();
$typelist = array();

if ($listType == 'crim') {
    $data['type'] = 'Criminal';
    $typelist = array('Circuit Criminal', 'Mental Health Court','County Criminal');
} else if ($listType == 'civ') {
    $data['type'] = 'Civil';
    $typelist = array('Circuit Civil','Foreclosure','County Civil');
}  else if ($listType == 'fam') {
    $listType = 'civ';
    $data['type'] = 'Family';
    $typelist = array('Family','Unified Family Court');
} else if ($listType == 'juv') {
    $data['type'] = 'Juvenile';
    $typelist = array('Juvenile');
} else if ($listType == 'pro') {
    $data['type'] = 'Probate';
    $typelist = array('Probate');
}

$data['pathpart'] = $listType;

$dbh = dbConnect("judge-divs");

$query = " select
        division_id as DivisionID,
        CASE division_type
            WHEN 'Misdemeanor' THEN 'County Criminal'
            WHEN 'VA' then 'County Criminal'
            WHEN 'Felony' THEN 'Circuit Criminal'
            WHEN 'Mental Health' THEN 'Mental Health Court'
            WHEN 'UFC Linked Cases' THEN 'Unified Family Court'
            WHEN 'UFC Transferred Cases' THEN 'Unified Family Court'
            WHEN 'UFC Judicial Memo' THEN 'Unified Family Court'
        ELSE division_type
        END as CourtType
    from
        divisions
    where
        division_id not in ('CFTD')
        and show_icms_list = 1";

$divisions = array();
getData($divisions, $query, $dbh);
$temp = array();

foreach($typelist as $t){
	$temp['type'] = $t;
	$divArray = array();
	
	foreach($divisions as $d){
		if($d['CourtType'] == $t){
			$divArray[] = $d;
		}
	}
	$temp['divs'] = $divArray;
	$data['divlist'][] = $temp;
}

$smarty->assign('wfCount', $wfcount);
$smarty->assign('data', $data);
$smarty->assign('active', "cases");
$smarty->display('top/header.tpl');
$smarty->display('allDivs.tpl');