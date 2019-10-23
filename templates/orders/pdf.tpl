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
        
        $('.pdfiframe').attr('src', '{$filename}');
        $('.pdfiframe').css('width', '100%');
        $('.pdfiframe').css('height', PDFIFRAMEHEIGHT);
        
        $('#dialogDiv').bind('dialogclose', function(event, ui) {
			$(".pdfiframe").show();
		});
       
       	{if $editable}
	       	{if $isOrder}
		       	$(document).on('click','#step1',function() {
		       		$(".pdfiframe").hide();
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
			{if $isSigned}
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
	<div id="activeWFMenuItem">
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
	{if !$locked}
		<div class="WFMenuItem">
	{else}
		<div class="WFMenuItem inactiveWFMenuItem">
	{/if}
		<div class="bigNumber">{$count}</div> <div class="wfMenuItemLink"><a id="step7">Envelopes</a></div>
	</div>
	{$count = $count + 1}
	{if $isSigned && $editable}
    	{$class = "WFMenuItem"}
	{else}
		{$class = "WFMenuItem inactiveWFMenuItem"}
	{/if}
	<div class="{$class}">
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
	<iframe class="pdfiframe">
	
	</iframe>
</div>