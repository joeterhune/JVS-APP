<?php

require_once("/usr/local/icms-web/case/php-lib/db_functions.php");

$config = simplexml_load_file("/usr/local/icms/etc/ICMS.xml");

//Submitted Orders
$query = "	SELECT order_id, ucn
			FROM olscheduling.submitted_orders
			WHERE division_id IS NULL";

$dbh = dbConnect("ols");
$sdbh = dbConnect("showcase-prod");

$results = array();
getData($results, $query, $dbh);

foreach($results as $r){
	
	if(strlen($r['ucn']) == 25){
		$query2 = "
					SELECT DivisionID
					FROM vCase
					WHERE CaseNumber = :case_number";
		
		$row = getDataOne($query2, $sdbh, array("case_number" => $r['ucn']));
	}
	else{
		$query2 = "
					SELECT DivisionID
					FROM vCase
					WHERE UCN LIKE '50" . $r['ucn'] . "%'";
		
		$row = getDataOne($query2, $sdbh);
	}
	
	if(!empty($row['DivisionID'])){
		$division = $row['DivisionID'];
		
		$query3 = "	UPDATE olscheduling.submitted_orders
					SET division_id = :division
					WHERE order_id = :id";
		
		doQuery($query3, $dbh, array("division" => $division, "id" => $r['order_id']));
	}
}

//User order templates
$query = "	SELECT order_id, ucn
			FROM olscheduling.user_order_templates
			WHERE division_id IS NULL";

$results = array();
getData($results, $query, $dbh);

foreach($results as $r){

	if(strlen($r['ucn']) == 25){
		$query2 = "
					SELECT DivisionID
					FROM vCase
					WHERE CaseNumber = :case_number";

		$row = getDataOne($query2, $sdbh, array("case_number" => $r['ucn']));
	}
	else{
		$query2 = "
					SELECT DivisionID
					FROM vCase
					WHERE UCN LIKE '50" . $r['ucn'] . "%'";

		$row = getDataOne($query2, $sdbh);
	}

	if(!empty($row['DivisionID'])){
		$division = $row['DivisionID'];

		$query3 = "	UPDATE olscheduling.user_order_templates
					SET division_id = :division
					WHERE order_id = :id";

		doQuery($query3, $dbh, array("division" => $division, "id" => $r['order_id']));
	}
}

//Drafts
$query = "	SELECT order_id, ucn
			FROM olscheduling.order_drafts
			WHERE division_id IS NULL";

$results = array();
getData($results, $query, $dbh);

foreach($results as $r){

	if(strlen($r['ucn']) == 25){
		$query2 = "
					SELECT DivisionID
					FROM vCase
					WHERE CaseNumber = :case_number";

		$row = getDataOne($query2, $sdbh, array("case_number" => $r['ucn']));
	}
	else{
		$query2 = "
					SELECT DivisionID
					FROM vCase
					WHERE UCN LIKE '50" . $r['ucn'] . "%'";

		$row = getDataOne($query2, $sdbh);
	}

	if(!empty($row['DivisionID'])){
		$division = $row['DivisionID'];

		$query3 = "	UPDATE olscheduling.order_drafts
					SET division_id = :division
					WHERE order_id = :id";

		doQuery($query3, $dbh, array("division" => $division, "id" => $r['order_id']));
	}
}

//Now do watchlist....

$query = "	SELECT casenum
			FROM watchlist
			WHERE division_id IS NULL";

$dbh = dbConnect("icms");

$results = array();
getData($results, $query, $dbh);

foreach($results as $r){

	$query2 = "
				SELECT DivisionID
				FROM vCase
				WHERE CaseNumber = :case_number";

	$row = getDataOne($query2, $sdbh, array("case_number" => $r['casenum']));

	if(!empty($row['DivisionID'])){
		$division = $row['DivisionID'];

		$query3 = "	UPDATE watchlist
					SET division_id = :division
					WHERE casenum = :casenum";

		doQuery($query3, $dbh, array("division" => $division, "casenum" => $r['casenum']));
	}
}

$dbh = dbConnect("ols");

//Now do supporting_documents
$query = "	SELECT event_cases_id,
			supporting_doc_id
			FROM olscheduling.supporting_documents
			WHERE event_cases_id IS NOT NULL
			AND case_number IS NULL";

$results = array();
getData($results, $query, $dbh);

foreach($results as $r){
	$dbh = dbConnect("vrb2");
	$query2 = " SELECT case_num
				FROM event_cases
				WHERE event_cases_id = :ec_id";
	
	$row = getDataOne($query2, $dbh, array("ec_id" => $r['event_cases_id']));
	
	if(!empty($row['case_num'])){
		$query3 = "	SELECT CaseNumber
					FROM vCase
					WHERE UCN LIKE '50" . $row['case_num'] . "%'";
		
		$row2 = getDataOne($query3, $sdbh);
		
		$dbh = dbConnect("ols");
		
		if(!empty($row2['CaseNumber'])){
			$query4 = "	UPDATE olscheduling.supporting_documents
						SET case_number = :case_number
						WHERE event_cases_id = :event_cases_id";
			
			doQuery($query4, $dbh, array("case_number" => $row2['CaseNumber'], "event_cases_id" => $r['event_cases_id']));
		}
	}
}

$dbh = dbConnect("ols");

// And again
$query = "	SELECT submitted_order_id
			FROM olscheduling.supporting_documents
			WHERE submitted_order_id IS NOT NULL
			AND case_number IS NULL";

$results = array();
getData($results, $query, $dbh);

foreach($results as $r){
	$query2 = " SELECT ucn
				FROM olscheduling.submitted_orders
				WHERE order_id = :order_id";

	$row = getDataOne($query2, $dbh, array("order_id" => $r['submitted_order_id']));

	if(!empty($row['ucn'])){
		$query3 = "	SELECT CaseNumber
					FROM vCase
					WHERE UCN LIKE '50" . $row['ucn'] . "%'
					OR CaseNumber = :ucn";

		$row2 = getDataOne($query3, $sdbh, array("ucn" => $row['ucn']));

		if(!empty($row2['CaseNumber'])){
			$query4 = "	UPDATE olscheduling.supporting_documents
						SET case_number = :case_number
						WHERE submitted_order_id = :order_id";
				
			doQuery($query4, $dbh, array("case_number" => $row2['CaseNumber'], "order_id" => $r['submitted_order_id']));
		}
	}
}

//Now get the divisions...

$query = "	SELECT case_number
			FROM olscheduling.supporting_documents
			WHERE division_id IS NULL
			AND case_number IS NOT NULL";

$results = array();
getData($results, $query, $dbh);

foreach($results as $r){

	$query2 = "
				SELECT DivisionID
				FROM vCase
				WHERE CaseNumber = :case_number";

	$row = getDataOne($query2, $sdbh, array("case_number" => $r['case_number']));

	if(!empty($row['DivisionID'])){
		$division = $row['DivisionID'];

		$query3 = "	UPDATE olscheduling.supporting_documents
					SET division_id = :division
					WHERE case_number = :casenum";

		doQuery($query3, $dbh, array("division" => $division, "casenum" => $r['case_number']));
	}
}

// And do the styles

//Now get the divisions...

$query = "	SELECT case_number
			FROM olscheduling.supporting_documents
			WHERE case_style IS NULL
			AND case_number IS NOT NULL";

$results = array();
getData($results, $query, $dbh);

foreach($results as $r){

	$query4 = "
				SELECT CaseStyle
				FROM vCase
				WHERE CaseNumber = :case_number";

	$row = getDataOne($query4, $sdbh, array("case_number" => $r['case_number']));

	if(!empty($row['CaseStyle'])){
		$case_style = $row['CaseStyle'];

		$query5 = "	UPDATE olscheduling.supporting_documents
					SET case_style = :case_style
					WHERE case_number = :casenum";

		doQuery($query5, $dbh, array("case_style" => $case_style, "casenum" => $r['case_number']));
	}
}