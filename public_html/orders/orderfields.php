<?php
require_once("../php-lib/common.php");
require_once("../php-lib/db_functions.php");
require_once('Smarty/Smarty.class.php');

include "../icmslib.php";
include "../caseinfo.php";

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);

#
# generate_form_fields creates the HTML form elements for filling in 
#    form information
#

function generate_form_fields($dbh,$formid,$FORMDATA,$chaddress,$countynum,$division,$ucn,$casetype) {
    $gff = new Smarty;
    $gff->setTemplateDir($templateDir);
    $gff->setCompileDir($compileDir);
    $gff->setCacheDir($cacheDir);
    
    $gff->assign('chaddress',$chaddress);
    $gff->assign('formid', $formid);
    
    # first, get the JSON that defines the field list...
    $query = "
        select
            form_fields,
            form_name
        from
            forms
        where
            form_id = :formid
    ";
    $rec = getDataOne($query, $dbh, array('formid' => $formid));
    $orderfieldsjson = $rec['form_fields'];
    $formname = $rec['form_name'];
    $gff->assign('formname',$formname);
    
    $orderfields=json_decode($orderfieldsjson,true);
    
    # get event types for dropdown below
    $query = "
        select
            dscr
        from
            hearingtypes
        where
            countynum = :countynum
            and division = :division
        order by
            dscr
    ";
    $evtypes = array();
    getData($evtypes, $query, $dbh, array('countynum' => $countynum, 'division' => $division));
    
    if (isset($FORMDATA->{'docket_line_text'})) {
        $dockline = $FORMDATA->{'docket_line_text'};
    } else {
        $dockline = "";
    }
    if ($dockline=="") {
        $dockline=$formname;
    }
    
    $magistrates = getMagistrateNames();
    $ufc_cm_names = getUFCCMNames();
    
    if($casetype == 'Family' || ($casetype == 'Probate') || ($casetype == 'Juvenile')){
	    $caseid = getCaseID($ucn);
	    $petRespAddresses = getAllPetRespAddresses($caseid);
	    $petRespNames = getAllPetRespNames($caseid);
	    $gff->assign('names', $petRespNames);
	    $gff->assign('addresses', $petRespAddresses);
    }
    else{
    	$gff->assign('addresses', "");
    }

    $gff->assign('ufc_cm_names', $ufc_cm_names);
    $gff->assign('magistrates', $magistrates);
    $gff->assign('formdata', $FORMDATA);   
    $gff->assign('dockline', $dockline);
    $gff->assign('orderfields', $orderfields);
    
    return $gff->fetch('orders/generate_form_fields.tpl');
}


# generate_builtin_fields creates the hidden values for the built-in variables

function generate_builtin_fields($dbh,$countynum,$ucn,$counties,$SETTINGS,$FORMDATA,$divisioncode,$docid, $signName) {
    
    $config = simplexml_load_file($_SERVER['APP_ROOT'] . "/conf/ICMS.xml");
    
    $url = sprintf("%s/divInfo", (string) $config->{'icmsWebService'});
    
    $fields = array(
        'division' => $divisioncode
    );
    
    $return = curlJson($url, $fields);
    $json = json_decode($return,true);
    $divInfo = $json['DivInfo'];
    
    $query = "
    		SELECT form_name
    		FROM forms
    		WHERE form_id = :form_id";
    
    $row = getDataOne($query, $dbh, array("form_id" => $docid));
    $form_name = $row['form_name'];

    //fb($fields,"FIELDS");
    //fb($url,"URL");
    //fb($json,"JSON");
    
    if (is_conf_file("Divisions.$countynum.json")) {
        $divconf = load_conf_file("Divisions.$countynum.json");
    } else {
        $divconf = load_conf_file("Divisions.Default.json");
    }
    
    $casetype = getDivType($divisioncode);
    
    if(empty($casetype) && ((strpos($ucn, 'MO') !== false) || (strpos($ucn, 'CO') !== false) || (strpos($ucn, 'TR') !== false))){
    	$casetype = "TRAFFIC";
    }
    
    $gbi = new Smarty;
    $gbi->setTemplateDir($templateDir);
    $gbi->setCompileDir($compileDir);
    $gbi->setCacheDir($cacheDir);
    
    //$divname = getCaseDiv($ucn);
    $divname = $divisioncode;
    $caseid = getCaseID($ucn);
    
    # build a hash for all the builtin fields in this form
    $query = "
        select
            field_code
        from
            form_fields
        where
            field_type='BUILTIN'
    ";
    $builtintypesraw = array();
    getdata($builtintypesraw, $query, $dbh);
    foreach ($builtintypesraw as $x) {
        $builtintypes[$x['field_code']]=1;
    }
    
    $arr = $builtintypesraw;
    $data = array();
    foreach ($arr as $x) {
        $code=$x['field_code'];
        if (!$builtintypes[$code]) {
            continue;
        } # skip unused built-ins...
        
        switch($code) {
			
			/*case "ListVars":
				$val = "<p><strong>Courtroom:</strong> ".$divInfo['Courtroom']."</p>";
				$val.= "<p><strong>City: </strong>".$divInfo['City']."</p>";
				$val.= "<p><strong>JudgeTitle: </strong>".$divInfo['JudgeTitle']."</p>";
				$val .=  implode(",",array_keys($divInfo));
				$val .= "<ul>";
				
			foreach($divInfo as $x)
				{
						$val .= "<li>".$x."</li>";
				}
			$val .= "</ul>";
				break;*/
            case "ADACoordinator":
                $val = (string) $config->{'ADACoordinator'};
                break;
            case "ADAText":
            	$val = getADAText();
            	break;    
            case "InterpreterText":
            	$val = getInterpreterText();
            	break;
           	case "TranslatorText":
            	$val = getTranslatorText();
            	break;
            case "GMvacate_text":
            	$val = getGMVacateText();
            	break;
            case "FileExp_text":
            	$val = getFileExpText();
            	break;
            case "casetype":
                $val = strtoupper($casetype);
                break;
            case "ADAPhone":
                $val = (string) $config->{'ADAPhone'};
                break;
            case "case_number":
            	list($ucn, $db_type) = sanitizeCaseNumber($ucn);
            	if ($db_type == 'banner') {
            		$ucn = getBannerExtendedCaseId($ucn);
            	}
                $val = $ucn;
                break;
            case "isCircuit":
                $val = isCircuit($ucn);
                break;
            case "cc_list":
					break;
            case "case_caption":
                // continue; # set by Parties tab
                break;
            case "CIRCUIT":
                $val = strtoupper($counties->{$countynum}->{'circuit'});
                break;
            case "circuit":
				  $val = $counties->{$countynum}->{'circuit'};
                break;
            case "Circuit":
                $val = $counties->{$countynum}->{'circuit'};
                break;
            case "clerk_phone":
                $val=$counties->{$countynum}->{'clerk_phone'};
                break;
            case "commserv_agency":
                $val=$counties->{$countynum}->{'commserv_agency'};
                break;
            case "COUNTY":
                $val=strtoupper($counties->{$countynum}->{'name'});
                break;
            case "county":
			 $val = $counties->{$countynum}->{'name'};
                break;
            case "County":
                $val = $counties->{$countynum}->{'name'};
                break;
            case "courthouse_address":
			case "courthouseaddress":
			case "ch_adress":
                $val = $divInfo['Address'];
                break;
            case "courthouse_name":
                $val = $divInfo['CourthouseName'];
                break;
           case "courthouse_location":
           		$c_arr = explode(" ", $divInfo['CourthouseName']);
                $val = $c_arr[0];
                break;
			case "ddallcities":
            case "courthouse_city":
                $val = $divInfo['City'];
				if($val=="") $val = "West Palm Beach"; // default to west palm if not found
                break;
            case "courthouse_state":
                $val = $divInfo['State'];
                break;
            case "courthouse_zip":
                $val = $divInfo['ZIP'];
                break;
            case "courthouse_full_address":
                $val = $divInfo['CourthouseAddress'];
                break;
            case "judge_name":
				//$sigVars = getTitle($signName,$docid);
				//$val = "<span class='sig-name'>".$sigVars['FullName']."</span>";
				$val = $divInfo['FullName'];
                break;
            case "courtroom":
                $val = $divInfo['Courtroom'];
                break;
            case "judge_first_name":
                $val = $divInfo['FirstName'];
                break;
            case "judge_middle_name":
                $val = $divInfo['MiddleName'];
                break;
            case "judge_last_name":
                $val = $divInfo['LastName'];
                break;
            case "judge_suffix":
                $val = $divInfo['Suffix'];
                break;
			case "judge_title":
				 $sigVars = getTitle($signName,$docid);
				//get the signature user title from AD lookup
				$val = "<span class='sig-title'>".$sigVars['Title']."</span>";
				break;
			
            //    break;
            # if array, we handled in generate_form_fields above
            //case "courthouse_address_only":
            //case "courthouse_mail_address":
            //case "courthouse_name":
            //    $val=""; # set by JavaScript
            //    break;
            case "DivisionID":
                $val=$divname;
                break;
            case "order_location":
                $val=$counties->{$countynum}->{'order_location'};
            case "style":
                continue; # set by Parties tab
            case "today":
                $val = date('jS \d\a\y \o\f F, Y');
                break;
            case "Month":
                $val = date('F');
                break;
            case "Day":
            	$val = date('d');
                break;
            case "Year":
                $val = date('Y');
                break;
			case "LinkedCases":
				//This takes a while so I'm not calling it if it's not required
				if($divname == 'AY' || ($divname == 'AC')){
					$val = getLinkedCases($caseid, true);
				}
				break;
			case "LinkedCaseList":
				//This takes a while so I'm not calling it if it's not required
				if($form_name == "DCM Case Management Order"){
					$val = getLinkedCases($caseid, false, true);
				}
				break;
			case "LinkedCaseAndStatusList":
				//This takes a while so I'm not calling it if it's not required
				if($form_name == "DCM Case Management Order"){
					$val = getLinkedCases($caseid, false, false, true);
				}
				break;
            case "ucn":
            	list($ucn, $db_type) = sanitizeCaseNumber($ucn);
            	if ($db_type == 'banner') {
            		$ucn = getBannerExtendedCaseId($ucn);
            	}
            	$val = $ucn;
                break;
            case "PRAttorneyAddress":
            	//This takes a while so I'm not calling it if it's not required
            	if($casetype == "Probate"){
            		$val = getPersonalRepresentativeAttorneyAddress($caseid);
            	}
            	break;   
            case "RespAttorneyAddress":
            	//This takes a while so I'm not calling it if it's not required
            	if($casetype == "Probate"){
            		$val = getRespondentAttorneyAddress($caseid);
            	}
            	break;
            case "caseTypeDesc":
            	$val = getCaseTypeDescription($caseid);
            	break;
            case "CourtTypeDesc":
            	$val = getCourtTypeDescription($caseid);
            	break;
            case "FileDate":
            	$val = getCaseFileDate($caseid);
            	break;	
            case "petAttorney":
            	if($casetype == "Family" || ($casetype == "Probate")){
            		$val = getPetitionerAttorney($caseid);
            	}
            	break;
            case "respAttorney":
            	if($casetype == "Family" || ($casetype == "Probate")){
            		$val = getRespondentAttorney($caseid);
            	}
            	break;
            case "RespAttorneyBarNo":
            	if($casetype == "Family" || ($casetype == "Probate")){
            		$val = getRespondentAttorneyBarNumber($caseid);
            	}
            	break;
            case "petName":
            	if($casetype == "Family" || ($casetype == "Probate")){
	            	$val = getPetitionerName($caseid);
            	}
            	break;
            case "respName":
            	if($casetype == "Family" || ($casetype == "Probate")){
	            	$val = getRespondentName($caseid);
            	}
            	break;
            case "pltName":
            	if($casetype == "Circuit Civil" || ($casetype == "County Civil")){
            		$val = getPlaintiffName($caseid);
            	}	
            	break;
            case "dftName":
            	if($casetype == "Circuit Civil" || ($casetype == "County Civil")){
            		$val = getDefendantName($caseid);
            	}
            	break;
            case "pltNameAndAddress":
            	if($casetype == "Circuit Civil" || ($casetype == "County Civil")){
            		$val = getPlaintiffNameAndAddress($caseid);
            	}
            	break;
            case "propertyAddress":
            	if($casetype == "County Civil"){
            		$val = getPropertyAddress($caseid);
            	}
            	break;
            case "MostRecentDocketDate":
            	if($casetype == "Family" || ($casetype == "Probate")){
            		$val = getMostRecentDocketDate($caseid);
            	}	
            	break;
            case "childrenAndDOBs":
            	if($casetype == "Family" || ($casetype == "Juvenile")){
            		$val = getChildrenAndDOBs($caseid);
            	}	
            	break;
            case "PDNames":
            	if($casetype == "Felony" || ($casetype == "Misdemeanor")){
	            	$val = getPDNames($caseid);
            	}
            	break;
            case "childCount":
            	if($casetype == "Family" || ($casetype == "Juvenile") || ($casetype == "Probate")){
            		$val = getChildCount($caseid);
            	}	
            	break;
            case "mediatorRoom":
            	$c_arr = explode(" ", $divInfo['CourthouseName']);
            	$val = getMediatorRoom($c_arr[0]);
            	break;
            case "current_user_name":
            	$val = getCurrentUserName();
            	break; 
            case "child_dob":
            	if($casetype == "Juvenile"){
            		$val = getChildDob($caseid);
            	}
            	break;
            case "respDOB":
            	if($casetype == "Family"){
            		$val = getRespDOB($caseid);
            	}
            	break;
            case "petDOB":
            	if($casetype == "Family"){
            		$val = getPetDOB($caseid);
            	}
            	break;
            case "respAddress":
            	if($casetype == "Family"){
            		$val = getAllPetRespAddresses($caseid, "'RESPONDENT', 'DEFENDANT/RESPONDENT'");
            	}
            	break;
            case "petAddress":
            	if($casetype == "Family"){
            		$val = getAllPetRespAddresses($caseid, "'PETITIONER', 'PLAINTIFF/PETITIONER'");
            	}
            	break;
            case "juv_mag":
            	if($casetype == "Juvenile"){
            		$juvMag = getJuvMagInfo($divname);
            		$val = $juvMag['name'];
            	}	
            	break;
            case "juv_mag_room":
            	if($casetype == "Juvenile"){
            		$juvMag = getJuvMagInfo($divname);
            		$val = $juvMag['room'];
            	}
            	break;
            case "juv_mag_address":
            	if($casetype == "Juvenile"){
            		$juvMag = getJuvMagInfo($divname);
            		$val = $juvMag['address'];
            	}
            	break;
            case "petitioner":
            case "respondent":
            case "plaintiff":
            case "defendant":
			case "appellant":
			case "appellee":
                // These are added at merge time.
                break;
            default:
                $val = "<span style='color:red'>MISSING(X)</span>";
                break;
        }
        
        if ($val==="") {
            $val="<span style='color:red'>MISSING(X)</span>";
        }
        $data[$code] = $val;
        //echo "<input type=hidden id=$code name=$code value=\"$val\">\n";
        $val="";
    }
    
    $gbi->assign('data', $data);
    return $gbi->fetch('orders/generate_builtin_fields.tpl');
}


#
# generate_esig_fields generates the appropriate values for the e-sig fields
#    needed by this document
#

function generate_esig_fields($dbh,$formid,$FORMDATA) {
    $esigtpl = new Smarty;
    $esigtpl->setTemplateDir($templateDir);
    $esigtpl->setCompileDir($compileDir);
    $esigtpl->setCacheDir($cacheDir);
    
    # make a hash table of e-sig-related types...
    $query = "
        select
            field_code
        from
            form_fields
        where
            field_type='ESIG'
    ";
    
    $esigtypesraw = array();
    getData($esigtypesraw, $query, $dbh);
    
    $esiglist="";
    foreach ($esigtypesraw as $x) {
        $esigstype[$x['field_code']]=1;
    }
    
    $query = "
        select
            all_fields
        from
            forms
        where
            form_id = :formid
    ";
    $fieldref = getDataOne($query, $dbh, array('formid' => $formid));
    $formfieldarr = explode(",", $fieldref['all_fields']);
    $esignedlist = "";
    
    $esigvals = array();
    
    foreach ($formfieldarr as $x) {
        if (array_key_exists($x,$esigstype)) {
            if (substr($x,-10)=="_signature") {
                # note this as a needed esig
                if ($esiglist != "") {
                    $esiglist.=",";
                }
                $sigtype=substr($x,0,-10);
                $esiglist .= $sigtype;
                if ((isset($FORMDATA->{$x})) && ($FORMDATA->{$x} != "")) {
                    # signed in data
                    if ($esignedlist!="") {
                        $esignedlist.=",";
                    }
                    $esignedlist.=$sigtype;
                }
            }
            if (isset($FORMDATA->$x)) {
                $esigvals[$x] = $FORMDATA->{$x};
            } else {
                $esigvals[$x] = "";
            }
            //array_push($esigvals, $x);
            //echo "<input type=hidden name=$x id=$x value=\"",$FORMDATA->{$x},"\">\n";
        }
    }
    $esigvals['esigs'] = $esiglist;
    $esigvals['esigned'] = $esignedlist;
    
    # generate hidden _signature_by field for each esig type...
    
    foreach (explode(',',$esiglist) as $esig) {
        $fld=$esig."_signature_by";
        if (isset($FORMDATA->$fld)) {
            $esigvals[$fld] = $FORMDATA->$fld;    
        }
        //echo "<input type=hidden name=${esig}_signature_by id=${esig}_signature_by value=\"",$FORMDATA->$fld,"\">";
    }
    
    $esigtpl->assign('vals', $esigvals);
    $output = $esigtpl->fetch('orders/generate_esig_fields.tpl');
    return $output;
}


#
#  MAIN PROGRAM
#
$ucn = getReqVal('ucn');
$formid = getReqVal('formid');
$docid = getReqVal('docid');
$debug = getReqVal('debug');
$signName = getReqVal('signAs');
// if not signing name get signing name. 
$user = $_SESSION['user'];

$FORMDATA=NULL; # global populated from json file...
if ($docid=="" && $ucn=="") {
    echo "Need ucn or docid ($ucn,$docid)\n";
    exit;
}

$smarty->assign('formid', $formid);
$smarty->assign('docid', $docid);
$smarty->assign('debug', $debug);

$dbh = dbConnect("icms");
if ($docid!="" && $ucn=="") {
    $query = "
        select
            ucn
        from
            workflow
        where
            doc_id = :docid
    ";
    $rec = getDataOne($query, $dbh, array('docid' => $docid));
    
    if (array_key_exists('ucn', $rec)) {
        $ucn = $rec['ucn'];
    }
}

$smarty->assign('ucn',$ucn);


$countynum = 50;
$counties=load_conf_file("county_db_info.json");

$chaddress=$counties->{$countynum}->{'courthouse_address'};
$charray = array();
foreach ($chaddress as $addr) {
    array_push($charray, "'$addr'");
}
$chmailaddrs = implode(",", $charray);

load_system_settings();

if ($docid != "") {  # an existing order in workflow, pull form data
    $query = "
        select
            data
        from
            workflow
        where
            doc_id=:docid
    ";
    $rec = getDataOne($query, $dbh, array('docid' => $docid));
    $FORMDATA = json_decode($rec['data'],true);
}

if ($debug) {
  echo " <script src='/javascript/jquery/jquery.min.js'></script>";
  echo "<script src='/javascript/jquery/ui/js/jquery-ui.js'></script>";
}
#
# now generate all the visible and hidden form fields...
#

$divisioncode = getCaseDiv($ucn);
$casetype = getDivType($divisioncode);
$gff = generate_form_fields($dbh,$formid,$FORMDATA,$chaddress,$countynum,$divisioncode,$ucn,$casetype);
$smarty->assign('formfields',$gff);

$gbi = generate_builtin_fields($dbh,$countynum,$ucn,$counties,$SETTINGS,$FORMDATA,$divisioncode,$formid,$signName);
$smarty->assign('builtins',$gbi);

$estpl = generate_esig_fields($dbh,$formid,$FORMDATA);
$smarty->assign('esigtpl', $estpl);
$smarty->assign('chmailarr',$chmailaddrs);

/*$result = array();
$result['status'] = "Success";
$result['html'] = $smarty->fetch('orders/orderfields.tpl');

header('application/json');
print json_encode($result);*/
echo $smarty->fetch('orders/orderfields.tpl');
exit;

?>
<script language=javascript>

<?php

if (is_array($x)) {
  echo "var chmailarr=[";
  $flag=0;
  foreach ($x as $anaddress) {
     if ($flag) { echo ","; }
     echo "\"",$anaddress,"\"";
     $flag++;
  }
  echo "];\n";
} else {
  echo "var chmailarr=[ \"",$x,"\"];\n";
}
?>


// HandleAddressChange changes the 
// courthouse_name, courthouse_mail_address, and courthouse_address_only
// to match courthouse_address...

function HandleAddressChange() {
   var offset;
   if (chmailarr.length>1) { // multiple addresses
      offset=$("#courthouse_address option:selected").index();
   } else { 
      offset=0; 
   }
   var chval=$("#courthouse_address").val();
   var chname='';
   var chaddonly='';
   if (chval) {
      var x=chval.indexOf(',');
      chname=chval.substring(0,x);
      chaddonly=chval.substring(x+1,1024);
   }
   $("#courthouse_name").val(chname);
   $("#courthouse_address_only").val(chaddonly);
   $("#courthouse_mail_address").val(chmailarr[offset]);
}


// viewdata is a little diagnostic I put up to see how things are populated

function ViewData() {
   var formjson=getformJSON();
   alert(formjson);
}


// VALIDATION STUFF -- currently unused

// FieldFocus causes the cursor to focus on the appropriate field,
// handling multi-checkboxes as well

function FieldFocus(varname) {
   if (varname.indexOf('[]')>0) { // a multi-checkbox
      // we'll do a search based on the name field..focus doesn't seem to work in IE9..
      $("input[name='"+varname+"']:first").focus();
   } else {
      $('#'+varname).focus();
   }
}


// GetFieldValue gets the value of the field name passed it;
// it works for checkboxes, too...

function GetFieldValue(varname) {
   if (varname.indexOf('[]')>0) { // a multi-checkbox
      var chkvals=[];
      // we'll do a search based on the name field..
      $("input[name='"+varname+"']:checked").each(function () {
        chkvals.push($(this).val());
      });
      fldval=chkvals.join(',');
   } else if ($("#"+varname).is(':checkbox')) { // a single checkbox
      if ($("#"+varname).is(':checked')) {
         fldval=$("#"+varname).val();
      } else {
         fldval="";
     }
   } else {
     fldval=$("#"+varname).val();
   }
   return fldval;
}

// END OF VALIDATION STUFF -- currently unused



// INITIALIZATION FUNCTION FOR THIS DOCUMENT...

$().ready(function () {
    $(".datepick").datepicker({
       showOn:"button",
       buttonImage: "/case/style/images/calendar.gif",
       buttonImageOnly: true
    });
    $(".chaddress").change(HandleAddressChange);
    UpdateEsigStatus();
    HandleAddressChange(); // set things up initially
   // populate the combo box...
   $("#event_type").simpleCombo();
});

</script>
<?php
if ($SETTINGS['WORKFLOW']!="LIVE") { # show for TEST and NOFILE only
   echo "<p><font size=-2>($ucn,$formid,$docid,$debug)</font> <input type=button value=Data onclick=ViewData();>";
}
?>
</body>
</html>
