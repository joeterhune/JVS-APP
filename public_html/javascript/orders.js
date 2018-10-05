$(document).ready(function() {
    EDITORHEIGHT = 400;
    PDFIFRAMEHEIGHT = 400;
    MAILIFRAMEHEIGHT = 400;
    $(document).on('click','.xmlefilebutton',function() {
        //UpdateEmailView($(this).closest('.orderDiv')); Changing this...
    	OrderEfileConfirm($(this).closest('.orderDiv'));
    });
    $(document).on('click','.xmlbutton',OrderShowButton);
     // Handle order buttons
    $(document).on('click','.previewbutton',function() {
        var pane = $(this).closest('.orderDiv');
        UpdateFormPreview(pane);
    });
    $(document).on('click','.xmlsignbutton',function () {
    	var pane = $(this).closest('.orderDiv');
    	var isOrder = $(pane).find('.isOrder').val();
    	if(isOrder == 0){
	    	var pane = $(this).closest('.orderDiv');
	    	var editor = $(pane).find('.preview-ta').ckeditor().editor;
	    	editor.execCommand('AddSignature');
    	}
    	else{
    		selectSign($(this).closest('.orderDiv'));
    	}
    });
    $(document).on('click','.orderviewbutton',function() {
    	var pane = $(this).closest('.orderDiv');
    	$(pane).find('.previewsave').first().trigger('click');
        UpdatePDFView($(this).closest('.orderDiv'));
    });
    $(document).on('click','.xmlmailbutton',function() {
        UpdateMailView($(this).closest('.orderDiv'));
    });
    $(document).on('click','.mailConfirm',function() {
        OrderMailConfirm($(this).closest('.orderDiv'))
    });
    $(document).on('click','.emailConfirm',function() {
        OrderEmailConfirm($(this).closest('.orderDiv'));
    });
    $(document).on('click','.efileConfirm',function() {
        OrderEfileConfirm($(this).closest('.orderDiv'));
    });
    $(document).on('click','.doTransfer',function() {
    	var pane = $(this).closest('.orderDiv');
        OrderTransferConfirm(pane);
    }); 
    $(document).on('change','.signAs',function() {
    	var pane = $(this).closest('.orderDiv');
    	var signcheck = $(".wfqueue").find('.signCheck:checked');
        var bulksign = $(signcheck).length;
        
        //We're bulk signing....
        if(bulksign > 0){
        	var signed = 0;
        	var esigSelect = $('#workflow').find('.signAs').first();
        	var signas = $(esigSelect).val();
        	
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
    	var isOrder = $(pane).find('.isOrder').val();
    	if(isOrder == 0){
    		var pane = $(this).closest('.orderDiv');
        	var editor = $(pane).find('.preview-ta').ckeditor().editor;
        	editor.execCommand('AddSignature');
    	}
    	else{
    		eSignOrder($(this).closest('.orderDiv'));
    	}
    });
    $(document).on('click','.finishbutton',function() {
    	var pane = $(this).closest('.orderDiv');
    	var docid = $(pane).find('.docid').val();
    	WorkFlowFinish(docid);
    });   
    $(document).on('click','.chooseNewAddr', function() {
        var pane = $(this).closest('.orderDiv');
        $(pane).find('input.newFromAddr').show().focus();
        $(pane).find('button.newAddrSet').show();
    });
    $(document).on('click','.newAddrSet', function() {
        var pane = $(this).closest('.orderDiv');
        var newAddr = $(pane).find('input.newFromAddr').val();
        // Still need to validate the address
        if (validEmail(newAddr)) {
            $(pane).find('input.fromAddr').val(newAddr);
            $(pane).find('span.fromAddr').html(newAddr);
            showDialog("Updated Email Address", "The messge will be sent with a \"from\" address of " + newAddr + ".");
            return true;
        } else {
            showDialog("Invalid Email Address","Please enter a valid email address.");
            return false;
        }
    });
});
function selectSign () {
    var esigSelect = $('.signAs');
    var pane = $(".orderDiv");
    var optCount = $('.signAs option').size();
	if (optCount == 2) {
		// Only 1 option and it's automagically selected.  Do the signing thing
		eSignOrder(pane);
		return true;
	}
    // More than 1 available signature.  Show the select
	//$(esigSelect).css("margin-bottom", "1%");
	$(".signAsBox").show();
    $(esigSelect).show();
	return false;
}

// getFormJSON returns the JSON version of the form data.
function getformJSON(top) {
    var formid = {name : 'form_id', value:  $(top).find('select.formid').val()};
    var formarr = $(top).find('.formdiv').first().serializeArray();
    formarr.push(formid);
    var outstr='{';
    $.each(formarr,function (i,field) {
        if (i != 0) {
            outstr += ",\n";
        }
        var v = field.value;
        if (v != undefined) {
            v = v.replace(/(\n|\<br\>)/g,"\\n");
            v = v.replace(/\r/g,"");
            v = v.replace(/"/g, "\\\"");
            if (v.substr(0,1)!='{' && v.substr(0,1)!='[') {
                v='"'+v+'"';
            }
            outstr+='"'+field.name+'": '+v;   
        }
    });
    outstr+="}";
    //$(orderDiv).find('.previewbutton,.partiesbutton').attr('disabled',false);
    return(outstr);
}
// NOTE: no formvalidate() call taking place... 
function SaveToWorkflow(pane,keepsigned) {
    var editor = $('.preview-ta').ckeditor().editor;
    /*if (typeof keepsigned === "undefined" || keepsigned === null) {
        keepsigned = 0;
    }
    if (!editor.checkDirty()) {
        return;
    }
    
    // NOW add to workflow OR update...  Also delete any signatures and generated files.
    //var caption = $(pane).find('.wfcasestyle').val();
    //var cclist = $('#cc_list').val();
    //var cclist = $(pane).find('.cclistjson').val();
    
    var ucn = $(pane).find('.ucn').val();
    var docid = $(pane).find('.docid').val();
    
    var formjson = getformJSON(pane);
    var formobj = JSON.parse(formjson);
    
    //formobj.case_caption = caption;
    formobj.ucn = ucn;
    //formobj.cc_list = cclist;
    
    if (formobj.order_html == undefined) {
        var order_html = editor.getData();
        formobj.order_html = order_html;
    }
    
    var isOrder = $(pane).find('.isOrder').val();
    if (isOrder == 0) {
        // Need to be sure we keep a copy of the original HTML
        if (formobj.orig_html == undefined) {
            var orig_html = $(pane).find('.orig_html').val();
            formobj.orig_html = orig_html;
        }
    }*/
    
    var order_html = editor.getData();
    var ucn = $('#ucn').val();
    var docid = $('#docid').val();
    var isOrder = $('#isOrder').val();
    var form_name = $("#form_name").val();
    var form_id = $("#form_id").val();
    
    var postData = { docid: docid, isOrder: isOrder, ucn: ucn, order_html: order_html, form_id : form_id, form_name : form_name };
    $.ajax({
        url: "/workflow/wfaddformorder.php",
        method: 'POST',
        async: false,
        data: postData,
        success: function(data) {
            var docid = data.docid;
            $('#docid').val(docid);
        }
    });
    
    editor.resetDirty();
    return docid;
}
// UpdatePDFView re-gens the PDF file based on the form data.
function UpdatePDFView(pane) {
    var editor = $(pane).find('.preview-ta').ckeditor().editor;
    var isOrder = $(pane).find('.isOrder').val();
    if (isOrder == 0) {
        SaveToWorkflow(pane,1);
    }
    var sigdiv = $(pane).find('.signaturediv').html();
    var formhtml;
    formhtml = editor.getData();
    var docid = $(pane).find('.docid').val();
    var ucn = $(pane).find('.ucn').val();
    var formname;
    if($('input[name="orderTitle"]').length > 0){
    	if($('input[name="orderTitle"]').val()){
    		formname = $('input[name="orderTitle"]').val();
    	}
    	else{
    		formname = $(pane).find('.form_name').val();
    	}
    }
    else{
    	formname = $(pane).find('.form_name').val();
    }

    postData = {formhtml: formhtml, ucn: ucn, sigdiv: sigdiv, docid: docid, formname: formname};
    $.ajax({
        url: "/orders/genpdf.php",
        data: postData,
        async: false,
        method: 'POST',
        success: function(data) {
            var json = $.parseJSON(data);
            var signed = $(pane).find('.pdf');
            var iframe = $(pane).find('.pdfiframe');
            var docid = $(pane).find('.docid').val();
            $(signed).val(json.filename);
            $(iframe).attr('src',json.filename);
            docid = $(pane).find('.docid').val();
            //Now let's enable the Mail and File buttons
            $(pane).find('.xmlmailbutton,.xmlefilebutton').attr('disabled',false);
        }
    });
    return;
}
function showIframe(pane) {
    // Keep the file name to potentially not have to regenerate it each time.
    var signed = $(pane).find('.signeddoc');
    var iframe = $(pane).find('.pdfiframe');
    var pdf = $(pane).find('.pdf').first().val();
    $(iframe).attr('src',pdf);
}
function UpdateMailView(pane) {
    var snail = $(pane).find(".pt_needsnail").val();
    if ($(pane).find(".pt_needsnail").val()=="0") {
        $('#dialogSpan').html("All listed parties have specified email addresses.  No snail mail is needed.");
        $('#dialogDiv').dialog({
            resizable: false,
            minheight: 150,
            width: 500,
            modal: true,
            title: 'No Snail Mail Needed',
            buttons: {
                "OK": function() {
                    $(this).dialog( "close" );
                    return false;
                }
            }
        });
        $(pane).find(".mailpdfiframe").attr('src',"");
    } else {
        var signed = $(pane).find('.pdf').val();
        if (signed == "") {
            showDialog('Order Not Signed','Please ensure that the order is signed and that you have reviewed the PDF before attempting to mail.');
            return false;
        }
        var docid = $(pane).find('.docid').val();
        var postData = { docid: docid, signed: signed};
        $.ajax({
            url: "/workflow/envelopes.php",
            data: postData,
            async: false,
            success: function(data) {
                var srcfile = data.file;
                $(pane).find('.mailpdfiframe').attr('src', srcfile);
            }
        });
    }
}
function UpdateEmailView(pane) {
    // Check to be sure the document is signed before allowing this.
    var signed = $(pane).find('.pdf').val();
    if (signed == "") {
        showDialog('Order Not Signed','Please ensure that the order is signed and that you have reviewed the PDF before attempting to e-mail or e-File.');
    }
}
function UpdateEsigStatus(pane) {
    var sigdiv=$(pane).find(".signaturediv").html();
    var str;
    if (sigdiv != "") {
        str = "<font color=green>SIGNED</font> ";
    }
    $(pane).find(".esigstatus").html(str);
    $(pane).find('.isSigned').val(1);
}
function OrderHandleView(pane) {
    if (!formvalidate()) {
        return;
    }
    var formid=$("select.formid option:selected").val();
    if (formid != "") {
        $(pane).find('.previewbutton,.partiesbutton').attr('disabled',false);   
    }
    var formdata=$(pane).find(".formdiv").serialize();
    var docid = $(pane).find('.docid').val();
    var ucn = $(pane).find('.ucn').val();
    $.post("/orders/ordersave.php",formdata,function (data) {
        if (data!="OK") {
            alert('xmlsave: '+data);
        }
    });
    $(pane).find(".xmlstatus").html('<i>Re-generating...please wait...</i>');
    window.location.replace("/orders/index.php?ucn=" + ucn  +
                            "&formid="+formid+"&docid=" + docid);
}
function OrderDisplayFields(pane) {
    var formsel=$(pane).find("select.formid option:selected").val();
    var formdiv = $(pane).find('.formdiv').first();
    var docid = $(pane).find('.docid').val();
    var ucn = $(pane).find('.ucn').val();
    var signAs = $(pane).find(".signAs option:selected").val();
	if(signAs == "")
	{
		signAs = $(pane).find(".signAs  option:not(:selected)").first().val();
	}
    if (formsel != "") {
        $(pane).find('.previewbutton,.partiesbutton').attr('disabled',false);
        var t=new Date().getTime();
        var postData = {ucn: ucn, formid: formsel, docid: docid, t: t, signAs: signAs};
        $.ajax({
            url: '/orders/orderfields.php',
            data: postData,
            async: false,
            success: function(data) {
                var json = $.parseJSON(data);
                $(formdiv).html(json.html);
                OrderHandleFormLoading(pane);
            }
        });
    } else {
        $(formdiv).html('');
    }
    var cc = $(pane).find('.cclistjson');
    var ccjson = $(pane).find('.cclistjson').val();
    $(pane).find('.cc_list').val(ccjson);
}
function OrderHandleFormLoading(pane) {
    //UpdateButtons(pane);
    // set casestyle and cc_list from parties if defined
    if (typeof(UpdateCC_List)=="function") { // we have parties
        UpdateCC_List();
        $(pane).find(".case_style").val($(pane).find(".wfcasestyle").val());
    }
}
// OrderShowParties hides the other tabs, then displays the parties tab...
function OrderShowButton() {
    var but=$(this).data('type');
    var showDiv = but + 'div';
    var foo = $(this).closest('.orderDiv');
    $(this).closest('.orderDiv').find('.buttondiv').each(function(i,e) {
        if ($(e).hasClass(showDiv) && (showDiv != "xmlefilediv")) {
            $(e).show();
        } else {
            $(e).hide();
        }
    });
    return true;
}
// Called after a save on Parties, it re-gens the order...    
function OrderRegenOrder(data,pane) {
    $.unblockUI();
    UpdateFormPreview(pane);
}
// UpdateFormPreview updates the Preview editor window with 
// freshly merged data...
function UpdateFormPreview(pane) {
    var isOrder = $('#isOrder').val();
    var top = pane;

    var cc_list = $("#case_caption").val();
    var case_caption = $("#cclist").val();
    
    var editor = $('.preview-ta').first().ckeditor().editor;
    var postData = { cclist: EncodeURI(cc_list), case_caption: EncodeURI(case_caption) };
    var sigdiv = $('.signaturediv').html();
	SaveToWorkflow(pane);
    if (sigdiv != "") {
        postData.sigdiv = sigdiv;
    }
    if (isOrder == 0) {
        //var formjson = getformJSON(top);
        postData.formData = JSON.stringify(editor.getData());
        $.ajax({
            url: '/orders/merge.cgi',
            data: postData,
            async: true,
            method: 'POST',
            success: function (data) {
                // Enable the sign button after the doc is previewed
                //$(pane).find('.signbutton,.transferbutton').attr('disabled',false);
                //$(editor).val(data.html);
                $(".preview-ta").first().val(data.html);
                return true;
            }
        });
    } else {
        var docid = $('#docid').val();
        postData.docid = docid;
        $.ajax({
            url: '/orders/getPropOrder.php',
            data: postData,
            async: true,
            method: 'POST',
            success: function (data) {
                // Enable the sign button after the doc is previewed
                //$(pane).find('.signbutton,.transferbutton').attr('disabled',false);
                //$(editor).val(data.html);
                $(".preview-ta").first().val(data.html);
                //$(pane).find('.orig_html').val(data.orig_html);
                return true;
            }
        });
    }
}
// eSignOrder is called by pressing the Sign button; it creates an
// appropriate e-sig, updating everything that needs updating...
function eSignOrder(pane) {
    var editor = $('.preview-ta').ckeditor().editor;
    var isOrder = $('#isOrder').val();
    var sigName = $('.signAs option:selected').text();
    
    SaveToWorkflow(pane);
    var selSig = $('.signAs').val();
    var docid = $('#docid').val();
    var postData = { sigName: selSig, docid: docid, isOrder: isOrder, formData: JSON.stringify(editor.getData())  };
    $.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait </h1>', fadeIn: 0});
    $.ajax({
        url: "/orders/genesig.php",
        type: 'POST',
        data: postData,
        success: function (data) {
            var sigdiv = data.sigdiv;
            $('.signaturediv').html(data.sigdiv);    
            UpdateEsigStatus(pane);
            $.unblockUI();
            
            if(isOrder != "0"){
	            postData.sig = JSON.stringify($('.signaturediv').html());
	            $.ajax({
	                url: '/orders/mergeSig.php',
	                data: postData,
	                method: 'POST',
	                success: function (data) {
	                    $(".preview-ta").first().val(data.order_html);
	                    SaveToWorkflow(pane);
	                    return true;
	                }
	            });
            }
            else{
        		var editor = $('.preview-ta').ckeditor().editor;
            	editor.execCommand('AddSignature');
            	SaveToWorkflow(pane);
            	return true;
        	}
        }
    });
}
// OrderTransferConfirm posts to /workflow/transfer.php, transferring the
//                    document and closing the window...
function OrderTransferConfirm(pane) {
	var toqueue = $(".xmltransferqueue option:selected").val();
	
	if(!toqueue || (toqueue == "")){
		showDialog("Error", "You must select a valid workflow queue.", 'errorDialog');
		return false;
	}
	
	var docid = $("#docid").val();
    var postData = { toqueue: toqueue, docid: docid};
    $.ajax({
        url: "/workflow/transfer.php",
        data: postData,
        async: true,
        success: function(data) {
            showDialog("Transfer Successful",data.message);
            window.location = "/workflow.php";
        }
    });
}
function OrderMailConfirm(pane) {
    // user just said they mailed it; we believe them...
    var ts=GetTimeStamp();
    var docid = $(pane).find('.docid').val();
    var postData = {docid: docid};
    $.ajax({
        url: "/orders/confirm_mail.php",
        data: postData,
        async: true,
        method: 'POST',
        success: function(data) {
            return true;
        }
    });
    var mailstat = $(pane).find('.mailstatus');
    $(pane).find('.mailstatus').html('MAILED');
    $(pane).find(".mailedby").val(conf); // set form value...
    //SaveToWorkflow(pane);
}
// OrderEmailConfirm posts the addresses to the emailparties.php script, 
function OrderEmailConfirm(pane) {
    var needemail = $(pane).find(".pt_needemail").val();
    if ($(pane).find(".pt_needemail").val()=="0") {
        $('#dialogSpan').html("No listed parties have specified email addresses.");
        $('#dialogDiv').dialog({
            resizable: false,
            minheight: 150,
            width: 500,
            modal: true,
            title: 'No E-Mail Needed',
            buttons: {
                "OK": function() {
                    $(this).dialog( "close" );
                    return false;
                }
            }
        });
        return false;
    }
    var ucn = $(pane).find('.ucn').val();
    //var formdata=$(pane).find(".pt_emails").serialize(); // get email addresses
    /*var postData = {ucn: ucn};
    var foo = new Array;
    $(pane).find('.svcList').each(function(i,e) {
        // Need to find the associated checkbox to see if we are emailing to this address.
        var group = $(e).data('group');
        var classSel = "group" + group;
        var cb = $(pane).find('input:checkbox.' + classSel);
        if ($(cb).prop('checked') == true) {
            foo.push($(e).val());    
        }
    });
    var pdf = $(pane).find('.pdf').val();
    if (pdf != "") {
        postData.pdf = pdf;
    }
    postData.docid = $(pane).find('.docid').val();
    postData.pt_emails = encodeURIComponent(foo.join(";"));
    postData.formname = $(pane).find('.form_name').val();
    postData.fromAddr = $(pane).find('input.fromAddr').val();
    $.ajax({
        url: "/workflow/emailparties.php",
        data: postData,
        async: false,
        method: 'POST',
        success: function(data) {
            //SaveToWorkflow(pane);
            $('#dialogSpan').html("The document has been e-mailed to the selected parties.");
            $('#dialogDiv').dialog({
                resizable: false,
                minheight: 150,
                width: 500,
                modal: true,
                title: 'E-mailing Complete',
                buttons: {
                    "OK": function() {
                        $(this).dialog( "close" );
                        return false;
                    }
                }
            });
        }
    });
    loadTab('workflow');
    return true;*/
    var casenum = ucn;
    var docid = $(pane).find('.docid').val();
    var pdf = $(pane).find('.pdf').val();
    var tabName = "case-" + casenum;
    createTab(tabName, casenum, 'casetop', 'caseTab', 1);
    var esTabName = tabName + '-eservice';
    createTab(esTabName, 'e-Service', tabName, 'innerPane', 0);
    $('#\\#' + tabName + "_link").trigger('click');
    //var postData = {case: casenum, tab: esTabName, show: 1, doc_id: docid};
    var postData = { case: casenum, tab: esTabName, show: 1, pdf: pdf, doc_id: docid };
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
}
// OrderEfileConfirm posts the addresses to the efile.php script,
// EFILING THE ORDER!!! AND.
function OrderEfileConfirm(pane) {
    //$(pane).find(".efilestatus").html(' <img src="/icons/spinner.gif" style="vertical-align:bottom">');
    var ucn = $(pane).find('.ucn').val();
    var docid = $(pane).find('.docid').val();
    var filingId = $(pane).find('.filingId').val();
    var pdf = $(pane).find('.pdf').val();
    //SaveToWorkflow(pane);
    if (ucn=='' || docid=='') {
        alert('ERROR: please Sign & Save the document BEFORE E-Filing it!');
        return;
    }
    var signed = $(pane).find('.signeddoc').val();
    var casenum = ucn;
    
    $.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait </h1>', fadeIn: 0});
    var url = "/cgi-bin/eservice/eService.cgi?case=" + casenum + "&pdf=" + pdf + "&signed=" + signed + "&doc_id=" + docid + "&efileCheck=1&clerkFile=1";
    if (filingId != undefined) {
    	url += "&filingId=" + filingId;
    }
    window.location.href = url;
}
function OrderPartySourceChange(pane) {
    var ucn = $("#ucn").val();
    var psrc = $(".wfpartysrc option:selected").val();
    var t = new Date().getTime();
    var postData = {ucn: ucn, t: t, json: 1};
    $.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait </h1>', fadeIn: 0});
    if (psrc=="clerk") {
    	postData.isOrder = $('#isOrder').val();
    	postData.showclerk = 1;
    	postData.clerkOnly = 1;
    	$.ajax({
            url: '/workflow/parties.php',
            data: postData,
            async: true,
            success: function(data) {
                $('#partyPeople').replaceWith(data);
                $.unblockUI();
            }
        });
    } else {
    	postData.isOrder = $('#isOrder').val();
    	$.ajax({
            url: '/workflow/parties.php',
            data: postData,
            async: true,
            success: function(data) {
                $('#partyPeople').replaceWith(data);
                $.unblockUI();
            }
        });
    }
}
function allowDrop(ev) {
    ev.preventDefault();
}
function drag(ev) {
    var foo = ev.dataTransfer.setData("text/html", ev.target);
    return true;
}
function drop(ev) {
    ev.preventDefault();
    var data = ev.dataTransfer.getData("text");
    ev.target.appendChild(document.getElementById(data));
}