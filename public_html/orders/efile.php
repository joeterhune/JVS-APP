<?php
require_once "../php-lib/common.php";
require_once "../php-lib/db_functions.php";
require_once "../php-lib/ldap_functions.php";
require_once "../icmslib.php";
require_once "../caseinfo.php";

require_once "Smarty/Smarty.class.php";

$smarty = initSmarty();

$templateData = array();

#
#  MAIN PROGRAM
#
#
# get filing info from workflow
#
#fix_request();
$docid = getReqVal('docid');
$ucn = getReqVal('ucn');
$signedDoc = getReqVal('signed');

if ($docid=="") {
    echo "Error: no docid provided!";
    exit;
}

if ($signedDoc != "") {
    $signedDoc = sprintf("/var/www/html%s", $signedDoc);
    if (!file_exists($signedDoc)) {
        $signedDoc = "";
    }
}

$user = $_SESSION['user'];

$dbh = dbConnect("icms");

if ($ucn=="") { # called from workflow?
    $query = "
        select
            ucn,
            data
        from
            workflow
        where
            doc_id = :docid
    ";
    
    $rec = getDataOne($query, $dbh, array('docid' => $docid));
    $ucn = $rec['ucn'];
    $datajson = $rec['data'];
}
if ($ucn=="") {
    echo "Error: the case # for this document is blank! Please fill it in!";
    exit;
}

$data = json_decode($datajson, true);

list($ucn, $type) = sanitizeCaseNumber($data['ucn']);
if ($type == "banner") {
    $ucn = getBannerExtendedCaseId($ucn);
}
$formid = $data['form_id'];

list($ucn, $type) = sanitizeCaseNumber($ucn);
list($div, $style) = getCaseDivAndStyle($ucn, $type);

$templateData['ccisucn'] = preg_replace("/-/","",$ucn);
$templateData['docid'] = sprintf("%s_%s", $templateData['ccisucn'], $docid);
$templateData['filetime'] = date('Y-m-d\TH:i:s.uP');

$jdbh = dbConnect("judge-divs");
$divlist = array();

getDivList($jdbh, $divlist);

//$pdbh = dbConnect("portal_info");
$efInfo = eFileInfo($user, $jdbh);

$templateData['firstname'] = $efInfo['first_name'];
$templateData['lastname'] = $efInfo['last_name'];
$templateData['logonname'] = $efInfo['user_id'];
$templateData['password'] = $efInfo['password'];
$templateData['bar_id'] = $efInfo['bar_num'];

$templateData['case_type'] = $divlist[$div]['PortalNameSpace'];
$templateData['casestyle'] = $style;
$templateData['countyid'] = 50;
$templateData['court_id'] = $divlist[$div]['CourtTypeID'];
$templateData['jud_circuit'] = "Fifteenth Circuit";
$templateData['county'] = "Palm Beach County";
$templateData['court_type'] = $divlist[$div]['PortalCourtType'];

$query = "
    select
        efiling_document_description
    from
        forms
    where
        form_id = :formid
";
$rec = getDataOne($query, $dbh, array('formid' => $formid));
$docdesc = $rec['efiling_document_description'];

if ($signedDoc == "") {
    
    $html=`/var/www/html/case/orders/merge.cgi paramfile=$paramfile`;
    
    # now write the resulting html to a file
    $orderfile=tempnam("/var/www/html/tmp","order");
    
    # fix img src params
    $html=str_replace("<img src=\"/icmsdata/tmp","<img src=\"/var/www/icmsdata/tmp",$html);
    $html=str_replace("<img src=/icmsdata/tmp","<img src=/var/www/icmsdata/tmp",$html);
    # replace that pagebreak tag with the actual html
    $formhtml=str_replace("[% pagebreak %]","<pagebreak />",$formhtml);
    file_put_contents($orderfile,$html);
    logerr("envelopes.php: orderfile is $orderfile");
    
    $postFields = array (
        'ucn' => urlencode($ucn),
        'htmlfile' => urlencode($orderfile)
    );

    $protocol = "http";
    if ($_SERVER['HTTPS'] == 'on') {
        $protocol = "https";
    }

    $url = sprintf("%s://%s/case/orders/genpdf.php", $protocol, $_SERVER['HTTP_HOST']);
    $orderJson = curlJson($url, $postFields);
    $ofile = json_decode($orderJson,true);
    $orderfname = sprintf("/var/www/html%s", $ofile['filename']);
} else {
    $orderfname = $signedDoc;
}

$image = array();
$image['file_type'] = 'application/pdf';
$image['file_desc'] = $data['form_name'];
$image['file_desc'] = "ORDER";
$image['file_name'] = $orderfname;
$stat = stat($orderfname);
$image['binary_size'] = $stat['size'];

$infile = file_get_contents($orderfname);
$image['encodedBase64'] = base64_encode($infile);

$templateData['doc_info'] = array();
$templateData['doc_info']['FilingLeadDocument'] = $image;
$templateData['doc_info']['FilingConnectedDocuments'] = array();

$smarty->assign('data', $templateData);

$xml = $smarty->fetch('portal/ReviewFiling.tpl');

$config = simplexml_load_file($icmsXml);

$wsdl = (string) $config->{'eFilingWsdl'};

# This file will contain an XML request to be sent directly to RetrieveCaseDocuments
//$meta = file_get_contents($xmlfile);
file_put_contents("/tmp/lastRequest.xml", $xml);

$client = new SoapClient($wsdl,array('cache_wsdl' => 1, 'trace' => 1));
try {    
    $ReviewFiling = new SoapVar($xml, XSD_ANYXML);
    $response = $client->ReviewFiling($ReviewFiling);
    #
    # save this response object for perusal/analysis...
    $sr=serialize($response);
    file_put_contents("/tmp/lastresponseobject.txt",$sr);
    # save the xml, while we're at it...
    file_put_contents("/tmp/lastresponse.xml",$client->__getLastResponse());
    # get data from the $response object
    $errcode=$response->MessageReceiptMessage->Error->ErrorCode->_;
    $errmsg=$response->MessageReceiptMessage->Error->ErrorText->_;
    $fileid=$response->MessageReceiptMessage->DocumentIdentification[0]->IdentificationID->_;
    if ($errcode!=0) {
        echo "ERROR:$errcode: $errmsg";
        exit;
    }
} catch (exception $e) {
    
    file_put_contents("/tmp/lastexceptionresponse.xml",$client->__getLastResponse());
    echo 'Caught exception: ',  $e->getMessage(), "\n";
    echo "Fault string: " . $e->faultstring . "\n\n";
    exit;
}
echo "OK:$fileid:$errcode:$errmsg";
?>