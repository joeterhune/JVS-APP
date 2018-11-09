<?php
require_once("../php-lib/common.php");
require_once("../php-lib/db_functions.php");

include "../icmslib.php";
include "../caseinfo.php";

$icmsuser = $_SESSION['user'];
$email = getEmailFromAD($icmsuser);

if(!empty($_POST)){
	
	$plaintext = strip_tags($_POST['message']);
    
    $recips = "CAD-HELP@jud12.flcourts.org";
    //$recips = "lkries@jud12.flcourts.org";
    	
    $uid = md5(uniqid(time()));

	$plaintext = str_replace("<br>", "\r\n", $plaintext);
	
	$from_mail = $_POST['from'];
    
    $header = "From: ".$from_mail."\r\n";
    $header .= "cc: $from_mail\r\n";
    $header .= "MIME-Version: 1.0\r\n";
    $header .= "Content-Type: multipart/alternative; boundary=\"".$uid."\"\r\n\r\n";
    //$header .= "This is a multi-part message in MIME format.\r\n";
    
    $mMessage .= "--".$uid."\r\n";
    $mMessage .= "Content-type:text/plain; charset=iso-8859-1\r\n";
    $mMessage .= "Content-Transfer-Encoding: quoted-printable\r\n\r\n";
    $mMessage .= $plaintext."\r\n\r\n";
    $mMessage .= "--".$uid."\r\n";
    
    $mMessage .= "Content-type:text/html; charset=iso-8859-1\r\n";
    $mMessage .= "Content-Transfer-Encoding: 7bit\r\n\r\n";
    $mMessage .= $_POST['message']."\r\n\r\n";
    $mMessage .= "--".$uid."\r\n";
    
    if(!empty($_FILES) && ($_FILES['attach']['size'] > 0)){
    	$filename = $_FILES['attach']['name'];
    	$filename = preg_replace('/[^A-Za-z0-9 _ .-]/', '', $filename);
    	$content = file_get_contents($_FILES['attach']['tmp_name']);
    	$content = chunk_split(base64_encode($content));
    		
    	$mMessage .= "Content-Type: application/octet-stream; name=\"".$filename."\"\r\n"; // use different content types here
    	$mMessage .= "Content-Transfer-Encoding: base64\r\n";
    	$mMessage .= "Content-Disposition: attachment; filename=\"".$filename."\"\r\n\r\n";
    	$mMessage .= $content."\r\n\r\n";
    	$mMessage .= "--".$uid."--";
    }    
	
    mail($recips, "JVS Support Request", $mMessage, $header);
    $messageSent = true;
}
else{
	$messageSent = false;
}

?>

<!DOCTYPE html>
    <html>
        <head>
            <title>Contact Support</title>
            <link rel="stylesheet" type="text/css" href="/case/icms1.css?1.2">
            <link rel="stylesheet" href="/case/style/ICMS.css?1.5">
            <link rel="stylesheet" href="/case/style/ICMS2.css?1.3">
            <script src="https://e-services.co.Sarasota-beach.fl.us/cdn/jslib/jquery-1.11.0.min.js" type="text/javascript"></script>
            <script src="/case/javascript/vrb.js?1.1" type="text/javascript"></script>
        </head>
    </html>
    
    <body>
    	<?php if(!$messageSent) { ?>
        <div class="title">
            Please submit the form below to contact technical support. 
        </div>
        <br/>
        <form method="post" action="support.php" enctype="multipart/form-data">
        	<table>
	        	<tr>
	        		<td><label>From: </label></td>
	        		<td><input type="text" id="from" name="from" value="<?php echo $email; ?>" /></td>
	        	</tr>
	        	<tr>	
	        		<td><label>Message: </label></td>
	        		<td><textarea rows="20" cols="75" name="message" id="message"></textarea></td>
	        	</tr>
	        	<tr>
	        		<td><label>Attachment: </label></td>
	        		<td><input type="file" id="attach" name="attach" /></td>
	        	</tr>
	        	<tr>
	        		<td>&nbsp;</td>
	        		<td style="text-align:right"><input type="submit" name="submit" id="submit" value="Send"/></td>
	        	</tr>
        	</table>
        </form>
        <?php } else {?>
        	<div class="title">
            	Your message has been submitted and you will be contacted by Court Technology shortly. 
        	</div>
        <?php }?>
    </body>