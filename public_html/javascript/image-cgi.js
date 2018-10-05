function LoadImage(el, did, ucn, viewer){
    el = $(el);
    
    
    //$.post("/view/image_status.php",{ucn: ucn, did: did}, function (res) {
    //    res=res.substring(0,1);
    //    
    //    if (res=='A' || res=='P') {
    //        el.find(".image-status .status").text("Retrieving document from clerk system!");
    //    } else if (res=='C') {
    //        el.find(".image-status .status").text("Converting document to PDF format");
    //    } else if (res=='G') {
    //        RenderImage(el, viewer);
    //        return;
    //    } else if (res=='B') {
    //        el.find(".image-status .status").text("document failed to load; error has been logged. Please try again later.");
    //        el.find(".spinner").hide();
    //        return;
    //    }
    //    
    //    setTimeout(function(){
    //        LoadImage(el, did, ucn, viewer);
    //    }, 500);
    //});
}

function RenderImage(id, viewer){
    var el = $(id);
    var foo = $(el).attr('id');
    var url = el.data('url');
    
    // Mobile open pdf directly outside of iframe
    if(window.location.search.match(/mobile=true/)){
        window.location = url;
        return;
    }
    
    if(viewer == "pdfjs"){
        url = "/cgi-bin/pdfjs.cgi?file=" + url;
    }
    
    el.html($("<iframe  src='" + url + "'></iframe>"));
    el.find("iframe").focus();
    
    var p = el.parent();
    el.find("iframe").css("height", p.innerHeight() - 20 + "px");
    el.find("iframe").css("width", p.innerWidth() - 20 + "px");
    
    $(window).resize(function(){
        var p = el.parent();
        el.find("iframe").css("height", p.innerHeight() - 20 + "px");
        el.find("iframe").css("width", p.innerWidth() - 20 + "px");
    });
}
