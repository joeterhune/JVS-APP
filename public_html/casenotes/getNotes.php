<?php
require_once(__DIR__ . "/../php-lib/common.php");
require_once(__DIR__ . "/../php-lib/db_functions.php");

extract($_REQUEST);

list($ucn, $type) = sanitizeCaseNumber($ucn);

$querycase = $ucn;
//$matches = array();
//if (preg_match("/(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)/",$querycase, $matches)) {
    // This is a Banner case number with no dashes.  Need to convert it for this purpose.
//    $querycase = sprintf("%04d%s%06d", $matches[1], $matches[2], $matches[3]); //Remove dashes for BenchMark
//}

$querycase2 = $ucn;
//$matches = array();
//if (preg_match("/(\d\d)-(\d\d\d\d)-(\D\D)-(\d\d\d\d\d\d)-(\D\D\D\D)-(\D\D)/", $querycase2, $matches)) {
 //   $querycase2 = sprintf("%04d%s%06d", $matches[2], $matches[3], $matches[4]); //Remove dashes for BenchMark
//}

$user = $_SESSION['user'];

$viewPrivate = array("'$user'");

// Has any other user shared private notes with this user?
$dbh = dbConnect("icms");

$query = "
    select
        json
    from
        config
    where
        user = :user
        and module = 'sharednotes'
";
$shares = getDataOne($query, $dbh, array('user' => $user));

if (array_key_exists('json', $shares)) {
    $shareusers = explode(",", $shares['json']);
    foreach ($shareusers as $share) {
        array_push($viewPrivate,"'$share'");
    }
}

$canView = implode(",", $viewPrivate);

$result = array();
if (!isset($ucn)) {
    $result['status'] = "Failure";
    $result['message'] = "No UCN specified."; 
} else {

    $query = "
        select
            cn.seq as NoteID,
            cn.userid as User,
            cn.date as NoteDate,
            cn.note as Note,
            CASE
                WHEN cn.private = 0 then 'N'
                ELSE 'Y'
            END as Private,
            cna.filename as Attachment
        from
            casenotes cn left outer join casenote_attachments cna on (cn.seq = cna.note_id)
        where
            ( casenum = :ucn
            OR casenum = :ucn2 )
            and ((private = 0) or (userid in ($canView)))
        order by
            date desc
    ";
    
    $result['notes'] = array();
    getData($result['notes'], $query, $dbh, array('ucn' => $querycase, 'ucn2' => $querycase2));
    
    if(!empty($result['notes'])){
    	foreach($result['notes'] as $key => $n){
    		$result['notes'][$key]['Note'] = mb_convert_encoding($result['notes'][$key]['Note'], 'HTML-ENTITIES', mb_detect_encoding($result['notes'][$key]['Note'], "auto"));
    	}
    }
    
    $result['status'] = "Success";
    $result['ucn'] = $ucn;
    $result['casenum'] = $ucn;
}

returnJson($result);
exit;

?>