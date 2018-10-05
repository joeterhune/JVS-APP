<head>
<title>Delete Form</title>
<?php
require_once("../php-lib/common.php");
require_once("../php-lib/db_functions.php");
require_once "../icmslib.php";

$dbh=dbConnect("icms");
$arr=sqlarrayp($dbh,"select form_id,form_name from forms order by form_name",array());

?>
<script src="/icms/javascript/jquery/jquery.min.js"></script>
<script src="/icms/javascript/ckeditor/ckeditor.js"></script>
<script src="/icms/javascript/ckeditor/adapters/jquery.js"></script>
</head>
<body>
<font face=calibri,arial,helvetica>
<form method=post action="deleteform-post.php">
Form to Delete: <select name=form_id>
<option>
<?php
foreach ($arr as $x) {
   list($formid,$formname)=$x;
   echo "<option value=$formid>$formname";
}
?>
</select><p> <input type=submit value=Delete> <input type=button value=Cancel onclick="window.location='index.php';">
</form>
</font>
</body>