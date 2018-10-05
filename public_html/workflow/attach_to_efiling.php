<?php

include "../php-lib/common.php";
include "../php-lib/db_functions.php";
include "../icmslib.php";

$xml = simplexml_load_file($icmsXml);

$wf_id = $_REQUEST['wf_id'];
$doc_id = $_REQUEST['doc_id'];
$attach = $_REQUEST['attach'];
$merge_doc = $_REQUEST['mergeDoc'];
$user = $_SESSION['user'];

$dbh = dbConnect("ols");
$idbh = dbConnect("icms");

$docQuery = "SELECT jvs_doc,
			file
			FROM olscheduling.supporting_documents
			WHERE supporting_doc_id = :doc_id";

$row = getDataOne($docQuery, $dbh, array("doc_id" => $doc_id));

$is_jvs_doc = $row['jvs_doc'];

$args = array();
$set = ", jvs_file_path = NULL ";
if($is_jvs_doc == '0'){
	$new_file_path = "/var/www/html/case/uploads/" . $user . "/" . basename($row['file']);
	
	if(!file_exists("/var/www/html/case/uploads/" . $user)) {
		mkdir("/var/www/html/case/uploads/" . $user);
	}
	
	copy($xml->olsURL . "/" . $row['file'], $new_file_path);
	$set = ", jvs_file_path = :new_file_path ";
	$new_file_path = "/case/uploads/" . $user . "/" . basename($row['file']);
	$args['new_file_path'] = $new_file_path;
}

$docQuery = "UPDATE olscheduling.supporting_documents
			SET efile_attach = :attach";
$docQuery .= $set;

$docQuery .= "	, order_merge = :order_merge
			WHERE supporting_doc_id = :doc_id";

$args['order_merge'] = $merge_doc;
$args['doc_id'] = $doc_id;
$args['attach'] = $attach;

doQuery($docQuery, $dbh, $args);

$logMsg = "User $user marked document ID $doc_id to be attached to e-filing";
$logIP = $_SERVER['REMOTE_ADDR'];
log_this('JVS', 'workflow', $logMsg, $logIP, $idbh);
    
$result['status'] = "Success";
$result['message'] = "This document was successfully attached for e-Filing.";

$omQuery = " SELECT document_title,
			 CASE
				WHEN jvs_file_path IS NOT NULL
					THEN jvs_file_path
				ELSE
					file
			 END AS file,
			 supporting_doc_id
			 FROM olscheduling.supporting_documents
			 WHERE workflow_id = :wf_id
			 AND order_merge = 1";

$mergeDocs = array();
getData($mergeDocs, $omQuery, $dbh, array("wf_id" => $wf_id));

if(count($mergeDocs) > 0){
	$html = '<p>The following documents will be merged with the order: </p>
			<table style="width:40%; text-align:center">
				<thead>
					<tr>
						<th>Document Title</th>
						<th>Remove</th>
					</tr>
				</thead>
				<tbody>';
	
	foreach($mergeDocs as $md){
		$html .= '<tr id="merge-' . $md['supporting_doc_id'] . '">
					<td><a href="' . $md['file'] . '" target="_blank">' . $md['document_title'] . '</a></td>
					<td><a href="#\" class="removeMergeDoc" data-docid="' . $md['supporting_doc_id'] . '"><img src="../icons/delete.png"/></a></td>
				</tr> ';
	}

	$html .= '</tbody>
			</table>
			<br/>';
}
else{
	$html = "";
}

$result['html'] = $html;

returnJson($result);