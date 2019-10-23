// $Id: workflow.js 2212 2015-08-24 20:10:26Z rhaney $

// WorkFlow subsystem JavaScript routines
// global to keep track of async bulk signature calls
//var bulksign = 0;
//var signed = 0;

function closeDialogs () {
    $('#wf_reject_dialog').dialog('close');
    $('#nt_add_dialog').dialog('close');
    $('#wf_add_dialog').dialog('close');
    $('#wf_bulkxferdialog').dialog('close');
    $('#wf_case_pick').dialog('close');
    $('#wfmenuhrg').dialog('close');
    $('#wf_xferdialog').dialog('close');
    $('#wf_reject_dialog').dialog('close');
    $('#dialogDiv').dialog('close');
}

function WorkFlowSetCaseVal(x,val) {
    $("#wf_case_pick").dialog("close");
    $("#"+x).val(val);
    HandleWorkFlowAddCaseChange(); // change the dropdown vals as appropriate
}


// WorkFlowCheckCase is a quick case # validation function...

function WorkFlowCheckCase(x) {
    var ucnSel = "#" + x;
    var ucn=$(ucnSel).val();
    
    var postData = {ucn: ucn};
    var url = "/workflow/checkcase.php";
    $.ajax({
        url: url,
        data: postData,
        async: false,
        success: function(data) {
            var casenum = data.CaseNumber;
            if (casenum == undefined) {
                alert("No Match");
                return false;
            } else {
                $(ucnSel).val(casenum);
            }
            return true;
        }
    });
    return false;
    
//    $.post("/workflow/checkcase.php?ucn="+ucn,function (response) {
//	if (response=="NO MATCH") { alert("NO MATCH"); return ""; 
//        } else {
//            var arr=response.split('\n');
//            if ( arr.length-2==1) { // one match
//		$("#"+x).val(arr[0]);
//	    } else {  // more responses, must pick one...
//		var ht='';
//		for (i=0;i<arr.length;i++) {
//                    ht+="<div onClick=WorkFlowSetCaseVal('"+x+"','"+arr[i]+"');>"+arr[i]+"</div>";
//		}
//		$("#wf_case_pick").html(ht);
//		$("#wf_case_pick").dialog();
//                  
//            }
//    	    return response;
//        }
//    });
}



function WorkFlowAddToggle() {  
    if ($("#wf_an_order").attr('checked')) {
        $("#wf_order_details").show();
    } else {
        $("#wf_order_details").hide(); 
    }
}



var wfchosen;

// WorkFlowDoIt performs the action for a given document selected in the neighboring drop-down

function WorkFlowDoIt(id,ucn,choice) {
    choice = typeof choice !== 'undefined' ? choice : $(this).data('choice');
    //var choice = $(this).data('choice');
    if (choice=="") {
        return;
    }
    
    id = $(wfchosen).data('doc_id');
    //if (id == undefined) {
    //    id = $(wfchosen).data('doc_id');
    //}
    if (ucn == undefined) {
        ucn = $(wfchosen).data('ucn');
    }
    
    $("#wfmenu").hide();
    $("#wfmenufo").hide();  // one of the three...
    $("#wfmenurem").hide();  // ditto
    var t=new Date().getTime();
    switch(choice) {
        //case "View":
        //    PopUpURL('workflow/view.php?docid='+id+'&t='+t,'View');
        //    break;
        case "viewetc":
            window.location.href="/orders/index.php?ucn=" + ucn + "&docid=" + id;
            break;
        //case "Annotate":
        //    SignOrder(ucn,id,ROLE);
        //    break;
        //case "parties & Addresses":
        //    PopUpURL('workflow/parties.php?docid='+id+'&close=1&t='+t,'Parties');
        //    break;
        //case "Edit Document":
        //    PopUpURL('workflow/edit.php?docid='+id+'&t='+t,'Edit');
        //    break;
        case "settings":
            HandleAdd('',id,'');
            break;
        case "reject":
            DisplayWorkFlowRejectDialog(id);
            break;
        //case "Enveloper for Parties":
        //    PopUpURL('workflow/envelopes.php?docid='+id,'Envelopes');
        //    break;
        case "transfer":
            HandleTransfer(id);
            break;
        case "flag":
        	DoWorkFlowFlag(id);
        	break;
        case "finish":
            WorkFlowFinish(id);
            break;
        case "revert":
            var thisRow = $(wfchosen).closest('tr');
            var efileStat = $(thisRow).find('.efileStat').text();
            if ((efileStat == "Q") || (efileStat == "Y") || (efileStat == "S")) {
                showDialog("Already e-Filed","This document has already been submitted for e-Filing, and cannot be reverted.");
                return false;
            }
            var mailStat = $(thisRow).find('.mailStat').text();
            if (mailStat == "Y") {
                showDialog("Already Mailed","Mailing has already been confirmed on this document.  Please ensure that any updated documents are re-mailed.");
            }
    
            WorkFlowRevert(id);
            break;
        case "delete":
        	WorkFlowDelete(id);
            break;
        default:
            alert('Error: unknown action '+choice);
    }
}


function WorkFlowMenuActionButton() {
    if (wfchosen==this) {
        $("#wfmenu").toggle();
    } else {
        $(".wfmenu").hide();
        $("#wfmenu").show().position({my: "left top",at: "right top", of: this});
        // need code here to grey out/enable buttons based on status
        //	$("#wfdocedit").addClass("ui-state-disabled");
        //	$("#wfdocemail").addClass("ui-state-disabled");
        //	$("#wfdocefile").addClass("ui-state-disabled");
        //	$("#wfdoccomplete").addClass("ui-state-disabled");
    }
    wfchosen=this;
}


// button action for form orders...launch the appropriate popup...

function WorkFlowMenuActionButtonFormOrder() {
    if (wfchosen==this) {
        $("#wfmenufo").toggle();
    } else {
        $(".wfmenu").hide();
        $("#wfmenufo").show().position({my: "left top",at: "right top", of: this});
        //$("#wfmenufo").show();
    }
    wfchosen=this;
}

function WorkFlowMenuActionButtonReminder() {
    if (wfchosen==this) {
        $("#wfmenurem").toggle();
    } else {
        $(".wfmenu").hide();
        $("#wfmenurem").show().position({my: "left top",at: "right top", of: this});
    }
    wfchosen=this;
}


function HearingRequestAccept() {
    var id=wfchosen.id.substring(1);
    $("#wfmenuhrg").dialog('close');
    i=FindWorkQueueIndex(id);
    var wqdata=$.parseJSON(WORKQUEUES[i][33]);
    var data={ accepted: 1,doc_id:id,email:wqdata.email,division:wqdata.division,ucn:wqdata.ucn,block_id:wqdata.block_id,dscr:wqdata.dscr,ealert:1};
//wqdata: ucn,email,division,block_id,dscr,ealert,name,location,date,time
    $.ajax({url:'/icms/workflow/schedhrg.php',
            data:data }).done(function (msg) {
		if (msg!="OK") {
            alert('ERROR: '+msg);
		} else {  // refresh the work queue tabs..
            var t=new Date().getTime();
            $("#wfcount").load('workflow/wfcount.php?t='+t,LoadErr);
            $("#Workflow").load('workflow/wfshow.php?t='+t,LoadErr);
		}
    });
}


function HearingRequestDeny() {
    var id=wfchosen.id.substring(1);
    $("#wfmenuhrg").dialog('close');
    i=FindWorkQueueIndex(id);
    var wqdata=$.parseJSON(WORKQUEUES[i][33]);
    var data={ accepted: 0,doc_id:id,email:wqdata.email,division:wqdata.division,ucn:wqdata.ucn,block_id:wqdata.block_id,dscr:wqdata.dscr,ealert:1};
    $.ajax({
        url:'/icms/workflow/schedhrg.php',
        data:data }).done(function (msg) {
        if (msg!="OK") {
            alert('ERROR: '+msg);
        } else {  // refresh the work queue tabs..
            var t=new Date().getTime();
            $("#wfcount").load('workflow/wfcount.php?t='+t,LoadErr);
            $("#Workflow").load('workflow/wfshow.php?t='+t,LoadErr);
        }
    });
}


function WorkFlowMenuActionButtonHearingRequest() {
    wfchosen=this;
    var id=wfchosen.id.substring(1);
    i=FindWorkQueueIndex(id);
    var data=$.parseJSON(WORKQUEUES[i][33]);
    var details='<table><tr><td>UCN:<td>'+data.ucn+'<tr><td>Requestor:<td>'+data.name+' &lt;'+data.email+'&gt;<tr><td>Hearing:<td>'+data.dscr+
        '<tr><td>Location:<td>'+data.location+'<tr><td>Date:<td>'+data.date+'<tr><td>Time:<td>'+data.time+'</table>';
    $("#wfmenuhrg").html(details);
    $("#wfmenuhrg").dialog('open');
}



function WorkFlowRevert(id) {
    var postData = {docid: id};
    $.ajax({
        url: "/workflow/revert.php",
        method: 'POST',
        data: postData,
        async: true,
        success: function(data) {
        	location.reload();
        }
    })
}

function ModifyUpdate(status) {
//   $("#statusmsg").html('update status='+status);
    UPDATEDISABLED=status;
}

// DeleteEntry removes a document from the workflow queue
// in production, this might not be allowed, but
// handy for testing

function DeleteEntry(id) {
    url = "workflow/delete.php";
    postData = {docid : id};
    $.ajax({
        url : url,
        data : postData,
        async: false,
        success: function (data) {
        	$("#doc-" + id).hide();
        }
    });
}


// WorkFlowFinish sets the finished flag for the document, which "hides" it.

function WorkFlowFinish(id) {
    $('#dialogSpan').html("Are you sure you wish to mark this item complete?");
    $('#dialogDiv').dialog({
        resizable: false,
        minheight: 150,
        width: 500,
        modal: true,
        title: 'Confirm Completion',
        buttons: {
            "Yes": function() {
                $(this).dialog( "close" );
                DoWorkFlowFinish(id);
                return false;
            },
            "No": function() {
                $(this).dialog( "close" );
                return false;
            }
        }
    });
}

function WorkFlowDelete(id) {
    $('#dialogSpan').html("Are you sure you wish to delete this item?");
    $('#dialogDiv').dialog({
        resizable: false,
        minheight: 150,
        width: 500,
        modal: true,
        title: 'Confirm Deletion',
        buttons: {
            "Yes": function() {
                $(this).dialog( "close" );
                DeleteEntry(id);
                return false;
            },
            "No": function() {
                $(this).dialog( "close" );
                return false;
            }
        }
    });
}

function DoWorkFlowFinish(id) {
    var url = "workflow/finish.php";
    var postData = {docid : id};
    $.ajax({
        url : url,
        data : postData,
        success: function (data) {
        	$("#doc-" + id).hide();
        }
    });
}

function DoWorkFlowFlag(id) {
    var url = "workflow/flag.php";
    var postData = {docid : id};
    $.ajax({
        url : url,
        data : postData,
        success: location.reload()
    });
}


// SignOrder makes a pop-up containing the signature window...

function SignOrder(ucn,wfid,role) {
   // 1.45x gets me original size on my 30" dell 2560x1600 monitor
    x=612;
    y=792;
    x=parseInt(x)*1.48;
    y=parseInt(y)*1.48;
    var path="workflow/sign.php?id="+wfid+"&role="+role+"&ucn="+ucn;
//TESTING
    PopUpXY(path,'Sign',x,y);
}


// FindWorkQueueIndex finds the index for a specified doc_id in the
// WORKQUEUES array...

function FindWorkQueueIndex(id) {
    var myid=0;
    for (i=0;i<WORKQUEUES.length;i++) {
        if (WORKQUEUES[i]['doc_id']==id) {
            return i;
        }
    }
   return -1;
}

var TRANSFERID;

// HandleTransfer displays the transfer dialog box, setting the TRANSFERID in the
// process so if the Transfer button is it, the correct doc will be selected

var DIALOG; // needed for IE9...

///  HERE  ///
function HandleTransfer(id) {
    UPDATEDISABLED=1;  // disable workflow page updates
    // Seems kinda silly, 
    
    DIALOG=$("#wf_xferdialog").dialog({
        width:450,
        height:200,
        title: "Select Queue"
    });
    
    $("#wf_xferid").val(id);
    var i = FindWorkQueueIndex(id);
    $("#wf_xferfromqueue").val(WORKQUEUES[i]['queue']); // current queue
}


// WorkFlowTransfer handles the display after a transfer has been processed

function WorkFlowTransfer() {
    DIALOG.dialog("close");
    loadTab('workflow');
    UPDATEDISABLED=0;  // re-enable workflow page updates
}


// HandleShowFinished is called by the Show Finished button
// it creates a new tab showing older orders
//
//function HandleShowFinished(queue) {
//   var t=new Date().getTime();
//   AddTab("workflowtabs",'Finished items from '+queue+"'s Queue",'/icms/workflow/showfinished.php?t='+t+'&queue='+queue,true);
//}



// HandleAdd is the function called by the Add Document buttons on the Workflow
// Tabs, the Action/Edit Settings button on a workflow page, 
// and also by the "add to workflow" option on a document view
// If from workflow, queue will be set
// If from Action/Edit Setting, wfid will be set
// If from docview, docref will be set.

function HandleAdd(queue,wfid,docref) {
    UPDATEDISABLED=1;  // disable workflow page updates for now
    
    var foo = $('#wf_add_dialog');
    
    DIALOG=$("#wf_add_dialog").dialog({
        width:690,
        height:550,
        open: function(event){
            var foo = $(this).parents('.ui-dialog');
            //$(this).parents(".ui-dialog").first().shim();
        },
        close: function(event){
            $(this).dialog("close");
            //$(this).parents(".ui-dialog").first().shim('close');
        },
        resize: function(event){
            //$(this).parents(".ui-dialog").first().shim('resize');
        },
        drag: function(event){
            //$(this).parents(".ui-dialog").first().shim('resize');
        }
    });
    
    if (wfid!='') { // this is an EDIT...
        var myid=0;
        for (i=0;i<WORKQUEUES.length;i++) {
            if (WORKQUEUES[i]['doc_id']==wfid) {
                myid=i;
                break;
            }
        }
        
        queue=WORKQUEUES[myid]['queue'];
        $("#wf_id").val(wfid);
        if(queue != ''){
            $("#wf_queue option[value="+queue+"]").prop('selected',true);
        }
        $("#wf_ucn").val(WORKQUEUES[i]['ucn']);
        $("#wf_title").val(WORKQUEUES[i]['title']);
        $("#wf_upload_row").hide();
        $("#wf_priority option[value="+WORKQUEUES[i]['color']+']').prop('selected',true);
        $("#wf_comments").val(WORKQUEUES[i]['comments']);
        $("#wf_due_date").datepicker({
            showOn:"button",
            buttonImage: "/style/images/calendar.gif",
            buttonImageOnly: true
        });
        $("#wf_due_date").val(PrettyDate(WORKQUEUES[i]['due_date']));
        $("#wf_doctype").val(WORKQUEUES[i]['doc_type']);
        if (WORKQUEUES[i]['doc_type']=="PROPORDER") {
            $("#wf_an_order").attr('checked',true)
            $("#wf_an_order").show();
        } else if (WORKQUEUES[i]['doc_type']=="FORMORDER") {
            $("#wf_an_order").attr('checked',false)
            $("#wf_an_order_span").hide();
        } else {
            $("#wf_an_order").removeAttr('checked');
            $("#wf_an_order_span").show();
        }
        
        $("#wf_docket_as option[value="+WORKQUEUES[i]['docket_as']+"]").prop('selected',true);
        WorkFlowAddToggle();
    } else {
        // select the option that matches the queue you clicked on...
        if(queue != ''){
            $("#wf_queue option[value="+queue+"]").prop('selected',true);
        }
        $("#wf_ucn").val('');
        $("#wf_title").val('');
        $("#wf_priority").val([]);
        $("#wf_comments").val('');
        $("#wf_an_order").removeAttr('checked');
        if (docref!="") { // a docref
            $("#wf_upload_row").hide();
            $("#wf_docref").val(docref);
            $("#wf_ucn").val((docref.split('.'))[0]);
            $("#wf_title").focus();
        } else {
            $("#wf_upload_row").show();
        }
        $("#wf_docket_as").val([]);
        $("#wf_id").val('');
        $("#wf_due_date").datepicker({
            showOn:"button",
            buttonImage: "/style/images/calendar.gif",
            buttonImageOnly: true
        });
        var nextweek=new Date();
        nextweek.setDate(nextweek.getDate()+7);
        $("#wf_due_date").datepicker('setDate',nextweek);
    }
}

function HandleAddComment(){
	var ucn = $(this).data('ucn');
	var title = $(this).data('title');
	var queue  = $(this).data('queue');
	var comment  = $(this).data('comment');
	var wf_id = $(this).data('wfid');
	var queue = $(this).data('queue');
	
    DIALOG=$("#wf_addcomment_dialog").dialog({
        width:650,
        height:385,
        open: function(event){
            var foo = $(this).parents('.ui-dialog');
            //$(this).parents(".ui-dialog").first().shim();
        },
        close: function(event){
            $(this).dialog("close");
            //$(this).parents(".ui-dialog").first().shim('close');
        },
        resize: function(event){
            //$(this).parents(".ui-dialog").first().shim('resize');
        },
        drag: function(event){
            //$(this).parents(".ui-dialog").first().shim('resize');
        }
    });
    
    $("#wf_add_comment_ucn").html(ucn);
    $("#wf_add_comment_title").html(title);
    $("#wf_add_comment_comments").val(comment);
    $("#add_comment_wf_id").val(wf_id);
    $("#add_comment_queue").val(queue);
}


// HandleWorkFlowAddCaseChange changes the dropdown for docket_as to match the case

function HandleWorkFlowAddCaseChange() {
    var el=$("#wf_docket_as");
    var ucn=$("#wf_ucn").val();
    var countynum=ucn.substring(0,2);
    var casetype=ucn.substring(8,10);
    casetype=casetype.toUpperCase();
    $("#docket_as option:gt(0)").remove();
    // alternatively el.empty();  // empty out the current values
    var txt="";
    for (i=0;i<EFILING_CODE.length;i++) {
	if (EFILING_CODE[i][0]==countynum && EFILING_CODE[i][1]==casetype) {
            el.append($("<option></option>").attr("value",EFILING_CODE[i][2]).text(EFILING_CODE[i][3]));
	}
    }
}


// HandleWorkFlowCaseFind handles the Find button being clicked on
//                        the workflow add/edit dialog box...

function HandleWorkFlowCaseFind() {
    WorkFlowCheckCase('wf_ucn'); // find the appropriate case #
}


// WorkFlowFinishAdd is called after an item is added to the workflow system
//                   via the ICMS dialog...

function WorkFlowFinishAdd() {
    UPDATEDISABLED=0;  // re-enable workflow page updates
    $("#wf_add_dialog").dialog("close"); // close the dialog box...
    loadTab('workflow');
    //var t=new Date().getTime();
    //$("#wfcount").load('workflow/wfcount.php?t='+t);
    //$("#Workflow").load('workflow/wfshow.php?t='+t);
}



// DisplayWorkFlowRejectDialog displays the workflow rejection dialog for a given id..


function DisplayWorkFlowRejectDialog(wfid) {
    UPDATEDISABLED=1;  // disable workflow page updates for now
    DIALOG=$("#wf_reject_dialog").dialog({width:640,height:275});
    var myid=0;
    for (i=0;i<WORKQUEUES.length;i++) {
        if (WORKQUEUES[i]['doc_id']==wfid) {
            myid=i;
            break;
        }
    }
    $("#wf_reject_id").val(wfid);
    $("#wf_reject_creator").val(WORKQUEUES[myid]['creator']);
    $("#wf_reject_queue").val(WORKQUEUES[myid]['queue']);
    $("#wf_reject_ucn").val(WORKQUEUES[myid]['ucn']);
}


// WorkFlowFinishReject does the cleanup after the WorkFlowReject dialog closes...

function WorkFlowFinishReject() {
   UPDATEDISABLED=0;  // re-enable workflow page updates
   $("#wf_reject_dialog").dialog("close"); // close the dialog box...
   var t=new Date().getTime();
   $("#wfcount").load('workflow/wfcount.php?t='+t);
   $("#Workflow").load('workflow/wfshow.php?t='+t);   
}



function WorkFlowSelectAll() { // selects all rows in the table it's in..
    var bid = this.id;
    var newval = $(this).attr('checked');
    var tid = bid.replace('selectall','maintable');
    $('#'+tid+' tbody td input:checkbox').each(function () {
        if (newval=='checked') {
            $(this).attr('checked',newval);
        } else {
            $(this).removeAttr('checked');
        }
    });
}


// WorkFlowSignFormOrder is called by the sign button for a specific 
// workflow document.

function WorkFlowSignFormOrder(docid,signas) {
    $.ajax({
        url: "/workflow/signformorder.php",
        data: { docid: docid, signas:signas},
        async: false,
        success: function(data) {
            return false;
        }
    });
}


function WorkFlowBulkSign(qid) { // selects all rows in the table it's in..
    // qid is the page that this button is on...
    var tid='wf_maintable_'+qid;
    $("#wf_bulksign_status_"+qid).html('<img src=/icms/jvsicons/spinner.gif>');
    var signed = 0;
    var signcheck = $('#' + tid).find('.signCheck:checked');
    var bulksign = $(signcheck).length;
    if (bulksign == 0) {
        return false;
    };

    var esigSelect = $('#workflow').find('.signAs').first();
    var optCount = $(esigSelect).find('option').size();
    if (optCount == 2) {
        var signas = $(esigSelect).val();
    } else {
        $(esigSelect).show();
        return false;
    }
    
    $(signcheck).each(function () {
        var docid=$(this).val();
        $.ajax({
            url: "/workflow/signformorder.php",
            data: { docid: docid, signas:signas},
            method: 'POST',
            async: true,
            success: function(data) {
                var json = $.parseJSON(data);
                if (json.status == "Success") {
                    signed++;
                }
                if (signed == bulksign) {
                    // All have been done.
                    location.reload();
                }
            }
        });
    });
    
    return false;
}


function WorkFlowBulkEfile(qid) { // selects all rows in the table it's in..
    // qid is the page that this button is on...
    var tid='wf_maintable_'+qid;
    $("#wf_bulksign_status_"+qid).html('<img src="/jvsicons/spinner.gif">');
    var filed = 0;
    var filecheck = $('#' + tid).find('.fileCheck:checked');
    var bulkfile = $(filecheck).length;
    if (bulkfile == 0) {
        return false;
    };
    
    $(filecheck).each(function () {
        var docid=$(this).val();
        $.ajax({
            url: "/workflow/efile.php",
            data: { docid: docid },
            method: 'POST',
            async: true,
            success: function(data) {
                var json;
                if (data.status == undefined) {
                    json = $.parseJSON(data);
                } else {
                    json = data;
                }
                if (json.status == "Success") {
                    filed++;
                }
                if (filed == bulkfile) {
                    // All have been done.
                	location.reload();
                }
            }
        });
    });
    
    return false;
}



function updateWfCount () {
    $.ajax({
        url: '/workflow/wfcount.php',
        async: true,
        success: function(data) {
            var json = $.parseJSON(data);
            $('#wfcount').html(json.wfcount);
        }
    })
}


$(document).ready(function() {
    $(document).on('click','.wf_add_save_btn', function(e) {
        e.preventDefault();
        
        $('#wf_add_form').ajaxSubmit({
            async: false,
            success: function(data) {
                $('#wf_add_dialog').dialog('close');
                showDialog('Success', data.message);
                window.location.reload();
            }
        });
        
        return true;
    });
    
    $(document).on('click','.wf_add_comment_save_btn', function(e) {
        e.preventDefault();
        
        $('#wf_add_comment_form').ajaxSubmit({
            async: false,
            success: function(data) {
                $('#wf_addcomment_dialog').dialog('close');
                showDialog('Success', data.message);
                window.location.reload();
            }
        });
        
        return true;
    });
    
    
    $('.queuexfer').click(function() {
        $('#wf_xferdialog').dialog("close");
        var fromQueue = $('#wf_xferfromqueue').val();
        var toQueue = $('#wf_xferqueue').val();
        
        if(!toQueue || (toQueue == "")){
    		showDialog("Error", "You must select a valid workflow queue.", 'errorDialog');
    		return false;
    	}
        
        var docid = $('#wf_xferid').val();
        var postData = {fromqueue : fromQueue, toqueue: toQueue, docid : docid};
        var url = "/workflow/transfer.php";
        $.ajax({
            url: url,
            data: postData,
            success: function(data) {
            	window.location.reload();
            }
        });
    });
    
    $('.bulkqueuexfer').click(function() {
        $('#wf_bulkxferdialog').dialog("close");
        var thisq = XFERQUEUE;
        var tid='wf_maintable_'+thisq;
        var xferred = 0;
        var xfercheck = $('#' + tid).find('.xferCheck:checked');
        var bulkxfer = $(xfercheck).length;
        var foo = $('#wf_bulkxferqueue');
        var toqueue = $('#wf_bulkxferqueue').val();
        
        if(!toqueue || (toqueue == "")){
    		showDialog("Error", "You must select a valid workflow queue.", 'errorDialog');
    		return false;
    	}
        
        if (bulkxfer == 0) {
            return false;
        };
        
        $(xfercheck).each(function () {
            var docid=$(this).val();
            $.ajax({
                url: "/workflow/transfer.php",
                data: { docid: docid, toqueue: toqueue },
                method: 'POST',
                async: true,
                success: function(data) {
                    var json;
                    if (data.status == undefined) {
                        json = $.parseJSON(data);
                    } else {
                        json = data;
                    }
                    if (json.status == "Success") {
                        xferred++;
                    }
                    if (xferred == bulkxfer) {
                        // All have been done.
                    	window.location.reload();
                    }
                }
            });
        });
        return true;
    });
    
    
    $('.rejectBtn').click(function() {
        $('#wf_reject_dialog').dialog("close");
        var wf_reject_comments = $('#wf_reject_comments').val();
        var wf_reject_creator = $('#wf_reject_creator').val();
        var wf_reject_queue = $('#wf_reject_queue').val();
        var wf_reject_ucn = $('#wf_reject_ucn').val();
        var docid = $('#wf_reject_id').val();
        var postData = {wf_reject_comments : wf_reject_comments, wf_reject_creator: wf_reject_creator, wf_reject_queue : wf_reject_queue,
            wf_reject_ucn: wf_reject_ucn, wf_reject_id : docid};
        var url = "/workflow/wfreject.php";
        $.ajax({
            url: url,
            data: postData,
            success: function(data) {
            	window.location.reload();
            }
        });
    });
    
    $('.rejectBtnOW').click(function() {
    	$.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait </h1>', fadeIn: 0});
        var wf_reject_comments = $('#wf_reject_comments').val();
        var wf_reject_creator = $('#wf_reject_creator').val();
        var wf_reject_queue = $('#wf_reject_queue').val();
        var wf_reject_ucn = $('#wf_reject_ucn').val();
        var docid = $('#wf_reject_id').val();
        var postData = {wf_reject_comments : wf_reject_comments, wf_reject_creator: wf_reject_creator, wf_reject_queue : wf_reject_queue,
            wf_reject_ucn: wf_reject_ucn, wf_reject_id : docid};
        var url = "/workflow/wfreject.php";
        $.ajax({
            url: url,
            data: postData,
            success: function(data) {
            	$.unblockUI();
            	showDialog("Rejection Successful", "Document has been rejected and will be removed from workflow queue.");
            	window.location = '/workflow.php';
            }
        });
    });
});
