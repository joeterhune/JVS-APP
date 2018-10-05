<?php
/* Smarty version 3.1.31, created on 2018-06-29 12:09:27
  from "/var/jvs/templates/top/search.tpl" */

/* @var Smarty_Internal_Template $_smarty_tpl */
if ($_smarty_tpl->_decodeProperties($_smarty_tpl, array (
  'version' => '3.1.31',
  'unifunc' => 'content_5b3659b7b326c5_49362375',
  'has_nocache_code' => false,
  'file_dependency' => 
  array (
    'a11434b68927b78e7cc2ebfa66ddc7e6eaa6f50a' => 
    array (
      0 => '/var/jvs/templates/top/search.tpl',
      1 => 1530288557,
      2 => 'file',
    ),
  ),
  'includes' => 
  array (
  ),
),false)) {
function content_5b3659b7b326c5_49362375 (Smarty_Internal_Template $_smarty_tpl) {
?>
<style type="text/css">
	.h2{
		font-size:20px;
	}
	button, #buttons input {
		font-size:14px;
	}
</style>

<?php echo '<script'; ?>
 src="/javascript/jquery/jquery.form.js" type="text/javascript"><?php echo '</script'; ?>
>
<?php echo '<script'; ?>
 type="text/javascript">
	OIVTOP = 'https://oiv.15thcircuit.com/solr/';
	$(document).ready(function (){
	
		$("input:text").first().focus();
        	 
    	$(document).on('click','.search',function() {
	    	if(!$.trim($("#searchname").val()).length && !$.trim($("#searchcitation").val()).length){
	    		$('#dialogSpan').html(" Please enter a name, case number, or citation number and try again. ");
				$('#dialogDiv').dialog({
					resizable: false,
					minheight: 150,
					width: 500,
					modal: true,
					title: 'No Search Parameters Entered',
					buttons: {
						"OK": function() {
							$(this).dialog( "close" );
							return false;
						}
					}
				});
				
				return false;
	    	}
	    });
	    
	    $('.dftCheck, .attyCheck').click(function(event) {
        	// Toggle attorney or defendant party types to match the main checkbox
            var target = $(this).data('targetclass');
            $('.' + target).prop('checked',$(this).prop('checked'));
        });
	    
	    $('.allOptsCheck').click(function() {
        	// Find the subsection
            var optsdiv = $(this).closest('.optsTop').find('div.optsDiv').first();
            if ($(this).prop('checked') == true) {
	            // Hide the optsDiv and uncheck all of the checkboxes in it
                $(optsdiv).css('display','none');
                $(optsdiv).find('input[type=checkbox]').prop('checked',false);
            } else {
            	// Show the optsDiv
                $(optsdiv).css('display','table');
            }
        });
        
        $('.docSearchBtn').click(function() {
        	var searchTerm = $.trim($('#dsSearchTerm').val());
            if (searchTerm == "") {
            	showDialog("Search Term Required", "You must enter a search term.");
                return false;
            }
            
                
            	$.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait</h1>', fadeIn: 0});
            
            var url = "/docSearch.php";
            $('#docSearchForm').ajaxSubmit({
            	url: url,
                async: false,
                success: function(data) {
                    $.unblockUI();
                    var json = $.parseJSON(data);
                    $('#docSearchTableBody').html('');
                    var docCount = json.length;
                    $('#searchCount').html(docCount);
                    $(json).each(function(i,e) {
                        var pathPieces = e.path.split("/");
                        var imgLink = $('<a>').attr('href',OIVTOP + e.path).html(pathPieces[1]).attr('target','_blank').attr('title',OIVTOP + e.path);
                        var caseNum = $('<a>').attr('href','#').addClass('caseLink').html(e.case_number).data('casenum',e.case_number).attr('title',e.case_number);
                        var highlights = e.highlights.split("(...)");
                        var hlStr = highlights.join("<br/><br/>");
                        var newRow = $('<tr>').append(
                            $('<td>').css('vertical-align','top').css('padding-right','2em').html(caseNum),
                            $('<td>').css('vertical-align','top').css('padding-right','2em').html(imgLink),
                            $('<td>').css('vertical-align','top').css('padding-right','2em').html(hlStr)
                        );
                          
                        $('#docSearchTableBody').append($(newRow));
                        $('#docSearchResults').show();
                    });
                },
                error: function(data) {
                	    
                    	$.unblockUI();
                    
                    return false;
                }
            });
                
            return true;
        });
        
        $(document).keypress(function(e) {
			if(e.which == 13) {
				e.preventDefault();
				if($("#dsSearchTerm").is(":focus")){
					$('.docSearchBtn').click();
				}
				else if($("#searchname").is(":focus")){
					$('.search').click();
				}
			}
		});
	});
<?php echo '</script'; ?>
>
<div style="padding-left:1%">
	
    <div style="float: right">
        <a class="helpLink" data-context="main">
            <img class="toolbarBtn" style="height: 20px !important; width: 20px;" alt="Help" title="Help" src="/images/help_icon.png">
        </a>
    </div>
    
    <form id="mainSearchForm" method="post" action="/cgi-bin/search.cgi">
    	<input type="hidden" name="div" id="div"/>
		<table style="width:75%;">
			<tr>
				<td><br/></td>
			</tr>
		    <tr>
	            <td colspan="3">
	                <span style="font-size:30px; color:blue; font-weight:bold">
	            		Search
	            	</span>	
	            	<div style="background:blue; width:100%; height:2px;">&nbsp;</div>
	            	<br/>
	            </td>
	        </tr>
		    <tr>
	            <td style="text-align:right; vertical-align:top; width: 130px">
	                <span>
	            		Name or Case #:
	                </span>
	            </td>
	
	            <td class="textinput">
	                <div>
	                    <div style="padding-bottom:1%">
	                        <input placeholder="Enter Name or Case Number to Search" style="line-height: 1.25em" type="text" id="searchname" name="name" size="30" title="Enter Name or Case Number to Search" />
	                        <button style="height: 2em" type="submit" class="search" title="Search Button">Search</button>
	                        <!--<input style="height: 2em" type="submit" name="gosearch" class="search" value="Search"/>-->
	                    </div>
	                    
	                    <div id="soundexSearchOpts" style="display: table; line-height: normal">
	                                <div style="display: table-row">
	                                    <div style="display: table-cell">
	                                        <input type="checkbox" name="soundex" value="1"/>
	                                    </div>
	                                    <div style="display: table-cell; padding-left: .5em" title="Search for Name Sounding Like Entered Value">
	                                        'Sounds Like' Name Search
	                                    </div>
	                                </div>
	                            </div>
	                            
	                            <div id="busNameSearchOpts" style="display: table; line-height: normal">
	                                <div style="display: table-row">
	                                    <div style="display: table-cell">
	                                        <input type="checkbox" name="business" value="1"/>
	                                    </div>
	                                    <div style="display: table-cell; width: 12em; padding-left: .5em" title="Search for Business Names Only">
	                                        Search Business Names &nbsp;
	                                    </div>
	                                    <div style="display: table-cell">
	                                        <span style="color: red">
	                                            To broaden your search results, use an asterisk (*). For example, searching
	                                            <span style="font-style: italic; font-weight: bold">exxon*</span>
	                                            will return "Exxon", "Exxon Mobil", "Exxon Corp", etc. </span>
	                                    </div>
	                                </div>
	                            </div>
	                            
	                            <div id="bookingPhotoSearchOpts" style="display: table; line-height: normal;">
	                                <div style="display: table-row">
	                                    <div style="display: table-cell">
	                                        <input type="checkbox" name="photos" value="1"/>
	                                    </div>
	                                    <div style="display: table-cell; padding-left: .5em" title="Search Booking Photos (if applicable)">
	                                        Show Booking Photos
	                                    </div>
	                                </div>
	                            </div>
	
	                    <div style="padding-top:1%">
	                        <button style="height: 2em" class="toggleSearchOpts" type="button" title="Toggle Search Options">Show/Hide Advanced Search Options</button>
	                    </div>
	                    
	                    <div id="searchOpts" style="display: none">
	                        <div>
	                            <div class="datePickerDiv" style="display: table; line-height: normal; margin-top: 1em">
	                                <div style="display: table-row">
	                                    <div style="display: table-cell; width: 9em">
	                                        <input placeholder="DOB" style="line-height: 1.25em; width: 6em; margin-right: .5em;" class="datepicker" id="DOB" name="DOB"/>
	                                    </div>
	                                    <div style="display: table-cell;">
	                                        DOB (will only list cases where DOB matches) &nbsp;  
	                                    </div>
	                                     <div style="display: table-cell;">
	                                        <input type="checkbox" id="fuzzyDOB" name="fuzzyDOB" checked="checked" value="1">
	                                     </div>
	                                     <div style="display: table-cell;">
	                                        Approximate DOB (will search 15 days before and after)&nbsp;
	                                     </div>
	                                     <div style="display: table-cell; vertical-align: middle">
	                                        <button type="button" class="clearDates" title="Clear Date of Birth">Clear DOB</button>
	                                     </div>
	                                </div>
	                            </div>
	                            
	                            <div class="datePickerDiv" style="display: table; line-height: normal">
	                                <div style="display: table-row">
	                                    <div style="display: table-cell">
	                                        File Dates Between
	                                    </div>
	                                    <div style="display: table-cell: width: 9em">
	                                        <input placeholder="Begin" style="line-height: 1.25em; width: 6em; margin-right: .5em;" class="datepicker" id="searchStart" name="searchStart"/>
	                                    </div>
	                                    <div style="display: table-cell; padding-left: .5em; padding-right: .5em;">
	                                        and
	                                    </div>
	                                    <div style="display: table-cell; width: 9em">
	                                        <input placeholder="End" style="line-height: 1.25em; width: 6em; margin-right: .5em;" class="datepicker" id="searchEnd" name="searchEnd"/>
	                                    </div>
	                                    <div style="display: table-cell">
	                                        Name searches only &nbsp;
	                                    </div>
	                                    <div style="display: table-cell">
	                                        <button type="button" class="clearDates" title="Clear Dates">Clear Dates</button> 
	                                    </div>
	                                </div>
	                            </div>

	                            <div id="divSeachOptsGroup" class="optsTop">
	                                <div id="divisionSearchOptsTitle" style="display: table; line-height: normal; margin-top: 1em;">
	                                    <div style="display: table-row">
	                                        <div style="display: table-cell;">
	                                            <span class="h2">Divisions</span>
	                                        </div>
	                                    </div>
	                                </div>
	                                <div id="divisionSearchOptsAll" class="allDiv" style="display: table; line-height: normal">
	                                    <div style="display: table-row" class="allOptsDiv">
	                                        <div style="display: table-cell; width: 1em; margin-right: 1em;">
	                                            <input type="checkbox" class="allOptsCheck" name="limitdiv" value="All" checked="checked"/>
	                                        </div>
	                                        <div style="display: table-cell;">
	                                            All (uncheck to choose individual divisions)
	                                        </div>
	                                    </div>
	                                </div>
	                                <div id="divisionSearchOpts" class="optsDiv" style="display: none; line-height: normal;">
	                                    <div style="display: table" class="optsDiv">
	                                        <?php $_smarty_tpl->_assignInScope('count', 0);
?> <?php $_smarty_tpl->_assignInScope('perCol', 10);
?>
	                                        <?php
 while ($_smarty_tpl->tpl_vars['count']->value < count($_smarty_tpl->tpl_vars['divlist']->value)) {?> 
	                                        <div style="display: table-row">
	                                            <?php
$_smarty_tpl->tpl_vars['inc'] = new Smarty_Variable(null, $_smarty_tpl->isRenderingCache);
$_smarty_tpl->tpl_vars['inc']->value = 0;
if ($_smarty_tpl->tpl_vars['inc']->value < $_smarty_tpl->tpl_vars['perCol']->value) {
for ($_foo=true;$_smarty_tpl->tpl_vars['inc']->value < $_smarty_tpl->tpl_vars['perCol']->value; $_smarty_tpl->tpl_vars['inc']->value++) {
$_smarty_tpl->_assignInScope('div', $_smarty_tpl->tpl_vars['divlist']->value[$_smarty_tpl->tpl_vars['count']->value+$_smarty_tpl->tpl_vars['inc']->value]);
?>
	                                            <?php if ($_smarty_tpl->tpl_vars['div']->value != '') {?>
	                                            <div style="display: table-cell; width: 1em; margin-right: 1em;">
	                                                <input type="checkbox" class="optCheck" name="limitdiv" value="<?php echo $_smarty_tpl->tpl_vars['div']->value;?>
"/>
	                                            </div>
	                                            <div style="display: table-cell; width: 10em; margin-right: 2em" title="Divison <?php echo $_smarty_tpl->tpl_vars['div']->value;?>
">
	                                                <?php echo $_smarty_tpl->tpl_vars['div']->value;?>

	                                            </div>
	                                            <?php }?>
	                                            <?php }
}
?>

	                                        </div>
	                                        <?php $_smarty_tpl->_assignInScope('count', $_smarty_tpl->tpl_vars['count']->value+$_smarty_tpl->tpl_vars['perCol']->value);
?>
	                                        <?php }?>

	                                    </div>
	                                </div>
	                            </div>
	                            
	                            <div id="courtTypeSearchOptsGroup" class="optsTop">
	                                <div id="courtTypeSearchOptsTitle" style="display: table; line-height: normal; margin-top: 1em;">
	                                    <div style="display: table-row">
	                                        <div style="display: table-cell;">
	                                            <span class="h2">Court Types</span>
	                                        </div>
	                                    </div>
	                                </div>
	                                
	                                <div id="courtTypeSearchOptsAll" class="allDiv" style="display: table; line-height: normal;">
	                                    <div style="display: table-row" class="allOptsDiv">
	                                        <div style="display: table-cell; width: 1em; margin-right: 1em;">
	                                            <input type="checkbox" class="allOptsCheck" name="limittype" value="All" checked="checked"/>
	                                        </div>
	                                        <div style="display: table-cell;">
	                                            All (uncheck to choose individual divisions)
	                                        </div>
	                                    </div>
	                                </div>
	                                
	                                <div id="courtTypeSearchOpts" class="optsDiv" style="display: none; line-height: normal;">
	                                    <div style="display: table" class="optsDiv">
	                                        <?php $_smarty_tpl->_assignInScope('count', 0);
?> <?php $_smarty_tpl->_assignInScope('perCol', 3);
?>
	                                        <?php
 while ($_smarty_tpl->tpl_vars['count']->value < count($_smarty_tpl->tpl_vars['divtypes']->value)) {?> 
	                                        <div style="display: table-row">
	                                            <?php
$_smarty_tpl->tpl_vars['inc'] = new Smarty_Variable(null, $_smarty_tpl->isRenderingCache);
$_smarty_tpl->tpl_vars['inc']->value = 0;
if ($_smarty_tpl->tpl_vars['inc']->value < $_smarty_tpl->tpl_vars['perCol']->value) {
for ($_foo=true;$_smarty_tpl->tpl_vars['inc']->value < $_smarty_tpl->tpl_vars['perCol']->value; $_smarty_tpl->tpl_vars['inc']->value++) {
$_smarty_tpl->_assignInScope('divtype', $_smarty_tpl->tpl_vars['divtypes']->value[$_smarty_tpl->tpl_vars['count']->value+$_smarty_tpl->tpl_vars['inc']->value]);
?>
	                                            <?php if ($_smarty_tpl->tpl_vars['divtype']->value != '') {?>
	                                            <div style="display: table-cell; width: 20em; margin-right: 2em" title="<?php echo $_smarty_tpl->tpl_vars['divtype']->value['division_type'];?>
">
	                                                <input type="checkbox" class="optCheck" name="limittype" value="<?php echo $_smarty_tpl->tpl_vars['divtype']->value['division_type'];?>
"/><?php echo $_smarty_tpl->tpl_vars['divtype']->value['division_type'];?>

	                                            </div>
	                                            <?php }?>
	                                            <?php }
}
?>

	                                        </div>
	                                        <?php $_smarty_tpl->_assignInScope('count', $_smarty_tpl->tpl_vars['count']->value+$_smarty_tpl->tpl_vars['perCol']->value);
?>
	                                        <?php }?>

	                                    </div>
	                                </div>
	                            </div>
	                            
	                            <div id="PartyTypeSearchOptsGroup" class="optsTop">
	                                <div id="PartyTypeSearchOpts" style="display: table; line-height: normal; margin-top: 1em;">
	                                    <div style="display: table-row">
	                                        <div style="display: table-cell;">
	                                            <span class="h2">Party Types</span>
	                                        </div>
	                                    </div>
	                                    <div style="display: table-row" class="allOptsDiv">
	                                        <div style="display: table-cell" title="Select All Party Types">
	                                            <input type="checkbox" class="allOptsCheck" name="partyTypeLimit" value="All" checked="checked"/>All (uncheck to choose specific types)
	                                        </div>
	                                    </div>
	                                </div>
	                                <div id="PartyTypeSearchOptsSpecial" style="display: table; line-height: normal;">
	                                    <div style="display: none" class="optsDiv">
	                                        <div style="display: table-row">
	                                            <div style="display: table-cell; width: 1em; margin-right: 2em">
	                                                <input type="checkbox" class="attyCheck" data-targetclass="attyParty" style="margin-right: .5em"/>
	                                            </div>
	                                            <div style="display: table-cell" title="Select All Attorney Types">
	                                                <strong>All Attorney Parties</strong>
	                                            </div>
	                                            <div style="display: table-cell; width: 1em; margin-right: 2em">
	                                                <input type="checkbox" class="dftCheck" data-targetclass="dftParty" style="margin-right: .5em"/>
	                                            </div>
	                                            <div style="display: table-cell" title="Select All Defendant Types">
	                                                <strong>All Defendant Parties</strong>
	                                            </div>
	                                        </div>
	                                        <?php $_smarty_tpl->_assignInScope('count', 0);
?> <?php $_smarty_tpl->_assignInScope('perCol', 3);
?>
	                                        <?php
 while ($_smarty_tpl->tpl_vars['count']->value < count($_smarty_tpl->tpl_vars['partyTypes']->value)) {?> 
	                                        <div style="display: table-row">
	                                            <?php
$_smarty_tpl->tpl_vars['inc'] = new Smarty_Variable(null, $_smarty_tpl->isRenderingCache);
$_smarty_tpl->tpl_vars['inc']->value = 0;
if ($_smarty_tpl->tpl_vars['inc']->value < $_smarty_tpl->tpl_vars['perCol']->value) {
for ($_foo=true;$_smarty_tpl->tpl_vars['inc']->value < $_smarty_tpl->tpl_vars['perCol']->value; $_smarty_tpl->tpl_vars['inc']->value++) {
$_smarty_tpl->_assignInScope('partytype', $_smarty_tpl->tpl_vars['partyTypes']->value[$_smarty_tpl->tpl_vars['count']->value+$_smarty_tpl->tpl_vars['inc']->value]);
?>
	                                            <?php if ($_smarty_tpl->tpl_vars['partytype']->value['PartyTypeDescription'] != '') {?>
	                                            <div style="display: table-cell; width: 1em; margin-right: 2em">
	                                                <input type="checkbox" class="optCheck <?php echo $_smarty_tpl->tpl_vars['partytype']->value['PartyClass'];?>
" name="partyTypeLimit" value="<?php echo $_smarty_tpl->tpl_vars['partytype']->value['PartyType'];?>
"/>
	                                            </div>
	                                            <div style="display: table-cell; width: 20em; margin-right: 2em; padding-right: 1em" title="<?php echo $_smarty_tpl->tpl_vars['partytype']->value['PartyTypeDescription'];?>
">
	                                                <?php echo $_smarty_tpl->tpl_vars['partytype']->value['PartyTypeDescription'];?>

	                                            </div>
	                                            <?php }?>
	                                            <?php }
}
?>

	                                        </div>
	                                        <?php $_smarty_tpl->_assignInScope('count', $_smarty_tpl->tpl_vars['count']->value+$_smarty_tpl->tpl_vars['perCol']->value);
?>
	                                        <?php }?>

	                                    </div>
	                                </div>
	                            </div>
	                            
	                            <div id="chargeSearchOptsGroup" class="optsTop">
	                                <div id="chargeSearchOpts" style="display: table; line-height: normal; margin-top: 1em; margin-bottom: 2em;">
	                                    <div style="display: table-row">
	                                        <div style="display: table-cell;">
	                                            <span class="h2">Charge Types (Criminal Cases Only)</span>
	                                        </div>
	                                    </div>
	                                    <div style="display: table-row" class="allOptsDiv">
	                                        <div style="display: table-cell">
	                                            <input type="checkbox" class="allOptsCheck" name="chargetype" value="All" checked="checked"/>All (uncheck to choose specific types)
	                                        </div>
	                                    </div>
	                                    <div style="display: none;" class="optsDiv">
	                                        <?php $_smarty_tpl->_assignInScope('count', 0);
?> <?php $_smarty_tpl->_assignInScope('perCol', 3);
?>
	                                        <?php $_smarty_tpl->_assignInScope('charges', $_smarty_tpl->tpl_vars['searchParams']->value['Charges']);
?>
	                                        <?php $_smarty_tpl->_assignInScope('inc', 0);
?>
	                                        <div style="display: table-row;">
	                                        <?php
$_from = $_smarty_tpl->smarty->ext->_foreach->init($_smarty_tpl, $_smarty_tpl->tpl_vars['charges']->value, 'val', false, 'key');
if ($_from !== null) {
foreach ($_from as $_smarty_tpl->tpl_vars['key']->value => $_smarty_tpl->tpl_vars['val']->value) {
?>
	                                            <div style="display: table-cell; width: 1em; margin-right: 2em">
	                                                <input type="checkbox" class="optCheck" name="chargetype" value="<?php echo $_smarty_tpl->tpl_vars['val']->value;?>
"/>
	                                            </div>
	                                            <div style="display: table-cell; width: 20em; margin-right: 2em; padding-right: 1em" title="<?php echo $_smarty_tpl->tpl_vars['key']->value;?>
">
	                                                <?php echo $_smarty_tpl->tpl_vars['key']->value;?>

	                                            </div>
	                                            <?php $_smarty_tpl->_assignInScope('inc', $_smarty_tpl->tpl_vars['inc']->value+1);
?>
	                                        <?php if ((($_smarty_tpl->tpl_vars['inc']->value == $_smarty_tpl->tpl_vars['perCol']->value) || ($_smarty_tpl->tpl_vars['charges']->value['last']))) {?>
	                                        <?php $_smarty_tpl->_assignInScope('inc', 0);
?>
	                                        </div>
	                                        <div style="display: table-row;">
	                                        <?php }?>
	                                        
	                                        <?php
}
}
$_smarty_tpl->smarty->ext->_foreach->restore($_smarty_tpl, 1);
?>

	                                        </div>
	                                    </div>
	                                </div>
	                            </div>
	                            
	                            <div id="causeSearchOptsGroup" class="optsTop">
	                                <div id="causeSearchOpts" style="display: table; line-height: normal; margin-top: 1em; margin-bottom: 2em;">
	                                    <div style="display: table-row">
	                                        <div style="display: table-cell;">
	                                            <span class="h2">Causes of Action (Non-Criminal)</span>
	                                        </div>
	                                    </div>
	                                    <div style="display: table-row" class="allOptsDiv">
	                                        <div style="display: table-cell">
	                                            <input type="checkbox" class="allOptsCheck" name="causetype" value="All" checked="checked"/>All (uncheck to choose specific types)
	                                        </div>
	                                    </div>
	                                    <div style="display: none;" class="optsDiv">
	                                        <?php $_smarty_tpl->_assignInScope('count', 0);
?> <?php $_smarty_tpl->_assignInScope('perCol', 3);
?>
	                                        <?php $_smarty_tpl->_assignInScope('charges', $_smarty_tpl->tpl_vars['searchParams']->value['Causes']);
?>
	                                        <?php $_smarty_tpl->_assignInScope('inc', 0);
?>
	                                        <div style="display: table-row;">
	                                        <?php
$_from = $_smarty_tpl->smarty->ext->_foreach->init($_smarty_tpl, $_smarty_tpl->tpl_vars['charges']->value, 'val', false, 'key');
if ($_from !== null) {
foreach ($_from as $_smarty_tpl->tpl_vars['key']->value => $_smarty_tpl->tpl_vars['val']->value) {
?>
	                                            <div style="display: table-cell; width: 1em; margin-right: 2em">
	                                                <input type="checkbox" class="optCheck" name="causetype" value="<?php echo $_smarty_tpl->tpl_vars['val']->value;?>
"/>
	                                            </div>
	                                            <div style="display: table-cell; width: 20em; margin-right: 2em; padding-right: 1em" title="<?php echo $_smarty_tpl->tpl_vars['key']->value;?>
">
	                                                <?php echo $_smarty_tpl->tpl_vars['key']->value;?>

	                                            </div>
	                                            <?php $_smarty_tpl->_assignInScope('inc', $_smarty_tpl->tpl_vars['inc']->value+1);
?>
	                                        <?php if ((($_smarty_tpl->tpl_vars['inc']->value == $_smarty_tpl->tpl_vars['perCol']->value) || ($_smarty_tpl->tpl_vars['charges']->value['last']))) {?>
	                                        <?php $_smarty_tpl->_assignInScope('inc', 0);
?>
	                                        </div>
	                                        <div style="display: table-row;">
	                                        <?php }?>
	                                        
	                                        <?php
}
}
$_smarty_tpl->smarty->ext->_foreach->restore($_smarty_tpl, 1);
?>

	                                        </div>
	                                    </div>
	                                </div>
	                            </div>
	                            
	                    <div>
	                        
	                        
	                    <div style="display: table; line-height: normal;">
	                        <div style="display: table-row">
	                            <div style="display: table-cell">
	                                <input type="checkbox" name="active" value="1"/>
	                            </div>
	                            <div style="display: table-cell; padding-left: .5em" title="Search Only Active Cases">
	                                Active Cases Only &nbsp;&nbsp;
	                            </div>
	                            <div style="display: table-cell">
	                                <input type="checkbox" name="charges" checked="checked" value="1"/>
	                            </div>
	                            <div style="display: table-cell; padding-left: .5em" title="Search Charges">
	                                Show Charge Information
	                            </div>
	                        </div>
	                    </div>
	
	                    <div style="display: table; line-height: normal;">
	                        <div style="display: table-row">
	                            <div style="display: table-cell">
	                                <input id="crimonly" type="checkbox" name="criminal" value="1" onchange="toggleOpposite('crimonly','civonly')"/>
	                            </div>
	                            <div style="display: table-cell; padding-left: .5em" title="Search Only Criminal and Traffic Cases">
	                                Criminal and Traffic Cases Only
	                            </div>
	                        </div>
	                    </div>
	
	                    <div style="display: table; line-height: normal;">
	                        <div style="display: table-row">
	                            <div style="display: table-cell">
	                                <input id="civonly" type="checkbox" name="nocriminal" value="1" onchange="toggleOpposite('civonly','crimonly')"/>
	                            </div>
	                            <div style="display: table-cell; padding-left: .5em" title="Search Only Civil Cases">
	                                Civil Cases Only
	                            </div>
	                        </div>
	                    </div>
	                </div>
	
	
	                        </div>
	                    </div>
	                </div>
	            </td>
		    </tr>

		    <tr>
	            <td colspan="2">
	                <input type="hidden" name="type" value=""/>
	            </td>
	        </tr>
			<tr>
				<td><br/></td>
			</tr>
	        <tr>
	            <td style="text-align:right; vertical-align:top;">
	                <span>
	                    Citation #:
	                </span>
	
	            </td>
	
	            <td class="textinput">
	                <div>
	                    <input placeholder="Search by Citation #" style="line-height: 1.25em" type="text" id="searchcitation" name="citation" size="30" title="Enter Citation #"/>
	                    <button style="height: 2em" type="submit" class="search" title="Search Button">Search</button>
	                </div>
	
	            </td>
		    </tr>
		</form> 

	        <!--<tr>
	            <td>&nbsp;</td>
	            <td style="padding-top:1%">
	                <button type="button" class="docSearchToggle">Show/Hide Document Search</button>
	                
	                <div id="docSearchTop" style="display: none">
	                    <form id="docSearchForm">
	                        <div id="docSearchDiv" style="display: table">
	                            <div id="docSearchHeaders" style="display: table-header-group;">
	                                <div class="docSearchCell docSearchHeader" style="display: table-cell" title="Select Court Type to Search">
	                                    Court Type
	                                </div>
	                                <div class="docSearchCell docSearchHeader" style="display: table-cell" title="Select Division to Search">
	                                    Division
	                                </div>
	                                <div class="docSearchCell docSearchHeader" style="display: table-cell" title="Select Case Numbers to Search">
	                                    Case Number(s) (Overrides other settings - separate multiple cases with spaces or commas)
	                                </div>
	                                <div class="docSearchCell docSearchHeader" style="display: table-cell" title="Enter Search Term">
	                                    Search Term(s) (separate multiple search terms with spaces or commas)
	                                </div>
	                            </div>
	                            
	                            <div id="docSearchSelects" style="display: table-row-group">
	                                <div class="docSearchCell" id="ds_courtTypeDiv" style="display: table-cell">
	                                    <select id="searchCore" name="searchCore">
	                                        <option value="all" selected="selected" title="All Court Types">All</option>
	                                        <option value="civil" title="Civil Divisions">Civil</option>
	                                        <option value="criminal" title="Criminal Divisions">Criminal</option>
	                                        <option value="family" title="Family Divisions">Family</option>
	                                        <option value="juvenile" title="Juvenile Divisions">Juvenile</option>
	                                        <option value="probate" title="Probate Divisions">Probate</option>
	                                    </select>
	                                </div>
	                                <div class="docSearchCell" id="ds_divisionDiv" style="display: table-cell">
	                                    <select id="searchDiv" name="searchDiv">
	                                        <option value="all" selected="selected" title="Search All Divisions">All</option>
	                                        <?php
$_from = $_smarty_tpl->smarty->ext->_foreach->init($_smarty_tpl, $_smarty_tpl->tpl_vars['allDivsArray']->value, 'div');
if ($_from !== null) {
foreach ($_from as $_smarty_tpl->tpl_vars['div']->value) {
?>
	                                        <option value="<?php echo $_smarty_tpl->tpl_vars['div']->value;?>
" title="Division <?php echo $_smarty_tpl->tpl_vars['div']->value;?>
"><?php echo $_smarty_tpl->tpl_vars['div']->value;?>
</option>
	                                        <?php
}
}
$_smarty_tpl->smarty->ext->_foreach->restore($_smarty_tpl, 1);
?>

	                                    </select>
	                                </div>
	                                <div class="docSearchCell" id="ds_caseNum" style="display: table-cell">
	                                    <input type="text" style="width: 35em" name="dsCaseNumSearch" id="dsCaseNumSearch" placeholder="Case Number" title="Enter Case Number(s) to Search">
	                                </div>
	                                
	                                <div class="docSearchCell" id="ds_serchTerm" style="display: table-cell">
	                                    <input type="text" name="dsSearchTerm" id="dsSearchTerm" placeholder="Search Term" title="Enter Search Term"/>
	                                    <button type="button" class="docSearchBtn">Search</button>
	                                </div>
	                            </div>
	                            
	                            <div style="display: table-row-group">
	                                <div class="docSearchCell" style="display: table-cell">&nbsp;</div>
	                                <div class="docSearchCell" style="display: table-cell">&nbsp;</div>
	                                <div class="docSearchCell" id="searchCaseStyle" style="display: table-cell; width: 40em; max-width: 40em;">
	                                    <div style="display: table" id="searchStyleTable">
	                                        
	                                    </div>
	                                </div>
	                                <div class="docSearchCell" style="display: table-cell"></div>
	                            </div>
	                        </div>
	                    </form>
	                    
	                    <div id="docSearchResults" style="display: none">
	                        <button type="button" class="toggleDocSearchResults">Show/Hide Search Results</button>
	                        <br/><br/>
	                        <div id="totalSearch">
	                            <span style="font-size: 120%; font-weight: bold"><span id="searchCount"></span> matching documents found.</span>
	                            <table id="docSearchTable">
	                                <thead>
	                                    <tr>
	                                        <th>Case Number</th>
	                                        <th>Document</th>
	                                        <th>Highlights</th>
	                                    </tr>
	                                </thead>
	                                <tbody id="docSearchTableBody">
	                                
	                                </tbody>
	                            </table>
	                        </div>
	                    </div>
	                    
	                </div>
	            </td>
	        </tr>-->
	        <tr>
	            <td colspan="2">
	            	<br/>
	                <span class="h3">
	                    <a href="/cgi-bin/casenotes/flaggedCaseSearch.cgi">
	                        Flagged Case Search
	                    </a>
	                </span>
	            </td>
	        </tr>
	        <tr>
	            <td colspan="2">
	                <span class="h3">
	                    <a href="/cgi-bin/PBSO/pbsolookup.cgi" data-tab="pbsolookup">
	                        PBSO Search
	                    </a>
	                </span>
	            </td>
	        </tr>
		</table>
	    <table style="width:75%;">
            <tr>
				<td><br/></td>
			</tr>    
		    <tr>
	            <td colspan="3">
	                <span style="font-size:30px; color:blue; font-weight:bold">
	            		Manage
	            	</span>	
	            	<div style="background:blue; width:100%; height:2px;">&nbsp;</div>
	            	<br/>
	            </td>
	        </tr>

	        <tr>
	            <td colspan="2">
	                <span class="h3">
	                    <a href="/cgi-bin/casenotes/bulkflag.cgi">
	                        Bulk Case Flagging/Unflagging
	                    </a>
	                </span>
	            </td>
	        </tr>
	        
	        <tr>
	            <td colspan="2">
	                <span class="h3">
	                    <a href="/cgi-bin/casenotes/bulknote.cgi">
	                        Add Bulk Case Notes
	                    </a>
	                </span>
	            </td>
	        </tr>
	        
	        <tr>
	            <td colspan="2">
	                <span class="h3">
	                    <a href="/cgi-bin/eservice/showFilings.cgi">
	                        View My e-Filing Status
	                    </a>
	                </span>
	            </td>
	        </tr>
	        
	        <tr>
	            <td colspan="2">
	                <span class="h3">
	                    <a href="/watchlist/showWatchList.php">
	                        Show My Case Watchlist
	                    </a>
	                </span>
	            </td>
	        </tr>
	    <tr>
			<td><br/></td>
		</tr>    
        <tr>
            <td colspan="3">
            	<span style="font-size:30px; color:blue; font-weight:bold">
	            	Reports
	            </span>	
	        </td>
	    </tr>
	    <tr>
	    	<td colspan="3">
	    		<div style="background:blue; width:100%; height:2px;">&nbsp;</div>
	    	</td>
	    </tr>
	    <tr>
	    	<td style="width:33%">
	            <div class="h2">
	            	All Judges
	            </div>
            </td>
            <td style="width:33%">
	        	<div class="h2">
	            	All Magistrates
	            </div>
	        </td>
	        <td>
				<div class="h2">
					All Divisions
				</div>
			</td>
        </tr>
		<tr>
		    <td>
				<span class="h3"></span>
				<select name="judgexy" title="Select Judge" style="min-width: 15em">
	            	<?php
$_from = $_smarty_tpl->smarty->ext->_foreach->init($_smarty_tpl, $_smarty_tpl->tpl_vars['judges']->value, 'divs', false, 'judge');
if ($_from !== null) {
foreach ($_from as $_smarty_tpl->tpl_vars['judge']->value => $_smarty_tpl->tpl_vars['divs']->value) {
?>
	                	<option value="<?php echo $_smarty_tpl->tpl_vars['judge']->value;?>
~<?php echo $_smarty_tpl->tpl_vars['divs']->value;?>
" title="<?php echo $_smarty_tpl->tpl_vars['judge']->value;?>
"><?php echo $_smarty_tpl->tpl_vars['judge']->value;?>
</option>
	                <?php
}
}
$_smarty_tpl->smarty->ext->_foreach->restore($_smarty_tpl, 1);
?>

	            </select>
				<button type="button" class="reportView judgeRpt" title="Submit Button" onclick="gojudge3();">View</button>
		    </td>
		    <td>
				<span class="h3"></span>
				<select name="magistratexy" style="min-width: 15em">
					<?php
$_from = $_smarty_tpl->smarty->ext->_foreach->init($_smarty_tpl, $_smarty_tpl->tpl_vars['magistrates']->value, 'mag', false, 'm');
if ($_from !== null) {
foreach ($_from as $_smarty_tpl->tpl_vars['m']->value => $_smarty_tpl->tpl_vars['mag']->value) {
?>
						<option value="<?php echo $_smarty_tpl->tpl_vars['mag']->value;?>
"><?php echo $_smarty_tpl->tpl_vars['m']->value;?>
</option>
					<?php
}
}
$_smarty_tpl->smarty->ext->_foreach->restore($_smarty_tpl, 1);
?>

				</select>
				<button type="button" class="reportView magRpt" title="Submit Button" onclick="gomag();">View</button>
		    </td>
		    <td>
				<span class="h3"></span>
	            <select name="divxy_all" title="Select Division" style="min-width: 15em">
	               	<?php
$_from = $_smarty_tpl->smarty->ext->_foreach->init($_smarty_tpl, $_smarty_tpl->tpl_vars['divlist']->value, 'div');
if ($_from !== null) {
foreach ($_from as $_smarty_tpl->tpl_vars['div']->value) {
?>
	                   	<?php if (!in_array($_smarty_tpl->tpl_vars['div']->value,$_smarty_tpl->tpl_vars['skipDivs']->value)) {?>
	                    	<option value="<?php echo $_smarty_tpl->tpl_vars['divisions']->value[$_smarty_tpl->tpl_vars['div']->value]['opt'];?>
" title="<?php echo $_smarty_tpl->tpl_vars['divisions']->value[$_smarty_tpl->tpl_vars['div']->value]['courtType'];?>
 Division <?php echo $_smarty_tpl->tpl_vars['div']->value;?>
"><?php echo $_smarty_tpl->tpl_vars['div']->value;?>
 <?php if ($_smarty_tpl->tpl_vars['div']->value != 'VA') {?>(<?php echo $_smarty_tpl->tpl_vars['divisions']->value[$_smarty_tpl->tpl_vars['div']->value]['courtType'];?>
)<?php }?></option>
	                    <?php }?>
	                <?php
}
}
$_smarty_tpl->smarty->ext->_foreach->restore($_smarty_tpl, 1);
?>

                 </select>
                <button type="button" class="reportView divRpt" title="Submit Button" onclick="godiv('all');">View</button>
            </td>
		</tr>
			<tr>
				<td>
					<div class="h2">
						Criminal Divisions
					</div>
				</td>
				<td>
					<div class="h2">
						Civil Divisions
					</div>
				</td>
				<td>
					<div class="h2">
						Family Divisions
					</div>
				</td>
			</tr>
			<tr>
                <td>
                	<span class="h3"></span>
	            	<select name="divxy_crim" title="Select Division" style="min-width: 15em">
	                	<?php
$_from = $_smarty_tpl->smarty->ext->_foreach->init($_smarty_tpl, $_smarty_tpl->tpl_vars['crim_divlist']->value, 'div');
if ($_from !== null) {
foreach ($_from as $_smarty_tpl->tpl_vars['div']->value) {
?>
	                    	<?php if (!in_array($_smarty_tpl->tpl_vars['div']->value,$_smarty_tpl->tpl_vars['skipDivs']->value)) {?>
	                        	<option value="<?php echo $_smarty_tpl->tpl_vars['divisions']->value[$_smarty_tpl->tpl_vars['div']->value]['opt'];?>
" title="<?php echo $_smarty_tpl->tpl_vars['divisions']->value[$_smarty_tpl->tpl_vars['div']->value]['courtType'];?>
 Division <?php echo $_smarty_tpl->tpl_vars['div']->value;?>
"><?php echo $_smarty_tpl->tpl_vars['div']->value;?>
 <?php if ($_smarty_tpl->tpl_vars['div']->value != 'VA') {?>(<?php echo $_smarty_tpl->tpl_vars['divisions']->value[$_smarty_tpl->tpl_vars['div']->value]['courtType'];?>
)<?php }?></option>
	                        <?php }?>
	                    <?php
}
}
$_smarty_tpl->smarty->ext->_foreach->restore($_smarty_tpl, 1);
?>

                    </select>
                    <button type="button" class="reportView divRpt" title="Submit Button" onclick="godiv('crim');">View</button>
                </td>
                <td>
                	<span class="h3"></span>
	            	<select name="divxy_civ" title="Select Division" style="min-width: 15em">
	                	<?php
$_from = $_smarty_tpl->smarty->ext->_foreach->init($_smarty_tpl, $_smarty_tpl->tpl_vars['civ_divlist']->value, 'div');
if ($_from !== null) {
foreach ($_from as $_smarty_tpl->tpl_vars['div']->value) {
?>
	                    	<?php if (!in_array($_smarty_tpl->tpl_vars['div']->value,$_smarty_tpl->tpl_vars['skipDivs']->value)) {?>
	                        	<option value="<?php echo $_smarty_tpl->tpl_vars['divisions']->value[$_smarty_tpl->tpl_vars['div']->value]['opt'];?>
" title="<?php echo $_smarty_tpl->tpl_vars['divisions']->value[$_smarty_tpl->tpl_vars['div']->value]['courtType'];?>
 Division <?php echo $_smarty_tpl->tpl_vars['div']->value;?>
"><?php echo $_smarty_tpl->tpl_vars['div']->value;?>
 <?php if ($_smarty_tpl->tpl_vars['div']->value != 'VA') {?>(<?php echo $_smarty_tpl->tpl_vars['divisions']->value[$_smarty_tpl->tpl_vars['div']->value]['courtType'];?>
)<?php }?></option>
	                        <?php }?>
	                    <?php
}
}
$_smarty_tpl->smarty->ext->_foreach->restore($_smarty_tpl, 1);
?>

                    </select>
                    <button type="button" class="reportView divRpt" title="Submit Button" onclick="godiv('civ');">View</button>
                </td>
                <td>
					<span class="h3"></span>
	            	<select name="divxy_fam" title="Select Division" style="min-width: 15em">
	                	<?php
$_from = $_smarty_tpl->smarty->ext->_foreach->init($_smarty_tpl, $_smarty_tpl->tpl_vars['fam_divlist']->value, 'div');
if ($_from !== null) {
foreach ($_from as $_smarty_tpl->tpl_vars['div']->value) {
?>
	                    	<?php if (!in_array($_smarty_tpl->tpl_vars['div']->value,$_smarty_tpl->tpl_vars['skipDivs']->value)) {?>
	                        	<option value="<?php echo $_smarty_tpl->tpl_vars['divisions']->value[$_smarty_tpl->tpl_vars['div']->value]['opt'];?>
" title="<?php echo $_smarty_tpl->tpl_vars['divisions']->value[$_smarty_tpl->tpl_vars['div']->value]['courtType'];?>
 Division <?php echo $_smarty_tpl->tpl_vars['div']->value;?>
"><?php echo $_smarty_tpl->tpl_vars['div']->value;?>
 <?php if ($_smarty_tpl->tpl_vars['div']->value != 'VA') {?>(<?php echo $_smarty_tpl->tpl_vars['divisions']->value[$_smarty_tpl->tpl_vars['div']->value]['courtType'];?>
)<?php }?></option>
	                        <?php }?>
	                    <?php
}
}
$_smarty_tpl->smarty->ext->_foreach->restore($_smarty_tpl, 1);
?>

                    </select>
                    <button type="button" class="reportView divRpt" title="Submit Button" onclick="godiv('fam');">View</button>
                </td>
	        </tr>
		    <tr>
				<td>
					<div class="h2">
						Juvenile Divisions
					</div>
				</td>
				<td>
					<div class="h2">
						Probate Divisions
					</div>
				</td>
				<td style="width:33%">
		        	<div class="h2">
		            	&nbsp;
		            </div>
		        </td>
			</tr>
			<tr>
                <td>
                	<span class="h3"></span>
	            	<select name="divxy_juv" title="Select Division" style="min-width: 15em">
	                	<?php
$_from = $_smarty_tpl->smarty->ext->_foreach->init($_smarty_tpl, $_smarty_tpl->tpl_vars['juv_divlist']->value, 'div');
if ($_from !== null) {
foreach ($_from as $_smarty_tpl->tpl_vars['div']->value) {
?>
	                    	<?php if (!in_array($_smarty_tpl->tpl_vars['div']->value,$_smarty_tpl->tpl_vars['skipDivs']->value)) {?>
	                        	<option value="<?php echo $_smarty_tpl->tpl_vars['divisions']->value[$_smarty_tpl->tpl_vars['div']->value]['opt'];?>
" title="<?php echo $_smarty_tpl->tpl_vars['divisions']->value[$_smarty_tpl->tpl_vars['div']->value]['courtType'];?>
 Division <?php echo $_smarty_tpl->tpl_vars['div']->value;?>
"><?php echo $_smarty_tpl->tpl_vars['div']->value;?>
 <?php if ($_smarty_tpl->tpl_vars['div']->value != 'VA') {?>(<?php echo $_smarty_tpl->tpl_vars['divisions']->value[$_smarty_tpl->tpl_vars['div']->value]['courtType'];?>
)<?php }?></option>
	                        <?php }?>
	                    <?php
}
}
$_smarty_tpl->smarty->ext->_foreach->restore($_smarty_tpl, 1);
?>

                    </select>
                    <button type="button" class="reportView divRpt" title="Submit Button" onclick="godiv('juv');">View</button>
                </td>
                <td>
                	<span class="h3"></span>
	            	<select name="divxy_pro" title="Select Division" style="min-width: 15em">
	                	<?php
$_from = $_smarty_tpl->smarty->ext->_foreach->init($_smarty_tpl, $_smarty_tpl->tpl_vars['pro_divlist']->value, 'div');
if ($_from !== null) {
foreach ($_from as $_smarty_tpl->tpl_vars['div']->value) {
?>
	                    	<?php if (!in_array($_smarty_tpl->tpl_vars['div']->value,$_smarty_tpl->tpl_vars['skipDivs']->value)) {?>
	                        	<option value="<?php echo $_smarty_tpl->tpl_vars['divisions']->value[$_smarty_tpl->tpl_vars['div']->value]['opt'];?>
" title="<?php echo $_smarty_tpl->tpl_vars['divisions']->value[$_smarty_tpl->tpl_vars['div']->value]['courtType'];?>
 Division <?php echo $_smarty_tpl->tpl_vars['div']->value;?>
"><?php echo $_smarty_tpl->tpl_vars['div']->value;?>
 <?php if ($_smarty_tpl->tpl_vars['div']->value != 'VA') {?>(<?php echo $_smarty_tpl->tpl_vars['divisions']->value[$_smarty_tpl->tpl_vars['div']->value]['courtType'];?>
)<?php }?></option>
	                        <?php }?>
	                    <?php
}
}
$_smarty_tpl->smarty->ext->_foreach->restore($_smarty_tpl, 1);
?>

                    </select>
                    <button type="button" class="reportView divRpt" title="Submit Button" onclick="godiv('pro');">View</button>
                </td>
                <td>
		        	<div class="h2">
		            	&nbsp;
		            </div>
		        </td>
			</tr>
		<tr>
			<td><br/></td>
		</tr>  	
		<tr style="vertical-align: top">
			<td colspan="3">
				<span style="font-size:30px; color:blue; font-weight:bold">
	            	Calendars
	            </span>	
	            <div style="background:blue; width:100%; height:2px;">&nbsp;</div>
	        </td>
	    <tr>
	    	<td>
				<div class="h2">
					Circuit Civil
				</div>
			</td>
			<td>
				<div class="h2">
					County Civil
				</div>
			</td>
			<td>
				<div class="h2">
					Criminal
				</div>
			</td>
		</tr>
		<tr>
			<td id="civsel">
				<span class="h3"></span>
				<select style="min-width: 15em" class="divsel" name="caldiv" id="caldiv" title="Select a Civil Division">
					<option value="" title="Select a Division">Select a Division</option>
                    <?php
$_from = $_smarty_tpl->smarty->ext->_foreach->init($_smarty_tpl, $_smarty_tpl->tpl_vars['circivdivs']->value, 'info', false, 'div');
if ($_from !== null) {
foreach ($_from as $_smarty_tpl->tpl_vars['div']->value => $_smarty_tpl->tpl_vars['info']->value) {
?>
                    	<option value="<?php echo $_smarty_tpl->tpl_vars['div']->value;?>
" title="Division <?php echo $_smarty_tpl->tpl_vars['div']->value;?>
"><?php echo $_smarty_tpl->tpl_vars['div']->value;?>
 (<?php echo $_smarty_tpl->tpl_vars['info']->value['courtType'];?>
)</option>
                    <?php
}
}
$_smarty_tpl->smarty->ext->_foreach->restore($_smarty_tpl, 1);
?>

				</select>
                <button type="button" class="calsubmit" name="calType" value="civcal">View</button>
		    </td>
		    <td id="cocivselsel">
		    	<span class="h3"></span>
				<select style="min-width: 15em" class="divsel" name="cocivdiv" id="cocivdiv" title="Select a Civil Division">
					<option value="" title="Select a Division">Select a Division</option>
                    <?php
$_from = $_smarty_tpl->smarty->ext->_foreach->init($_smarty_tpl, $_smarty_tpl->tpl_vars['cocivdivs']->value, 'info', false, 'div');
if ($_from !== null) {
foreach ($_from as $_smarty_tpl->tpl_vars['div']->value => $_smarty_tpl->tpl_vars['info']->value) {
?>
                    <option value="<?php echo $_smarty_tpl->tpl_vars['div']->value;?>
" title="Division <?php echo $_smarty_tpl->tpl_vars['div']->value;?>
"><?php echo $_smarty_tpl->tpl_vars['div']->value;?>
 (<?php echo $_smarty_tpl->tpl_vars['info']->value['courtType'];?>
)</option>
                    <?php
}
}
$_smarty_tpl->smarty->ext->_foreach->restore($_smarty_tpl, 1);
?>

				</select>
                <button class="calsubmit" name="calType" value="cocivcal">View</button>
		    </td>
		    <td id="crimsel">
		    	<span class="h3"></span>
				<select style="min-width: 15em" class="divsel"  name="crimdiv" id="crimdiv" title="Select Criminal Division">
                    <option value="" title="Select a Division">Select a Division</option>
                    <?php
$_from = $_smarty_tpl->smarty->ext->_foreach->init($_smarty_tpl, $_smarty_tpl->tpl_vars['crimdivs']->value, 'info', false, 'div');
if ($_from !== null) {
foreach ($_from as $_smarty_tpl->tpl_vars['div']->value => $_smarty_tpl->tpl_vars['info']->value) {
?>
                    <option value="<?php echo $_smarty_tpl->tpl_vars['div']->value;?>
" title="Division <?php echo $_smarty_tpl->tpl_vars['div']->value;?>
"><?php echo $_smarty_tpl->tpl_vars['div']->value;?>
 (<?php echo $_smarty_tpl->tpl_vars['info']->value['courtType'];?>
)</option>
                    <?php
}
}
$_smarty_tpl->smarty->ext->_foreach->restore($_smarty_tpl, 1);
?>

				</select>
                <button class="calsubmit" name="calType" value="crimcal" title="Submit Button">View</button>
		    </td>
		</tr>
		
		<tr>
			<td>
				<div class="h2">
					Family
				</div>
			</td>
			<td>
				<div class="h2">
					Juvenile
				</div>
			</td>
			<td>
				<div class="h2">
					Magistrates
				</div>
			</td>
		</tr>
		<tr>
			<td id="famsel">
		    	<span class="h3"></span>
				<select style="min-width: 15em" class="divsel"  name="famdiv" id="famdiv" title="Select Family Division">
                    <option value="" title="Select a Division">Select a Division</option>
                    <?php
$_from = $_smarty_tpl->smarty->ext->_foreach->init($_smarty_tpl, $_smarty_tpl->tpl_vars['famdivs']->value, 'info', false, 'div');
if ($_from !== null) {
foreach ($_from as $_smarty_tpl->tpl_vars['div']->value => $_smarty_tpl->tpl_vars['info']->value) {
?>
                    <option value="<?php echo $_smarty_tpl->tpl_vars['div']->value;?>
" title="Division <?php echo $_smarty_tpl->tpl_vars['div']->value;?>
"><?php echo $_smarty_tpl->tpl_vars['div']->value;?>
 (<?php echo $_smarty_tpl->tpl_vars['info']->value['courtType'];?>
)</option>
                    <?php
}
}
$_smarty_tpl->smarty->ext->_foreach->restore($_smarty_tpl, 1);
?>

				</select>
                <button class="calsubmit" name="calType" value="famcal" title="Submit Button">View</button>
		    </td>
			<td id="juvsel">
				<span class="h3"></span>
				<select style="min-width: 15em" class="divsel"  name="juvdiv" id="juvdiv" title="Select Juvenile Division">
					<option value="" title="Select a Division">Select a Division</option>
                    <?php
$_from = $_smarty_tpl->smarty->ext->_foreach->init($_smarty_tpl, $_smarty_tpl->tpl_vars['juvdivs']->value, 'info', false, 'div');
if ($_from !== null) {
foreach ($_from as $_smarty_tpl->tpl_vars['div']->value => $_smarty_tpl->tpl_vars['info']->value) {
?>
                    <option title="Division <?php echo $_smarty_tpl->tpl_vars['div']->value;?>
" value="<?php echo $_smarty_tpl->tpl_vars['div']->value;?>
"><?php echo $_smarty_tpl->tpl_vars['div']->value;?>
 (<?php echo $_smarty_tpl->tpl_vars['info']->value['courtType'];?>
)</option>
                    <?php
}
}
$_smarty_tpl->smarty->ext->_foreach->restore($_smarty_tpl, 1);
?>

				</select>
                <button class="calsubmit" name="calType" value="juvcal" title="Submit Button">View</button>
		    </td>
		    <td id="magsel">
		    	<span class="h3"></span>
				<select style="min-width: 15em" class="divsel"  name="magch" id="magch">
                    <?php
$_from = $_smarty_tpl->smarty->ext->_foreach->init($_smarty_tpl, $_smarty_tpl->tpl_vars['calMagistrates']->value, 'm', false, 'key');
if ($_from !== null) {
foreach ($_from as $_smarty_tpl->tpl_vars['key']->value => $_smarty_tpl->tpl_vars['m']->value) {
?>
                    	<option value="<?php echo $_smarty_tpl->tpl_vars['key']->value;?>
"><?php echo $_smarty_tpl->tpl_vars['m']->value;?>
</option>
                    <?php
}
}
$_smarty_tpl->smarty->ext->_foreach->restore($_smarty_tpl, 1);
?>

				</select>
                <button class="calsubmit" name="calType" value="magcal">View</button>
                <input type="hidden" name="magcal" id="magcal" value=""/>
		    </td>
		</tr>
		<tr>
			<td>
				<div class="h2">
					Probate
				</div>
			</td>
			<td>
				<div class="h2">
					First Appearance
				</div>
			</td>
			<td>
				<div class="h2">
					Civil Traffic
				</div>
			</td>
		</tr>
		<tr>
			<td id="prosel">
		    	<span class="h3"></span>
				<select style="min-width: 15em" class="divsel"  name="prodiv" id="prodiv" title="Select Probate Division">
                    <option value="" title="Select a Division">Select a Division</option>
                    <?php
$_from = $_smarty_tpl->smarty->ext->_foreach->init($_smarty_tpl, $_smarty_tpl->tpl_vars['prodivs']->value, 'info', false, 'div');
if ($_from !== null) {
foreach ($_from as $_smarty_tpl->tpl_vars['div']->value => $_smarty_tpl->tpl_vars['info']->value) {
?>
                    <option value="<?php echo $_smarty_tpl->tpl_vars['div']->value;?>
" title="Division <?php echo $_smarty_tpl->tpl_vars['div']->value;?>
"><?php echo $_smarty_tpl->tpl_vars['div']->value;?>
 (<?php echo $_smarty_tpl->tpl_vars['info']->value['courtType'];?>
)</option>
                    <?php
}
}
$_smarty_tpl->smarty->ext->_foreach->restore($_smarty_tpl, 1);
?>

				</select>
                <button class="calsubmit" name="calType" value="procal" title="Submit Button">View</button>
		    </td>
			<td id="fapsel">
		    	<span class="h3"></span>
				<select title="Select Courthouse for First Appearance" style="min-width: 15em" class="divsel"  name="fapch" id="fapch">
					<option value="" title="Select a Location">Select a Location</option>
                    <?php
$_from = $_smarty_tpl->smarty->ext->_foreach->init($_smarty_tpl, $_smarty_tpl->tpl_vars['faps']->value, 'info');
if ($_from !== null) {
foreach ($_from as $_smarty_tpl->tpl_vars['info']->value) {
?>
                    <option title="<?php echo $_smarty_tpl->tpl_vars['info']->value['courthouse_nickname'];?>
 Courthouse" value="<?php echo $_smarty_tpl->tpl_vars['info']->value['courthouse_id'];?>
"><?php echo $_smarty_tpl->tpl_vars['info']->value['courthouse_nickname'];?>
</option>
                    <?php
}
}
$_smarty_tpl->smarty->ext->_foreach->restore($_smarty_tpl, 1);
?>

				</select>
                <button class="calsubmit" name="calType" value="fapcal" title="Submit Button">View</button>
		    </td>
			<td>
				<span class="h3"></span>
				<select title="Select a Traffic Court Type" style="min-width: 15em" class="divsel" name="civ_traffic" id="civ_traffic">
					<option value="Civil Traffic" title="Select a Traffic Court Type">Civil Traffic</option>
				</select>
                <button type="button" class="reportView divRpt" title="Submit Button" onclick="go_civ_traffic();">View</button>
			</td>
		</tr>
		<tr>
			<td>
				<div class="h2">
					Mediation
				</div>
			</td>
			<td>
				<div class="h2">
					Ex-Parte
				</div>
			</td>
			<td>
				<div class="h2">
					Mental Health
				</div>
			</td>
		</tr>
		<tr>
			<td id="medsel">
		    	<span class="h3"></span>
				<select style="min-width: 15em" class="divsel" name="medch" id="medch">
					<option value="all">All Mediators</option>
                    <?php
$_from = $_smarty_tpl->smarty->ext->_foreach->init($_smarty_tpl, $_smarty_tpl->tpl_vars['mediators']->value, 'm', false, 'key');
if ($_from !== null) {
foreach ($_from as $_smarty_tpl->tpl_vars['key']->value => $_smarty_tpl->tpl_vars['m']->value) {
?>
                    	<option value="<?php echo $_smarty_tpl->tpl_vars['m']->value['mediator_id'];?>
"><?php echo $_smarty_tpl->tpl_vars['m']->value['name'];?>
</option>
                    <?php
}
}
$_smarty_tpl->smarty->ext->_foreach->restore($_smarty_tpl, 1);
?>

				</select>
                <button class="calsubmit" name="calType" value="medcal">View</button>
                <input type="hidden" name="medcal" id="medcal" value=""/>
		    </td>
		    <td>
				<span class="h3"></span>
				<select title="Select an Ex-Parte Division" style="min-width: 15em" class="divsel" name="ex_parte" id="ex_parte">
					<option value="all">All Divisions</option>
                    <?php
$_from = $_smarty_tpl->smarty->ext->_foreach->init($_smarty_tpl, $_smarty_tpl->tpl_vars['expdivs']->value, 'info', false, 'div');
if ($_from !== null) {
foreach ($_from as $_smarty_tpl->tpl_vars['div']->value => $_smarty_tpl->tpl_vars['info']->value) {
?>
                    	<option value="<?php echo $_smarty_tpl->tpl_vars['div']->value;?>
" title="Division <?php echo $_smarty_tpl->tpl_vars['div']->value;?>
"><?php echo $_smarty_tpl->tpl_vars['div']->value;?>
 (<?php echo $_smarty_tpl->tpl_vars['info']->value['courtType'];?>
)</option>
                    <?php
}
}
$_smarty_tpl->smarty->ext->_foreach->restore($_smarty_tpl, 1);
?>

				</select>
                <button class="calsubmit" name="calType" value="expcal">View</button>
                <input type="hidden" name="expcal" id="expcal" value=""/>
			</td>
			<td>
				<span class="h3"></span>
				<select title="Select a Mental Health Calendar" style="min-width: 15em" class="divsel" name="mental_health" id="mental_health">
					<option value="all">All Mental Health Calendars</option>
                    <?php
$_from = $_smarty_tpl->smarty->ext->_foreach->init($_smarty_tpl, $_smarty_tpl->tpl_vars['mh_divs']->value, 'div_name', false, 'div');
if ($_from !== null) {
foreach ($_from as $_smarty_tpl->tpl_vars['div']->value => $_smarty_tpl->tpl_vars['div_name']->value) {
?>
                    	<option value="<?php echo $_smarty_tpl->tpl_vars['div']->value;?>
" title="<?php echo $_smarty_tpl->tpl_vars['div_name']->value;?>
"><?php echo $_smarty_tpl->tpl_vars['div_name']->value;?>
</option>
                    <?php
}
}
$_smarty_tpl->smarty->ext->_foreach->restore($_smarty_tpl, 1);
?>

				</select>
                <button class="calsubmit" name="calType" value="mhcal">View</button>
                <input type="hidden" name="mhcal" id="mhcal" value=""/>
			</td>
		</tr>
	</table>
	<br/><br/><?php }
}
