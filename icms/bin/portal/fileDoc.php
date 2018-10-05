<?php
require_once('Smarty/Smarty.class.php');

$wsdl = "https://test.myflcourtaccess.com/wsdl/BulkFilingReviewService.wsdl";

$filerEmails = array (
    'rhaney@pbcgov.org',
    'rich@haneys.net'
);

$docs = array (
    array (
        'file_name' => '/home/rhaney/portaltest/Samples/Deny_as_Untimely.pdf',
        'file_desc' => 'DENY AS UNTIMELY'
    ),
    //array (
    //    'file_name' => '/home/rhaney/portaltest/Samples/Deny_for_Oath-English.docx',
    //    'file_desc' => 'DENY FOR OATH - ENGLISH'
    //),
    //array (
    //    'file_name' => '/home/rhaney/portaltest/Samples/Deny_as_Untimely-1.pdf',
    //    'file_desc' => 'DENY AS UNTIMELY - 1'
    //)
);

$docInfo = array();
getDocInfo($docs, $docInfo);

$template = "Ex1.tpl";

// Of course, this wouldn't be hard-coded in a real system
$data = array (
    'filetime' => date('c'),
    'firstname' => 'Richard',
    'lastname' => 'Haney',
    'bar_id' => '333333FL',
    'filer_address' => '205 N Dixie Hwy',
    'filer_city' => 'West Palm Beach',
    'filer_state' => 'FL',
    'filer_zip' => '33401',
    'filer_phone' => '561-355-1189',
    'emails' => $filerEmails,
    'jud_circuit' => 'Fifteenth Circuit',
    'county' => 'Palm Beach County',
    'countyid' => 50,
    'logonname' => 'rhaney',
    'password' => 'Kbrh0120',
    'casenum' => '2009CF015789',
    'ucn' => '502009CD015789AXXXMB',
    'docid' => '999999',
    'casestyle' => 'State of Florida vs. LUZINCOURT, BELOT',
    'court_type' => 'Circuit Criminal',
    'court_id' => 2,
    'org_name' => 'Judiciary, Fifteenth Judicial Circuit of Florida',
    'org_email' => 'rich@haneys.net',
    'app_id' => 'ICMS - Fifteenth Circuit',
    'case_type' => 'criminal', // This must be all lower-case - it's a namespace identifier,
    'doc_info' => $docInfo
);

$smarty = new Smarty();
$smarty->assign('data',$data);;  

$meta = $smarty->fetch($template);

try {
    $client = new SoapClient($wsdl,array('cache_wsdl' => 1, 'trace' => 1));
    
    $ReviewFiling = new SoapVar($meta, XSD_ANYXML);
    
    $response = $client->ReviewFiling($ReviewFiling);
} catch (exception $e) {
    echo 'Caught exception: ',  $e->getMessage(), "\n";
    echo "Fault string: " . $e->faultstring . "\n\n";
    file_put_contents ('response1.xml', $client->__getLastResponse());
    exit;
}

file_put_contents ('request1.xml', $client->__getLastRequest());
file_put_contents ('response1.xml', $client->__getLastResponse());

exit;

function getDocInfo ($docs, &$docinfo) {
    if (!sizeof($docs)) {
        print "No ducments were specified.  Exiting.\n\n";
        exit;
    }
    
    // Ok, we have docs specified. We need to process them in 2 groups - one for the FilingLeadDocument
    // (1 document) section, and one for FilingConnectedDocuments (all others)
    // But first, make sure all of the files exist.
    for ($count = 0; $count < sizeof($docs); $count++) {
        if (!($statinfo = stat($docs[$count]['file_name']))) {
            print "File ' " . $docs[$count]['file_name'] . "' does not exist.  Exiting.\n\n";
        } else {
            // We need to know the file size, anyway.
            $docs[$count]['binary_size'] = $statinfo[7];   
        }
    }
    
    // Ok, all exist.  Start processing them.  Do the FilingLeadDocument first (index 0)
    $fileInfo = array();
    $fileInfo['file_type'] = getFileType($docs[0]['file_name']);
    $fileInfo['file_desc'] = $docs[0]['file_desc'];
    $fileInfo['file_name'] = $docs[0]['file_name'];
    $fileInfo['binary_size'] = $docs[0]['binary_size'];
    $fileInfo['encodedBase64'] = encodeFile($docs[0]['file_name']);
    
    $docinfo['FilingLeadDocument'] = $fileInfo;
    $docinfo['FilingConnectedDocuments'] = array();
    
    // Now get all of the other files.  The FilingConnectedDocuments is going to be an array of arrays,
    // with each of the "inner" arrays 
    for ($count = 1; $count < sizeof($docs); $count++) {
        $fileInfo = array();
        $fileInfo['file_type'] = getFileType($docs[$count]['file_name']);
        $fileInfo['file_desc'] = $docs[$count]['file_desc'];
        $fileInfo['file_name'] = $docs[$count]['file_name'];
        $fileInfo['binary_size'] = $docs[$count]['binary_size'];
        $fileInfo['encodedBase64'] = encodeFile($docs[$count]['file_name']);
        
        array_push($docinfo['FilingConnectedDocuments'], $fileInfo);
    }
}


function encodeFile ($filename) {
    # Returns a Base64-encoded representation of $filename
    $binary = file_get_contents($filename);
    $encoded = base64_encode($binary);
    return $encoded;
}

function getFileType ($filename) {
    $extensionTypes = array (
        'doc' => 'application/ms-word',
        'docx' => 'application/ms-word',
        'pdf' => 'application/pdf'
    );
    
    // Get the file extension
    $pieces = explode(".", $filename);
    $extension = $pieces[sizeof($pieces) - 1];
    if (!isset($extensionTypes[$extension])) {
        print "Unknown file type for '$filename'. Exiting.\n\n";
        exit;
    }
    return $extensionTypes[$extension];
}

?>