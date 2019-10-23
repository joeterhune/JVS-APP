<?php 

require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/common.php");
require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/db_functions.php");
require_once("Smarty/Smarty.class.php");

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);

$case_number = getReqVal('case_number');

$config = simplexml_load_file($_SERVER['JVS_ROOT'] . "/conf/ICMS.xml");
$sc_db = (string)$config->{'showCaseDb'};

$dbh = dbConnect($sc_db);

$casenum = strtoupper($case_number);
if (preg_match("/^(\d{1,6})(\D\D)(\d{0,6})(.*)/", $casenum, $matches)) {
	$year = $matches[1];
	$type = $matches[2];
	$seq = $matches[3];
	$suffix = $matches[4];

	# If we have a 2-digit year, adjust it (we'll use 60 as the split point)
	if ($year < 100) {
		if ($year > 60) {
			$year = sprintf("19%02d", $year);
		} else {
			$year = sprintf("20%02d", $year);
		}
	}
	
	if(strlen($casenum) < 12){
		$casenum = $year . $type . str_pad($seq, 6, "0", STR_PAD_LEFT);
	}
}

$case_number = $casenum;
//Let's get the case ID first
if(substr($case_number, 0, 2) == "50"){
	$regex = '/^50-[0-9]{4}-[A-Z]{2}-[0-9]{6}-[A-Z]{4}-[A-Z]{2}$/';
	if (preg_match($regex, $case_number)) {
    	$where = " CaseNumber = '$case_number'";
    }
    else{
    	$case_number = str_replace("-", "", $case_number);
    	$where = " UCN LIKE '%$case_number%' ";
    }
}
else{
  	$case_number = str_replace("-", "", $case_number);
  	$regex = '/^[0-9]{4}[A-Z]{2}[0-9]{6}$/';
  	if (preg_match($regex, $case_number)) {
	    $where = " LegacyCaseNumber = '$case_number' OR UCN LIKE '50$case_number%' ";
	}
	else{
		$where = " LegacyCaseNumber LIKE '%$case_number%' OR UCN LIKE '%$case_number%'";
   	}
}

$query = " 	SELECT CaseID,
			CaseNumber
	    	FROM vCase
	    	WHERE $where";

$caseRow = getDataOne($query, $dbh, array("case_number" => $case_number));
$case_id = $caseRow['CaseID'];
$case_number = $caseRow['CaseNumber'];

//Get SC related cases first
$caseList = array();
$sc_results = array();
$query = "	SELECT
				CASE WHEN ToCaseID = :case_id
					THEN FromCaseID
					ELSE ToCaseID
				END AS ToCaseID
			FROM
			   vLinkedCases l with(nolock)
			where
			    FromCaseID = :case_id
			    OR ToCaseID = :case_id";

getData($sc_results, $query, $dbh, array("case_id" => $case_id));

if(!empty($sc_results)){
	foreach($sc_results as $r){
		$caseList[] = $r['ToCaseID'];
	}
}

$results = array();
$query = "	SELECT CaseNumber,
				PartyType,
				PartyTypeDescription,
				FirstName,
				MiddleName,
				LastName,
				DOB,
				Sex,
				PersonID,
				CaseID
			FROM 
				vAllParties
			WHERE 
				CaseID = :case_id
			AND 
				PartyType NOT IN ('ATTY', 'JUDG')
			ORDER BY DOB DESC";

getData($results, $query, $dbh, array("case_id" => $case_id));

$childCount = 1;
$fatherCount = 1;
$children = array();
$fathers = array();
$mother = array();
foreach($results as $r){
	if($r['PartyType'] == 'CHLD' || ($r['PartyTypeDescription'] == 'CHILD (CJ)') || ($r['PartyTypeDescription'] == 'CHILD')){
		$children[$childCount]['FirstName'] = $r['FirstName'];
		$children[$childCount]['MiddleName'] = $r['MiddleName'];
		$children[$childCount]['LastName'] = $r['LastName'];
		$children[$childCount]['DOB'] = date("m/d/Y", strtotime($r['DOB']));
		$children[$childCount]['sqlDOB'] = date("Y-m-d", strtotime($r['DOB']));
		$children[$childCount]['Sex'] = $r['Sex'];
		$children[$childCount]['PersonID'] = $r['PersonID'];
		
		$interval = date_diff(date_create(), date_create($r['DOB']));
		$children[$childCount]['Age'] = $interval->format("%y years, %m months");
		$childCount++;
	}
	else if($r['PartyType'] == 'FTH' || ($r['PartyTypeDescription'] == 'FATHER')){
		$fathers[$fatherCount]['FirstName'] = $r['FirstName'];
		$fathers[$fatherCount]['MiddleName'] = $r['MiddleName'];
		$fathers[$fatherCount]['LastName'] = $r['LastName'];
		//$fathers[$fatherCount]['DOB'] = date("m/d/Y", strtotime($r['DOB']));
		//$fathers[$fatherCount]['Sex'] = $r['Sex'];
		$fathers[$fatherCount]['PersonID'] = $r['PersonID'];
		$fatherCount++;
	}
	else if($r['PartyType'] == 'MTH' || ($r['PartyTypeDescription'] == 'MOTHER')){
		$mother['FirstName'] = $r['FirstName'];
		$mother['MiddleName'] = $r['MiddleName'];
		$mother['LastName'] = $r['LastName'];
		//$mother['DOB'] = date("m/d/Y", strtotime($r['DOB']));
		//$mother['Sex'] = $r['Sex'];
		$mother['PersonID'] = $r['PersonID'];
	}
}

$case_plans = array();
$results = array();
$query = "	SELECT DocketCode,
				CaseNumber,
				CaseID,
				UCN,
				ObjectID,
				EffectiveDate,
				EnteredDate,
				DocketDescription,
				SeqPos
			FROM
				vDocket
			WHERE
				CaseID = :case_id
			AND
				 ( 
					DocketCode = 'CPLN' 
					OR DocketDescription = 'Case Plan'
				)
			ORDER BY EnteredDate";

getData($results, $query, $dbh, array("case_id" => $case_id));

$cpCount = 0;
if(count($results) > 0){
	foreach($results as $r){
		$case_plans[$cpCount]['DocketCode'] = $r['DocketCode'];
		$case_plans[$cpCount]['CaseNumber'] = $r['CaseNumber'];
		$case_plans[$cpCount]['CaseID'] = $r['CaseID'];
		$case_plans[$cpCount]['UCNObj'] = $r['UCN'] . "|" . $r['ObjectID'];
		$case_plans[$cpCount]['EffectiveDate'] = date("m/d/Y", strtotime($r['EffectiveDate']));
		$case_plans[$cpCount]['EnteredDate'] = date("m/d/Y", strtotime($r['EnteredDate']));
		$case_plans[$cpCount]['DocketDescription'] = $r['DocketDescription'];
		$case_plans[$cpCount]['SeqPos'] = $r['SeqPos'];
		$case_plans[$cpCount]['ObjectID'] = $r['ObjectID'];
		$cpCount++;
	}
}

//Now let's check our own data....
$idbh = dbConnect("icms");

//Case Info
$query = "	SELECT *
		  	FROM case_management.juv_case_info
			WHERE case_id = :case_id";

$ciRow = getDataOne($query, $idbh, array("case_id" => $case_id));

if(!empty($ciRow)){
	$cls_attorney = $ciRow['cls_attorney_name'];
	$gal_name = $ciRow['gal_name'];
	$gal_attorney = $ciRow['gal_attorney_name'];
	$dcm_name = $ciRow['dcm_name'];
}
else{
	$cls_attorney = "";
	$gal_name = "";
	$gal_attorney = "";
	$dcm_name = "";
}

$cp_res = array();
//Case Plan
$query = "	SELECT *
			FROM case_management.juv_case_plans
			WHERE case_id = :case_id";

getData($cp_res, $query, $idbh, array("case_id" => $case_id));

if(count($case_plans) > 0){
	foreach($case_plans as $key => $c){
		if(count($cp_res) > 0){
			foreach($cp_res as $r){
				
				$rcps = array();
				$rcp_res = array();
				$query = "	SELECT person_id
							FROM case_management.juv_related_case_plans
							WHERE case_id = :case_id
							AND case_plan_id = :cp_id";
					
				getData($rcp_res, $query, $idbh, array("case_id" => $case_id, "cp_id" => $r['juv_case_plan_id']));

				if(count($rcp_res) > 0){
					foreach($rcp_res as $re){
						$rcps[] = $re['person_id'];
					}
				}
			
			
				if($c['ObjectID'] == $r['trakman_object_id']){
					if(empty($r['executed']) && strlen($r['executed']) < 1){
						$case_plans[$key]['executed'] = "";
					}
					else if($r['executed'] == '1'){
						$case_plans[$key]['executed'] = "Yes";
					}
					else{
						$case_plans[$key]['executed'] = "No";
					}
					
					if(empty($r['executed_date']) || ($r['executed_date'] == "0000-00-00")){
						$case_plans[$key]['executed_date'] = "";
					}
					else{
						$case_plans[$key]['executed_date'] = date("m/d/Y", strtotime($r['executed_date']));
					}
					
					if(empty($r['goal_date']) || ($r['goal_date'] == "0000-00-00")){
						$case_plans[$key]['goal_date'] = "";
					}
					else{
						$case_plans[$key]['goal_date'] = date("m/d/Y", strtotime($r['goal_date']));
					}
					
					if(empty($r['order_date']) || ($r['order_date'] == "0000-00-00")){
						$case_plans[$key]['order_date'] = "";
					}
					else{
						$case_plans[$key]['order_date'] = date("m/d/Y", strtotime($r['order_date']));
					}
					
					$case_plans[$key]['relates_to'] = $rcps;
				
				}
			}
		}
	}
}

$oCount = 0;
$orders = array();
$o_res = array();
//Orders
$query = "	SELECT *
			FROM case_management.juv_orders
			WHERE case_id = :case_id
			AND completed = 0";

getData($o_res, $query, $idbh, array("case_id" => $case_id));

if(!empty($o_res)){
	foreach($o_res as $or){
		$orders[$oCount]['completed'] = $or['completed'];
		
		if(empty($or['completed_date']) || ($or['completed_date'] == "0000-00-00")){
			$orders[$oCount]['completed_date'] = "";
		}
		else{
			$orders[$oCount]['completed_date'] = date("m/d/Y", strtotime($or['due_date']));
		}
		
		$orders[$oCount]['juv_order_id'] = $or['juv_order_id'];
		$orders[$oCount]['order_title'] = $or['order_title'];
		
		if(empty($or['due_date']) || ($or['due_date'] == "0000-00-00")){
			$orders[$oCount]['due_date'] = "";
		}
		else{
			$orders[$oCount]['due_date'] = date("m/d/Y", strtotime($or['due_date']));
		}
		
		if(empty($or['order_date']) || ($or['order_date'] == "0000-00-00")){
			$orders[$oCount]['order_date'] = "";
		}
		else{
			$orders[$oCount]['order_date'] = date("m/d/Y", strtotime($or['order_date']));
		}
		
		$forRes = array();
		$forQuery = "SELECT *
					 FROM case_management.juv_order_parties
					 WHERE juv_order_id = :order_id";
		
		getData($forRes, $forQuery, $idbh, array("order_id" => $or['juv_order_id']));
		
		if(!empty($forRes)){
			$ordersFor = array();
			foreach($forRes as $f){
				$ordersFor[] = $f['person_id'];
			}
			
			$orders[$oCount]['order_for'] = $ordersFor;
		}
		
		$oCount++;
	}
}

$poCount = 0;
$previousOrders = array();
$po_res = array();
//Previous Orders
$prevQuery = "	SELECT *
			FROM case_management.juv_orders
			WHERE case_id = :case_id
			AND completed = 1";

getData($po_res, $prevQuery, $idbh, array("case_id" => $case_id));

if(!empty($po_res)){
	foreach($po_res as $or){
		$previousOrders[$poCount]['completed'] = $or['completed'];

		if(empty($or['completed_date']) || ($or['completed_date'] == "0000-00-00")){
			$previousOrders[$poCount]['completed_date'] = "";
		}
		else{
			$previousOrders[$poCount]['completed_date'] = date("m/d/Y", strtotime($or['due_date']));
		}

		$previousOrders[$poCount]['juv_order_id'] = $or['juv_order_id'];
		$previousOrders[$poCount]['order_title'] = $or['order_title'];

		if(empty($or['due_date']) || ($or['due_date'] == "0000-00-00")){
			$previousOrders[$poCount]['due_date'] = "";
		}
		else{
			$previousOrders[$poCount]['due_date'] = date("m/d/Y", strtotime($or['due_date']));
		}

		if(empty($or['order_date']) || ($or['order_date'] == "0000-00-00")){
			$previousOrders[$poCount]['order_date'] = "";
		}
		else{
			$previousOrders[$poCount]['order_date'] = date("m/d/Y", strtotime($or['order_date']));
		}

		$forRes = array();
		$forQuery = "SELECT *
					 FROM case_management.juv_order_parties
					 WHERE juv_order_id = :order_id";

		getData($forRes, $forQuery, $idbh, array("order_id" => $or['juv_order_id']));

		if(!empty($forRes)){
			$ordersFor = array();
			foreach($forRes as $f){
				$ordersFor[] = $f['person_id'];
			}
				
			$previousOrders[$poCount]['order_for'] = $ordersFor;
		}

		$poCount++;
	}
}

$results = array();
$notes = array();
//Event Notes
$query = "	SELECT *
			FROM case_management.juv_event_notes
			WHERE case_id = :case_id";

getData($results, $query, $idbh, array("case_id" => $case_id));

$count = 0;
if(!empty($results)){
	foreach($results as $r){
		$notes[$count]['note_id'] = $r['juv_event_note_id'];
		$notes[$count]['event_date'] = date("m/d/Y", strtotime($r['event_date']));
		$notes[$count]['note'] = $r['event_note'];
		$notes[$count]['created_by'] = $r['created_user'];
		$count++;
	}
}

//Children 
$query = "	SELECT c.father_person_id,
			c.father_name,
			c.type_of_father,
			c.child_where,
			c.child_with,
			c.child_address,
			c.date_placed,
			CASE 
				WHEN c.home_study_ind = 1
				THEN 'Yes'
				WHEN c.home_study_ind = 0
					THEN 'No'
				ELSE NULL
			END AS home_study_ind,
			c.home_study_approved_date,
			c.home_study_filed_date,
		 	CASE 
				WHEN c.tico = 1
				THEN 'Yes'
				WHEN c.tico = 0
					THEN 'No'
				ELSE NULL
			END AS tico,
			c.person_id,
			c.notes
			FROM case_management.juv_children c
			LEFT OUTER JOIN case_management.juv_fathers f
			ON c.case_id = f.case_id
			AND ( c.person_id = f.person_id
			OR c.father_name = f.father_name)
			WHERE c.case_id = :case_id";

$results = array();
getData($results, $query, $idbh, array("case_id" => $case_id));

if(!empty($results)){
	foreach($results as $r){
		foreach($children as $key => $c){
			if($c['PersonID'] == $r['person_id']){
				
				$children[$key]['FatherPersonID'] = $r['father_person_id'];
				$children[$key]['FatherName'] = $r['father_name'];
				$children[$key]['type_of_father'] = $r['type_of_father'];
				$children[$key]['ChildWhere'] = $r['child_where'];
				$children[$key]['ChildWith'] = $r['child_with'];
				$children[$key]['child_address'] = $r['child_address'];
				
				if(!empty($r['date_placed']) && ($r['date_placed'] != "0000-00-00")){
					$date_placed = date("m/d/Y", strtotime($r['date_placed']));
				}
				else{
					$date_placed = "";
				}
				
				$children[$key]['date_placed'] = $date_placed;
				$children[$key]['home_study_ind'] = $r['home_study_ind'];
				
				if(!empty($r['home_study_approved_date']) && ($r['home_study_approved_date'] != "0000-00-00")){
					$home_study_approved_date = date("m/d/Y", strtotime($r['home_study_approved_date']));
				}
				else{
					$home_study_approved_date = "";
				}
				
				if(!empty($r['home_study_filed_date']) && ($r['home_study_filed_date'] != "0000-00-00")){
					$home_study_filed_date = date("m/d/Y", strtotime($r['home_study_filed_date']));
				}
				else{
					$home_study_filed_date = "";
				}
				
				$children[$key]['home_study_approved_date'] = $home_study_approved_date;
				$children[$key]['home_study_filed_date'] = $home_study_filed_date;
				$children[$key]['TICO'] = $r['tico'];
				$children[$key]['notes'] = $r['notes'];
			}
		}
	}
}

//Do separately because we may not have data about the child yet
foreach($children as $key => $c){
	//Get the child's attorneys
	$query = "SELECT attorney_type,
					attorney_name,
					CASE WHEN active = 1
						THEN 'Yes'
					ELSE 'No'
					END as active,
					juv_attorney_id
					FROM case_management.juv_attorneys
					WHERE case_id = :case_id
					AND person_id = :person_id";

	$attorneyRes = array();
	getData($attorneyRes, $query, $idbh, array("case_id" => $case_id, "person_id" => $c['PersonID']));
	if(!empty($attorneyRes)){
		foreach($attorneyRes as $a){
			$atty = array();
			$atty['attorney_type'] = $a['attorney_type'];
			$atty['attorney_name'] = $a['attorney_name'];
			$atty['attorney_active'] = $a['active'];
			$atty['attorney_id'] = $a['juv_attorney_id'];
			$children[$key]['attorneys'][] = $atty;
		}
	}
	
	//Get the child's special identifiers
	$query = "SELECT identifier_desc
				FROM case_management.juv_identifiers
				WHERE case_id = :case_id
				AND person_id = :person_id";
	
	$identifierRes = array();
	getData($identifierRes, $query, $idbh, array("case_id" => $case_id, "person_id" => $c['PersonID']));
	if(!empty($identifierRes)){
		foreach($identifierRes as $i){
			$children[$key]['special_identifiers'][] = $i['identifier_desc'];
		}
	}
	
	$children[$key]['special_identifiers_string'] = implode(", ", $children[$key]['special_identifiers']);
}

//Psych meds
foreach($children as $key => $c){
	//Get the child's attorneys
	$query = "SELECT psych_meds_requested_by,
					psych_meds_requested_date,
					CASE 
						WHEN psych_meds_affidavit_ind = 1
						THEN 'Yes'
						ELSE 'No'
					END as psych_meds_affidavit_ind,
					psych_meds_order_ind,
					psych_meds_order_date,
					psych_meds_trakman_object_id,
					psych_meds,
					juv_psych_meds_id
					FROM case_management.juv_psych_meds
					WHERE case_id = :case_id
					AND person_id = :person_id";

	$psychMedRes = array();
	getData($psychMedRes, $query, $idbh, array("case_id" => $case_id, "person_id" => $c['PersonID']));
	if(!empty($psychMedRes)){
		foreach($psychMedRes as $m){
			$meds = array();
			$meds['psych_meds_requested_by'] = $m['psych_meds_requested_by'];
			
			if(!empty($m['psych_meds_requested_date']) && ($m['psych_meds_requested_date'] != "0000-00-00")){
				$med_req_date = date("m/d/Y", strtotime($m['psych_meds_requested_date']));
			}
			else{
				$med_req_date = "";
			}
			
			$meds['psych_meds_requested_date'] = $med_req_date;
			$meds['psych_meds_affidavit_filed'] = $m['psych_meds_affidavit_ind'];
			$meds['psych_meds_order_filed'] = $m['psych_meds_order_ind'];
			
			if(!empty($m['psych_meds_order_date']) && ($m['psych_meds_order_date'] != "0000-00-00")){
				$med_order_date = date("m/d/Y", strtotime($m['psych_meds_order_date']));
			}
			else{
				$med_order_date = "";
			}
			
			$meds['psych_meds_order_date'] = $med_order_date;
			$meds['object_id'] = $m['psych_meds_trakman_object_id'];
			$meds['psych_meds'] = $m['psych_meds'];
			$meds['pm_id'] = $m['juv_psych_meds_id'];
			
			$children[$key]['psych_meds'][] = $meds;
		}
	}
}

//Father
$query = "	SELECT CASE 
				WHEN f.offending = 1
				THEN 'Yes'
				WHEN f.offending = 0
					THEN 'No'
				ELSE NULL
			END AS offending,
			CASE 
				WHEN in_custody_ind = 1
				THEN 'Yes'
				WHEN in_custody_ind = 0
					THEN 'No'
				ELSE NULL
			END AS in_custody_ind,
			in_custody_where,
			CASE 
				WHEN no_contact_order = 1
				THEN 'Yes'
				WHEN no_contact_order = 0
					THEN 'No'
				ELSE NULL
			END AS no_contact_ind,
			no_contact_entered,
			no_contact_vacated,
			recom,
			f.shelter_dos,
			f.dependency_dos,
			f.supp_findings_dos,
			f.tpr_dos,
			f.arraignment_dos,
			f.shelter_order_filed,
			f.dependency_order_filed,
			f.supp_findings_order_filed,
			f.tpr_order_filed,
			f.arraignment_order_filed,
			f.person_id,
			f.father_name
			FROM case_management.juv_fathers f
			WHERE case_id = :case_id";

$results = array();
getData($results, $query, $idbh, array("case_id" => $case_id));

foreach($results as $r){
	$fatherExists = false;
	foreach($fathers as $key => $f){
		if($f['PersonID'] == $r['person_id']){
			$fathers[$key]['Offending'] = $r['offending'];
			$fathers[$key]['in_custody_ind'] = $r['in_custody_ind'];
			$fathers[$key]['in_custody_where'] = $r['in_custody_where'];
			$fathers[$key]['no_contact_ind'] = $r['no_contact_ind'];
	
			//Get no contact with
			$no_contact_with = array();
			$query = "	SELECT no_contact_with_person_id
							FROM case_management.juv_no_contact_parties
							WHERE case_id = :case_id
							AND person_id = :person_id";
	
			$nc_res = array();
			getData($nc_res, $query, $idbh, array("case_id" => $case_id, "person_id" => $f['PersonID']));
	
			if(count($nc_res) > 0){
				foreach($nc_res as $re){
					$no_contact_with[] = $re['no_contact_with_person_id'];
				}
			}
	
			$fathers[$key]['no_contact_with'] = $no_contact_with;
			if(!empty($r['no_contact_entered']) && ($r['no_contact_entered'] != "0000-00-00")){
				$no_contact_entered = date("m/d/Y", strtotime($r['no_contact_entered']));
			}
			else{
				$no_contact_entered = "";
			}
			$fathers[$key]['no_contact_entered'] = $no_contact_entered;
	
			if(!empty($r['no_contact_vacated']) && ($r['no_contact_vacated'] != "0000-00-00")){
				$no_contact_vacated = date("m/d/Y", strtotime($r['no_contact_vacated']));
			}
			else{
				$no_contact_vacated = "";
			}
			$fathers[$key]['no_contact_vacated'] = $no_contact_vacated;
	
			$fathers[$key]['recom'] = $r['recom'];
			if(!empty($r['shelter_dos']) && ($r['shelter_dos'] != "0000-00-00")){
				$shelter_dos = date("m/d/Y", strtotime($r['shelter_dos']));
			}
			else{
				$shelter_dos = "";
			}
			$fathers[$key]['shelter_dos'] = $shelter_dos;
	
			if(!empty($r['dependency_dos']) && ($r['dependency_dos'] != "0000-00-00")){
				$dependency_dos = date("m/d/Y", strtotime($r['dependency_dos']));
			}
			else{
				$dependency_dos = "";
			}
			$fathers[$key]['dependency_dos'] = $dependency_dos;
	
			if(!empty($r['supp_findings_dos']) && ($r['supp_findings_dos'] != "0000-00-00")){
				$supp_findings_dos = date("m/d/Y", strtotime($r['supp_findings_dos']));
			}
			else{
				$supp_findings_dos = "";
			}
			$fathers[$key]['supp_findings_dos'] = $supp_findings_dos;
	
			if(!empty($r['tpr_dos']) && ($r['tpr_dos'] != "0000-00-00")){
				$tpr_dos = date("m/d/Y", strtotime($r['tpr_dos']));
			}
			else{
				$tpr_dos = "";
			}
			$fathers[$key]['tpr_dos'] = $tpr_dos;
	
			if(!empty($r['arraignment_dos']) && ($r['arraignment_dos'] != "0000-00-00")){
				$arraignment_dos = date("m/d/Y", strtotime($r['arraignment_dos']));
			}
			else{
				$arraignment_dos = "";
			}
			$fathers[$key]['arraignment_dos'] = $arraignment_dos;
	
			if(!empty($r['shelter_order_filed']) && ($r['shelter_order_filed'] != "0000-00-00")){
				$shelter_order_filed = date("m/d/Y", strtotime($r['shelter_order_filed']));
			}
			else{
				$shelter_order_filed = "";
			}
			$fathers[$key]['shelter_order_filed'] = $shelter_order_filed;
	
			if(!empty($r['dependency_order_filed']) && ($r['dependency_order_filed'] != "0000-00-00")){
				$dependency_order_filed = date("m/d/Y", strtotime($r['dependency_order_filed']));
			}
			else{
				$dependency_order_filed = "";
			}
			$fathers[$key]['dependency_order_filed'] = $dependency_order_filed;
	
			if(!empty($r['supp_findings_order_filed']) && ($r['supp_findings_order_filed'] != "0000-00-00")){
				$supp_findings_order_filed = date("m/d/Y", strtotime($r['supp_findings_order_filed']));
			}
			else{
				$supp_findings_order_filed = "";
			}
			$fathers[$key]['supp_findings_order_filed'] = $supp_findings_order_filed;
	
			if(!empty($r['tpr_order_filed']) && ($r['tpr_order_filed'] != "0000-00-00")){
				$tpr_order_filed = date("m/d/Y", strtotime($r['tpr_order_filed']));
			}
			else{
				$tpr_order_filed = "";
			}
			$fathers[$key]['tpr_order_filed'] = $tpr_order_filed;
	
			if(!empty($r['arraignment_order_filed']) && ($r['arraignment_order_filed'] != "0000-00-00")){
				$arraignment_order_filed = date("m/d/Y", strtotime($r['arraignment_order_filed']));
			}
			else{
				$arraignment_order_filed = "";
			}
			$fathers[$key]['arraignment_order_filed'] = $arraignment_order_filed;
			$fatherExists = true;
		}
	}
	
	
	
	if(!$fatherExists){
	
		$key = $fatherCount;
		
		$fNamePieces = explode(" ", $r['father_name']);
		$fName = $fNamePieces[0];
		$mName = $fNamePieces[1];
		
		if(!empty($fNamePieces[2])){
			$lName = $fNamePieces[2];
		}
		else{
			$mName = "";
			$lName = $fNamePieces[1];
		}
		
		$fathers[$key]['FirstName'] = $fName;
		$fathers[$key]['MiddleName'] = $mName;
		$fathers[$key]['LastName'] = $lName;
		$fathers[$key]['PersonID'] = $r['person_id'];
		
		$fathers[$key]['Offending'] = $r['offending'];
		$fathers[$key]['in_custody_ind'] = $r['in_custody_ind'];
		$fathers[$key]['in_custody_where'] = $r['in_custody_where'];
		$fathers[$key]['no_contact_ind'] = $r['no_contact_ind'];
	
		//Get no contact with
		$no_contact_with = array();
		$query = "	SELECT no_contact_with_person_id
						FROM case_management.juv_no_contact_parties
						WHERE case_id = :case_id
						AND person_id = :person_id";
	
		$nc_res = array();
		getData($nc_res, $query, $idbh, array("case_id" => $case_id, "person_id" => $r['person_id']));
	
		if(count($nc_res) > 0){
			foreach($nc_res as $re){
				$no_contact_with[] = $re['no_contact_with_person_id'];
			}
		}
		$fathers[$key]['no_contact_with'] = $no_contact_with;
	
		if(!empty($r['no_contact_entered']) && ($r['no_contact_entered'] != "0000-00-00")){
			$no_contact_entered = date("m/d/Y", strtotime($r['no_contact_entered']));
		}
		else{
			$no_contact_entered = "";
		}
		$fathers[$key]['no_contact_entered'] = $no_contact_entered;

		if(!empty($r['no_contact_vacated']) && ($r['no_contact_vacated'] != "0000-00-00")){
			$no_contact_vacated = date("m/d/Y", strtotime($r['no_contact_vacated']));
		}
		else{
			$no_contact_vacated = "";
		}
		$fathers[$key]['no_contact_vacated'] = $no_contact_vacated;

		$fathers[$key]['recom'] = $r['recom'];
		if(!empty($r['shelter_dos']) && ($r['shelter_dos'] != "0000-00-00")){
			$shelter_dos = date("m/d/Y", strtotime($r['shelter_dos']));
		}
		else{
			$shelter_dos = "";
		}
		$fathers[$key]['shelter_dos'] = $shelter_dos;

		if(!empty($r['dependency_dos']) && ($r['dependency_dos'] != "0000-00-00")){
			$dependency_dos = date("m/d/Y", strtotime($r['dependency_dos']));
		}
		else{
			$dependency_dos = "";
		}
		$fathers[$key]['dependency_dos'] = $dependency_dos;

		if(!empty($r['supp_findings_dos']) && ($r['supp_findings_dos'] != "0000-00-00")){
			$supp_findings_dos = date("m/d/Y", strtotime($r['supp_findings_dos']));
		}
		else{
			$supp_findings_dos = "";
		}
		$fathers[$key]['supp_findings_dos'] = $supp_findings_dos;

		if(!empty($r['tpr_dos']) && ($r['tpr_dos'] != "0000-00-00")){
			$tpr_dos = date("m/d/Y", strtotime($r['tpr_dos']));
		}
		else{
			$tpr_dos = "";
		}
		$fathers[$key]['tpr_dos'] = $tpr_dos;

		if(!empty($r['arraignment_dos']) && ($r['arraignment_dos'] != "0000-00-00")){
			$arraignment_dos = date("m/d/Y", strtotime($r['arraignment_dos']));
		}
		else{
			$arraignment_dos = "";
		}
		$fathers[$key]['arraignment_dos'] = $arraignment_dos;

		if(!empty($r['shelter_order_filed']) && ($r['shelter_order_filed'] != "0000-00-00")){
			$shelter_order_filed = date("m/d/Y", strtotime($r['shelter_order_filed']));
		}
		else{
			$shelter_order_filed = "";
		}
		$fathers[$key]['shelter_order_filed'] = $shelter_order_filed;

		if(!empty($r['dependency_order_filed']) && ($r['dependency_order_filed'] != "0000-00-00")){
			$dependency_order_filed = date("m/d/Y", strtotime($r['dependency_order_filed']));
		}
		else{
			$dependency_order_filed = "";
		}
		$fathers[$key]['dependency_order_filed'] = $dependency_order_filed;

		if(!empty($r['supp_findings_order_filed']) && ($r['supp_findings_order_filed'] != "0000-00-00")){
			$supp_findings_order_filed = date("m/d/Y", strtotime($r['supp_findings_order_filed']));
		}
		else{
			$supp_findings_order_filed = "";
		}
		$fathers[$key]['supp_findings_order_filed'] = $supp_findings_order_filed;

		if(!empty($r['tpr_order_filed']) && ($r['tpr_order_filed'] != "0000-00-00")){
			$tpr_order_filed = date("m/d/Y", strtotime($r['tpr_order_filed']));
		}
		else{
			$tpr_order_filed = "";
		}
		$fathers[$key]['tpr_order_filed'] = $tpr_order_filed;

		if(!empty($r['arraignment_order_filed']) && ($r['arraignment_order_filed'] != "0000-00-00")){
			$arraignment_order_filed = date("m/d/Y", strtotime($r['arraignment_order_filed']));
		}
		else{
			$arraignment_order_filed = "";
		}
		$fathers[$key]['arraignment_order_filed'] = $arraignment_order_filed;
		$fatherExists = true;
		
		$fatherCount++;
	}
}

//Do separately because we may not have data about the father yet
foreach($fathers as $key => $f){
	
	//Get the father's special identifiers
	$query = "SELECT identifier_desc
						FROM case_management.juv_identifiers
						WHERE case_id = :case_id
						AND person_id = :person_id";
	
	$identifierRes = array();
	getData($identifierRes, $query, $idbh, array("case_id" => $case_id, "person_id" => $f['PersonID']));
	if(!empty($identifierRes)){
		foreach($identifierRes as $i){
			$fathers[$key]['special_identifiers'][] = $i['identifier_desc'];
		}
	}
	
	$fathers[$key]['special_identifiers_string'] = implode(", ", $fathers[$key]['special_identifiers']);
	
	//Get the father's attorneys
	$query = "SELECT attorney_type,
				attorney_name,
				CASE WHEN active = 1
					THEN 'Yes'
				ELSE 'No'
				END as active,
				juv_attorney_id
				FROM case_management.juv_attorneys
				WHERE case_id = :case_id
				AND person_id = :person_id";

	$attorneyRes = array();
	getData($attorneyRes, $query, $idbh, array("case_id" => $case_id, "person_id" => $f['PersonID']));
	if(!empty($attorneyRes)){
		foreach($attorneyRes as $a){
			$atty = array();
			$atty['attorney_type'] = $a['attorney_type'];
			$atty['attorney_name'] = $a['attorney_name'];
			$atty['attorney_active'] = $a['active'];
			$atty['attorney_id'] = $a['juv_attorney_id'];
			$fathers[$key]['attorneys'][] = $atty;
		}
	}
}

//Mother
$query = "	SELECT CASE 
				WHEN offending = 1
				THEN 'Yes'
				WHEN offending = 0
					THEN 'No'
				ELSE NULL
			END AS offending,
			CASE 
				WHEN in_custody_ind = 1
				THEN 'Yes'
				WHEN in_custody_ind = 0
					THEN 'No'
				ELSE NULL
			END AS in_custody_ind,
			in_custody_where,
			CASE 
				WHEN no_contact_order = 1
				THEN 'Yes'
				WHEN no_contact_order = 0
					THEN 'No'
				ELSE NULL
			END AS no_contact_ind,
			no_contact_vacated,
			no_contact_entered,
			recom,
			shelter_dos,
			dependency_dos,
			supp_findings_dos,
			tpr_dos,
			arraignment_dos,
			shelter_order_filed,
			dependency_order_filed,
			supp_findings_order_filed,
			tpr_order_filed,
			arraignment_order_filed,
			person_id
			FROM case_management.juv_mothers
			WHERE case_id = :case_id";

$row = getDataOne($query, $idbh, array("case_id" => $case_id));

if(!empty($row)){
	
	$mother['Offending'] = $row['offending'];
	$mother['in_custody_ind'] = $row['in_custody_ind'];
	$mother['in_custody_where'] = $row['in_custody_where'];
	$mother['no_contact_ind'] = $row['no_contact_ind'];
	
	//Get no contact with
	$no_contact_with = array();
	$query = "	SELECT no_contact_with_person_id
							FROM case_management.juv_no_contact_parties
							WHERE case_id = :case_id
							AND person_id = :person_id";
	
	$nc_res = array();
	getData($nc_res, $query, $idbh, array("case_id" => $case_id, "person_id" => $row['person_id']));
	
	if(count($nc_res) > 0){
		foreach($nc_res as $re){
			$no_contact_with[] = $re['no_contact_with_person_id'];
		}
	}
	$mother['no_contact_with'] = $no_contact_with;
	
	if(!empty($row['no_contact_entered']) && ($row['no_contact_entered'] != "0000-00-00")){
		$no_contact_entered = date("m/d/Y", strtotime($row['no_contact_entered']));
	}
	else{
		$no_contact_entered = "";
	}
	$mother['no_contact_entered'] = $no_contact_entered;
	
	if(!empty($row['no_contact_vacated']) && ($row['no_contact_vacated'] != "0000-00-00")){
		$no_contact_vacated = date("m/d/Y", strtotime($row['no_contact_vacated']));
	}
	else{
		$no_contact_vacated = "";
	}
	$mother['no_contact_vacated'] = $no_contact_vacated;
	
	$mother['recom'] = $row['recom'];
	
	if(!empty($row['shelter_dos']) && ($row['shelter_dos'] != "0000-00-00")){
		$mother['shelter_dos'] = date("m/d/Y", strtotime($row['shelter_dos']));
	}
	else{
		$mother['shelter_dos'] = "";
	}
		
	if(!empty($row['dependency_dos']) && ($row['dependency_dos'] != "0000-00-00")){
		$mother['dependency_dos'] = date("m/d/Y", strtotime($row['dependency_dos']));
	}
	else{
		$mother['dependency_dos'] = "";
	}
	
	if(!empty($row['supp_findings_dos']) && ($row['supp_findings_dos'] != "0000-00-00")){
		$mother['supp_findings_dos'] = date("m/d/Y", strtotime($row['supp_findings_dos']));
	}
	else{
		$mother['supp_findings_dos'] = "";
	}
				
	if(!empty($row['tpr_dos']) && ($row['tpr_dos'] != "0000-00-00")){
		$mother['tpr_dos'] = date("m/d/Y", strtotime($row['tpr_dos']));
	}
	else{
		$mother['tpr_dos'] = "";
	}
				
	if(!empty($row['arraignment_dos']) && ($row['arraignment_dos'] != "0000-00-00")){
		$mother['arraignment_dos'] = date("m/d/Y", strtotime($row['arraignment_dos']));
	}
	else{
		$mother['arraignment_dos'] = "";
	}
				
	if(!empty($row['shelter_order_filed']) && ($row['shelter_order_filed'] != "0000-00-00")){
		$mother['shelter_order_filed'] = date("m/d/Y", strtotime($row['shelter_order_filed']));
	}
	else{
		$mother['shelter_order_filed'] = "";
	}
				
	if(!empty($row['dependency_order_filed']) && ($row['dependency_order_filed'] != "0000-00-00")){
		$mother['dependency_order_filed'] = date("m/d/Y", strtotime($row['dependency_order_filed']));
	}
	else{
		$mother['dependency_order_filed'] = "";
	}
	
	if(!empty($row['supp_findings_order_filed']) && ($row['supp_findings_order_filed'] != "0000-00-00")){
		$mother['supp_findings_order_filed'] = date("m/d/Y", strtotime($row['supp_findings_order_filed']));
	}
	else{
		$mother['supp_findings_order_filed'] = "";
	}
				
	if(!empty($row['tpr_order_filed']) && ($row['tpr_order_filed'] != "0000-00-00")){
		$mother['tpr_order_filed'] = date("m/d/Y", strtotime($row['tpr_order_filed']));
	}
	else{
		$mother['tpr_order_filed'] = "";
	}
				
	if(!empty($row['arraignment_order_filed']) && ($row['arraignment_order_filed'] != "0000-00-00")){
		$mother['arraignment_order_filed'] = date("m/d/Y", strtotime($row['arraignment_order_filed']));
	}
	else{
		$mother['arraignment_order_filed'] = "";
	}
}

//Do separately because we may not have data about the mother yet
//Get the mother's attorneys
$query = "SELECT attorney_type,
			attorney_name,
			CASE WHEN active = 1
				THEN 'Yes'
			ELSE 'No'
			END as active,
			juv_attorney_id
			FROM case_management.juv_attorneys
			WHERE case_id = :case_id
			AND person_id = :person_id";

$attorneyRes = array();
getData($attorneyRes, $query, $idbh, array("case_id" => $case_id, "person_id" => $mother['PersonID']));
if(!empty($attorneyRes)){
	foreach($attorneyRes as $a){
		$atty = array();
		$atty['attorney_type'] = $a['attorney_type'];
		$atty['attorney_name'] = $a['attorney_name'];
			$atty['attorney_active'] = $a['active'];
		$atty['attorney_id'] = $a['juv_attorney_id'];
		$mother['attorneys'][] = $atty;
	}
}

//Get the mother's special identifiers
$query = "SELECT identifier_desc
				FROM case_management.juv_identifiers
				WHERE case_id = :case_id
				AND person_id = :person_id";

$identifierRes = array();
getData($identifierRes, $query, $idbh, array("case_id" => $case_id, "person_id" => $mother['PersonID']));
if(!empty($identifierRes)){
	foreach($identifierRes as $i){
		$mother['special_identifiers'][] = $i['identifier_desc'];
	}
}

if(!empty($mother['special_identifiers'])){
	$mother['special_identifiers_string'] = implode(", ", $mother['special_identifiers']);
}

//Now finish the related cases
foreach($fathers as $key => $f){
	$our_results = array();
	$query = " 	SELECT related_to_case_id as case_id
				FROM case_management.juv_related_cases
				WHERE person_id = :person_id
				AND original_case_id = :case_id";
	
	getData($our_results, $query, $idbh, array("person_id" => $f['PersonID'], "case_id" => $case_id));
	
	if(!empty($our_results)){
		foreach($our_results as $r){
			$fathers[$key]['related_cases'][] = $r['case_id'];
			if(!in_array($r['case_id'], $caseList)){
				$caseList[] = $r['case_id'];
			}
		}
	}
}

//Do children
foreach($children as $key => $c){
	$our_results = array();
	$query = " 	SELECT related_to_case_id as case_id
				FROM case_management.juv_related_cases
				WHERE person_id = :person_id
				AND original_case_id = :case_id";

	getData($our_results, $query, $idbh, array("person_id" => $c['PersonID'], "case_id" => $case_id));

	if(!empty($our_results)){
		foreach($our_results as $r){
			$children[$key]['related_cases'][] = $r['case_id'];
			if(!in_array($r['case_id'], $caseList)){
				$caseList[] = $r['case_id'];
			}
		}
	}
}

//And do mother...
$our_results = array();
$query = " 		SELECT related_to_case_id as case_id
				FROM case_management.juv_related_cases
				WHERE person_id = :person_id
				AND original_case_id = :case_id";

getData($our_results, $query, $idbh, array("person_id" => $mother['PersonID'], "case_id" => $case_id));

if(!empty($our_results)){
	foreach($our_results as $r){
		$mother['related_cases'][] = $r['case_id'];
		if(!in_array($r['case_id'], $caseList)){
			$caseList[] = $r['case_id'];
		}
	}
}

$caseString = "";
if(count($caseList) > 0){
	$caseString = implode(", ", $caseList);

	$rcQuery = "SELECT c.CaseNumber AS ToCaseNumber,
				c.CaseType,
				c.CaseStatus,
				CONVERT(varchar, c.FileDate, 101) as FileDate,
				c.CaseStyle,
				DivisionID,
				c.CaseID
			FROM
				vCase c with(nolock)
			WHERE
				CaseID IN (" . $caseString . ")
			ORDER BY c.FileDate DESC";

	$relatedCaseResults = array();
	getData($relatedCaseResults, $rcQuery, $dbh);
	
	if(!empty($relatedCaseResults)){
		foreach($relatedCaseResults as $key => $r){
			$relatedCaseResults[$key]['HasWarrant'] = 'No';
			$wQuery = "SELECT 
							COUNT(*) as WarrCount
						FROM 
							vWarrant
						WHERE CaseID = :case_id
						AND Closed = 'N'";
			
			$row = getDataOne($wQuery, $dbh, array("case_id" => $r['CaseID']));
			
			if($row['WarrCount'] > 0){
				$relatedCaseResults[$key]['HasWarrant'] = 'Yes';
			}
		}
	}
}

//Previous child placements...
$pcpResults = array();
foreach($children as $key => $c){
	$pcpResults = array();
	$pcpQuery = "SELECT child_where,
				child_with,
				child_address,
				date_placed,
				CASE 
					WHEN home_study_ind = 1
					THEN 'Yes'
					WHEN home_study_ind = 0
						THEN 'No'
					ELSE NULL
				END AS home_study_ind,
				home_study_approved_date,
				home_study_filed_date
				FROM case_management.juv_child_placement
				WHERE case_id = :case_id
				AND person_id = :person_id";
	
	getData($pcpResults, $pcpQuery, $idbh, array("case_id" => $case_id, "person_id" => $c['PersonID']));
	
	if(count($pcpResults) > 0){
		foreach($pcpResults as $pcp){
			$prevPlacement = array();
			$prevPlacement['child_where'] = $pcp['child_where'];
			$prevPlacement['child_with'] = $pcp['child_with'];
			$prevPlacement['child_address'] = $pcp['child_address'];
			$prevPlacement['home_study_ind'] = $pcp['home_study_ind'];
			
			if(!empty($pcp['date_placed']) && ($pcp['date_placed'] != "0000-00-00")){
				$date_placed = date("m/d/Y", strtotime($pcp['date_placed']));
			}
			else{
				$date_placed = "";
			}
			
			$prevPlacement['date_placed'] = $date_placed;
			
			if(!empty($pcp['date_placed']) && ($pcp['date_placed'] != "0000-00-00")){
				$date_placed = date("m/d/Y", strtotime($pcp['date_placed']));
			}
			else{
				$date_placed = "";
			}
				
			$prevPlacement['date_placed'] = $date_placed;
			
			if(!empty($pcp['home_study_approved_date']) && ($pcp['home_study_approved_date'] != "0000-00-00")){
				$home_study_approved_date = date("m/d/Y", strtotime($pcp['home_study_approved_date']));
			}
			else{
				$home_study_approved_date = "";
			}
				
			$prevPlacement['home_study_approved_date'] = $home_study_approved_date;
			
			if(!empty($pcp['home_study_filed_date']) && ($pcp['home_study_filed_date'] != "0000-00-00")){
				$home_study_filed_date = date("m/d/Y", strtotime($pcp['home_study_filed_date']));
			}
			else{
				$home_study_filed_date = "";
			}
			
			$prevPlacement['home_study_filed_date'] = $home_study_filed_date;
			
			$children[$key]['previous_placements'][] = $prevPlacement;
		}
	}
}

$special_identifiers = array("Deceased", "Missing/Abscond", "Crossover - DEL/DEP", "Pick Up Order/Warrant", "Human Trafficking", "Extended Foster Care", "TPR", "Unknown Father", "No Contact", "Incarcerated");

$smarty->assign('cls_attorney', $cls_attorney);
$smarty->assign('gal_name', $gal_name);
$smarty->assign('gal_attorney_name', $gal_attorney);
$smarty->assign('dcm_name', $dcm_name);
$smarty->assign('special_identifiers', $special_identifiers);
$smarty->assign('previousOrders', $previousOrders);
$smarty->assign('orders', $orders);
$smarty->assign('case_plans', $case_plans);
$smarty->assign('related_cases', $relatedCaseResults);
$smarty->assign('notes', $notes);
$smarty->assign('case_number', $case_number);
$smarty->assign('mother', $mother);
$smarty->assign('fathers', $fathers);
$smarty->assign('children', $children);
$smarty->assign('case_id', $case_id);

echo $smarty->fetch('case_management/juv_case_info.tpl');