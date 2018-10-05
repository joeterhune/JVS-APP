<script src="/javascript/workflow.js?2.5" type="text/javascript"></script>
<script type="text/javascript">
    
    $(document).ready(function () {
        
        {if $isOrder}
	       	$(document).on('click','#step1',function() {
				window.location = '/orders/igo.php?ucn={$ucn}&docid={$docid}';
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
				window.location = '/cgi-bin/eservice/eService.cgi?fromWF=1&efileCheck=1&clerkFile=1&ucn={$ucn}&docid={$docid}';
			});
		{/if}
		
		$(document).on('click','#step9',function() {
			window.location = '/orders/transfer.php?ucn={$ucn}&docid={$docid}';
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
	<div class="WFMenuItem">
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
	{if !$isOrder || (!empty($pdf_file) && (!empty($signature_html) || !empty($signature_img)))}
		<div class="WFMenuItem">
	{else}
		<div class="WFMenuItem inactiveWFMenuItem">
	{/if}
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
		<div id="activeWFMenuItem">
			<div class="bigNumber">{$count}</div> <div class="wfMenuItemLink"><a id="step10">Reject</a></div>
		</div>
	{/if}
</div>
<br/>
<div style="padding-top:1%; padding-left:2%;">
	<div id="wf_reject_dialog" title="Reject Document">
		<table>
			<tr>
	    		<td><label for="wf_reject_comments">Reason for Rejection</label></td>
	    	</tr>
	    	<tr>
	        	<td><textarea rows="6" cols="80" id="wf_reject_comments" name="wf_reject_comments"></textarea></td>
	        </tr>
		    <tr>
		     	<td style="text-align:right"><button class="rejectBtnOW">Reject</button></td>
		    </tr>
	        <input type="hidden" name="wf_reject_id" id="wf_reject_id" value="{$docid}"/>
	        <input type="hidden" name="wf_reject_creator" id="wf_reject_creator" value="{$creator}"/>
	        <input type="hidden" name="wf_reject_queue" id="wf_reject_queue" value="{$current_queue}"/>
	        <input type="hidden" name="wf_reject_ucn" id="wf_reject_ucn" value="{$ucn}"/>
        </table>
    </div>
</div>