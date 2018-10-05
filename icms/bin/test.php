<?php
require('wse-php/soap-wsa.php');
require('wse-php/soap-wsse.php');

define('PRIVATE_KEY', '/etc/pki/tls/clientcerts/trakman_user.pem');
define('CERT_FILE', '/etc/pki/tls/clientcerts/trakman_user.pem');

class mySoap extends SoapClient {

   function __doRequest($request, $location, $saction, $version, $one_way = NULL) {
	  $dom = new DOMDocument();
	  $dom->loadXML($request);

	  $objWSA = new WSASoap($dom);

	  $dom = $objWSA->getDoc();

	  $objWSSE = new WSSESoap($dom);
	  /* Sign all headers to include signing the WS-Addressing headers */
	  $objWSSE->signAllHeaders = TRUE;

	  $objWSSE->addTimestamp();

	  /* create new XMLSec Key using RSA SHA-1 and type is private key */
	  $objKey = new XMLSecurityKey(XMLSecurityKey::RSA_SHA1, array('type'=>'private'));

	  /* load the private key from file - last arg is bool if key in file (TRUE) or is string (FALSE) */
	  $objKey->loadKey(PRIVATE_KEY, TRUE);

	  /* Sign the message - also signs appropraite WS-Security items */
	  $objWSSE->signSoapDoc($objKey,array('insertBefore' => 0));

	  /* Add certificate (BinarySecurityToken) to the message and attach pointer to Signature */
	  $token = $objWSSE->addBinaryToken(file_get_contents(CERT_FILE));
	  $objWSSE->attachTokentoSig($token);

	  $request = $objWSSE->saveXML();

	  return parent::__doRequest($request, $location, $saction, $version);
   }
}

$options = getopt("o:");
$obj_id = $options['o'];


# This file will contain an XML request to be sent directly to RetrieveCaseDocuments
$wsdl ="/var/jvs/conf/TrakMan.wsdl";

$sc = new mySoap($wsdl,array('trace' => 1,
                             "stream_context"=>
                             stream_context_create(
                                                   array(
                                                         "ssl"=>array(
                                                                      "verify_peer"=>true,
                                                                      "verify_peer_name" => false,
                                                                      "allow_self_signed"=>true,
                                                                      "ca_path" => "/etc/pki/tls/certs/ca1_clerk_local_new.pem"
                                                                      )
                                                         )
                                                   )
                             )
                 );

$case = '<?xml version="1.0"?><RetrieveCaseDocsInput xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://www.csisoft.com/2010/1.0/RetrieveCaseDocsInput.xsd"><UserID>SVCCTADMIN</UserID><Password>Ju90Pf</Password><CaseNumber>502013CT026921AXXXMB</CaseNumber><ObjectID xsi:nil="true" /><ReturnFilePath xsi:nil="true" /></RetrieveCaseDocsInput>';

$single = sprintf('<?xml version="1.0"?><RetrieveCaseDocsInput xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://www.csisoft.com/2010/1.0/RetrieveCaseDocsInput.xsd"><UserID>SVCCTADMIN</UserID><Password>Ju90Pf</Password><CaseNumber></CaseNumber><ObjectID>%s</ObjectID></RetrieveCaseDocsInput>', $obj_id);
$bogus = '<?xml version="1.0"?><RetrieveCaseDocsInput xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://www.csisoft.com/2010/1.0/RetrieveCaseDocsInput.xsd"><UserID>SVCCTADMIN</UserID><Password>Ju90Pf</Password><CaseNumber xsi:nil="true" /><ObjectID></ObjectID><ReturnFilePath xsi:nil="true" /></RetrieveCaseDocsInput>';
$multiple = '<?xml version="1.0"?><RetrieveCaseDocsInput xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://www.csisoft.com/2010/1.0/RetrieveCaseDocsInput.xsd"><UserID>SVCCTADMIN</UserID><Password>Ju90Pf</Password><CaseNumber xsi:nil="true" /><ObjectID>12609281,18134125</ObjectID><ReturnFilePath xsi:nil="true" /></RetrieveCaseDocsInput>';

try {
   $out = $sc->RetrieveCaseDocuments(array('metadata' => $single));
   print $sc->__getLastResponse();
} catch (SoapFault $fault) {
    var_dump($fault);
}
