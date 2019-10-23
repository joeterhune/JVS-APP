<?php
require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/common.php");
require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/db_functions.php");
require_once('Smarty/Smarty.class.php');

$config = simplexml_load_file($_SERVER['JVS_ROOT'] . "/conf/ICMS.xml");

if (isset($config->{'eFilingWsdl'})) {
    $wsdl = (string) $config->{'eFilingWsdl'};
} else {
    $wsdl = 'https://test.myflcourtaccess.com/wsdl/BulkFilingReviewService.wsdl';
}

$dbh = dbConnect("portal_info");
$idbh = dbConnect("icms");

$openFilings = array();

getOpenFilings($openFilings, $dbh);

$filingIds = array();
foreach ($openFilings as $filing) {
    array_push($filingIds, $filing['filing_id']);
}
//$filingIds = array(240735);
//
//var_dump($filingIds);
//exit;

if (!count($filingIds)) {
    print "Nothing to do.  Exiting.\n\n";
    exit;
}

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);

$smarty->assign('filings', $filingIds);
$smarty->assign('adminLogin', $config->{'portalAdminFiler'}->{'name'});
$smarty->assign('adminPassword', $config->{'portalAdminFiler'}->{'password'});

$meta = $smarty->fetch('portal/FilingStatusReviewRequest.tpl');

$client = new SoapClient($wsdl, array('cache_wsdl' => 1, 'trace' => 1));

try {
    
    $ReviewFiling = new SoapVar($meta, XSD_ANYXML);
    $response = $client->GetFilingReviewResult($ReviewFiling);
    
    file_put_contents ('request.xml', $client->__getLastRequest());
    file_put_contents("response.xml", $client->__getLastresponse());
} catch (exception $e) {
    file_put_contents ('request.xml', $client->__getLastRequest());
    file_put_contents("response.xml", $client->__getLastresponse());
    echo 'Caught exception: ',  $e->getMessage(), "\n";
    echo "Fault string: " . $e->faultstring . "\n\n";
    exit;
}

$response = json_decode(json_encode($response),true);
$messages = array();

if (array_key_exists('Case',$response['ReviewFilingCallbackMessage'])) {
    // Just a single element.  Push it onto the $messages array
    array_push($messages, $response['ReviewFilingCallbackMessage']);
} else {
    $messages = $response['ReviewFilingCallbackMessage'];   
}

$dbh->beginTransaction();
$idbh->beginTransaction();

foreach ($messages as $message) {
    $status = $message['FilingStatus']['StatusText']['_'];
    $filingID = $message['DocumentIdentification']['IdentificationID']['_'];
    $style =  $message['Case']['CaseTitleText']['_'];
    $fileDate = array_key_exists('DocumentFiledDate', $message) ? $message['DocumentFiledDate']['DateTime']['_'] : null;
    $fileDate = preg_replace('/T/',' ',$fileDate);
    $clerkCase =  $message['Case']['CaseTrackingID'][0]['_'];
    
    $statusDesc = null;
    
    if (array_key_exists('StatusDescriptionText', $message['FilingStatus'])) {
        $statusDesc = $message['FilingStatus']['StatusDescriptionText']['_'];
    }
    
    if ($filingID == 240768) {
        $statusDesc = "Correction Queue";
        $status = "Correction Queue";
    }
    
    if ($fileDate != null) {
        $query = "
            update
                portal_filings
            set
                case_style = :caseStyle,
                clerk_case_id = :clerkCase,
                filing_status = :status,
                completion_date = :compDate,
                status_dscr = :statusDesc
            where
                filing_id = :filingID
        ";
        doQuery($query, $dbh, array('caseStyle' => $style, 'clerkCase' => $clerkCase, 'status' => $status, 'compDate' => $fileDate,
                                    'statusDesc' => $statusDesc, 'filingID' => $filingID));
    } else {
        $query = "
            update
                portal_filings
            set
                case_style = :caseStyle,
                clerk_case_id = :clerkCase,
                filing_status = :status,
                status_dscr = :statusDesc
            where
                filing_id = :filingID
        ";
        doQuery($query, $dbh, array('caseStyle' => $style, 'clerkCase' => $clerkCase, 'status' => $status,
                                    'statusDesc' => $statusDesc, 'filingID' => $filingID));
    }
    
    if ($statusDesc == "Correction Queue") {
        // It's a pending queue filing. Update the record for the workflow accordingly
        $query = "
            update
                workflow
            set
                efile_queued = 0,
                efile_submitted = 0,
                efile_pended = 1,
                efile_completed = 0
            where
                portal_filing_id = :filingID
        ";
        doQuery($query,$idbh,array('filingID' => $filingID));
    } elseif ($statusDesc == "Filed") {
        $query = "
            update
                workflow
            set
                efile_queued = 1,
                efile_submitted = 1,
                efile_pended = 0,
                efile_completed = 1
            where
                portal_filing_id = :filingID
        ";
        doQuery($query,$idbh,array('filingID' => $filingID));
    }
    
    print "Updated filing '$filingID'\n";
}

$dbh->commit();
$idbh->commit();

?>
