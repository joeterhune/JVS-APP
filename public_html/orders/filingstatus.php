#!/usr/bin/php
<?php

# filingstatus.php - returns the filing status for the filing id supplied...

include "/var/icms/web/icmslib.php";
include "/var/icms/phplib/efiling/efilelib.php";

#
# MAIN PROGRAM
#
$filingid=$argv[1];
if ($filingid=="") {
   echo "ERROR: no Filing ID supplied";
   exit;
}
$obj=get_filing_status($filingid);
$obj=get_filing_status($filingid);
echo $obj->FilingStatus,':',$obj->ErrorCode,':',$obj->ErrorText,"\n";
?>
