$('#orderDiv-{$data.ucn}').ready(function() {
    var pane = $('#orderDiv-{$data.ucn}').closest('.orderDiv');
        
    var queue='{$data.queue}';
    var docid='{$data.docid}';
    var ucn = $(pane).find('.ucn').val();
    orderDiv = $('#orderDiv-' + $(pane).find('.ucn').val());
    
    var pdfht=$(orderDiv).height()-30;
    // acrobat and IE like to cache this, so...
    var t=new Date().getTime();
    var formname = EncodeURI('{$data.formname}');

    {literal}
    var postData = {ucn: $(pane).find('.ucn').val(), formname: formname, t: t};
    {/literal}

    {if $data.docid}
    postData.docid = {$data.docid}
    {/if}

    $.ajax({
        url: '/orders/pickorder.php',
        data: postData,
        async: false,
        success: function(data) {
            var json = $.parseJSON(data);
            $(orderDiv).find('.htmlformdiv').first().html(json.html);
            // Enable the "Parties" and "Preview" buttons if an order type has been selected
            var selType = $(orderDiv).find('.formid').val();
            if (selType != "") {
                $(orderDiv).find('.previewbutton,.partiesbutton').attr('disabled',false);
            }
        },
        error: function(data) {
            debugger;
            return false;
        }
    });
    
    $.ajax({
        url: '/orders/preview.php',
        data: postData,
        async: false,
        success: function(data) {
            var json = $.parseJSON(data);
            $(orderDiv).find('.previewdiv').first().html(json.html);
        }
    });
    
    postData.isOrder = 1;
    
    $.ajax({
        url: '/workflow/parties.php',
        data: postData,
        async: false,
        success: function(data) {
            var json = $.parseJSON(data);
            $(orderDiv).find('.xmlpartiesdiv').first().html(json.html);
        }
    });
    
    var cvRow = $(pane).find('.xmlviewctrl');
    var pos = $(cvRow).offset();
    // The top of the editor should be 2* (the height of the button row + 5) offset from the top of the button row
    var editTop = pos.top + (2 * ($(cvRow).height() + 5));
    var winHt = $(window).height();
    PDFIFRAMEHEIGHT = winHt - editTop;
    MAILIFRAMEHEIGHT = PDFIFRAMEHEIGHT-35;
    
    var ht=$(window).height()-100;
    $(orderDiv).find(".xmlpdfdiv").first().html('<iframe class="pdfiframe" style="width:100%;height:' +PDFIFRAMEHEIGHT+'px"></iframe>');
    //$(orderDiv).find(".xmlpdfdiv").first().html('<br><iframe class="pdfiframe" style="width:100%;height:100%"></iframe>');
    $(orderDiv).find(".xmlmailpdfdiv").first().html('<iframe class="mailpdfiframe" style="width:100%;height:'+MAILIFRAMEHEIGHT+'px"></iframe>');

    if ($(pane).find('.didgen').val() != 0) {
        pvb = $(orderDiv).find('.previewbutton').first();
        $(pvb).removeAttr('disabled');
    }
    
    if ($(pane).find('.pdf').val() != "") {
        $(orderDiv).find('.orderviewbutton').removeAttr('disabled');
    }
    
    function OrderShowMailDisabledDialog() {
       $("#maildisableddialog").dialog();
    }
});