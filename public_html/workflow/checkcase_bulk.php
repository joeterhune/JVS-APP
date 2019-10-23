<?php

# checkcase_bulk.php checks to see whether the case # passed it is valid
# it returns the properly formatted case # or ERROR.

require_once '../php-lib/db_functions.php';
require_once '../php-lib/common.php';

$cases = getReqVal('cases');

$db = "showcase-prod";
$dbh = dbConnect($db);
$schema = getDbSchema($db);

$caseList = explode("\n", $cases);
$goodCaseList = array();
$goodStyleList = array();

if(!empty($caseList)){
	foreach($caseList as $ucn){
		$case = sanitizeCaseNumber($ucn);
		$case = $case[0];
		
		$sd = getCaseDivAndStyle($case);
		$style = $sd[1];
		
		if(!empty($case)){
			$goodCaseList[] = $case;
			$goodStyleList[] = $style;
		}
	}
}


$result = array();
if(!empty($goodCaseList)){
	$result['status'] = "Success";
	$result['CaseList'] = $goodCaseList;
	$result['StyleList'] = $goodStyleList;
}
else{
	$result['status'] = "Error";
}
returnJson($result);
exit;