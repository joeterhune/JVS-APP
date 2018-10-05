<?php
$DBH="";

#echo phpinfo();


$CONFIG[DBTYPE]="pgsql";
$CONFIG[DBHOST]="localhost";
$CONFIG[DBNAME]="casenotes";
$CONFIG[DBUSER]="postgres";
$CONFIG[DBPASS]="postgres"; # should trust...

sqlconnect();

?>
