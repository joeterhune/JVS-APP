<?php 

include "/var/www/icms/icmslib.php";

$dbh=db_connect("icms");
$formid=13;
list($formbody,$formfields)=sqlgetonerowp($dbh,"select form_body,form_fields from forms where form_id=?",array($formid));
$fields=get_form_fields($formbody);
if ($formfields=="") { # build a new formdata 
   list($formfields,$errs)=build_form_fields_json($dbh,$fields);
} else {
   list($formfields,$errs)=merge_form_fields_json($dbh,$fields,$formfields);
}
if (count($errs)>0) {
   echo "<h2>Errors detected</h2>";
   echo implode("<p>",$errs);
}
sqlexecp($dbh,"update forms set form_fields='$formfields' where form_id=?",array($formid));

?>