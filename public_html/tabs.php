<?php

require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/common.php");
require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/db_functions.php");
require_once($_SERVER['JVS_DOCROOT'] . "/icmslib.php");
require_once($_SERVER['JVS_DOCROOT'] . "/workflow/wfcommon.php");

require_once('Smarty/Smarty.class.php');

checkLoggedIn();

$config = simplexml_load_file($icmsXml);

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);

setActive("Main Form");

# Check to be sure the user is set up.  If he's gotten to this point, he's set up
# in AD to use ICMS; we just need to be sure things like the work queue and such are defined.

extract($_REQUEST);

if (isset($ucn)) {
    $smarty->assign('initialUCN',$ucn);
}

$user = $_SESSION['user'];

$jdbh = dbConnect('judge-divs');

$fdbh = dbConnect("icms");

$pdbh = dbConnect('portal_info');

// Is this person even a filer?
$query = "
	select
		user_id
	from
		portal_users
	where
		user_id = :user
	UNION
	select
		user_id
	from
		portal_alt_filers
	where
		user_id = :user
		and active = 1
";
$pfilers = array();
getData($pfilers, $query, $pdbh, array('user' => $user));

if (sizeof($pfilers)) {
	$query = "
		select
			count(*) as pendCount
		from
			portal_filings
		where
			user_id = :user
			and filing_status in ('Correction Queue')
			and portal_post_date is not null
			and status_ignore = 0
	";

	$pendCount = getDataOne($query, $pdbh, array('user' => $user));
} else {
	$pendCount['pendCount'] = 0;
}

# Get the list of party types
$query = "
    select
        PartyType,
        PartyTypeDescription,
        CASE
            WHEN DefendantType=1 THEN 'dftParty'
            WHEN AttorneyType=1 THEN 'attyParty'
            ELSE null
        END as PartyClass
    from
        party_types
    order by
        PartyTypeDescription
";
$partyTypes = array();
getData($partyTypes, $query, $fdbh);

$smarty->assign('partyTypes', $partyTypes);
$smarty->assign('vrbUrl', (string) $config->{'vrbUrl'});


$query = "
    select
        userid
    from
        users
    where
        userid = :user
";
$userRec = getDataOne($query, $fdbh, array('user' => $user));

if (!array_key_exists('userid', $userRec)) {
    createUser($user, $fdbh);
}

$myqueues = array($user);
$sharedqueues = array();

getSubscribedQueues($user, $fdbh, $myqueues);
getSharedQueues($user, $fdbh, $sharedqueues);
$allqueues = array_merge($myqueues, $sharedqueues);

$queueItems = array();

$wfcount = getQueues($queueItems, $allqueues, $fdbh);

$magistrates = array(
	"ALIJEWICZ, SARA" => "MSA",
	"FANELLI, JUDETTE" => "MJF"
);

$judges = array();
$divisions = array();

getJudgeDivs($judges,$divisions,$jdbh);

$smarty->assign('judges', $judges);
$smarty->assign('skipDivs',array("","AP"));
$smarty->assign('magistrates', $magistrates);

$crimDivs = array();
$civDivs = array();
$famDivs = array();
$juvDivs = array();
$proDivs = array();
foreach($divisions as $key => $d){
	if($d['courtType'] == "Misdemeanor" || ($d['courtType'] == "Felony")){
		$crimDivs[$key]['opt'] = $d['opt']; 
		$crimDivs[$key]['courtType'] = $d['courtType'];
		$crimDivs[$key]['has_ols'] = $d['has_ols'];
	}
	else if($d['courtType'] == "Circuit Civil" || ($d['courtType'] == "County Civil") || ($d['courtType'] == "Foreclosure")){
		$civDivs[$key]['opt'] = $d['opt']; 
		$civDivs[$key]['courtType'] = $d['courtType'];
		$civDivs[$key]['has_ols'] = $d['has_ols'];
	}
	else if($d['courtType'] == "Family"){
		$famDivs[$key]['opt'] = $d['opt'];
		$famDivs[$key]['courtType'] = $d['courtType'];
		$famDivs[$key]['has_ols'] = $d['has_ols'];
	}
	else if($d['courtType'] == "Juvenile"){
		$juvDivs[$key]['opt'] = $d['opt'];
		$juvDivs[$key]['courtType'] = $d['courtType'];
		$juvDivs[$key]['has_ols'] = $d['has_ols'];
	}
	else if($d['courtType'] == "Probate"){
		$proDivs[$key]['opt'] = $d['opt'];
		$proDivs[$key]['courtType'] = $d['courtType'];
		$proDivs[$key]['has_ols'] = $d['has_ols'];
	}
	
	if($key == "CHJD"){
		$divisions[$key]['opt'] = "CHJD~pro";
	}
}

$x=array_keys($divisions);
sort($x);

$x_crim=array_keys($crimDivs);
sort($x_crim);

$x_civ=array_keys($civDivs);
sort($x_civ);

$x_fam=array_keys($famDivs);
sort($x_fam);

$x_juv=array_keys($juvDivs);
sort($x_juv);

$x_pro=array_keys($proDivs);
sort($x_pro);

$smarty->assign('divlist', $x);
$smarty->assign('divisions',$divisions);
$smarty->assign('crim_divlist', $x_crim);
$smarty->assign('civ_divlist', $x_civ);
$smarty->assign('fam_divlist', $x_fam);
$smarty->assign('juv_divlist', $x_juv);
$smarty->assign('pro_divlist', $x_pro);

$ctDivs = array(
    'civil' => array('AA','AB','RE','RF'),
    'criminal' => array('E','L','R','S'),
    'family' => array('FX'),
    'juvenile' => array('JK','JL'),
    'probate' => array('IB')
);

$allDivs = array_merge($ctDivs['civil'], $ctDivs['criminal'], $ctDivs['family'], $ctDivs['juvenile'], $ctDivs['probate']);
sort($allDivs);

$smarty->assign('ctDivs',json_encode($ctDivs));
$smarty->assign('allDivs',json_encode($allDivs));
$smarty->assign('allDivsArray', $allDivs);

# Also build the listing of OLS divisions.  And Criminal.  And Juvenile.
$olsdiv = array();
$crimdivs = array();
$juvdivs = array();
$cocivdivs = array();
$circivdivs = array();
$famdivs = array();
$prodivs = array();
$expdivs = array();

foreach ($x as $adiv) {
	
	if ($divisions[$adiv]['has_ols']) {
        array_push($olsdiv,$adiv);
    }
	
	if ($divisions[$adiv]['courtType'] == 'Family') {
        $famdivs[$adiv] = $divisions[$adiv];
    }
    
    if ($divisions[$adiv]['courtType'] == 'Probate') {
        $prodivs[$adiv] = $divisions[$adiv];
    }

    if (preg_match('/\~crim$/', $divisions[$adiv]['opt']) || ($divisions[$adiv]['courtType'] == 'Trial')) {
        $crimdivs[$adiv] = $divisions[$adiv];
    }

    if (preg_match('/\~juv$/', $divisions[$adiv]['opt'])) {
        $juvdivs[$adiv] = $divisions[$adiv];
    }
    
    if ($divisions[$adiv]['courtType'] == 'Circuit Civil' || ($divisions[$adiv]['courtType'] == 'Foreclosure') || ($divisions[$adiv]['courtType'] == 'Trial')) {
        $circivdivs[$adiv] = $divisions[$adiv];
    }

    if ($divisions[$adiv]['courtType'] == 'County Civil' || ($divisions[$adiv]['courtType'] == 'Trial')) {
    	$cocivdivs[$adiv] = $divisions[$adiv];
    }
}

$expdivs = $prodivs;

$mh_divs = array();
$mh_divs["IPHNB"] = "Baker Act (North)";
$mh_divs["IPHSB"] = "Baker Act (South)";
$mh_divs["MHNB"] = "Marchman Act (North)";
$mh_divs["MHSB"] = "Marchman Act (South)";

$smarty->assign('prodivs', $prodivs);
$smarty->assign('famdivs', $famdivs);
$smarty->assign('circivdivs', $circivdivs);
$smarty->assign('olsdiv',$olsdiv);
$smarty->assign('crimdivs',$crimdivs);
$smarty->assign('juvdivs',$juvdivs);
$smarty->assign('cocivdivs',$cocivdivs);
$smarty->assign('expdivs', $expdivs);
$smarty->assign('mh_divs', $mh_divs);

$query = "
    select
        distinct(division_type)
    from
        divisions
    where
        division_type not in ('Shadow')
";

$divtypes = array();
getData($divtypes, $query, $jdbh);

$smarty->assign('divtypes',$divtypes);

$query = "
    select
    	distinct(courthouse_nickname),
        c.courthouse_id
    from
    	divisions d left outer join courthouses c on (d.courthouse_id=c.courthouse_id)
    where	
    	first_appearance = 1
";

$faps = array();
getData($faps, $query, $jdbh);

$smarty->assign('faps',$faps);

asort($divtypes);

$flagTypes = array();
$query = "
    select
        flagtype,
        dscr
    from
        flagtypes
    order by
        dscr
";

getData($flagTypes,$query,$fdbh);
$smarty->assign('flagTypes', $flagTypes);

$magResults = array();
$magistrates = array();
$query = "select
			first_name,
			middle_name,
			last_name,
			suffix,
			division,
			juv_cal_divisions,
			magistrate_type
		from
			magistrates
		order by
			last_name";
getData($magResults, $query, $jdbh);

foreach($magResults as $m){
	$types = explode("/", $m['magistrate_type']);
	$type = "";
	foreach($types as $t){
		if($t == "Juvenile"){
			$type .= $m['juv_cal_divisions'] . "," . $t . ";";
		}
		else{
			$type .= $m['division'] . "," . $t . ";";
		}
	}
	
	if(!empty($m['suffix'])){
        $mName = $m['last_name'] . ", " . $m['suffix'] . ", " . $m['first_name'];
    }
	else{
		$mName = $m['last_name'] . ", " . $m['first_name'];
	}
	
	if(!empty($m['middle_name'])){
		$mName .= " " . $m['middle_name'];
	}
	$magistrates[$mName] = $mName . "~" . $type;
	$calMagistrates[$m['division']] = $mName;
}

$jdbh = null;

$xferqueues = array();
getUserQueues($xferqueues, $fdbh);

$real_xferqueues = array();
getTransferQueues($user, $fdbh, $real_xferqueues);

$sdivs = $divisions;
ksort($sdivs);

foreach ($sdivs as $sdiv => $vals) {
    $queue = array("queue" => $sdiv);
    $queue['queuedscr'] = sprintf ("%s (%s)", $sdiv, $vals['courtType']);
    array_push($xferqueues, $queue);
}

$odbh = dbConnect("ols");
$results = array();
$query = "	SELECT *
            FROM mediation_scheduling.mediators
			WHERE active = 1
            ORDER BY last_name";

getData($results, $query, $odbh);

$count = 0;
$medNames = array();
$mediators = array();
foreach($results as $r){
	$medFirstNameArr = explode("-", $r['first_name']);
	
	$mString = trim($medFirstNameArr[1]) . " " . $r['last_name'];
	if(!in_array($mString, $medNames)){
		$medNames[$count] = $mString;
		$mediators[$count]['name'] = $mString;
		$mediators[$count]['mediator_id'] = $r['mediator_id'];
		$mediators[$count]['type'] = $r['mediator_type'];
		$mediators[$count]['locations'] = $r['locations'];
		$count++;
	}
	else{
		foreach($mediators as $key => $m){
			if($m['name'] == $mString){
				$curVal = $mediators[$key]['mediator_id'];
                $mediators[$key]['mediator_id'] = $curVal . "-" . $r['mediator_id'];
			}
	   }
    }
}

$smarty->assign('xferqueues', $xferqueues);
$smarty->assign('real_xferqueues', $real_xferqueues);

$searchParamJson = file_get_contents($_SERVER['JVS_DOCROOT'] . "/../conf/searchParams.json");
$searchParams = json_decode($searchParamJson,true);

ksort($searchParams['Charges']);
ksort($searchParams['Causes']);

$tabs = getSessVal('tabs');
if ($tabs == null) {
    $tabs = array();
}
$userid = getSessVal('user');

$smarty->assign('foo','FOOBAR');
$smarty->assign('mediators', $mediators);
$smarty->assign('magistrates', $magistrates);
$smarty->assign('calMagistrates', $calMagistrates);
$smarty->assign('searchParams', $searchParams);
$smarty->assign('userid', $userid);
$smarty->assign('vrbUrl', (string) $config->{'vrbUrl'});
$smarty->assign('wfCount', $wfcount);
$smarty->assign('pendCount', $pendCount);
$smarty->assign('tabs', $tabs);
$smarty->assign('active', "index");
$smarty->display('top/header.tpl');
$smarty->display('top/search.tpl');
?>
