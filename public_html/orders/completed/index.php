<font face=arial>
<h2>Domestic Violence - Completed Orders</h2>
<?php
# completed.php - list completed domestic violence orders (in case one doesn't get sent down automatically...


function prettydate($date) {
  return substr($date,5,2)."/".substr($date,8,2)."/".substr($date,0,4);
}

#
# MAIN PROGRAM
#
$inpath="/var/www/icmsdata/workflow/orders/01-DV";
chdir($inpath);
$files=glob("*.pdf");
$list=array();
foreach ($files as $line) {
   array_push($list,filemtime($line).":$line");
}
rsort($list);
foreach ($list as $line) {
  list($ftime,$fname)=explode(":",$line);
  list($ucn,$date)=explode(".",$fname);
  if ($date!=$olddate) { echo "<b>",prettydate($date),"</b><br>"; }
  echo "<a href=/icmsdata/workflow/orders/01-DV/$fname style='padding-left:30px'>$ucn</a><br>";
  $olddate=$date;
}
?>
</font>