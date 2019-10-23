<script src="/javascript/jquery/jquery.form.js"></script> 
<script src="/javascript/workflow.js?2.4" type="text/javascript"></script>
<script type="text/javascript">
    
    $(document).ready(function () {
    
    	$(".wf_add_comment_but").unbind('click',HandleAddComment);
	    $(".wf_add_comment_but").click(HandleAddComment);
        
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
				window.location = '/cgi-bin/eservice/eService.cgi?fromWF=1&efileCheck=1&clerkFile=1&ucn={$ucn}&docid={$docid}';
			});
		{/if}
		
		{if !$isOrder}
			$(document).on('click','#step10',function() {
				window.location = '/orders/reject.php?ucn={$ucn}&docid={$docid}';
			});
		{/if}
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
	<div id="activeWFMenuItem">
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
	<table>
		<tr>
			{if !empty($user_comments) || !empty($comments)}
				<td><label>Comments:</label></td>
				<td>
					{if !empty($user_comments)}
						<span style="color:blue">{$user_comments}</span>
						<br/>
					{/if}
					<span style="color:green">{$comments}</span>
				</td>
			{/if}
		</tr>
		<tr>
			<td colspan="2" style="text-align:right">
				<button class="wf_add_comment_but" data-queue="{$queueName}" data-ucn="{$ucn}" data-title="{$title}" data-comment="{$comments}" data-wfid="{$docid}">Add/Edit Comment</button>
			</td>
		</tr>
	</table>
	<br/>
	<table>
		<tr>
			<td><label>Workflow Queue:</label></td>
			<td>
				<select class="xmltransferqueue">
				   	{foreach $real_xferqueues as $user}
				   		<option value="{$user.queue}">{$user.queuedscr}</option>
				   	{/foreach}
				</select>
			</td>
		</tr>
		<tr>
			<td colspan="2" style="text-align:right"><button class="doTransfer">Transfer</button></td>
		</tr>
		<input type="hidden" name="docid" id="docid" value="{$docid}"/>
	</table>
</div>
<!-- WF add comment -->
<div id="wf_addcomment_dialog" style="display:none" title="Add/Edit Comment">
	<form id="wf_add_comment_form" action="../workflow/wf_add_comment.php" method="post">
    	<fieldset>
        	<table>
            	<tr>
                	<td>
                    	<label for="wf_add_comment_ucn">
                        	Case Number:
                        </label>
                    </td>
                    <td>
                    	<span id="wf_add_comment_ucn"></span>
                    </td>
                </tr>
                <tr>
                	<td>
                    	<label for="wf_add_comment_title">
                        	Title:
                        </label>
                    </td>
                    <td>
                    	<span id="wf_add_comment_title"></span>
                    </td>
                </tr>
            </table>
			<label for="wf_add_comment_comments">
            	Comments: 
            </label>
            <textarea rows="8" cols="70" id="wf_add_comment_comments" name="wf_add_comment_comments"></textarea>
            <br/>
                
            <input type="hidden" name="add_comment_wf_id" id="add_comment_wf_id"/>
            <input type="hidden" name="add_comment_queue" id="add_comment_queue"/>
            <button type="button" class="wf_add_comment_save_btn">Save</button>
		</fieldset>
	</form>
</div>