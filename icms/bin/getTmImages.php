<?php
ini_set('soap.wsdl_cache_enabled', '0'); 
ini_set('soap.wsdl_cache_ttl', '0'); 

require('wse-php/soap-wsa.php');
require('wse-php/soap-wsse.php');
require_once('Smarty/Smarty.class.php');

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

# This file will contain an XML request to be sent directly to RetrieveCaseDocuments
$options = getopt("f:c:o:");

$data['user_id'] = 'SVCCTADMINSV';
$data['user_password'] = 'r3sbu64w9';

if (isset($options['f'])) {
    $file = $options['f'];
    if (!file_exists($file)) {
        exit;
    }
    $meta = file_get_contents($file);
} else if (isset($options['c'])) {
    $case = $options['c'];
    $template = "/var/jvs/icms/bin/RetrieveCaseDocs.tpl";
    $smarty = new Smarty();
    $data['casenum'] = $case;
    $smarty->assign('data', $data);
    $meta = $smarty->fetch($template);
} else if (isset($options['o'])) {
    $object = $options['o'];
    $template = "/var/jvs/icms/bin/RetrieveCaseDocs.tpl";
    $smarty = new Smarty();
    $data['objectid'] = $object;
    $smarty->assign('data', $data);
    $meta = $smarty->fetch($template);
}

$wsdl ="/var/jvs/conf/TrakMan.wsdl";

$sc = new mySoap($wsdl,array('trace' => 1,
                             "stream_context"=>
                             stream_context_create(
                                                   array(
                                                         "ssl"=>array(
                                                                      "verify_peer"=>true,
                                                                      "verify_peer_name" => false,
                                                                      "allow_self_signed"=>false,
                                                                      "ca_path" => "/etc/pki/tls/certs/ca1_clerk_local_new.pem"                                                                      
                                                                      )
                                                         )
                                                   )
                             )
                 );

try {
    $out = $sc->RetrieveCaseDocuments(array('metadata' => $meta));
    print $sc->__getLastResponse();
} catch (SoapFault $fault) {
    var_dump($fault);
}

