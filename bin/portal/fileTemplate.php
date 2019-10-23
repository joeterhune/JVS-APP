<?php

require_once($_SERVER['JVS_ROOT'] . "/public_html/php-lib/common.php");
require_once($_SERVER['JVS_ROOT'] . "/public_html/php-lib/db_functions.php");

$config = simplexml_load_file($icmsXml);

if (isset($config->{'eFilingWsdl'})) {
    $wsdl = (string) $config->{'eFilingWsdl'};
} else {
    $wsdl = 'https://test.myflcourtaccess.com/wsdl/BulkFilingReviewService.wsdl';
}

# This file will contain an XML request to be sent directly to BulkReviewFilingRequest
$options = getopt("f:r::");
$file = $options['f'];
if (!file_exists($file)) {
    exit;
}

if(isset($options['r'])){
	$retry = true;
}
else{
	$retry = false;
}

$meta = file_get_contents($file);

try {
    $client = new SoapClient($wsdl,array('cache_wsdl' => 1, 'trace' => 1));
    $fileXml = simplexml_load_file($file);
    //Now submit the request
    $ReviewFiling = new SoapVar($meta, XSD_ANYXML);
    $response = $client->ReviewFiling($ReviewFiling);
    
    if($retry){
	    $pdbh = dbConnect("portal_info");
	    $portal_args = array();
	    $pending_args = array();
	    
	    //This is super nasty and I hope they don't change the format of their response anytime soon
	    $namespaces =  $fileXml->ReviewFilingRequestMessage->CoreFilingMessage->getNameSpaces(true);
	    $nc = $fileXml->ReviewFilingRequestMessage->CoreFilingMessage->children($namespaces['nc']);
	    $domestic = $fileXml->ReviewFilingRequestMessage->CoreFilingMessage->children($namespaces['domestic']);
	    $juvenile = $fileXml->ReviewFilingRequestMessage->CoreFilingMessage->children($namespaces['juvenile']);
	    $criminal = $fileXml->ReviewFilingRequestMessage->CoreFilingMessage->children($namespaces['criminal']);
	    $civil = $fileXml->ReviewFilingRequestMessage->CoreFilingMessage->children($namespaces['civil']);
	    $appellate = $fileXml->ReviewFilingRequestMessage->CoreFilingMessage->children($namespaces['appellate']);
	    
	    $dom_type = $domestic->children($namespaces['nc'])->CaseTitleText;
	    $juv_type = $juvenile->children($namespaces['nc'])->CaseTitleText;
	    $crim_type = $criminal->children($namespaces['nc'])->CaseTitleText;
	    $civ_type = $civil->children($namespaces['nc'])->CaseTitleText;
	    $app_type = $appellate->children($namespaces['nc'])->CaseTitleText;
	    
	    if(isset($dom_type) && !empty($dom_type)){
	    	$case_type = "domestic";
	    }
	    else if(isset($juv_type) && !empty($juv_type)){
	    	$case_type = "juvenile";
	    }
	    else if(isset($crim_type) && !empty($crim_type)){
	    	$case_type = "criminal";
	    }
	    else if(isset($civ_type) && !empty($civ_type)){
	    	$case_type = "civil";
	    }
        else if(isset($app_type) && !empty($app_type)){
            $case_type = "appellate";
        }
	    
		$ecf = $nc->DocumentSubmitter->children($namespaces['ecf']);
		$nc2 = $ecf->children($namespaces['nc']);
		
		$portal_id = (string)$nc2->PersonOtherIdentification->IdentificationID;
		$portal_args['portal_id'] = $portal_id;
		
		$userQuery = "
            SELECT
                user_id
            FROM
                portal_alt_filers
            WHERE
                portal_user = :short_portal_id
                AND active = 1
                AND user_id NOT IN ('lkries')
            UNION
            SELECT
                user_id
            FROM
                portal_users
            WHERE
                user_id = :short_portal_id
            UNION
            SELECT
                user_id
            FROM
                portal_users
            WHERE
                portal_id = :real_portal_id
            LIMIT 1";
		
		$query_portal_id = str_replace("_15th", "", $portal_id);
		$query_portal_id = str_replace("med_", "", $query_portal_id);
		$query_portal_id = str_replace("tho_", "", $query_portal_id);
		
		$row = getDataOne($userQuery, $pdbh, array("short_portal_id" => $query_portal_id, "real_portal_id" => $portal_id));
		$user_id = $row['user_id'];
		$portal_args['user_id'] = $user_id;
		
		$nc3 = $$case_type->children($namespaces['nc']);
		$case_style = (string)$nc3->CaseTitleText;
		$portal_args['case_style'] = $case_style;
		
		$case_num = (string)$nc3->CaseTrackingID;
		$no_hyphens = str_replace("-", "", $case_num);
		$portal_args['case_num'] = $no_hyphens;
		
	    $portal_args['clerk_case_id'] = $case_num;
	    
	    $filing_id = $response->MessageReceiptMessage->DocumentIdentification[0]->IdentificationID->_;
	    $portal_args['filing_id'] = $filing_id;
	    $pending_args['filing_id'] = $filing_id;
	    
	    $portal_post_date = $response->MessageReceiptMessage->DocumentReceivedDate->DateTime->_;
	    $portal_args['portal_post_date'] = $portal_post_date;

	    # Start the transaction
	    $pdbh->AutoCommit = 0;
	
	    # First, insert the record into the portal_filings table
	    $query = " replace into
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
				    	status_dscr
				    )
				    values (
				    	:user_id,
	    				:portal_id,
	    				:filing_id,
	    				:case_num,
	    				:case_style,
	    				:clerk_case_id,
	    				NOW(),
	    				:portal_post_date,
	    				'Pending Filing',
	    				NOW(),
	    				'Pending Filing'
				    )";
	
	    doQuery($query, $pdbh, $portal_args);
	    
	    $nc4 = $fileXml->ReviewFilingRequestMessage->CoreFilingMessage->FilingLeadDocument->children($namespaces['nc']);
	    $ecf2 = $fileXml->ReviewFilingRequestMessage->CoreFilingMessage->FilingLeadDocument->children($namespaces['ecf']);
	    $nc5 = $ecf2->DocumentRendition->DocumentRenditionMetadata->children($namespaces['nc']);
	    
	    $file_name = (string)$nc5->DocumentFileControlID;
	    $pending_args['file_name'] = $file_name;
	    
	    $document_group = (string)$nc4->DocumentDescriptionText[1];
	    $pending_args['document_group'] = $document_group;
	    
	    $document_type = (string)$nc4->DocumentDescriptionText[2];
	    $pending_args['document_type'] = $document_type;
	    
	    $document_id = (string)$fileXml->ReviewFilingRequestMessage->CoreFilingMessage->FilingLeadDocument->attributes($namespaces['s'])->id;
	    $pending_args['document_id'] = $document_id;
	    
	    $ecf3 = $ecf2->DocumentRendition->DocumentRenditionMetadata->DocumentAttachment;
	    $attachment_id = (string)$ecf3->attributes($namespaces['s'])->id;
	    $pending_args['attachment_id'] = $attachment_id;
	    
	    $nc6 = $ecf3->children($namespaces['nc']);
	    $binary_size = (string)$nc6->BinarySizeValue;
	    $pending_args['binary_size'] = $binary_size;
	    
	    $base64_attachment = (string)$nc6->BinaryBase64Object;
	    $pending_args['base64_attachment'] = $base64_attachment;
	    
		$query = "
			    replace into
			    pending_filings (
				    filing_id,
				    file_name,
				    document_group,
				    document_type,
				    document_id,
				    attachment_id,
				   	binary_size,
				    base64_attachment
				)
				values (
				    :filing_id,
		    		:file_name,
		    		:document_group,
		    		:document_type,
		    		:document_id,
		    		:attachment_id,
		    		:binary_size,
		    		:base64_attachment
			    )";
		
		doQuery($query, $pdbh, $pending_args);
		
		//Now time for connected documents....
		$connected_file_args = array();
		$connected_file_args['filing_id'] = $filing_id;
		if(isset($fileXml->ReviewFilingRequestMessage->CoreFilingMessage->FilingConnectedDocument)){
			foreach($fileXml->ReviewFilingRequestMessage->CoreFilingMessage->FilingConnectedDocument as $c){
				$nc4 = $c->children($namespaces['nc']);
				$ecf2 = $c->children($namespaces['ecf']);
				$nc5 = $ecf2->DocumentRendition->DocumentRenditionMetadata->children($namespaces['nc']);
				
				$file_name = (string)$nc5->DocumentFileControlID;
				$connected_file_args['file_name'] = $file_name;
				
				$document_group = (string)$nc4->DocumentDescriptionText[1];
				$connected_file_args['document_group'] = $document_group;
				
				$document_type = (string)$nc4->DocumentDescriptionText[2];
				$connected_file_args['document_type'] = $document_type;
				
				$document_id = (string)$c->attributes($namespaces['s'])->id;
				$connected_file_args['document_id'] = $document_id;
				
				$ecf3 = $ecf2->DocumentRendition->DocumentRenditionMetadata->DocumentAttachment;
				$attachment_id = (string)$ecf3->attributes($namespaces['s'])->id;
				$connected_file_args['attachment_id'] = $attachment_id;
				
				$nc6 = $ecf3->children($namespaces['nc']);
				$binary_size = (string)$nc6->BinarySizeValue;
				$connected_file_args['binary_size'] = $binary_size;
				
				$base64_attachment = (string)$nc6->BinaryBase64Object;
				$connected_file_args['base64_attachment'] = $base64_attachment;
				
				$query = "
			    replace into
			    pending_filings (
				    filing_id,
				    file_name,
				    document_group,
				    document_type,
				    document_id,
				    attachment_id,
				   	binary_size,
				    base64_attachment
				)
				values (
				    :filing_id,
		    		:file_name,
		    		:document_group,
		    		:document_type,
		    		:document_id,
		    		:attachment_id,
		    		:binary_size,
		    		:base64_attachment
			    )";
				
				doQuery($query, $pdbh, $connected_file_args);
			}
		}
		
		$pdbh->commit;
    }
    
	print $client->__getLastResponse();

} catch (exception $e) {
    echo 'Caught exception: ',  $e->getMessage(), "\n";
    echo "Fault string: " . $e->faultstring . "\n\n";
    exit;
}


exit;


?>