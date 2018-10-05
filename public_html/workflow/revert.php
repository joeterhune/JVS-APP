<?php
require_once "../php-lib/common.php";
require_once "../php-lib/db_functions.php";
require_once "../icmslib.php";
require_once 'wfcommon.php';

require_once('FirePHPCore/fb.php');
$firephp = FirePHP::getInstance(true);
$firephp->setEnabled(false); 

$docid = getReqVal('docid');

$ts=date("m/d/Y h:i:s A"); # current timestamp...
if ($docid=="") {
    file_put_contents("php://stderr","$ts: revert.php ERROR: blank docid\n",FILE_APPEND);
    echo "ERROR";
    exit;
}
$dbh = dbConnect("icms");

# get current queue for this doc
$query ="
    select
        queue,
        doc_type,
        ucn,
        formname
    from
        workflow
    where
        doc_id = :docid
";

$rec = getDataOne($query, $dbh, array('docid' => $docid));

$queue = $rec['queue'];
$doctype = $rec['doc_type'];
$ucn = $rec['ucn'];
$formname = $rec['formname'];

if (in_array($doctype,array("OLSORDER","PROPORDER","MISCDOC"))) {
    # Get the original form HTML and replace the order_html element of data with it
    $query = "
        select
            data
        from
            workflow
        where
            doc_id = :docid
    ";
    $rec = getDataOne($query, $dbh, array('docid' => $docid));
    $formData = json_decode($rec['data'], TRUE);
    if (array_key_exists('orig_html', $formData)) {
        $formData['order_html'] = $formData['orig_html'];
    } else {
        // No original? Make the original the current value so we at least
        // have something
        $formData['orig_html'] = $formData['order_html'];
    }
    
    // And, recreate it
    $newData = json_encode($formData);
    
    # reset any signatures/annotations...
    $query = "
        update
            workflow
        set
            data = :datajson,
            signed_time = null,
            signer_id = null,
            signer_name = null,
            signer_title = null,
            signature_img = null,
            signature_file = null,
            conformed_sig_file = null,
            conformed_sig_img = null,
            signed_pdf = null,
            signed_filename = null,
            signed_binary_size = null,
            efile_queued = 0,
            efile_submitted = 0,
            efile_pended = 0,
            efile_completed = 0,
            emailed = 0,
            emailed_time = null,
            emailed_from_addr = null,
            portal_filing_id = null,
            mailing_confirmed = 0,
            mailing_confirmed_by = 0,
            mailing_confirmed_time = null,
            finished = 0
        where
            doc_id = :docid
    ";
    doQuery($query, $dbh, array('datajson' => $newData, 'docid' => $docid));
    # delete the annotated and possibly signed copy...
    //unlink("$DOCPATH/$docid.pdf");
    # delete any associated JSON data...
    //unlink("$DOCPATH/$docid.data");
} else if ($doctype=="FORMORDER") {
    $query = "
        select
            data
        from
            workflow
        where
            doc_id = :docid
    ";
    
    $rec = getDataone($query, $dbh, array('docid' => $docid));
    $data = $rec['data'];
    
    $dataobj = json_decode($data, true);
    $esigsarr=explode(",",$dataobj['esigs']);
    
    foreach ($esigsarr as $esig) {
        $signame = $esig . "_signature";
        $dataobj[$signame] = "";
    }
    
    //$dataobj['order_html'] = ''; # wipe any saved versions, as they may have e-sigs partially applied...
    
    
    $datajson=json_encode($dataobj);
    
    $query = "
        update
            workflow
        set
            data = :datajson,
            signed_time = null,
            signer_id = null,
            signer_name = null,
            signer_title = null,
            signature_img = null,
            signature_file = null,
            conformed_sig_file = null,
            conformed_sig_img = null,
            signed_pdf = null,
            signed_filename = null,
            signed_binary_size = null,
            efile_queued = 0,
            efile_submitted = 0,
            efile_pended = 0,
            efile_completed = 0,
            emailed = 0,
            emailed_time = null,
            emailed_from_addr = null,
            portal_filing_id = null,
            mailing_confirmed = 0,
            mailing_confirmed_by = 0,
            mailing_confirmed_time = null,
            finished = 0
        where
            doc_id = :docid
    ";
    
    doQuery($query, $dbh, array('datajson' => $datajson, 'docid' => $docid));
}

$user = $_SESSION['user'];
$logMsg = "User $user reverted document ID $docid in workflow queue '$queue'";
$logIP = $_SERVER['REMOTE_ADDR'];
log_this('JVS','workflow',$logMsg,$logIP,$dbh);

// And remove any queued_filings records
$query = "
    delete from
        queued_filings
    where
        doc_id = :docid
";
doQuery($query, $dbh, array('docid' => $docid));

#
# set last_updated for that queue
#

updateQueue($queue, $dbh);
echo "OK";
?>