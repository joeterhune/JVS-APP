<?php
require_once ('../php-lib/common.php');
require_once ('../php-lib/db_functions.php');

include "../icmslib.php";
$dbh= dbConnect("icms");
$id = getReqVal('id');

if ($id != null) {
   $fields=sqlarrayp($dbh,"select field_id,field_code,field_name,field_description,field_type,field_values, field_default from form_fields where field_id=?",array($id));
} else {
   $fields=array();
}
?>
<title>Add/Edit Field</title>
<font face=calibri,arial,helvetica>
<h3>Add/Edit Field Definition</h3>
<form method=post action=editfield-post.php>
<table>
<?php
echo "<tr>";
$id = "";
$code = "";
$name = "";
$desc = "";
$type = "";
$vals = "";
$def = "";
if (sizeof($fields)) {
    list($id,$code,$name,$desc,$type,$vals,$def)=$fields[0];   
}
echo <<<EOS
<tr><td><b>Field Name<td><input type=text name="name" value="$name"><td>A short desciptive name of the field.
<tr><td><b>Field Code<td><input type=text name="code" value="$code"><td>The code used to reference this field in the document
<tr><td valign=top><b>Field Description<td><textarea style="width:600px;height:100px" name=desc>$desc</textarea><td>A longer description of the field, used as a "tool tip" when hovering over the field name
<tr><td><b>Field Type<td><select name="type">
<option>
EOS;
$opts=array("CHECKBOX"=>"Checkbox","DATE"=>"Date","TIME"=>"Time","SELECT"=>"Select (multiple choice)","GROUP"=>"Group of Fields","BUILTIN"=>"Built-in (provided by JVS)","ESIG"=>"E-signature related (provided by JVS)","TEXT"=>"Text (usually single line)","LONGTEXT"=>"Long Text (usually multiple line)");
foreach ($opts as $key=>$val) {
   if ($key==$type) { $chk="selected"; }
   else { $chk=""; }
   echo "<option value=$key $chk>$val";
}
echo <<<EOS
</select>
<td>The code used to reference this field in the document
<tr><td valign=top><b>Field Values<td><textarea style="width:600px;height:100px" name="vals">$vals</textarea><td>A list of possible values (used for Select fields)
</select>
<tr><td><b>Field Default Value<td><input type=text name="def" value="$def"><td>The default value for this field
</table><p>
<input type=hidden name=id value="$id">
EOS;
?>
<input type=submit value=Save>
<input type=button value=Cancel onClick="window.location='formfields.php';">
</form>
