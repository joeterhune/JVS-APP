<?php
require_once ('../php-lib/common.php');
require_once ('../php-lib/db_functions.php');

include "../icmslib.php";

$id = getReqVal('id');
$code = getReqVal('code');
$name = getReqVal('name');
$desc = getReqVal('desc');
$type = getReqVal('type');
$vals = getReqVal('vals');
$def = getReqVal('def');

$dbh=dbConnect("icms");

if ($id==null) { # an add
   $res=sqlexecp($dbh,"insert into form_fields (field_code,field_name,field_description,field_type,field_values,field_default) values (?,?,?,?,?,?)",array($code,$name,$desc,$type,$vals,$def));
} else { # update
   $res=sqlexecp($dbh,"update form_fields set field_code=?, field_name=?, field_description=?,field_type=?,field_values=?,field_default=? where field_id=?",array($code,$name,$desc,$type,$vals,$def,$id));
}
#  echo "$id,$code,$name,$desc,$type,$vals,$def<p>";
echo header("Location: formfields.php");
?>