<!-- $Id: index.tpl 2233 2015-08-27 20:02:27Z rhaney $ -->
<script src="/javascript/jquery/jquery.form.js"></script> 
<script src="/javascript/workflow.js?2.6" type="text/javascript"></script>
<script type="text/javascript">
    var ROLE='{$role}'; 
    var EFILING_CODE='{$efiling_code}';
    WORKQUEUELIST='{','|implode:$allqueues}';
    var WORKQUEUES = {$queuejson};
    var XFERQUEUE;
    
    $(document).ready(function () {
    
    	$(document).on('click','.showAttachments',function(e) {
    		var doc_id = $(this).data('id');
    		$("#attachments_" + doc_id).toggle();
    	});
    
    	$(document).on('click','.notesAttach',function(e) {
	        e.preventDefault;
	        
	        var noteid = $(this).data('noteid');
			
	        var postData = {};
	        
	        var pane;
	        var ucn;
	        var url = "/casenotes/displayAttachment.php";
	        if (noteid != undefined) {
	            noteid = noteid;
	            filename = $(this).data('filename');
	            pane = $(this).closest('.caseTab');
	            ucn = $(pane).find('.ucn').val();
	            url += "?noteid=" + noteid + "&filename=" + filename;
	        } else {
	            ucn = $(this).data('casenum');
	            docid = $(this).data('docid');
	            // No noteid?  Came from a workflow link.
	            docid = docid;
	            casenum = ucn;
	            noteid = docid;
	            url += "?docid=" + docid + "&casenum=" + casenum;
	        }
	        
	        window.open(url);        
	        return false;
	    });
    
    	$(document).on('click','.hideCol,.showCol', function () {
    		cookieName = "wf-cookie";
	    	colCookie = $.cookie(cookieName);
	    	hideCols = new Array;
	        if (colCookie != undefined) {
	            hideCols = colCookie.split(':');
	        }
        
	        var colName = $(this).attr('data-colName');
	        var selTarget = '.' + colName;
	        // Find the header for the target column - we need to know its column number
	        headerTarget = $('.tablesorter-headerRow').find(selTarget).first();
	        thisCol = $(headerTarget)[0].column;
	        $(selTarget).toggle();
	        
	        // Also be sure to hide the filter for that column (it doesn't hide with the class)
	        // Find which one it is.  We know the column number
	        $('.tablesorter-filter').each(function(i,e) {
	            var colNum = $(e).attr('data-column');
	            if (colNum == thisCol) {
	                // This is the one.  Hide the parent.
	                $(e).parent().toggle();
	                return false;
	            }
	            return true;
	        });
	        
	        {literal}
		        
		        if ($(this).hasClass('hideCol')) {
		            $(this).removeClass('hideCol').addClass('showCol');
		            if (colCookie == undefined) {
		                $.cookie(cookieName,colName, {expires : 10000});
		            } else {
		                cookieVal = colCookie + ':' + colName;
		                $.cookie(cookieName, cookieVal, {expires : 10000});
		            }
		        } else {
		            $(this).removeClass('showCol').addClass('hideCol');
		            if (colCookie != undefined) {
		                // Need to remove a value from the cookie.  It's delimited by colons.
		                hideCols = colCookie.split(':');
		                newHide = new Array;
		                for (i = 0; i < hideCols.length; i++) {
		                    if (hideCols[i] == '') {
		                        continue;
		                    }
		                    if (hideCols[i] != colName) {
		                        newHide.push(hideCols[i]);
		                    }
		                }
		                // Now join the values and set the cookie.
		                cookieVal = newHide.join(':');
		                $.cookie(cookieName, cookieVal, {expires : 10000});
		                return true;
		            }
		        }
	        {/literal}
	        return true;
	    });
    
    	 $('#wf_maintable_{$queueName}').tablesorter({
         	widgets: ['filter'],
            widgetOptions: {
	            filter_columnFilters: true,
	            filter_saveFilters: true,
	            filter_reset : '.{$queueName}-reset'
           	}
        });
        
        // Do something to warn people that they have a filter set... 
		$('#wf_maintable_{$queueName}').bind('filterEnd', function(event, config) {
			if(config.filteredRows != config.totalRows){
				$(".myqueue-reset").css("background-color", "red");
				$(".myqueue-reset").css("border-color", "#000000");
			}
			else{
				$(".myqueue-reset").css("background-color", "#428bca");
				$(".myqueue-reset").css("border-color", "#357ebd");
			}
		});
        
        //setTimeout(function(){
        	cookieName = "wf-cookie";
	    	colCookie = $.cookie(cookieName);
	    	hideCols = new Array;
	        if (colCookie != undefined) {
	            hideCols = colCookie.split(':');
	        }
	        
	        for (i = 0; i < hideCols.length; i++) {
	            if (hideCols[i] == '') {
	                continue;
	            }
	            var selTarget = '.' + hideCols[i];
	            // Find the header for the target column - we need to know its column number
	            var headerTarget = $('.tablesorter-headerRow').find(selTarget).first();
	            if(headerTarget[0]){
		            var thisCol = $(headerTarget)[0].column;
		            $(selTarget).hide();
		            $("#" + hideCols[i] + "Link").removeClass( "hideCol" ).addClass("showCol");
		
			        // Also be sure to hide the filter for that column (it doesn't hide with the class)
			        // Find which one it is.  We know the column number
			        $('.tablesorter-filter').each(function(i,e) {
			            var colNum = $(e).attr('data-column');
			            if (colNum == thisCol) {
			                // This is the one.  Hide the parent.
			                $(e).parent().hide();
			            }
			        });
		        }
	        }
        //}, 250);
    	
    
    	$('.wfTabLink').click(function() {
        	window.location.href = $(this).attr('href');
        })
    
        wfTab = $('#workflow');
        
        $('#workflow').on('click','.addToQueue',function(e) {
            e.preventDefault();
            var queue = $(this).data('queue');
            HandleAdd(queue,'','');
            return true;
        });
        
        
        //'<a class="efCheck" data-targetclass="fileCheck">Check All</a>'
        $('#workflow').on('click','.wfAllCheck',function(e) {
            e.preventDefault();
            var targetClass = $(this).data('targetclass');
            $(this).closest('.qtable').find('.' + targetClass).prop('checked',true);
        });
        
        //$('#workflow').on('click','.addQItem',function() {
        //    queuename = $(this).parentsUntil('#wfTabContents').find('.queuename').first().val();
        //    alert("Will be adding something to the " + queuename + " queue.");
        //});
        //
        
        $('#workflow').on('click','.showQFinished',function() {
        	{if $queueName == "myqueue"}
        		{$finished = $user}
        	{else}
        		{$finished = $queueName}
        	{/if}
        	window.location="/workflow/showfinished.php?queue={$finished}";
        });
        
        $('#workflow').on('click','.showQDeleted',function() {
        	{if $queueName == "myqueue"}
        		{$deleted = $user}
        	{else}
        		{$deleted = $queueName}
        	{/if}
        	window.location="/workflow/show_deleted.php?queue={$deleted}";
        });
        
        $('#workflow').on('click','.showQMyDocuments',function() {
        	{if $queueName == "myqueue"}
        		{$myDocuments = $user}
        	{else}
        		{$myDocuments = $queueName}
        	{/if}
        	window.location="/workflow/show_my_documents.php?queue={$myDocuments}";
        });
        
        $('#workflow').on('click','.showQMyAuditLog',function() {
        	{if $queueName == "myqueue"}
        		{$myAuditLog = $user}
        	{else}
        		{$myAuditLog = $queueName}
        	{/if}
        	window.location="/workflow/my_audit_log.php?queue={$myAuditLog}";
        });
        
        $('#wfcount').html({$wfCount});
        
        {literal}
	        $("#workflowtabs").tabs({beforeLoad: PreventTabReload});
	        $("#wfmenu").menu();
	        $("#wfmenufo").menu();
	        $("#wfmenurem").menu();
	        
	        $(".wfmenubut").unbind('click',WorkFlowMenuActionButton);
	        $(".wfmenubut").click(WorkFlowMenuActionButton);
	        
	        $(".wf_add_comment_but").unbind('click',HandleAddComment);
	        $(".wf_add_comment_but").click(HandleAddComment);
	        
	        $(".wfmenubut2").unbind('click',WorkFlowMenuActionButtonFormOrder);
	        $(".wfmenubut2").click(WorkFlowMenuActionButtonFormOrder);
	        
	        $(".wfmenubut3").unbind('click',WorkFlowMenuActionButtonReminder);
	        $(".wfmenubut3").click(WorkFlowMenuActionButtonReminder);
	        $(".wfmenubut4").unbind('click',WorkFlowMenuActionButtonHearingRequest);
	        $(".wfmenubut4").click(WorkFlowMenuActionButtonHearingRequest);
	        
	        //$(".wfmenubut5").unbind('click',WorkFlowMenuActionMiscDoc);
	        //$(".wfmenubut5").click(WorkFlowMenuActionMiscDoc);
	        
	        $(".wfmenuitem").unbind('click',WorkFlowDoIt);
	        $(".wfmenuitem").click(WorkFlowDoIt);
	        $(".wfselectall").unbind('click',WorkFlowSelectAll);
	        $(".wfselectall").click(WorkFlowSelectAll);
	        //$(".wf_tables").dataTable({
	        //    "aoColumns": [
	        //        {"sWidth":"8%"},
	        //        {"sWidth":"10%"},
	        //        {"sWidth":"15%"},
	        //        {"sWidth":"6%"},
	        //        {"sWidth":"5%"},
	        //        {"sWidth":"7%"},
	        //        {"sWidth":"10%"},
	        //        {"sWidth":"5%"},
	        //        {"sWidth":"8%"},
	        //        {"sWidth":"27%"}
	        //        ],
	        //    "bLengthChange":false,
	        //    "bInfo":false,
	        //    "bPaginate":false,
	        //    "bAutoWidth":false,
	        //    "bPaginate:":false
	        //});
	        
	        $("#wfmenuhrg").dialog({autoOpen:false,width:350,height:245,buttons: [ { text:"Accept",click: HearingRequestAccept},{text: "Deny",click: HearingRequestDeny},{ text: "Cancel",click: function () { $("#wfmenuhrg").dialog("close");}}]});
        {/literal}
        
        $('.bulkxfer').on("click", function() {
	        XFERQUEUE = $(this).attr('data-queue');
	        
	        DIALOG=$("#wf_bulkxferdialog").dialog({
	            width:450,
	            height:200,
	            title: "Select Queue"
	        });
	    });
	    
	    $('.bulkdelete').on("click", function() {
	        var deletecheck = $('.qtable').find('.deleteCheck:checked');
	        var bulkdelete = $(deletecheck).length;
	        
	        if (bulkdelete == 0) {
	            return false;
	        }
	    
	        $('#dialogSpan').html("Are you sure you wish to delete these " + bulkdelete + " item(s)?");
		    $('#dialogDiv').dialog({
		        resizable: false,
		        minheight: 150,
		        width: 500,
		        modal: true,
		        title: 'Confirm Deletion',
		        buttons: {
		            "Yes": function() {
		                $(this).dialog("close");
		                $(deletecheck).each(function () {
				            var docid = $(this).val();
							DeleteEntry(docid);
						});
		                return false;
		            },
		            "No": function() {
		                $(this).dialog("close");
		                return false;
		            }
		        }
		    });
	    });
	    
	    $('.bulkefile').on("click", function() {
	        var queue = $(this).attr('data-queue');
	        var tid='wf_maintable_'+queue;
	        var filecheck = $('#' + tid).find('.fileCheck:checked');
	        var bulkfile = $(filecheck).length;
	        
	        if(bulkfile == 0){
	        	return false;
	        }
	        /*else if(bulkfile == 1){
	            
	            var casenum = $(filecheck).attr('data-casenum');
	            var pdf = $(filecheck).attr('data-pdf');
	            var doc_id = $(filecheck).attr('data-doc_id');
	            var tabName = "case-" + casenum;
	            createTab(tabName, casenum, 'casetop', 'caseTab', 1);
	            var esTabName = tabName + '-eservice';
	            createTab(esTabName, 'e-Service', tabName, 'innerPane', 0);
	            $('#\\#' + tabName + "_link").trigger('click');
	            
	            {literal}
	            	var postData = {case: casenum, tab: esTabName, show: 1, efileCheck: 1, pdf: pdf, doc_id: doc_id, clerkFile: 1};
	            
		            $.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait </h1>', fadeIn: 0});
		                    
		            $.ajax({
		            	url: "/cgi-bin/eservice/eService.cgi",
		                data: postData,
		                async: false,
		                success: function(data) {
		                	$.unblockUI();
		                    showTab(data);
		                }
		        	});
	        	{/literal}
	        	
	        	return false;
	        }*/
	        else{
		        $('#dialogSpan').html("Clicking OK will e-file all of the selected documents through the state's e-filing portal.");
			    $('#dialogDiv').dialog({
			    	resizable: false,
			        minheight: 150,
			        width: 500,
			        modal: true,
			        title: 'E-Filing Confirmation',
			        buttons: {
			        	"OK": function() {
			            	$(this).dialog( "close" );
	        				WorkFlowBulkEfile(queue);
			                return false;
			            },
			            "Cancel": function(){
			            	$(this).dialog( "close" );
			                return false;
			            }
			        }
				});
	        }
	    });
	    
	    $('.bulksign').on("click", function() {
	        var queue = $(this).attr('data-queue');
	        WorkFlowBulkSign(queue);
	    });
	    
	    $('.comment_field').on("click", function() {
	    	if ($(this).prop('scrollWidth') >  $(this).width()) {
		        var ucn = $(this).attr('data-ucn');
		       	$('#dialogSpan').html($(this).html());
				$('#dialogDiv').dialog({
					resizable: false,
				    minheight: 150,
				    width: 500,
				    modal: true,
				    title: 'Comment for ' + ucn,
				    buttons: {
				    	"OK": function() {
				        	$(this).dialog( "close" );
				            return false;
				        },
				    }
				});
				//$(".ui-dialog-titlebar").hide();
			}
	    });
	    
	    cookieName = "wf-cookie";
	    colCookie = $.cookie(cookieName);
	    hideCols = new Array;
	    if (!colCookie || (colCookie == undefined) || (colCookie == "")) {
		    if($("#FlaggedLink").hasClass('hideCol')){
		    	$("#FlaggedLink").click();
		    }
		    if($("#CategoryLink").hasClass('hideCol')){
	    		$("#CategoryLink").click();
	    	}
	    	if($("#DueLink").hasClass('hideCol')){
	    		$("#DueLink").click();
	    	}
	    	if($("#DaysInQueueLink").hasClass('hideCol')){
	    		$("#DaysInQueueLink").click();
	    	}
	    	if($("#TransferLink").hasClass('hideCol')){
	    		$("#TransferLink").click();
	    	}
	    	if($("#DeleteLink").hasClass('hideCol')){
	    		$("#DeleteLink").click();
	    	}
    	}
    });
    
</script> 

<!-- Workflow add/edit dialog -->
        <div id="wf_add_dialog" style="display:none" title="Add/Edit Document">
            <form id="wf_add_form" action="workflow/wfupload.php" method="post">
                <fieldset>
                    <table>
                        <tr>
                            <td>
                                <label for="wf_ucn">
                                    Case #
                                </label>
                            </td>
                            <td>
                                <input type="text" style="width: 20em" name="wf_ucn" id="wf_ucn" class="text ui-widgit-content ui-corner-all" onChange="HandleWorkFlowCaseFind('wf_ucn');"/>
                                <input type="button" class="button" id="wf_findcase" value="Find" onClick="HandleWorkFlowCaseFind('wf_ucn');"/>
                            </td>
                        </tr>
                        
                        <tr id="wf_upload_row">
                            <td>
                                <label for="wf_file">
                                    File to Upload
                                </label>
                            </td>
                            <td>
                                <input type="file" name="wf_file" id="wf_file" size=50 class="text ui-widgit-content ui-corner-all"/>
                            </td>
                        </tr>
                        
                        <tr>
                            <td>
                                <label for="wf_queue">
                                    Work Queue
                                </label>
                            </td>
                            <td>
                                <select id="wf_queue" name="wf_queue">
                                	<option value="{$user}" selected>My Queue</option>
                                    {foreach $real_xferqueues as $xferqueue}
                                    	<option value="{$xferqueue.queue}">
                                    		{$xferqueue.queuedscr}
                                    	{/foreach}
                                    </option>
                                </select>
                            </td>
                        </tr>
                        
                        <tr>
                            <td>
                                <label for="wf_title">
                                    Title
                                </label>
                            </td>
                            <td>
                                <input type="text" name="wf_title" id="wf_title" size=50 class="text ui-widgit-content ui-corner-all"/>
                                <br/>
                            </td>
                        </tr>
                        
                        <tr>
                            <td>
                                <label for="priority">
                                    Category
                                </label>
                            </td>
                            <td>
                                <select name="wf_priority" id="wf_priority">
                                    <option value="Red">Red</option>
                                    <option value="Orange">Orange</option>
                                    <option value="Yellow">Yellow</option>
                                    <option value="Green">Green</option>
                                    <option value="Blue">Blue</option>
                                    <option value="Indigo">Indigo</option>
                                    <option value="Violet">Violet</option>
                                    <option value="Black">Black</option>
                                    <option value="Gray">Gray</option>
                                    <option value="White">White</option>
                                </select>
                            </td>
                        </tr>
                        
                        <tr>
                            <td>
                                <label for="wf_due_date">
                                    Due Date
                                </label>
                            </td>
                            <td>
                                <input type="text" name="wf_due_date" id="wf_due_date" class="text ui-widget-content"/>
                            </td>
                        </tr>
                    </table>
                    
                    <label for="wf_comments">
                        Comments
                    </label>
                    
                    <textarea rows="8" cols="75" id="wf_comments" name="wf_comments"></textarea>
                    <br/>
                    
<!--                    <span id="wf_an_order_span">
                        <label for="wf_an_order">
                            This document is a proposed order
                        </label>
                        <input type='checkbox' id="wf_an_order" name="wf_an_order" onclick="WorkFlowAddToggle();"/>
                        <br/>
                    </span>-->
                    
                    <div id="wf_order_details" style="display:none">
                        <label for="wf_need_judge">
                            Needs Judge Signature
                        </label>
                        
                        <input type="checkbox" id="wf_need_judge" name="wf_need_judge" checked="checked"/>
                        <br/>
                        
                        <div id="wf_docket_as_div">
                            <label for="wf_docket_as">
                                Docket As:
                            </label>
                            <select id="wf_docket_as" name="wf_docket_as">
                                <option></option>
                            </select>
                        </div>
                    </div>
                    
                    <input type=hidden name="wf_id" id="wf_id"/>
                    <input type=hidden name="wf_docref" id="wf_docref"/>
                    <input type=hidden name="wf_doctype" id="wf_doctype"/>
                    <button type="button" class="wf_add_save_btn">Save</button>
                </fieldset>
            </form>
        </div>
        

<div id="workflow" style="margin-top:0.5%">
	<div class="tabbable">
		<ul id="workflowlist" class="nav nav-tabs">
			<li {if $queueName == "myqueue"}class="active"{/if}>
				<a class="wfTabLink" href="workflow.php?queueName=myqueue" data-toggle="tab">
					My Queue ({if array_key_exists($user,$queueItems)}{$queueItems.$user|@count}{else}0{/if})
				</a>
			</li>
			{foreach $sharedqueues as $divname}
	        	{$username = $users.$divname.fullname}
	        	<li {if $queueName == $divname}class="active"{/if}>
	        		<a class="wfTabLink" href="workflow.php?queueName={$divname}" data-toggle="tab">
		        		{$username}'s Shared Queue ({if array_key_exists($divname,$queueItems)}{$queueItems.$divname|@count}{else}0{/if})
	        		</a>
	        	</li>
			{/foreach}
			{foreach $queues as $divname}
	        	{if $divname != $user}
		        	<li {if $queueName == $divname}class="active"{/if} {if strpos($divs.$divname.CourtType, "Emergency") !== false}style="background-color:red;"{/if}>
		        		<a class="wfTabLink" href="workflow.php?queueName={$divname}" data-toggle="tab">
		        			{if $divs.$divname.CustomQueue == '0'}
		        				{$divs.$divname.CourtType} Division {$divname}
		        			{else}
		        				{$divs.$divname.CourtType}
		        			{/if} 
		        			({if array_key_exists($divname,$queueItems)}{$queueItems.$divname|@count}{else}0{/if})
		        		</a>
		        	</li>
	        	{/if}
			{/foreach}
		</ul>
		<div class="tab-content" id="workflowtabs">
			{if $queueName == "myqueue"}
				{$queueName = "my"}
				{$key = $user}
				{$qType = "my"}
			{else}
				{$key = $queueName}
				{$qType = "shared"}
				{foreach $queues as $divname}
					{if $queueName == $divname}
						{$qType = "div"}
					{/if}
				{/foreach}
			{/if}
			{include file='workflow/queue.tpl' queueName=$queueName queueItems=$queueItems[$key] qType=$qType canSign=$cansign}
		</div>
	</div>
</div>
        <!-- Workflow Reject Dialog -->
        <div id="wf_reject_dialog" style="display:none; z-index:100" title="Reject Document">
            <label for="wf_reject_comments">Reason for Rejection</label>
            <textarea rows="6" cols="80" id="wf_reject_comments" name="wf_reject_comments"></textarea>
            <br/>
            <input type="hidden" name="wf_reject_id" id="wf_reject_id"/>
            <input type="hidden" name="wf_reject_creator" id="wf_reject_creator"/>
            <input type="hidden" name="wf_reject_queue" id="wf_reject_queue"/>
            <input type="hidden" name="wf_reject_ucn" id="wf_reject_ucn"/>
            <button class="rejectBtn">Save</button>
        </div>
        
        <!-- Workflow Transfer Dialog -->
        <div id="wf_xferdialog" style="display: none">
            Who would you like to transfer this document to?
            <p>
                <select id="wf_xferqueue" name="wf_xferqueue">
                    {foreach $real_xferqueues as $xferqueue}<option value="{$xferqueue.queue}">{$xferqueue.queuedscr}{/foreach}</option>
                </select>
                <input id="wf_xferfromqueue" type="hidden" name="wf_xferfromqueue"/>
                <input id="wf_xferid" type="hidden" name="wf_xferid" />
                <button class="queuexfer">Transfer</button>
            </p>
        </div>
        
        <!-- WORKFLOW ACTION MENU -->
        
        <ul class="wfmenu" id="wfmenu" style="width:150px;display:none;cursor:pointer;z-index:100">
            <li class="wfmenuitem" id="wfdocedits1" data-choice="settings">Edit Settings</li>
            <li class="wfmenuitem" data-choice="transfer">Transfer</li>
            <li class="wfmenuitem" data-choice="flag">Flag/Unflag</li>
            <li class="wfmenuitem" data-choice="reject">Reject</li>
            <li class="wfmenuitem" data-choice="delete">Delete</li>
            <li class="wfmenuitem" data-choice="finish" id="wfdocfinish">Finish</li>
        </ul>
        
        
        <!--                                     -->
        <!-- WORKFLOW ACTION MENU - FORM ORDERS -->
        <!--                                     -->
        
        <ul class="wfmenu" id="wfmenufo" style="width:150px;display:none;cursor:pointer;z-index:100">
            <li class="wfmenuitem" id="wfdocedits1" data-choice="settings">Edit Settings</li>
            <li class="wfmenuitem" data-choice="transfer">Transfer</li>
            <li class="wfmenuitem" data-choice="flag">Flag/Unflag</li>
            <li class="wfmenuitem" data-choice="reject">Reject</li>
            <li class="wfmenuitem" data-choice="delete">Delete</li>
            <li class="wfmenuitem" data-choice="finish">Finish</li>
        </ul>
        
        <!--                                     -->
        <!-- WORKFLOW ACTION MENU - REMINDERS    -->
        <!--                                     -->
        
        <ul class="wfmenu" id="wfmenurem" style="width:150px;display:none;cursor:pointer;z-index:100">
            <li class="wfmenuitem" id="wfdocedit" data-choice="settings">Edit Settings</li>
            <li class="wfmenuitem" data-choice="transfer">Transfer</li>
            <li class="wfmenuitem" data-choice="flag">Flag/Unflag</li>
            <li class="wfmenuitem" data-choice="delete">Delete</li>
            <li class="wfmenuitem" data-choice="finish">Finish</li>
        </ul>
        
        <!-- Workflow bulk transfer dialog -->
        <div id="wf_bulkxferdialog" style="display: none">
            Who would you like to transfer these documents to?
            <p>
                <select id="wf_bulkxferqueue" name="wf_bulkxferqueue">
                    {foreach $real_xferqueues as $xferqueue}<option value="{$xferqueue.queue}">{$xferqueue.queuedscr}{/foreach}</option>
                </select>
                <!--<input id="wf_bulkxferfromqueue" type="hidden" name="wf_xferfromqueue" />-->
                <!--<input id="wf_bulkxferid" type="hidden" name="wf_xferid" />-->
                <button class="bulkqueuexfer">Transfer</button>
            </p>
        </div>
        
<!-- WF add comment -->
<div id="wf_addcomment_dialog" style="display:none" title="Add/Edit Comment">
	<form id="wf_add_comment_form" action="workflow/wf_add_comment.php" method="post">
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