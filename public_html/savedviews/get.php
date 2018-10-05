<?php
require_once("../php-lib/common.php");
require_once("../php-lib/db_functions.php");

require_once('FirePHPCore/fb.php');
$firephp = FirePHP::getInstance(true);
$firephp->setEnabled(false); 


$casetype = getReqVal('casetype');
$user = $_SERVER['PHP_AUTH_USER'];

$dbh = dbConnect("icms");

$query = "
    select
        docket_code,
        load_order
    from
        user_docket_codes
    where
        userid = :userid
        and case_type = :casetype
    order by
        load_order asc
";

$codes = array();
getData($codes, $query, $dbh, array('userid' => $user, 'casetype' => $casetype));

returnJson($codes);
exit;

?>