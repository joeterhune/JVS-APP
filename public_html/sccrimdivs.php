<?php
# 06/21/10 lms showcase criminal divisions - based on alldivs.php
?>
<html>
<head>
   <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
   <meta name="GENERATOR" content="Mozilla/4.72 [en] (Windows NT 5.0; I) [Netscape]">
   <meta name="Author" content="Default">
   <title>15th Circuit Case Management System</title>
   <link rel="stylesheet" type="text/css" name="stylin" href="icms1.css">
<script src="icms.js" language="javascript" type="text/javascript"></script>
</head>
<body onLoad="SetBack('ICMS_1');">
<img src=icmslogo.jpg>
<font face=arial>
<p>
<input type=button name=Back value=Back onClick=GoBack("ICMS_0");>
<h1>All Showcase Criminal Divisions</h1>
<h2>Circuit Criminal</h2>
<ul>
<?php
$fp=fopen("/usr/local/icms/etc/scjudgepage.conf","r");
$num=1;
while (!feof($fp)) {
  $line=fgets($fp,1024);
  $line=substr($line,0,-1);
  list($name,$div,$casetype)=explode('~',$line);
  $arr[]="$div~$casetype~$name";
}
fclose($fp);
sort($arr);
# first, felony divisions
foreach ($arr as $line) {
  list($div,$casetype,$name)=explode('~',$line);
  $seccasetype=explode(',',$casetype);

  if ((($casetype=="CF") || ($seccasetype[1]=="CF")) && ($div!="CFMH")) {
       if ($div!="CFTD" && $div!="KK2") { # exclude CF and KK2 for Noel
          echo "<li><a href=gensumm.php?rpath=case/Palm/crim/div$div/index.txt>$div</a>";
	   }
  }
}
?>
</ul>
<h2>Mental Health Court</h2>
<ul>
<?php
foreach ($arr as $line) {
  list($div,$casetype,$name)=explode('~',$line);
  $seccasetype=explode(',',$casetype);

  if ((($casetype=="CF") || ($seccasetype[1]=="CF")) && ($div=="CFMH")) {
    echo "<li><a href=gensumm.php?rpath=case/Palm/crim/div$div/index.txt>$div</a>";
  }
}
?>
</ul>

<h2>County Criminal</h2>
<ul>
<?php
# now misdemeanor
# show all casetype MM except div F, casetype CF and div KK2, casetype TR and divs L, DM, N, SP, casetype IN
foreach ($arr as $line) {
  list($div,$casetype,$name)=explode('~',$line);
  $seccasetype=explode(',',$casetype);
  if ( ((($casetype=="MM") || ($seccasetype[1]=="MM")) && ($div!="F"))  ||
       ((($casetype=="CF") || ($seccasetype[1]=="CF")) && ($div=="KK2")) ||
	   ((($casetype=="TR") || ($seccasetype[1]=="TR")) && ($div=="L" || $div=="DM" || $div=="N")) ||
	   (($casetype=="IN") || ($seccasetype[1]=="IN")) ) {
	   # Noel wants KK2 excluded
	   if($div!="KK2") {
	   	  echo "<li><a href=gensumm.php?rpath=case/Palm/crim/div$div/index.txt>$div</a>";
	   }
  }
}
?>
</ul>


<h2>First Appearance</h2>
<ul>
<?php
foreach ($arr as $line) {
  list($div,$casetype,$name)=explode('~',$line);
  $seccasetype=explode(',',$casetype);
  if ( ((($casetype=="MM") || ($seccasetype[1]=="MM")) && ($div=="F")) ) {
    echo "<li><a href=gensumm.php?rpath=case/Palm/crim/div$div/index.txt>$div</a>";
  }
}
?>
</ul>


</font>
