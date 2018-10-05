<?php
require_once ('../php-lib/common.php');
require_once ('../php-lib/db_functions.php');
require_once ('../icmslib.php');

fix_request(); # populates $_REQUEST if called from command line
$formid = getReqVal('form_id');

$dbh = dbConnect("icms");

$query = "
    select
        form_body
    from
        forms
    where
        form_id = :formid
";

$form = getDataOne($query, $dbh, array("formid" => $formid));

print $form['form_body'];
?>