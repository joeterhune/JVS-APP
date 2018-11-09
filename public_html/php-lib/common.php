<?php

session_start();

require_once('Crypt/CBC.php');
require_once('ldap_functions.php');
require_once "mpdf60/mpdf.php";

require_once('Smarty/Smarty.class.php');
//require_once("../icmslib.php");

// Some variables that may be neede globally
$SCCODES = array('CF','MM','MO','CO','CT','IN','TR');
$SIGPATH = "/tmp";
$SIGXTWIPS = 4000;
$SIGYTWIPS = 1000;
$SIGXPIXELS = 400;
$SIGYPIXELS = 100;

# This value ($_SERVER['APP_ROOT']) is set in the Apache config file
# for this VirtualHost.
$appDir = $_SERVER['APP_ROOT'];
$confDir = "$appDir/conf";
$icmsXml = "$confDir/ICMS.xml";

# Directories used by Smarty
$templateDir = "$appDir/templates";
$compileDir = "$appDir/templates_c";
$cacheDir = "$appDir/cache";

$courtTypes = array(
	'CF' => 'Circuit Criminal',
	'MM' => 'County Criminal',
	'MO' => 'County Criminal',
	'CT' => 'Criminal Traffic',
	'DR' => 'Domestic Relations/Family',
	'CA' => 'Circuit Civil',
	'SC' => 'County Civil',
	'TR' => 'Civil Traffic',
	'CP' => 'Probate',
	'GA' => 'Probate',
	'MH' => 'Probate',
	'CJ' => 'Juvenile Delinquency',
	'DP' => 'Juvenile Dependency',
	'CO' => 'County Criminal',
	'CC' => 'County Civil',
	'AP' => 'Appellate Criminal',
	'IN' => 'Civil Traffic',
	'4D' => 'Appellate Criminal',
	'WO' => 'Probate',
	'DA' => 'Domestic Relations/Family'
);

$portalTypes = array(
	'Circuit Civil' => 'circuit_civil',
	'Foreclosure' => 'circuit_civil',
	'Felony' => 'circuit_criminal',
	'Circuit Criminal' => 'circuit_criminal',
	'Family' => 'family',
	'Juvenile Dependency' => 'dependency',
	'Probate' => 'probate',
	'County Civil' => 'county_civil',
	'Misdemeanor' => 'county_criminal',
	'County Criminal' => 'county_criminal',
	'Juvenile Delinquency' => 'delinquency',
	'Criminal Traffic' => 'criminal_traffic',
	'Appellate Civil' => 'circuit_civil',
	'Appellate Criminal' => 'circuit_criminal',
	'VA' => 'county_criminal',
	'Civil Traffic' => 'civil_traffic',
	'Domestic Relations/Family' => 'family'
);

$ranges = array(
    array('lower' => 0, 'upper' => 120, 'rangeString' => '0 - 120 days'),
    array('lower' => 121, 'upper' => 180, 'rangeString' => '121 - 180 days'),
    array('lower' => 181, 'upper' => 99999999, 'rangeString' => '181+ days'),
    array('lower' => 0, 'upper' => 60, 'rangeString' => '0-60 days'),
    array('lower' => 60, 'upper' => 90, 'rangeString' => '60-90 days'),
    array('lower' => 91, 'upper' => 99999999, 'rangeString' => '91+ days'),
);

function log_this ($logApp, $logType, $logMsg, $logIP = null, $dbh = null) {
    if ($dbh == null) {
        $dbh = dbConnect("icms");
    }
    
    $query = "
        insert into
            audit_log (
                log_app,
                log_date_time,
                log_type,
                log_msg,
                log_ip
            ) values (
                :app,
                null,
                :type,
                :msg,
                :ipaddr
            )
    ";
    doQuery($query, $dbh, array('app' => $logApp, 'type' => $logType, 'msg' => $logMsg, 'ipaddr' => $logIP));
}

function replaceHTMLElement($htmlString,$targetID, $replacement) {
    $dom = new DOMDocument();
    
    $foo = $dom->loadHTML($htmlString);
    
    $element = $dom->getElementById($targetID);
    
}

// Get a session value and return it.  If the value isn't set, return NULL.
function getSessVal($field) {
	if (isset($_SESSION[$field])) {
		if (gettype($_SESSION[$field]) == "string") {
			return trim($_SESSION[$field]);
		} else {
			return $_SESSION[$field];
		}
	} else {
		return null;
	}
}

// Get a $_REQUEST value and return it.  If the value isn't set, return NULL.
function getReqVal($field) {
	if (isset($_REQUEST[$field])) {
		return $_REQUEST[$field];
	} else {
		return null;
	}
}

// Get a $_COOKIE value and return it.  If the value isn't set, return NULL.
function getCookieVal($field) {
	if (isset($_COOKIE[$field])) {
		return $_COOKIE[$field];
	} else {
		return null;
	}
}

function fatalError ($title,$errStr) {
	include_once("templates/error.php");
	exit;
}

function createUser($user, $dbh = nuill) {
    if ($dbh == null) {
        $dbh = dbConnect("icms");
    }
    
    $config = simplexml_load_file($_SERVER['APP_ROOT'] . "/conf/ICMS.xml");
    $ldapConf = $config->{'ldapConfig'};
    $filter = "(sAMAccountName=$user)";
    $userdata = array();
    $adFields = array('givenname','initials','sn','title','telephonenumber','mail','physicaldeliveryofficename');

    ldapLookup($userdata, $filter, $ldapConf, null, $adFields, (string) $ldapConf->{'userBase'});

    $first_name = $userdata[0]['givenname'][0];
    $last_name = $userdata[0]['sn'][0];
    $middle_name = "";
    if (array_key_exists('initials',$userdata[0])) {
        $middle_name = $userdata[0]['initials'][0];
    }
    $title = $userdata[0]['title'][0];
    $phone = $userdata[0]['telephonenumber'][0];
    $email = $userdata[0]['mail'][0];
    
    $chname = $userdata[0]['physicaldeliveryofficename'][0];
    
    $courthouse = "";
    
    if (preg_match("/Main/", $chname)) {
        $courthouse = "MB";
    } elseif (preg_match("/North/", $chname)) {
        $courthouse = "NB";
    } elseif (preg_match("/South/", $chname)) {
        $courthouse = "SB";
    } elseif (preg_match("/West/", $chname)) {
        $courthouse = "WB";
    } elseif (preg_match("/Criminal Justice/", $chname)) {
        $courthouse = "GC";
    }
    
    $query = "
        insert into
            users (
                userid,
                first_name,
                middle_name,
                last_name,
                role,
                email,
                phone,
                courthouse
            )
            values (
                :user,
                :first,
                :middle,
                :last,
                :title,
                :email,
                :phone,
                :courthouse
            )
    ";
    doQuery($query, $dbh, array('user' => $user, 'first' => $first_name, 'middle' => $middle_name, 'last' => $last_name,
                                'title' => $title, 'phone' => $phone, 'email' => $email, 'courthouse' => $courthouse));
    
    
    # And create the work queue
    $query = "
        insert into
            workqueues (
                queue,
                last_update
            ) values (
                :user,
                NOW()
            )
    ";
    doQuery($query, $dbh, array('user' => $user));
}

function sanitizeCaseNumber ($ucn){
    global $SCCODES;
    
    $casenum = strtoupper($ucn);
    
    # Strip leading "50" and any dashes.
    $casenum = preg_replace("/-/","",$casenum);
    $casenum = preg_replace("/^58/","",$casenum); //58 for sarasota
    
    if (preg_match("/^(\d{1,6})(\D\D)(\d{0,6})(.*)/", $casenum, $matches)) {
        $year = $matches[1];
        $type = $matches[2];
        $seq = $matches[3];
        $suffix = $matches[4];
        
        # If we have a 2-digit year, adjust it (we'll use 60 as the split point)
        if ($year < 100) {
            if ($year > 60) {
                $year = sprintf("19%02d", $year);
            } else {
                $year = sprintf("20%02d", $year);
            }
        }
        
		# If it's a Showcase code, prepend the 50 - they're all SC codes now!
        if (preg_match("/(\S\S\S\S)(\S\S)/",$suffix,$smatches) || 
        		(preg_match("/(\S\D\S\S)(\S\S)/",$suffix,$smatches))) {
/*         	##### modified 11/7/2018 jmt formatting for benchmark also 58 for sarasota
			$year = sprintf("50-%04d", $year);
		    $suffix = sprintf("%s-%s", $smatches[1], $smatches[2]);
		    $retval = sprintf("%s-%s-%06d-%s", $year, $type, $seq, $suffix);
 */			$year = sprintf("58%04d", $year);
		    $suffix = sprintf("%s%s", $smatches[1], $smatches[2]);
		    $retval = sprintf("%s%s%06d%s", $year, $type, $seq, $suffix);

        }
        else{
        	$dbh = dbConnect("showcase-prod");
        	
        	if(strlen($casenum) < 12){
        		$casenum = $year . $type . str_pad($seq, 6, "0", STR_PAD_LEFT);
        	}
        	if(substr( $casenum, 0, 2 ) != "58" ){
				$casenum = "58" . $casenum;
			}
        	$query = "
            select
                CaseNumber
            from
                vCase with(nolock)
            where
                ( LegacyCaseNumber = :casenum OR UCN LIKE '" . $casenum . "%' ) // changed 50 to 58 for sarasota
        	";
        	
        	$caseInfo = getDataOne($query, $dbh, array('casenum' => $casenum));
        	$retval = $caseInfo['CaseNumber'];
        }
        
        $dbtype = "showcase";
        return array($retval, $dbtype);
    }
}

function getCaseDiv ($casenum, $type = null) {
    if ($type == null) {
        list($casenum,$type) = sanitizeCaseNumber($casenum);
    }
    
    $dbh = dbConnect("showcase-prod");
    
        $query = "
            select
                DivisionID
            from
                vCase with(nolock)
            where
                CaseNumber = :casenum
        ";
    
    
    $caseInfo = getDataOne($query, $dbh, array('casenum' => $casenum));
    
    if (sizeof($caseInfo)) {
        return ($caseInfo['DivisionID']);
    } else {
        return null;
    }
}

function getCaseDivAndStyle ($casenum, $type = null) {
    if ($type == null) {
        list($casenum,$type) = sanitizeCaseNumber($casenum);
    }
    
    $dbh = dbConnect("showcase-prod");
        $query = "
            select
                DivisionID,
                CaseStyle
            from
                vCase with(nolock)
            where
                CaseNumber = :casenum
        ";

    
    $caseInfo = getDataOne($query, $dbh, array('casenum' => $casenum));
    
    if (sizeof($caseInfo)) {
        return array($caseInfo['DivisionID'],$caseInfo['CaseStyle']);
    } else {
        return null;
    }
}

function getBannerExtendedCaseId($casenum, $dbh = null) {
    $dbh = dbConnect("showcase-prod");
    $query = '
        select
            c.CaseNumber,
            c.CaseStyle,
            c.CourtType,
            c.CaseType,
            c.UCN
        from
            vCase c with(nolock)
        where
            CaseNumber = :ucn
    ';
    $rec = getDataOne($query, $dbh, array('ucn' => $casenum));
    $rec['CaseStyle'] = preg_replace('/&/','&amp',$rec['CaseStyle']);
    return $rec;
}

function getShowcaseCaseInfo($casenum, $dbh = null) {
    if ($dbh == null) {
        $dbh = dbConnect("showcase-prod");
    }
    $query = '
        select
            c.CaseNumber,
            c.CaseStyle,
            c.CourtType,
            c.CaseType,
            c.UCN
        from
            vCase c with(nolock)
        where
            CaseNumber = :ucn
    ';
    $rec = getDataOne($query, $dbh, array('ucn' => $casenum));
    $rec['CaseStyle'] = preg_replace('/&/','&amp',$rec['CaseStyle']);
    return $rec;
}

function getPortalServiceList($casenum) {
    //ini_set('soap.wsdl_cache', WSDL_CACHE_NONE);
    $config = simplexml_load_file($_SERVER['APP_ROOT'] . "/conf/ICMS.xml");
    
    list($ucn,$type) = sanitizeCaseNumber($casenum);
    
    if ($type == "banner") {
        // We need to look up the extended case ID from Banner, because that's what
        // the portal wants
        $ucn = getBannerExtendedCaseId($ucn);
    } else {
        // For Showcase, just strip dashes, because that's what the portal wants
        $ucn = preg_replace("/-/", "", $casenum);
    }
    
    if (isset($config->{'serviceListWsdl'})) {
        $wsdl = (string) $config->{'serviceListWsdl'};
    } else {
        $wsdl = '/usr/local/icms/etc/ElectronicServiceListService-PROD.wsdl';
    }
    
    try {
        $client = new SoapClient($wsdl, array('cache_wsdl' => 0, 'trace' => 1));
        
        $query = new StdClass();
        $query->request = new StdClass();
        $query->request->LogonName = "foo";
        $query->request->PassWord = "bar";
        $query->request->UniformCaseNumber = $ucn;
        $query->request->CaseId = -1;
        $query->request->UserID = 59706;
        // Set an ISO 8601 format date
        $query->request->RequestTime = date('c');
        $query->request->UserOrganizationID_x0020_ = 10;
        
        $response = $client->GetElectronicServiceListCase($query);
        $response = $client->__getLastResponse();
        file_put_contents ('/tmp/response.xml', $client->__getLastResponse());
        
        $xml = preg_replace("/(<\/?)(\w+):([^>]*>)/", "$1$2$3", $response);
		$xml = simplexml_load_string($xml);
		$json = json_encode($xml);
		$responseArray = json_decode($json,true);
		$response = $responseArray['sBody']['GetElectronicServiceListCaseResponse'];
    
        $psl = array();
        
        if ($response['GetElectronicServiceListCaseResult']['brOperationSuccessful']) {
            if (isset($response['GetElectronicServiceListCaseResult']['esmElectronicServiceListCase'])) {
                $serviceList = $response['GetElectronicServiceListCaseResult']['esmElectronicServiceListCase'];
				
                $filers = $serviceList['esdFilers'];
                
                // Do a little data massaging so everything can be treated the same later
                /*$type = gettype($serviceList['esdFilers']);
                
                if ($type == "object") {
                    array_push($filers, $serviceList['esdFilers']);
                } else {
                    $filers = $serviceList['esdFilers'];
                }*/
                
                //Sometimes this is one array, sometimes it's an array of arrays...
                foreach ($filers as $filer) {
                	if(!is_array($filer)){
                		$filers = array($serviceList['esdFilers']);
                		break;
                	}
                }
                
                $attorneys = array();
                $parties = array();
                $psl['Attorneys'] = &$attorneys;
                $psl['Parties'] = &$parties;
                
                foreach ($filers as $filer) {
                	
                	$filer['esdName'] = iconv('UTF-8', 'ASCII//TRANSLIT', $filer['esdName']);
                	
                    $type = $filer['esdUserType'];
                    $typeid = $filer['esdUserTypeCode'];
                    $excludeFilers = array(7,8,10,11,12,14,15,16,18,20,21,22);
                    
                    if ($filer['esdShowOnMyCases'] == 'false') {
                        // Has been excluded.  Move along.
                        continue;
                    }
                    
                    if ($filer['esdActive'] == 'false') {
                        // Not active on this case.  Move along.
                        continue;
                    }
                    
                    if (in_array($typeid, $excludeFilers)) {
                        // It's a Judge.  Move along.  Nothing to see here.
                        continue;
                    } elseif ($typeid == 1 || (isset($filer['esdBarNumber']))) {
                        // An attorney
                        $attorneys[$filer['esdBarNumber']] = array();
                        $thisRec = &$attorneys[$filer['esdBarNumber']];
                    } else {
                        // Set up a an array using the EPortalUserId for the key.
                        $parties[$filer['esdEPortalUserId']] = array();
                        $thisRec = &$parties[$filer['esdEPortalUserId']];
                    }
                    
                    $thisRec['Name'] = $filer['esdName'];
                    $thisRec['Addresses'] = array();
                    foreach (array('PrimaryEmailAddress', 'AlternateEmailAddress1', 'AlternateEmailAddress2') as $addrType) {
                        if ((isset($filer['esd' . $addrType])) && ($filer['esd' . $addrType] != "") && (!is_array($filer['esd' . $addrType]))) {
                            array_push($thisRec['Addresses'], $filer['esd' . $addrType]);
                        }
                    }
                    
                    // Are there other recipients specified by this person?
                    if (isset($filer['esdOtherServiceRecipients'])) {
                        $others = $filer['esdOtherServiceRecipients'];
                        //Sometimes this is one array, sometimes it's an array of arrays...
                        foreach ($others as $other) {
                        	if(!is_array($other)){
                        		$others = array($filer['esdOtherServiceRecipients']);
                        		break;
                        	}
                        }
                        foreach ($others as $other) {
                        	if($other['esdRemovalRequested'] == 'false'){
	                            foreach (array('PrimaryEmailAddress', 'AlternateEmailAddress1', 'AlternateEmailAddress2') as $addrType) {
	                                if ((isset($other['esd' . $addrType])) && ($other['esd' . $addrType] != "") && (!is_array($other['esd' . $addrType]))) {
	                                	
	                                	$other['esdName'] = iconv('UTF-8', 'ASCII//TRANSLIT', $other['esdName']);
	                                	
	                               		if(isset($other['esdBarNumber'])){
	                                		if($other['esdBarNumber'] == $filer['esdBarNumber']){
	                                			array_push($thisRec['Addresses'], $other['esd' . $addrType]);
	                                		}
	                                		else{
	                                			if(isset($attorneys[$other['esdBarNumber']])){
	                                				$newRec = &$attorneys[$other['esdBarNumber']];
	                                				array_push($newRec['Addresses'], $other['esd' . $addrType]);
	                                			}
	                                			else{
	                                				$attorneys[$other['esdBarNumber']] = array();
	                                				$newRec = &$attorneys[$other['esdBarNumber']];
	                                				$newRec['Name'] = $other['esdName'];
	                                				$newRec['Addresses'] = array();
	                                				array_push($newRec['Addresses'], $other['esd' . $addrType]);
	                                			}
	                                		}
	                                	}
	                                	else{
	                                		if($other['esdEPortalUserId'] != "-1"){
		                                		if(isset($parties[$other['esdEPortalUserId'] . "-" . $other['esdEPortalUserId']])){
		                                			$newRec = &$parties[$other['esdEPortalUserId'] . "-" . $other['esdEPortalUserId']];
		                                			array_push($newRec['EPortalUserId'], $other['esd' . $addrType]);
		                                		}
		                                		else{
		                                			$parties[$other['esdEPortalUserId'] . "-" . $other['esdEPortalUserId']] = array();
		                                			$newRec = &$parties[$other['esdEPortalUserId'] . "-" . $other['esdEPortalUserId']];
		                                			$newRec['Name'] = $other['esdName'];
		                                			$newRec['Addresses'] = array();
		                                			array_push($newRec['Addresses'], $other['esd' . $addrType]);
		                                		}
	                                		}
	                                		else{
	                                			if(isset($parties[$other['esdServiceRecipientId']])){
	                                				$newRec = &$parties[$other['esdServiceRecipientId']];
	                                				array_push($newRec['Addresses'], $other['esd' . $addrType]);
	                                			}
	                                			else{
	                                				$parties[$other['esdServiceRecipientId']] = array();
	                                				$newRec = &$parties[$other['esdServiceRecipientId']];
	                                				$newRec['Name'] = $other['esdName'];
	                                				$newRec['Addresses'] = array();
	                                				array_push($newRec['Addresses'], $other['esd' . $addrType]);
	                                			}
	                                		}
	                                	}
	                                }
	                            }
                        	}
                        }
                    }
                }
            }
        }
        
        return $psl;
    
    } catch (exception $e) {
    	return "Error";
        //echo 'Caught exception: ',  $e->getMessage(), "\n";
        //echo "Fault string: " . $e->faultstring . "\n\n";
        //exit;
    }
}

function getEServiceList(&$partylist, $ucn, &$psl) {
    $attorneys = &$partylist['Attorneys'];
    $parties = &$partylist['Parties'];
    
    $olsdbh = dbConnect("eservice");
    
    foreach ($attorneys as $attorney) {
        $barnum = $attorney['BarNumber'];
        $addrs = getEsAddresses($barnum, $ucn, $olsdbh);
        
        // Now that we have the local address list, see if we can merge it with the portal list
        if (isset($psl['Attorneys'][$barnum])) {
            foreach ($addrs as $addr) {
                foreach($addr as $email) {
                    if (!in_array($email['email_addr'],$psl['Attorneys'][$barnum]['Addresses'])) {
                        array_push($psl['Attorneys'][$barnum]['Addresses'], $email['email_addr']);
                    }
                }
            }
        } else {
            $psl['Attorneys'][$barnum] = array('Addresses' => array());
            foreach ($addrs as $addr) {
                foreach($addr as $email) {
                    array_push($psl['Attorneys'][$barnum]['Addresses'], $email['email_addr']);
                }
            }
        }
    }
    
    $query = "
    	select
			u.first_name as FirstName,
			u.last_name as LastName,
			e.email_addr
		from
			case_emails ce,
			case_parties cp,
			email_addresses e,
			users u
		where
			ce.casenum = :casenum
			and ce.casenum=cp.casenum
			and ce.email_addr_id = u.login_id
			and ((u.first_name = cp.first_name) or (cp.first_name is null))
			and u.last_name = cp.last_name
			and u.login_id = e.email_addr_id
			and cp.partytype <> 'ATTY'
    ";
    $proseAddrs = array();
    getData($proseAddrs, $query, $olsdbh, array('casenum' => $ucn));
    
    foreach ($parties as &$party) {
    	if(!isset($party['ServiceList'])){
        	$party['ServiceList'] = array();
    	}
        foreach ($proseAddrs as $addr) {
            if ((!strcasecmp($party['FirstName'], $addr['FirstName'])) &&
                (!strcasecmp($party['LastName'], $addr['LastName']))) {
                array_push($party['ServiceList'], $addr['email_addr']);
                continue;
            }
        }
    }
}

function getEsAddresses ($barnum, $ucn, $dbh) {
    // Strip the "FL" for this search
    $barnum = preg_replace('/^FL/','',$barnum);
    
    $query = "
        select
            CONCAT('FL', bar_num) as bar_num,
            email_addr
        from
            email_addresses e left outer join
                (case_emails ce left outer join users u on ce.user_id=u.user_id) on (e.email_addr_id=ce.email_addr_id)
        where
            ce.casenum = :ucn
            and u.bar_num = :bar_num
    ";
    $addresses = array();
    getData($addresses, $query, $dbh, array('ucn' => $ucn, 'bar_num' => $barnum), 'bar_num');
    
    if (!sizeof($addresses)) {
        // There are no case-specific email addresses for this attorney on this case.  How about defaults?
        $query = "
            select
                CONCAT('FL', bar_num) as bar_num,
                email_addr
            from
                email_addresses e left outer join
                    (default_addresses de left outer join users u on de.user_id=u.user_id) on (e.email_addr_id=de.email_addr_id)
            where
                u.bar_num = :bar_num
        ";
        getData($addresses, $query, $dbh, array('bar_num' => $barnum), 'bar_num');
        
        if (!sizeof($addresses)) {
            // Still nothing?  Get the Bar address - it's an unregistered user
            $query = "
                select
                    CONCAT('FL', bar_num) as bar_num,
                    email_addr
                from
                    email_addresses e left outer join unreg_bar_members ub on e.email_addr_id=ub.email_addr_id
                where
                    ub.bar_num = :bar_num
            ";
            getData($addresses, $query, $dbh, array('bar_num' => $barnum),'bar_num');
        }
    }
    
    return $addresses;
}

function sanitizeString ($string) {
    // Cleans up extraneous whitespace in a string
    // At the beginning
    $string = preg_replace('/^\s+/', '', $string);
    // At the end
    $string = preg_replace('/\s+$/', '', $string);
    // And compresses any inside
    $string = preg_replace('/\s+/', ' ', $string);
    return $string;
}

function buildAddress (&$party) {
    $addrFields = array ("FirstName","MiddleName","LastName","Address1","Address2","City","State","ZipCode","FullName");
    
    $party['Suffix'] = null;
    $party['FullName'] = buildName($party);
    foreach ($addrFields as $field) {
        // Sanitize the string a little
        $party[$field] = sanitizeString($party[$field]);
    }
    
    if ($party['Address1'] == "") {
        $party['FullAddress'] = "";
        return;
    }
    
    if ($party['Address2'] != "") {
        $party['FullAddress'] = sprintf("%s\n%s\n%s, %s  %05d", $party['Address1'], $party['Address2'], $party['City'], $party['State'], $party['ZipCode']);
    } else {
        $party['FullAddress'] = sprintf("%s\n%s, %s  %05d", $party['Address1'], $party['City'], $party['State'], $party['ZipCode']);
    }
}

function getServiceList(&$partylist, $ucn) {
    // First, get the full service list from the portal
    $psl = getPortalServiceList($ucn);
    
    //Try again?
    if($psl == 'Error'){
    	sleep(3);
    	$psl = getPortalServiceList($ucn);
    }
    
    // Then, get the e-Service list from our system, merging with $psl as needed
    getEServiceList($partylist, $ucn, $psl);
    
    if(is_array($partylist['Attorneys'])){
		foreach ($partylist['Attorneys'] as &$attorney) {
			$barnum = $attorney['BarNumber'];
			
			foreach($psl['Attorneys'] as $key => $a){
				if($barnum == $key) {
					foreach($a['Addresses'] as $aAdd){
						if(isset($attorney['ServiceList'])){
							if(!in_array($aAdd, $attorney['ServiceList'])){
								$attorney['ServiceList'][] = strtolower($aAdd);
								unset($psl['Attorneys'][$key]);
							}
						}
					}
				}
			}
		}
		
		$attCount = count($partylist['Attorneys']);
		if(!empty($psl['Attorneys'])){
			foreach($psl['Attorneys'] as $key => $a){
				$partylist['Attorneys'][$attCount]['FullName'] = trim(strtoupper($a['Name']));
				$partylist['Attorneys'][$attCount]['ServiceList'] = $a['Addresses'];
				$partylist['Attorneys'][$attCount]['BarNumber'] = $key;
				$partylist['Attorneys'][$attCount]['check'] = 1;
				unset($psl['Attorneys'][$key]);
				$attCount++;
			}
		}
	}
    
	if(is_array($partylist['Parties'])){
		$count = count($partylist['Parties']);
	    //foreach ($partylist['Parties'] as &$party) {
			if(is_array($psl['Parties'])){
				foreach($psl['Parties'] as $key => $p){
					//Amy says we can't match people just on name alone...
					/*if(trim(strtoupper($p['Name'])) == trim(strtoupper($party['FullName']))){
						foreach($p['Addresses'] as $pAdd){
							if(!in_array($pAdd, $party['ServiceList'])){
								$party['ServiceList'][] = strtolower($pAdd);
							}
						}
					}
					else{*/
						$partylist['Parties'][$count]['FullName'] = trim(strtoupper($p['Name']));
						$partylist['Parties'][$count]['ServiceList'] = $p['Addresses'];
						$partylist['Parties'][$count]['check'] = 1;
						unset($psl['Parties'][$key]);
						$count++;
					//}
				}
			}
	    //}
	}
	
	$oldArray = $partylist;
	$partylist = array();
	
	$count = 0;
	foreach($oldArray['Parties'] as $p){
		$partylist['Parties'][$count] = $p;
		$count++;
	}
	
	foreach($oldArray['Attorneys'] as $a){
		$partylist['Parties'][$count] = $a;
		$count++;
	}
	
	$partylist['Parties'] = array_sort($partylist['Parties'], "FullName");
	$partylist['Parties'] = array_values($partylist['Parties']);
	
	foreach($partylist['Parties'] as &$p){
		if(count($p['ServiceList']) > 1){
			$existingEmails = array();
			foreach($p['ServiceList'] as $s){
				$search_array = array_map('strtolower', $existingEmails);
				if (!in_array(strtolower($s), $search_array)){ 
					$existingEmails[] = $s;
				}
			}
				
			$p['ServiceList'] = $existingEmails;
		}
	}
	
}

function array_sort($array, $on, $order = SORT_ASC){

	$new_array = array();
	$sortable_array = array();

	if (count($array) > 0) {
		foreach ($array as $k => $v) {
			if (is_array($v)) {
				foreach ($v as $k2 => $v2) {
					if ($k2 == $on) {
						$sortable_array[$k] = $v2;
					}
				}
			} else {
				$sortable_array[$k] = $v;
			}
		}

		switch ($order) {
			case SORT_ASC:
				asort($sortable_array);
				break;
			case SORT_DESC:
				arsort($sortable_array);
				break;
		}

		foreach ($sortable_array as $k => $v) {
			$new_array[$k] = $array[$k];
		}
	}

	return $new_array;
}

function getLinkedCases($caseid, $caseString = true, $caseList = false, $caseListAndStatus = false){
	$dbh = dbConnect("showcase-prod");
	$cases = array();
	
	$query = "  SELECT 
				CASE WHEN ToCaseID = :caseid
					THEN FromCaseNumber
					ELSE ToCaseNumber
				END AS ToCaseNumber,
				CASE WHEN ToCaseID = :caseid
					THEN FromCaseID
					ELSE ToCaseID
				END AS ToCaseID
			from
				vLinkedCases l with(nolock)
			where
			    FromCaseID = :caseid
			    OR ToCaseID = :caseid";
	
	getData($cases, $query, $dbh, array('caseid' => $caseid));
	 
	if(count($cases) > 0){
		if($caseString){
			foreach($cases as $c){
				$caseArr[] = $c['ToCaseNumber'];
			}
			
			return implode(", ", $caseArr);
		}
		else if($caseList){
			$caseList = "<ul>";
			foreach($cases as $c){
				$caseList .= "<li>" . $c['ToCaseNumber'] . "</li>";
			}
			$caseList .= "<ul>";
			
			return $caseList;
		}
		else if($caseListAndStatus){
			foreach($cases as $c){
				$caseArr[] = $c['ToCaseID'];
			}
			
			$caseStr = "CaseID IN (" . implode(", ", $caseArr) . ") ";
				
			$linkedRes = array();
			$moreInfoQuery = "
				SELECT c.CaseNumber AS ToCaseNumber,
					c.CaseType,
					c.CaseStatus,
					CONVERT(varchar, c.FileDate, 101) as FileDate,
					c.CaseStyle,
					DivisionID,
					CaseID
				FROM 
					vCase c with(nolock)
				WHERE
					$caseStr";
				
			getData($linkedRes, $moreInfoQuery, $dbh);
			
			if(!empty($linkedRes)){
				$clsList = "<ul>";
				foreach($linkedRes as $r){
					$clsList .= "<li>" . $r['ToCaseNumber'] . "&emsp;&emsp;" . $r['CaseStatus'] . "</li>";
				}
				$clsList .= "</ul>";
				
				return $clsList;
			}
		}
	}
	else{
		return "N/A";
	}
	 
}

function getCaseID($ucn) {
	$dbh = dbConnect("showcase-prod");

	$query = "
            select
                CaseID
            from
                vCase with(nolock)
            where
                CaseNumber = :casenum
        ";


	$caseInfo = getDataOne($query, $dbh, array('casenum' => $ucn));
	return $caseInfo['CaseID'];
}

function getCaseTypeDescription($caseid) {
	$dbh = dbConnect("showcase-prod");

	$query = "
            select
                CaseTypeDescription
            from
                vCase with(nolock)
            where
                CaseID = :caseid
        ";


	$caseInfo = getDataOne($query, $dbh, array('caseid' => $caseid));
	return $caseInfo['CaseTypeDescription'];
}

function getCourtTypeDescription($caseid) {
	$dbh = dbConnect("showcase-prod");

	$query = "
            select
                CourtTypeDescription
            from
                vCase with(nolock)
            where
                CaseID = :caseid
        ";


	$caseInfo = getDataOne($query, $dbh, array('caseid' => $caseid));
	return $caseInfo['CourtTypeDescription'];
}

function getCaseFileDate($caseid) {
	$dbh = dbConnect("showcase-prod");

	$query = "
            select
                CONVERT(varchar, FileDate, 101) as FileDate
            from
                vCase with(nolock)
            where
                CaseID = :caseid
        ";


	$caseInfo = getDataOne($query, $dbh, array('caseid' => $caseid));
	return $caseInfo['FileDate'];
}

function getChildrenAndDOBs($caseid){
	$dbh = dbConnect("showcase-prod");
	
	$children = array();
	$results = array();
	$query = "
				SELECT 
					FirstName, 
					MiddleName, 
					LastName, 
					DOB
				FROM
					vAllParties
				WHERE CaseID = :caseid
				AND PartyTypeDescription = 'CHILD'
				AND Active = 'Yes'
				AND (Discharged = 0 OR Discharged IS NULL)
				ORDER BY DOB DESC";
	
	getData($results, $query, $dbh, array("caseid" => $caseid));
	
	$count = 0;
	if(!empty($results)){
		foreach($results as $r){
			$name = $r['FirstName'];
			
			if(!empty($r['MiddleName'])){
				$name .= " " . $r['MiddleName'] . " ";
			}
			
			$name .= " " . $r['LastName'];
			$dob = date('m/d/y', strtotime($r['DOB']));
			$children[$count]['name'] = $name;
			$children[$count]['dob'] = $dob;
			$count++;
		}
	}
	
	$returnString = "";
	if($count > 0){
		$returnString .= "<table style='display:inline-table;'>";
		$returnString .= "<tr>";
		$returnString .= "<td>";
		$returnString .= "<strong>CHILD NAME</strong>";
		$returnString .= "</td>";
		$returnString .= "<td>";
		$returnString .= "<strong>DATE OF BIRTH</strong>";
		$returnString .= "</td>";
		$returnString .= "</tr>";
		foreach($children as $c){
			$returnString .= "<tr>";
			$returnString .= "<td>";
			$returnString .= $c['name'];
			$returnString .= "</td>";
			$returnString .= "<td>";
			$returnString .= $c['dob'];
			$returnString .= "</td>";
			$returnString .= "</tr>";
		}
		$returnString .= "</table>";
		return $returnString;
	}
	else{
		$returnString .= "<table style='display:inline-table;'>";
		$returnString .= "<tr>";
		$returnString .= "<td>";
		$returnString .= "<strong>CHILD NAME</strong>";
		$returnString .= "</td>";
		$returnString .= "<td>";
		$returnString .= "<strong>DATE OF BIRTH</strong>";
		$returnString .= "</td>";
		$returnString .= "</tr>";
		$returnString .= "<tr>";
		$returnString .= "<td> </td>";
		$returnString .= "<td> </td>";
		$returnString .= "</tr>";
		$returnString .= "</table>";
		return $returnString;
	}
}

function getPetitionerName($caseid) {
	$dbh = dbConnect("showcase-prod");

	$query = "
            select
                FirstName, 
				MiddleName, 
				LastName
            from
                vAllParties
            where
                CaseID = :caseid
			and 
				PartyTypeDescription IN ('PETITIONER', 'PLAINTIFF/PETITIONER')
			and
				Active = 'Yes'
        ";

	$results = array();
	getData($results, $query, $dbh, array('caseid' => $caseid));
	
	$count = 0;
	$petName = "";
	if(!empty($results)){
		foreach($results as $r){
			if($count > 0){
				$petName .= ", ";
			}
			
			$petName .= $r['FirstName'];
		
			if(!empty($r['MiddleName'])){
				$petName .= " " . $r['MiddleName'] . " ";
			}
			
			$petName .= " " . $r['LastName'];
			$count++;
		}
	}
	else{
		$petName = "";
	}

	return $petName;
}

function getPetitionerAttorney($caseid) {
	$dbh = dbConnect("showcase-prod");

	$query = "
            SELECT 
				AttorneyName
			FROM 
				vAttorney a
			INNER JOIN 
				vAllParties p
				ON p.PersonID = a.Represented_PersonID
				AND p.CaseID = a.CaseID
				AND p.PartyTypeDescription IN ('PLAINTIFF/PETITIONER', 'PETITIONER')
            where
                a.CaseID = :caseid
        ";

	$results = array();
	getData($results, $query, $dbh, array('caseid' => $caseid));
	
	$count = 0;
	$petAttyName = "";
	if(!empty($results)){
		foreach($results as $r){
			if($count > 0){
				$petAttyName .= ", ";
			}
				
			$petAttyName .= $r['AttorneyName'];
			$count++;
		}
	}
	else{
		$petAttyName = "N/A";
	}

	return $petAttyName;
}

function getRespondentName($caseid) {
	$dbh = dbConnect("showcase-prod");

	$query = "
            select
                FirstName,
				MiddleName,
				LastName
            from
                vAllParties
            where
                CaseID = :caseid
			and 
				PartyTypeDescription IN ('RESPONDENT', 'DEFENDANT/RESPONDENT')
			and
				Active = 'Yes'
        ";

	$results = array();
	getData($results, $query, $dbh, array('caseid' => $caseid));
	
	$count = 0;
	$respName = "";
	if(!empty($results)){
		foreach($results as $r){
			if($count > 0){
				$respName .= ", ";
			}
				
			$respName .= $r['FirstName'];
	
			if(!empty($r['MiddleName'])){
				$respName .= " " . $r['MiddleName'] . " ";
			}
				
			$respName .= " " . $r['LastName'];
			$count++;
		}
	}
	else{
		$respName = "";
	}

	return $respName;
}

function getRespondentAttorney($caseid) {
	$dbh = dbConnect("showcase-prod");

	$query = "
            SELECT
				AttorneyName
			FROM
				vAttorney a
			INNER JOIN 
				vAllParties p
				ON p.PersonID = a.Represented_PersonID
				AND p.CaseID = a.CaseID
				AND p.PartyTypeDescription IN ('DEFENDANT/RESPONDENT', 'RESPONDENT')
            where
                a.CaseID = :caseid
        ";

	
	$results = array();
	getData($results, $query, $dbh, array('caseid' => $caseid));
	
	$count = 0;
	$respAttyName = "";
	if(!empty($results)){
		foreach($results as $r){
			if($count > 0){
				$respAttyName .= ", ";
			}
			$respAttyName .= $r['AttorneyName'];
			$count++;
		}
	}
	else{
		$respAttyName = "N/A";
	}

	return $respAttyName;
}

function getRespondentAttorneyBarNumber($caseid) {
	$dbh = dbConnect("showcase-prod");

	$query = "
            SELECT
				a.BarNumber
			FROM
				vAttorney a
			INNER JOIN 
				vAllParties p
				ON p.PersonID = a.Represented_PersonID
				AND p.CaseID = a.CaseID
				AND p.PartyTypeDescription IN ('DEFENDANT/RESPONDENT', 'RESPONDENT')
            where
                a.CaseID = :caseid
        ";

	$results = array();
	getData($results, $query, $dbh, array('caseid' => $caseid));
	
	$count = 0;
	$barNumber = "";
	if(!empty($results)){
		foreach($results as $r){
			if($count > 0){
				$barNumber .= ", ";
			}
			$barNumber .= $r['BarNumber'];
			$count++;
		}
	}
	else{
		$barNumber = "N/A";
	}

	return $barNumber;
}

function getPlaintiffName($caseid) {
	$dbh = dbConnect("showcase-prod");

	$query = "
            select
                FirstName,
				MiddleName,
				LastName
            from
                vAllParties
            where
                CaseID = :caseid
			and
				PartyTypeDescription IN ('PLAINTIFF', 'PLAINTIFF/PETITIONER')
			and
				Active = 'Yes'
        ";

	$results = array();
	getData($results, $query, $dbh, array('caseid' => $caseid));

	$count = 0;
	$pltName = "";
	if(!empty($results)){
		foreach($results as $r){
			if($count > 0){
				$pltName .= ", ";
			}
			
			$pltName .= $r['FirstName'];

			if(!empty($r['MiddleName'])){
				$pltName .= " " . $r['MiddleName'] . " ";
			}
	
			$pltName .= " " . $r['LastName'];
			$count++;
		}
	}
	else{
		$pltName = "";
	}

	return $pltName;
}

function getDefendantName($caseid) {
	$dbh = dbConnect("showcase-prod");

	$query = "
            select
                FirstName,
				MiddleName,
				LastName
            from
                vAllParties
            where
                CaseID = :caseid
			and
				PartyTypeDescription IN ('DEFENDANT', 'DEFENDANT/RESPONDENT')
			and
				Active = 'Yes'
        ";

	$results = array();
	getData($results, $query, $dbh, array('caseid' => $caseid));

	$count = 0;
	$dftName = "";
	if(!empty($results)){
		foreach($results as $r){
			if($count > 0){
				$dftName .= ", ";
			}
				
			$dftName .= $r['FirstName'];

			if(!empty($r['MiddleName'])){
				$dftName .= " " . $r['MiddleName'] . " ";
			}

			$dftName .= " " . $r['LastName'];
			$count++;
		}
	}
	else{
		$dftName = "";
	}

	return $dftName;
}

function getPlaintiffNameAndAddress($caseid) {
	$dbh = dbConnect("showcase-prod");

	$query = "
             SELECT
                p.FirstName,
				p.LastName,
				Address1,
				Address2,
				City,
				State,
				ZipCode
            FROM
				vAllParties p
			LEFT OUTER JOIN 
				vAllPartyAddress a
			ON 
				p.CaseID = a.CaseID
				AND p.PersonID = a.PartyID
				AND a.DefaultAddress = 'Yes'
			WHERE
				p.CaseID = :caseid
			AND
				p.PartyTypeDescription IN ('PLAINTIFF', 'PLAINTIFF/PETITIONER')
			and
				p.Active = 'Yes'
        ";

	$results = array();
	getData($results, $query, $dbh, array('caseid' => $caseid));
	
	$count = 0;
	$pltName = "";
	$address = "";
	if(!empty($results)){
		foreach($results as $r){
			if($count > 0){
				$address .= ", ";
			}
			
			$pltName = $r['FirstName'];
			
			if(!empty($r['MiddleName'])){
				$pltName .= " " . $r['MiddleName'] . " ";
			}
			
			$pltName .= " " . $r['LastName'];
			
			$address .= $pltName . ", ";
			$address .= $r['Address1'];
			if(!empty($r['Address2'])){
				$address .= ", " . $r['Address2'];
			}
			if(!empty($r['Address1'])){
				$address .= ", " . $r['City'] . ", " . $r['State'] . " " . $r['Zip'];
			}
			
			$count++;
		}
	}
	else{
		$address = "";
	}

	return $address;
}

function getPersonalRepresentativeAttorneyAddress($caseid){
	$dbh = dbConnect("showcase-prod");
	
	$query = "
            SELECT
                AttorneyName,
				Address1, 
				Address2, 
				City, 
				State, 
				Zip
            FROM 
				vAttorney a
			WHERE 
				CaseID = :caseid
			AND
				Represented_PartyType = 'PR'
        ";

	$count = 0;
	$attRes = array();
	getData($attRes, $query, $dbh, array('caseid' => $caseid));

	if(!empty($attRes)){
		$address = "";
		foreach($attRes as $a){
			if($count > 0){
				$address .= "<br/><br/>";
			}
			
			$address .= $a['AttorneyName'] . "<br/>";
			$address .= $a['Address1'];
			if(!empty($a['Address2'])){
				$address .= "<br/>" . $a['Address2'];
			}
			$address .= "<br/>" . $a['City'] . ", " . $a['State'] . " " . $a['Zip'];
			$count++;
		}
	}
	else{
		$query = "
            SELECT
                p.FirstName,
				p.LastName,
				Address1,
				Address2,
				City,
				State,
				ZipCode
            FROM
				vAllParties p
			INNER JOIN 
				vAllPartyAddress a
			ON 
				p.CaseID = a.CaseID
				AND p.PersonID = a.PartyID
				AND a.DefaultAddress = 'Yes'
			WHERE
				p.CaseID = :caseid
			AND
				p.PartyType = 'PR'
        ";
		
		$count = 0;
		$partyRes = array();
		getData($partyRes, $query, $dbh, array('caseid' => $caseid));
		
		$address = "";
		foreach($partyRes as $p){
			if($count > 0){
				$address .= "<br/><br/>";
			}
			
			$address = $p['LastName'] . ", " . $p['FirstName'] . "<br/>";
			$address .= $p['Address1'];
			if(!empty($p['Address2'])){
				$address .= "<br/>" . $p['Address2'];
			}
			$address .= "<br/>" . $p['City'] . ", " . $p['State'] . " " . $p['Zip'];
			$count++;
		}
	}
	
	return $address;
}

function getRespondentAttorneyAddress($caseid){
	$dbh = dbConnect("showcase-prod");

	$query = "
            SELECT
                AttorneyName,
				Address1,
				Address2,
				City,
				State,
				Zip
            FROM
				vAttorney a
			WHERE
				CaseID = :caseid
			AND
				Represented_PartyType = 'RESP'
        ";

	$attorneys = array();
	$address = "";
	getData($attorneys, $query, $dbh, array('caseid' => $caseid));

	if(!empty($attorneys)){
		$count = 0;
		foreach($attorneys as $a){
			if($count > 0){
				$address .= ", and ";
			}
			$address .= $a['AttorneyName'] . " ";
			$address .= $a['Address1'];
			if(!empty($a['Address2'])){
				$address .= " " . $a['Address2'];
			}
			$address .= " " . $a['City'] . ", " . $a['State'] . " " . $a['Zip'];
			$count++;
		}
	}

	return $address;
}

function getPropertyAddress($caseid){
	$dbh = dbConnect("showcase-prod");

	$query = "
            SELECT
                CaseNumber,
				PartyType,
				Address1,
				Address2,
				City,
				ZipCode as Zip,
				State,
				AddressType as AddrType
            FROM 
				vAllPartyAddress a
			WHERE
				CaseID = :caseid
			AND
				AddressType IN('Property Address', 'Alternative') 
			ORDER BY 
				AddressType DESC
        ";

	$caseInfo = getDataOne($query, $dbh, array('caseid' => $caseid));

	$address = " ";
	if(!empty($caseInfo)){
		$address = $caseInfo['Address1'];
		if(!empty($caseInfo['Address2'])){
			$address .= " " . $caseInfo['Address2'];
		}
		$address .= " " . $caseInfo['City'] . ", " . $caseInfo['State'] . " " . $caseInfo['Zip'];
	}
	
	return $address;
}

function getPDNames($caseid) {
	$dbh = dbConnect("showcase-prod");
	$results = array();
	
	$query = "
             SELECT
                FirstName,
				LastName,
				MiddleName
            FROM
				vAllParties
			WHERE
				CaseID = :caseid
			AND
				PartyType = 'PD'
			and
				Active = 'Yes'
        ";

	getData($results, $query, $dbh, array('caseid' => $caseid));

	$pds = "";
	$count = 0;
	if(!empty($results)){
		foreach($results as $r){
			
			if($count > 0){
				$pds .= ", ";
			}
			
			$pds .= $r['FirstName'];
	
			if(!empty($r['MiddleName'])){
				$pds .= " " . $r['MiddleName'] . " ";
			}
	
			$pds .= " " . $r['LastName'];
			$count++;
		}
	}
	else{
		$pds = "";
	}
	
	return $pds;
}

function getMostRecentDocketDate($caseid){
	$dbh = dbConnect("showcase-prod");
	
	$query = "	SELECT 
					CONVERT(varchar, MAX(EffectiveDate), 101) as DocketDate
				FROM 
					vDocket
				WHERE 
					CaseID = :caseid";
	
	$docketInfo = getDataOne($query, $dbh, array("caseid" => $caseid));
	
	if(!empty($docketInfo)){
		$docket_date = $docketInfo['DocketDate'];
	}
	else{
		$docket_date = "N/A";
	}
	
	return $docket_date;
}

function getChildCount($caseid){
	$dbh = dbConnect("showcase-prod");
	
	$query = "	SELECT
					COUNT(DISTINCT PersonID) AS child_count
				FROM
					vAllParties
				WHERE
					CaseID = :caseid
				AND 
					PartyTypeDescription IN ('CHILD', 'CHILD (CJ)')
				AND 
					Active = 'Yes'
				AND 
					(Discharged = 0 OR Discharged IS NULL)	";
	
	$child_row = getDataOne($query, $dbh, array("caseid" => $caseid));
	
	if(!empty($child_row)){
		$child_count = $child_row['child_count'];
	}
	else{
		$child_count = 0;
	}
	
	return $child_count;
}

function getAllPetRespAddresses($caseid, $partyType = ""){
	$dbh = dbConnect("showcase-prod");

	$query = "	SELECT 
					p.PartyTypeDescription, 
					p.LastName, 
					p.FirstName, 
					p.MiddleName, 
					pa.Address1, 
					pa.Address2, 
					pa.City, 
					pa.State, 
					pa.ZipCode
				FROM 
					vAllPartyAddress pa
				INNER JOIN vAllParties p
					ON p.CaseID = pa.CaseID
					AND p.PersonID = pa.PartyID
					AND Active = 'Yes'
					AND ( Discharged IS NULL OR Discharged = 0 )
					AND ( CourtAction IS NULL OR CourtAction LIKE 'Disposed%' )";
	
	if(empty($partyType)){
		$query .= " AND p.PartyTypeDescription IN ('PLAINTIFF/PETITIONER', 'ATTORNEY', 'PLAINTIFF', 'PETITIONER', 'DEFENDANT', 'RESPONDENT', 'DEFENDANT/RESPONDENT') ";
	}
	else{
		$query .= " AND p.PartyTypeDescription IN ($partyType) ";
	}
				
	$query .= "	WHERE pa.CaseID = :caseid
				AND ( pa.AddressActive IS NULL OR pa.AddressActive = 'Yes' )	";

	$addresses = array();
	getData($addresses, $query, $dbh, array("caseid" => $caseid));
	
	$fullAddresses = array();

	if(!empty($addresses)){
		foreach($addresses as $a){
			$name = "";
			$address = "";
			if(!empty($a['FirstName'])){
				$name .= $a['FirstName'];
				
				if(!empty($a['MiddleName'])){
					$name .= " " . $a['MiddleName'];
				}
				
				$name .= " " . $a['LastName'];
			}
			else{
				$name .= $a['LastName'];
			}
			
			$address .= $a['Address1'];
			
			if(!empty($a['Address2'])){
				$address .= ", " . $a['Address2'];
			}
			
			if(!empty($a['City'])){
				$address .= ", " . $a['City'];
			}
			
			if(!empty($a['State'])){
				$address .= ", " . $a['State'];
			}
			
			if(!empty($a['ZipCode'])){
				$address .= " " . $a['ZipCode'];
			}
			
			$fullAddress = $name . ", " . $address;
			
			if(empty($partyType)){
				$fullAddresses[$fullAddress] = $a['PartyTypeDescription'] . " - " . $fullAddress;
			}
			else{
				$fullAddresses[] = $fullAddress;
			}
		}
	}

	if(!empty($partyType)){
		if(!empty($fullAddresses)){
			$fullAddresses = implode(", ", $fullAddresses);
		}
		else{
			$fullAddresses = "__________________________________________";
		}
	}
	
	return $fullAddresses;
}

function getAllPetRespNames($caseid){
	$dbh = dbConnect("showcase-prod");

	$query = "	SELECT
					p.PartyTypeDescription,
					p.LastName,
					p.FirstName,
					p.MiddleName
				FROM
					vAllParties p
					WHERE p.CaseID = :caseid
					AND Active = 'Yes'
					AND ( Discharged IS NULL OR Discharged = 0 )
					AND ( CourtAction IS NULL OR CourtAction LIKE 'Disposed%' )
					AND p.PartyTypeDescription IN ('PLAINTIFF/PETITIONER', 'ATTORNEY', 'PLAINTIFF', 'PETITIONER', 'DEFENDANT', 'RESPONDENT', 'DEFENDANT/RESPONDENT')";

	$names = array();
	getData($names, $query, $dbh, array("caseid" => $caseid));

	$fullNames = array();

	if(!empty($names)){
		foreach($names as $n){
			$name = "";
			if(!empty($n['FirstName'])){
				$name .= $n['FirstName'];

				if(!empty($n['MiddleName'])){
					$name .= " " . $n['MiddleName'];
				}

				$name .= " " . $n['LastName'];
			}
			else{
				$name .= $n['LastName'];
			}
				
			if(!empty($name)){
				$fullNames[$name] = $n['PartyTypeDescription'] . " - " . $name;
			}
		}
	}

	return $fullNames;
}

function getADAText(){
	$config = simplexml_load_file($_SERVER['APP_ROOT'] . "/conf/ICMS.xml");
	$adaCoordinator = $config->{'ADACoordinator'};
	$text = '<pagebreak />
			<p>This notice is provided pursuant to Administrative Order No. 2.207</p>
			<br />
			<div class="notice"><p class="ind">&ldquo;If you are a <u>person with a disability</u> who needs any accommodation in order to participate in this proceeding, you are entitled, at no cost to you, to the provision of certain assistance. Please contact ' . $adaCoordinator . ', Americans with Disabilities Act Coordinator, Sarasota Beach County Courthouse, 205 North Dixie Highway West Sarasota Beach, Florida 33401; telephone number (561) 355-4380 at least 7 days before your scheduled court appearance, or immediately upon receiving this notification if the time before the scheduled appearance is less than 7 days; if you are hearing or voice impaired, call 711.&rdquo;</p></div>
			<div class="notice"><p class="ind">&ldquo;Si usted es una <u>persona minusv&aacute;lida</u> que necesita alg&uacute;n acomodamiento para poder participar en este procedimiento, usted tiene derecho, sin tener gastos propios, a que se le provea cierta ayuda.  Tenga la amabilidad de ponerse en contacto con ' . $adaCoordinator . ', 205 N. Dixie Highway, West Sarasota Beach, Florida 33401; tel&eacute;fono n&uacute;mero (561) 355-4380, por lo menos 7 d&iacute;as antes de la cita fijada para su comparecencia en los tribunales, o inmediatamente despu&eacute;s de recibir esta notificaci&oacute;n si el tiempo antes de la comparecencia que se ha programado es menos de 7 d&iacute;as; si usted tiene discapacitaci&oacute;n del o&iacute;do o de la voz, llame al 711.&rdquo;</p></div>
			<div class="notice"><p class="ind">&ldquo;Si ou se yon <u>moun ki enfim</u> ki bezwen akomodasyon pou w ka patisipe nan pwosedi sa, ou kalifye san ou pa gen okenn lajan pou w peye, gen pwovizyon pou jwen k&egrave;k &egrave;d. Tanpri kontakte ' . $adaCoordinator . ', k&ograve;&ograve;donat&egrave; pwogram Lwa pou ameriken ki Enfim yo nan Tribinal Konte Sarasota Beach la ki nan 205 North Dixie Highway, West Sarasota Beach, Florida 33401; telef&ograve;n li se (561) 355-4380 nan 7 jou anvan dat ou gen randevou pou par&egrave;t nan tribinal la, oubyen imedyatman apre ou fin resevwa konvokasyon an si l&egrave; ou gen pou w par&egrave;t nan tribinal la mwens ke 7 jou; si ou gen pwobl&egrave;m pou w tande oubyen pale, rele 711.&rdquo;</p></div>';
	return base64_encode($text);
}

function getInterpreterText(){
	$text = '<div style="border:1px solid black; padding:0.5%; text-align:left;">
			<strong><u>INTERPRETERS:</u> It is the responsibility of the party needing an interpreter to bring to court an interpreter who is <u>certified, language skilled, provisionally approved or who is registered with the Office of State Court Administrator</u>, as required by Rule 2.560 and Rule 2.565 of the Florida Rules of Judicial Administration.  For further information or for assistance locating an interpreter, please visit our website at <a href="http://15thcircuit.co.Sarasota-beach.fl.us/web/guest/court-interpreters">http://15thcircuit.co.Sarasota-beach.fl.us/web/guest/court-interpreters</a>. Persons unable to obtain an interpreter may bring someone to assist. The Court shall determine if they are qualified to interpret the proceedings.</strong>
			<br/><br/>
			<strong><u>INT&Eacute;RPRETES:</u> Si una parte litigante necesita un int&eacute;rprete, es su responsabilidad  traer consigo al tribunal un int&eacute;rprete <u>certificado,  aprobado provisionalmente, capacitado en idiomas, o que este registrado con la Oficina Administrativa del Tribunal Estatal</u>, conforme a la Regla 2.560, y la Regla 2.565, de las Reglas Judiciales Administrativas de la Florida. Si requiere m&aacute;s informaci&oacute;n o necesita ayuda para localizar un int&eacute;rprete, por favor visite nuestro sitio web en <a href="http://15thcircuit.co.Sarasota-beach.fl.us/web/guest/court-interpreters">http://15thcircuit.co.Sarasota-beach.fl.us/web/guest/court-interpreters</a>. Las personas que no puedan obtener un int&eacute;rprete, pueden traer una persona que les pueda asistir. El Juez determinar&aacute; si la persona est&aacute; calificada para interpretar en dicho procedimiento.</strong>
			<br/><br/>
			<strong><u>ENT&Egrave;PR&Egrave;T:</u> Selon R&egrave;gleman 2.560 and R&egrave;gleman 2.565 Administrasyon Jidisy&egrave; Florid, se responsablite moun ke bezwen <u>ent&egrave;pr&egrave;t la ki sipoze mennen yon ent&egrave;pr&egrave;t s&egrave;tifye, kalifye, aprouve provizwaman, oswa anrejistre ak Biro Administrasyon Tribinal Leta</u>. Pou plis enf&ograve;masyon sou asistans lokalize yon ent&egrave;pr&egrave;t, tanpri vizite sit Ent&egrave;n&egrave;t <a href="http://15thcircuit.co.Sarasota-beach.fl.us/web/guest/court-interpreters">http://15thcircuit.co.Sarasota-beach.fl.us/web/guest/court-interpreters</a>. Moun ki pa kapab jwenn yon ent&egrave;pr&egrave;t gendwa mennen yon moun pou &egrave;de.  Tribinal la va det&egrave;mine si moun sa a kalifye pou ent&egrave;prete nan prosedi yo.</strong>
			</div>';
	
	return base64_encode($text);
}

function getGMVacateText(){
	$text = '<div style="border:1px solid black; padding:0.5%; text-align:left;">
			<strong>ANY PARTY AFFECTED BY THIS ORDER MAY MOVE TO VACATE THE ORDER BY FILING A MOTION TO VACATE WITHIN TEN (10) DAYS FROM THE ENTRY OF THIS ORDER.  FOR THE PURPOSE OF HEARING ON A MOTION TO VACATE, A RECORD SHALL BE PROVIDED TO THE COURT BY THE PARTY SEEKING REVIEW IN CONFORMITY WITH RULE 12.491 OF FLA. FAM. L. R. P.  TRANSCRIPTS AND ELECTRONIC RECORDINGS CAN BE OBTAINED THROUGH THE COURT REPORTING SERVICES WEB REQUEST FORM AT <a href="https://e-services.co.Sarasota-beach.fl.us/crtrpt/" target="_blank">https://e-services.co.Sarasota-beach.fl.us/crtrpt/</a>.  PURSUANT TO RULE 12.491(G), ANY PARTY MAY PETITION TO MODIFY THE ORDER AT ANY TIME.</strong>
			</div>';

	return base64_encode($text);
}

function getFileExpText(){
	$text = '<div style="border:1px solid black; padding:0.5%;">
			<strong>
				<div style="text-align:center"><u>NOTICE RE: FILING EXCEPTIONS, RULE 12.490</u></div>
				<div style="text-align:left">SHOULD YOU WISH TO SEEK REVIEW OF THE REPORT AND RECOMMENDATIONS MADE BY THE GENERAL MAGISTRATE, YOU MUST FILE EXCEPTIONS IN ACCORDANCE WITH RULE 12.490 (f), FLA. FAM. L. R.P.   YOUR EXCEPTIONS MUST BE FILED WITHIN TEN (10) DAYS OF THE ABOVE DATE OR WITHIN FIFTEEN (15) DAYS IF YOU WERE SERVED WITH THIS REPORT BY MAIL.  SERVE A COPY ON THE OPPOSING PARTY AND THE GENERAL MAGISTRATE.  YOU WILL BE REQUIRED TO PROVIDE THE COURT WITH A RECORD SUFFICIENT TO SUPPORT YOUR EXCEPTIONS OR YOUR EXCEPTIONS WILL BE DENIED.  THE PERSON SEEKING REVIEW MUST HAVE THE TRANSCRIPT PREPARED IF NECESSARY FOR THE COURT\'S REVIEW.  TRANSCRIPTS AND ELECTRONIC RECORDINGS MAY BE OBTAINED THROUGH THE COURT REPORTING SERVICES WEB REQUEST FORM AT <a href="https://e-services.co.Sarasota-beach.fl.us/crtrpt/" target="_blank">https://e-services.co.Sarasota-beach.fl.us/crtrpt/</a>.</div>
			</strong>
			</div>';

	return base64_encode($text);
}

function getTranslatorText(){
	$text = '<p style="font-weight:bold; font-size:14pt">Court proceedings are conducted in English.  If you have difficulty speaking or understanding English, please bring a translator.</p>
			<br/>
			<div style="border:1px solid black; width:75%; margin:0 auto; padding:0.5%; text-align:left; font-size:14pt">
				Los procedimientos en los tribunales se llevan a cabo en ingl&eacute;s.  Si usted tiene dificultad en hablar o entender el ingl&eacute;s.  Por favor traiga un int&eacute;rprete. 
			</div>
			<br/>
			<div style="border:1px solid black; width:75%; margin:0 auto; padding:0.5%; text-align:left; font-size:14pt">
				Yo f&egrave; Pwosedi Tribinal yo an Angl&egrave;.  Si ou gen difkilte pou pale ou byen konprann Angl&egrave;, tanpri vini av&egrave;k yon Ent&egrave;pr&egrave;t.  
			</div>';

	return base64_encode($text);
}

function decrypt_sig ($sig, $key) {
    $decoded = base64_decode(mb_convert_encoding($sig, "BASE64", "UTF-8"));
    
    $cipher = new Crypt_CBC($key, "BLOWFISH");
    
    $decrypted = $cipher->decrypt($decoded);
    if (PEAR::isError($decrypted)) {
        $ret = null;
    } else {
        $ret = $decrypted;
    }
    
    return $ret;
}

function getUserQueues (&$queues, $dbh) {
    $query = "
        select
            userid as QueueName,
            first_name as FirstName,
            middle_name as MiddleName,
            last_name as LastName,
            suffix as Suffix
        from
            users
        order by
            LastName desc
    ";
    $temp = array();
    getData($temp, $query, $dbh);
    
    foreach ($temp as $user) {
        $queue = array('queue' => strtolower($user['QueueName']));
        $queue['queuedscr'] = buildName($user);
        array_push($queues, $queue);
    }
}

function buildName (&$name, $lastfirst = 0) {    
    if ($name == null) {
        return null;
    }
    $last = $name['LastName'];   
    
    if ($name['Suffix'] != null) {
        $last = sprintf("%s, %s", $name['LastName'], $name['Suffix']);
    }
    
    $fullname = "";
    
    if ($name['MiddleName'] != null) {
        if (strlen($name['MiddleName']) == 1) {
            $name['MiddleName'] .= ".";
        }
        if ($lastfirst) {
            $fullname = sprintf("%s %s %s", $last, $name['FirstName'], $name['MiddleName']);
        } else {
            $fullname = sprintf("%s %s %s", $name['FirstName'], $name['MiddleName'], $last);
        }
    } else {
        if ($lastfirst) {
            $fullname = sprintf("%s, %s", $last, $name['FirstName']);
        } else {
            $fullname = sprintf("%s %s", $name['FirstName'], $last);
        }
    }
    
    return $fullname;
}

function curlJson ($url, $postFields) {
    $ch = curl_init($url);

    $args = array();
    foreach ($postFields as $key=>$value) {
        array_push($args, sprintf("%s=%s", $key, $value));
    }
    
    curl_setopt($ch, CURLOPT_POST, count($fields));
    curl_setopt($ch, CURLOPT_POSTFIELDS, implode("&", $args));
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    
    $user = $_SESSION['user'];
    $pass = $_SERVER['PHP_AUTH_PW'];
    curl_setopt($ch, CURLOPT_USERPWD, "$user:$pass");
                
    $result = curl_exec($ch);
    curl_close($ch);
    
    return $result;
}

function eFileInfo  ($user, $dbh) {
    $query = "
        select
            p.user_id,
            p.portal_id,
            p.password,
            p.bar_num,
            pt.portal_user_type_name
        from
            portal_users p left outer join portal_user_types pt on (p.portal_user_type_id=pt.portal_user_type_id)
        where
            user_id = :userid
    ";
    
    $userInfo = getDataOne($query, $dbh, array('userid' => $user));
    
    $config = simplexml_load_file($_SERVER['APP_ROOT'] . "/conf/ICMS.xml");
    $ldapConf = $config->{'ldapConfig'};
    $filter = "(sAMAccountName=$user)";
    $userdata = array();

    ldapLookup($userdata, $filter, $ldapConf, null, array('givenname','sn'), (string) $ldapConf->{'userBase'});

    $userInfo['first_name'] = $userdata[0]['givenname'][0];
    $userInfo['last_name'] = $userdata[0]['sn'][0];
        
    return $userInfo;
}

function getCaseInfo ($casenum) {
    $config = simplexml_load_file($_SERVER['APP_ROOT'] . "/conf/ICMS.xml");
    $wsUrl = sprintf("%s/vrbcaseinfo", $config->{'icmsWebService'});
    
    $postFields = array (
        'casenum' => urlencode($casenum)
    );
    
    $json = curlJson($wsUrl,$postFields);
    return $json;
}

function getDivType($division, $dbh = null) {
    if ($dbh == null) {
        $dbh = dbConnect("judge-divs");
    }
    
    $query = "
        select
            division_type
        from
            divisions
        where
            division_id = :division
    ";
    $div = getDataOne($query, $dbh, array('division' => $division));
    return $div['division_type'];
}

function getEsigs (&$sigs, $user) {
    // Returns information on the e-signatures this user is permitted to use
    $dbh = dbConnect("portal_info");
    
    // First, check to see if we have a signature for this particular user (it should always be first in the
    // list, if so).
	$query = "
		select
			LOWER(user_id) as user_id,
			first_name as FirstName,
			middle_name as MiddleName,
			last_name as LastName,
			suffix as Suffix
		from
			signatures
		where
			user_id = :user
	";
    
    getData($sigs, $query, $dbh, array('user' => $user));
    
    // And then get and signatures this user is permitted to use
	$query = "
		select
			LOWER(s.user_id) as user_id,
			s.first_name as FirstName,
			s.middle_name as MiddleName,
			s.last_name as LastName,
			s.suffix as Suffix
		from
			signatures s,
			sig_users su
		where
			su.user_id = :user
			and su.sig_user = s.user_id
			and su.active = 1
		order by
			s.last_name
	";
    getData($sigs, $query, $dbh, array('user' => $user));
    
    return sizeof($sigs);
}

function getDocInfo ($docid, $dbh = null) {
    if ($dbh == null) {
        $dbh = dbConnect("icms");
    }
    
    $query = "
        select
            doc_id as DocID,
            queue as WFQueue,
            ucn as UCN,
            title as Title,
            creator as DocCreator,
            creation_date as CreationDate,
            signer_id as SignerID,
            signed_time as SignedTime,
            CASE
                WHEN signature_img is null THEN 'N'
                ELSE 'Y'
            END as ESigned,
            color as Color,
            CASE doc_type
                 WHEN 'FORMORDER' then 'IGO'
    			 WHEN 'DVI' then 'DVI'
                 WHEN 'OLSORDER' then 'PropOrd'
        		 WHEN 'WARRANT' then 'Warrant'
        		 WHEN 'EMERGENCYMOTION' then 'EmerMot'
    			 ELSE 'PropOrd'
            END as DocType,
            finished as Finished,
            due_date as DueDate,
            formname as FormName
        from
            workflow
        where
            doc_id = :docid
    ";
    return getDataOne($query, $dbh, array('docid' => $docid));
}

function isCircuit ($ucn) {
    // Returns 1 or 0, based on the UCN
    $divType = (preg_match('/CF|CA|MH|GA|CP|DR|CJ|DP/', $ucn)) ? 1 : 0;
    
    return $divType;
}

function getTitle($sigUser, $docid, $dbh = null, $wdbh = null) {
	
	//error_log("Sig User= ".$sigUser."\nDocID=".$docid);
	if ($dbh == null) {
        $dbh = dbConnect("portal_info");
    }
    
    if ($wdbh == null) {
        $wdbh = dbConnect("icms");
    }
    
    $docInfo = getDocInfo($docid, $wdbh);
    $ucn = $docInfo['UCN'];
    
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
    
    $sigInfo = getDataOne($query, $dbh, array('userid' => $sigUser));
    $sigInfo['ucn'] = $ucn;
    
    if (array_key_exists('user_sig', $sigInfo)) {
        $sigInfo['FullName'] = buildName($sigInfo);
        // Ok, we have a signature.  Look up information on the user and generate the file
        $config = simplexml_load_file($_SERVER['APP_ROOT'] . "/conf/ICMS.xml");
        $ldapConf = $config->{'ldapConfig'};
        $filter = "(sAMAccountName=$sigUser)";
        $userdata = array();
        
        ldapLookup($userdata, $filter, $ldapConf, null, array('title'),
                   (string) $ldapConf->{'userBase'});
        $sigInfo['Title'] = $userdata[0]['title'][0];
        
        /*if (preg_match('/judge/i', $sigInfo['Title'])) {
            if (isCircuit($ucn)) {
                $sigInfo['Title'] = 'Circuit Judge';
            } else {
                $sigInfo['Title'] = 'County Court Judge';
            }
        } elseif (strtolower($sigUser) == 'sblumberg') {
            $sigInfo['Title'] = 'Traffic Hearing Officer';
        }*/
        
        if (strtolower($sigUser) == 'sblumberg') {
        	$sigInfo['Title'] = 'Traffic Hearing Officer';
        }

	}
		return $sigInfo;
	
}

function generateSignature($sigUser, $docid, $dbh = null, $wdbh = null) {
	
	//error_log("Sig User= ".$sigUser."\nDocID=".$docid);
    global $SIGXPIXELS, $SIGYPIXELS;
    if ($dbh == null) {
        $dbh = dbConnect("portal_info");
    }
    
    if ($wdbh == null) {
        $wdbh = dbConnect("icms");
    }
    
    $docInfo = getDocInfo($docid, $wdbh);
    $ucn = $docInfo['UCN'];
    
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
    
    $sigInfo = getDataOne($query, $dbh, array('userid' => $sigUser));
    $sigInfo['ucn'] = $ucn;
    
    if (array_key_exists('user_sig', $sigInfo)) {
        $sigInfo['FullName'] = buildName($sigInfo);
        // Ok, we have a signature.  Look up information on the user and generate the file
        $config = simplexml_load_file($_SERVER['APP_ROOT'] . "/conf/ICMS.xml");
        $ldapConf = $config->{'ldapConfig'};
        $filter = "(sAMAccountName=$sigUser)";
        $userdata = array();
        
        ldapLookup($userdata, $filter, $ldapConf, null, array('title'),
                   (string) $ldapConf->{'userBase'});
        $sigInfo['Title'] = $userdata[0]['title'][0];
        
        /*if (preg_match('/judge/i', $sigInfo['Title'])) {
        	if($sigInfo['Title'] != "Senior Judge"){
	            if (isCircuit($ucn)) {
	                $sigInfo['Title'] = 'Circuit Judge';
	            } else {
	                $sigInfo['Title'] = 'County Court Judge';
	            }
        	}
        } elseif (strtolower($sigUser) == 'sblumberg') {
            $sigInfo['Title'] = 'Traffic Hearing Officer';
        }*/
        
        if (strtolower($sigUser) == 'sblumberg') {
        	$sigInfo['Title'] = 'Traffic Hearing Officer';
        }
        
        // Now generate the signature image
        
        $jpg = pack("H*", $sigInfo['user_sig']);
        
        $origImg = imagecreatefromstring($jpg);
        $width = imagesx($origImg);
        $height = imagesy($origImg);
        
        $newimg = imagecreate($SIGXPIXELS, $SIGYPIXELS+70);
        
        // Set the colors
        $black = imagecolorallocate($newimg,0,0,0);
        $gray = imagecolorallocatealpha($newimg,225,225,225,127);
        $white = imagecolorallocate($newimg,255,255,255);
        imagecopyresampled($newimg, $origImg,0, 0, 0, 0, $SIGXPIXELS, $SIGYPIXELS, $width, $height);
        
        if (1 == 0) {
            $style = array($black,$black,$black,$black,IMG_COLOR_TRANSPARENT,IMG_COLOR_TRANSPARENT);
            imagesetstyle($newimg,$style);
            imagerectangle($newimg,0,0,$SIGXPIXELS-2, $SIGYPIXELS-2,$black);
        }
        
        $textheight = 10;
        
        // The top/right of the watermark box
        $wmTop = 35;
        $wmMargin = 20;
        
        // Top/right corners of the name box
        $nameTop = $SIGYPIXELS - $textheight - 15;
        
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
        imagettftext($newimg, $textheight+2, 0, 40,120,
                     $black, $font2, $titleString);
        
        $outfile=tempnam("/var/jvs/public_html/tmp", "sig");
        $outfile .= ".jpg";
        ob_start();
        imagejpeg($newimg);
        $imageString = ob_get_clean();
        
        // Output it to a file
        //file_put_contents($outfile, $imageString);
        
        // AND save it to the database for later re-use.
        $query = "
            update
                workflow
            set
                signature_img = :sigimg,
                signed_time = NOW(),
                signer_id = :sigid,
                signer_name = :signame,
                signer_title = :sigtitle
            where
                doc_id = :docid
        ";
        doQuery($query, $wdbh, array('sigimg' => base64_encode($imageString), 'sigid' => $sigUser, 'docid' => $docid,
                                     'signame' => $sigInfo['FullName'], 'sigtitle' => $sigInfo['Title']));
        
        //$sigInfo['SigFile'] = sprintf("/tmp/%s", basename($outfile));
        $sigInfo['SigImg'] = base64_encode($imageString);
        
        imagedestroy($newimg);
        imagedestroy($origImg);
    }
    
    return $sigInfo;
}

function getFilingGroup($portalDesc, $dbh = null) {
    if ($dbh == null) {
        $dbh = dbConnect("portal_info");
    }
    $query = "
        select
            file_group
        from
            order_type_map
        where
            docket_desc = :pd
    ";
    $rec = getDataOne($query, $dbh, array('pd' => $portalDesc));
    return $rec['file_group'];
}

function createOrderPDF ($formhtml, $ucn, $form_name, $isTemplate = null) {
	
	list($ucn, $db_type) = sanitizeCaseNumber($ucn);
	if ($db_type == 'banner') {
		$ucn = getBannerExtendedCaseId($ucn);
	}
	
	$margins = "-L 0mm -R 0mm -B 19.5mm -T 19.5mm";
	$topMargin = "0%";
	$leftMargin = "0%";
	
	/*if($isTemplate){
		$margins = "-L 0mm -R 0mm -B 18mm -T 25.4mm";
		$topMargin = "-1%";
		$leftMargin = "12%";
	}
	else{
		$margins = "-L 25.4mm -R 25.4mm -B 20mm -T 25.4mm";
		$topMargin = "-1%";
		$leftMargin = "0%";
		
		//I don't think I can do this... I don't want to always remove underlines for PropOrds
		//$formhtml = str_replace("text-decoration:underline", "", $formhtml);
	}*/
	
	$formhtml = str_replace("<pagebreak>", "<div style=\"page-break-after: always\"><span style=\"display: none;\"> </span></div>", $formhtml);
	
	$formhtml = preg_replace('/<(?:p)(?:\s+\w+="[^"]+(?:"\$[^"]+"[^"]+)?")*>.<\\/p>/uis', "<br/>", $formhtml);
	
	//Sigh, they don't want this
	$form_name = "";
	
	$h_fname = "/var/jvs/public_html/tmp/header-order-" . $ucn . "-" . uniqid();
	$h_file = fopen($h_fname . ".html", "w");
	$h_html = "<!DOCTYPE html>
			<head>
        <meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\" />
        <script>
        function subst() {
          var vars={};
          var x=document.location.search.substring(1).split('&');
          for (var i in x) {var z=x[i].split('=',2);vars[z[0]] = unescape(z[1]);}
          var x=['frompage','topage','page','webpage','section','subsection','subsubsection'];
          for (var i in x) {
            var y = document.getElementsByClassName(x[i]);
            for (var j=0; j<y.length; ++j) y[j].textContent = vars[x[i]];

            if(vars['page'] == 1){ // If page is 1, set FakeHeaders display to none
               document.getElementById(\"header\").style.display = 'none';
            }
          }
        }
        </script>
    </head>
    <body style=\"border:0;margin:0;margin-left:" . $leftMargin . ";\" onload=\"subst()\">
        <div class=\"header\" id=\"header\" style=\"margin-top:" . $topMargin . "\"><p>$form_name</p><p>Case No. $ucn</p></div>
    </body>
	</html>";
	fwrite($h_file, $h_html);
	$finalHFileName = $h_fname . ".html";
	
	$f_fname = "/var/jvs/public_html/tmp/footer-order-" . $ucn . "-" . uniqid();
	$f_file = fopen($f_fname . ".html", "w");
	
	//I don't like this but I found it online
	$f_html = "<html><head><script>
			function subst() {
			  var vars={};
			  var x=document.location.search.substring(1).split('&');
			  for (var i in x) {var z=x[i].split('=',2);vars[z[0]] = unescape(z[1]);}
			  var x=['frompage','topage','page','webpage','section','subsection','subsubsection'];
			  for (var i in x) {
			    var y = document.getElementsByClassName(x[i]);
			    for (var j=0; j<y.length; ++j) y[j].textContent = vars[x[i]];
			  }
			}
			</script></head><body style=\"border:0; margin: 0; padding:0;\" onload=\"subst()\">
			<div class=\"footer\">Page <strong> <span class=\"page\"></span></strong> of <strong><span class=\"topage\"></strong></div>";
	fwrite($f_file, $f_html);
	$finalFFileName = $f_fname . ".html";
	
	$fname = "/var/jvs/public_html/tmp/order-" . $ucn . "-" . uniqid();
	$file = fopen($fname . ".html", "w");
	fwrite($file, $formhtml);
	$finalFileName = $fname . ".pdf";
	
	system("/usr/share/wkhtmltopdf/bin/wkhtmltopdf --footer-spacing 5 --header-spacing 5 --page-size Letter --header-html " . $finalHFileName . " --footer-html " . $finalFFileName . " --disable-smart-shrinking " . $margins . " --encoding utf-8 --user-style-sheet /var/jvs/public_html/orders/custom_forms.css " . $fname . ".html" . " " . $finalFileName);

	unlink($fname . ".html");
	unlink($finalHFileName);
	unlink($finalFFileName);
	return $finalFileName;
}

function getEmailFromAD ($user) {
    $config = simplexml_load_file($_SERVER['APP_ROOT'] . "/conf/ICMS.xml");
    
    $ldapConf = $config->{'ldapConfig'};
    $filter = "(sAMAccountName=$user)";
    $userdata = array();
    $adFields = array('mail');

    ldapLookup($userdata, $filter, $ldapConf, null, $adFields, (string) $ldapConf->{'userBase'});
    
    if (sizeof($userdata) > 0) {
        return $userdata[0]['mail'][0];
    } else {
        return null;
    }
}

function encodeFile ($filename) {
    # Returns a Base64-encoded representation of $filename
    $binary = file_get_contents($filename);
    $encoded = base64_encode($binary);
    return $encoded;
}

function getFileType ($file) {
    $finfo = finfo_open(FILEINFO_MIME_TYPE);
    $filetype = finfo_file($finfo, $file);
    finfo_close($finfo);
    return $filetype;
}

function getOpenFilings(&$filings, $dbh) {
	$query = "
		select
			filing_id
		from
			portal_filings
		where
			completion_date is null
	";
	getData($filings, $query, $dbh);
}

function returnJson($data) {
    header('Content-Type: application/json');
    print json_encode($data);
}

function initSmarty() {
	global $templateDir,$compileDir,$cacheDir;
    $smarty = new Smarty;
    $smarty->setTemplateDir($templateDir);
    $smarty->setCompileDir($compileDir);
    $smarty->setCacheDir($cacheDir);
    return $smarty;
}

function fancydate($date) {
	$month = "";
	$day = "";
	$year = "";
	# Are there slashes?
	if (preg_match('/\//', $date)) {
		list($month,$day,$year)=explode('/',$date);
	};
	if ($month!="" and $day!="" and $year!="") {
		return date("l, F jS, Y",mktime(0,0,0,$month,$day,$year));
	} else {
		return($date);
	}
}

function createTab($tabName, $href, $active, $close, $parent, $tabs = array()){
	$sess_tabs = $_SESSION['tabs'];
	$next_key = count($sess_tabs);
	
	#Deactivate all tabs
	foreach($sess_tabs as $key => $my_tabs){
		$sess_tabs[$key]['active'] = 0;
		
		if($sess_tabs[$key]['name'] == $tabName){
			$next_key = $key;
		}
		
		if(count($sess_tabs[$key]['tabs']) > 0){
			foreach($sess_tabs[$key]['tabs'] as $t_key => $e_tabs){
				$sess_tabs[$key]['tabs'][$t_key]['active'] = 0;
			}
		}
	}

	$keepTabs = "";
	
	if(!empty($sess_tabs[$next_key]['tabs'])){
		$keepTabs = $sess_tabs[$next_key]['tabs'];
		
		$sess_tabs[$next_key] = array (
				"name" => $tabName,
				"active" => $active,
				"close" => $close,
				"href" => $href,
				"parent" => $parent,
				"tabs" => $keepTabs
		);
	}
	else{
		$sess_tabs[$next_key] = array (
				"name" => $tabName,
				"active" => $active,
				"close" => $close,
				"href" => $href,
				"parent" => $parent
		);
		
	}
	
	if(isset($tabs) && !empty($tabs)){
		$tab_key = count($sess_tabs[$next_key]['tabs']);
		
		if(isset($sess_tabs[$next_key]['tabs']) && !empty($sess_tabs[$next_key]['tabs'])){
			foreach($sess_tabs[$next_key]['tabs'] as $tkey => $exist_tabs){
				if($sess_tabs[$next_key]['tabs'][$tkey]['name'] == $tabs['name']){
					$tab_key = $tkey;
				}
			}
		}
		
		$sess_tabs[$next_key]['tabs'][$tab_key] = array (
			"name" => $tabs['name'],
			"active" => $tabs['active'],
			"close" => $tabs['close'],
			"href" => $tabs['href'],
			"parent" => $tabs['parent']
		);
	}
	
	ksort($sess_tabs);
	$_SESSION['tabs'] = $sess_tabs;
}

function setActive($name){
	$sess_tabs = $_SESSION['tabs'];
	
	foreach($sess_tabs as $key => $my_tabs){
		if($sess_tabs[$key]['name'] == $name){
			$sess_tabs[$key]['active'] = 1;
		}
		else{
			$sess_tabs[$key]['active'] = 0;
		}
	}
	
	$_SESSION['tabs'] = $sess_tabs;
}

function checkLoggedIn() {
	$MAX_INACTIVE = 28800;
	$reqPage = $_SERVER['REQUEST_URI'];
	
	if(isset($_SESSION['user'])){
		apache_setenv("USER", $_SESSION['user']);
		if (!isset($_SESSION['LASTACTIVITY'])) {
			$_SESSION['LASTACTIVITY'] = time();
		} else if ((time() - $_SESSION['LASTACTIVITY']) > $MAX_INACTIVE) {
			$_SESSION['LASTACTIVITY'] = time();
	
			session_unset();
			session_destroy();
			if(!empty($reqPage)){
				$url = "/cgi-bin/logout.cgi?timeout=1&ref=" . $reqPage;
			}
			else{
				$url = "/cgi-bin/logout.cgi?timeout=1";
			}
	
			header("Location: " . $url);
			die;
		} else {
			$_SESSION['LASTACTIVITY'] = time();
		}
	}
	else{
		if(!empty($reqPage)){
			$url = "/login.php?ref=" . $reqPage;
		}
		else{
			$url = "/login.php";
		}
		
		header("Location: " . $url);
		die;
	}

	// Ok to proceed.
	return 1;
}

function getShowcaseDb(){
    # Get the name of the Showcase DB from the ICMS.xml file
    $xml = simplexml_load_file($_SERVER['APP_ROOT'] . "/conf/ICMS.xml");
    if (empty($xml->showCaseDb)) {
        return "showcase-prod";
    }
    return (string)$xml->showCaseDb;
}

function unsetQueueVars(){
	unset($_SESSION['docid']);
	unset($_SESSION['formData']);
	unset($_SESSION['form_data']);
	unset($_SESSION['order_html']);
	unset($_SESSION['case_caption']);
	unset($_SESSION['cclist']);
	unset($_SESSION['isOrder']);
	unset($_SESSION['ucn']);
	unset($_SESSION['caseid']);
	unset($_SESSION['formid']);
	unset($_SESSION['pdf_file']);
	unset($_SESSION['signature_html']);
}

function getDocData($doc_id){
	$dbh = dbConnect("icms");
	
	$query = "SELECT 
					doc_id,
					data,
					doc_type,
					ucn,
					form_id,
					title AS form_name,
					signed_filename AS pdf_file,
					signature_img,
					comments,
					user_comments,
					queue,
					portal_filing_id,
					creator,
					doc_lock_date,
					doc_lock_user,
					doc_lock_sessid
				FROM
					workflow
				WHERE
					doc_id = :doc_id";
	
	$results = array();
	getData($results, $query, $dbh, array("doc_id" => $doc_id));
	
	$docInfo = array();
	if(!empty($results)){
		foreach($results as $r){
			if(!empty($r['data'])){
				$data = json_decode($r['data'], true);
				
				if(isset($data['form_data']) && !empty($data['form_data'])){
					//$_SESSION['formData'] = $data['form_data'];
					$docInfo['formData'] = $data['form_data'];
				}
				if(isset($data['cc_list']) && !empty($data['cc_list'])){
					//$_SESSION['cc_list'] = $data['cc_list'];
					$docInfo['cc_list'] = $data['cc_list'];
				}
				if(isset($data['case_caption']) && !empty($data['case_caption'])){
					//$_SESSION['case_caption'] =  $data['case_caption'];
					$docInfo['case_caption'] = $data['case_caption'];
				}
				if(isset($data['signature_html']) && !empty($data['signature_html'])){
					//$_SESSION['signature_html'] =  $data['signature_html'];
					$docInfo['signature_html'] = $data['signature_html'];
				}
				if(isset($data['order_html']) && !empty($data['order_html'])){
					//$_SESSION['order_html'] = $data['order_html'];
					//$_SESSION['form_data'] = $data['form_data'];
					$docInfo['order_html'] = $data['order_html'];
					$docInfo['form_data'] = $data['form_data'];
				}
			}
			if(!empty($r['doc_id'])){
				//$_SESSION['docid'] = $r['doc_id'];
				$docInfo['docid'] = $r['doc_id'];
			}
			if(!empty($r['ucn'])){
				//$_SESSION['ucn'] = $r['ucn'];
				$docInfo['ucn'] = $r['ucn'];
			}
			if(!empty($r['form_id'])){
				//$_SESSION['form_id'] = $r['form_id'];
				$docInfo['form_id'] = $r['form_id'];
			}
			if(!empty($r['form_name'])){
				//$_SESSION['form_id'] = $r['form_id'];
				$docInfo['form_name'] = $r['form_name'];
			}
			if(!empty($r['doc_type'])){
				if($r['doc_type'] == "FORMORDER"){
					//$_SESSION['isOrder'] = 1;
					$docInfo['isOrder'] = 1;
				}
				else{
					//$_SESSION['isOrder'] = 0;
					$docInfo['isOrder'] = 0;
				}
			}
			if(!empty($r['pdf_file'])){
				//$_SESSION['form_id'] = $r['form_id'];
				$docInfo['pdf_file'] = "/tmp/" . $r['pdf_file'];
			}
			if(isset($r['signature_img']) && !empty($r['signature_img'])){
				//$_SESSION['signature_html'] =  $data['signature_html'];
				$docInfo['signature_img'] = $r['signature_img'];
			}
			if(!empty($r['comments'])){
				$docInfo['comments'] = $r['comments'];
			}
			if(!empty($r['user_comments'])){
				$docInfo['user_comments'] = $r['user_comments'];
			}
			if(!empty($r['queue'])){
				$docInfo['queue'] = $r['queue'];
			}
			if(!empty($r['portal_filing_id'])){
				$docInfo['portal_filing_id'] = $r['portal_filing_id'];
			}
			if(!empty($r['creator'])){
				$docInfo['creator'] = $r['creator'];
			}
			if(!empty($r['doc_lock_date'])){
				$docInfo['doc_lock_date'] = $r['doc_lock_date'];
			}
			if(!empty($r['doc_lock_user'])){
				$docInfo['doc_lock_user'] = $r['doc_lock_user'];
			}
			if(!empty($r['doc_lock_sessid'])){
				$docInfo['doc_lock_sessid'] = $r['doc_lock_sessid'];
			}
		}
	}
	
	return $docInfo;
}

function isSigned($doc_id){
	$dbh = dbConnect("icms");
	$query = "	SELECT 
					signature_img
				FROM 
					workflow
				WHERE
					doc_id = :doc_id";
					
	$row = getDataOne($query, $dbh, array("doc_id" => $doc_id));	

	if(empty($row)){
		$isSigned = false;
	}
	else{
		if(!isset($row['signature_img']) || (empty($row['signature_img'])) || ($row['signature_img'] == "")){
			$isSigned = false;
		}
		else{
			$isSigned = true;
		}
	}
	
	return $isSigned;
}

function getMagistrateNames(){
	$dbh = dbConnect("judge-divs");
	
	$query = "SELECT 
				first_name,
				middle_name,
				last_name
			FROM 
				magistrates
			ORDER BY 
				last_name, first_name";
	
	$results = array();
	getData($results, $query, $dbh);
	
	$magNames = array();
	foreach($results as $r){
		$name = $r['first_name'];
		
		if(!empty($r['middle_name'])){
			$name .= " " . $r['middle_name'];
		}
		
		$name .= " " . $r['last_name'];
		$magNames[] = $name;
	}
	
	return $magNames;
}

function getMediatorRoom($location){
	switch($location){
		case "Main":
			$room = "6.2100";
			break;
		case "North":
			$room = "2717";
			break;
		case "South":
			$room = "2E-202";
			break;
		case "West":
			$room = "N-109";
			break;
		default:
			$room = "6.21";
			break;
	}
	
	return $room;
}

function getCurrentUserName(){

	$user = $_SESSION['user'];
	$config = simplexml_load_file($_SERVER['APP_ROOT'] . "/conf/ICMS.xml");
	$ldapConf = $config->{'ldapConfig'};
	$filter = "(sAMAccountName=$user)";
	$userdata = array();

	ldapLookup($userdata, $filter, $ldapConf, null, array('displayName'), (string) $ldapConf->{'userBase'});
	$name = $userdata[0]['displayname'][0];
	return $name;
}

function getUFCCMNames(){
	$dbh = dbConnect("judge-divs");

	$query = "SELECT
				first_name,
				middle_name,
				last_name
			FROM
				case_managers
			WHERE
				court_type = 'Family'
			AND
				active = 1
			ORDER BY
				last_name, first_name";

	$results = array();
	getData($results, $query, $dbh);

	$cmNames = array();
	foreach($results as $r){
		$name = $r['first_name'];

		if(!empty($r['middle_name'])){
			$name .= " " . $r['middle_name'];
		}

		$name .= " " . $r['last_name'];
		$cmNames[] = $name;
	}

	return $cmNames;
}

function getJuvMagInfo($div){
	$jdbh = dbConnect("judge-divs");

	$query = "SELECT first_name,
				  middle_name,
				  last_name,
				  suffix,
				  hearing_room,
				  address
			  FROM magistrates
			  WHERE juv_divisions LIKE ('%". $div . "%')";

	$row = getDataOne($query, $jdbh);

	$juvMag = array();
	if(empty($row)){
		$juvMag['name'] = "N/A";
		$juvMag['room'] = "N/A";
		$juvMag['address'] = "N/A";
	}
	else{
		$fName = $row['first_name'];
		$mName = $row['middle_name'];
		$lName = $row['last_name'];
		$suffix = $row['suffix'];

		$name = $fName;

		if(empty($mName)){
			$name .= " " . $lName;
		}
		else{
			$name .= " " . $mName . " " . $lName;
		}

		if(!empty($suffix)){
			$name .= " " . $suffix;
		}
		
		$juvMag['name'] = $name;
		
		$room = $row['hearing_room'];
		if(strpos($room, "/") !== false){
			$roomArr = explode("/", $room);
			$room = $roomArr[0];
		}
		
		$juvMag['room'] = $room;
		$juvMag['address'] = $row['address'];
	}

	return $juvMag;
}

function getChildDob($caseid){
	$dbh = dbConnect("showcase-prod");

	$results = array();
	$query = "
				SELECT
					DOB
				FROM
					vAllParties
				WHERE CaseID = :caseid
				AND PartyTypeDescription = 'CHILD'
				AND Active = 'Yes'
				AND (Discharged = 0 OR Discharged IS NULL)
				ORDER BY DOB DESC";

	getData($results, $query, $dbh, array("caseid" => $caseid));

	$child_count = 0;
	$dob = "";
	if(!empty($results)){
		foreach($results as $r){
			
			if(!empty($r['DOB'])){
				if($child_count > 0){
					$dob .= ", "; 
				}
					
				$dob .= date("m/d/Y", strtotime($r['DOB']));					
				$child_count++;
			}
		}
	}
	
	if(empty($dob)){
		$dob = "N/A";
	}
	
	return $dob;

}

function getPetDOB($caseid){
	$dbh = dbConnect("showcase-prod");

	$results = array();
	$query = "
				SELECT
					DOB
				FROM
					vAllParties
				WHERE CaseID = :caseid
				AND PartyTypeDescription IN ( 'PETITIONER', 'PLAINTIFF/PETITIONER' )
				AND Active = 'Yes'
				AND (Discharged = 0 OR Discharged IS NULL)
				ORDER BY DOB DESC";

	getData($results, $query, $dbh, array("caseid" => $caseid));

	$petCount = 0;
	$dob = "";
	if(!empty($results)){
		foreach($results as $r){
			
			if(!empty($r['DOB'])){
				if($petCount > 0){
					$dob .= ", ";
				}
					
				$dob .= date("m/d/Y", strtotime($r['DOB']));
				$petCount++;
			}
		}
	}

	if(empty($dob)){
		$dob = "N/A";
	}

	return $dob;

}

function getRespDOB($caseid){
	$dbh = dbConnect("showcase-prod");

	$results = array();
	$query = "
				SELECT
					DOB
				FROM
					vAllParties
				WHERE CaseID = :caseid
				AND PartyTypeDescription IN ( 'RESPONDENT', 'DEFENDANT/RESPONDENT' )
				AND Active = 'Yes'
				AND (Discharged = 0 OR Discharged IS NULL)
				ORDER BY DOB DESC";

	getData($results, $query, $dbh, array("caseid" => $caseid));

	$respCount = 0;
	$dob = "";
	if(!empty($results)){
		foreach($results as $r){

			if(!empty($r['DOB'])){
				if($respCount > 0){
					$dob .= ", ";
				}
					
				$dob .= date("m/d/Y", strtotime($r['DOB']));
				$respCount++;
			}
		}
	}

	if(empty($dob)){
		$dob = "N/A";
	}

	return $dob;

}
