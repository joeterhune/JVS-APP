#!/usr/bin/php
<?php

function getxmlval($term,$str) {
   $i=strpos($str,"$term>");
   $j=strpos($str,"</ecf:$term");
   $adj=strlen($term)+1;
   $val=substr($str,$i+$adj,$j-$i-$adj);
   return $val;
}



function getidentid($term,$str) {
   $i=strpos($str,$term);
   $j=strrpos($str,"<nc:IdentificationID>",-(strlen($str)-$i));
   $k=strpos($str,"</nc:IdentificationID>",$j);
   $j+=strlen("<nc:IdentificationID>");
   $val=substr($str,$j,$k-$j);
   return $val;
}


#
# parsing approach
#
#$obj=simplexml_load_file("test.xml");
#if (!$obj) {
#   echo "error parsing\n";
#}
#print_r($obj);
#exit;

#$obj=simplexml_load_file("good.xml");
#print_r($obj); echo "\n\n\n";
#print_r($obj->MessageReceiptMessage); echo "\n";
##$json_string=json_encode($obj);
##echo $json_string,"\n";

#echo "**",obj->MessageReceiptMessage->DocumentIdentification,"***";
#exit;

#
# non-parsing approach
#
$file=file_get_contents("good.xml");
$errcode=getxmlval("ErrorCode",$file);
$errmsg=getxmlval("ErrorText",$file);
$fileid=getidentid("FLEPORTAL_FILING_ID",$file);
echo "$errcode:$errmsg:$fileid\n";
?>
