<?php
require_once ('../php-lib/db_functions.php');
require_once('Smarty/Smarty.class.php');

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);

$dbh = dbConnect("icms");

$forms = array();

$query = "
    select
        form_id,
        form_name
    from
        forms
    order by
        form_name
";

getData($forms, $query, $dbh);

$smarty->assign('forms', $forms);

$smarty->display('forms/newform.tpl');
?>

