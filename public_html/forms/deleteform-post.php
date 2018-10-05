<font face=calibri,arial,helvetica>
<?php
require_once("../php-lib/common.php");
require_once("../php-lib/db_functions.php");
require_once "../icmslib.php";

$dbh=dbConnect("icms");

$formid=getReqVal('form_id');

if ($formid!="") {
    $res=sqlexecp($dbh,"delete from forms where form_id=?",array($formid));
    if ($res) {
        echo "Form deleted.";
    } else {
        echo "Error deleting form.";
    }
} else {
    echo "Error: please select a form";
}
?>
<p><input type=button value=Back onclick="window.location='index.php';">
</form>
