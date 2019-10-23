<?php

require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/common.php");
require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/db_functions.php");

extract($_REQUEST);

$user = getSessVal('user');

$dbh = dbConnect("icms");

if (isset($docid)) {
    // Came from workflow
    $query = "
        select
            ref_file_filename as filename,
            ref_file as encoded_attachment,
    		creator
        from
            workflow
        where
            doc_id = :docid
    ";
    $filerec = getDataOne($query, $dbh, array('docid' => $docid));
} else {
    // Get the file from the DB
    $query = "
        select
            filename,
            encoded_attachment,
    		userid as creator
        from
            casenote_attachments ca
    	inner join
    		casenotes c
    			on ca.note_id = seq
        where
            note_id = :noteid
            and filename = :filename
    ";
    $filerec = getDataOne($query, $dbh, array('noteid' => $noteid, 'filename' => $filename));
}

if(!empty($filerec['filename'])){
	$fileloc = sprintf("/uploads/%s/%s", strtolower($filerec['creator']), $filerec['filename']);
	
	// Get the MIME type of the file
	$finfo = finfo_open(FILEINFO_MIME_TYPE);
	$mime = finfo_file($finfo, $fileloc);
	$ext = pathinfo($fileloc);
	
	header("Location: " . $fileloc);
}
else{
	echo "File not found!";
}