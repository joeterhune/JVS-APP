<?php

require_once("/usr/local/icms-web/case/php-lib/db_functions.php");

$dbh = dbConnect("icms");
$sdbh = dbConnect("showcase-prod");

$query = "	SELECT DISTINCT casenum
			FROM olscheduling.case_emails
			WHERE casenum NOT LIKE '%-%'";

$results = array();
getData($results, $query, $dbh);

foreach($results as $r){
	$query2 = "
				SELECT CaseNumber
				FROM dbo.vCase
				WHERE UCN LIKE '50" . $r['casenum'] . "%'";
	
	$case_res = array();
	getData($case_res, $query2, $sdbh);
	
	$case_count = 0;
	if(!empty($case_res)){
		foreach($case_res as $cr){
			$case_count++;
		}
	}
	
	if($case_count == 1){
		$case_num = $case_res[0]['CaseNumber'];
		
		$query3 = "	UPDATE olscheduling.case_emails
					SET casenum = :casenum
					WHERE casenum = :old_casenum";
		
		doQuery($query3, $dbh, array("casenum" => $case_num, "old_casenum" => $r['casenum']));
	}
	else{
		echo "More than one case match (case_emails): " . $r['casenum'] . "\n";
	}
}

/*$query = "	SELECT DISTINCT casenum
			FROM olscheduling.case_parties";

$results = array();
getData($results, $query, $dbh);

foreach($results as $r){
	$query2 = "
				SELECT CaseNumber
				FROM dbo.vCase
				WHERE UCN LIKE '50" . $r['casenum'] . "%'";

	$case_res = array();
	getData($case_res, $query2, $sdbh);

	$case_count = 0;
	if(!empty($case_res)){
		foreach($case_res as $cr){
			$case_count++;
		}
	}

	if($case_count == 1){
		$case_num = $case_res[0]['CaseNumber'];

		$query3 = "	UPDATE olscheduling.case_parties
					SET casenum = :casenum
					WHERE casenum = :old_casenum";

		doQuery($query3, $dbh, array("casenum" => $case_num, "old_casenum" => $r['casenum']));
	}
	else{
		echo "More than one case match (case_parties): " . $r['casenum'] . "\n";
	}
}*/