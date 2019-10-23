<?php
error_reporting (E_ALL ^ E_NOTICE);
ini_set('display_errors','On');


//require_once('common.php');
 


function onlyAdmins(){
	
	$user = $_SESSION['user'];
	// The idea is having a table for admins and manage that over the web-page.
	
	// for now. we jsut use an array.
	$validUsers = array(
		'jterhune','nchessman','rhaney','lkries'
	);
	
	if( !in_array($user,$validUsers) ){
		header("location: /");
		exit();
	}
	
	
}


function getSignature($userId, $encoded = true ) {
	
	//error_log("Sig User= ".$sigUser."\nDocID=".$docid);
    global $SIGXPIXELS, $SIGYPIXELS;
  
	$dbh = dbConnect("portal_info");
	$wdbh = dbConnect("icms");
 
    
    $query = "
        select
            user_sig,
            user_id,
            first_name as FirstName,
            middle_name as MiddleName,
            last_name as LastName,
            suffix as Suffix
        from
            signatures
        where
            user_id = :userid
    ";
    
    $sigInfo = getDataOne($query, $dbh, array('userid' => $userId));
    $sigInfo['ucn'] = $ucn;
    
    if (array_key_exists('user_sig', $sigInfo)) {
      
         $sigInfo['FullName'] = buildName($sigInfo);
        // Now generate the signature image
        
        $jpg = pack("H*", $sigInfo['user_sig']);
        
        $origImg = imagecreatefromstring($jpg);
        $width = imagesx($origImg);
        $height = imagesy($origImg);
        
        $newimg = imagecreate($SIGXPIXELS, $SIGYPIXELS );
        
        // Set the colors
        $black = imagecolorallocate($newimg,0,0,0);
        $gray = imagecolorallocatealpha($newimg,225,225,225,127);
        $white = imagecolorallocate($newimg,255,255,255);
		
        imagecopyresampled($newimg, $origImg,0, 0, 0, 0, $SIGXPIXELS, $SIGYPIXELS, $width, $height);
        
 
       // $outfile=tempnam("/var/www/html/tmp", "sig");
       // $outfile .= ".jpg";
        ob_start();
        imagejpeg($newimg);
        $imageString = ob_get_clean();
		ob_end_flush();
		
		
        if($encoded == true){
			$sigInfo = base64_encode($imageString);
		}else{
			$sigInfo = $imageString;
		}
        
        //$sigInfo = base64_encode($newimg);
		
        imagedestroy($newimg);
        imagedestroy($origImg);
		
		
    }
    
    return $sigInfo;
}


function getSignatureWithInfo($userId, $caseNumber){

	$caseNumber = str_replace("-",'',$caseNumber);
	$ucn = $caseNumber;
 
	
	$dbh = dbConnect("portal_info");
	$wdbh = dbConnect("icms");
 
	global $SIGXPIXELS, $SIGYPIXELS;
	
	 
	$origImg  = imagecreatefromstring(getSignature($userId, false ));
	
	if($origImg  === false){
		print "error";
		exit();
	}
	
	
	$width = imagesx($origImg );
    $height = imagesy($origImg );
	//$userSignature = imagejpeg($userSignature);
	 
	 //print $userSignature;
	//exit();
	
	$newimg = imagecreate($SIGXPIXELS, $SIGYPIXELS + 70);
	
	$black = imagecolorallocate($newimg,0,0,0);
	$gray = imagecolorallocatealpha($newimg,225,225,225,127);
	$white = imagecolorallocate($newimg,255,255,255);
	imagecopyresampled($newimg, $origImg ,0, 0, 0, 0, $SIGXPIXELS, $SIGYPIXELS, $width, $height);
	
	
	$textheight = 10;
	// The top/right of the watermark box
	$wmTop = 35;
	$wmMargin = 20;

	// Top/right corners of the name box
	$nameTop = $SIGYPIXELS - $textheight - 15;
	
	
	
	 $query = "
        select
            user_sig,
            user_id,
            first_name as FirstName,
            middle_name as MiddleName,
            last_name as LastName,
            suffix as Suffix
        from
            signatures
        where
            user_id = :userid
    ";
    
    $sigInfo = getDataOne($query, $dbh, array('userid' => $userId));
    $sigInfo['ucn'] = $caseNumber;
	
	$sigInfo['FullName'] = buildName($sigInfo);
	
	
	
	// Ok, we have a signature.  Look up information on the user and generate the file
	$config = simplexml_load_file("/usr/local/icms/etc/ICMS.xml");
	$ldapConf = $config->{'ldapConfig'};
	$filter = "(sAMAccountName=$userId)";
	$userdata = array();

	ldapLookup($userdata, $filter, $ldapConf, null, array('title'),
			   (string) $ldapConf->{'userBase'});
	$sigInfo['Title'] = $userdata[0]['title'][0];
	
	//print_r($userdata);
	//exit();
	
	if (preg_match('/judge/i', $sigInfo['Title'])) {
		if (isCircuit($ucn)) {
			$sigInfo['Title'] = 'Circuit Judge';
		} else {
			$sigInfo['Title'] = 'County Court Judge';
		}
	} elseif (strtolower($userId) == 'sblumberg') {
		$sigInfo['Title'] = 'Traffic Hearing Officer';
	}
	
	
	
	imagecolortransparent($newimg, $gray);

	$now = date('m/d/Y');
	$ucnString = sprintf("%s    %s", $ucn, $now);
	$nameString = sprintf("%s    %s", $sigInfo['FullName'], $sigInfo['Title']);

	$font = '/usr/share/fonts/liberation/LiberationSans-Bold.ttf';
	$font2 = '/usr/share/fonts/liberation/LiberationSerif-Regular.ttf';
	
	$ucnBounds = imageftbbox($textheight, 0, $font, $ucnString);
	$ucnWidth = $ucnBounds[2] - $ucnBounds[0];
	$ucnHeight = $ucnBounds[1] - $ucnBounds[7];
	imagefilledrectangle($newimg, $wmMargin, $wmTop, $wmMargin + $ucnWidth, $wmTop + $textheight, $gray);

	imagettftext($newimg, $textheight, 0, $wmMargin, $wmTop+$textheight , $black, $font, $ucnString);

	$nameBounds = imageftbbox($textheight, 0, $font, $nameString);

	$nameWidth = $nameBounds[2] - $nameBounds[0];
	$nameHeight = $nameBounds[1] - $nameBounds[7];

	imagefilledrectangle($newimg,$SIGXPIXELS - $nameWidth - $wmMargin, $SIGYPIXELS - $wmTop - $textheight,
						 $SIGXPIXELS - $wmMargin, $SIGYPIXELS - $wmTop, $gray);
	imagettftext($newimg, $textheight, 0, $SIGXPIXELS - $nameWidth - $wmMargin, $SIGYPIXELS - $wmTop,
				 $black, $font, $nameString);

	$titleString = sprintf("%s      %s\n%s\n%s", $ucn, $now, $sigInfo['FullName'], $sigInfo['Title']);
	$titlebounds = imageftbbox(35, 0, $font, $titleString);
	imagefilledrectangle($newimg, 0, $SIGYPIXELS, $SIGXPIXELS, $SIGYPIXELS+70, $white);
	imagettftext($newimg, $textheight+2, 0, 40,120, $black, $font2, $titleString);
	
	
	ob_start();
        imagejpeg($newimg);
    	$signature = ob_get_clean();
	ob_end_flush();
	
	  imagedestroy($newimg);
	
	return $signature;
	
}


function getPendingCases($division){
	
	$path = getDivisionPath($division);
	
 	if(file_exists($path . 'index.txt')){
		$contents  = file_get_contents($path . 'index.txt');
		$contentsArray = explode( "\n", $contents);
	}else{
		return false;
	}
	
	
	
	
	$excludeFiles = array('DATE=','TITLE1=','TITLE2=','PATH=','HELP=','BLANK');
	$outLines = array();
	
	foreach($contentsArray as $key=>$line){
		
		//search the excluded lines.
		foreach($excludeFiles as $ef){
			
			if(strpos($line,$ef) !== false){
				// Eliminate lines
				unset($contentsArray[$key]);
			}
			
			
		}
		
		if($line == ''){
			unset($contentsArray[$key]);
		}

	}
	
	$out = array();
	foreach($contentsArray as $line){
		$out[] = explode('~', $line);
	}
	
	return $out;
	
	
}


function getDivisionPath($division){
	
	$hdPath = "/var/www/Palm/";
	
	$dbConector = dbConnect("judge-divs");
	
	$query = "
		SELECT division_type 
		FROM
			divisions
		WHERE
			division_id = :division
			
	";
	$arg = array('division'=>$division);
	
	$divArra = array();
	getData($divArra,$query,$dbConector,$arg);
	
	$divType = $divArra[0]['division_type'];
	
	switch ($divType){
		
		case "Circuit Civil":
			$prefix = "civ";
			break;
		case "Family":
			$prefix ="civ";
			break;
		case "Juvenile":
			$prefix ='juv';
			break;
		case "Misdemeanor":
			$prefix = 'crim';
			break;
		case "Probate":
			$prefix = 'pro';
			break;
		case "Felony":
			$prefix = "crim";
			break;
		case "Traffic":
			$prefix = 'crim';
			break;
		case "County Civil":
			$prefix = "civ";
			break;
		case "Foreclousure":
			$prefix ="civ";
			break;
		case "Civil":
			$prefix="civ";
			break;
		case "VA":
			$prefix = 'crim';
			break;
		case "Appellate Civil":
			$prefix = "civ";
			break;
		case "Appellate Criminal":
			$prefix = 'crim';
			break;
		case "County Civil":
			$prefix = 'civ';
			break;
		case "Mental Health":
			$prefix = "crim";
			break;
		case "Shadow":
			$prefix = "";
			break;
		case "UFC Judicial Memo":
			$prefix="civ";
			break;
		case "UFC Linked Cases":
			$prefix ="civ";
			break;
		case "UFC Transferred Cases":
			$prefix = "civ";
			break;
			
			
			
			
	}
	
	$hdPath .= $prefix .'/div'.$division.'/';
	
	if($prefix !=''){
		return $hdPath;
	}else{
		return false;
	}
	
}

?>