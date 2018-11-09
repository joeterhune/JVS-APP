<?php
require_once(__DIR__ . "/../php-lib/common.php");
require_once(__DIR__ . "/../php-lib/db_functions.php");


extract($_REQUEST);

list($ucn, $type) = sanitizeCaseNumber($ucn);

$querycase = $ucn;
//$matches = array();
//if (preg_match("/(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)/",$querycase, $matches)) {
    // This is a Banner case number with no dashes.  Need to convert it for this purpose.
 //   $querycase = sprintf("%04d-%s-%06d", $matches[1], $matches[2], $matches[3]);
//}

$querycase2 = $ucn;
//$matches = array();
//if (preg_match("/(\d\d)-(\d\d\d\d)-(\D\D)-(\d\d\d\d\d\d)-(\D\D\D\D)-(\D\D)/", $querycase2, $matches)) {
 //   $querycase2 = sprintf("%04d-%s-%06d", $matches[2], $matches[3], $matches[4]);
//}


$result = array();

$result{'querycase'} =$querycase;

if (!isset($ucn)) {
    $result['status'] = "Failure";
    $result['message'] = "No UCN specified."; 
} else {
    $dbh = dbConnect("icms");

    $query = "
        select
            f.idnum as FlagID,
            f.userid as User,
            DATE_FORMAT(f.date,'%m/%d/%Y') as FlagDate,
            IFNULL(DATE_FORMAT(f.expires,'%m/%d/%Y'),'') as Expires,
            ft.dscr as FlagDesc
        from
            flags f,
            flagtypes ft
        where
            ( f.casenum = :ucn
            OR f.casenum = :ucn2 )
            and f.flagtype = ft.flagtype
        order by
            date desc
    ";
    
    $result['flags'] = array();
    getData($result['flags'], $query, $dbh, array('ucn' => $querycase, 'ucn2' => $querycase2));
    
    foreach ($result['flags'] as &$flag) {
        if (preg_match('/Requires Action|Judge/', $flag['FlagDesc'])) {
            $flag['Image'] = 'flag-red.gif';
        } else if (preg_match('/CM Action/', $flag['FlagDesc'])) {
            $flag['Image'] = 'flag-cm.gif';
        } else if (preg_match('/Quarantine/', $flag['FlagDesc'])) {
            $flag['Image'] = 'flag-jr.gif';
        } else {
            $flag['Image'] = 'flag.gif';
        }
    }
    
    $result['status'] = "Success";
    $result['ucn'] = $ucn;
    $result['casenum'] = $ucn;

}

returnJson($result);
exit;

?>