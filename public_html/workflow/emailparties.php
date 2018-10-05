<?php
# emailparties.php -- called by order gen and soon by workflow, it emails the generated order

require_once("../php-lib/common.php");
require_once("../php-lib/db_functions.php");
require_once("../icmslib.php");
require_once("Smarty/Smarty.class.php");

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);

extract($_REQUEST);

$emails = explode(";", urldecode($pt_emails));
$result = array();

list ($division, $style) = getCaseDivAndStyle($ucn);

//$result['division'] = $division;
//$result['style'] = $style;

if (isset($pdf)) {
    $filename = sprintf("%s/tmp/%s", $_SERVER['DOCUMENT_ROOT'], basename($pdf));
} else {
    // We weren't passed a PDF name, so get it from the DB.  Just check to see if the file exists on disk, first
    $dbh = dbConnect("icms");
    $query = "
        select
            signed_filename
        from
            workflow
        where
            doc_id = :docid
    ";
    $doc = getDataOne($query, $dbh, array('docid' => $docid));
    $filename = sprintf("%s/tmp/%s", $_SERVER['DOCUMENT_ROOT'], $doc['signed_filename']);
    if (!file_exists($filename)) {
        // The file doesn't exist on disk.  Pull it from the DB
        $query = "
            select
                signed_pdf
            from
                workflow
            where
                doc_id = :docid
        ";
        $doc = getDataOne($query, $dbh, array('docid' => $docid));
        file_put_contents($filename, base64_decode($doc['signed_pdf']));
    };
}

//$result['pdf'] = $filename;
//$result['shortname'] = basename($filename);

$smarty->assign('ucn', $ucn);
$smarty->assign('casestyle', $style);
$smarty->assign('division',$division);

$attachments = array(array('filedesc' => $formname, 'shortname' => basename($filename)));
$smarty->assign('orders', $attachments);

$message = $smarty->fetch('eservice/eservice-email.tpl');

//$result['message'] = $message;

$from_name="Court E-Service System";

$subject="SERVICE OF COURT DOCUMENT CASE No.: $ucn";


# message body needs 
# division of court, case style, partes, title of documnet, sender's name & phone #.

#
#  MAIL IT!
#
if (mail_attachment($filename, $emails, $fromAddr, $from_name, $subject, $message)) {
    $result['status'] = "Success";
    $result['message'] = "The message was sent successfully.";
    
    $mailRecips = implode(",", $emails);
    
    $user = $_SESSION['user'];
    $logMsg = "User $user emailed document ID $docid to email addresses: $mailRecips";
    $logIP = $_SERVER['REMOTE_ADDR'];
log_this('JVS','workflow',$logMsg,$logIP,$dbh);
} else {
    $result['status'] = "Failure";
    $result['message'] = "There was a problem sending the message!!";
}

header("Content-type: application/json");
print json_encode($result);
exit;

?>