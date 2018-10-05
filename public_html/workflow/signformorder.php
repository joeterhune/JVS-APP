<?php
require_once("../php-lib/common.php");
require_once("../php-lib/db_functions.php");
# signformorder.php - sign a form order from the sign button in workflow

require_once('FirePHPCore/fb.php');
$firephp = FirePHP::getInstance(true);
$firephp->setEnabled(false); 

include "../icmslib.php";
include "../caseinfo.php";

extract($_REQUEST);

$docid = getReqval('docid');
$ts = date("m/d/Y h:i:s A");

$userid=strtolower($_SESSION['user']);

//file_put_contents("php://stderr","$ts: signformorder: ($docid,$ucn,$role,$userid)\n",FILE_APPEND);
if ((!isset($docid)) || (!isset($signas))) {
   echo "signformorder: ERROR: missing a variable ($docid,$ucn,$userid)";
   exit;
}

//$obj = array('userid' => $userid, 'ucn' => $ucn);

$dbh = dbConnect("icms");
$pdbh = dbConnect("portal_info");
$query = "
    select
        data,
        CASE
            WHEN signature_img is null THEN 'N'
            ELSE 'Y'
        END as esigned,
        ucn
    from
        workflow
    where
        doc_id = :docid
";

$rec = getDataOne($query, $dbh, array('docid' => $docid));

$formjson = $rec['data'];
$esigned = $rec['esigned'];
$ucn = $rec['ucn'];

$jsondata=(object)json_decode($formjson);

$sigInfo = generateSignature($signas,$docid, $pdbh, $dbh);

if (array_key_exists('FullName',$sigInfo)) {
    $sigimgfile = $sigInfo['SigFile'];
    $sigimg = $sigInfo['SigImg'];
    $signame = $sigInfo['FullName'];
    $sigtitle = $sigInfo['Title'];
    //$sigdiv = sprintf('<div class="sigdiv" id="sigdiv_%s" style="position: relative; left: 100px"><img src="%s"></div>', $ucn, $sigimgfile);
    $sigdiv = sprintf('<img class="signature" draggable="true" style="cursor: move; display: initial" src="data:image/jpeg;base64,%s">', $sigimg);
    $result['sigdiv'] = $sigdiv;
    $jsondata->{'judge_signature'} = $sigdiv;
} else {
    $result['ts'] = $ts;
}

# Generate the PDF with the signature inserted
$html = urldecode($jsondata->{'order_html'});

// Substitute the signature block
$html = preg_replace("/\[\% judge_signature \%\]/", $jsondata->{'judge_signature'}, $html);
$jsondata->{'order_html'} = html_entity_decode($html);

$fname = createOrderPDF($html, $ucn);
$signedPdf = file_get_contents($fname);
$stat = stat($fname);
$bsize = $stat[7];

#
# update the database
#
$query = "
    update
        workflow
    set
        data = :data,
        signed_pdf = :pdf,
        signed_filename = :fname,
        signed_binary_size = :bsize
    where
        doc_id = :docid
";
doQuery($query, $dbh, array('data' => json_encode($jsondata), 'docid' => $docid, 'pdf' => base64_encode($signedPdf),
                            'fname' => basename($fname), 'bsize' => $bsize));

#
# update te workqueues last_update for whatever queueu...
#
$query = "
    update
        workqueues
    set
        last_update=CURRENT_TIMESTAMP
    where
        queue=(
            select
                queue
            from
                workflow
            where
                doc_id = :docid
        )
";
doQuery($query, $dbh, array('docid' => $docid));

$result = array();
$result['status'] = "Success";

header('application/json');
print json_encode($result);
?>
