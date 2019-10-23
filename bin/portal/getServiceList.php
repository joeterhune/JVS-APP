<?php

require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/common.php");

$config = simplexml_load_file($icmsXml);

if (isset($config->{'serviceListWsdl'})) {
    $wsdl = (string) $config->{'serviceListWsdl'};
} else {
    $wsdl = $_SERVER['JVS_ROOT'] . '/conf/ElectronicServiceListService-PROD.wsdl';
}

$options = getopt('u:x');
if (!isset($options['u'])) {
    echo "You must specify a UCN\n\n";
    exit;
}
$ucn = $options['u'];
$showXML = 0;
if (isset($options['x'])) {
    $showXML = 1;
}


try {
    $client = new SoapClient($wsdl, array('cache_wsdl' => 0, 'trace' => 1));
    
    $query = new StdClass();
    $query->request = new StdClass();
    $query->request->LogonName = "foo";
    $query->request->PassWord = "bar";
    $query->request->UniformCaseNumber = $ucn;
    $query->request->CaseId = -1;
    $query->request->UserID = 59706;
    // Set an ISO 8601 format date
    $query->request->RequestTime = date('c');
    $query->request->UserOrganizationID_x0020_ = 10;
    
    $response = $client->GetElectronicServiceListCase($query);
    
    if ($showXML) {
        echo $client->__getLastResponse() . "\n\n";
        exit;
    }
} catch (exception $e) {
    echo 'Caught exception: ',  $e->getMessage(), "\n";
    echo "Fault string: " . $e->faultstring . "\n\n";
    exit;
}

file_put_contents ('request.xml', $client->__getLastRequest());

file_put_contents ('response.xml', $client->__getLastResponse());


if ($response->GetElectronicServiceListCaseResult->OperationSuccessful) {
    if (isset($response->GetElectronicServiceListCaseResult->ElectronicServiceListCase)) {
        $serviceList = $response->GetElectronicServiceListCaseResult->ElectronicServiceListCase;
        
        $filers = array();
        
        // Do a little data massaging so everything can be treated the same later
        $type = gettype($serviceList->Filers);
        
        if ($type == "object") {
            array_push($filers, $serviceList->Filers);
        } else {
            $filers = $serviceList->Filers;
        }
        
        foreach ($filers as $filer) {
            if (!$filer->ShowOnMyCases) {
                continue;
            }
            print "Name: " . $filer->Name . "\n";
            foreach (array('PrimaryEmailAddress', 'AlternateEmailAddress1', 'AlternateEmailAddress2') as $addrType) {
                if (isset($filer->$addrType)) {
                    print "\t$addrType: " . $filer->$addrType . "\n";
                }
            }
            print "\n";
        }
    } else {
        print "No filers were found.\n";
    }
}

?>