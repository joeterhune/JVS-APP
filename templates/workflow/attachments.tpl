<script type="text/javascript">
    
    $(document).ready(function () {
    
    	$(document).on('click','.removeMergeDoc',function() {
			var doc_id = $(this).data('docid');
	        
	        $('#dialogSpan').html("Are you sure you want to remove this merged document?");
			$('#dialogDiv').dialog({
				resizable: false,
				minheight: 150,
				width: 500,
				modal: true,
				title: 'Remove Merged Document',
				buttons: {
					"Yes": function() {
						$(this).dialog("close");
						{literal}
							$.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait </h1>', fadeIn: 0});
			                $.ajax({
			                    url: "/workflow/remove_merged.php",
			                    type: 'POST',
			                    data: {doc_id : doc_id},
			                    success: function(data) {
			                    	$.unblockUI();
			                        $("#merge-" + doc_id).hide();
			                    }
			                });
			            {/literal}
						return true;
					},
					"No": function() {
						$(this).dialog("close");
						return false;
					}
				}
			});
		});
    
    	$(document).on('click','.deleteDoc',function() {
			var doc_id = $(this).data('docid');
	        
	        $('#dialogSpan').html("Are you sure you want to delete this attached document?");
			$('#dialogDiv').dialog({
				resizable: false,
				minheight: 150,
				width: 500,
				modal: true,
				title: 'Delete Attached Document',
				buttons: {
					"Yes": function() {
						$(this).dialog("close");
						{literal}
							$.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait </h1>', fadeIn: 0});
			                $.ajax({
			                    url: "/workflow/delete_attachment.php",
			                    type: 'POST',
			                    data: {doc_id : doc_id},
			                    success: function(data) {
			                    	$.unblockUI();
			                        $("#" + doc_id).hide();
			                    }
			                });
			            {/literal}
						return true;
					},
					"No": function() {
						$(this).dialog("close");
						return false;
					}
				}
			});
		});
		
		$(document).on('click','.attachToEfiling',function() {
			var doc_id = $(this).data('docid');
			var file = $(this).data('file');
			
			var type = file.split('.').pop();
                	
            if(type != "pdf"){
            	$('#dialogSpan').html("Documents attached for e-Filing must be in PDF format.");
            	$("#dialogDiv").dialog({
            	    resizable: false,
                    minheight: 200,
                    width: 500,
                    modal: true,
                    title: 'Error',
                    buttons: {
                 	   "OK": function() {
                    	   $(this).dialog("close");
                    	   $("#efile_cb_" + doc_id).prop('checked', false);
                           return false;
                    	}
                	}
				});		
				
				return false;
			}
			
			var attach;
			if($(this).is(':checked')){
				attach = 1;
			}
			else{
				attach = 0;
			}
	        
	        var title;
	        if(attach == '1'){
	        	$('#dialogSpan').html("Are you sure you want to attach this document to the order that will be e-Filed?<br/><br/><input type=\"checkbox\" name=\"mergeDoc\" id=\"mergeDoc\" value=\"yes\"/> <span style=\"vertical-align:top\">Merge document with order</span>");
	        	title = "Attach to e-Filing";
	        }
	        else{
	        	$('#dialogSpan').html("Are you sure you remove this attachment from e-Filing?");
	        	title = "Remove from e-Filing";
	        }
	        
	        var wf_id = "{$docid}";
	        
			$('#dialogDiv').dialog({
				resizable: false,
				minheight: 150,
				width: 500,
				modal: true,
				title: title,
				buttons: {
					"Yes": function() {
						$(this).dialog("close");
						{literal}
							var mergeDoc = 0;
							if($("#mergeDoc").is(':checked')){
								mergeDoc = 1;
							}
							
							$.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait </h1>', fadeIn: 0});
			                $.ajax({
			                    url: "/workflow/attach_to_efiling.php",
			                    type: 'POST',
			                    data: {doc_id : doc_id, attach: attach, mergeDoc: mergeDoc, wf_id: wf_id},
			                    success: function(data) {
			                    	$("#mergeDocs").html(data.html);
			                    	$.unblockUI();
			                    }
			                });
			            {/literal}
						return true;
					},
					"No": function() {
					
						if(attach == '1'){
							$("#efile_cb_" + doc_id).prop('checked', false);
						}
						else{
							$("#efile_cb_" + doc_id).prop('checked', true);
						}
					
						$(this).dialog("close");
						return false;
					}
				}
			});
		});
        
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
		
		{if !$isOrder}
			$(document).on('click','#step10',function() {
				window.location = '/orders/reject.php?ucn={$ucn}&docid={$docid}';
			});
		{/if}
		
		$(document).on("click", ".attachAnotherCustom", function(e){
			var count = parseInt($(this).attr('data-row'));
			var newCount = count + 1;
			$(".customAttachLink").hide();
			var newRow = '<tr class="customAttachField_'+newCount+'"><td><label>Title ' + newCount + ': </strong></td>';
			newRow += '<td><input type="text" name="customSupportingTitle_'+newCount+'" id="customSupportingTitle_'+newCount+'" size="50"/></td></tr>';
			newRow += '<tr class="customAttachField_'+newCount+'"><td><label>Document ' + newCount + ': </strong></td>';
			newRow += '<td><input id="customSupportingDoc_'+newCount+'" type="file" size="50" style="display:inline" name="customSupportingDoc_'+newCount+'"></td></tr>';
			newRow += '<tr class="customAttachLink"><td>&nbsp;</td><td><a href="#/" class="attachAnotherCustom" data-row="' + newCount + '">Attach another document</a></td></tr></td></tr>';
			$(".customAttachField_" + count).last("tr").after(newRow);
		});
		
		$('.submit').click(function() {
					
			if ($("#customSupportingTitle_1").val() == "") {
				showDialog("Error", "You must enter a document title.", 'errorDialog');
				return false;
			}
					
			if ($("#customSupportingDoc_1").val() == "") {
				showDialog("Error", "You must select a file to upload.", 'errorDialog');
				return false;
			}
					
			$("#attForm").submit();
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
	<div id="activeWFMenuItem">
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
<br/>
<div style="padding-top:1%; padding-left:2%;">
	<div id="mergeDocs">
		{if !empty($merge_docs)}
			<p>The following documents will be merged with the order: </p>
			<table style="width:40%; text-align:center">
				<thead>
					<tr>
						<th>Document Title</th>
						<th>Remove</th>
					</tr>
				</thead>
				<tbody>
					{foreach $merge_docs as $md}
						<tr id="merge-{$md.supporting_doc_id}">
							<td><a href="{$md.file}" target="_blank">{$md.document_title}</a></td>
							<td><a href="#\" class="removeMergeDoc" data-docid="{$md.supporting_doc_id}"><img src="../icons/delete.png"/></a></td>
						</tr> 
					{/foreach}
				</tbody>
			</table>
			<br/>
		{/if}
	</div>
	{if !$isOrder}
		{if !empty($ols_docs)}
			<p>The following documents were submitted through the Online Scheduling system: </p>
			<table style="width:40%; text-align:center">
				<thead>
					<tr>
						<th>Document Title</th>
						<th>Attach to e-Filing?</th>
					</tr>
				</thead>
				<tbody>
					{foreach $ols_docs as $od}
						<tr id="{$od.supporting_doc_id}">
							<td><a href="{$olsURL}/{$od.file}" target="_blank">{$od.document_title}</a></td>
							<td>
								{if $od.efile_attach == '1'}
									<input type="checkbox" name="attachToEfiling" id="efile_cb_{$od.supporting_doc_id}" class="attachToEfiling" checked="checked" data-docid="{$od.supporting_doc_id}" data-file="{$od.file}"/> 
								{else}
									<input type="checkbox" name="attachToEfiling" id="efile_cb_{$od.supporting_doc_id}" class="attachToEfiling" data-docid="{$od.supporting_doc_id}" data-file="{$od.file}"/> 
								{/if}
							</td>
						</tr> 
					{/foreach}
				</tbody>
			</table>
			<br/>
		{/if}
	{/if}
	{if !empty($jvs_docs)}
		<p>The following documents were attached through JVS: </p>
		<table style="width:40%; text-align:center">
			<thead>
				<tr>
					<th>Document Title</th>
					<th>Attach to e-Filing?</th>
					<th>Delete</th>
				</tr>
			</thead>
			<tbody>
				{foreach $jvs_docs as $od}
					<tr id="{$od.supporting_doc_id}">
						<td><a href="{$od.file}" target="_blank">{$od.document_title}</a></td>
						<td>
							{if $od.efile_attach == '1'}
								<input type="checkbox" name="attachToEfiling" id="efile_cb_{$od.supporting_doc_id}" class="attachToEfiling" checked="checked" data-docid="{$od.supporting_doc_id}" data-file="{$od.file}"/> 
							{else}
								<input type="checkbox" name="attachToEfiling" id="efile_cb_{$od.supporting_doc_id}" class="attachToEfiling" data-docid="{$od.supporting_doc_id}" data-file="{$od.file}"/> 
							{/if}
						</td>
						<td><a href="#\" class="deleteDoc" data-docid="{$od.supporting_doc_id}"><img src="../icons/delete.png"/></a></td>
					</tr> 
				{/foreach}
			</tbody>
		</table>
		<br/>
	{/if}
	<p>(OPTIONAL) Upload new attachments to this order.</p> 
	<form method="post" action="attachments.php?ucn={$ucn}&docid={$docid}" enctype="multipart/form-data" id="attForm">
		<table style="width:80%">
			<tr class="customAttachField_1">
				<td><label>Title 1: </strong></td>
				<td><input type="text" name="customSupportingTitle_1" id="customSupportingTitle_1" size="50"/></td>
			</tr>
			<tr class="customAttachField_1">
				<td><label>Document 1: </strong></td>
				<td>
					<input type="file" name="customSupportingDoc_1" id="customSupportingDoc_1" style="display:inline" size="50"/>
				</td>
			</tr>
			<tr class="customAttachLink">
				<td>&nbsp;</td>
				<td><a href="#/" class="attachAnotherCustom" data-row="1">Attach another document</a></td>
			</tr>
			<tr>
				<td colspan="2" style="text-align:center"><button class="submit" type="submit" onclick="javascript:return false;">Upload Document(s)</button></td>
			</tr>
		</table>
	</form>
</div>