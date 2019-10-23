<?php
# efile.php -- electronically files the document passed it, via
#              the settings in efilesettings for that county/division
require_once '../php-lib/common.php';
require_once '../php-lib/db_functions.php';
require_once "../icmslib.php";
require_once "../caseinfo.php";

require_once('FirePHPCore/fb.php');
$firephp = FirePHP::getInstance(true);
$firephp->setEnabled(true);


function  efilebyemail($icms,$user,$ucn,$title,$filename,$emails) {
    $emailhost=emailhost();
    $from_mail="efiling$emailhost";
    $from_name="Court E-Filing System";
    $replyto="$user$emailhost";
    $subject="ELECTRONIC FILING OF COURT DOCUMENT: $UCN";
    $division=get_division_text($ucn);
    $case_style=get_case_style_easy($ucn);
    list($name,$phone)=sqlgetonerowp($icms,"select name,phone from users where userid=?",array($user));
    $message="Attached is a $formtitle to be filed in $case_style, $ucn in the $division division. If you have any questions, please contact $name at $user$emailhost or $phone.";
    #
    #  MAIL IT!
    #
    if (mail_attachment($filename, $emails, $from_mail, $from_name, $replyto, $subject, $message)) {
    } else {
        # e-mail error-log it!
        file_put_contents("php://stderr","$ts: efile.php E-MAIL ERROR: ($ucn,$title,$filename,$replyto)\n",FILE_APPEND);
        echo "ERROR";
        exit;
    }
}


function efilebyprint_raw($filepath,$dest) {
    global $_SERVER;
    list($destip,$port)=explode(":",$dest);
    if ($destip=="" || $port=="") {
        echo "ERROR: invalid destination $dest";
        exit;
    }
    $pspath=$filepath;
    $pspath=str_replace(".pdf",".ps",$pspath);
    `pdftops $filepath $pspath`;
    if (!file_exists($pspath) || filesize($pspath)==0) {
        echo "ERROR converting PDF to PostScript format!";
        exit;
    }
    $file=file_get_contents($pspath);
    if ($file=="") {
        echo "ERROR: error reading file $filepath\n";
    }
    $hostip=$_SERVER["SERVER_ADDR"];
    $sock=socket_create(AF_INET,SOCK_STREAM,getprotobyname('tcp'));
    socket_set_option($sock,SOL_SOCKET,SO_RCVTIMEO,array('sec'=>1,'usec'=>0));
    socket_set_option($sock,SOL_SOCKET,SO_SNDTIMEO,array('sec'=>1,'usec'=>0));
    socket_bind($sock,$hostip);
    $retval=@socket_connect($sock,$destip,$port); # non-blocking...
    if ($retval) { # it worked!
        socket_set_block($sock); # now that we know it's OK...
        socket_write($sock,$file);
        socket_close($sock);
    } else {
        echo "ERROR: could not connect to printer at $dest";
        exit;
    }
}

// efilebyprint sends the print job to the server's printer specified.

function efilebyprint($filepath,$dest) {
   $pspath=$filepath;
   $pspath=str_replace(".pdf",".ps",$pspath);
   `pdftops $filepath $pspath`;
   if (!file_exists($pspath) || filesize($pspath)==0) {
      echo "ERROR converting PDF to PostScript format!";
      exit;
   }
   
   $res=`lpr -P $dest $pspath; echo \$?`;
   if ($res!=0) { echo "ERROR: print result=$res\n"; }
}


// efiledirect sends the print job to the server's printer specified.

function efiledirect($countynum,$ucn,$file) {
   $list=glob("./$countynum.efile.*");
   $prog=$list[0];
   if ($prog=="") {
      echo "ERROR: e-filing program not found!";
      exit;
   }
   echo `$prog $ucn $file`;
}



#
#  MAIN PROGRAM
#

extract($_REQUEST);

if (isset($filingId)) {
    // This is a resubmittion of a pending queue filing.
    $dbh = dbConnect("icms");
    $args = array('filingid' => $filingId);
    $query = "
        update
            workflow
        set
            efile_queued = 1,
            efile_pended = 0,
            efile_submitted = 0,
            efile_completed = 0
        where
            portal_filing_id = :filingid
    ";
    doQuery($query,$dbh,$args);
    
    // Also update the queued_filings table.
    $query = "
        update
            queued_filings
        set
            filing_complete = 0
        where
            doc_id in (
                select
                    doc_id
                from
                    workflow
                where
                    portal_filing_id = :filingid
            )
    ";
    doQuery($query,$dbh,$args);
    
    $pdbh = dbConnect("portal_info");
    $query = "
        update
            portal_filings
        set
            filing_status = 'Queued',
            status_dscr = 'Queued for Re-Submission'
        where
            filing_id = :filingid
    ";
    
    doQuery($query, $pdbh, $args);
    
    $result = array();
    $result['status'] = "Success";
    $result['message'] = "Filing ID $filingId has been re-submitted.";
    
    $user = $_SESSION['user'];
    $logMsg = "User $user submitted updated document ID $docid for re-filing (as portal filing ID $filingId)";
    $logIP = $_SERVER['REMOTE_ADDR'];
    log_this('JVS','workflow',$logMsg,$logIP,$dbh);
    
    header("Content-type: application/json");
    print json_encode($result);
    exit;    
}

$ts=date("m/d/Y h:i:s A");
if (!isset($docid)) {
   echo "ERROR: need UCN and document id #!";
   exit;
}

// Get information on the signed doc
$dbh = dbConnect("icms");

$query = "
    select
        ucn as UCN
    from
        workflow
    where
        doc_id = :docid
";
$doc = getDataOne($query, $dbh, array('docid' => $docid));

$query = "
    replace into
        queued_filings (
            doc_id,
            submit_date,
            case_style,
            clerk_case_id,
            filing_complete
        ) values (
            :doc_id,
            now(),
            :case_style,
            :clerk_case_id,
            0
        )
";

list($div, $style) = getCaseDivAndStyle($doc['UCN']);

if (preg_match("/^58/", $doc['UCN'])) {
    $clerkid = $doc['UCN'];
} else {
    $clerkid = preg_replace("/-/","", $doc['UCN']);
}

doQuery($query, $dbh, array('doc_id' => $docid, 'case_style' => $style, 'clerk_case_id' => $clerkid));

$query = "
    update
        workflow
    set
        efile_queued = 1
    where
        doc_id = :docid
";
doQuery($query, $dbh, array('docid' => $docid));

$user = $_SESSION['user'];
$logMsg = "User $user submitted document ID $docid for e-filing";
$logIP = $_SERVER['REMOTE_ADDR'];
log_this('JVS','workflow',$logMsg,$logIP,$dbh);
                            
$result = array();
$result['status'] = "Success";
$result['message'] = "The document has successfully been submitted for e-Filing.";

header("Content-type: application/json");
print json_encode($result);
exit;
                            
?>