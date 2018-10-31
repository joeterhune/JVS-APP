<?php
# checkcase.php checks to see whether the case # passed it is valid
# it returns the properly formatted case # or ERROR.
# it uses the /icms/find.cgi script
include_once("../php-lib/common.php");

$conf = simplexml_load_file($icmsXml);
$url = sprintf("%s/isValidCase", (string) $conf->{'icmsWebService'});

$ucn = getReqVal('ucn');

$fields = array(
    'casenum' => urlencode($ucn)
);
    
$return = curlJson($url, $fields);
$json = json_decode($return,true);

$result = array();
$result['status'] = "Success";
$result['CaseNumber'] = $json['CaseNumber'];

returnJson($result);
exit;

?>
