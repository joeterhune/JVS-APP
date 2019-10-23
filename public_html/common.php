<?php

date_default_timezone_set('America/New_York');

$mssql_functions = array (
			  "connect" => "mssql_connect",
			  "query" => "mssql_query",
			  "execute" => "mssql_execute",
			  "fetch_assoc" => "mssql_fetch_assoc",
			  "fetch_array" => "mssql_fetch_array",
			  "num_rows" => "mssql_num_rows",
			  "free_result" => "mssql_free_result",
			  "select_db" => "mssql_select_db"
			  );

$postgres_functions = array (
			     "connect" => "pg_connect",
			     "query" => "pg_query",
			     "execute" => "pg_execute",
			     "fetch_assoc" => "pg_fetch_assoc",
			     "fetch_array" => "pg_fetch_array",
			     "num_rows" => "pg_num_rows",
			     "free_result" => "pg_free_result"
			     );

function casenumtoucn ($casenum) {
  // Copied almost directly from bannersearch.cgi
  $x=substr($casenum,0,4)."-".substr($casenum,4,2)."-".substr($casenum,6,6);
  if (substr($casenum,12,1) != "") {
    $x.="-".substr($casenum,12);
  }
  return $x;
}


function lookupShowcase ($bannerCase) {
  // Given a Banner case number, look up the corresponding Showcase
  // case number.

  $dbname = "showcase";

  $dbConfig = getDbConfig($dbname);

  // First, strip all of the spaces from the Banner case number
  $caseNum = preg_replace('/-/','', $bannerCase);
  $query = "select CaseNumber from vCase where LegacyCaseNumber = '$caseNum'";

  $dbh = mssql_connect($dbConfig[host], $dbConfig[dbUser], $dbConfig[dbPass]);

  mssql_select_db($dbConfig[dbName], $dbh);

  $data = getData($query, $dbConfig, $dbh);

  if (isset($data[0][CaseNumber])) {
    return ($data[0][CaseNumber]);
  } else {
    return NULL;
  }
  }

function lookupBanner ($caseNum) {
  // Given a Showcase case number, look up the corresponding Banner
  // case number.

  $dbname = "showcase";

  $dbConfig = getDbConfig($dbname);

  $query = "select LegacyCaseNumber from vCase where CaseNumber = '$caseNum'";

  $dbh = mssql_connect($dbConfig[host], $dbConfig[dbUser], $dbConfig[dbPass]);

  mssql_select_db($dbConfig[dbName], $dbh);

  $data = getData($query, $dbConfig, $dbh);

  // This query will return at most 1 record.
  if (isset($data[0][LegacyCaseNumber])) {
    $casenum = casenumtoucn($data[0][LegacyCaseNumber]);
    return ($casenum);
  } else {
    return NULL;
  }
  }

?>
