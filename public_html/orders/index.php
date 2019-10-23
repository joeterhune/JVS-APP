<?php
# /orders/index.php - filles in and posts web form data, then generates a PDF 
#                  from JSON data and then allows various options from there...

require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/common.php");
require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/db_functions.php");
require_once($_SERVER['JVS_DOCROOT'] . "/workflow/wfcommon.php");
require_once($_SERVER['JVS_DOCROOT'] . "/caseinfo.php");
require_once($_SERVER['JVS_DOCROOT'] . "/icmslib.php");

require_once('Smarty/Smarty.class.php');

checkLoggedIn();

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);

#
#  MAIN PROGRAM 
#
$ucn = getReqVal('ucn');
$docid = getReqVal('docid');
$case_id = getReqVal('caseid');
extract($_REQUEST, EXTR_SKIP);

if (isset($filingId)) {
    $smarty->assign('filingId',$filingId);
}

if (($ucn == "") && ($docid == "")) {
    $smarty->assign('noUCN',1);
}

if (($ucn == "") && ($docid != "")) {
    $query = "
        select
            ucn
        from
            workflow
        where
            doc_id = :docid
    ";
    $doc = getDataOne($query, $dbh, array('docid' => $docid));
    $ucn = $doc['ucn'];
}

$oucn = $ucn;

list($ucn, $casetype) = sanitizeCaseNumber($oucn);

if ($casetype == "showcase") {
    if (!preg_match("/^58/", $ucn)) {
        $ucn = sprintf("58-%s",$ucn);
        $smarty->assign('ucn', $ucn);
    }
} elseif ($casetype == "banner") {
    $ucn = $oucn;
}

$smarty->assign('ucn', $ucn);

$div = getCaseDiv($ucn, $casetype);

$dbh = dbConnect("icms");

$user = $_SESSION['user'];

$orderObj = array (
    'userid' => $user,
    'docid' => $docid,
    'ucn' => $ucn,
    'casetype' => $casetype,
    'divisionid' => $div,
    'dbh' => $dbh
);

getObjInfo($orderObj);

$myqueues = array($user);
$sharedqueues = array();

getSubscribedQueues($user, $dbh, $myqueues);
getSharedQueues($user, $dbh, $sharedqueues);
$allqueues = array_merge($myqueues, $sharedqueues);

$queueItems = array();

$wfcount = getQueues($queueItems, $allqueues, $dbh);

if(isset($docid) && !empty($docid)){
	$url = "/orders/index.php?ucn=" . $ucn . "&docid=" . $docid;
}
else{
	$url = "/orders/index.php?ucn=" . $ucn . "&caseid=" . $case_id;
}

createTab($ucn, $url, 1, 1, "cases",
	array(
		"name" => "Order Creation",
		"active" => 1,
		"close" => 1,
		"href" => $url,
		"parent" => $ucn
	)
);

if ((!array_key_exists('DocType', $orderObj)) || ($orderObj['DocType'] == 'IGO' || ($orderObj['DocType'] == 'DVI'))) {
    $template = "orders/index.tpl";
    $smarty->assign('isOrder', 1);
} else {
    $template = "orders/index-propord.tpl";
    $smarty->assign('isOrder', 0);
}

$smarty->assign('doc_type', $orderObj['DocType']);

$fromAddr = sprintf("CAD-Division%s@pbcgov.org", $div);

// Is it an existing document?
if ($orderObj['docid'] != '') {
    $smarty->assign('fromwf',1);
    // Is the order signed?
    if ($orderObj['esigned'] == 'Y') {
        // Yes! Build the signature div
        $query = "
            select
                signer_id,
                signature_img,
                signer_name,
                signer_title,
                signed_filename 
            from
                workflow
            where
                doc_id = :docid
        ";
        $siginfo = getDataOne($query, $dbh, array('docid' => $docid));
        
        $outfile=tempnam("/var/www/html/tmp", "sig");
        $outfile .= ".jpg";
        file_put_contents($outfile, base64_decode($siginfo['signature_img']));
        $sigimgfile = sprintf("/tmp/%s", basename($outfile));
        $signame = $siginfo['signer_name'];
        $sigtitle = $siginfo['signer_title'];
        $sigdiv = sprintf('<div style="position: relative; left: 300px"><img src="%s"><br/>%s<br/>%s</div>', $sigimgfile, $signame, $sigtitle);
        $smarty->assign('isSigned',1);
        $smarty->assign('pdf',$siginfo['signed_filename']);
        $smarty->assign('didgen',1);
    } else {
        $sigdiv = "";
        $smarty->assign('isSigned',0);
        $smarty->assign('pdf','');
        $smarty->assign('didgen',1);
    }
} else {
    $sigdiv = "";
    $smarty->assign('isSigned',0);
    $smarty->assign('pdf','');
    $smarty->assign('didgen',0);
    $smarty->assign('fromwf',0);
}

$smarty->assign('data', $orderObj);

$users = array();
getUserList($users, $dbh);
$smarty->assign('users', $users);

$real_xferqueues = array();
getTransferQueues($user, $dbh, $real_xferqueues);
$smarty->assign('real_xferqueues', $real_xferqueues);

$divlist = array();
$jdbh = dbConnect("judge-divs");

getDivList($jdbh, $divlist);

$smarty->assign('divlist',$divlist);

$smarty->assign('docid', $docid);
$smarty->assign('allsigned',0);
$smarty->assign('user',strtolower($user));
$smarty->assign('sigdiv',$sigdiv);
$smarty->assign('fromAddr', $fromAddr);

$esigs = array();
$sigCount = getEsigs($esigs,$user);
foreach ($esigs as &$esig) {
    $esig['fullname'] = buildName($esig);
}
$smarty->assign('esigs',$esigs);
$smarty->assign('cansign',$sigCount);

$result = array();

if (!isset($tab)) {
    // Must have come in from the queue management page
    $result['parentTab'] = sprintf("case-%s", $ucn);
    $tab = sprintf("case-%stabs", $ucn);
    $show = 1;
} 

$smarty->assign('wfCount', $wfcount);

$smarty->assign('active', "cases");
$smarty->assign('tabs', $_SESSION['tabs']);
$smarty->display('top/header.tpl');
echo $smarty->fetch($template);

