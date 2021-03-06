 <script type="text/javascript">

	var ucn = '{$ucn}';
	var docid = '{$docid}';
	var formid = '{$formid}';
	{if isset($formData) && !empty($formData)}
		var formData = {$formData}; 
	{else}
		var formData = "";
	{/if}
	
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
	
	function OrderDisplayFields(formsel) {
		{literal}
        	$.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait </h1>', fadeIn: 0});
        {/literal}
        
	    if (formsel != "") {
	        var t = new Date().getTime();
	        $("#formdiv").load("/orders/orderfields.php?ucn="+ucn+"&formid="+formsel+'&docid='+docid+'&t='+t, OrderHandleFormLoading);
	        $("#bulkGenerate").show();
	    } else {
	        $("#formdiv").html('');
	        $("#bulkGenerate").hide();
	        $.unblockUI();
	    }
	    
	    if(formsel != ""){
			$("#step2").attr('class', 'editDocument');
			$("#step2").parent().parent().removeClass('inactiveWFMenuItem');
		}
		else{
			$("#step2").attr('class', '');
			$("#step2").parent().parent().addClass('inactiveWFMenuItem');
		}
	}
	
	function OrderHandleFormLoading() {
	   
	   if(formData){
	    	$.each(formData, function( key, value ) {
	    		if(key != "docket_line_text" && (key != "form_name") && (key != "form_id")){
		    		if($('input[name="'+key+'"]').length) {
		    			if($('input[name="'+key+'"]').is(':checkbox')){
		    				if(value == 1){
		    					$('input[name="'+key+'"]').prop('checked', true);
		    				}
		    			}
		    			else{
		    				$('input[name="'+key+'"]').val(value);
		    			}
		    		}
	    		}
	    	});
	    }
	    
	    $.unblockUI();
	}
	
	$(document).ready(function (){
	
		$("#form_id_search").autocomplete({
	    	source: function(request, response) {
	        	$.ajax({
	          		url: "getForms.php",
	          		dataType: "json",
	          		data: {
	            		term: request.term
	          		},
	          		success: function(data) {
	            		response(data);
	          		}
	        	} );
	      	},
	      	minLength: 0,
	      	select: function(event, ui) {
	      		$("#formid").val(ui.item.id);
	      		$("#form_id_select").val("");
	        	OrderDisplayFields(ui.item.id);
	      	}
	    }).focus(function() {
	    	if($(this).val() == ""){
				$(this).autocomplete("search", "");
			}
		});
	
		$(document).keypress(function(e) {
			if(!$("textarea").is(":focus")){
			    if(e.which == 13) {
			        $("#formdiv").append('<input type="hidden" name="fromTemplate" id="fromTemplate" value="1"/>');
					$("#formdiv").submit();
			    }
		    }
		});
	
	    $("#form_id_select").change(function(e) {
	    	OrderDisplayFields($("#form_id_select").val());
	    	$("#form_id_search").val("");
	    	$("#formid").val($("#form_id_select").val());
	    });
	    
	    $("#doBulkGenerate").change(function(e) {
	    	if($(this).prop("checked") == true){
	    		var cnHTML = "<strong>Case Number(s):</strong> (Please enter one case number per line and click outside the box to continue.)</strong><br/><br/>";
	    		cnHTML += "<div style=\"float:left; width:50%\"><textarea name=\"bulkGenerateCases\" id=\"bulkGenerateCases\" rows=\"10\" cols=\"35\">" + $("#bulkGenerateCasesHidden").val() + "</textarea></div>";
	    		cnHTML += "<div style=\"float:left; width:50%; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;\" id=\"bulkStyles\">" + $("#bulkStylesHidden").val() + "</div>";
	    		
		    	$('#dialogSpan').html(cnHTML);
		        $('#dialogDiv').dialog({
		            resizable: false,
		            minheight: 150,
		            width: 'auto',
		            modal: true,
		            title: 'Enter Case Number(s)',
		            buttons: {
		                "OK": function() {
		                    $(this).dialog( "close" );
		                    
		                    var text = $("#bulkGenerateCases").val();   
							var lines = text.split(/\r|\r\n|\n/);
							var count = lines.length;
							
							if(!text || (text == "")){
								count = 0;
							}
							
		                    if(count > 0){
		                    	var countText = "(" + count + " cases entered)";
		                    	$("#bulkCaseCount").html(countText);
		                    }
		                    else{
		                    	$("#bulkCaseCount").html("");
		                    }
		                    return false;
		                },
		                "Cancel": function() {
		                    $(this).dialog( "close" );
		                    return false;
		                }
		            }
		        });
			}
			else{
				$("#bulkCaseCount").html("");
			}
	    });
	    
	    $(document).on('change','#bulkGenerateCases', function () {
	    	{literal}
	    		$.blockUI.defaults.baseZ = 4000;
				$.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait </h1>', fadeIn: 0});
			{/literal}
			
	    	var bulk_cases = $("#bulkGenerateCases").val();
	    	if(!bulk_cases || (bulk_cases == "")){
				$("#bulkGenerateCasesHidden").val("");
				$("#bulkStylesHidden").val("");
				$("#bulkStyles").html("");
	    		$.unblockUI();
				return false;
			}
	    	
	    	var caseArr = bulk_cases.split("\n");
	    	
	    	var cleanCaseArr = new Array();
	    	var styleArr = new Array();
	    	var casesLength = caseArr.length;
	    	
	    	var postData = { cases : bulk_cases };
	    	$.ajax({
				url: '/workflow/checkcase_bulk.php',
				type: "POST",
				data : postData,
				success: function(data, textStatus, xhr) {
					if(data.status == "Success"){
						var cleanCaseArr = data.CaseList;
						var styleArr = data.StyleList;
						
						var newCaseList = cleanCaseArr.join("\n");
				    	var styleList = styleArr.join("<br/>");
				    	$("#bulkGenerateCases").val(newCaseList);
				    	$("#bulkGenerateCasesHidden").val(newCaseList);
				    	$("#bulkStylesHidden").val(styleList);
				    	$("#bulkStyles").html(styleList);
				    	$.unblockUI();
					}
					else{
						$.unblockUI();
						showDialog("Error", "No case numbers were found.");
						$("#doBulkGenerate").prop('checked', false);
					}
				}
			});
			
			return false;
		});
		
		$(document).on('click','.editDocument',function() {
	        $("#formdiv").append('<input type="hidden" name="fromTemplate" id="fromTemplate" value="1"/>');
	        
	        if(($("#doBulkGenerate").prop("checked") == true) && $("#bulkGenerateCasesHidden").val()){
	        	$("#formdiv").append('<input type="hidden" name="bulkGenerateCases" id="bulkGenerateCases" value="' + $("#bulkGenerateCasesHidden").val() + '"/>');
	        	var caseDisplay = $("#bulkGenerateCasesHidden").val();
	        	caseDisplay = caseDisplay.replace(/\n/g, "<br/>");
	        	
	        	$('#dialogSpan').html("This order will automatically generate and will be placed into your queue for the following additional cases:<br/><br/>" + caseDisplay);
		        $('#dialogDiv').dialog({
		            resizable: false,
		            minheight: 150,
		            width: 500,
		            modal: true,
		            title: 'Multiple Orders',
		            buttons: {
		                "OK": function() {
		                    $(this).dialog( "close" );
		                    $("#formdiv").submit();
		                    return false;
		                },
		                "Cancel": function() {
		                    $(this).dialog( "close" );
		                    return false;
		                }
		            }
		        });
	        }
	        else{
	        	$("#formdiv").submit();
	        }
	        
			
		});
		
		{if !empty($formid)}
			$("#form_id_select").val("{$formid}");
			$("#form_id_select").trigger("change");
		{/if}
		
		$('#formdiv').submit(function() {
		    {literal}
				$.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait </h1>', fadeIn: 0});
			{/literal}
		    return true; 
		});
	});
	
</script>
<style type="text/css">
 	.ui-widget-content{
    	border: 5px solid black;
        color: #222222;
        background-color: #FFFFFE;
    }
 	.ui-menu .ui-menu-item a{
    	display: block;
        padding: 3px 3px 3px 3px;
        text-decoration: none;
        cursor: pointer;
        background-color: #FFFFFE;
        border: 1px solid #eceff1;
        border-radius: 0.25rem;
    }
    .ui-state-active a:hover,
	.ui-state-active a:link,
	.ui-state-active a:visited,
	.ui-menu .ui-menu-item a:hover{
		background-color:#428bca;
	}
	.ui-datepicker-title{
		color:#000000;
	}
</style>
<div id="orderMenu">
	{$count = 1}
	<div id="activeWFMenuItem" class="biggerWFMenuItem">
		<div class="bigNumber">{$count}</div> <div class="wfMenuItemLink"><a id="step1">Select Template</a></div>
	</div>
	{$count = $count + 1}
	<div class="WFMenuItem inactiveWFMenuItem biggerWFMenuItem">
		<div class="bigNumber">{$count}</div> <div class="wfMenuItemLink"><a id="step2">Edit Document</a></div>
	</div>
	{$count = $count + 1}
	<div class="WFMenuItem inactiveWFMenuItem">
		<div class="bigNumber">{$count}</div> <div class="wfMenuItemLink"><a id="step3">Verify Parties</a></div>
	</div>
	{$count = $count + 1}
	<div class="WFMenuItem inactiveWFMenuItem">
		<div class="bigNumber">{$count}</div> <div class="wfMenuItemLink"><a id="step4">Sign</a></div>
	</div>
	{$count = $count + 1}
	<div class="WFMenuItem inactiveWFMenuItem">
		<div class="bigNumber">{$count}</div> <div class="wfMenuItemLink"><a id="step5">Preview PDF</a></div>
	</div>
	{$count = $count + 1}
	<div class="WFMenuItem inactiveWFMenuItem">
		<div class="bigNumber">{$count}</div> <div class="wfMenuItemLink"><a id="step6">Attachments</a></div>
	</div>
	{$count = $count + 1}
	<div class="WFMenuItem inactiveWFMenuItem">
		<div class="bigNumber">{$count}</div> <div class="wfMenuItemLink"><a id="step7">Envelopes</a></div>
	</div>
	{$count = $count + 1}
	<div class="WFMenuItem inactiveWFMenuItem">
		<div class="bigNumber">{$count}</div> <div class="wfMenuItemLink"><a id="step8">E-File</a></div>
	</div>
	{$count = $count + 1}
	<div class="WFMenuItem inactiveWFMenuItem">
		<div class="bigNumber">{$count}</div> <div class="wfMenuItemLink"><a id="step9">Transfer</a></div>
	</div>
</div>

<div style="padding:2%">
	<div class="col-md-12">
		<div class="row">
	    	Order for <span style="font-weight: bold">{$ucn}</span>&nbsp;
			Division: <span style="font-weight: bold">{$DivisionID}</span>
		</div>
	    <div class="row" style="margin-bottom:15px;">
		    <div class="input-group">
		        {if !isset($formid)}
		        	{$formid = -999}
		        {/if}
		        <br/>
		        <p>
		        	Forms are organized by relevant court types based on information submitted by the form's requestor at the time of form creation.
           			If a selected form has not been assigned to this court type, some fields may not populate correctly.
		        </p>
		        <br/>
		        <table>
					<tr>	
						<td>Court Type/Division Forms:</td>
						<td>
							{if $forms|@count > 0}
					        	{$single = ($forms|@count == 1)}
						        <select class="formid" id="form_id_select">
						            {if !$single}
						            <option value="" selected="selected">
						                Select
						            </option>
						            {/if}
						            {foreach $forms as $form}
										{assign var="div_checks" value=","|explode:$form.case_div}
											{foreach from=$div_checks item=div_check}
										
												{if   $div_check == "" ||
													( (strpos($div_check, '!')===false ) && $div_check == $DivisionID ) ||
													( (strpos($div_check, '!')!==false ) && ($div_check != $DivCheck ) ) }
													<option value="{$form.form_id}" {if ($single) || ($form.form_id == $formid)}selected="selected"{/if}>
														{$form.form_name}
													</option>
												{/if}
											{/foreach}
						            {/foreach}
						        </select>
					        {else}
					        	<span style="color: red">No forms available for this case type.</span>
					        {/if}
				        </td>
					</tr>
					<tr>
						<td colspan="2">or</td>
					</tr>
					<tr>
			        	<td>Search All Forms:</td>
						<td><input id="form_id_search" name="form_id_search" size="50"/></td>
					</tr>
					<tr id="bulkGenerate" style="display:none">
						<td colspan="2"><input type="checkbox" name="doBulkGenerate" id="doBulkGenerate" /> Generate this order for multiple cases <span id="bulkCaseCount" style="color:red"></span></td>
					</tr>
		        </table>
		        <hr/>
		    </div>
		    <input type="hidden" id="formid" name="formid"/>
		    <input type="hidden" id="bulkGenerateCasesHidden" name="bulkGenerateCasesHidden"/>
		    <input type="hidden" id="bulkStylesHidden" name="bulkStylesHidden"/>
		</div>
	    <div>
			<div style="max-height:550px; height:80%; overflow-y:auto; margin-left:-2%;">
				<div class="col-md-12">
					<form class="formdiv form-horizontal" autocomplete="on" id="formdiv" method="post" action="preview.php?ucn={$ucn}&docid={$docid}">
					
					</form>
				</div>	
			</div>
		</div>
		<!--<div class="row" style="margin-top:20px; display:none">
			<button data-type="preview" class="btn btn-success btn-xl xmlbutton previewbutton pull-right" type="submit">Edit Document</button>
		</div>-->
	</div>
</div>
