<?php

# checkcase.php checks to see whether the case # passed it is valid
# it returns the properly formatted case # or ERROR.

require_once '../php-lib/db_functions.php';
require_once '../php-lib/common.php';

$ucn = getReqVal('ucn');

$db = "showcase-prod";
$dbh = dbConnect($db);
$schema = getDbSchema($db);
$where = "";

$case = sanitizeCaseNumber($ucn);
$case = $case[0];

$sd = getCaseDivAndStyle($case);
$style = $sd[1];

$result = array();
if(!empty($case)){
	$result['status'] = "Success";
	$result['CaseNumber'] = $case;
	$result['CaseStyle'] = $style;
}
else{
	$result['status'] = "Error";
}
returnJson($result);
exit;