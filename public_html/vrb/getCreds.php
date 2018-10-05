<?php
require_once('../php-lib/common.php');

$result['user'] = $_SESSION['user'];
$result['pw'] = $_SERVER['PHP_AUTH_PW'];

returnJson($result);

?>