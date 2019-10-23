<?php
require_once("../php-lib/common.php");
require_once("../php-lib/db_functions.php");



# addnote.php - receives data from a note add dialog...
//include "../icmslib.php";

#
# main program...
#

# nt_seq
# nt_casenum
# nt_note
# nt_file
# nt_private
# nt_docref

$seq = getReqVal('nt_seq');

if ($seq=="") {
    # an add
    if ($_FILES[nt_file][name]!="") { # attachment ho...
        $attachments=1;
        if ($_FILES["nt_file"]["error"] > 0) {
            echo "<font face=arial>File Upload Error: " . $_FILES["nt_file"]["error"] . "<br />";
            exit;
        }
        $size=$_FILES["nt_file"]["size"];
        if ($size==0) {
            echo "<font face=arial>Error: file size=0; upload failed!";
            exit;
        }
    } else {
        $attachments=0;
    }
}

$dbh = dbConnect("icms");

$creator = $_SESSION['user'];

if (array_key_exists('nt_file',$_FILES)) {
    $ffile = $_FILES["nt_file"]["name"];
    $tname = $_FILES["nt_file"]["tmp_name"];    
}

$casenum = getReqVal('nt_casenum');

$docref = getReqVal('nt_docref');

$attachment = "";
if ($docref != "") {
    $baseAttachment = preg_replace("/^$casenum\./", "", $docref);
    $attachment = sprintf("/var/www/html/pdfs/%s", $baseAttachment);
}
if ($attachment != "") {
    if (file_exists($attachment)) {
        $encAttachment = base64_encode(file_get_contents($attachment));
    }
}

$matches = array();
if (preg_match("/(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)/", $casenum, $matches)) {
    # Convert the banner casenum to the YYYY-XX-NNNNNN format that casenotes wants
    $casenum = sprintf("%04d-%s-%06d", $matches[1], $matches[2], $matches[3]);
}

$note = getReqVal('nt_note');
$private = getReqVal('nt_private');

if ($private=="on") {
    $private=1;
} else {
    $private=0;
}

if ($seq=="") {
    $query = "
        insert into
            casenotes (
                casenum,
                userid,
                date,
                note
            ) values (
                :casenum,
                :user,
                CURRENT_TIMESTAMP,
                :note
            )
    ";
    doQuery($query, $dbh, array('casenum' => $casenum, 'user' =>  $creator, 'note' => $note));
    
    # Get the ID of the note just inserted, so we can enter the attachment
    $noteid = getLastInsert($dbh);
    
    $query = "
        insert into
            casenote_attachments (
                note_id,
                filename,
                encoded_attachment
            )
        values (
            :noteid,
            :filename,
            :encoded
        )
    ";
    doQuery($query, $dbh, array('noteid' => $noteid, 'filename' => basename($attachment), 'encoded' => $encAttachment));
}

$request = array();
$request['status'] = "Success";
$request['message'] = "The note was successfully added";

returnJson($request);
?>
