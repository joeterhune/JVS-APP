#!/usr/bin/perl
<?php
# mock direct efiling piece for testing.

list($prog,$ucn,$file)=$argv;
if ($ucn=="" || $file=="") {
   echo "ERROR: 01.efile.php: need $ucn and $file";
  exit;
}
echo "OK";
?>
