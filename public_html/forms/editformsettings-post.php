<?php
require_once ('../php-lib/common.php');
require_once ('../php-lib/db_functions.php');

require_once('FirePHPCore/fb.php');
$firephp = FirePHP::getInstance(true);
$firephp->setEnabled(true); 

include "../icmslib.php";

$formid = getReqVal('form_id');
$formname = getReqVal('formname');
$countiesarr = getReqVal('counties');
$formdivs = getReqVal('formdivs');
$isprivate = getReqVal('is_private');
$sharedwith = getReqVal('shared_with');
$docdesc = getReqVal('doc_description');
$formfields = getReqVal('formfieldsjson');

$formarr = json_decode($formfields);

$dbh = dbConnect("icms");

if (sizeof($formarr)) {
    // Ok,since there are form fields specified (which there really always should be), we need to be sure that what's specified
    // in the JSON text has the correct type and defaults
    // To do that, we need to have an array of all of the defined types
    $allfields = array();
    $query = "
        select
            field_code,
            field_type,
            field_values,
            field_default
        from
            form_fields
        order by
            field_code
    ";
    getData($allfields, $query, $dbh, null, 'field_code', 1);
    foreach ($formarr as &$form) {
        $code = $form->{'field_code'};
        $form->{'field_type'} = $allfields[$code]['field_type'];
        $form->{'field_values'} = $allfields[$code]['field_values'];
        $form->{'field_default'} = $allfields[$code]['field_default'];
    }
}

$formfields = json_encode($formarr);

$counties = "";
if (!empty($countiesarr)) {
    for ($i=0;$i<count($countiesarr);$i++) {
        if ($i!=0) {
            $counties.=",";
        }
       $counties.=$countiesarr[$i];
   }
}

$divs = implode(",", $formdivs);
//if (!empty($formdivs)) { # some checked
//   for ($i=0;$i<count($formdivs);$i++) {
//       if ($i!=0) { $divs.=","; }
//       $divs.=$formdivs[$i];
//   }
//}
$query = "
    update
        forms
    set
        form_name = :formname,
        counties = :counties,
        case_types = :casetypes,
        is_private = :isprivate,
        shared_with = :sharedwith,
        efiling_document_description = :docdesc,
        form_fields = :formfields
    where
        form_id = :formid
";
$res = doQuery($query, $dbh, array('formname' => $formname, 'counties' => $counties, 'casetypes' => $divs,
                                   'isprivate' => $isprivate, 'sharedwith' => $sharedwith, 'docdesc' => $docdesc,
                                   'formfields' => $formfields, 'formid' => $formid));

if ($res < 0) {
    echo "Error saving form.";
} else {
    echo header("Location: index.php");
    exit;
}
?>
<p>
<input type=button value=Back onClick="window.location='index.php';">

