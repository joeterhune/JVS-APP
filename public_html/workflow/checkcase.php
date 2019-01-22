<?php
# checkcase.php checks to see whether the case # passed it is valid
# it returns the properly formatted case # or ERROR.
# it uses the /icms/find.cgi script
include_once("../php-lib/common.php");
# modified 11/26/2018 jmt switching from api to direct call
require_once("../php-lib/db_functions.php");

#$conf = simplexml_load_file($icmsXml);
#$url = sprintf("%s/isValidCase", (string) $conf->{'icmsWebService'});

$ucn = getReqVal('ucn');
list($casenum,$type) = sanitizeCaseNumber($ucn);
#$fields = array(
#    'casenum' => urlencode($ucn)
#);
    
#$return = curlJson($url, $fields);
#$json = json_decode($return,true);

$result = array();
$result['status'] = "Success";
$result['CaseNumber'] = $casenum;
#$result['CaseNumber'] = $json['CaseNumber'];

returnJson($result);
exit;

?>
