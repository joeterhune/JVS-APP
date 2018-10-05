<script src="/javascript/ckeditor/ckeditor.js"></script>
<script type="text/javascript">
	// do this before the first CKEDITOR.replace( ... )
	CKEDITOR.timestamp = +new Date;
</script>
<script src="/javascript/ckeditor/adapters/jquery.js"></script>
<script type="text/javascript">
    
    $(document).ready(function () {
        var pane = $('.orderDiv');
        
        var previewDiv = $(pane).find('.previewdiv');
        var cfheight = $(previewDiv).height();
        
        var cvRow = $('#orderMenu');
        var pos = $(cvRow).offset();
        // The top of the editor should be 2* (the height of the button row + 5) offset from the top of the button row
        var editTop = pos.top + (2 * ($(cvRow).height() + 5));
        var winHt = $(window).height();
        PDFIFRAMEHEIGHT = winHt - editTop - 50 + "px";
        
        $('.pdfmailiframe').attr('src', '{$file}');
        $('.pdfmailiframe').css('width', '100%');
        $('.pdfmailiframe').css('height', PDFIFRAMEHEIGHT);
       
       	{if $editable}
	       	{if $isOrder}
		       	$(document).on('click','#step1',function() {
					window.location = '/orders/igo.php?ucn={$ucn}&docid={$docid}';
				});
			{/if}
		{/if}
			
		$(document).on('click','#step2',function() {
			window.location = '/orders/preview.php?ucn={$ucn}&docid={$docid}';
		});
			
		{if $editable}	
			$(document).on('click','#step3',function() {
				window.location = '/workflow/parties.php?ucn={$ucn}&docid={$docid}';
			});
			
			$(document).on('click','#step4',function() {
				window.location = '/orders/preview.php?sign=Y&ucn={$ucn}&docid={$docid}';
			});
		{/if}
		
		{if !$locked}
			$(document).on('click','#step5',function() {
				window.location = '/orders/genpdf.php?ucn={$ucn}&docid={$docid}';
			});
		{/if}
		
		{if $editable}
			$(document).on('click','#step6',function() {
				window.location = '/workflow/attachments.php?ucn={$ucn}&docid={$docid}';
			});
		{/if}

		{if !$locked}
			$(document).on('click','#step7',function() {
				window.location = '/workflow/envelopes.php?ucn={$ucn}&docid={$docid}';
			});
		{/if}
		
		{if $editable}
			{if !empty($pdf_file) && (!empty($signature_html) || !empty($signature_img))}
				$(document).on('click','#step8',function() {
					window.location = '/cgi-bin/eservice/eService.cgi?fromWF=1&efileCheck=1&clerkFile=1&ucn={$ucn}&docid={$docid}';
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
		{/if}
		
		$(document).on('click','.showHideEnvOptions',function() {
			$("#customSender").toggle();		
		});
    });
</script>
<div id="orderMenu">
	{if $isOrder}
		{$count = 1}
		{if $editable}
			<div class="WFMenuItem biggerWFMenuItem">
		{else}
			<div class="WFMenuItem biggerWFMenuItem inactiveWFMenuItem">
		{/if}
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
	{if $editable}
		<div class="WFMenuItem">
	{else}
		<div class="WFMenuItem inactiveWFMenuItem">
	{/if}
		<div class="bigNumber">{$count}</div> <div class="wfMenuItemLink"><a id="step3">Verify Parties</a></div>
	</div>
	{$count = $count + 1}
	{if $editable}
		<div class="WFMenuItem">
	{else}
		<div class="WFMenuItem inactiveWFMenuItem">
	{/if}
		<div class="bigNumber">{$count}</div> <div class="wfMenuItemLink"><a id="step4">Sign</a></div>
	</div>
	{$count = $count + 1}
	{if !$locked}
		<div class="WFMenuItem">
	{else}
		<div class="WFMenuItem inactiveWFMenuItem">
	{/if}
		<div class="bigNumber">{$count}</div> <div class="wfMenuItemLink"><a id="step5">Preview PDF</a></div>
	</div>
	{$count = $count + 1}
	{if $editable}
		<div class="WFMenuItem">
	{else}
		<div class="WFMenuItem inactiveWFMenuItem">
	{/if}
		<div class="bigNumber">{$count}</div> <div class="wfMenuItemLink"><a id="step6">Attachments</a></div>
	</div>
	{$count = $count + 1}
	<div id="activeWFMenuItem">
		<div class="bigNumber">{$count}</div> <div class="wfMenuItemLink"><a id="step7">Envelopes</a></div>
	</div>
	{$count = $count + 1}
	{if !empty($pdf_file) && (!empty($signature_html) || !empty($signature_img)) && $editable}
		<div class="WFMenuItem">
	{else}
		<div class="WFMenuItem inactiveWFMenuItem">
	{/if}
		<div class="bigNumber">{$count}</div> <div class="wfMenuItemLink"><a id="step8">E-File</a></div>
	</div>
	{$count = $count + 1}
	{if $editable}
		<div class="WFMenuItem">
	{else}
		<div class="WFMenuItem inactiveWFMenuItem">
	{/if}
		<div class="bigNumber">{$count}</div> <div class="wfMenuItemLink"><a id="step9">Transfer</a></div>
	</div>
	{if !$isOrder}
		{$count = $count + 1}
		{if $editable}
			<div class="WFMenuItem">
		{else}
			<div class="WFMenuItem inactiveWFMenuItem">
		{/if}
			<div class="bigNumber">{$count}</div> <div class="wfMenuItemLink"><a id="step10">Reject</a></div>
		</div>
	{/if}
</div>
<br/>
<div class="orderDiv">
	<form id="customSender" style="display:none; padding:1%" method="post" action="/workflow/envelopes.php?ucn={$ucn}&docid={$docid}">
		<table style="margin:auto;">
			<tr>
				<td><label>Name: </label></td>
				<td><input type="text" id="custom_sender_name" name="custom_sender_name" value="{$s_name}" size="50"/></td>
			</tr>
			<tr>
				<td><label>Address: </label></td>
				<td><textarea id="custom_sender_address" name="custom_sender_address" rows="4" cols="48">{$s_add}</textarea></td>
			</tr>
			<tr>
				<td colspan="2" style="text-align:right"><button type="submit" name="submit">Regenerate Envelopes</button></td>
			</tr>
		</table>
	</form>
	<div style="padding-top:0.5%; margin:auto; width:50%; text-align:center;">
		<a href="#/" class="showHideEnvOptions">Show/Hide Return Address Options</a>
	</div>
	<br/>
	<iframe class="pdfmailiframe">
	
	</iframe>
</div>