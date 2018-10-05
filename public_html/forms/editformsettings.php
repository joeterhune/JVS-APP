<?php
require_once ('../php-lib/common.php');
require_once ('../php-lib/db_functions.php');
include "../icmslib.php";
require_once('Smarty/Smarty.class.php');

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);

$dbh = dbConnect("icms");

$arr = array();
$query = "
    select
        form_id,
        form_name
    from
        forms
    order by
        form_name
";

getData($arr, $query, $dbh);
#
# get all the workflow users so they can be granted sharing rights
#
$userarr = array();
getUserList($userarr, $dbh);

//sqlarrayp($dbh,"select userid,name from users order by userid",array());
for ($i=0;$i<count($userarr);$i++) {
    $users[$userarr[$i]['userid']]=$userarr[$i]['fullname'];
}

#
# collect county/division info
#
//$allcounties=load_conf_file("county_db_info.json");
//$countyarr = array('50' => array('name' => 'Palm Beach'));
//$countyjson = json_encode($countyarr);
$allcounties = array('50' => array('name' => 'Palm Beach'));
# sub-optimal buildinf of countylist array...
$custdivarr=array();
$countylist=array_keys((array)$allcounties);

//$defaultdivs=load_conf_file("Divisions.Default.json");
$defaultdivs = array(
    array('divisions' => 'AP', 'name' => 'AP'),
    array('divisions' => 'CA', 'name' => 'CA'),
    array('divisions' => 'CC', 'name' => 'CC'),
    array('divisions' => 'CF', 'name' => 'CF'),
    array('divisions' => 'CJ', 'name' => 'CJ'),
    array('divisions' => 'CP', 'name' => 'CP'),
    array('divisions' => 'DP', 'name' => 'DP'),
    array('divisions' => 'DR', 'name' => 'DR'),
    array('divisions' => 'GA', 'name' => 'GA'),
    array('divisions' => 'MH', 'name' => 'MH'),
    array('divisions' => 'MM', 'name' => 'MM'),
    array('divisions' => 'SC', 'name' => 'SC'),
    array('divisions' => 'TR', 'name' => 'TR'),
);

$caseTypes = array('AP','CA','CC','CF','CJ','CP','CT','DP','DR','GA','MH','MM','SC','TR');

#
# get the efiling_document_descriptions & divisions
#
$query = "
    select
        title,
        divisions
    from
        efiling_document_descriptions
    order by
        title
";

$docdescs = array();
getData($docdescs, $query, $dbh);

$formid = getReqVal('formid');

$formname = "";
$counties = "50";
$casetypes = "";
$docdesc = "";
$isprivate = "";
$sharedwith = "";
$formfieldsjson = "";
$sharedlist = "";

if ($formid != null) {
    $query = "
        select
            form_name,
            counties,
            case_types,
            efiling_document_description,
            is_private,
            shared_with,
            form_fields
        from
            forms
        where
            form_id = :formid
    ";
    $forminfo = getDataOne($query, $dbh, array('formid' => $formid));
    $formname = $forminfo['form_name'];
    $counties = $forminfo['counties'];
    $casetypes = $forminfo['case_types'];
    $docdesc = $forminfo['efiling_document_description'];
    $isprivate = $forminfo['is_private'];
    $sharedwith = $forminfo['shared_with'];
    $formfieldsjson = $forminfo['form_fields'];
} else {
    $formid = "";
}

$smarty->assign('formid', $formid);
$smarty->assign('user', $_SERVER['PHP_AUTH_USER']);
$smarty->assign('docdesc', $docdesc);
$smarty->assign('users',$users);
$smarty->assign('custdivarr', $custdivarr);
$smarty->assign('forms', $arr);
$smarty->assign('casetypes', $caseTypes);

if ($formfieldsjson = "") {
    $smarty->assign('formfields', "[]");
} else {
    $smarty->assign('formfields', $formfieldsjson);
}

$smarty->display('forms/editformsettings.tpl');


exit;
?>


// divmaps unused at the moment

var divmaps={
<?php 
# build the divmaps array for those counties with custom divisions
$flag=0;
foreach ($custdivarr as $countynum=>$x) {
   foreach ($x as $y) {
      if ($flag) { echo ",\n"; } 
      echo "\"$countynum-".$y->{divisions}."\": \"".$y->{casetypes}."\"";
      $flag++;
   }
}
?>
};

var docdescs={
<?php
# build the docdescs array so we can re-populate the dropdown based
# on the fields selected
$flag=0;
for ($i=0;$i<count($docdescs);$i++) {
   list($title,$divs)=$docdescs[$i];
   if ($flag) { echo ",\n"; } 
   echo "\"$title\": \"$divs\"";
   $flag++;
}
?>

};



function HandlePrivate() {
    if ($("#is_private").prop('checked')) {
        $("#sharespan").show();
        if ($("#shared_with").val()=="") {
        $("#shared_with").val(USER);
    }
    FixSharedList();
    } else {
     $("#sharespan").hide();
  }
}




// HandleFormDivChange modifies the document description dropdown based
// on the boxes checked...

function HandleFormDivChange() {
   // recalculate the dropdown based on checks provided.
   // first, let's get a list of all divisions checked.
   var chked=$('.formdivs:checkbox:checked').map(function() {
      return this.value;
   }).get();
   var $el=$("#doc_description");
   var selval;
   if (olddocdesc!="") {  // first time
      selval=olddocdesc;
      olddocdesc=''; 
   } else {
     selval=$("#doc_description").val();
   }
   $el.empty();
   $el.append("<option></option>"); // initial blank option
   $.each(docdescs,function (title,divlist) {
       var isOK=1;
       for (j=0;j<chked.length;j++) {
          if (divlist.search(chked[j])==-1) { // not found
             isOK=0; 
             break;
          }
       }
       if (isOK) {
          $el.append($("<option></option>").attr("value",title).text(title+' ('+divlist+')'));
       }
   });
   $el.val(selval); // select the previous value
   // TEST  alert(chked.join(','));
   // for now, just build the list from the array...
}



function HandleAllCounties() {
  if ($("#allcounties").prop('checked')) {
     $(".counties").attr('checked','checked');
  } else {
     $(".counties").removeAttr('checked');
  }
}


// UpdateFormFields copies updates the fforder,ffname, and ffdesc
// fields in the Form Fields display table; also updates formfieldsjson
// to match the contents of the formfields object

function UpdateFormFieldsCopies() {
   for (i=0;i<formfields.length;i++) {
      j=i+1;
      $("#fforder"+j).val(j);    
      $("#ffname"+j).val(formfields[i].field_name);    
      $("#ffdesc"+j).val(formfields[i].field_description);    
   }
   $("#formfieldsjson").val(JSON.stringify(formfields));
}


// a now unused function that displays the names of the fields in order 
// in an alert box; handy for debugging.

function showfields(newfields) {
   var str='';
   for (i=0;i<newfields.length;i++) {
      str+=newfields[i].field_name+'\n';
   }
   alert(str);
}

// This function handles re-ordering a field by changing the order # for it.

function HandleFieldReorder() {
   var oldpos=this.id;
   oldpos=oldpos.replace('fforder',''); // leaves the #
   newpos=$(this).val();
   var newfields=JSON.parse(JSON.stringify(formfields)); // cheap clone...
   newpos--; oldpos--; // 0-basis...
   if (newpos>=newfields.length) { newpos=newfields.length-1; }
   if (newpos<0) { newpos=0; }
   var x=formfields[oldpos];
   newfields.splice(oldpos,1);
   newfields.splice(newpos,0,x);
   formfields=newfields;
   UpdateFormFieldsCopies();
}


function HandleTopIcon() {
   var n=this.id;
   n=n.replace('topicon',''); // leaves the #
   var newfields=[];
   n--;
   newfields[0]=formfields[n];
   j=1;
   for (i=0;i<formfields.length;i++) {
      if (i!=n) { 
         newfields[j]=formfields[i];
         j++;
      }
   }
   formfields=newfields;
   UpdateFormFieldsCopies();
}


function HandleFieldModification() {
  var fldname=this.id;
  var n=fldname.replace('ffname','');
  var n=n.replace('ffdesc','');
  var fldtype=fldname.replace(n,'');
  n--; // 0 basis
  if (fldtype=="ffname") { // field label change
     formfields[n].field_name=$("#"+fldname).val();
  } else { // ffdesc
     formfields[n].field_description=$("#"+fldname).val();
  }
  // since we just fixed formfields, and the ff table is correct,
  // just fix the json version
   $("#formfieldsjson").val(JSON.stringify(formfields));
}



//
// JQUERY INIT FOR THIS PAGE
//

$(document).ready(function () {
    $("#formselect").change(LoadNewForm);
    $("#is_private").change(HandlePrivate);
    $("#sharedadd").click(AddUserToShared);
    $("#shareddel").click(DelUserFromShared);
    $(".formdivs").change(HandleFormDivChange);
    $("#allcounties").click(HandleAllCounties);
    $(".topicon").click(HandleTopIcon);
    $(".ffreorder").change(HandleFieldReorder);
    $(".ff").change(HandleFieldModification);
    
    HandlePrivate(); // set the initial value properly
    HandleFormDivChange(); // set the initial document description properly
});

</script>
</head>
<body>
<font face=calibri,arial,helvetica>
<form method=post action="editformsettings-post.php">
<?php
if ($formid == "") {
    echo "Form Settings to Edit: <select id=formselect><option>";
    
    foreach ($arr as $x) {
        $aformid = $x['form_id'];
        $aformname = $x['form_name'];
        if ($aformid==$formid) {
            $sel="selected"; $formname=$aformname;
        } else {
            $sel="";
        }
        echo "<option value=$aformid $sel>$aformname";
   }
   echo <<<EOS
</select> <input type=submit value=Save> <input type=button value=Cancel onclick="window.location='index.php';">
<p>
EOS;
}
#
# get all the field definitions on this server
#
$query = "
    select
        *
    from
        form_fields
    where
        field_type not in ('BUILTIN','ESIG')
    order
        by field_name
";

$allfields = array();
getData($allfields, $query, $dbh);

//$allfields=sqlarrayp($dbh,"select * from form_fields where field_type not in ('BUILTIN','ESIG') order by field_name",array());
#
# make selecteddivs hash to check appropriate divs below
#
$divarr=explode(',',$casetypes);
foreach ($divarr as $adiv) { $selecteddivs[$adiv]=1; }
#
# Display the form...
#
echo <<<EOS
<input type=hidden name=form_id id=form_id value='$formid'>
<table>
<tr><td>Form Name:<td colspan=2><input type=text name=formname id=formname value="$formname" size=120 > <input type=submit value=Save> <input type=button value=Cancel onclick="window.location='index.php';">
EOS;
#
# create checkboxes for ALL county and case types..
#
foreach (explode(",",$counties) as $acounty) {
   $countiesarr[$acounty]=1;
}

$count=0;
#$divtext="Case Types:";
echo "<tr><td>Case Types:<td colspan=2>";
foreach ($countylist as $acounty) {
    if ($countiesarr[$acounty] || count($countylist)==1) {
        $chk="checked";
    } else {
        $chk="";
    }
   echo "<input type=checkbox class=counties name=\"counties[]\" value=\"$acounty\" $chk>",$allcounties[$acounty]['name'];
}
echo "&nbsp;&nbsp;<input type=checkbox id=allcounties> All";
echo "<tr><td><td colspan=2>";


foreach ($defaultdivs as $adiv) {
    $divcodes=$adiv['divisions'];
    $divname=$adiv['name'];
    $x=strpos($divcodes,",");
    if ($x!==false) {
        $divcodes=substr($divcodes,0,$x);
    }
    if (array_key_exists($divcodes, $selecteddivs)) {
        $chk=" checked";
    } else {
        $chk="";
    }
    
    echo "<input class=formdivs name=\"formdivs[]\" value=\"$divcodes\" type=checkbox $chk>$divcodes&nbsp;&nbsp;";
#         $count++;
#         if ($count>6) { echo "<br>"; $count=0; }
      }
#   }
#}
#
# the document description drop-down..
#
echo "<tr><td>E-Filing Description: <td colspan=2><select id=doc_description name=doc_description style=\"font-size:9pt\"><option></select>";
#
# the is_private option and the shared-with values & controls...
#
if ($isprivate==1) {
    $chk="checked";
} else {
    $chk="";
}

echo "<tr valign=top><td>Private:<td><input id=is_private name=is_private value=1 type=checkbox $chk><td><span id=sharespan style='display:none'>Shared with: <span id=sharedlist>$sharedlist</span><br><select id=sharedselect><option>";

foreach ($users as $userid=>$fullname) {
    echo "<option value=$userid>$fullname";
}

echo "</select> <input type=button id=sharedadd value='Add'> <input type=button id=shareddel value='Delete'></span>";
echo <<<EOS
</table>
<input type=hidden id="shared_with" name="shared_with" value="$sharedwith">
<hr>
Form Fields<p>
<table>
<thead style='font-size:9pt'><tr><th>List Order<th><th>Label<th>Field Code<th>Description</thead>
<tbody>
EOS;
#  $formfieldsjson<p>
#
# Preview Form fields...
#
$formfields=json_decode($formfieldsjson);
$i=1;
foreach ($formfields as $afield) {
    echo "<tr><td style='width:35px;padding-left:15px'><input type=text class=ffreorder id=fforder$i name=fforder$i value=$i style='width:20px;'><td>";
    if ($i!=1) {
        echo "<img id=topicon$i class=topicon src=topicon.png>";
    }
    echo "<td><input type=text class=ff id=ffname$i name=ffname$i value=\"",$afield->{'field_name'},"\"><td>",$afield->{'field_code'},"<td><input type=text class=ff size=80 id=ffdesc$i name=ffdesc$i value=\"",$afield->{'field_description'},"\">";
    $i++;
}
echo <<<EOS
</tbody>
</table>
<input type=hidden id=formfieldsjson name=formfieldsjson value='$formfieldsjson'>
EOS;
#<select name=fieldtoadd id=fieldtoadd>
#<option>
#EOS;
#foreach ($allfields as $x) {
#   list($id,$code,$name,$desc,$type,$values,$default)=$x;
#   echo "<option value=$id>$name";
#}
#echo <<<EOS
#</select>
#<input type=button value='Add' onClick=AddNewField();>
#EOS;
?>
</form>
</font>
</body>
