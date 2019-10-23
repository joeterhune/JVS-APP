<?php
# wfshow.php - show all work queues for a user
require_once("php-lib/common.php");
require_once("php-lib/db_functions.php");
require_once("./icmslib.php");
require_once('Smarty/Smarty.class.php');
require_once("workflow/wfcommon.php");

checkLoggedIn();

require_once('Smarty/Smarty.class.php');

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);

if(isset($_REQUEST['queueName'])){
	$queueName = $_REQUEST['queueName'];
	
}
else{
	$queueName = "myqueue";
}

$dbh = dbConnect("icms");
$smarty->assign('role',$ROLE);

$user = strtolower($_SESSION['user']);

#
# create a javascript EFILING_CODE array for upload document commands...
#
$icms=dbConnect("icms");
$query = "
    select
        *
    from
        efiling_docket_codes
";
$list = array();
getData($list, $query, $dbh);

$smarty->assign('efiling_code',json_encode($list));

#
# and a JavaScript WORKQUEUES array for things like the workflow upload function
#
$jdbh = dbConnect("judge-divs");
$divnames=array();
getDivList($jdbh,$divnames);
getCustomQueues($jdbh,$divnames);
$divisions = array();
getJudgeDivs($judges,$divisions,$jdbh);

$xferqueues = array();
getUserQueues($xferqueues, $dbh);

$sdivs = $divisions;
ksort($sdivs);

foreach ($sdivs as $sdiv => $vals) {
	$queue = array("queue" => $sdiv);
	$queue['queuedscr'] = sprintf ("%s (%s)", $sdiv, $vals['courtType']);
	array_push($xferqueues, $queue);
}

$real_xferqueues = array();
getTransferQueues($user, $dbh, $real_xferqueues);

$smarty->assign('xferqueues', $xferqueues);
$smarty->assign('real_xferqueues', $real_xferqueues);
$smarty->assign('divs',$divnames);

#
# find out what workqueues this person is subscribed to...
#

$myqueues = array($user);
getSubscribedQueues($user, $dbh, $myqueues);
$smarty->assign('queues',$myqueues);

$sharedqueues = array();
getSharedQueues($user, $dbh, $sharedqueues);

$smarty->assign('sharedqueues', $sharedqueues);

$allqueues = array_merge($myqueues,$sharedqueues);

$smarty->assign('allqueues',$allqueues);

$queueItems = array();

$wfcount = getQueues($queueItems,$allqueues,$dbh);

$today = date("Y-m-d");
$nextweek = strtotime('+6 days');
$todaytime = strtotime($today);

function escapeJavaScriptText($string)
{
    return str_replace("\n", '\n', str_replace('"', '\"', addcslashes(str_replace("\r", '', (string)$string), "\0..\37'\\")));
}
 
foreach (array_keys($queueItems) as $queue) {
    foreach ($queueItems[$queue] as &$item) {
        $item['due_time'] = strtotime($item['due_date']);
        $item['comments'] = nl2br(htmlspecialchars($item['comments']));
		$item['title'] = escapeJavaScriptText($item['title']);
        $item['classes'] = array();
        if ($item['due_time'] < $todaytime) {
            array_push($item['classes'], "overdue");
        } elseif ($nextweek > $item['due_time']) {
            array_push($item['classes'], "duesoon");
        }
        
        get_esig_status($item);
        
        if ($item['doc_type'] == "IGO" || ($item['doc_type'] == "DVI")) {
            $item['sigAction'] = 'WorkFlowSignFormOrder';
            $item['btntype'] = "wfmenubut2";
        } elseif(in_array($item['doc_type'], array('PropOrd','Warrant','EmerMot'))) {
            $item['sigAction'] = 'SignOrder';
            $item['btntype'] = "wfmenubut";
        } elseif (in_array($item['doc_type'], array('MiscDoc','Task'))) {
            $item['btntype'] = "wfmenubut3";
        }
    }
}

function smarty_function_getSuppDocs($params, $smarty){
	global $dbh;
	$suppDocs = array();
	$docs = getSuppDocsForQueueItem($params['doc_id'], $dbh);
	foreach($docs as $d){
		$suppDocs[] = $d;
	}
	$smarty->assign($params['assign'], $suppDocs);
}

$smarty->registerPlugin('function', 'getSuppDocs', 'smarty_function_getSuppDocs');
$xml = simplexml_load_file($_SERVER['JVS_ROOT'] . "/conf/ICMS.xml");
$smarty->assign('olsURL', $xml->olsURL);
$smarty->assign('queueItems', $queueItems);

$esigs = array();
$sigCount = getEsigs($esigs,$user);
foreach ($esigs as &$esig) {
    $esig['fullname'] = buildName($esig);
}
$smarty->assign('esigs',$esigs);
$smarty->assign('cansign',$sigCount);

$users = array();
$temp = array();
getUserList($temp, $dbh);
foreach ($temp as $t) {
    $users[$t['userid']] = $t;
}

$smarty->assign('users',$users);
$smarty->assign('user',$user);

$queuelist="('".join("','",$allqueues)."')";
$query = "
    select
        *
    from
        workflow
    where
        queue in $queuelist
        and not finished
";

$qres = array();
getData($qres, $query, $dbh);

if(!empty($qres)){
	foreach($qres as $key => $q){
		unset($qres[$key]['data']);
		unset($qres[$key]['signed_pdf']);
		unset($qres[$key]['signature_img']);
	}
}

$smarty->assign('queuejson', json_encode($qres));

$smarty->assign('tabs', $_SESSION['tabs']);
$smarty->assign('wf-cookie', $_COOKIE['wf-cookie']);
$smarty->assign('queueName', $queueName);
$smarty->assign('wfCount', $wfcount);
$smarty->assign('active', "workflow");
$smarty->display('top/header.tpl');
$smarty->display('workflow/index.tpl');