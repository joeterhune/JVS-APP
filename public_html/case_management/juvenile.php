<?php

require_once("../php-lib/common.php");
require_once("../php-lib/db_functions.php");
require_once("Smarty/Smarty.class.php");

checkLoggedIn();

if(isset($_REQUEST['case_number'])){
	$case_number = $_REQUEST['case_number'];
}
else{
	$case_number = "";
}

if(isset($_REQUEST['case_id'])){
	$case_id = $_REQUEST['case_id'];
}
else{
	$case_id = "";
}

if(!empty($_POST)){
	
	$dbh = dbConnect("icms");
	
	$cls_attorney = trim($_POST['cls_attorney']);
	$gal_name = trim($_POST['gal_name']);
	$gal_attorney_name = trim($_POST['gal_attorney_name']);
	$dcm_name = trim($_POST['dcm_name']);
	
	if(!empty($cls_attorney) || !empty($gal_name) || !empty($gal_attorney_name) || !empty($dcm_name)){
		$query = "	SELECT COUNT(*) as ci_count
					FROM case_management.juv_case_info
					WHERE case_id = :case_id";
			
		$row = getDataOne($query, $dbh, array("case_id" => $case_id));
		
		//It's an insert
		if($row['ci_count'] < 1){
			$iQuery = "	INSERT INTO case_management.juv_case_info
						(
							case_number,
							case_id,
							cls_attorney_name,
							gal_name,
							gal_attorney_name,
							dcm_name,
							created_user,
							created_time,
							last_updated_user,
							last_updated_time
						)
						VALUES 
						(
							:case_number,
							:case_id,
							:cls_attorney_name,
							:gal_name,
							:gal_attorney_name,
							:dcm_name,
							:user,
							NOW(),
							:user,
							NOW()
						)";
			
			$args = array();
			$args['case_number'] = $case_number;
			$args['case_id'] = $case_id;
			$args['cls_attorney_name'] = $cls_attorney;
			$args['gal_name'] = $gal_name;
			$args['gal_attorney_name'] = $gal_attorney_name;
			$args['dcm_name'] = $dcm_name;
			$args['user'] = $_SESSION['user'];
			
			doQuery($iQuery, $dbh, $args);
		}
		else{
			//It's an update
			
			$uQuery = "	UPDATE case_management.juv_case_info
						SET cls_attorney_name = :cls_attorney_name,
						gal_attorney_name = :gal_attorney_name,
						gal_name = :gal_name,
						dcm_name = :dcm_name,
						last_updated_user = :user,
						last_updated_time = NOW()
						WHERE case_id = :case_id";
				
			$args = array();
			$args['case_id'] = $case_id;
			$args['cls_attorney_name'] = $_POST['cls_attorney'];
			$args['gal_name'] = $gal_name;
			$args['gal_attorney_name'] = $gal_attorney_name;
			$args['dcm_name'] = $dcm_name;
			$args['user'] = $_SESSION['user'];
				
			doQuery($uQuery, $dbh, $args);
		}
	}
	
	$order_ids = array();
	$obj_ids = array();
	$rel_cases = array();
	
	//Erase all related cases and we'll rewrite them
	$query = "	DELETE FROM case_management.juv_related_cases
				WHERE original_case_id = :case_id";
	doQuery($query, $dbh, array("case_id" => $case_id));
	
	foreach($_POST as $key => $p){
		
		// Related Cases
		if(strpos($key, "related~") !== false){
			$relPieces = explode("~", $key);
			$rel_case_number = $relPieces[1];
			$rel_case_id = $relPieces[2];
			
			//Go through all the people... 
			foreach($_POST['related~' . $rel_case_number . '~' . $rel_case_id] as $p1){
				$query = "	INSERT INTO case_management.juv_related_cases
							(
								original_case_number,
								original_case_id,
								related_to_case_number,
								related_to_case_id,
								person_id,
								created_user,
								created_time,
								last_updated_user,
								last_updated_time
							)
							VALUES 
							(
								:original_case_number,
								:original_case_id,
								:related_to_case_number,
								:related_to_case_id,
								:person_id,
								:user,
								NOW(),
								:user,
								NOW()
							)";
				
				$args = array();
				$args['original_case_number'] = $case_number;
				$args['original_case_id'] = $case_id;
				$args['related_to_case_number'] = $rel_case_number;
				$args['related_to_case_id'] = $rel_case_id;
				$args['person_id'] = $p1;
				$args['user'] = $_SESSION['user'];
				
				doQuery($query, $dbh, $args);
			}
		}
		
		if(strpos($key, "cp_") !== false && (strpos($key, "cp_relates_to~") === false)){
			$relPieces = explode("_", $key);
			$obj_id = $relPieces[1];
			
			if(!in_array($obj_id, $obj_ids)){
				$obj_ids[] = $obj_id;
			}
		}
		
		if(strpos($key, "co_order_for~") !== false){
			$relPieces = explode("~", $key);
			$order_id = $relPieces[1];
				
			if(!in_array($order_id, $order_ids)){
				$order_ids[] = $order_id;
			}
		}
	}
	
	//Case Plan Info
	foreach($obj_ids as $o){
		
		if($_POST['cp_' . $o . '_exec'] == "No"){
			$cp_exec = 0;
			
			if(!empty($_POST['cp_' . $o . '_exec_date'])){
				$cp_exec_date = date("Y-m-d", strtotime($_POST['cp_' . $o . '_exec_date']));
			}
			else{
				$cp_exec_date = "";
			}
			
			if(!empty($_POST['cp_' . $o . '_goal_date'])){
				$cp_goal_date = date("Y-m-d", strtotime($_POST['cp_' . $o . '_goal_date']));
			}
			else{
				$cp_goal_date = "";
			}
				
			if(!empty($_POST['cp_' . $o . '_order_date'])){
				$cp_order_date = date("Y-m-d", strtotime($_POST['cp_' . $o . '_order_date']));
			}
			else{
				$cp_order_date = "";
			}
				
			if(!empty($_POST['cp_' . $o . '_ent_date'])){
				$cp_filed_date = date("Y-m-d", strtotime($_POST['cp_' . $o . '_ent_date']));
			}
			else{
				$cp_filed_date = "";
			}
			
			if(!empty($_POST['cp_' . $o . '_ent_date'])){
				$cp_filed_date = date("Y-m-d", strtotime($_POST['cp_' . $o . '_ent_date']));
			}
			else{
				$cp_filed_date = "";
			}
		}
		else if($_POST['cp_' . $o . '_exec'] == "Yes"){
			$cp_exec = 1;
			if(!empty($_POST['cp_' . $o . '_exec_date'])){
				$cp_exec_date = date("Y-m-d", strtotime($_POST['cp_' . $o . '_exec_date']));
			}
			else{
				$cp_exec_date = "";
			}
		
			if(!empty($_POST['cp_' . $o . '_goal_date'])){
				$cp_goal_date = date("Y-m-d", strtotime($_POST['cp_' . $o . '_goal_date']));
			}
			else{
				$cp_goal_date = "";
			}
			
			if(!empty($_POST['cp_' . $o . '_order_date'])){
				$cp_order_date = date("Y-m-d", strtotime($_POST['cp_' . $o . '_order_date']));
			}
			else{
				$cp_order_date = "";
			}
			
			if(!empty($_POST['cp_' . $o . '_ent_date'])){
				$cp_filed_date = date("Y-m-d", strtotime($_POST['cp_' . $o . '_ent_date']));
			}
			else{
				$cp_filed_date = "";
			}
		}
		else{
			$cp_exec = "";
			
			if(!empty($_POST['cp_' . $o . '_exec_date'])){
				$cp_exec_date = date("Y-m-d", strtotime($_POST['cp_' . $o . '_exec_date']));
			}
			else{
				$cp_exec_date = "";
			}
				
			if(!empty($_POST['cp_' . $o . '_goal_date'])){
				$cp_goal_date = date("Y-m-d", strtotime($_POST['cp_' . $o . '_goal_date']));
			}
			else{
				$cp_goal_date = "";
			}
			
			if(!empty($_POST['cp_' . $o . '_order_date'])){
				$cp_order_date = date("Y-m-d", strtotime($_POST['cp_' . $o . '_order_date']));
			}
			else{
				$cp_order_date = "";
			}
			
			if(!empty($_POST['cp_' . $o . '_ent_date'])){
				$cp_filed_date = date("Y-m-d", strtotime($_POST['cp_' . $o . '_ent_date']));
			}
			else{
				$cp_filed_date = "";
			}
				
			if(!empty($_POST['cp_' . $o . '_ent_date'])){
				$cp_filed_date = date("Y-m-d", strtotime($_POST['cp_' . $o . '_ent_date']));
			}
			else{
				$cp_filed_date = "";
			}
		}
		
		$query = "	SELECT COUNT(*) as CPCount
					FROM case_management.juv_case_plans
					WHERE case_id = :case_id
					AND trakman_object_id = :object_id";
			
		$row = getDataOne($query, $dbh, array("case_id" => $case_id, "object_id" => $o));
		if($row['CPCount'] < 1){
			$args = array();
			$args['case_number'] = $case_number;
			$args['case_id'] = $case_id;
			$args['executed_date'] = $cp_exec_date;
			$args['goal_date'] = $cp_goal_date;
			$args['order_date'] = $cp_order_date;
			$args['trakman_object_id'] = $o;
			$args['file_date'] = $cp_filed_date;
			$args['user'] = $_SESSION['user'];
				
			$insertQuery = "INSERT INTO
								case_management.juv_case_plans
								(
									case_number,
									case_id,
									executed,
									executed_date,
									goal_date,
									order_date,
									trakman_object_id,
									file_date,
									created_user,
									created_time,
									last_updated_user,
									last_updated_time
								)
								VALUES
								(
									:case_number,
									:case_id,";
			
			if(strlen($cp_exec)){
				$insertQuery .= " :executed, ";
				$args['executed'] = $cp_exec;
			}
			else{
				$insertQuery .= " NULL, ";
			}

			$insertQuery .= "		:executed_date,
									:goal_date,
									:order_date,
									:trakman_object_id,
									:file_date,
									:user,
									NOW(),
									:user,
									NOW()
								)";

			doQuery($insertQuery, $dbh, $args);
		}
		else{
				
			$args = array();
			$args['case_id'] = $case_id;
			$args['executed_date'] = $cp_exec_date;
			$args['goal_date'] = $cp_goal_date;
			$args['order_date'] = $cp_order_date;
			$args['object_id'] = $o;
			$args['file_date'] = $cp_filed_date;
			$args['user'] = $_SESSION['user'];
				
			//This is an update....
			$updateQuery = "	UPDATE case_management.juv_case_plans SET ";
			
			if(strlen($cp_exec)){
				$updateQuery .= " executed = :executed, ";
				$args['executed'] = $cp_exec;
			}
			$updateQuery .= "		executed_date = :executed_date,
									goal_date = :goal_date,
									order_date = :order_date,
									file_date = :file_date,
									last_updated_user = :user,
									last_updated_time = NOW()
									WHERE case_id = :case_id
									AND trakman_object_id = :object_id";
				
			doQuery($updateQuery, $dbh, $args);
				
		}
	}
	
	$orderCount = 1;
	while(isset($_POST['co_order_title_' . $orderCount]) && !empty($_POST['co_order_title_' . $orderCount])){
		//What was ordered? BRAND NEW ORDERS
		if(!empty($_POST['co_order_title_' . $orderCount])){
			$order_title = $_POST['co_order_title_' . $orderCount];
		}
		else{
			$order_title = "";
		}
		
		if(!empty($_POST['co_due_date_' . $orderCount])){
			$order_due_date = date("Y-m-d", strtotime($_POST['co_due_date_' . $orderCount]));
		}
		else{
			$order_due_date = "";
		}
		
		if(!empty($_POST['co_order_date_' . $orderCount])){
			$order_order_date = date("Y-m-d", strtotime($_POST['co_order_date_' . $orderCount]));
		}
		else{
			$order_order_date = "";
		}
		
		if(!empty($order_title) || !empty($order_due_date) || (!empty($order_order_date))){
			$args = array();
			$args['case_number'] = $case_number;
			$args['case_id'] = $case_id;
			$args['order_title'] = $order_title;
			$args['due_date'] = $order_due_date;
			$args['order_date'] = $order_order_date;
			$args['user'] = $_SESSION['user'];
			$query = "	INSERT INTO case_management.juv_orders
						(
							case_number,
							case_id,
							order_title,
							due_date,
							order_date,
							created_user,
							created_time,
							last_updated_user,
							last_updated_time
						)
						VALUES 
						(
							:case_number,
							:case_id,
							:order_title,
							:due_date,
							:order_date,
							:user,
							NOW(),
							:user,
							NOW()
						)";
			
			doQuery($query, $dbh, $args);
			$new_order_id = getLastInsert($dbh);
			
			if(count($_POST['co_order_for_' . $orderCount]) > 0){
				foreach($_POST['co_order_for_' . $orderCount] as $of){
					$args = array();
					$args['case_number'] = $case_number;
					$args['case_id'] = $case_id;
					$args['person_id'] = $of;
					$args['order_id'] = $new_order_id;
					$args['user'] = $_SESSION['user'];
							
					$ofQuery = "INSERT INTO case_management.juv_order_parties
								(
									case_number,
									case_id,
									person_id,
									juv_order_id,
									created_user,
									created_time,
									last_updated_user,
									last_updated_time
								)
								VALUES
								(
									:case_number,
									:case_id,
									:person_id,
									:order_id,
									:user,
									NOW(),
									:user,
									NOW()
								)";
					
					doQuery($ofQuery, $dbh, $args);
				}
			}
		}
		
		$orderCount++;
	}
	
	//Updates to existing orders
	if(count($order_ids) > 0){
		foreach($order_ids as $o){
		
			if(!empty($_POST['co_' . $o . '_order_title'])){
				$order_title = $_POST['co_' . $o . '_order_title'];
			}
			else{
				$order_title = "";
			}
			
			if(!empty($_POST['co_' . $o . '_due_date'])){
				$order_due_date = date("Y-m-d", strtotime($_POST['co_' . $o . '_due_date']));
			}
			else{
				$order_due_date = "";
			}
			
			if(!empty($_POST['co_' . $o . '_order_date'])){
				$order_order_date = date("Y-m-d", strtotime($_POST['co_' . $o . '_order_date']));
			}
			else{
				$order_order_date = "";
			}
			
			$args = array();
			$args['case_id'] = $case_id;
			$args['order_title'] = $order_title;
			$args['due_date'] = $order_due_date;
			$args['order_date'] = $order_order_date;
			$args['order_id'] = $o;
			$args['user'] = $_SESSION['user'];
		
			//This is an update....
			$updateQuery = "	UPDATE case_management.juv_orders
								SET order_title = :order_title,
								due_date = :due_date,
								order_date = :order_date,
								last_updated_user = :user,
								last_updated_time = NOW()
								WHERE juv_order_id = :order_id
								AND case_id = :case_id";
		
			doQuery($updateQuery, $dbh, $args);
			
			//Let's update who they are ordered for...
			//Erase all of them and we'll rewrite them
			$query = "	DELETE FROM case_management.juv_order_parties
						WHERE case_id = :case_id
						AND juv_order_id = :order_id";
			doQuery($query, $dbh, array("case_id" => $case_id, "order_id" => $o));
				
			//Go through all the people...
			foreach($_POST['co_order_for~' . $o] as $p){
				$query = "	INSERT INTO case_management.juv_order_parties
								(
									case_number,
									case_id,
									person_id,
									juv_order_id,
									created_user,
									created_time,
									last_updated_user,
									last_updated_time
								)
								VALUES
								(
									:case_number,
									:case_id,
									:person_id,
									:order_id,
									:user,
									NOW(),
									:user,
									NOW()
								)";
			
				$args = array();
				$args['case_number'] = $case_number;
				$args['case_id'] = $case_id;
				$args['order_id'] = $o;
				$args['person_id'] = $p;
				$args['user'] = $_SESSION['user'];
			
				doQuery($query, $dbh, $args);
			}
	
		}
	}
	
	foreach($_POST as $key => $p){

		//Case Plan Related to....
		if(strpos($key, "cp_relates_to~") !== false){
			$relPieces = explode("~", $key);
			$object_id = $relPieces[1];
			
			//Get CP ID from object ID...
			$query = "	SELECT juv_case_plan_id
						FROM case_management.juv_case_plans
						WHERE trakman_object_id = :object_id";
			
			$row = getDataOne($query, $dbh, array("object_id" => $object_id));
			$cp_id = $row['juv_case_plan_id'];
	
			//Erase all of them and we'll rewrite them
			$query = "	DELETE FROM case_management.juv_related_case_plans
						WHERE trakman_object_id = :object_id";
			doQuery($query, $dbh, array("object_id" => $object_id));
	
			//Go through all the people...
			foreach($p as $p1){
				$query = "	INSERT INTO case_management.juv_related_case_plans
							(
								case_number,
								case_id,
								person_id,
								case_plan_id,
								trakman_object_id,
								created_user,
								created_time,
								last_updated_user,
								last_updated_time
							)
							VALUES
							(
								:case_number,
								:case_id,
								:person_id,
								:case_plan_id,
								:object_id,
								:user,
								NOW(),
								:user,
								NOW()
							)";
				
				$args = array();
				$args['case_number'] = $case_number;
				$args['case_id'] = $case_id;
				$args['person_id'] = $p1;
				$args['case_plan_id'] = $cp_id;
				$args['object_id'] = $object_id;
				$args['user'] = $_SESSION['user'];
	
				doQuery($query, $dbh, $args);
			}
		}
	}
	
	$child_ids = array();
	foreach($_POST as $key => $p){
		if(strpos($key, "child_") !== false){
			$pieces = explode("_", $key);
			$child_id = $pieces[1];
			
			if(!in_array($child_id, $child_ids)){
				$child_ids[] = $child_id;
			}
		}
	}
	
	//Father?
	
	$father_ids = array();
	foreach($_POST as $key => $p){
		if(strpos($key, "father_") !== false && (strpos($key, "child_") === false)){
			$pieces = explode("_", $key);
			$father_id = $pieces[1];
				
			if(!in_array($father_id, $father_ids)){
				$father_ids[] = $father_id;
			}
		}
	}
	
	$father_data = array();
	foreach($father_ids as $father_id){
		
		//Father's attorneys
		$attCount = 1;
		while(isset($_POST['father_' . $father_id . '_attorney_name_' . $attCount]) && !empty($_POST['father_' . $father_id . '_attorney_name_' . $attCount])){
			$atty = array();
			if(isset($_POST['father_' . $father_id . '_attorney_id_' . $attCount]) && !empty($_POST['father_' . $father_id . '_attorney_id_' . $attCount])){
				$atty['attorney_id'] = $_POST['father_' . $father_id . '_attorney_id_' . $attCount];
			}
			else{
				$atty['attorney_id'] = "";
			}
			
			$atty['name'] = trim($_POST['father_' . $father_id . '_attorney_name_' . $attCount]);
				
			if($_POST['father_' . $father_id . '_attorney_active_' . $attCount] == 'Yes'){
				$atty['active'] = 1;
			}
			else{
				$atty['active'] = 0;
			}
				
			$father_data[$father_id]['attorneys'][] = $atty;
			$attCount++;
		}
		
		$father_data[$father_id]['father_id'] = $father_id;
		$father_data[$father_id]['father_name'] = $_POST['father_'  . $father_id . '_name'];
		if(!empty($_POST['father_' . $father_id . '_off'])){
			if($_POST['father_' . $father_id . '_off'] == 'Yes'){
				$father_data[$father_id]['offending'] = 1;
			}
			else{
				$father_data[$father_id]['offending'] = 0;
			}
		}
		else{
			$father_data[$father_id]['offending'] = "";
		}
		
		//Insert father's attorneys
		if(!empty($father_data[$father_id]['attorneys'])){
			foreach($father_data[$father_id]['attorneys'] as $a){
				if(!empty($a['attorney_id'])){
					$updateAttyQuery = "UPDATE case_management.juv_attorneys
										SET attorney_name = :attorney_name,
										active = :active,
										last_updated_user = :user,
										last_updated_time = NOW()
										WHERE case_id = :case_id
										AND person_id = :person_id
										AND juv_attorney_id = :attorney_id";
		
					$args = array();
					$args['attorney_name'] = $a['name'];
					$args['active'] = $a['active'];
					$args['user'] = $_SESSION['user'];
					$args['case_id'] = $case_id;
					$args['person_id'] = $father_id;
					$args['attorney_id'] = $a['attorney_id'];
		
					doQuery($updateAttyQuery, $dbh, $args);
				}
				else{
						
					$insertAttyQuery = "INSERT INTO case_management.juv_attorneys
										(
											case_number,
											case_id,
											person_id,
											attorney_name,
											active,
											created_user,
											created_time,
											last_updated_user,
											last_updated_time
										)
										VALUES
										(
											:case_number,
											:case_id,
											:person_id,
											:attorney_name,
											:active,
											:user,
											NOW(),
											:user,
											NOW()
										)";
		
					$args = array();
					$args['case_number'] = $case_number;
					$args['attorney_name'] = $a['name'];
					$args['active'] = $a['active'];
					$args['user'] = $_SESSION['user'];
					$args['case_id'] = $case_id;
					$args['person_id'] = $father_id;
		
					doQuery($insertAttyQuery, $dbh, $args);
				}
			}
		}
			
		if(!empty($_POST['father_' . $father_id . '_special_identifiers'])){
			foreach($_POST['father_' . $father_id . '_special_identifiers'] as $si){
				$father_data[$father_id]['special_identifiers'][] = $si;
			}
		}
		else{
			$father_data[$father_id]['special_identifiers'] = "";
		}
			
		if(empty($_POST['father_' . $father_id . '_in_custody_ind'])){
			$father_data[$father_id]['in_custody_ind'] = "";
			$father_data[$father_id]['in_custody_where'] = "";
		}
		else{
			if($_POST['father_' . $father_id . '_in_custody_ind'] == 'Yes'){
				$father_data[$father_id]['in_custody_ind'] = 1;
		
				if(!empty($_POST['father_' . $father_id . '_in_custody_where'])){
					$father_data[$father_id]['in_custody_where'] = $_POST['father_' . $father_id . '_in_custody_where'];
				}
				else{
					$father_data[$father_id]['in_custody_where'] = "";
				}
		
			}
			else{
				$father_data[$father_id]['in_custody_ind'] = 0;
				$father_data[$father_id]['in_custody_where'] = "";
			}
		}
			
		if(empty($_POST['father_' . $father_id . '_no_contact_ind'])){
			$father_data[$father_id]['no_contact_ind'] = "";
			//$father_data[$father_id]['no_contact_who'] = "";
			$father_data[$father_id]['no_contact_entered'] = "";
			$father_data[$father_id]['no_contact_vacated'] = "";
		}
		else{
			if($_POST['father_' . $father_id . '_no_contact_ind'] == 'Yes'){
				$father_data[$father_id]['no_contact_ind'] = 1;
					
				if(!empty($_POST['father_' . $father_id . '_no_contact_entered'])){
					$father_data[$father_id]['no_contact_entered'] = date("Y-m-d", strtotime($_POST['father_' . $father_id . '_no_contact_entered']));
				}
				else{
					$father_data[$father_id]['no_contact_entered'] = "";
				}
					
				if(!empty($_POST['father_' . $father_id . '_no_contact_vacated'])){
					$father_data[$father_id]['no_contact_vacated'] = date("Y-m-d", strtotime($_POST['father_' . $father_id . '_no_contact_vacated']));
				}
				else{
					$father_data[$father_id]['no_contact_vacated'] = "";
				}
					
			}
			else{
				$father_data[$father_id]['no_contact_ind'] = 0;
				//$father_data[$father_id]['no_contact_who'] = "";
				$father_data[$father_id]['no_contact_entered'] = "";
				$father_data[$father_id]['no_contact_vacated'] = "";
			}
		}
			
		if(!empty($_POST['father_' . $father_id . '_recom'])){
			$father_data[$father_id]['recom'] = $_POST['father_' . $father_id . '_recom'];
		}
		else{
			$father_data[$father_id]['recom'] = "";
		}
			
		if(empty($_POST['father_' . $father_id . '_shelter_dos'])){
			$father_data[$father_id]['shelter_dos'] = "";
		}
		else{
			$father_data[$father_id]['shelter_dos'] = date("Y-m-d", strtotime($_POST['father_' . $father_id . '_shelter_dos']));
		}
			
		if(empty($_POST['father_' . $father_id . '_arraignment_dos'])){
			$father_data[$father_id]['arraignment_dos'] = "";
		}
		else{
			$father_data[$father_id]['arraignment_dos'] = date("Y-m-d", strtotime($_POST['father_' . $father_id . '_arraignment_dos']));
		}
		
		if(empty($_POST['father_' . $father_id . '_dependency_dos'])){
			$father_data[$father_id]['dependency_dos'] = "";
		}
		else{
			$father_data[$father_id]['dependency_dos'] = date("Y-m-d", strtotime($_POST['father_' . $father_id . '_dependency_dos']));
		}
			
		if(empty($_POST['father_' . $father_id . '_supp_findings_dos'])){
			$father_data[$father_id]['supp_findings_dos'] = "";
		}
		else{
			$father_data[$father_id]['supp_findings_dos'] = date("Y-m-d", strtotime($_POST['father_' . $father_id . '_supp_findings_dos']));
		}
		
		if(empty($_POST['father_' . $father_id . '_tpr_dos'])){
			$father_data[$father_id]['tpr_dos'] = "";
		}
		else{
			$father_data[$father_id]['tpr_dos'] = date("Y-m-d", strtotime($_POST['father_' . $father_id . '_tpr_dos']));
		}
			
		if(empty($_POST['father_' . $father_id . '_shelter_order_filed'])){
			$father_data[$father_id]['shelter_order_filed'] = "";
		}
		else{
			$father_data[$father_id]['shelter_order_filed'] = date("Y-m-d", strtotime($_POST['father_' . $father_id . '_shelter_order_filed']));
		}
			
		if(empty($_POST['father_' . $father_id . '_arraignment_order_filed'])){
			$father_data[$father_id]['arraignment_order_filed'] = "";
		}
		else{
			$father_data[$father_id]['arraignment_order_filed'] = date("Y-m-d", strtotime($_POST['father_' . $father_id . '_arraignment_order_filed']));
		}
			
		if(empty($_POST['father_' . $father_id . '_dependency_order_filed'])){
			$father_data[$father_id]['dependency_order_filed'] = "";
		}
		else{
			$father_data[$father_id]['dependency_order_filed'] = date("Y-m-d", strtotime($_POST['father_' . $father_id . '_dependency_order_filed']));
		}
			
		if(empty($_POST['father_' . $father_id . '_supp_findings_order_filed'])){
			$father_data[$father_id]['supp_findings_order_filed'] = "";
		}
		else{
			$father_data[$father_id]['supp_findings_order_filed'] = date("Y-m-d", strtotime($_POST['father_' . $father_id . '_supp_findings_order_filed']));
		}
			
		if(empty($_POST['father_' . $father_id . '_tpr_order_filed'])){
			$father_data[$father_id]['tpr_order_filed'] = "";
		}
		else{
			$father_data[$father_id]['tpr_order_filed'] = date("Y-m-d", strtotime($_POST['father_' . $father_id . '_tpr_order_filed']));
		}
	}
	
	$mother_id = "";
	foreach($_POST as $key => $p){
		if(strpos($key, "mother_") !== false){
			$motherPieces = explode("_", $key);
			$mother_id = $motherPieces[1];
		}
	}
	
	$child_data = array();
	
	$newFatherCount = 1;
	
	//Mother's attorneys
	$attCount = 1;
	while(isset($_POST['mother_' . $mother_id . '_attorney_name_' . $attCount]) && !empty($_POST['mother_' . $mother_id . '_attorney_name_' . $attCount])){
		$atty = array();
		if(isset($_POST['mother_' . $mother_id . '_attorney_id_' . $attCount]) && !empty($_POST['mother_' . $mother_id . '_attorney_id_' . $attCount])){
			$atty['attorney_id'] = $_POST['mother_' . $mother_id . '_attorney_id_' . $attCount];
		}
		else{
			$atty['attorney_id'] = "";
		}
			
		$atty['name'] = trim($_POST['mother_' . $mother_id . '_attorney_name_' . $attCount]);
	
		if($_POST['mother_' . $mother_id . '_attorney_active_' . $attCount] == 'Yes'){
			$atty['active'] = 1;
		}
		else{
			$atty['active'] = 0;
		}
	
		$mother['attorneys'][] = $atty;
		$attCount++;
	}
	
	//Insert mother's attorneys
	if(!empty($mother['attorneys'])){
		foreach($mother['attorneys'] as $a){
			if(!empty($a['attorney_id'])){
				$updateAttyQuery = "UPDATE case_management.juv_attorneys
										SET attorney_name = :attorney_name,
										active = :active,
										last_updated_user = :user,
										last_updated_time = NOW()
										WHERE case_id = :case_id
										AND person_id = :person_id
										AND juv_attorney_id = :attorney_id";
	
				$args = array();
				$args['attorney_name'] = $a['name'];
				$args['active'] = $a['active'];
				$args['user'] = $_SESSION['user'];
				$args['case_id'] = $case_id;
				$args['person_id'] = $mother_id;
				$args['attorney_id'] = $a['attorney_id'];
	
				doQuery($updateAttyQuery, $dbh, $args);
			}
			else{
	
				$insertAttyQuery = "INSERT INTO case_management.juv_attorneys
										(
											case_number,
											case_id,
											person_id,
											attorney_name,
											active,
											created_user,
											created_time,
											last_updated_user,
											last_updated_time
										)
										VALUES
										(
											:case_number,
											:case_id,
											:person_id,
											:attorney_name,
											:active,
											:user,
											NOW(),
											:user,
											NOW()
										)";
	
				$args = array();
				$args['case_number'] = $case_number;
				$args['attorney_name'] = $a['name'];
				$args['active'] = $a['active'];
				$args['user'] = $_SESSION['user'];
				$args['case_id'] = $case_id;
				$args['person_id'] = $mother_id;
	
				doQuery($insertAttyQuery, $dbh, $args);
			}
		}
	}
	
	if(!empty($_POST['mother_' . $mother_id . '_special_identifiers'])){
		foreach($_POST['mother_' . $mother_id . '_special_identifiers'] as $si){
			$mother['special_identifiers'][] = $si;
		}
	}
	else{
		$mother['special_identifiers'] = "";
	}
		
	if(empty($_POST['mother_' . $mother_id . '_off'])){
		$mother_offending = "";
	}
	else{
		if($_POST['mother_' . $mother_id . '_off'] == 'Yes'){
			$mother_offending = 1;
		}
		else{
			$mother_offending = 0;
		}
	}
		
	if(empty($_POST['mother_' . $mother_id . '_name'])){
		$mother_name = "";
	}
	else{
		$mother_name = $_POST['mother_' . $mother_id . '_name'];
	}
	
	if(empty($_POST['mother_' . $mother_id . '_in_custody_ind'])){
		$mother_in_custody_ind = "";
		$mother_in_custody_where = "";
	}
	else{
		if($_POST['mother_' . $mother_id . '_in_custody_ind'] == 'Yes'){
			$mother_in_custody_ind = 1;
			
			if(!empty($_POST['mother_' . $mother_id . '_in_custody_where'])){
				$mother_in_custody_where = $_POST['mother_' . $mother_id . '_in_custody_where'];
			}
			else{
				$mother_in_custody_where = "";
			}
			
		}
		else{
			$mother_in_custody_ind = 0;
			$mother_in_custody_where = "";
		}
	}
	
	if(empty($_POST['mother_' . $mother_id . '_no_contact_ind'])){
		$mother_no_contact_ind = "";
		$mother_no_contact_entered = "";
		$mother_no_contact_vacated = "";
	}
	else{
		if($_POST['mother_' . $mother_id . '_no_contact_ind'] == 'Yes'){
			$mother_no_contact_ind = 1;
			
			if(!empty($_POST['mother_' . $mother_id . '_no_contact_entered'])){
				$mother_no_contact_entered = date("Y-m-d", strtotime($_POST['mother_' . $mother_id . '_no_contact_entered']));
			}
			else{
				$mother_no_contact_entered = "";
			}
			
			if(!empty($_POST['mother_' . $mother_id . '_no_contact_vacated'])){
				$mother_no_contact_vacated = date("Y-m-d", strtotime($_POST['mother_' . $mother_id . '_no_contact_vacated']));
			}
			else{
				$mother_no_contact_vacated = "";
			}
				
		}
		else{
			$mother_no_contact_ind = 0;
			$mother_no_contact_entered = "";
			$mother_no_contact_vacated = "";
		}
	}
	
	//Mother no contact
	//Erase all of them and we'll rewrite them
	
	$query = "	DELETE FROM case_management.juv_no_contact_parties
				WHERE case_id = :case_id
				AND person_id = :person_id";
	doQuery($query, $dbh, array("case_id" => $case_id, "person_id" => $mother_id));
		
	if(!empty($_POST['mother_' . $mother_id . '_no_contact_with'])){	
		//Go through all the people...
		foreach($_POST['mother_' . $mother_id . '_no_contact_with'] as $nc){
			$query = "	INSERT INTO case_management.juv_no_contact_parties
						(
							case_number,
							case_id,
							person_id,
							no_contact_with_person_id,
							created_user,
							created_time,
							last_updated_user,
							last_updated_time
						)
						VALUES
						(
							:case_number,
							:case_id,
							:person_id,
							:no_contact_with_person_id,
							:user,
							NOW(),
							:user,
							NOW()
						)";
		
			$args = array();
			$args['case_number'] = $case_number;
			$args['case_id'] = $case_id;
			$args['person_id'] = $mother_id;
			$args['no_contact_with_person_id'] = $nc;
			$args['user'] = $_SESSION['user'];
		
			doQuery($query, $dbh, $args);
		}
	}
	
	if(!empty($_POST['mother_' . $mother_id . '_recom'])){
		$mother_recom = $_POST['mother_' . $mother_id . '_recom'];
	}
	else{
		$mother_recom = "";
	}
	
	if(empty($_POST['mother_' . $mother_id . '_shelter_dos'])){
		$mother_shelter_dos = "";
	}
	else{
		$mother_shelter_dos = date("Y-m-d", strtotime($_POST['mother_' . $mother_id . '_shelter_dos']));
	}
	
	if(empty($_POST['mother_' . $mother_id . '_arraignment_dos'])){
		$mother_arraignment_dos = "";
	}
	else{
		$mother_arraignment_dos = date("Y-m-d", strtotime($_POST['mother_' . $mother_id . '_arraignment_dos']));
	}
		
	if(empty($_POST['mother_' . $mother_id . '_dependency_dos'])){
		$mother_dependency_dos = "";
	}
	else{
		$mother_dependency_dos = date("Y-m-d", strtotime($_POST['mother_' . $mother_id . '_dependency_dos']));
	}
	
	if(empty($_POST['mother_' . $mother_id . '_supp_findings_dos'])){
		$mother_supp_findings_dos = "";
	}
	else{
		$mother_supp_findings_dos = date("Y-m-d", strtotime($_POST['mother_' . $mother_id . '_supp_findings_dos']));
	}
		
	if(empty($_POST['mother_' . $mother_id . '_tpr_dos'])){
		$mother_tpr_dos = "";
	}
	else{
		$mother_tpr_dos = date("Y-m-d", strtotime($_POST['mother_' . $mother_id . '_tpr_dos']));
	}
	
	if(empty($_POST['mother_' . $mother_id . '_shelter_order_filed'])){
		$mother_shelter_order_filed = "";
	}
	else{
		$mother_shelter_order_filed = date("Y-m-d", strtotime($_POST['mother_' . $mother_id . '_shelter_order_filed']));
	}
	
	if(empty($_POST['mother_' . $mother_id . '_arraignment_order_filed'])){
		$mother_arraignment_order_filed = "";
	}
	else{
		$mother_arraignment_order_filed = date("Y-m-d", strtotime($_POST['mother_' . $mother_id . '_arraignment_order_filed']));
	}
	
	if(empty($_POST['mother_' . $mother_id . '_dependency_order_filed'])){
		$mother_dependency_order_filed = "";
	}
	else{
		$mother_dependency_order_filed = date("Y-m-d", strtotime($_POST['mother_' . $mother_id . '_dependency_order_filed']));
	}
	
	if(empty($_POST['mother_' . $mother_id . '_supp_findings_order_filed'])){
		$mother_supp_findings_order_filed = "";
	}
	else{
		$mother_supp_findings_order_filed = date("Y-m-d", strtotime($_POST['mother_' . $mother_id . '_supp_findings_order_filed']));
	}
	
	if(empty($_POST['mother_' . $mother_id . '_tpr_order_filed'])){
		$mother_tpr_order_filed = "";
	}
	else{
		$mother_tpr_order_filed = date("Y-m-d", strtotime($_POST['mother_' . $mother_id . '_tpr_order_filed']));
	}
	
	foreach($child_ids as $child_id){
		
		//Attorneys
		$attCount = 1;
		while(isset($_POST['child_' . $child_id . '_attorney_type_' . $attCount]) && !empty($_POST['child_' . $child_id . '_attorney_type_' . $attCount])){
			$atty = array();
			if(isset($_POST['child_' . $child_id . '_attorney_id_' . $attCount]) && !empty($_POST['child_' . $child_id . '_attorney_id_' . $attCount])){
				$atty['attorney_id'] = $_POST['child_' . $child_id . '_attorney_id_' . $attCount];
			}
			else{
				$atty['attorney_id'] = "";
			}
			$atty['type'] = $_POST['child_' . $child_id . '_attorney_type_' . $attCount];
			$atty['name'] = trim($_POST['child_' . $child_id . '_attorney_name_' . $attCount]);
			
			if($_POST['child_' . $child_id . '_attorney_active_' . $attCount] == 'Yes'){
				$atty['active'] = 1;
			}
			else{
				$atty['active'] = 0;
			}
			
			$child_data[$child_id]['attorneys'][] = $atty;
			$attCount++;
		}
		
		//Psych meds
		$pmCount = 1;
		$pm_requested_by = $_POST['child_' . $child_id . '_psych_meds_requested_by_' . $pmCount];
		$pm_requested_date = $_POST['child_' . $child_id . '_psych_meds_requested_date_' . $pmCount];
		$pm_affidavit_filed = $_POST['child_' . $child_id . '_psych_meds_affidavit_filed_' . $pmCount];
		$pm_order_filed = $_POST['child_' . $child_id . '_psych_meds_order_filed_' . $pmCount];
		$pm_order_date = $_POST['child_' . $child_id . '_psych_meds_order_date_' . $pmCount];
		$pm_meds = $_POST['child_' . $child_id . '_psych_meds_' . $pmCount];
		
		while(!empty($pm_requested_by) || !empty($pm_requested_date) || !empty($pm_affidavit_filed) || !empty($pm_order_filed)
				|| !empty($pm_order_date) || !empty($pm_meds)){
			$med = array();
			if(isset($_POST['child_' . $child_id . '_pm_id_' . $pmCount]) && !empty($_POST['child_' . $child_id . '_pm_id_' . $pmCount])){
				$med['pm_id'] = $_POST['child_' . $child_id . '_pm_id_' . $pmCount];
			}
			else{
				$med['pm_id'] = "";
			}
			$med['requested_by'] = $pm_requested_by;
			
			if(!empty($pm_requested_date)){
				$med['requested_date']= date("Y-m-d", strtotime($pm_requested_date));
			}
			else{
				$med['requested_date'] = "";
			}
				
			if(!empty($pm_affidavit_filed)){
				if($pm_affidavit_filed == 'Yes'){
					$med['affidavit_filed'] = 1;
				}
				else{
					$med['affidavit_filed'] = 0;
				}
			}
			else{
				$med['affidavit_filed'] = "";
			}
			
			$med['order_filed'] = $pm_order_filed;
			
			if(!empty($pm_order_date)){
				$med['order_date']= date("Y-m-d", strtotime($pm_order_date));
			}
			else{
				$med['order_date'] = "";
			}
			
			$med['meds'] = trim($pm_meds);
				
			$child_data[$child_id]['psych_meds'][] = $med;
			$pmCount++;
			
			$pm_requested_by = $_POST['child_' . $child_id . '_psych_meds_requested_by_' . $pmCount];
			$pm_requested_date = $_POST['child_' . $child_id . '_psych_meds_requested_date_' . $pmCount];
			$pm_affidavit_filed = $_POST['child_' . $child_id . '_psych_meds_affidavit_filed_' . $pmCount];
			$pm_order_filed = $_POST['child_' . $child_id . '_psych_meds_order_filed_' . $pmCount];
			$pm_order_date = $_POST['child_' . $child_id . '_psych_meds_order_date_' . $pmCount];
			$pm_meds = $_POST['child_' . $child_id . '_psych_meds_' . $pmCount];
		}
		
		if(empty($_POST['child_' . $child_id . '_name'])){
			$child_data[$child_id]['name'] = "";
		}
		else{
			$child_data[$child_id]['name'] = $_POST['child_' . $child_id . '_name'];
		}
		
		if(empty($_POST['child_' . $child_id . '_dob'])){
			$child_data[$child_id]['DOB'] = "";
		}
		else{
			$child_data[$child_id]['DOB'] = $_POST['child_' . $child_id . '_dob'];
		}
		
		if($_POST['child_' . $child_id . '_father'] == "Other"){
			
			$child_data[$child_id]['father_name'] = $_POST['child_' . $child_id . '_father_custom'];
			$child_data[$child_id]['father_id'] = "";
			$father_data[$newFatherCount]['father_id'] = "";
			$father_data[$newFatherCount]['father_name'] = $_POST['child_' . $child_id . '_father_custom'];
			$father_data[$newFatherCount]['offending'] = "";
			$father_data[$newFatherCount]['in_custody_ind'] = "";
			$father_data[$newFatherCount]['in_custody_where'] = "";
			$father_data[$newFatherCount]['no_contact_ind'] = "";
			$father_data[$newFatherCount]['no_contact_entered'] = "";
			$father_data[$newFatherCount]['no_contact_vacated'] = "";
			$father_data[$newFatherCount]['recom'] = "";
			$father_data[$newFatherCount]['special_identifiers'] = "";
			
			$newFatherCount++;
		}
		else{
			$fatherPieces = explode("~", $_POST['child_' . $child_id . '_father']);
			
			$father_id = $fatherPieces[0];
			$child_data[$child_id]['father_id'] = $father_id;
			$child_data[$child_id]['father_name'] = $fatherPieces[1];
		
		}
		
		$child_data[$child_id]['father_type'] = $_POST['child_' . $child_id . '_father_type'];
		
		if(!empty($_POST['child_' . $child_id . '_special_identifiers'])){
			foreach($_POST['child_' . $child_id . '_special_identifiers'] as $si){
				$child_data[$child_id]['special_identifiers'][] = $si;
			}
		}
		else{
			$child_data[$child_id]['special_identifiers'] = "";
		}
		
		if(empty($_POST['child_' . $child_id . '_new_placement']) || ($_POST['child_' . $child_id . '_new_placement'] != "on")){
			$child_data[$child_id]['new_placement'] = "No";
		}
		else{
			$child_data[$child_id]['new_placement'] = "Yes";
		}
		
		if(empty($_POST['child_' . $child_id . '_where'])){
			$child_data[$child_id]['child_where'] = "";
		}
		else{
			$child_data[$child_id]['child_where'] = $_POST['child_' . $child_id . '_where'];
		}
		
		if(empty($_POST['child_' . $child_id . '_who'])){
			$child_data[$child_id]['child_with_whom'] = "";
		}
		else{
			$child_data[$child_id]['child_with_whom'] = $_POST['child_' . $child_id . '_who'];
		}
		
		if(empty($_POST['child_' . $child_id . '_address'])){
			$child_data[$child_id]['child_address'] = "";
		}
		else{
			$child_data[$child_id]['child_address'] = $_POST['child_' . $child_id . '_address'];
		}
		
		if(empty($_POST['child_' . $child_id . '_date_placed'])){
			$child_data[$child_id]['child_date_placed'] = "";
		}
		else{
			$child_data[$child_id]['child_date_placed'] = date("Y-m-d", strtotime($_POST['child_' . $child_id . '_date_placed']));
		}
		
		if(empty($_POST['child_' . $child_id . '_home_study_ind'])){
			$child_data[$child_id]['home_study_ind'] = "";
			$child_data[$child_id]['home_study_date'] = "";
		}
		else{
			if($_POST['child_' . $child_id . '_home_study_ind'] == 'Yes'){
				$child_data[$child_id]['home_study_ind'] = 1;
					
				if(!empty($_POST['child_' . $child_id . '_home_study_approved_date'])){
					$child_data[$child_id]['home_study_approved_date'] = date("Y-m-d", strtotime($_POST['child_' . $child_id . '_home_study_approved_date']));
				}
				else{
					$child_data[$child_id]['home_study_approved_date'] = "";
				}
				
				if(!empty($_POST['child_' . $child_id . '_home_study_filed_date'])){
					$child_data[$child_id]['home_study_filed_date'] = date("Y-m-d", strtotime($_POST['child_' . $child_id . '_home_study_filed_date']));
				}
				else{
					$child_data[$child_id]['home_study_filed_date'] = "";
				}
					
			}
			else{
				$child_data[$child_id]['home_study_ind'] = 0;
				$child_data[$child_id]['home_study_approved_date'] = "";
				$child_data[$child_id]['home_study_filed_date'] = "";
			}
		}
		
		if(empty($_POST['child_' . $child_id . '_tico'])){
			$child_data[$child_id]['tico'] = "";
		}
		else{
			if($_POST['child_' . $child_id . '_tico'] == 'Yes'){
				$tico = 1;
			}
			else{
				$tico = 0;
			}
			$child_data[$child_id]['tico'] = $tico;
		}
		
		if(empty($_POST['child_' . $child_id . '_notes'])){
			$child_data[$child_id]['notes'] = "";
		}
		else{
			$child_data[$child_id]['notes'] = trim($_POST['child_' . $child_id . '_notes']);
		}

	}
	
	if(!empty($_POST['event_date'])){
		$event_date = date("Y-m-d", strtotime($_POST['event_date']));
	}
	else{
		$event_date = "";
	}
	
	if(!empty($_POST['event_notes'])){
		$event_notes = $_POST['event_notes'];
	}
	else{
		$event_notes = "";
	}
	
	if(!empty($event_date) && !empty($event_notes)){
		$args = array();
		$args['case_number'] = $case_number;
		$args['case_id'] = $case_id;
		$args['event_date'] = $event_date;
		$args['event_note'] = $event_notes;
		$args['user'] = $_SESSION['user'];
		
		$insertQuery = "	INSERT INTO 
							case_management.juv_event_notes
							(
								case_number,
								case_id,
								event_date,
								event_note,
								created_user,
								created_time,
								last_updated_user,
								last_updated_time
							)
							VALUES
							(
								:case_number,
								:case_id,
								:event_date,
								:event_note,
								:user,
								NOW(),
								:user,
								NOW()
							)";
		
		doQuery($insertQuery, $dbh, $args);
	}
	
	foreach($child_data as $key => $c){
		//Check if child exists..
		
		//Attorneys
		if(!empty($c['attorneys'])){
			foreach($c['attorneys'] as $a){
				if(!empty($a['attorney_id'])){
					$updateAttyQuery = "UPDATE case_management.juv_attorneys
										SET attorney_type = :attorney_type,
										attorney_name = :attorney_name,
										active = :active,
										last_updated_user = :user,
										last_updated_time = NOW()
										WHERE case_id = :case_id
										AND person_id = :person_id
										AND juv_attorney_id = :attorney_id";
						
					$args = array();
					$args['attorney_type'] = $a['type'];
					$args['attorney_name'] = $a['name'];
					$args['active'] = $a['active'];
					$args['user'] = $_SESSION['user'];
					$args['case_id'] = $case_id;
					$args['person_id'] = $key;
					$args['attorney_id'] = $a['attorney_id'];
						
					doQuery($updateAttyQuery, $dbh, $args);
				}
				else{
					
					$insertAttyQuery = "INSERT INTO case_management.juv_attorneys
										(
											case_number,
											case_id,
											person_id,
											attorney_type,
											attorney_name,
											active,
											created_user,
											created_time,
											last_updated_user,
											last_updated_time
										)
										VALUES
										(
											:case_number,
											:case_id,
											:person_id,
											:attorney_type,
											:attorney_name,
											:active,
											:user,
											NOW(),
											:user,
											NOW()
										)";
						
					$args = array();
					$args['case_number'] = $case_number;
					$args['attorney_type'] = $a['type'];
					$args['attorney_name'] = $a['name'];
					$args['active'] = $a['active'];
					$args['user'] = $_SESSION['user'];
					$args['case_id'] = $case_id;
					$args['person_id'] = $key;
						
					doQuery($insertAttyQuery, $dbh, $args);
				}
			}
		}
		
		//Psych meds....
		if(!empty($c['psych_meds'])){
			
			//Delete them first.  Then we will re-enter them.
			$delQuery = "DELETE FROM case_management.juv_psych_meds
						WHERE case_id = :case_id
						AND person_id = :person_id";
			
			doQuery($delQuery, $dbh, array("case_id" => $case_id, "person_id" => $key));
			
			foreach($c['psych_meds'] as $p){
					$insertPMQuery = "INSERT INTO case_management.juv_psych_meds
										(
											case_number,
											case_id,
											person_id,
											psych_meds_requested_by,
											psych_meds_requested_date,
											psych_meds_affidavit_ind,
											psych_meds_order_ind,
											psych_meds_order_date,
											psych_meds,
											created_user,
											created_time,
											last_updated_user,
											last_updated_time
										)
										VALUES
										(
											:case_number,
											:case_id,
											:person_id,
											:requested_by,
											:requested_date,
											:affidavit_filed,
											:order_filed,
											:order_date,
											:meds,
											:user,
											NOW(),
											:user,
											NOW()
										)";
		
					$args = array();
					$args['case_number'] = $case_number;
					$args['requested_by'] = $p['requested_by'];
					$args['requested_date'] = $p['requested_date'];
					$args['affidavit_filed'] = $p['affidavit_filed'];
					$args['order_filed'] = $p['order_filed'];
					$args['order_date'] = $p['order_date'];
					$args['meds'] = $p['meds'];
					$args['user'] = $_SESSION['user'];
					$args['case_id'] = $case_id;
					$args['person_id'] = $key;
		
					doQuery($insertPMQuery, $dbh, $args);
			}
		}
		
		$deleteSIQuery = "	DELETE FROM case_management.juv_identifiers
							WHERE case_id = :case_id
							AND person_id = :person_id";
				
		doQuery($deleteSIQuery, $dbh, array("case_id" => $case_id, "person_id" => $key));

		if(!empty($c['special_identifiers'])){
			foreach($c['special_identifiers'] as $si){
				$insertSIQuery = "	INSERT INTO case_management.juv_identifiers
									(
										case_number,
										case_id,
										person_id,
										identifier_desc,
										created_user,
										created_time,
										last_updated_user,
										last_updated_time
									)
									VALUES
									(
										:case_number,
										:case_id,
										:person_id,
										:identifier_desc,
										:user,
										NOW(),
										:user,
										NOW()
									)";
			
				$args = array();
				$args['case_number'] = $case_number;
				$args['case_id'] = $case_id;
				$args['person_id'] = $key;
				$args['identifier_desc'] = $si;
				$args['user'] = $_SESSION['user'];
			
				if(!empty($si)){
					doQuery($insertSIQuery, $dbh, $args);
				}
			}
		}
		
		$query = "	SELECT COUNT(*) as ChildCount
					FROM case_management.juv_children
					WHERE case_id = :case_id
					AND person_id = :person_id";

		$row = getDataOne($query, $dbh, array("case_id" => $case_id, "person_id" => $key));
		if($row['ChildCount'] < 1){
			
			$args = array();
			$args['case_number'] = $case_number;
			$args['case_id'] = $case_id;
			$args['person_id'] = $key;
			$args['child_name'] = $c['name'];
			$args['dob'] = $c['DOB'];
			$args['father_name'] = $c['father_name'];
			$args['father_type'] = $c['father_type'];
			$args['mother_person_id'] = $mother_id;
			$args['child_where'] = $c['child_where'];
			$args['child_with'] = $c['child_with_whom'];
			$args['child_address'] = $c['child_address'];
			$args['child_date_placed'] = $c['child_date_placed'];
			$args['home_study_approved_date'] = $c['home_study_approved_date'];
			$args['home_study_order_date'] = $c['home_study_filed_date'];
			$args['notes'] = $c['notes'];
			$args['user'] = $_SESSION['user'];
			
			if(isset($c['father_id']) && !empty($c['father_id']) && ($c['father_id'] != 0)){
				$args['father_person_id'] = $c['father_id'];
			}
			
			$insertQuery = "INSERT INTO 
							case_management.juv_children
							(
								case_number,
								case_id,
								person_id,
								child_name,
								dob,";
			
			if(isset($args['father_person_id'])){
				$insertQuery .= "	father_person_id, ";
			}
			
			$insertQuery .= "
								father_name,
								type_of_father,
								mother_person_id,
								child_where,
								child_with,
								child_address,
								date_placed,
								home_study_ind,
								home_study_approved_date,
								home_study_filed_date,
								tico,
								notes,
								created_user,
								created_time,
								last_updated_user,
								last_updated_time
							)
							VALUES
							(
								:case_number,
								:case_id,
								:person_id,
								:child_name,
								:dob,";
			
			if(isset($args['father_person_id'])){
				$insertQuery .= "	:father_person_id, ";
			}

			$insertQuery .= 	":father_name,
								:father_type,
								:mother_person_id,
								:child_where,
								:child_with,
								:child_address,
								:child_date_placed,";
			
			if(strlen($c['home_study_ind'])){
				$insertQuery .= "	:home_study_ind, ";
				$args['home_study_ind'] = $c['home_study_ind'];
			}
			else{
				$insertQuery .= " NULL, ";
			}

			$insertQuery .= "	:home_study_approved_date,
								:home_study_order_date,";
			
			if(strlen($c['tico'])){
				$insertQuery .= "	:tico, ";
				$args['tico'] = $c['tico'];
			}
			else{
				$insertQuery .= " NULL, ";
			}
			
			$insertQuery .= "	:notes,
								:user,
								NOW(),
								:user,
								NOW()
							)";
			
			//Don't insert blank rows...
			if(!empty($c['father_name']) || !empty($c['father_person_id'])
					||!empty($c['child_where']) || !empty($c['child_with']) || !empty($c['child_address'])
					|| strlen($c['tico']) || strlen($c['home_study_ind']) || !empty($c['notes'])){
				doQuery($insertQuery, $dbh, $args);
			}
		}
		else{
			
			$args = array();
			$args['case_id'] = $case_id;
			$args['person_id'] = $key;
			$args['father_person_id'] = $c['father_id'];
			$args['father_name'] = $c['father_name'];
			$args['father_type'] = $c['father_type'];
			$args['child_where'] = $c['child_where'];
			$args['child_with'] = $c['child_with_whom'];
			$args['child_address'] = $c['child_address'];
			$args['child_date_placed'] = $c['child_date_placed'];
			$args['home_study_approved_date'] = $c['home_study_approved_date'];
			$args['home_study_order_date'] = $c['home_study_filed_date'];
			$args['notes'] = $c['notes'];
			$args['user'] = $_SESSION['user'];
			
			//Archive the placements if the WHERE/WITH/or ADDRESS has been updated
			$query = "	SELECT child_name,
						child_where,
						child_with,
						child_address,
						date_placed,
						home_study_ind,
						home_study_approved_date,
						home_study_filed_date
						FROM case_management.juv_children
						WHERE case_id = :case_id
						AND person_id = :person_id";
			
			$row = getDataOne($query, $dbh, array("case_id" => $case_id, "person_id" => $key));
			
			if($c['new_placement'] == "Yes" && (trim($row['child_where']) != trim($c['child_where']) || (trim($row['child_with']) != trim($c['child_with_whom']))
					|| (trim($row['child_address']) != trim($c['child_address'])))){
				$pArgs = array();
				$pArgs['case_number'] = $case_number;
				$pArgs['case_id'] = $case_id;
				$pArgs['person_id'] = $key;
				$pArgs['child_name'] = $row['child_name'];
				$pArgs['child_where'] = $row['child_where'];
				$pArgs['child_with'] = $row['child_with'];
				$pArgs['child_address'] = $row['child_address'];
				$pArgs['date_placed'] = $row['date_placed'];
				$pArgs['home_study_approved_date'] = $row['home_study_approved_date'];
				$pArgs['home_study_filed_date'] = $row['home_study_filed_date'];
				$pArgs['user'] = $_SESSION['user'];
				
				//Time to archive this record because the child moved.
				$insertQuery = "INSERT INTO
								case_management.juv_child_placement
								(
									case_number,
									case_id,
									person_id,
									child_name,
									child_where,
									child_with,
									child_address,
									date_placed,
									home_study_ind,
									home_study_approved_date,
									home_study_filed_date,
									created_user,
									created_time,
									last_updated_user,
									last_updated_time
								)
								VALUES
								(
									:case_number,
									:case_id,
									:person_id,
									:child_name,
									:child_where,
									:child_with,
									:child_address,
									:date_placed,";
				
				if(strlen($c['home_study_ind'])){
					$insertQuery .= "	:home_study_ind, ";
					$pArgs['home_study_ind'] = $c['home_study_ind'];
				}
				else{
					$insertQuery .= " NULL, ";
				}

				$insertQuery .= "   :home_study_approved_date,
									:home_study_filed_date,
									:user,
									NOW(),
									:user,
									NOW()
								)";
				
				doQuery($insertQuery, $dbh, $pArgs);
			}
			
			//This is an update....
			$updateQuery = "UPDATE case_management.juv_children
							SET father_person_id = :father_person_id,
								father_name = :father_name,
								type_of_father = :father_type,
								child_where = :child_where,
								child_with = :child_with,
								child_address = :child_address,
								date_placed = :child_date_placed,";
			
			if(strlen($c['home_study_ind'])){
				$updateQuery .= "	home_study_ind = :home_study_ind, ";
				$args['home_study_ind'] = $c['home_study_ind'];
			}
			else{
				$updateQuery .= " home_study_ind = NULL, ";
			}
			
			$updateQuery .= "	home_study_approved_date = :home_study_approved_date,
								home_study_filed_date = :home_study_order_date,";
			
			if(strlen($c['tico'])){
				$updateQuery .= "	tico = :tico, ";
				$args['tico'] = $c['tico'];
			}
			else{
				$updateQuery .= " tico = NULL, ";
			}
								
			$updateQuery .= "	notes = :notes,
								last_updated_user = :user,
								last_updated_time = NOW()
							WHERE case_id = :case_id
							AND person_id = :person_id"; 
			
			doQuery($updateQuery, $dbh, $args);
		}
	}
	
	foreach($father_data as $key => $f){
		//Now do father stuff
		//Check if Father exists..
		
		$updateChildRecord = false;
		
		$query = "		SELECT COUNT(*) as FatherCount
						FROM case_management.juv_fathers
						WHERE case_id = :case_id
						AND person_id = :person_id";
		
		$row = array();
		if(!empty($f['father_id'])){
			$row = getDataOne($query, $dbh, array("case_id" => $case_id, "person_id" => $f['father_id']));
		}
		
		if($row['FatherCount'] < 1 || (empty($f['father_id']))){
			//Insert
			$args = array();
			$args['case_number'] = $case_number;
			$args['case_id'] = $case_id;
			$args['person_id'] = $f['father_id'];
			$args['father_name'] = $f['father_name'];
			$args['in_custody_where'] = $f['in_custody_where'];
			$args['no_contact_entered'] = $f['no_contact_entered'];
			$args['no_contact_vacated'] = $f['no_contact_vacated'];
			$args['recom'] = $f['recom'];
			$args['shelter_dos'] = $f['shelter_dos'];
			$args['dependency_dos'] = $f['dependency_dos'];
			$args['supp_findings_dos'] = $f['supp_findings_dos'];
			$args['tpr_dos'] = $f['tpr_dos'];
			$args['arraignment_dos'] = $f['arraignment_dos'];
			$args['shelter_order_filed'] = $f['shelter_order_filed'];
			$args['dependency_order_filed'] = $f['dependency_order_filed'];
			$args['supp_findings_order_filed'] = $f['supp_findings_order_filed'];
			$args['tpr_order_filed'] = $f['tpr_order_filed'];
			$args['arraignment_order_filed'] = $f['arraignment_order_filed'];
			$args['user'] = $_SESSION['user'];
			
			if(empty($f['father_id'])){
				//Get the current ID of fathers...
				$query = "	SELECT MAX(juv_father_id) AS current_id
				FROM case_management.juv_fathers";
				
				$row = getDataOne($query, $dbh);
				if(!empty($row)){
					$newFatherID = $row['current_id'] + 1;
				}
				else{
					$newFatherID = 1;
				}
				
				$args['person_id'] = $newFatherID;
				
				$updateChildRecord = true;
			}
			
			$insertQuery = "INSERT INTO 
							case_management.juv_fathers
							(
								case_number,
								case_id,
								person_id,
								father_name,
								offending,
								in_custody_ind,
								in_custody_where,
								no_contact_order,
								no_contact_entered,
								no_contact_vacated,
								recom,
								shelter_dos,
								arraignment_dos,
								dependency_dos,
								supp_findings_dos,
								tpr_dos,
								shelter_order_filed,
								arraignment_order_filed,
								dependency_order_filed,
								supp_findings_order_filed,
								tpr_order_filed,
								created_user,
								created_time,
								last_updated_user,
								last_updated_time
							)
							VALUES
							(
								:case_number,
								:case_id,
								:person_id,
								:father_name,";
			
			if(strlen($f['offending'])){
				$insertQuery .= "	:offending, ";
				$args['offending'] = $f['offending'];
			}
			else{
				$insertQuery .= " NULL, ";
			}
			
			if(strlen($f['in_custody_ind'])){
				$insertQuery .= "	:in_custody_ind, ";
				$args['in_custody_ind'] = $f['in_custody_ind'];
			}
			else{
				$insertQuery .= " NULL, ";
			}

			$insertQuery .= "	:in_custody_where,";
			
			if(strlen($f['no_contact_ind'])){
				$insertQuery .= "	:no_contact_ind, ";
				$args['no_contact_ind'] = $f['no_contact_ind'];
			}
			else{
				$insertQuery .= " NULL, ";
			}
								
			$insertQuery .= "	:no_contact_entered,
								:no_contact_vacated,
								:recom,
								:shelter_dos,
								:arraignment_dos,
								:dependency_dos,
								:supp_findings_dos,
								:tpr_dos,
								:shelter_order_filed,
								:arraignment_order_filed,
								:dependency_order_filed,
								:supp_findings_order_filed,
								:tpr_order_filed,
								:user,
								NOW(),
								:user,
								NOW()
							)";
			
			//Do this if it's a brand new father, or if we actually entered stuff about an existing father
			if(empty($f['father_id']) || strlen($f['offending']) || strlen($f['in_custody_ind']) || strlen($f['in_custody_where']) || strlen($f['no_contact_ind'])
			|| strlen($f['recom']) || strlen($f['shelter_dos']) || strlen($f['arraignment_dos']) || strlen($f['dependency_dos'])
			|| strlen($f['supp_findings_dos']) || strlen($f['tpr_dos']) || strlen($f['shelter_order_filed']) || strlen($f['arraignment_order_filed'])
			|| strlen($f['dependency_order_filed']) || strlen($f['supp_findings_order_filed']) || strlen($f['tpr_order_filed'])){
				doQuery($insertQuery, $dbh, $args);
			
				if($updateChildRecord){
					$args = array();
					$args['case_id'] = $case_id;
					$args['new_father_id'] = $newFatherID;
					$args['father_name'] = $f['father_name'];
					$query = "	UPDATE case_management.juv_children
								SET father_person_id = :new_father_id
								WHERE case_id = :case_id
								AND father_name = :father_name";
					
					doQuery($query, $dbh, $args);
				}
			}
		}
		else{
			$args = array();
			$args['case_id'] = $case_id;
			$args['person_id'] = $f['father_id'];
			$args['father_name'] = $f['father_name'];
			$args['in_custody_where'] = $f['in_custody_where'];
			$args['no_contact_entered'] = $f['no_contact_entered'];
			$args['no_contact_vacated'] = $f['no_contact_vacated'];
			$args['recom'] = $f['recom'];
			$args['shelter_dos'] = $f['shelter_dos'];
			$args['dependency_dos'] = $f['dependency_dos'];
			$args['supp_findings_dos'] = $f['supp_findings_dos'];
			$args['tpr_dos'] = $f['tpr_dos'];
			$args['arraignment_dos'] = $f['arraignment_dos'];
			$args['shelter_order_filed'] = $f['shelter_order_filed'];
			$args['dependency_order_filed'] = $f['dependency_order_filed'];
			$args['supp_findings_order_filed'] = $f['supp_findings_order_filed'];
			$args['tpr_order_filed'] = $f['tpr_order_filed'];
			$args['arraignment_order_filed'] = $f['arraignment_order_filed'];
			$args['user'] = $_SESSION['user'];
				
			//This is an update....
			$updateQuery = "UPDATE case_management.juv_fathers
							SET person_id = :person_id,
								father_name = :father_name,";
			
			if(strlen($f['offending'])){
				$updateQuery .= "	offending = :offending, ";
				$args['offending'] = $f['offending'];
			}
			else{
				$updateQuery .= " offending = NULL, ";
			}
			
			if(strlen($f['in_custody_ind'])){
				$updateQuery .= "	in_custody_ind = :in_custody_ind, ";
				$args['in_custody_ind'] = $f['in_custody_ind'];
			}
			else{
				$updateQuery .= " in_custody_ind = NULL, ";
			}

			$updateQuery .= "	in_custody_where = :in_custody_where,";
			
			if(strlen($f['no_contact_ind'])){
				$updateQuery .= "	no_contact_order = :no_contact_ind, ";
				$args['no_contact_ind'] = $f['no_contact_ind'];
			}
			else{
				$updateQuery .= " no_contact_order = NULL, ";
			}

			$updateQuery .= "	no_contact_entered = :no_contact_entered,
								no_contact_vacated = :no_contact_vacated,
								recom = :recom,
								shelter_dos = :shelter_dos,
								arraignment_dos = :arraignment_dos,
								dependency_dos = :dependency_dos,
								supp_findings_dos = :supp_findings_dos,
								tpr_dos = :tpr_dos,
								shelter_order_filed = :shelter_order_filed,
								arraignment_order_filed = :arraignment_order_filed,
								dependency_order_filed = :dependency_order_filed,
								supp_findings_order_filed = :supp_findings_order_filed,
								tpr_order_filed = :tpr_order_filed,
								last_updated_user = :user,
								last_updated_time = NOW()
							WHERE case_id = :case_id
							AND person_id = :person_id";
				
			doQuery($updateQuery, $dbh, $args);
		}
		
		//Father no contact
		//Erase all of them and we'll rewrite them
		
		$query = "	DELETE FROM case_management.juv_no_contact_parties
					WHERE case_id = :case_id
					AND person_id = :person_id";
		doQuery($query, $dbh, array("case_id" => $case_id, "person_id" => $f['father_id']));
		
		if(!empty($_POST['father_' . $f['father_id'] . '_no_contact_with'])){
			//Go through all the people...
			foreach($_POST['father_' . $f['father_id'] . '_no_contact_with'] as $nc){
				$query = "	INSERT INTO case_management.juv_no_contact_parties
						(
							case_number,
							case_id,
							person_id,
							no_contact_with_person_id,
							created_user,
							created_time,
							last_updated_user,
							last_updated_time
						)
						VALUES
						(
							:case_number,
							:case_id,
							:person_id,
							:no_contact_with_person_id,
							:user,
							NOW(),
							:user,
							NOW()
						)";
					
				$args = array();
				$args['case_number'] = $case_number;
				$args['case_id'] = $case_id;
				$args['person_id'] = $f['father_id'];
				$args['no_contact_with_person_id'] = $nc;
				$args['user'] = $_SESSION['user'];
					
				doQuery($query, $dbh, $args);
			}
		}
		
		
		$deleteSIQuery = "	DELETE FROM case_management.juv_identifiers
							WHERE case_id = :case_id
							AND person_id = :person_id";
				
		doQuery($deleteSIQuery, $dbh, array("case_id" => $case_id, "person_id" => $f['father_id']));

		if(!empty($f['special_identifiers'])){
			foreach($f['special_identifiers'] as $si){
				$insertSIQuery = "	INSERT INTO case_management.juv_identifiers
									(
										case_number,
										case_id,
										person_id,
										identifier_desc,
										created_user,
										created_time,
										last_updated_user,
										last_updated_time
									)
									VALUES
									(
										:case_number,
										:case_id,
										:person_id,
										:identifier_desc,
										:user,
										NOW(),
										:user,
										NOW()
									)";
		
				$args = array();
				$args['case_number'] = $case_number;
				$args['case_id'] = $case_id;
				$args['person_id'] = $f['father_id'];
				$args['identifier_desc'] = $si;
				$args['user'] = $_SESSION['user'];
		
				if(!empty($si)){
					doQuery($insertSIQuery, $dbh, $args);
				}
			}
		}
	}
	
	//Now do Mother stuff...
	
	
	$deleteSIQuery = "	DELETE FROM case_management.juv_identifiers
							WHERE case_id = :case_id
							AND person_id = :person_id";
			
	doQuery($deleteSIQuery, $dbh, array("case_id" => $case_id, "person_id" => $mother_id));
	
	if(!empty($mother['special_identifiers'])){		
		foreach($mother['special_identifiers'] as $si){
			$insertSIQuery = "	INSERT INTO case_management.juv_identifiers
									(
										case_number,
										case_id,
										person_id,
										identifier_desc,
										created_user,
										created_time,
										last_updated_user,
										last_updated_time
									)
									VALUES
									(
										:case_number,
										:case_id,
										:person_id,
										:identifier_desc,
										:user,
										NOW(),
										:user,
										NOW()
									)";
	
			$args = array();
			$args['case_number'] = $case_number;
			$args['case_id'] = $case_id;
			$args['person_id'] = $mother_id;
			$args['identifier_desc'] = $si;
			$args['user'] = $_SESSION['user'];
	
			if(!empty($si)){
				doQuery($insertSIQuery, $dbh, $args);
			}
		}
	}
	
	$query = "		SELECT COUNT(*) as MotherCount
					FROM case_management.juv_mothers
					WHERE case_id = :case_id
					AND person_id = :person_id";
	
	$row = getDataOne($query, $dbh, array("case_id" => $case_id, "person_id" => $mother_id));
	if($row['MotherCount'] < 1){
		//Insert
		$args = array();
		$args['case_number'] = $case_number;
		$args['case_id'] = $case_id;
		$args['person_id'] = $mother_id;
		$args['mother_name'] = $mother_name;
		$args['in_custody_where'] = $mother_in_custody_where;
		$args['no_contact_entered'] = $mother_no_contact_entered;
		$args['no_contact_vacated'] = $mother_no_contact_vacated;
		$args['recom'] = $mother_recom;
		$args['shelter_dos'] = $mother_shelter_dos;
		$args['arraignment_dos'] = $mother_arraignment_dos;
		$args['dependency_dos'] = $mother_dependency_dos;
		$args['supp_findings_dos'] = $mother_supp_findings_dos;
		$args['tpr_dos'] = $mother_tpr_dos;
		$args['shelter_order_filed'] = $mother_shelter_order_filed;
		$args['arraignment_order_filed'] = $mother_arraignment_order_filed;
		$args['dependency_order_filed'] = $mother_dependency_order_filed;
		$args['supp_findings_order_filed'] = $mother_supp_findings_order_filed;
		$args['tpr_order_filed'] = $mother_tpr_order_filed;
		$args['user'] = $_SESSION['user'];
			
		$insertQuery = "INSERT INTO
						case_management.juv_mothers
						(
							case_number,
							case_id,
							person_id,
							mother_name,
							offending,
							in_custody_ind,
							in_custody_where,
							no_contact_order,
							no_contact_entered,
							no_contact_vacated,
							recom,
							shelter_dos,
							arraignment_dos,
							dependency_dos,
							supp_findings_dos,
							tpr_dos,
							shelter_order_filed,
							arraignment_order_filed,
							dependency_order_filed,
							supp_findings_order_filed,
							tpr_order_filed,
							created_user,
							created_time,
							last_updated_user,
							last_updated_time
						)
						VALUES
						(
							:case_number,
							:case_id,
							:person_id,
							:mother_name,";
		
			if(strlen($mother_offending)){
				$insertQuery .= "	:offending, ";
				$args['offending'] = $mother_offending;
			}
			else{
				$insertQuery .= " NULL, ";
			}
				
			if(strlen($mother_in_custody_ind)){
				$insertQuery .= "	:in_custody_ind, ";
				$args['in_custody_ind'] = $mother_in_custody_ind;
			}
			else{
				$insertQuery .= " NULL, ";
			}
			
			$insertQuery .= "	:in_custody_where,";
				
			if(strlen($mother_no_contact_ind)){
				$insertQuery .= "	:no_contact_ind, ";
				$args['no_contact_ind'] = $mother_no_contact_ind;
			}
			else{
				$insertQuery .= " NULL, ";
			}

			$insertQuery .= ":no_contact_entered,
							:no_contact_vacated,
							:recom,
							:shelter_dos,
							:arraignment_dos,
							:dependency_dos,
							:supp_findings_dos,
							:tpr_dos,
							:shelter_order_filed,
							:arraignment_order_filed,
							:dependency_order_filed,
							:supp_findings_order_filed,
							:tpr_order_filed,
							:user,
							NOW(),
							:user,
							NOW()
						)";
		
		//Only do this if we actually entered info...
		if(strlen($mother_offending) || strlen($mother_in_custody_ind) || strlen($mother_in_custody_where) || strlen($mother_no_contact_ind)
			|| strlen($mother_recom) || strlen($mother_shelter_dos) || strlen($mother_arraignment_dos) || strlen($mother_dependency_dos)
			|| strlen($mother_supp_findings_dos) || strlen($mother_tpr_dos) || strlen($mother_shelter_order_filed) || strlen($mother_arraignment_order_filed)
			|| strlen($mother_dependency_order_filed) || strlen($mother_supp_findings_order_filed) || strlen($mother_tpr_order_filed)){
			doQuery($insertQuery, $dbh, $args);
		}
	}
	else{
		$args = array();
		$args['case_id'] = $case_id;
		$args['person_id'] = $mother_id;
		$args['mother_name'] = $mother_name;
		$args['in_custody_where'] = $mother_in_custody_where;
		$args['no_contact_entered'] = $mother_no_contact_entered;
		$args['no_contact_vacated'] = $mother_no_contact_vacated;
		$args['recom'] = $mother_recom;
		$args['shelter_dos'] = $mother_shelter_dos;
		$args['arraignment_dos'] = $mother_arraignment_dos;
		$args['dependency_dos'] = $mother_dependency_dos;
		$args['supp_findings_dos'] = $mother_supp_findings_dos;
		$args['tpr_dos'] = $mother_tpr_dos;
		$args['shelter_order_filed'] = $mother_shelter_order_filed;
		$args['arraignment_order_filed'] = $mother_arraignment_order_filed;
		$args['dependency_order_filed'] = $mother_dependency_order_filed;
		$args['supp_findings_order_filed'] = $mother_supp_findings_order_filed;
		$args['tpr_order_filed'] = $mother_tpr_order_filed;
		$args['user'] = $_SESSION['user'];
		
		//This is an update....
		$updateQuery = "UPDATE case_management.juv_mothers
							SET person_id = :person_id,
								mother_name = :mother_name,";
		
		if(strlen($mother_offending)){
			$updateQuery .= "	offending = :offending, ";
			$args['offending'] = $mother_offending;
		}
		else{
			$updateQuery .= " offending = NULL, ";
		}
			
		if(strlen($mother_in_custody_ind)){
			$updateQuery .= "	in_custody_ind = :in_custody_ind, ";
			$args['in_custody_ind'] = $mother_in_custody_ind;
		}
		else{
			$updateQuery .= " in_custody_ind = NULL, ";
		}
		
		$updateQuery .= "	in_custody_where = :in_custody_where,";
			
		if(strlen($mother_no_contact_ind)){
			$updateQuery .= "	no_contact_order = :no_contact_order, ";
			$args['no_contact_order'] = $mother_no_contact_ind;
		}
		else{
			$updateQuery .= " no_contact_order = NULL, ";
		}
							
		$updateQuery .= "		no_contact_entered = :no_contact_entered,
								no_contact_vacated = :no_contact_vacated,
								recom = :recom,
								shelter_dos = :shelter_dos,
								arraignment_dos = :arraignment_dos,
								dependency_dos = :dependency_dos,
								supp_findings_dos = :supp_findings_dos,
								tpr_dos = :tpr_dos,
								shelter_order_filed = :shelter_order_filed,
								arraignment_order_filed = :arraignment_order_filed,
								dependency_order_filed = :dependency_order_filed,
								supp_findings_order_filed = :supp_findings_order_filed,
								tpr_order_filed = :tpr_order_filed,
								last_updated_user = :user,
								last_updated_time = NOW()
							WHERE case_id = :case_id
							AND person_id = :person_id";
		
		doQuery($updateQuery, $dbh, $args);
	}
}


$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);

$smarty->assign('case_number', $case_number);
$smarty->display('case_management/juvenile.tpl');