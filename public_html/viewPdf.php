<?php

require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/common.php");
require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/db_functions.php");

$pdbh = dbConnect("portal_info");

$filing_id = getReqVal('filing_id');

$query = "	SELECT base64_attachment
			FROM pending_filings
			WHERE filing_id = :filing_id";

$row = getDataOne($query, $pdbh, array("filing_id" => $filing_id));

$data = base64_decode($row['base64_attachment']);
header('Content-Type: application/pdf');
echo $data;
die;