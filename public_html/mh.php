<?php
$fp=fopen($_SERVER['JVS_ROOT'] . "/conf/judgepage.conf","r");
$num=1;
while (!feof($fp)) {
  $line=fgets($fp,1024);
  $line=substr($line,0,-1);
  list($name,$div,$casetype)=explode('~',$line);
  $arr[]="$div~$casetype~$name";
}
fclose($fp);
sort($arr);

# now unified family court
foreach ($arr as $line) {
  list($div,$casetype,$name)=explode('~',$line);
  $seccasetype=explode(',',$casetype);

  if ((($casetype=="DR") || ($seccasetype[1]=="DR")) &&($div=="UFCL")) {
    $label="Linked Cases";
    echo "<li><a href=gensumm.php?rpath=case/Sarasota/civ/div$div/index.txt>$label</a>";
  }
}
foreach ($arr as $line) {
  list($div,$casetype,$name)=explode('~',$line);
  $seccasetype=explode(',',$casetype);

  if ((($casetype=="DR") || ($seccasetype[1]=="DR")) &&($div=="UFCT")) {
    $label="Transfered Cases";
    echo "<li><a href=gensumm.php?rpath=case/Sarasota/civ/div$div/index.txt>$label</a>";
  }
}
foreach ($arr as $line) {
  list($div,$casetype,$name)=explode('~',$line);
  $seccasetype=explode(',',$casetype);

  if ((($casetype=="DR") || ($seccasetype[1]=="DR")) &&($div=="UFJM")) {
    $label = "Judicial Memo";
    echo "<li><a href=gensumm.php?rpath=case/Sarasota/civ/div$div/index.txt>$label</a>";
  }
}
?>
