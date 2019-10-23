<?php
require_once "php-lib/common.php";

require_once('FirePHPCore/fb.php');
$firephp = FirePHP::getInstance(true);
$firephp->setEnabled(true);

$searchCore = "";
$searchDiv = "";
$dsCaseNumSearch = "";
$dsSearchTerm = "";

extract($_REQUEST, EXTR_IF_EXISTS);

$fields = array(
    'query' => $dsSearchTerm
);

if ($dsCaseNumSearch != "") {
    # Split it up and format them, then put it back together
    $pieces = explode(",", $dsCaseNumSearch);
    $searchnums = array();
    foreach ($pieces as $case) {
        $case = preg_replace("/-/","", $case);
        if (!preg_match("/^58/", $case)) {
            $case = sprintf("58%s", $case);
        }
        array_push($searchnums,$case);
    }
    
    $fields['case_number'] = implode(",", $searchnums);
} else if (($searchCore != "all") || ($searchDiv != "all")) {
    if ($searchCore != "all") {
        $fields['core'] = $searchCore;
    }
    if ($searchDiv != "all") {
        $fields['division'] = $searchDiv;
    }
}

$response = curlJson("https://oiv.15thcircuit.com/solr/search.php", $fields);
returnJson($response);

?>
