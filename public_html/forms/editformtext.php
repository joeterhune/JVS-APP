<?php
require_once ('../php-lib/db_functions.php');
require_once('Smarty/Smarty.class.php');

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);

$dbh = dbConnect("icms");

$arr = array();
$query = "
    select
        form_id,
        form_name
    from
        forms
    order by
        form_name
";
getData($arr, $query, $dbh);
$smarty->assign('forms', $arr);

$query = "
    select
        field_code,
        field_name,
        field_description
    from
        form_fields
    order by
        field_name
";

$fields = array();
getData($fields, $query, $dbh);
$smarty->assign('formfields', $fields);

$smarty->display('forms/editformtext.tpl');
exit;

?>
