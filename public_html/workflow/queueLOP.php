<?php
require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/common.php");
require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/db_functions.php");

$divname = getReqVal('reportDiv');

$cases = array();

foreach ($_REQUEST as $key => $val) {
    if (!preg_match("/^flagLOP-/", $key)) {
        continue;
    }
    
    array_push($cases, $val);
}

$user = $_SESSION['user'];

$dbh = dbConnect("icms");
$dbh->beginTransaction();

$count = 0;

foreach ($cases as $case) {
    list($ucn, $casetype) = sanitizeCaseNumber($case);
    $query = "
        insert into
            lop_queue (
                case_num,
                ucn,
                division_id,
                queued_by,
                queued_date
            ) values (
                :casenum,
                :ucn,
                :division,
                :user,
                now()
            )
    ";
    doQuery($query, $dbh, array('casenum' => $case, 'ucn' => $ucn, 'division' => $divname,
                                'user' => $user));
    $count++;
}

# Create a record in div_lop_queues for this division if one doesn't already exist
$query = "
    replace into
        div_lop_queues (
            division_id,
            last_updated
        ) values (
            :division,
            now()
        )
";

doQuery($query, $dbh, array('division' => $divname));

# And automatically subscribe this user to that queue.
# First get the existing config
$query = "
    select
        json,
        id
    from
        config
    where
        user = :user
        and module = 'config'
";
$rec = getDataOne($query, $dbh, array('user' => $user));

$cfgId = $rec['id'];

$decoded = json_decode($rec['json'], true);
$bulkQueues = array();
$qname = sprintf("%s_lop", $divname);

if (array_key_exists('bulkqueues',$decoded)) {
    $bulkQueues = explode(',', $decoded['bulkqueues']);
}

if (!in_array($qname, $bulkQueues)){
    array_push($bulkQueues, $qname)   ;
}
# And rebuild the string
$decoded['bulkqueues'] = implode(",", $bulkQueues);

$newJson = json_encode($decoded);
$query = "
    update
        config
    set
        json = :newJson
    where
        id = :id
";

doQuery($query, $dbh, array('newJson' => $newJson, 'id' => $cfgId));

$dbh->commit();

$result = array();
$result['divname'] = $divname;
$result['queuedCount'] = $count;
returnJson($result);
exit;

?>