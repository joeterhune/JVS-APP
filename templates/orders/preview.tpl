<script src="/javascript/ckeditor/ckeditor.js?1.1"></script>
<script type="text/javascript">
	// do this before the first CKEDITOR.replace( ... )
	CKEDITOR.timestamp = +new Date;
</script>
<script src="/javascript/ckeditor/adapters/jquery.js"></script>
<script type="text/javascript">

    function HandlePreviewSave() {
        var pane = $(this).closest('.orderDiv');
        var data = $(pane).find('.preview-ta').first().ckeditor().editor.getData();
        data=encodeURI(data);
        $(pane).find(".order_html").val(data);
        SaveToWorkflow(pane,1);
        // And clear signed, mailed, etc. flags
        //$(pane).find('.statusind').html('');
        //$(pane).find('.isSigned').val(0);
        //$(pane).find('.pdf').val('');
        //// And disable PDF, mail, efile buttons
        //$(pane).find('.revisedisable').attr('disabled',true)
    }
    
    function HandlePreviewCancel() {
        var pane = $(this).closest('.orderDiv');
        var data = $(pane).find(".order_html").val();
        if (data!="") {
            //data=decodeURI(data);
            //$(pane).find('.preview-ta').first().ckeditor().editor.setData(data);
            UpdateFormPreview(pane);
        } else {
            UpdateFormPreview(pane);  // re-gen and display
        }
    }
    
    function HandlePreviewRegenerate() {
        var pane = $(this).closest('.orderDiv');
        $(pane).find(".order_html").val(''); // wipe the order_html field on the form
        UpdateFormPreview(pane);
    }
    
    function LockDoc(lock){
    
    	if(lock){
    		var docid = $('#docid').val();
		    var postData = { docid: docid, lock: 1 };
		    $.ajax({
		        url: "/workflow/doc_lock.php",
		        method: 'POST',
		        data: postData,
		        success: function(data) {
		        	
		        }
		    });
    	}
    	else{
    		var docid = $('#docid').val();
		    var postData = { docid: docid, lock: 0 };
		    $.ajax({
		    	async: false,
		        url: "/workflow/doc_lock.php",
		        method: 'POST',
		        data: postData,
		        success: function(data) {
		        	
		        }
		    });
    	}
    }
    
    $(document).ready(function () {
    
    	{if $editable}
	    	$(window).unload(function(){
	    		var pane = $(".orderDiv");
			    SaveToWorkflow(pane);
				LockDoc(0);
			});
		{/if}
 
    	{if $editable}
    		LockDoc(1);
	        setInterval(function(){ 
	        	//Autosave every 5 sec.... (5000)
	        	SaveToWorkflow(pane);
	        }, 5000);
        {/if}
    
	    {if $locked}
	    	showDialog("Document Locked", "This document is locked for editing by {$locked_user}.  It will open in read-only mode.", "errorDialog");
	    {/if}
	    
	    {if !$editable && !$locked}
	    	showDialog("Read-Only", "{$disable_reason}", "errorDialog");
	    {/if}
    
        var pane = $('#editwindow-{$ucn}').closest('.orderDiv');
        
        var previewDiv = $(pane).find('.previewdiv');
        var cfheight = $(previewDiv).height();
        
        var cvRow = $('#orderMenu');
        var pos = $(cvRow).offset();
        // The top of the editor should be 2* (the height of the button row + 5) offset from the top of the button row
        var editTop = pos.top + (2 * ($(cvRow).height() + 5));
        var winHt = $(window).height();
        EDITORHEIGHT = winHt - editTop - 175;
        
        $('.preview-ta').ckeditor({
            customConfig: '/javascript/ckeditor/ckeditor_custom_config.js',
            height: EDITORHEIGHT,
            
            {if !$editable}
            	readOnly: true
            {/if}
        });
        
        var editor = $('.preview-ta').first().ckeditor().editor;
        
		editor.on('instanceReady', function() { 
			{if $editable}
				if('{$sign}' == 'Y'){
				    	
					{if !$isOrder}
					    $('.cke_contents iframe').contents().one( "click", function() {
							selectSign();
						});
					{else}
						selectSign();
					{/if}
				 }
			 {/if}
		});
       
       	{if $editable}
	       	{if $isOrder}
		       	$(document).on('click','#step1',function() {
		       		var pane = $(".orderDiv");
	        		SaveToWorkflow(pane);
	        		
	        		if($("#docid").val() != ''){
		        		var doc_id = $("#docid").val();
		        	}
		        	else{
		        		var doc_id = "{$docid}";
		        	}
	        		
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
		                    	window.location = '/orders/igo.php?ucn={$ucn}&docid=' + doc_id;
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
		
		{if $editable}
			$(document).on('click','#step2',function() {
				var pane = $(".orderDiv");
	        	SaveToWorkflow(pane);
	        	if($("#docid").val() != ''){
	        		var doc_id = $("#docid").val();
	        	}
	        	else{
	        		var doc_id = "{$docid}";
	        	}
				window.location = '/orders/preview.php?ucn={$ucn}&docid=' + doc_id;
			});
		{/if}
		
		{if $editable}
			$(document).on('click','#step3',function() {
				var pane = $(".orderDiv");
	        	SaveToWorkflow(pane);
	        	if($("#docid").val() != ''){
	        		var doc_id = $("#docid").val();
	        	}
	        	else{
	        		var doc_id = "{$docid}";
	        	}
				window.location = '/workflow/parties.php?ucn={$ucn}&docid=' + doc_id;
			});
		{/if}
		
		{if $editable}
			$(document).on('click','#step4',function() {
				var pane = $(".orderDiv");
				SaveToWorkflow(pane);
				if($("#docid").val() != ''){
	        		var doc_id = $("#docid").val();
	        	}
	        	else{
	        		var doc_id = "{$docid}";
	        	}
				window.location = '/orders/preview.php?sign=Y&ucn={$ucn}&docid=' + doc_id;
			});
		{/if}
		
		{if !$locked}
			$(document).on('click','#step5',function() {
				var pane = $(".orderDiv");
				SaveToWorkflow(pane);
				if($("#docid").val() != ''){
	        		var doc_id = $("#docid").val();
	        	}
	        	else{
	        		var doc_id = "{$docid}";
	        	}
				window.location = '/orders/genpdf.php?ucn={$ucn}&docid=' + doc_id;
			});
		{/if}
		
		{if $editable}
			$(document).on('click','#step6',function() {
				var pane = $(".orderDiv");
		       	SaveToWorkflow(pane);
		       	if($("#docid").val() != ''){
		       		var doc_id = $("#docid").val();
		       	}
		       	else{
		       		var doc_id = "{$docid}";
		       	}
		       	
		       	var case_num = "{$ucn}";
			    window.location = '/workflow/attachments.php?ucn={$ucn}&docid=' + doc_id;
			});
		{/if}
		
		{if !$locked}
			$(document).on('click','#step7',function() {
				var pane = $(".orderDiv");
				SaveToWorkflow(pane);
				if($("#docid").val() != ''){
		       		var doc_id = $("#docid").val();
		       	}
		       	else{
		       		var doc_id = "{$docid}";
		       	}
				window.location = '/workflow/envelopes.php?ucn={$ucn}&docid=' + doc_id;
			});
		{/if}
		
		{if $editable}
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
		{/if}
		
		{if $editable}
			$(document).on('click','#step9',function() {
				var pane = $(".orderDiv");
	        	SaveToWorkflow(pane);
	        	if($("#docid").val() != ''){
	        		var doc_id = $("#docid").val();
	        	}
	        	else{
	        		var doc_id = "{$docid}";
	        	}
				window.location = '/orders/transfer.php?ucn={$ucn}&docid=' + doc_id;
			});
		{/if}
		
		{if $editable}
			{if !$isOrder}
				$(document).on('click','#step10',function() {
					var pane = $(".orderDiv");
		        	SaveToWorkflow(pane);
		        	if($("#docid").val() != ''){
		        		var doc_id = $("#docid").val();
		        	}
		        	else{
		        		var doc_id = "{$docid}";
		        	}
					window.location = '/orders/reject.php?ucn={$ucn}&docid=' + doc_id;
				});
			{/if}
		{/if}
		
		$(document).on('click','.showComments',function() {
			$("#commentDiv").toggle();		
		});
    });
</script>
<div id="dialogDiv">
	<span id="dialogSpan" style="font-size: 80%"></span>
</div>
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
	{if $sign != 'Y'}
		<div id="activeWFMenuItem" class="biggerWFMenuItem">
	{else}
		<div class="WFMenuItem biggerWFMenuItem">
	{/if}
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
	{if $sign == 'Y'}
		<div id="activeWFMenuItem">
	{else}
		{if $editable}
			<div class="WFMenuItem">
		{else}
			<div class="WFMenuItem inactiveWFMenuItem">
		{/if}
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
	{if !$locked}
		<div class="WFMenuItem">
	{else}
		<div class="WFMenuItem inactiveWFMenuItem">
	{/if}
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
<div style="padding-top:2%; padding-left:2%; margin-bottom:-2%;">
	{if !empty($user_comments) || !empty($comments)}
		<div style="width:50%; margin:auto; text-align:center;">
			<a href="#/"/ class="showComments">Show/Hide Comments</a>
			<div id="commentDiv" style="display:none">
				{if !empty($user_comments)}
					<span style="color:blue">{$user_comments}</span>
					<br/>
				{/if}
				<span style="color:green">{$comments}</span>
			</div>
		</div>
	{/if}
	{if $cansign > 0}           
		<div style="width:15%; margin:auto; display:none; padding-top:0.5%;" class="signAsBox">
			<select class="signAs" name="signAs" style="display: none">
				<option value="" selected="selected">Please select a signature to apply</option>
			    {foreach $esigs as $signame}
			    	{$sel = ""}
			        {if (($cansign == 1) || ($signame.user_id == $user))}
			         	{$sel = "selected=\"selected\""}
			        {/if}
			  		<option value="{$signame.user_id}" {$sel}>{$signame.fullname}</option>
			   {/foreach}
			</select>
		</div>
	{/if}
	{if empty($signature_html) || empty($signature_img)}
		{if $sign == 'Y'}
			{if !$isOrder}
				<br class="clear"/>
				<div id="sigNotice" style="color:#FFFFFE">
					Click on the location of the document where you want the signature to be placed.  If you have access to multiple signatures, a dropdown list will appear above this message when you click on the document.  Once you select the signature, it will be placed in the location of your initial click.
				</div>
				<br class="clear"/>
			{/if}
		{/if}
	{/if}
	<br class="clear"/>
	<div class="signaturediv" style="position: unset; display: none;"></div>
	<div class="hidden_copies_to_list" style="position: unset; display: none;">{$cclist_html}</div>
	
	<div id="ckeditor-window" style="padding-top:0.25%" class="orderDiv" id="orderDiv-{$ucn}">
		<textarea class="preview-ta" id="editwindow-{$ucn}" name="editwindow"  style="width:100%" spellcheck="true">
		    {$formbody}
		</textarea>
		<input type="hidden" name="docid" id="docid" value="{$docid}"/>
		<input type="hidden" name="ucn" id="ucn" value="{$ucn}"/>
		<input type="hidden" class="isOrder" name="isOrder" id="isOrder" value="{$isOrder}"/>
		<input type="hidden" name="form_name" id="form_name" value="{$form_name}"/>
		<input type="hidden" name="form_id" id="form_id" value="{$form_id}"/>
		
		<input type="hidden" name="case_caption" id="case_caption" value="{$case_caption}"/>
		<input type="hidden" name="cclist" id="cclist" value="{$cclist}"/>
	</div>
</div>