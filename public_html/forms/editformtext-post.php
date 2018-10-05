<?php
require_once ('../php-lib/common.php');
require_once ('../php-lib/db_functions.php');
require_once ('../icmslib.php');

require_once('FirePHPCore/fb.php');
$firephp = FirePHP::getInstance(true);
$firephp->setEnabled(true);

$formid = getReqVal('formid');
$formbody = getReqVal('editwindow');
$dbh = dbConnect("icms");
$formbody=str_replace("&nbsp;%]"," %]",$formbody);
// Strip the "data." from old-school form tags.
$formbody = preg_replace("/ data\./"," ",$formbody);
$formbody=str_replace("&gt;",">", $formbody);
$formbody=str_replace("&lt;","<", $formbody);
$formbody=str_replace("<li>[% END %]</li>","[% END %]",$formbody);
$formbody=preg_replace("#<li>\[\% IF (\w+) \%\]</li>#","[% IF $1 %]",$formbody);
$formbody = html_entity_decode($formbody);

$query = "
    update
        forms
    set
        form_body = :formbody,
        update_user = :updater
    where
        form_id = :formid
";

$args = array('formbody' => $formbody, 'formid' => $formid, 'updater' => $_SERVER['PHP_AUTH_USER']);
$res = doQuery($query,$dbh,array('formbody' => $formbody, 'formid' => $formid, 'updater' => $_SERVER['PHP_AUTH_USER']));

if ($res < 0) {
    echo "Error saving form.";
    exit;
} else {
    # OK, we save the form_body, now we must update the form_data field
    $fields=get_form_fields($formbody);
    
    $all_fields=implode(',',$fields);
    
    $query = "
        select
            form_fields
        from
            forms
        where
            form_id = :formid
    ";
    
    $foo = getDataOne($query, $dbh, array('formid' => $formid));
    $formfields['form_fields'] = isset($foo['form_fields'])  ? $foo['form_fields'] : "";
    
    list($formfields,$errs) = build_form_fields_json($dbh,$fields);
    
    $query = "
        update
            forms
        set
            form_fields = :formfields,
            all_fields = :all_fields
        where
            form_id = :formid
    ";
    
    $count = doQuery($query, $dbh, array('formfields' => $formfields, 'all_fields' => $all_fields, 'formid' => $formid));
    
    if (count($errs)>0) {
        echo "<h2>Errors detected</h2>";
        echo implode("<p>",$errs);
    } else {
        echo header("Location: index.php");
        exit;
    }
}
?>
<p>
<input type=button value=Back onClick="window.location='index.php';">
