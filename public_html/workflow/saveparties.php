<?php
require_once("../php-lib/common.php");
require_once("../php-lib/db_functions.php");

include "../icmslib.php";
include "../caseinfo.php";

# saveparties.php - saves the party info provided by parties.php into
# a JSON object for future use by this case...

$ucn = getReqVal('ucn');

if ($ucn=="") {
    echo "Error: no UCN found!";
    exit;
}

list($ucn, $type) = sanitizeCaseNumber($ucn);



$vars = array_keys($_REQUEST);

$cclist = array();
$cclist['Attorneys'] = array();
$cclist['Parties'] = array();

$casestyle = getReqVal('wfcasestyle');

$temp = array();

foreach ($vars as $key) {
    if (!preg_match("/^cclist/", $key)) {
        continue;
    }
    $pieces = explode("_", $key);
    $index = $pieces[1];
    $sub = $pieces[2];
    if (!array_key_exists($index, $temp)) {
        $temp[$index] = array();
    }
    $temp[$index][$sub] = $_REQUEST[$key];
}

foreach (array_keys($temp) as $key) {
    array_push($cclist[$temp[$key]['list']], $temp[$key]);
}

//Remove blanks! 
if(!empty($cclist)){
	foreach($cclist as $key1 => $cl){
		foreach($cl as $key2 => $c){
			if(empty($c['FullName']) && empty($c['ServiceList']) && empty($c['FullAddress'])){
				unset($cclist[$key1][$key2]);
			}
			
			if(isset($c['custom']) && $c['custom'] == '1' && isset($c['ServiceList']) && !empty($c['ServiceList'])){
				//Remove it, but add this to re-use
				unset($cclist[$key1][$key2]['custom']);
				
				$emails = explode(";", $c['ServiceList']);
				
				foreach($emails as $e){
					$dbh = dbConnect("ols");
					$query = "SELECT COUNT(*) as count
							  FROM olscheduling.reuse_emails
							  WHERE casenum = :ucn
							  AND email_addr = :email";
					
					$row = getDataOne($query, $dbh, array("ucn" => $ucn, "email" => trim($e)));
					
					if($row['count'] < 1){
						//Add to re-use
						$query = "INSERT INTO 
								  olscheduling.reuse_emails
								  (casenum, email_addr)
								  VALUES 
								  (:ucn, :email)";
						
						doQuery($query, $dbh, array("ucn" => $ucn, "email" => trim($e)));
					}
				}
			}
		}
	}
}

$partydir="/usr/local/icms/workflow/parties";

if (!is_dir($partydir)) {
    mkdir($partydir);
}

save_party_address("$partydir/$ucn.parties.json",$cclist,$casestyle);
echo $partydir . "/" . $ucn . ".parties.json"; die;

$result = array();
$result['status'] = "Success";
$result['cclist'] = json_encode($cclist);

header('Content-type: application/json');
print json_encode($result)

?>