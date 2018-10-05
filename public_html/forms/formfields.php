<?php
require_once ('../php-lib/common.php');
require_once ('../php-lib/db_functions.php');

include "../icmslib.php";
$dbh = dbConnect("icms");
$fields=sqlarrayp($dbh,"select field_id,field_code,field_name,field_description,field_type,field_values, field_default from form_fields order by field_name",array());
?>
<title>Form Field Definitions</title>
<style>
table,th,td {
   border: 1px solid black;
   padding: 3px
}
table.th { color:blue }
</style>
<font face=calibri,arial,helvetica>
<h3>Form Field Definitions</h3>
<input type=button value=Back onClick="window.location='index.php';"> <input type=button value=Add onClick="window.location='editfield.php';"><p>
<table style="border: 1px solid black; border-collapse:collapse">
<thead><tr><th>Name<th>Code<th>Type<th>Description<th>Actions</thead>
<tbody>
<?php
foreach ($fields as $x) {
   echo "<tr>";
   list($id,$code,$name,$desc,$type,$vals,$default)=$x;
   echo "<tr><td>$name<td>$code<td>$type<td>$desc<td><input type=button value='Edit' onClick=\"window.location='editfield.php?id=$id'\";> <input type=button value='Delete' onClick=\"window.location='deletefield.php?id=$id'\";>";
}
?>
</select>
</table><p>
</form>
