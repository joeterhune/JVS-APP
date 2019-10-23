<?php 

require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/common.php");
require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/db_functions.php");
require_once($_SERVER['JVS_DOCROOT'] . "/workflow/wfcommon.php");
require_once('Smarty/Smarty.class.php');

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);

$term = getReqVal('term');
$USER = $_SESSION['user'];
$dbh = dbConnect("icms");

$query = "
	select
		form_id AS id,
		form_name AS label,
		form_name AS value
	from
		forms
	where
		(is_private is null OR (is_private = 1 and shared_with like '%$USER%'))
		and ols_form = 0
		and form_name LIKE '%$term%'
	order by 
		form_name";

$forms = array();
getData($forms, $query, $dbh);

echo json_encode($forms);