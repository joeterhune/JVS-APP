<?php

require_once("/usr/local/icms-web/case/php-lib/common.php");
require_once("/usr/local/icms-web/case/php-lib/db_functions.php");
require_once('Smarty/Smarty.class.php');

$config = simplexml_load_file("/usr/local/icms/etc/ICMS.xml");

if (isset($config->{'eFilingWsdl'})) {
    $wsdl = (string) $config->{'eFilingWsdl'};
} else {
    $wsdl = 'https://test.myflcourtaccess.com/wsdl/BulkFilingReviewService.wsdl';
}

# This file will contain an XML request to be sent directly to BulkReviewFilingRequest
$options = getopt("f:");
if (array_key_exists('f', $options)) {
    $file = $options['f'];
    if (file_exists($file)) {
        $input = file_get_contents($file);
        
        $xse = new SimpleXMLElement($input);
        $filingID = (int) $xse->children('s',TRUE)->Body->children('',TRUE)->BulkReviewFilingResponse->MessageReceiptMessage->children('nc',TRUE)->DocumentIdentification->IdentificationID;
        print $filingID . "\n\n";
        $filingDate = (string) $xse->children('s',TRUE)->Body->children('',TRUE)->BulkReviewFilingResponse->MessageReceiptMessage->children('nc',TRUE)->DocumentReceivedDate->DateTime;
        print $filingDate . "\n\n";
    }
}

//exit;

$dbh = dbConnect("icms");

$query = "
    select
        w.doc_id as DocID,
        REPLACE(w.ucn, '-', '') as UCN,
        CONCAT(w.signer_id, '_15th') as PortalFiler,
        w.creator as FilingCreator,
        q.case_style as CaseStyle,
        q.clerk_case_id as ClerkCaseID,
        w.signed_pdf as encodedBase64,
        w.signed_filename as shortname,
        w.signed_binary_size as BinarySize,
        f.form_name as FormName,
        f.efiling_document_description as portaldesc,
        w.portal_filing_id as FilingID
    from
        queued_filings q
            left outer join workflow w on q.doc_id = w.doc_id
            left outer join forms f on w.form_id = f.form_id
    where
        q.filing_complete = 0
        and w.signed_binary_size is not null
";

$filings = array();
getData($filings, $query, $dbh);

if (sizeof($filings) == 0) {
    print "Nothing to do.\n";
    exit;
}

$pdbh = dbConnect("portal_info");
$scdbh = dbConnect("showcase-prod");

foreach ($filings as $filing) {
    if ($filing['FilingID'] != null) {
        print "NEED TO RE-FILE " . $filing['FilingID'] ." for WF ID  " . $filing['DocID'] . ".\n";
        $query = "
            select
                filing_xml
            from
                queued_filings
            where
                doc_id = (
                    select
                        doc_id
                    from
                        workflow
                    where
                        portal_filing_id = :filingID
                )
        ";
        $rec = getDataOne($query, $dbh, array('filingID' => $filing['FilingID']));
        
        
        $xse = new SimpleXMLElement($rec['filing_xml']);
        
        $doc = $xse->children('',TRUE)->ReviewFilingRequestMessage->CoreFilingMessage->FilingLeadDocument;
        
        $docmeta = $doc->children('ecf',TRUE)->DocumentRendition->DocumentRenditionMetadata;
        
        $filename = $docmeta->children('nc',TRUE)->DocumentFileControlID;
        $attachment = $docmeta->children('ecf',TRUE)->DocumentAttachment;
        $size = $attachment->children('nc',TRUE)->BinarySizeValue;
        $base64 = $attachment->children('nc',TRUE)->BinaryBase64Object;
        
        //var_dump($filename);
        //var_dump($size);
        
        // Get the replacement information from the queue
        $query = "
            select
                signed_pdf,
                signed_filename,
                signed_binary_size
            from
                workflow
            where
                portal_filing_id = :filingID
        ";
        
        $rec = getDataOne($query, $dbh, array('filingID' => $filing['FilingID']));
        
        $docmeta->children('nc',TRUE)->DocumentFileControlID = $rec['signed_filename'];
        $attachment->children('nc',TRUE)->BinarySizeValue = $rec['signed_binary_size'];
        $attachment->children('nc',TRUE)->BinaryBase64Object = $rec['signed_pdf'];
        
        $meta = $xse->asXML();
        
        // This next part is cheating.  Insert the filing ID into the XML.
        $docidStr =  sprintf("<nc:DocumentIdentification>\n<nc:IdentificationID>%s</nc:IdentificationID>\n<nc:IdentificationCategoryText>FLEPORTAL_FILING_ID</nc:IdentificationCategoryText>\n</nc:DocumentIdentification>\n\n<CoreFilingMessage",
                             $filing['FilingID']);
        
        $meta = preg_replace('/<CoreFilingMessage/', $docidStr, $meta);
        $meta = preg_replace('/<\?xml version="1.0"\?>/','',$meta);
        
        file_put_contents("/tmp/this.xml", $meta);
    } else {
        print "Document " . $filing['DocID'] . " is a NEW filing.\n";
        
        $casenum = $filing['ClerkCaseID'];
        list($ucn, $casetype) = sanitizeCaseNumber($casenum);
        
        // For Showcase, just strip dashes, because that's what the portal wants
        $caseInfo = getShowcaseCaseInfo($casenum,$scdbh);
        
        $smarty = new Smarty;
        $smarty->setTemplateDir("/usr/local/icms/templates");
        $smarty->setCompileDir("/var/www/smarty/templates_c");
        $smarty->setCacheDir("/var/www/smarty/cache");
        $smarty->setConfigDir("/var/www/smarty/config");
        
        $data = array();
        $data['filetime'] = date('c');
    
        $filer = $filing['PortalFiler'];
        $filer_user = str_replace("_15th", "", $filer);
        
        $eFileInfo = eFileInfo($filer_user, $pdbh);
        
        $data['firstname'] = $eFileInfo['first_name'];
        $data['lastname'] = $eFileInfo['last_name'];
        $data['logonname'] = $eFileInfo['portal_id'];
        $data['password'] = $eFileInfo['password'];
        $data['bar_id'] = $eFileInfo['bar_num'] . "FL";
        $data['ClerkCase'] = $casenum;
        $data['UCN'] = $ucn;
        $data['county_id'] = 50;
        $data['judicial_circuit'] = "Twelfth Circuit";
        $data['county'] = "Sarasota";
        $data['CaseStyle'] = $caseInfo['CaseStyle'];
            
        // Get the portal namespace and court type for this case
        $query = "
            select
                portal_namespace,
                court_type_id
            from
                court_type_map
            where
                portal_court_type = :pct
        ";
        $divInfo = getDataOne($query, $pdbh, array('pct' => $courtTypes[$caseInfo['CourtType']]));
        $data['court_id'] = $divInfo['court_type_id'];
        $data['case_type'] = $divInfo['portal_namespace'];
        $data['court_type'] = $courtTypes[$caseInfo['CourtType']];
        
        $data['doc_info'] = array();
            
        $firstFile = $filing;
        
        $imgCount = 1;
        
        $firstFile['docID'] = sprintf("DOC%05d", $imgCount);
        $firstFile['attachID'] = sprintf("ATT%05d", $imgCount);
        $firstFile['attachSeq'] = $imgCount;
        $firstFile['binary_size'] = $firstFile['BinarySize'];
        $firstFile['file_type'] = 'application/pdf';
        $firstFile['documentgroup'] = getFilingGroup($firstFile['portaldesc']);
        
        $data['doc_info']['FilingLeadDocument'] = $firstFile;
        
        //$data['doc_info']['FilingConnectedDocuments'] = array();
        
        $smarty->assign('data', $data);
        $meta = $smarty->fetch('portal/ReviewFiling.tpl');
        
    }
    
    
    
    // Save the XML so it'll be easier to reuse if needed
    $query = "
        update
            queued_filings
        set
            filing_xml = :meta
        where
            doc_id = :docid
    ";
    
    doQuery($query, $dbh, array('meta' => $meta, 'docid' => $filing['DocID']));
           
    // And, GO!
    $errorArr = array();
    $xmlresp = "";
    
    //$outfile = sprintf("/home/rhaney/tmp/meta-%d.xml", $filing['DocID']);
    //file_put_contents($outfile,$meta);
    
    $result = sendFiling($meta, $xmlresp, $errorArr);
    
    if (!$result) {
        print "There was an error!!!\n\n";
        var_dump($response);
        var_dump($errorArr);
        exit;
    } else {
        $xse = new SimpleXMLElement($xmlresp);
        $errorCode = (int) $xse->children('s',TRUE)->Body->children('',TRUE)->BulkReviewFilingResponse->MessageReceiptMessage->children('ecf',TRUE)->Error->ErrorCode;
        if ($errorCode) {
            $errorStr = (string) $xse->children('s',TRUE)->Body->children('',TRUE)->BulkReviewFilingResponse->MessageReceiptMessage->children('ecf',TRUE)->Error->ErrorText;
            print "There was an error filing. The response received was: " . $errorStr;
        } else {
            $filingID = (int) $xse->children('s',TRUE)->Body->children('',TRUE)->BulkReviewFilingResponse->MessageReceiptMessage->
                children('nc',TRUE)->DocumentIdentification->IdentificationID;
                
            $filingDate = (string) $xse->children('s',TRUE)->Body->children('',TRUE)->BulkReviewFilingResponse->MessageReceiptMessage->
                children('nc',TRUE)->DocumentReceivedDate->DateTime;
            
            // First, insert it into the portal_filings table
            $pdbh->beginTransaction();
            $query = "
                replace into
                    portal_filings (
                        user_id,
                        portal_id,
                        filing_id,
                        casenum,
                        case_style,
                        clerk_case_id,
                        filing_date,
                        portal_post_date,
                        filing_status,
                        status_date,
                        status_dscr,
                        workflow_id
                    ) values (
                        :user_id,
                        :portal_id,
                        :filing_id,
                        :casenum,
                        :case_style,
                        :clerk_case,
                        :file_date,
                        :post_date,
                        'Pending Filing',
                        NOW(),
                        'Pending Filing',
                        :docid
                    )
            ";
            $args = array('user_id' => $firstFile['FilingCreator'], 'portal_id' => $filer, 'filing_id' => $filingID, 'casenum' => $ucn,
                          'case_style' => $caseInfo['CaseStyle'], 'clerk_case' => $casenum, 'file_date' => $filingDate, 'post_date' => $data['filetime'],
                          'docid' => $filing['DocID']);
            doQuery($query, $pdbh, $args);
                
                
            // Now mark it as ifiled in the queued_filings_table
            $query = "
                update
                    queued_filings
                set
                    filing_complete = 1
                where
                    doc_id = :doc_id
            ";
            doQuery($query, $dbh, array('doc_id' => $filing['DocID']));
                    
            // And also in the workflow table
            $query = "
                update
                    workflow
                set
                    efile_queued = 0,
                    efile_submitted = 1,
                    efile_pended = 0,
                    efile_completed = 0,
                    portal_filing_id = :filing_id,
            		finished = 1
                where
                    doc_id = :doc_id
            ";
            doQuery($query, $dbh, array('doc_id' => $filing['DocID'], 'filing_id' => $filingID));
            $pdbh->commit();
        }
    }
}


function sendFiling ($reqData, &$response, &$error = null) {
    global $wsdl;
    $client = new SoapClient($wsdl,array('cache_wsdl' => 1, 'trace' => 1));
    try {
        
        $ReviewFiling = new SoapVar($reqData, XSD_ANYXML);
        $request = $client->ReviewFiling($ReviewFiling);
         
        $response = $client->__getLastResponse();
        return 1;
    } catch (exception $e) {
        $response = $client->__getLastResponse();
        if ($error != null) {
            $error['exception'] = $e->getMessage();
            $error['faultstring'] = $e->faultstring;
        }
        return 0;
    }
}


?>