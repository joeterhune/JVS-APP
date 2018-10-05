<font face=arial>
<h2>Download File for Editing</h2>
You can pull up the document for editing via the link below; when you're done working on the document, please e-mail it to <b>revise@icms3.circuit8.org</b>.<p>
<?php
$t=microtime();
$WEBPATH="/icmsdata/workflow/documents";
$docid=$_REQUEST[docid];
$list=glob("/var/www/$WEBPATH/$docid.dist.*");
$name=basename($list[0]);
echo "<a href=$WEBPATH/$name?t=$t>Download</a>";
?>
