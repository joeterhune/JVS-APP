<?php
require_once("../php-lib/common.php");
require_once("../php-lib/db_functions.php");

require_once('FirePHPCore/fb.php');
$firephp = FirePHP::getInstance(true);
$firephp->setEnabled(false); 

$result = array();

extract($_REQUEST);

if (!isset($docid)) {
    $result['status'] = "Failure";
    $result['message'] = "No Doc ID was specified.";
    returnJson($result);
    exit;
}


$dbh = dbConnect("icms");
$query = "
    select
        data
    from
        workflow
    where
        doc_id = :docid
";

$rec = getDataOne($query, $dbh, array('docid' => $docid));

# Do we have original HTML stored?
$formData = json_decode($rec['data'], TRUE);
if (!array_key_exists('orig_html',$formData)) {
    # Nope.  Copy order_html and update the record
    $formData['orig_html'] = $formData['order_html'];
    $newData = json_encode($formData);
    $query = "
        update
            workflow
        set
            data = :newdata
        where
            doc_id = :docid
    ";
    doQuery($query, $dbh, array('newdata' => $newData, 'docid' => $docid));
}

if (!array_key_exists('data',$rec)) {
    $result['status'] = "Failure";
    $result['html'] = "No order information found!";
} else {
    $data = json_decode($rec['data'],true);
    
    $result['status'] = "Success";
    $result['html'] = $data['order_html'];
    $result['orig_html'] = $data['orig_html'];
}

returnJson($result);
?>