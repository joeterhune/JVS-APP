// This library requires jQuery!!

function doAjax(script,querydata,async,completeFunction) {
    // Calls the JQuery Ajax 'post' method, and returns the xmlhttp object.
    // Default async to false
    async = typeof async !== 'undefined' ? async : false;
    
    if (typeof completeFunction !== 'undefined') {
        $.ajaxSetup({url: script, type: "POST", async:async, complete: completeFunction});
    } else {
        $.ajaxSetup({url: script, type: "POST", async:async});
    }
    
    var xmlhttp = $.ajax({data:querydata},
        function(data) {
        })
    .done(function() {})
    .fail(function() {
        if (!abortQuietly) {
            alert ("Failure performing lookup");
        }
    })
    .always(function() {});
    
    return xmlhttp;
}