<?php
# icms.php - PHP utilities for ICMS.
#
# figure out root directory path, and some other paths
#

date_default_timezone_set('America/New_York');

$ROOTPATH=$_SERVER['SCRIPT_FILENAME'];

if ($ROOTPATH=="") {
    $ROOTPATH=$HTTP_SERVER_VARS['SCRIPT_FILENAME'];
}
$ROOTPATH=str_replace("/var/www/html","",$ROOTPATH);

if (strpos($ROOTPATH,"secret")) {
    $ISSECRET++;
}
$ROOTPATH=str_replace("/secret","",$ROOTPATH);

if (strpos($ROOTPATH,"juv")) {
    $ISJUV++;
}

$ROOTPATH=str_replace("/juv","",$ROOTPATH);
$ROOTPATH=substr($ROOTPATH,0,strpos($ROOTPATH,"/",1));

$VIEWPATH="/cgi-bin$ROOTPATH";
if (isset($ISSECRET) && ($ISSECRET)) {
    $VIEWPATH.="/secret";
}

if (isset($ISJUV) && ($ISJUV)) {
    $VIEWPATH.="/juv";
}


function showheader($level,$rptdate,$title1,$title2,$help,$export) {
    global $ROOTPATH;
    $levelback=$level-1;
    echo <<<EOS
<html>
<head>
<title>$title1 - $title2</title>
<link rel="stylesheet" type="text/css" name="stylin" href="$ROOTPATH/icms1.css">
<script src="$ROOTPATH/icms.js" language="javascript" type="text/javascript">
</script>
</head>
<body onload=SetBack("ICMS_$level");>
<a href=index.php><img src=$ROOTPATH/icmslogo.jpg border=0></a><p>
<input type=button name=Back value=Back onClick=GoBack("ICMS_$levelback");>
EOS;
   if ($export!="") { print "&nbsp;&nbsp;&nbsp;<input type=button name=Export value=Export onClick=\"document.location='/cgi-bin$ROOTPATH/export.cgi?path=/var/www/html/$export&header=1'\";>"; }
   echo "<p>$rptdate<p>";
}

function fancydate($date) {
    $month = "";
    $day = "";
    $year = "";
    # Are there slashes?
    if (preg_match('/\//', $date)) {
	list($month,$day,$year)=explode('/',$date);
    };
    if ($month!="" and $day!="" and $year!="") {
	return date("l, F jS, Y",mktime(0,0,0,$month,$day,$year));
    } else {
	return($date);
    }
}

?>
