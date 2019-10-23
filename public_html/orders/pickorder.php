<?php
# pickorder.php - pick an order for a case and fill in the values
require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/common.php");
require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/db_functions.php");
require_once($_SERVER['JVS_DOCROOT'] . "/icmslib.php");
require_once($_SERVER['JVS_DOCROOT'] . "/caseinfo.php");
require_once('Smarty/Smarty.class.php');

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);

$debug = getReqVal('debug');

$smarty->assign('debug', $debug);

$ucn = getReqVal('ucn');
$division = getCaseDiv($ucn);
$formid = getReqval('formid');
$docid = getReqVal('docid');

$smarty->assign('DivisionID',$division);
$smarty->assign('DivCheck',"!".$division);
$smarty->assign('ucn', $ucn);


$countynum=substr($ucn,0,2);
$shortcase = preg_replace('/-/','',$ucn);
if (preg_match("/^(\d{1,6})(\D\D)(\d{0,6})(.*)/", $shortcase, $matches)) {
    $casetype = $matches[2];
}
#
# first, make a dropdown with a list of all possible forms
# 
#
$dbh = dbConnect("icms");

$query = "
    select
        form_id,
        form_name,
		case_div
    from
        forms
    where
        case_types like '%$casetype%'
        and (is_private is null OR (is_private=1 and shared_with like '%$USER%'))
        and ols_form = 0
    order
        by form_name
";

$forms = array();

getData($forms, $query, $dbh);

$smarty->assign('forms', $forms);

if ($docid!="") { # get the formid
    $query = "
        select
            data,
            CASE doc_type
                 WHEN 'FORMORDER' then 'IGO'
    			 WHEN 'DVI' then 'DVI'
                 WHEN 'OLSORDER' then 'PropOrd'
        		 WHEN 'WARRANT' then 'Warrant'
        		 WHEN 'EMERGENCYMOTION' then 'EmerMot'
    			 ELSE 'PropOrd'
            END as doc_type
        from
            workflow
        where
            doc_id = :docid
    ";
    
    $doc = getDataOne($query, $dbh, array('docid' => $docid));
    $formdata = json_decode($doc['data'],true);
    $formid=$formdata['form_id'];
    $smarty->assign('formid', $formid);
}

$smarty->assign('docid', $docid);

$result = array();
$result['status'] = "Success";
$result['html'] = $smarty->fetch("orders/pickorder.tpl");
header('application/json');
print json_encode($result);
exit;


#
# If there's only one form, we can show it selected (and load it too)
#
if (count($forms)==1) { $sel="selected";}
else { $sel=""; }
echo "Use Form: <select id=formid><option>";
for ($i=0;$i<count($forms);$i++) {
   if (count($forms)>1) {
     if ($formid!="" && $formid==$forms[$i][0]) { $sel="selected";}
     else { $sel=""; }
   }
   echo "<option value='".$forms[$i]['form_id']."' $sel>".$forms[$i]['form_name'];
}
echo <<<EOS
</select> 
EOS;
?>
<p>
<form id=formdiv></form>

<script language=javascript>

var ucn='<?php echo $ucn;?>';
var docid='<?php echo $docid;?>';

function OrderHandleView() {
    if (!formvalidate()) {
        return;
    }
    var formid=$("select#formid option:selected").val();
    var formdata=$("#formdiv").serialize();
    $.post("/orders/ordersave.php",formdata,function (data) {
        if (data!="OK") {
            alert('xmlsave: '+data);
        }
    });
    
    $("#xmlstatus").html('<i>Re-generating...please wait...</i>');
    window.location.replace("/orders/index.php?ucn="+ucn+"&formid="+formid+"&docid="+docid);
}


function OrderDisplayFields() {
    var formsel=$("select#formid option:selected").val();
    if (formsel!="") {
        var t=new Date().getTime();
        $("#formdiv").load("/orders/orderfields.php?ucn="+ucn+"&formid="+formsel+'&docid='+docid+'&t='+t,OrderHandleFormLoading);
    } else {
        $("#formdiv").html('');
    }
}


function OrderHandleFormLoading() {
   UpdateButtons();
   // set casestyle and cc_list from parties if defined
   if (typeof(UpdateCC_List)=="function") { // we have parties
      UpdateCC_List();
      $("#case_style").val($("#wfcasestyle").val());
   }
}




$().ready(function () {
    OrderDisplayFields(); // display the form fields for this form
    $("#formid").change(OrderDisplayFields); // re-display on form change
});
</script>

