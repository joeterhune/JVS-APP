{if $refresh == "0"}
	<script type="text/javascript" src="/javascript/jquery/jquery.form.js"></script>
	<script type="text/javascript">
	    $(document).ready(function () {
	    	
	    	{if $isOrder}
		    	$(document).on('click','#step1',function() {
					$('#dialogSpan').html("By clicking OK, you will be returned to the form selection screen.  Your current document will be completely regenerated and any text changes you have made will be overwritten.");
					$('#dialogDiv').dialog({
						resizable: false,
						minheight: 150,
						width: 500,
						modal: true,
						title: 'Order Regeneration',
						buttons: {
						   	"OK": function() {
						       	$(this).dialog( "close" );
						       	window.location = '/orders/igo.php?ucn={$ucn}&docid={$docid}';
						        return false;
						    },
						    "Cancel": function() {
						       	$(this).dialog( "close" );
						        return false;
						    }
						}
					});
						                
					return false;
									
				});
			{/if}
			
			$(document).on('click','#step2',function() {
				window.location = '/orders/preview.php?ucn={$ucn}&docid={$docid}';
			});
			
			$(document).on('click','#step3',function() {
				window.location = '/workflow/parties.php?ucn={$ucn}&docid={$docid}';
			});
			
			$(document).on('click','#step4',function() {
				window.location = '/orders/preview.php?sign=Y&ucn={$ucn}&docid={$docid}';
			});
			
			$(document).on('click','#step5',function() {
				window.location = '/orders/genpdf.php?ucn={$ucn}&docid={$docid}';
			});
			
			$(document).on('click','#step6',function() {
				window.location = '/workflow/attachments.php?ucn={$ucn}&docid={$docid}';
			});
			
			$(document).on('click','#step7',function() {
				window.location = '/workflow/envelopes.php?ucn={$ucn}&docid={$docid}';
			});
			
			{if !empty($pdf_file) && (!empty($signature_html) || !empty($signature_img))}
				$(document).on('click','#step8',function() {
					var pane = $(".orderDiv");
		        	SaveToWorkflow(pane);
		        	if($("#docid").val() != ''){
		        		var doc_id = $("#docid").val();
		        	}
		        	else{
		        		var doc_id = "{$docid}";
		        	}
		        	
		        	var case_num = "{$ucn}";
		        	var postData = { ucn: case_num, docid: doc_id };
				    $.ajax({
				        url: "/orders/genpdf.php",
				        type: 'POST',
				        data: postData,
				        success: function (data) {
				            window.location = '/cgi-bin/eservice/eService.cgi?fromWF=1&efileCheck=1&clerkFile=1&ucn={$ucn}&docid=' + doc_id;
				        }
				    });
				});
			{/if}
			
			$(document).on('click','#step9',function() {
				window.location = '/orders/transfer.php?ucn={$ucn}&docid={$docid}';
			});
			
			{if !$isOrder}
				$(document).on('click','#step10',function() {
					window.location = '/orders/reject.php?ucn={$ucn}&docid={$docid}';
				});
			{/if}
			
	        $('input,textarea').placeholder();
	        
	        var options = {
	            success: OrderRegenOrder
	        }
	        
	        $(document).on('click','.saveParties', function () {
	            {literal}
		            var formDiv = $(this);
		            var pane = $(this).closest('.orderDiv');
		            var cclist=$(pane).find(".wf_parties_form").serialize();
		            var casestyle = $(pane).find('.wfcasestyle').val();
		            var postData = {ucn: $(pane).find('.ucn').val(), cclist: cclist, wfcasestyle: casestyle};
					
		           $(".wf_parties_form").ajaxSubmit({
		                success: function(data) {
		                	$('#dialogSpan').html("Your changes have been saved.");
		                	$('#dialogDiv').dialog({
						    	resizable: false,
						        minheight: 150,
						        width: 500,
						        modal: true,
						        title: 'Parties Saved',
						        buttons: {
						        	"OK": function() {
						            	$(this).dialog( "close" );
						            	if($("#changeToExternal").val() == "1"){
						            		$(".wfpartysrc").val("clerk");
						            		$(".wfpartysrc").css("background-color", "#fffffe");
						            	}
						            	else{
						            		$(".wfpartysrc").val("previousorder");
						            		$(".wfpartysrc").css("background-color", "#ff9999");
						            	}
						                return false;
						            }
						        }
							});
		                }
		            });
	            {/literal}
	            return false;
	        });
	        
	        $(document).on('click','.cccheck', function () {
	            return true;
	        });
	        
	        $(document).on('change', '.wfpartysrc', function () {
	            OrderPartySourceChange();
	        });
	        
	        $(document).on("click", ".addParty", function(e){
				var count = Math.ceil(($('#partiesTable tr').length - 2) / 2);
				var newRow = "<tr>";
				newRow += "<td>";
				newRow += '<input class="group'+count+' cccheck" name="cclist_'+count+'_check" type="checkbox" value="1" checked/>';
				newRow += "</td>";
				newRow += "<td>";
				newRow += '<span style="font-weight: bold">Name</span>';
				newRow += "</td>";
				newRow += "<td>";
				newRow += '<input type="text" class="group'+count+'" name="cclist_'+count+'_FullName" style="width:200px" />';
				newRow += "</td>";
				newRow += "<td>";
				newRow += '<span style="font-weight: bold">E-mail</span>';
				newRow += "</td>";
				newRow += "<td>";
				newRow += '<input type="text" class="group'+count+' svcList" style="width:300px" data-group="'+count+'"';
				newRow += ' name="cclist_'+count+'_ServiceList"'; 
				newRow += ' placeholder="No email address on file"/>';
				newRow += '<input type="hidden" class="group'+count+'" name="cclist_'+count+'_ProSe" value="1"/>';
				newRow += "</td>";
				newRow += "</tr>";
				newRow += "<tr>";
				newRow += "<td>&nbsp;</td>";
				newRow += "<td>&nbsp;</td>";
				newRow += "<td>&nbsp;</td>";
				newRow += '<td style="vertical-align: top">';
				newRow += '<span style="font-weight: bold">Address</span>';
				newRow += "</td>";
				newRow += "<td>";
				newRow += '<textarea rows="4" class="group'+count+'" style="width:300px" name="cclist_'+count+'_FullAddress" placeholder="No mailing address on file" name="cclist_'+count+'_3"></textarea>';
				newRow += '<input type="hidden" name="cclist_'+count+'_list" value="Parties">';
				newRow += '<input type="hidden" name="cclist_'+count+'_custom" value="1">';
				newRow += "</td>";
				newRow += "</tr>";
				$(newRow).insertBefore($("#addLink"));
			});
	    });
	</script>
	
	<div id="orderMenu">
		{if $isOrder}
			{$count = 1}
			<div class="WFMenuItem biggerWFMenuItem">
				<div class="bigNumber">{$count}</div> <div class="wfMenuItemLink"><a id="step1">Select Template</a></div>
			</div>
			{$count = $count + 1}
		{else}
			{$count = 1}
		{/if}
		<div class="WFMenuItem biggerWFMenuItem">
			<div class="bigNumber">{$count}</div> <div class="wfMenuItemLink"><a id="step2">Edit Document</a></div>
		</div>
		{$count = $count + 1}
		<div id="activeWFMenuItem">
			<div class="bigNumber">{$count}</div> <div class="wfMenuItemLink"><a id="step3">Verify Parties</a></div>
		</div>
		{$count = $count + 1}
		<div class="WFMenuItem">
			<div class="bigNumber">{$count}</div> <div class="wfMenuItemLink"><a id="step4">Sign</a></div>
		</div>
		{$count = $count + 1}
		<div class="WFMenuItem">
			<div class="bigNumber">{$count}</div> <div class="wfMenuItemLink"><a id="step5">Preview PDF</a></div>
		</div>
		{$count = $count + 1}
		<div class="WFMenuItem">
			<div class="bigNumber">{$count}</div> <div class="wfMenuItemLink"><a id="step6">Attachments</a></div>
		</div>
		{$count = $count + 1}
		<div class="WFMenuItem">
			<div class="bigNumber">{$count}</div> <div class="wfMenuItemLink"><a id="step7">Envelopes</a></div>
		</div>
		{$count = $count + 1}
		{if !empty($pdf_file) && (!empty($signature_html) || !empty($signature_img))}
		<div class="WFMenuItem">
		{else}
			<div class="WFMenuItem inactiveWFMenuItem">
		{/if}
			<div class="bigNumber">{$count}</div> <div class="wfMenuItemLink"><a id="step8">E-File</a></div>
		</div>
		{$count = $count + 1}
		<div class="WFMenuItem">
			<div class="bigNumber">{$count}</div> <div class="wfMenuItemLink"><a id="step9">Transfer</a></div>
		</div>
		{if !$isOrder}
			{$count = $count + 1}
			<div class="WFMenuItem">
				<div class="bigNumber">{$count}</div> <div class="wfMenuItemLink"><a id="step10">Reject</a></div>
			</div>
		{/if}
	</div>
{/if}
<div style="padding:2%" id="partyPeople">
	<div class="col-md-8">
	Parties for <b>{$ucn}</b>
	<p>
	    Source:
	    <select class="wfpartysrc" name="wfpartysrc" {if $lastdata == "selected"}style="background-color:#ff9999"{/if}>
	        <option value="clerk" {$clerkdata}>External Data</option>
	        <option value="previousorder" {$lastdata}>Saved Data</option>
	    </select>
	</p>
	
	<form class="wf_parties_form " method="post" onsubmit="return false;" action="/workflow/saveparties.php">
	    <input type="hidden" name="ucn" value="{$ucn}"/>
	    <table id="partiesTable">
	    	<tr>
	        	<td colspan="5">
	        		<button type="button" class="btn btn-primary saveParties pull-right"><i class="fa fa-floppy-o"></i> Save Party Changes</button>
	        	</td>
	        </tr>
	        <tr>
	        	<td colspan="5">&nbsp;</td>
	        </tr>
	        <tr>
	            <td colspan="2">
	                Case Caption:
	            </td>
	            <td colspan="3">
	                <textarea class="wfcasestyle" name="wfcasestyle" rows="12" cols="80">{$caption}</textarea>
	            </td>
	        </tr>
			{if (isset($cclist.Attorneys) && (is_array($cclist.Attorneys)))}
			{$attycount = $cclist.Attorneys|@count}
	        {for $i=0; $i < $attycount; $i++}
				{$attorney = $cclist.Attorneys.$i}
				{if $attorney.check && $attorney.check == '1'}
					{$ck = "checked"}
				{else}
					{$ck = ""}
				{/if}
				<tr>
					<td>
						<input class="group{$i} cccheck" name="cclist_{$i}_check" type="checkbox" value="1" {$ck}/>
					</td>
					<td>
						<span style="font-weight: bold">Name</span>
					</td>
					<td>
						<input type="text" class="group{$i}" name="cclist_{$i}_FullName" style="width:200px" value="{$attorney.FullName}"/>
					</td>
					<td>
						<span style="font-weight: bold">E-mail</span>
					</td>
					<td>
						<input type="text" class="group{$i} svcList" style="width:300px" name="cclist_{$i}_ServiceList" data-group="{$i}"
							   value="{'; '|implode:$attorney.ServiceList}">
					</td>
				</tr>
				<tr>
					<td>&nbsp;</td>
					<td>&nbsp;</td>
					<td>&nbsp;</td>
					<td style="vertical-align: top">
						<span style="font-weight: bold">Address</span>
					</td>
					<td>
						<textarea rows="4" class="group{$varindex}" style="width:300px" name="cclist_{$i}_FullAddress">{$attorney.FullAddress}</textarea>
						<input type="hidden" name="cclist_{$i}_list" value="Attorneys">
					</td>
				</tr>
	        
	        {/for}
			{else}
			{$attycount = 0}
			{/if}
	        
	        {for $i = 0; $i < ($cclist.Parties|@count); $i++}
		        {$party = $cclist.Parties.$i}
		        {if $party.check && $party.check == '1'}
					{$ck = "checked"}
				{else}
					{$ck = ""}
				{/if}
			        {$varindex = $i + $attycount}
			        <tr>
			            <td>
			                <input class="group{$varindex} cccheck" name="cclist_{$varindex}_check" type="checkbox" value="1" {$ck}/>
			            </td>
			            <td>
			                <span style="font-weight: bold">Name</span>
			            </td>
			            <td>
			                <input type="text" class="group{$varindex}" name="cclist_{$varindex}_FullName" style="width:200px" value="{$party.FullName}"/>
			            </td>
			            <td>
			                <span style="font-weight: bold">E-mail</span>
			            </td>
			            <td>
			            	{if !empty($party.ServiceList)}
			            		{$p_sl = '; '|implode:$party.ServiceList}
			            	{else}
			            		{$p_sl = ""}
			            	{/if}
			                <input type="text" class="group{$varindex} svcList" style="width:300px" data-group="{$varindex}"
			                       name="cclist_{$varindex}_ServiceList" value="{$p_sl}"
			                       placeholder="No email address on file"/>
			                <input type="hidden" class="group{$varindex}" name="cclist_{$varindex}_ProSe" value="{$party.ProSe}"/>
			            </td>
			        </tr>
			        <tr>
			            <td>&nbsp;</td>
			            <td>&nbsp;</td>
			            <td>&nbsp;</td>
			            <td style="vertical-align: top">
			                <span style="font-weight: bold">Address</span>
			            </td>
			            <td>
			                <textarea rows="4" class="group{$varindex}" style="width:300px" name="cclist_{$varindex}_FullAddress" placeholder="No mailing address on file" name="cclist_{$i}_3">{$party.FullAddress}</textarea>
			                <input type="hidden" name="cclist_{$varindex}_list" value="Parties">
			            </td>
			        </tr>
	        {/for}
	        <tr>
	        	<td colspan="5">&nbsp;</td>
	        </tr>
	        <tr id="addLink">
	        	<td colspan="5" style="text-align:right">
	        		<a class="addParty" href="#\" style="font-size:1.5em">Add a New Recipient</a>
	        	</td>
	        </tr>
	        <tr>
	        	<td colspan="5">&nbsp;</td>
	        </tr>
	        <tr>
	        	<td colspan="5">
	        		<button type="button" class="btn btn-primary saveParties pull-right"><i class="fa fa-floppy-o"></i> Save Party Changes</button>
	        	</td>
	        </tr>
	    </table>
		<input type="hidden" name="changeToExternal" id="changeToExternal" value="{$clerkOnly}"/>
	</form>
	</div>
	<br class="clear"/><br class="clear"/>
	<input type="hidden" class="ucn" id="ucn" name="ucn" value='{$ucn}'/>
	<input type="hidden" class="pt_needsnail" name="pt_needsnail" value="{$needsnail}"/>
	<input type="hidden" class="pt_needemail" name="pt_needemail" value="{$needemail}"/>
	<input type="hidden" class="pt_emails" name="pt_emails" value="{$emails}"/>
	<input type="hidden" name="isOrder" id="isOrder" value="{$isOrder}"/>
	
	<input type="hidden" class="cclistjson" name="cclist" value="{$ccjson}"/>
	{if $isorder}<input type="hidden" class="wfcasestyle" name="wfcasestyle" value="{$caption}"/>{/if}
</div>