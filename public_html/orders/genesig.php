<?php
# genesig - given a userid, a case #, a name, and a role
# returns a timestamp, and path to a temporary file that contains the
# signature image for that user with the other info superimposed
# as a digital watermark...and the name and role superimposed at the bottom
require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/common.php");
require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/db_functions.php");
include $_SERVER['JVS_DOCROOT'] .  "/icmslib.php";

extract($_REQUEST);

$config = simplexml_load_file($icmsXml);

if (!isset($docid) || !isset($sigName)) {
    echo "ERROR";
    exit;
}

// Get this just in case the seconds change between the other function calls.
$now = time();
$ts=date("m/d/Y h:i:s A", $now);
$sigdate=date("l, F j, Y", $now);
$filets=date("Ymdhis", $now);

$sigkey = (string) $config->signKey;
$sigInfo = generateSignature($sigName, $docid);

if (array_key_exists('FullName',$sigInfo)) {
    $sigimgfile = $sigInfo['SigFile'];
    $sigimg = $sigInfo['SigImg'];
    $signame = $sigInfo['FullName'];
    $sigtitle = $sigInfo['Title'];
    
	if($isOrder){
    	$sigdiv = sprintf('<img class="signature" title="%s" name="%s" draggable="true" style="cursor: move; display: initial" src="data:image/jpeg;base64,%s">', $sigtitle, $signame, $sigimg);
    }
    else{
    	$sigdiv = sprintf('<div class="sigdiv  right"><div class="right"><img class="signature" title="%s" name="%s" draggable="true" style="cursor: move; display: initial" src="data:image/jpeg;base64,%s"></div>', $sigtitle, $signame, $sigimg);
    }
    
    $result['sigdiv'] = $sigdiv;
    
    //$_SESSION['signature_html'] = $sigdiv;
    $dbh = dbConnect("icms");
    $user = $_SESSION['user'];
    $logMsg = "User $user applied the signature for $signame to document ID $docid";
    $logIP = $_SERVER['REMOTE_ADDR'];
    log_this('JVS','workflow',$logMsg,$logIP,$dbh);
} else {
    $result['ts'] = $ts;
}

header('Content-Type: application/json');
print json_encode($result);

exit;

?>
