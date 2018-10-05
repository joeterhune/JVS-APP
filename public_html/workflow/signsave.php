<?php

# signsave - saves the esig and annotations for this document 

include "../icmslib.php";

$docid=$_REQUEST[docid];
# if there's a sig0, there's a new signature to attach...
if ($_REQUEST["sig0"]!="") {  # we have a sig; update the db!...
   $ts=date("Y-m-d H:i:s");    # what time is it now...
   file_put_contents("php://stderr","$ts: signsave: $docid ".$_REQUEST["sig0"]."\n",FILE_APPEND);
   # append that timestamp to the sig field.
   $_REQUEST["sig0"].="~$ts";
   # update the DB with the sig info...
   list($type,$userid,$x,$y,$page,$role,$ts)=explode("~",$_REQUEST["sig0"]);
   if ($role=="JUDGE") { $prefix="judge"; }
   elseif ($role=="JA") { $prefix="ja"; }
   elseif ($role=="GM") { $prefix="gm"; }
   else { echo "unknown role $role"; exit; }
   $icms=db_connect("icms");
#   $q="update workflow set ${prefix}_id='$USER',${prefix}_x=$x,${prefix}_y=$y,${prefix}_pagenum=$page,${prefix}_time=CURRENT_TIMESTAMP where doc_id=$docid ";
   # parameterized version
   $q="update workflow set ${prefix}_id=?,${prefix}_x=?,${prefix}_y=?,${prefix}_pagenum=?,${prefix}_time=CURRENT_TIMESTAMP where doc_id=?";
   file_put_contents("php://stderr","$ts: signsave: $docid: query: $q\n",FILE_APPEND);   
   sqlexecp($icms,$q,array($USER,$x,$y,$page,$docid));
   sqlexecp($icms,"update workqueues set last_update=CURRENT_TIMESTAMP where queue=(select queue from workflow where doc_id=?)",array($docid));
}
#
# make a string of key-value pairs
#
foreach ($_REQUEST as $key=>$val) {
   $txt.="$key=$val\n";
}
# write contents to settings file...
file_put_contents("/var/www/icmsdata/workflow/documents/$docid.data",$txt);
# make a pdf with all current sigs and annotations...
`./gensigned.pl $docid`; 
echo "OK\n";
?>