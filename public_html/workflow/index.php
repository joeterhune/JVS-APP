<?php
# wfshow.php - show all work queues for a user
require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/common.php");
require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/db_functions.php");
require_once("wfcommon.php");
require_once $_SERVER['JVS_DOCROOT'] . "/icmslib.php";

require_once('Smarty/Smarty.class.php');

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);

$smarty->assign('role',$ROLE);

$user = strtolower($_SERVER['REMOTE_USER']);

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
        $item['comments'] = preg_replace("/[^A-Za-z0-9 ^<>:$!#-+.\.\*]/", '', nl2br($item['comments']));
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
$smarty->assign('queuejson', json_encode($qres));

$smarty->assign('wfCount', $wfcount);
$smarty->display('top/header.tpl');
$smarty->display('workflow/index.tpl');
$smarty->display('top/footer.tpl');