<?php

# wfupload.php - receives data from a workflow upload dialog...
include "../php-lib/common.php";
include "../php-lib/db_functions.php";

include "../icmslib.php";

//print "<pre>"; var_dump($_REQUEST); print "</pre>"; exit;

$result = array();

$wf_an_order = "";
//$wf_need_judge = "";
//$wj_need_ja = "";
//$wf_need_gm = "";
$wf_ucn = "";
$wf_file = "";
$wf_queue = "";
$wf_title = "";
$wf_priority = "";
$wf_comments = "";
$wf_docket_as = "";
$wf_id = 0;
$wf_docref = "";
$wf_doctype = "";
$wf_due_date = "";

extract($_REQUEST, EXTR_IF_EXISTS);

if(!empty($wf_comments)){
	$wf_comments = $wf_comments . " (" . $_SESSION['user'] . ")";
}

//print "<pre>"; var_dump($_REQUEST); var_dump($wf_id); print "</pre>"; exit;

#
# main program...
#

$ts=date("m/d/Y h:i:s A");
if ($wf_id=="0") {
    $wf_id="";
}

if ($wf_id=="" && $wf_docref=="" && $_FILES["wf_file"]["name"]) {
    # we're trying to upload a file, or a docref
    if ($_FILES["wf_file"]["error"] > 0) {
        echo "<font face=arial>File Upload Error: " . $_FILES["wf_file"]["error"] . "<br />";
        exit;
    }
    $size=$_FILES["wf_file"]["size"];
    if ($size==0) {
        echo "<font face=arial>Error: file size=0; upload failed!";
        exit;
    }
}

$dbh = dbConnect("icms");

$creator = $_SESSION['user'];

$ffile = $_FILES["wf_file"]["name"];
$tname = $_FILES["wf_file"]["tmp_name"];
log_this('JVS','workflow',"Uploaded file - " . $ffile, $_SERVER['REMOTE_ADDR'], $dbh);
$duedate = db_date($wf_due_date);

if ($wf_doctype=="") {
    if ($wf_docref=="" && $ffile=="") { # no doc or uploaded file
        $wf_doctype="MISCDOC";
    } else if ($wf_an_order=="on") {
        $wf_doctype="PROPORDER";
    } else {
        $wf_doctype="MISCDOC";
    }
}

# a miscdoc can turn into a proporder if you set anorder...
if ($wf_an_order =="on" && $wf_doctype=="MISCDOC") {
   $wf_doctype="PROPORDER";
}

if ($wf_id=="") {
    $encFile = null;
    $filename = null;
    
    if ($wf_docref!="") {  # a document ref, so just copy over
        $filename = preg_replace("/^$wf_ucn\./","", $wf_docref);
        # we know it's a pdf...
        $inpath = "/var/www/html/pdfs/$filename";
        
        $encFile = encodeFile($inpath);
    }
	else{
		$docpath="/var/www/html/uploads/".$creator;
	}
	
	// Make directory is user directory does not exsist
	if(!is_dir($docpath)){ 
		mkdir($docpath, 0775); 
	}
	
    //What file type is this?	
    $ext = pathinfo($ffile, PATHINFO_EXTENSION);
    if (strtolower($ext) == "pdf") { # it's a PDF file...
    	$fullpath="$docpath/$ffile";
        move_uploaded_file($tname,$fullpath);
    } else { # it's not a PDF file...
    	$fullpath="$docpath/$ffile";
        move_uploaded_file($tname,$fullpath);
        # need to convert to PDF here...
   }
   
   $caseInfo = getCaseDivAndStyle($wf_ucn);
   $case_style = $caseInfo[1];
    
    $query="
        insert into
            workflow (
                queue,
                ucn,
    			case_style,
                title,
                due_date,
                creator,
                creation_date,
                color,
                comments,
                doc_type,
                docket_as,
                ref_file,
                ref_file_filename
            ) values (
                :queue,
                :ucn,
    			:case_style,
                :title,
                :duedate,
                :creator,
                CURRENT_TIMESTAMP,
                :color,
                :comments,
                :doctype,
                :docket_as,
                :encFile,
                :filename
            )
        ";
    doQuery($query, $dbh, array ('queue' => $wf_queue, 'ucn' => $wf_ucn, 'case_style' => $case_style, 'title' => $wf_title, 'duedate' => $duedate, 'creator' => $creator,
                                 'color' => $wf_priority, 'comments' => $wf_comments, 'doctype' => $wf_doctype, 'docket_as' => $wf_docket_as,
                                 'encFile' => $encFile, 'filename' => $ffile));

    $docnum = getLastInsert($dbh);
    
    $logMsg = "User $creator added external ID $docnum to queue '$wf_queue'";
    $logIP = $_SERVER['REMOTE_ADDR'];
    log_this('JVS','workflow',$logMsg,$logIP,$dbh);
    
    $result['status'] = "Success";
    $result['message'] = "The document was successfully added to the workflow queue '$wf_queue'";
   
} else { # an UPDATE
    $query = "
        update
            workflow
        set
            queue = :queue,
            ucn = :ucn,
            title = :title,
            color = :color,
            due_date = :duedate,
            comments = :comments,
            doc_type = :doctype,
            docket_as = :docket_as 
        where
            doc_id = :docid
    ";
    doQuery($query, $dbh, array ('queue' => $wf_queue, 'ucn' => $wf_ucn, 'title' => $wf_title, 'duedate' => $duedate, 'color' => $wf_priority,
                                 'comments' => $wf_comments, 'doctype' => $wf_doctype, 'docket_as' => $wf_docket_as, 'docid' => $wf_id));
    
    $user = $_SESSION['user'];
    $logMsg = "User $user updated settings for document ID $docnum";
    $logIP = $_SERVER['REMOTE_ADDR'];
    log_this('JVS','workflow',$logMsg,$logIP,$dbh);
    
    $result['status'] = "Success";
    $result['message'] = "The document settings were successfully updated.";
    
    //$sql="update workflow set queue=?,ucn=?,title=?,need_judge=?,need_gm=?,need_ja=?,color=?,due_date=?,comments=?,doc_type=?,docket_as=? where doc_id=?";
}

$query = "
    update
        workqueues
    set
        last_update=now()
    where
        queue = :queue
";

doQuery($query, $dbh, array('queue' => $wf_queue));

returnJson($result);

?>
