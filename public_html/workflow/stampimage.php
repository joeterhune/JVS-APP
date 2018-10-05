#!/usr/bin/php
<?php
# stampimage - given a userid, a timestamp, a case #, a name, and a role
# returns the full path to a temporary file that contains the
# signature image for that user with the other info superimposed
# as a digital watermark...and the name and role superimposed at the bottom

include "/var/www/icms/icmslib.php";

list($p,$ucn,$userid,$ts,$name,$role)=$argv;
if ($ucn=="" || $userid=="" || $ts=="" || $name=="" || $role=="") {
   echo "Usage: stampimage.php ucn userid timestamp name role\n($ucn,$userid,$ts,$name,$role)";
   exit;
}
$icms=db_connect("icms");
$sigkey=sqlgetonep($icms,"SELECT setval FROM settings WHERE setkey='SIGKEY'",array());
$key=substr(base64_decode($sigkey),0,8);
$srcfile="/var/icms/conf/signatures/$userid.sig.dat";
$decryptfile=tempnam("/var/www/icmsdata/tmp","sig");
$filetext=file_get_contents($srcfile);
$plaintext=decrypt($filetext,$key);
file_put_contents($decryptfile,$plaintext);
$list=`/usr/bin/file $decryptfile`;
if (preg_match("/(\d+) x (\d+)/",$list,$matches)) {
   $iwidth=$matches[1];
   $iheight=$matches[2];
} else {
   echo "Error: couldn't determine with of signature file for $userid\n";
   exit;
}
$height=50; # 50 box height for 40 point text
$pointsize=40;
$outfile=tempnam("/var/www/icmsdata/tmp","sig");
unlink($outfile);
$outfile.=".png";
$botheight=$iheight-10;
system("convert $decryptfile -fill '#0015' -draw 'rectangle 0,0,$iwidth,$height' -fill white -pointsize $pointsize -draw \"gravity north fill black text 0,12 '$ucn $ts' fill white text 1,11 '$ucn $ts'\" -draw \"fill black text 0,$botheight '$name, $role'\" $outfile");
echo str_replace("/var/www","",$outfile);
?>
