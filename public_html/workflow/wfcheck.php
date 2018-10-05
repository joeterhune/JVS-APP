<?php 
# wfcheck.php - returns the last_updated column for each workqueue subscribed to
# and returns the list.

# this is called by the UpdateMainPage javascript function in main.js
# to see if any changes have been made in any of the subscribed work queues.

include "../icmslib.php";

$queues=$_REQUEST[queues];
$queues=str_replace("%2C",",",$queues);
$icms=db_connect("icms");
$sqlterm="('".str_replace(",","','",$queues)."')";
$sql="select queue,last_update from workqueues where queue in $sqlterm order by queue";
#file_put_contents('php://stderr',"wfcheck.php: running $sql\n",FILE_APPEND);
$arr=sqlarrayp($icms,$sql,array());
foreach ($arr as $line) {
   list($queue,$dt)=$line;
#    file_put_contents('php://stderr',"wfcheck.php: ($queue,$dt)\n",FILE_APPEND);
   $recent[$queue]=$dt;
}
$queuelist=explode(",",$queues);
sort($queuelist);
$flag=0;
foreach ($queuelist as $queue) {
   if (!$recent[$queue]) {  # no entry found, create one.
#     file_put_contents('php://stderr',"wfcheck.php: could not find $queue--adding\n",FILE_APPEND);
     $sql2="insert into workqueues (queue) values (?)";
     sqlexecp($icms,$sql2,array($queue));
     $flag=1;
   }
}
if ($flag) { # there was a missing queue, re-run the query
   $arr=sqlarrayp($icms,$sql,array());
}
# now that we have a complete list.
foreach ($arr as $line) {
   $res.="$line[0],$line[1]\n";
}
#file_put_contents('php://stderr',"wfcheck: res=$res\n",FILE_APPEND);
echo $res;
?>