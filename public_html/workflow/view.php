<?php
$WEBPATH="/icmsdata/workflow/documents";
$docid=$_REQUEST[docid];
$t=$_REQUEST[t];
`/var/www/icms/workflow/gensigned.pl $docid`;
header("Cache-Control: no-cache, must-revalidate"); // HTTP/1.1
header("Expires: Sat, 26 Jul 1997 05:00:00 GMT"); // Date in the past
if (file_exists("/var/www/$WEBPATH/$docid.pdf")) {
   header("Location: $WEBPATH/$docid.pdf?t=".$t);
} else { # nothing added; use .dist version 
   header("Location: $WEBPATH/$docid.dist.pdf?t=".$t);
}
?>
