<?php
# 01-DV.orders.php - handler/re-director for 01 DV cases.
$ucn=$_REQUEST[ucn];
$div=$_REQUEST[div];
echo header("Location: domestic_violence/form.cgi?ucn=$ucn&div=$div");
?>