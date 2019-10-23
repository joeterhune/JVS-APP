<?php

require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/db_functions.php");

function getQueues (&$queueItems, $queuelist, $dbh) {
	global $icmsXml;
	
	$xml = simplexml_load_file($icmsXml);
	foreach($xml->dbConfig as $dbc){
		if ($dbc->name == "vrb2") {
			$db = $dbc->dbName;
		}
	}
		
    // Run a separate query for each queue, so we're sure to have
    // a value for each queue, even if it's an empty array.
    $temp = array();
    foreach ($queuelist as $queue) {
        array_push($temp, "'$queue'");
    }
    $inString = implode(',', $temp);
    $query = "
        select
            doc_id,
            queue,
            ucn,
            w.case_style,
            title,
            w.color,
            creator,
            DATE_FORMAT(due_date,'%m/%d/%Y') as due_date,
            DATE_FORMAT(creation_date, '%m/%d/%Y') as creation_date,
            CASE
                WHEN due_date < CURDATE() then 'pastDue'
                WHEN due_date < (DATE_ADD(CURDATE(), INTERVAL 3 day)) then 'dueSoon'
                ELSE ''
            END as dueDateClass,
            CASE doc_type
                WHEN 'FORMORDER' then 'IGO'
                WHEN 'DVI' then 'DVI'
                WHEN 'MISCDOC' then 'Task'
                WHEN 'OLSORDER' then 'PropOrd'
                WHEN 'WARRANT' then 'Warrant'
                WHEN 'EMERGENCYMOTION' then 'EmerMot'
            END as doc_type,
            CASE
                WHEN signature_img is null then 'N'
                ELSE 'Y'
            END as esigned,
            CASE mailing_confirmed
                WHEN 0 then 'N'
                ELSE 'Y'
            END as mailed,
            CASE flagged
                WHEN 0 then 'N'
                ELSE 'Y'
            END as flagged,
            DATEDIFF(CURDATE(),DATE(creation_date)) as Age,
            CASE efile_completed
                WHEN 1 THEN 'Y'
                ELSE
                    CASE efile_submitted
                        WHEN 1 then 'S'
                        ELSE
                            CASE efile_queued
                                WHEN 1 then 'Q'
                                ELSE
                                    CASE efile_pended
                                        WHEN 1 then 'PQ'
                                        ELSE 'N'
                                    END
                            END
                    END
            END as efiled,
            comments,
            signed_filename,
            user_comments,
            DATE_FORMAT(e.start_date, '%m/%d/%Y') AS event_date,
            CASE 
            	WHEN e.event_name = '' OR e.event_name IS NULL
            	THEN 'No Event'
            	ELSE e.event_name
            END AS event_name,
            CASE
            	WHEN agreed = '1'
            	THEN 'Y'
            	WHEN agreed = '0'
            	THEN 'N'
            	ELSE ''
            END AS agreed
        from
            workflow w
        left outer join
        	$db.event_cases ec
        	on ec.event_cases_id = w.event_cases_id
        left outer join
        	$db.events e
        	on e.event_id = ec.event_id
        where
            queue in ($inString)
        and
            finished = 0
        and
        	deleted = 0
    ";
    
    getData($queueItems, $query, $dbh, array('queue' => $queue), 'queue');
	
    // Now count them and return that value.
    $count = 0;
	
	//if (is_array($queueItems)) {
		foreach (array_keys($queueItems) as $queue) {
			$count += sizeof($queueItems[$queue]);
		}
    
		foreach ($queuelist as $queue) {
		    // Ensure that there is an array element even if there is nothing in the queue
		    if (!array_key_exists($queue, $queueItems)) {
		        $queueItems[$queue] = array();
		    }
		}
	//}
    
    return $count;
}


function getSubscribedQueues ($user, $dbh, &$myqueues) {
    $query = "
        select
            json
        from
            config
        where
            user = :user
            and module = 'config'
    ";
    
    $config = getDataOne($query, $dbh, array('user' => $user));
    
    $chash = json_decode($config['json'],true);
    $queues = $chash['queues'];
    if (isset($queues) && ($queues != '')) {
        $myqueues = array_merge($myqueues,explode(",", $queues));
    }
}

function getSharedQueues ($user, $dbh, &$sharedqueues) {
    // How about queues shared with this user?
    $query = "
        select
            json
        from
            config
        where
            user = :user
            and module='sharedqueues'
    ";
    
    $config = getDataOne($query, $dbh, array('user' => $user));
    
    if (isset($config['json'])) {
        $sharedqueues = explode(",", $config['json']);
    }
}

function getTransferQueues ($user, $dbh, &$transferqueues){
	$jdbh = dbConnect("judge-divs");
	$config_array = array();
	$query = "
		select
			json
		from
			config
		where
			user = :user
		and
			(
				module = 'config'
				or module = 'sharedqueues'
			)";
	
	getData($config_array, $query, $dbh, array('user' => $user));
	
	foreach($config_array as $config){
		if (isset($config['json'])) {
			$json = json_decode($config['json'], true);
			if(isset($json['transfer_to']) && !empty($json['transfer_to'])){
				foreach(explode(",", $json['transfer_to']) as $t){
					$q = "
				        select
				            userid as QueueName,
				            first_name as FirstName,
				            middle_name as MiddleName,
				            last_name as LastName,
				            suffix as Suffix
				        from
				            users
						where
							userid = :userid";
				    $temp = getDataOne($q, $dbh, array("userid" => $t));
				    
				    if(!empty($temp)){
					    $queue = array('queue' => strtolower($temp['QueueName']));
					    $queue['queuedscr'] = buildName($temp);
					    
					    $found = false;
					    foreach($transferqueues as $tq){
					    	if($queue['queuedscr'] == $tq['queuedscr']){
					    		$found = true;
					    	}
					    }
					    
					    if(!$found){
					    	array_push($transferqueues, $queue);
					    }
				    }
				    else{
				    	$q = "select
					            division_id as DivisionID,
					            division_type as CourtType,
				    			'0' as CustomQueue
					        from
					            divisions
					        where
					            division_id = :userid
					        order by
					            DivisionID";
				    	
				    	$temp = getDataOne($q, $jdbh, array("userid" => $t));
				    	
				    	if(!empty($temp)){
					    	$queue = array('queue' => $temp['DivisionID']);
					    	$queue['queuedscr'] = $temp['CourtType'] . " Division " . $temp['DivisionID'];
					    	
					    	$found = false;
					    	foreach($transferqueues as $tq){
					    		if($queue['queuedscr'] == $tq['queuedscr']){
					    			$found = true;
					    		}
					    	}
					    	
					    	if(!$found){
					    		array_push($transferqueues, $queue);
					    	}
				    	}
				    	else{
				    		$q = "select
					            queue_name as DivisionID,
					            queue_type as CourtType,
				    			'1' as CustomQueue
					        from
					            custom_queues
					        where
					            queue_name = :userid
					        order by
					            queue_name";
				    	
				    		$temp = getDataOne($q, $jdbh, array("userid" => $t));
				    		
				    		if(!empty($temp)){
					    		$queue = array('queue' => $temp['DivisionID']);
						    	$queue['queuedscr'] = $temp['CourtType'];
						    	
						    	$found = false;
						    	foreach($transferqueues as $tq){
						    		if($queue['queuedscr'] == $tq['queuedscr']){
						    			$found = true;
						    		}
						    	}
						    	
						    	if(!$found){
						    		array_push($transferqueues, $queue);
						    	}
				    		}
				    	}
				    }
					
				}
			}
			else{
				foreach(explode(",", $config['json']) as $t){
					$q = "
					        select
					            userid as QueueName,
					            first_name as FirstName,
					            middle_name as MiddleName,
					            last_name as LastName,
					            suffix as Suffix
					        from
					            users
							where
								userid = :userid";
					$temp = getDataOne($q, $dbh, array("userid" => $t));
					if(!empty($temp)){
						$queue = array('queue' => strtolower($temp['QueueName']));
						$queue['queuedscr'] = buildName($temp);
						$found = false;
						foreach($transferqueues as $tq){
							if($queue['queuedscr'] == $tq['queuedscr']){
								$found = true;
							}
						}
						
						if(!$found){
							array_push($transferqueues, $queue);
						}
					}
					else{
						$q = "select
					            division_id as DivisionID,
					            division_type as CourtType,
				    			'0' as CustomQueue
					        from
					            divisions
					        where
					            division_id = :userid
					        order by
					            DivisionID";
				    	
				    	$temp = getDataOne($q, $jdbh, array("userid" => $t));
				    	
				    	if(!empty($temp)){
					    	$queue = array('queue' => $temp['DivisionID']);
					    	$queue['queuedscr'] = $temp['CourtType'] . " Division " . $temp['DivisionID'];
					    	
					    	$found = false;
					    	foreach($transferqueues as $tq){
					    		if($queue['queuedscr'] == $tq['queuedscr']){
					    			$found = true;
					    		}
					    	}
					    	
					    	if(!$found){
					    		array_push($transferqueues, $queue);
					    	}
				    	}
				    	else{
				    		$q = "select
					            queue_name as DivisionID,
					            queue_type as CourtType,
				    			'1' as CustomQueue
					        from
					            custom_queues
					        where
					            queue_name = :userid
					        order by
					            queue_name";
				    	
				    		$temp = getDataOne($q, $jdbh, array("userid" => $t));
				    		
				    		if(!empty($temp)){
					    		$queue = array('queue' => $temp['DivisionID']);
						    	$queue['queuedscr'] = $temp['CourtType'];
						    	
						    	$found = false;
						    	foreach($transferqueues as $tq){
						    		if($queue['queuedscr'] == $tq['queuedscr']){
						    			$found = true;
						    		}
						    	}
						    	
						    	if(!$found){
						    		array_push($transferqueues, $queue);
						    	}
				    		}
				    	}
					}
				}
			}
		}
	}
	
	//@todo I'd like to do this, but people don't want these in alphabetical order...
	/*function sortByQueueName($a, $b) {
		return $a['queuedscr'] > $b['queuedscr'];
	}
	
	usort($transferqueues, 'sortByQueueName');*/
}

function can_i_sign($esigs,$ROLE) {
    # ROLE is one of JUDGE,GM,JA,STAFF,NONE
    if (strpos($esigs,"judge_gm")!==false && (preg_match("/JUDGE/i",$ROLE) || $ROLE=="GM")) {
        return "JUDGE_GM";
    }
    if (strpos($esigs,"ja")!==false && $ROLE=="JA") {
        return "JA";
    }
    if (strpos($esigs,"gm")!==false && $ROLE=="GM") {
        return "GM";
    }
    if (strpos($esigs,"judge")!==false && preg_match("/JUDGE/i",$ROLE)) {
        return "JUDGE";
    }
    if (strpos($esigs,"clerk")!==false && $ROLE=="CLERK") {
        return "CLERK";
    }
    return "";
}


function updateQueue ($queue, $dbh) {
    $query = "
        update
            workqueues
        set
            last_update=CURRENT_TIMESTAMP
        where
            queue = :queue
    ";
    doQuery($query, $dbh, array('queue' => $queue));
}

function getSuppDocsForQueueItem($doc_id, $dbh){
	$args = array("doc_id" => $doc_id);
	$docs = array();

	$query = "	SELECT document_title,
				file,
				jvs_doc
				FROM olscheduling.supporting_documents
				WHERE workflow_id = :doc_id";

	getData($docs, $query, $dbh, $args);
	return $docs;

}

function getWFDocInfo($doc_id){
	$dbh = dbConnect("icms");
	$args = array("doc_id" => $doc_id);
	
	$query = "	SELECT creator,
				queue,
				ucn
				FROM workflow
				WHERE doc_id = :doc_id";
	
	$doc_row = getDataOne($query, $dbh, $args);
	return $doc_row;
}


?>