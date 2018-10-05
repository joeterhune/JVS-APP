$(document).ready(function() {
    $(document).on('click','.addRecip', function () {
        var pane = $(this).closest('.eserviceDiv');
        var newrecip = $('#newrecip').html();
        var addlRecips = $(pane).find('.addlrecips');
        $(addlRecips).append($(newrecip));
        
        $(newrecip).find('input').each(function(i,e) {
            $(e).attr('disabled',false);
        });
        $(newrecip).show();
        return false;
    });
    
    $(document).on('click','.cloneBtn',function() {
        var parentDiv = $(this).parent();
        var target = $(parentDiv).closest('div.files').attr('id');
        
        var newdiv = $(parentDiv).clone(false);
        var divcount = $(this).closest('.files').find('.fileinput').length;
        
        // Get the number after the last dash - this will be incremented and become the ID of the new div
        var newid = $(newdiv).attr('id');
        var pieces = newid.split("-");
        var number = pieces.pop(); // Actually a throw-away value.f
        number = divcount + 1;
        pieces.push(number.toString());
        newid = pieces.join('-');
        $(newdiv).attr('id',newid);
        
        var elements = $(newdiv).find('input,select,button,textarea');
        // Now also increment any input fields (and their IDs!) in the div
        for (i = 0; i < elements.length; i++) {
            var elem = elements[i];
            var elemname = $(elem).attr('name');
            pieces = elemname.split("-");
            pieces.pop();
            pieces.push(number.toString());
            elemname = pieces.join('-');
            $(elem).attr('name',elemname);
            var elemid = $(elem).attr('id');
            pieces = elemid.split("-");
            pieces.pop();
            pieces.push(number.toString());
            elemid = pieces.join('-');
            $(elem).attr('id',elemid);
            $(elem).val('');
        }
        var top = (number-1) * 100;
        $(newdiv).css('top',top+'px');
        $(newdiv).appendTo('#'+target);
        var attachments = $(this).closest('.attachments');
        $(attachments).height(top+100);
        $(newdiv).find('.orderSel').html('').hide();
        return false;;
    });
    
    // Fire off automatic lookup of docket types when the user gets to 5 characters
    $(document).on('keyup','.idLookup', function(e) {
        var entered = $(this).val();
        if (e.keyCode != 13) {
            // If the enter key was pressed, process regardless of the length. Otherewise,
            // don't process if < 5 characters
            if (entered.length < 5) {
                return true;
            }
        }
        if (e.keyCode == 13) {
            $(this).blur();
        }
            
        var targetDiv = $(this).siblings('select.orderSel').attr('id');
        lookupOrders(entered,targetDiv);
        return true;
    });
    
    // Or fire it off manually when the lookup button is clicked.
    $(document).on('click','.lookup', function() {
        // Process if the button is clicked
        var search_val = $(this).siblings('.idLookup').val();
        var targetDiv = $(this).siblings('select.orderSel').attr('id');
        lookupOrders(search_val,targetDiv);
    });
    
    $(document).on('keypress','.addlcomment',function () {
        var pane = $(this).closest('.eserviceDiv');
        $(pane).find('.addlcommentdiv').show();
        $(pane).find('.addlcommentdisplay').html(nl2br($(this).val()));
        return;
    });
    
    $(document).on('click','.es-btn-submit',function() {
        var form = $(this).closest('.theForm');
        eserviceValidate(form);
    });

    $(document).on('click','.btn-correspond', function () {
        var pane = $(this).closest('.caseTab');
        var form = $(pane).find('.theForm');
        message = "<p>You have chosen to send correspondence with no attached files.</p>"+
            "<p>No files will be attached or e-Filed, and the contents of the \"Additional Comments\" " +
            "box will be sent to the selected recipients.</p>" +
            "<p>The case number and case style will be included in the subject line.</p>";
        $('#dialogSpan').html(message);
        $("#dialogSpan").dialog({
            resizable: false,
            minheight: 200,
            width: 500,
            modal: true,
            title: "Correspondence Only",
            buttons: {
                "OK": function() {
                    $(this).dialog("close");
                    allowNoAttach = 1;
                    $(form).append('<input type="hidden" name="noAttach" value="1">');
                    eserviceValidate(form);
                },
                "Cancel": function () {
                    $(this).dialog("close");
                    allowNoAttach = 0;
                    return false;
                }
            }
        });
        return false;
    });


});
