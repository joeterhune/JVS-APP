// this is the main JavaScript library for ICMS 3.0

// $Id: ICMS.js 2241 2015-09-04 18:34:04Z rhaney $

var mobile=0;
var UPDATEINTERVAL=10000;
var IMAGECOUNT=0; // used to name divs for embedded pdfs...
var UPDATEDISABLED=0; // set to 1 to temporarily stop the wf updates
var CASEVIEWCOUNT=0; // used to name divs for cases...
var WORKQUEUELIST=""; // used to track workflow queues for updates
var TABCOUNT=0; // a universal tab counter, incremented by AddTab after adding a tab...

function showDialog (header,text) {
    $('#dialogSpan').html(text);
    $('#dialogDiv').dialog({
        resizable: false,
        minheight: 150,
        width: 500,
        modal: true,
        title: header,
        buttons: {
            "OK": function() {
                $(this).dialog( "close" );
                return false;
            }
        }
    });
}

// IsMobilebile returns true for IOS-based platforms

function validEmail (email) {
    var hasError = false;
    var emailReg = /^([\w-\.]+@([\w-]+\.)+[\w-]{2,4})?$/;
    if(email == '') {
        return false;
    } else if(!emailReg.test(email)) {
        return false;
    }
    return true;
}

function getUCN(pane) {
    return $(pane).find('.ucn').val();
}

function IsMobile() {
    return (
      (navigator.platform.indexOf("iPhone") != -1) ||
      (navigator.platform.indexOf("iPad") != -1) ||
      (navigator.platform.indexOf("iPod") != -1)
    );
}

function IsIE() {
    if (navigator.userAgent.indexOf("MSIE")!=-1 || !!navigator.userAgent.match(/Trident\/7.0/)) { return 1; }
   return 0;
}

// Used as a beforeLoad handler for jQueryUI Tabs, it both helps with cachebusting for remotely loaded tabs
// and prevents ajax tabs from reloading when changing tabs
function PreventTabReload(event, ui){
    if (ui.tab.data("loaded")) {
      event.preventDefault();
      return;
    }
    ui.ajaxSettings.cache = false;
    ui.jqXHR.success(function() {
      ui.tab.data( "loaded", true );
    })
}

// LoadErr shows the user an error message if an error happened 
//         after a page or section is loaded...

function LoadErr(response,status,xhr) {
    if (status=='error')  {
	alert('Error: '+xhr.status+' text: '+xhr.statusText);
    }
}


// EncodeURI is a truly standards compliant URI encoder for jQuery

function EncodeURI(str) {
    return encodeURIComponent(str).replace(/[!'()*]/g, escape);
}

// PopUpXY creates a popup of the given width at the upper right corner
// of the screen, currently resizeable with no scroll.

function PopUpXY(path,title,width,height) {
   var wx=screen.width
   wx=wx-width-10; // some slack
//    alert(path+':'+title+':'+width+':'+height);
    MyWindow=window.open(path,title,'toolbar=no,location=no,directories=no,status=no,menubar=no,scrollbars=yes,resizable=yes,width='+width+',height='+height+',top=0,left='+wx);
    if(MyWindow){
      MyWindow.focus();
    }
   return false;
}


function PopUpURL(url,title) {
  // we're assuming a document here...
  // should resize based on screen width and height...
  var x=906;
  var y=1172;
  PopUpXY(url,title,x,y);
}


function GetImageDir(ucn) {
    var x=ucn.substr(0,2)+'/'+ucn.substr(3,4)+'/'+ucn.substr(8,2)+'/'+ucn.substr(11,3)+'/'+ucn;
//    alert(x);
    return x;
}


// PopUpImage pops up the the appropriate document image in a suitably scaled popup
// x and y, if present, are in points (72dpi pixels) so are scaled for display
// setting the x and y coordinates with the proper values allows landscape documents to pop up appropriately



function PopUpImage(ucn,did,ccisucn,imagefile,tabname,x,y) {
    if (x=='undefined') {
        x=612;
        y=792;
    }
    
    // 1.48x gets me original size on my 30" dell 2560x1600 monitor
    x=parseInt(x)*1.48;
    y=parseInt(y)*1.48;
  
    //var path = 'image.cgi?ucn='+ucn+'&did='+did+'&ccisucn='+ccisucn+'&imagefile='+imagefile+'&height='+ x +'&width='+ y;
    var path = '/cgi-bin/image-new.cgi?ucn='+ucn+'&objid='+did;
    
    PopUpXY(path,'Image'+did,x,y);
}


// AddTab provides a non-deprecated method of adding a tab...
// per http://jqueryui.com/upgrade-guide/1.9/#deprecated-add-and-remove-methods-and-events-use-refresh-method

function AddTab(tabname,tabtitle,url,allowclose) {
    var tabstr='#'+tabname;
    var tt=$(tabstr).position().top;
    var wh=$(window).height();
    var h=(wh-tt)-115; // height of tab
//    alert(tabtitle);
    tabtitle=decodeURIComponent(tabtitle).replace(/\+\+/g, " ").replace(/\+/g, " ");
    if (allowclose && tabtitle.indexOf('ui-icon-close')==-1) { // no close icon for a closable window title. add it!
      tabtitle+=" <span class='ui-icon ui-icon-close' style='display:inline-block;cursor:pointer'/>";
    }
    $("<li><a href="+url+">"+tabtitle+"</a></li>").appendTo("#"+tabname+" .ui-tabs-nav");
    $(tabstr).tabs("refresh");
    $(tabstr).tabs('option', 'active',-1);
    // these are overly broad, but work...
    $(tabstr+' .ui-tabs-panel').css('height',h);
    $(tabstr+' .ui-tabs-panel').css('overflow-y','auto');
    $(tabstr+' .ui-tabs-panel').css('overflowY','auto'); // for IE9...
    TABCOUNT++;
}


// ViewCase creates a new tab (for tab-family tabname full of case details...
function ViewCase(ucn, tabname) {
    AddTab(tabname,ucn+"<span class='ui-icon ui-icon-close' style='display:inline-block;cursor:pointer'/>","viewgen.php?ucn="+ucn+"&tabname="+tabname+'&caseviewcount='+CASEVIEWCOUNT,true);
    CASEVIEWCOUNT++; // for naming divs...
}


function ViewMultipleCases(ucns, newTab, parentTab) {
      var data = { 
                     'ucns[]'       :  [],
                     '_'            :  new Date().getTime() / 1000
                 };
                    
      for (var u in ucns) {
         data['ucns[]'].push(ucns[u]);
      }

      AddTab(parentTab, newTab + "<span class='ui-icon ui-icon-close' style='display: inline-block; cursor: pointer'/>","multiview.cgi?" + $.param(data), true);

}

// CloseTab closes a tab using the new approved methodology.
function CloseTab(el) {
    var tab=$(el).closest("li");
    var panelId=tab.attr('aria-controls');
    var tabs=tab.closest(".ui-tabs");
    var active=tabs.tabs("option", "active");
    tab.remove();
    $('#' + panelId).remove(); // Remove the actual panel from the DOM
    //tabs.tabs("refresh");
    tabs.tabs('option','active', active-1);
    return;
}


// HandleRegenerate handles the "R" request from a currently viewed image tab...

function HandleRegenerate(elem,ucn,did,ccisucn,imagefile,tabname,x,y,desc) {
    alert(ucn+':'+did+':'+ccisucn+':'+imagefile+':'+tabname+':'+x+':'+y+':'+desc);
    CloseTab(elem);
    ViewImageTab(ucn,did,ccisucn,imagefile,tabname,x,y,desc);
    return false;
}


// ViewImageTab creates a new tab (for tab-family tabname) with an image...

function ViewImageTab(ucn,did,ccisucn,imagefile,tabname,x,y,desc) {
    var tabstr='#'+tabname;
    var tt=$(tabstr).position().top;
    var wh=$(window).height();
    var ww=$(window).width();
    var h=(wh-tt)-110; // height of tab

    var h2=(wh-tt)-108; // height of embedded pdf object (was 105)
    var w2=ww-56;       // width of embedded pdf object (was 53)
    if (IsMobile()) { // just pop it up..
        // If we don't remove the tabname the supporting wrapper html wont output
        PopUpXY("image.cgi?ucn="+ucn+'&did='+did+'&ccisucn='+ccisucn+'&imagefile='+imagefile+'&imagecount='+IMAGECOUNT+'&mobile=true',"Document",screen.width,screen.height);
        return;
    }
    
    AddTab(tabname, "Document <span onClick=\"PopUpImage('"+ucn+"','"+did+"','"+ccisucn+"','"+imagefile+"','"+tabname+"','"+x+"','"+y+"');\" title='Pop-up this  document' style='cursor:pointer'>&#x2197;</span> <span onClick=\"HandleAdd('','','"+ucn+"."+did+".pdf');\" title='Add this document to Workflow' style='cursor:pointer'>W</span> <span onClick=\"ShowNoteDialog('','"+ucn+"','"+ucn+"."+did+".pdf','"+tabname+"','"+x+"','"+y+"','"+desc+"');\" title='Add a note linking to this document' style='cursor:pointer'>N</span>",
                    "image.cgi?ucn="+ucn+'&did='+did+'&ccisucn='+ccisucn+'&imagefile='+imagefile+'&height='+h2+'&width='+w2+'&imagecount='+IMAGECOUNT+'&tabname='+tabname, true);
    var tabcount=$(tabstr).children('ul:first').children().size();
    IMAGECOUNT++; // increment count so no duplicates ids...

    $(tabstr).tabs("refresh");
    $(tabstr).tabs('option', 'active',-1);
}

// Open image in DocumentViewer
function ViewImageDocumentViewer(ucn,did,ccisucn,name,imagefile,tabname,x,y,desc,docketcode) {
    var tabstr='#'+tabname;
    var tt=$(tabstr).position().top;
    var wh=$(window).height();
    var ww=$(window).width();
    var h2=(wh-tt)-105; // height of embedded pdf object
    var docurl='image.cgi?ucn='+ucn+'&did='+did+'&ccisucn='+ccisucn+'&imagefile='+imagefile+'&height='+ x +'&width='+ y +'&imagecount='+IMAGECOUNT;
    var docViewer=null;
    var id=ucn+'-docs';
    
    if($('#'+id).size() > 0){
        docViewer = $('#'+id+' .dv-window').data('dv-window');
    } else {
        $(tabstr + " > ul").append("<li><a href='#" + id + "'>" + ucn + " Documents<span class='ui-icon ui-icon-close' title='Close this tab' style='font-size: 5pt; display:inline-block; cursor:pointer'/></a></li>");
        $(tabstr).append("<div id='" + id + "'><div class='docviewer'></div></div>");
        $(tabstr).tabs("refresh");
        
        $(tabstr).on('tabsactivate', function(event, ui){
            if(ui.newPanel && ui.newPanel[0].id == id){
                var dv = $("#" + id + " .docviewer");
                if(dv.length > 0){
                    dv.show();
                    dv.data('dv-window').redraw();
                }
            } else {
                $("#" + id + " .docviewer").hide();
            }
        });
        
        docViewer = CreateDocumentViewer("#"+id+" .docviewer", ucn,2,'multi');
        
        docViewer.jqueryTabIndex = $(tabstr + ' > ul > li').size() - 1;
    }

    $(tabstr).tabs('option', 'active', docViewer.jqueryTabIndex);
    docViewer.openICMSImage = function(docurl, name, docketcode, ucn, did, ccisucn, imagefile, tabname, x, y){
        this.open(docurl, {name: name, docketCode: docketcode, ucn: ucn, did: did, ccisucn: ccisucn, imagefile: imagefile, tabname: tabname, popoutWidth: x, popoutHeight: y, scrollbar: GetSetting("pdf_scrollbar", 0), toolbar: GetSetting("pdf_toolbar", 1), navpanes: GetSetting("pdf_navpanes", 0), view: GetSetting("pdf_view", "FitV"), zoom: GetSetting("pdf_zoom", "100"), statusbar: GetSetting("pdf_statusbar", 1)});
    };
    //(docurl, name, docketcode, ucn, did, ccisucn, imagefile, tabname, x, y);
}

function ViewImageSideBySide(ucn,did,ccisucn,name,imagefile,tabname,x,y,desc,docketcode) {
    var tabstr='#' + tabname;
    var tt=$(tabstr).position().top;
    var wh=$(window).height();
    var ww=$(window).width();
    var h2=(wh-tt)-105; // height of embedded pdf object
    //var docurl='image.cgi?ucn='+ucn+'&did='+did+'&ccisucn='+ccisucn+'&imagefile='+imagefile+'&height='+ x +'&width='+ y +'&imagecount='+IMAGECOUNT;
    var docurl = '/cgi-bin/image-new.cgi?ucn=' + ucn + '&objid=' + did;
    //var docViewer=$("#"+ucn+"-documents").data("dv-window");
    var docViewer=$(tabstr).find('.dv-window').data('dv-window');
    var container = $(tabstr).find('.drawer-container');
        
    container.addClass("side-by-side");
    
    // Unmaximize Drawer if it's currently maximized, we want our document to be visible
    if(container.find(".content").hasClass("closed")){
        container.find(".drawer-controls .decrease").trigger("click");
    }
    
    docViewer.openICMSImage(docurl, name, docketcode, ucn, did, ccisucn, imagefile, tabname, x, y);
    
    //var imgCount = $(tabstr).find('.dv-pane').length;
    //
    //// Click the link for the appropriate number of documents
    //setTimeout(function() {
    //    var toolbar = $(tabstr).find('.dv-toolbar').first();
    //    switch (imgCount) {
    //        case 0:
    //            break;
    //        case 1:
    //            $(tabstr).find('.dv-one-pane').trigger('click');
    //            break;
    //        case 2:
    //            $(tabstr).find('.dv-two-pane').trigger('click');
    //            break;
    //        case 3:
    //            $(tabstr).find('.dv-three-pane').trigger('click');
    //            break;
    //        default:
    //            $(tabstr).find('.dv-three-pane').trigger('click');
    //            break;
    //    }
    //}, 1000);
}

// Open image using user configured viewing method
function ViewImage(ucn,did,ccisucn,name,imagefile,tabname,x,y,desc,docketcode) {
    var viewer=GetSetting('docviewer', 'sidebyside');
    var docurl='image.cgi?ucn='+ucn+'&did='+did+'&ccisucn='+ccisucn+'&imagefile='+imagefile+'&height='+ x +'&width='+ y +'&imagecount='+IMAGECOUNT;
    
    // Fix name escaping
    name=decodeURIComponent(name).replace(/\+\+/g, " ").replace(/\+/g, " ");
    
    switch(viewer) {
        case "docviewer":
            ViewImageDocumentViewer(ucn,did,ccisucn,name,imagefile,tabname,x,y,desc,docketcode);
            break;
        
        case "popout":
            PopUpImage(ucn,did,ccisucn,imagefile,tabname,x,y);
            break;
        
        case "sidebyside":
            ViewImageSideBySide(ucn,did,ccisucn,name,imagefile,tabname,x,y,desc,docketcode);
            break;
        
        // fallthrough to default
        case "tab":
            default:
            ViewImageTab(ucn,did,ccisucn,imagefile,tabname,x,y,desc);
    }
}


// LoadTab just changes the content of a tab; useful for admin screens,
// which won't make baby tabs...

function LoadTab(tabname,url) {
  $("#"+tabname).load(url);
}


// LoadTabNoCache adds a t= cache spoiler to the url

function LoadTabNoCache(tabname,url) {
    var t=new Date().getTime();
    url+='?t='+t;
    LoadTab(tabname,url);
}



var CurrentTab='Search';

function HelpFunction() {
    if (CurrentTab=="Search") {
        PopUpXY("help/Search.php","Help",600,800);
    } else if (CurrentTab=="Calendar") {
        PopUpXY("help/Calendar.php","Help",600,800);
    } else if (CurrentTab=="Reports") {
        PopUpXY("help/Reports.php","Help",600,800);
    } else if (CurrentTab.substring(0,10)=="Work Queue") {
        PopUpXY("help/Main.php","Help",600,800);
    } else if (CurrentTab=="Notes") {
        PopUpXY("help/Notes.php","Help",600,800);
    } else if (CurrentTab=="Settings") {
        PopUpXY("help/Main.php","Help",600,800);
    } else if (CurrentTab=="Analyst") {
        PopUpXY("help/Main.php","Help",600,800);
    } else if (CurrentTab=="Admin") {
        PopUpXY("help/Admin.php","Help",600,800);
    }
}


// HandleLogoClick handles the user click on the ICMS3 logo by display the search form window (the "home page" of the app)

function HandleLogoClick() {
    $("#tabs").tabs("option","active",0);
    $("#SearchTabs").tabs("option","active",0);
    $("#searchstring").focus();
}


// AlertDialog displays the specified alert-style box using the dialog ui element 

function AlertDialog(title,message) {
    $("#dialog-message").dialog({modal:true,buttons:{OK:function() {$(this).dialog("close");}}});
    $("#dialog-message").html("<span class='ui-icon ui-icon-alert' style='float:left; margin: 0 7px 50px 0;'></span>"+message);
    $("#dialog-message").dialog('option','title',title);
}


// SetTabHeight sets the height and overflow properly for a newly created tab

function SetTabHeight(tabname) {
   var tabstr='#'+tabname;
   var tt=$(tabstr).position().top;
   var wh=$(window).height();
   var h=(wh-tt)-115; // height of tab
   $(tabstr+' .ui-tabs-panel').css('height',h);
   $(tabstr+' .ui-tabs-panel').css('overflow-y','auto');
   $(tabstr+' .ui-tabs-panel').css('overflowY','auto'); // for IE9..
}

// PrettyDate takes a YYYY-MM-DD date and returns a MM/DD/YYYY date

function PrettyDate(dt) {
    if (dt == null) {
        return dt;
    }
    var x=dt.split('-');
    return x[1]+'/'+x[2]+'/'+x[0];
}

function HandleOrdersButton(tabname,ucn) {
// AddTab(tabname,'Order - $ucn  <span class=\'ui-icon ui-icon-close\' style=\'display:inline-block;\'/>','/icms/orders/index.php?ucn='+ucn,true);">
    PopUpURL('/icms/orders/index.php?ucn='+ucn);
}

// Retrieves settings that are stored in the database, or defaults
function GetSetting(name, deflt) {
    if(!window.settings){
        LoadSettings();
    }
    
    return window.settings[name] || deflt;
}

// retrieve settings via json request
function LoadSettings(){
    window.location.href='/settings/index.cgi';
}

function SetRelativeHeight(target, source,  margin) {
    var elements = $(target),
    h = $(source).height() - margin;
    
    if(h <= 0){
        return;
    }
    
    elements.each(function(i, el){
        el = $(el);
        el.height(h);
    });
}

function CreateDocumentViewer(selector, ucn, visiblePanes, cookiePrefix, height, width, viewName){
    var pane = $(selector).closest('.caseTab');
    var caseType = $(pane).find('.caseType').val();
    var ucnParts= ucn.split("-");
    var docViewer = new DocViewer.Window(
        selector,
        [],
        {
            name: ucn, height: height, width: width, visiblePanes: visiblePanes,
            caseType: caseType,
            viewName: viewName, cookiePrefix: cookiePrefix,
            popupFunction: function(pane){
                PopUpImage(pane.options.ucn, pane.options.did, pane.options.ccisucn, pane.options.imagefile, pane.options.tabname, pane.options.popoutWidth, pane.options.popoutHeight);
            },
            saveFunction: function(viewer){
                var i;
                var dockets = [];
                var panes = viewer.panes;
                for(i=0; i < panes.length; i++){
                    // This assumes we want unique, that we dont plan to save duplicate/triplicate modes
                    if(dockets.indexOf(panes[i].options.docketCode) == -1){
                        dockets.push(panes[i].options.docketCode);
                    }
                }
                
                EditView(viewer.options.caseType, viewer.options.viewName, dockets, ucn);
            },
            noteFunction: function(pane){
                var opt = pane.options;
                
                ShowNoteDialog('', opt.ucn, opt.ucn+'.'+opt.did+'.pdf', opt.tabname, opt.popoutWidth, opt.popoutHeight,'');
            },
            workflowFunction: function(pane){
                var opt = pane.options;
                HandleAdd('', '', opt.ucn+'.'+opt.did+'.pdf');
            }
        });
    
    var foo = $(docViewer);
    
    // Add ICMS specific logic to object
    docViewer.openICMSImage = function(docurl, name, docketcode, ucn, did, ccisucn, imagefile, tabname, x, y){
        this.open(docurl, {name: name, docketCode: docketcode, ucn: ucn, did: did, ccisucn: ccisucn, imagefile: imagefile, tabname: tabname, popoutWidth: x, popoutHeight: y, scrollbar: GetSetting("pdf_scrollbar", 0), toolbar: GetSetting("pdf_toolbar", 1), navpanes: GetSetting("pdf_navpanes", 0), view: GetSetting("pdf_view", "FitV"), zoom: GetSetting("pdf_zoom", "100"), statusbar: GetSetting("pdf_statusbar", 1)});
    };
    
    return docViewer;
}


function AdjustHeights(){
    var lhDiv = $('#logoDiv').height();
    SetRelativeHeight("#tabs", window, lhDiv-50);
    
    $("#toptabs").each(function(i, el){
        el = $(el);
        
        if(el.attr('id') != "tabs"){
            SetRelativeHeight(el, "#tabs", 40);
        }
    });
    
    $(".topPane").each(function(i, el){
        el = $(el);
        SetRelativeHeight(el, el.parents(".tab-content").first(), 45);
    });
    
    $(".innerPane,.imagePane").each(function(i, el){
        el = $(el);
        SetRelativeHeight(el, el.parents(".topPane").first(), 75);
    });
    
    $('.drawer-container').each(function(i, el){
        el = $(el);
        SetRelativeHeight(el, el.parents(".innerPane").first(), 5);
    });
    
    //$("#SearchTabs .drawer, #SearchTabs .drawer-content").each(function(i, el){
    $('.drawer, .drawer-content').each(function(i, el){
        el = $(el);
        SetRelativeHeight(el, el.parents(".drawer-container").first(), 5);
    });
    
    $('.drawer-container .content').each(function(i, el){
        el = $(el);
        SetRelativeHeight(el, el.parents(".drawer-container").first(), 0);
    });
    
    $(".dv-window").each(function(i, el){
        el = $(el);
        
        SetRelativeHeight(el, "#toptabs", 45);
        SetRelativeHeight(el.find(".pane iframe"), el, 50);
        SetRelativeHeight(el.find(".dv-container"), el, 30);
        el.width("100%");
        
        el.data('dv-window').redraw();
    });
}

function InitSavedViewButtons(container){
  $(container).find("button").button().click(function(){
  }).next()
  .button({
    text: false,
    icons: {
      primary: "ui-icon-triangle-1-s"
    }
  }).click(function() {
      var menu = $( this ).parent().next().show().position({
        my: "left top",
        at: "left bottom",
        of: this
      });
      $( document ).one( "click", function() {
        menu.hide();
      });
      return false;
  }).parent().buttonset().next()
  .hide()
  .menu();

  $(container).on('click', '.saved-view-open', function(){
    var el = $(this),
        ucn = el.parents('.case-view').attr('data-ucn');
    OpenView(el.attr("data-case-type"), el.attr("data-view-name"), ucn);
  });

  $(container).on('click', '.saved-view-delete', function(){
    var el = $(this);
    DeleteView(el.attr("data-case-type"), el.attr("data-view-name"), null, el.parents(".ui-tabs-panel").first());
  });

  $(container).on('click', '.saved-view-default', function(){
    var el = $(this),
        type = el.attr("data-case-type"),
        name = el.attr("data-view-name");

    // If already default, disable
    if(el.hasClass('default')){
      name = null;
    }

    SaveDefaultView(type, name);
  });

  // Highlight defaults
  $(container).find('.saved-view-default').each(function(i, el){
    el = $(el);
    if(GetDefaultView(el.attr("data-case-type")) == el.attr("data-view-name")){
      el.addClass("default");
      el.parents(".button-set").find("button.ui-button-text-only span").addClass("default");
    }
  });
}

function GetViews(callback){
  return GetView(null, null, callback);
}

function GetView(caseType){
    var postData = {casetype: caseType};
    
    var view;
    
    $.ajax({
        dataType: "json",
        url: "/savedviews/get.php",
        data: postData,
        async: false,
        cache: false,
        success: function(data){
            view = data;
            return true;
        }
    });
    
    return view;
}

 //docketTable_2009-CF-015789-AXXX-MB'] tbody tr[data-docketcode='OAC5']

function GetDocketForUCN(ucn, docket){
    var doc = $("#docketTable_" + ucn +" tbody tr[data-docketcode='" + docket + "']").first()
    if(doc.length > 0){
        return doc;
    }
    
    return null;
}

function OpenView(caseType, name, ucn){
  var view = GetView(caseType);

  if(view){
    // Clear open documents
    $('#'+ucn+'-documents, #'+ucn+'-docs .dv-window').each(function(i, docViewer){
      var w=$(docViewer).data('dv-window');
      if(w){
        w.removeAllPanes();
      }
    });

    $.each(view.dockets, function(i,d){
      var doc = GetDocketForUCN(ucn, d);
      if(doc){
        ViewImage(ucn,doc.attr('data-docket-id'), doc.attr('data-ccisucn'),doc.attr('data-docket-desc'),doc.attr('data-image-name'),doc.attr('data-tab-name'),612,704,'Image', d);
      }
    });

    // Update viewName on docviewers, we do this here because in the case of multi-pane mode the tab may not be open yet
    $('#'+ucn+'-documents, #'+ucn+'-docs .dv-window').each(function(i, docViewer){
      var w=$(docViewer).data('dv-window');
      if(w){
        w.options.viewName = name;
      }
    });
  }
}

function getUniqueDocketsForUCN(ucn){
  var dockets = $(".dockets[data-ucn='" + ucn +"'] tbody tr[data-docket-code!='']"),
      unique = [];

  dockets.each(function(i, el){
    el = $(el);
    var code = el.attr('data-docket-code');

    if(code && $.inArray(code, unique) == -1){
      unique.push(code);
    }
  });

  return unique;
}

function getDocketViewClass(ucn, docket){
    if(GetDocketForUCN(ucn, docket)){
        return 'current-docket-code';
    } else {
        return 'missing-docket-code';
    }
}

function EditView(caseType, name, currentDockets, ucn){
    var view = null;
    var savedDocketsEl = $("#saved-dockets");
    var currentDocketsEl = $("#current-dockets");
    
    currentDockets = currentDockets || [];
    var savedDockets = [];
    
    if(caseType){
        $('#save-view-case-type').html(caseType);
        
        view = GetView(caseType);
        $(view).each(function(i,e){
            savedDockets.push(e.docket_code);
        })
    }
    
    // Reset values
    currentDocketsEl.empty();
    currentDocketsEl.attr('data-case-type', caseType);
    savedDocketsEl.empty();
    savedDocketsEl.attr('data-case-type', caseType);
    $("#save-view-ucn").val(ucn);
    $("#view-name").val(name);
    $("#view-name").attr('original-view-name', name);
    
    // Populate auto-complete
    $("#docket-code").autocomplete({source: getUniqueDocketsForUCN(ucn)});
    
    // Populate Current List
    for(i=0; i < currentDockets.length; i++){
        currentDocketsEl.append($('<li class="ui-widget-content ' + getDocketViewClass(ucn, currentDockets[i]) + '" data-current="true" data-docket-code="' + currentDockets[i] + '"><div>' + currentDockets[i] + '<span class="ui-icon ui-icon-arrowthick-1-e">close</span></div></li>'));
    }
    
    // Populate Saved List
    if(view){
        for(i=0; i < savedDockets.length; i++){
            savedDocketsEl.append($('<li class="ui-widget-content ' + getDocketViewClass(ucn, savedDockets[i]) + '" data-docket-code="' + savedDockets[i] + '"><div>' + savedDockets[i] + '<span class="ui-icon ui-icon-closethick">close</span></div></li>'));
        }
    }
    
    $("#save-view").dialog("open");
    
    // Hide / Show Update button based on if we are editing
    if(name && view){
        var buttons = $("#save-view").parents(".ui-dialog").first().find(".ui-dialog-buttonset button");
        $.each(buttons, function(i, b){
            b = $(b);
            if(b.find(".ui-button-text").text() == "Update"){
                b.show();
            }
        });
    } else {
        var buttons = $("#save-view").parents(".ui-dialog").first().find(".ui-dialog-buttonset button");
        $.each(buttons, function(i, b){
            b = $(b);
            if(b.find(".ui-button-text").text() == "Update"){
                b.hide();
            }
        });
    }
}




function DeleteView(caseType, name, callback, overlayEl){
  ConfirmDialog("Delete View", "Are you sure you want to delete the view <strong>" + name + "</strong> for the case type <strong>" + caseType + "</strong>? This will delete the view for all users of the system.", {
    height: 200,
    confirmCaption: "Delete",
    cancelCaption: "Cancel",
    onConfirm: function(){
      var views = {
        views: GetViews() || {}
      };

      if(overlayEl){
        $(overlayEl).pleasewait();
      }

      // Remove all buttons for this view
      $(".button-set[data-view-name='" + name + "'][data-case-type='" + caseType + "']").remove();

      views.views[caseType] = views.views[caseType] || {};

      delete views.views[caseType][name]

      $.post("/icms/savedviews/save.cgi", {views: JSON.stringify(views)}, function(data){
        if(overlayEl){
          $(overlayEl).pleasewait('close');
        }

        if(callback){
          callback(data);
        }
      });
    }
  });
}

function SaveView(caseType, docketCodes){
    var postData = {casetype: caseType, docketCodes: docketCodes.join(",")};
    $.ajax({
        url: "/savedviews/save.php",
        data: postData,
        async: false,
        success: function(data) {
            $(".saved-view-buttons[data-case-type='" + caseType + "']").each(function(i, el){
                UpdateViewButtons(el);
            });
        },
        error: function(data) {
            return false;
        }
    });
}

function SaveDefaultView(caseType, name){
    window.defaultViews = window.defaultViews || {};
    
    if(name){
        window.defaultViews[caseType] = name;
    } else {
        delete window.defaultViews[caseType];
    }
    
    $.post("/icms/savedviews/setdefault.cgi", {default_views: JSON.stringify(window.defaultViews)}, function(data){
        $(".saved-view-buttons[data-case-type='" + caseType + "']").each(function(i, el){
            UpdateViewButtons(el);
        });
    });
}

function GetDefaultView(caseType){
    if(window.defaultViews == undefined){
        $.ajax({
            dataType: "json",
            url: "/savedviews/defaults.php",
            async: false,
            cache: false,
            success: function(data){
                window.defaultViews = data;
            }
        });
    }
    
    return window.defaultViews[caseType];
}

function OpenDefaultView(pane){
    var ucn = $(pane).find('.ucn').val();
    var type = $(pane).find('.caseType').val();
    
    var name=GetDefaultView(type);
    
    if(name){
        OpenView(type, name, ucn);
    }
}

function UpdateViewButtons(el){
    type = $(el).attr('data-case-type'),
    name = $(el).attr('data-view-name'),
    views = GetView(type);
    
    $(el).empty();

    $.each(views, function(i, v){
        var name = i;
        var button = $("<div class='button-set' data-view-name='" + name + "' data-case-type='" + type + "'>" +
                       "<div>" +
                       "<button class='saved-view-open' data-view-name='" + name + "' data-case-type='" + type + "'>" + name + "</button>" +
                       "<button>Select an action</button>" +
                       "</div>" +
                       "<ul style='position: absolute; z-index: 9999;'>" +
                       "<li><a href='#' class='saved-view-open' data-view-name='" + name + "' data-case-type='" + type + "'>Open</a></li>" +
                       "<li><a href='#' class='saved-view-delete' data-view-name='" + name + "' data-case-type='" + type + "'>Delete</a></li>" +
                       "<li><a href='#' class='saved-view-default' data-view-name='" + name + "' data-case-type='" + type + "'>Default</a></li>" +
                       "</ul>" +
                       "</div>");
        el.append(button);
    });
    
    InitSavedViewButtons(el);
}


function ConfirmDialog(title, msg, options){
    var newOpts = $.extend({}, {
        resizable: false,
        draggable: false,
        height: 350,
        width: 450,
        modal: true,
        confirmCaption: "Confirm",
        cancelCaption: "Cancel",
        onConfirm: function(){},
        onCancel: function(){},
    }, options || {});
    
    options = newOpts;
    
    $("#confirm-dialog").attr('title', title);
    $("#confirm-dialog").html("<p>" + msg + "</p>");
    
    $("#confirm-dialog").dialog({
        resizable: options.resizable,
        draggable: options.draggable,
        height: options.height,
        width: options.width,
        modal: options.modal,
        open: function(event){
            $(this).parents(".ui-dialog").first().shim();
        },
        close: function(event){
            $(this).dialog("close");
            $(this).parents(".ui-dialog").first().shim('close');
            
            // Close is called regardless of the button clicked, ensure we only call callback if the close icon was clicked
            if($(event.srcElement).hasClass('ui-icon-closethick') && options.onCancel){
                options.onCancel();
            }
        },
        resize: function(event){
            $(this).parents(".ui-dialog").first().shim('resize');
        },
        drag: function(event){
            $(this).parents(".ui-dialog").first().shim('resize');
        },
        buttons: [
            {
                text: options.confirmCaption,
                click: function(){
                    $(this).dialog("close");
                    
                    if(options.onConfirm){
                        options.onConfirm();
                    }
                }
            },
            {
                text: options.cancelCaption,
                click: function(){
                    $(this).dialog("close");
                    
                    if(options.onCancel){
                        options.onCancel();
                    }
                }
            }
        ]
    });
}


// The main document.ready function for ICMS3...
$(document).ready(function(){
    
    $(document).on('click','.wfNoteSave',function(e) {
        e.preventDefault();
        var casenum = $('#nt_casenum').val();
        var url = "/casenotes/addnote.php";
        
        $('#nt_add_form').ajaxSubmit({
            url: url,
            async: false,
            success: function(data) {
                $('#nt_add_dialog').dialog("close");
                showDialog("Note Added", "The note was successfully added.");
                getNotes(casenum);
                return true;
            }
        });
        
        return false;
    });
    
    $(document).on('click', ".ui-tabs-panel span.ui-icon-close", function(){
        //CloseTab(this);
    });

    // Ensure we redraw any docviewers when top-level tabs are changed
    /*$('#tabs').on('tabsactivate', function(event, ui){
        if(ui.newPanel[0].id == "SearchTab"){
            var panel = $(ui.newPanel);
            panel.find('.dv-window').each(function(i, w){
                w = $(w);
                w.data('dv-window').redraw();
            });
        }
    });*/

    /* Saved Views */
    /*$("#save-view").dialog({
        autoOpen: false,
        height: 475,
        width: 650,
        modal: true,
        open: function( event, ui ) {
            $(this).parents(".ui-dialog").first().shim();
            },
            close: function( event, ui ) {
                $(this).parents(".ui-dialog").first().pleasewait('close');
                $(this).parents(".ui-dialog").first().shim('close');
            },
            drag: function( event, ui ) {
                $(this).parents(".ui-dialog").first().shim('resize');
            },
            resize: function( event, ui ) {
                $(this).parents(".ui-dialog").first().shim('resize');
            },
            buttons: {
                "Cancel": function() {
                    $(this).dialog( "close" );
                },
                "Update": function() {
                    var name = $(this).find("#view-name").val(),
                    originalName = $(this).find("#view-name").attr('original-view-name'),
                    docketCodes = [],
                    d = $(this),
                    caseType = $(this).find("#saved-dockets").attr("data-case-type");
                    if(name.trim() == "" || caseType.trim() == ""){
                        return;
                    }
                    
                    d.find("#saved-dockets li").each(function(){
                        docketCodes.push($(this).attr('data-docket-code'));
                    });
                    
                    // If user has open dockets that are not in the saved configuration make them confirm
                    if($("#current-dockets").children().length > 0){
                        var missing = false;
                        
                        $("#current-dockets").children().each(function(i, li){
                            var code = $(li).attr('data-docket-code'),
                            found = false;
                            
                            $("#saved-dockets").children().each(function(i, li){
                                if(code == $(li).attr('data-docket-code')){
                                    found = true;
                                }
                            });
                            
                            if(!found){
                                missing = true;
                            }
                        });
                        
                        if(missing){
                            ConfirmDialog("Overwrite View", "You have dockets open that are not part of the configuration you're saving. Are you sure you want to save?", {
                                height: 200,
                                confirmCaption: "Overwrite",
                                cancelCaption: "Cancel",
                                onConfirm: function(){
                                    d.parents(".ui-dialog").first().pleasewait();
                                    SaveView(caseType, docketCodes);
                                    d.parents(".ui-dialog").first().pleasewait('close');
                                    d.dialog("close");;
                                }
                            });
                            return;
                        }
                    }
                    
                    d.parents(".ui-dialog").first().pleasewait();
                    SaveView(caseType, docketCodes);
                    d.parents(".ui-dialog").first().pleasewait('close');
                    d.dialog("close");
                },
                
                "Save": function() {
                    var docketCodes = [];
                    var d = $(this);
                    var caseType = $(this).find("#saved-dockets").attr("data-case-type");
                    var view = GetView(caseType);
                    
                    if(caseType.trim() == ""){
                        return;
                    }
                    
                    d.find("#saved-dockets li").each(function(){
                        docketCodes.push($(this).attr('data-docket-code'));
                    });
                    
                    // They are wanting to save a new view, but a view with this name already exists
                    if(view.length > 0){
                        ConfirmDialog("Overwrite View", "You specified you wanted to save this configuration, but a configuration for this case type already exists. Would you like to overwrite it?", {
                            height: 200,
                            confirmCaption: "Overwrite",
                            cancelCaption: "Cancel",
                            onConfirm: function(){
                                d.parents(".ui-dialog").first().pleasewait();
                                SaveView(caseType, docketCodes);
                                d.parents(".ui-dialog").first().pleasewait('close');
                                d.dialog("close");
                            }
                        });
                        return;
                    }
                    
                    d.parents(".ui-dialog").first().pleasewait();
                    
                    SaveView(caseType, docketCodes);
                    d.parents(".ui-dialog").first().pleasewait('close');
                    d.dialog("close");
                }   
            }
    });*/
    
    /* Saved Views */
    /*$("#saved-dockets, #current-dockets").sortable({
        connectWith: ".sortable-dockets",
        dropOnEmpty: true,
        forcePlaceholderSize: true,
        forceHelperSize: true,
        receive: function(event, ui){
            var target = $(event.target),
            item = $(ui.item);
            
            // Ensure we can only add missing items back to the list
            if(target.attr('id') == "current-dockets" && item.attr('data-current') != "true"){
                $("#saved-dockets").sortable('cancel');
                return false;
            }
            
            // Ensure we dont add duplicates to saved configuration
            if(target.attr('id') == "saved-dockets"){
                var found = 0;
                
                $("#saved-dockets li").each(function(i, el){
                    if($(el).attr('data-docket-code') == item.attr('data-docket-code')){
                        found++;
                    }
                });
                
                if(found > 1){
                    $("#current-dockets").sortable('cancel');
                    return false;
                }
            }
            return true;
        }
    });
    
    $("#saved-dockets").on('click', '.ui-icon-closethick', function(){
        var el = $(this).parents("li")
        el.remove();
        
        // If this is a docket currently open we want to move it back to the current list
        if(el.attr('data-current') == "true"){
            $("#current-dockets").append(el);
            // And put the arrow icon back
            $(el).find('span').removeClass('ui-icon-closethick').addClass('ui-icon-arrowthick-1-e');
        }
    });

    $("#save-view").on('click', '.add-docket-code', function(){
        var code = $("#docket-code").val().toUpperCase(),
        ucn = $("#save-view-ucn").val();
        
        $("#docket-code").val('');
        
        var found = false;
        $("#saved-dockets li").each(function(i, el){
            if($(el).attr('data-docket-code') == code){
                found = true;
            }
        });
        
        if(!found){
            $("#saved-dockets").append($('<li class="ui-widget-content ' + getDocketViewClass(ucn, code)  + '" data-docket-code="' + code + '"><div>' + code + '<span class="ui-icon ui-icon-closethick">close</span></div></li>'));
        }
    });

    $("#save-view").on('click', '.add-all-dockets', function(){
        var currentDockets = $("#current-dockets li");
        var savedContainer = $("#saved-dockets");
        
        currentDockets.each(function(i, li){
            var found = false;
            var code = $(li).attr('data-docket-code');
            
            $(li).remove();
            
            savedContainer.find("li").each(function(i, el){
                if($(el).attr('data-docket-code') == code){
                    found = true;
                }
            });
            
            if(!found){
                savedContainer.append(li);
                // Change the icon from the arrow to the close
                $(li).find('span').removeClass('ui-icon-arrowthick-1-e').addClass('ui-icon-closethick');
            }
        });
    });
    
    $('#current-dockets').on('dblclick','.current-docket-code, .missing-docket-code', function() {
        $(this).find('.ui-icon-arrowthick-1-e').first().trigger('click');
    });
    
    $('#current-dockets').on('click','.ui-icon-arrowthick-1-e', function() {
        // Moving a docket from currently displayed to saved
        var li = $(this).closest('li');
        var code = $(li).data('docketCode');
        
        $(li).remove();
        
        var savedContainer = $("#saved-dockets");
        var found = false;
        
        savedContainer.find("li").each(function(i, el){
            var foo = $(el).data('docketCode');
            if($(el).data('docketCode') == code){
                found = true;
                return false;
            }
            return true;
        });
        
        if(!found){
            savedContainer.append(li);
            // Change the icon from the arrow to the close
            $(li).find('span').removeClass('ui-icon-arrowthick-1-e').addClass('ui-icon-closethick');
        }
    });*/
  
    /* Side-by-Side Viewer */
    /*$(document).on('click','.drawer-controls .increase', function(){
        var el = $(this);
        var drawer = el.closest(".drawer");
        var container = el.closest(".drawer-container");
        var content = container.find('.content');
    
        if(drawer.hasClass("closed")){
            drawer.find(".drawer-content").show();
            content.animate({'width': '50%'}, 400, 'swing', function(){content.find('.dv-window').data('dv-window').redraw();});
            drawer.animate({'width': '49%'});
            
            drawer.removeClass("closed");
            drawer.addClass("half");
        } else if(drawer.hasClass("half")){
            content.hide();
            drawer.animate({'width': '99%'});
            drawer.removeClass("half");
            drawer.addClass("full");
            content.addClass("closed");
        }
    });

    $(document).on('click', '.drawer-controls .decrease', function(){
        var el = $(this);
        var drawer = el.closest(".drawer");
        var container = el.closest(".drawer-container");
        content = container.find('.content');
        
        if(drawer.hasClass("half")){
            drawer.find(".drawer-content").hide();
            drawer.animate({'width': '25px'});
            content.animate({'width': '98%'}, 400, 'swing', function(){content.find('.dv-window').data('dv-window').redraw();});
            
            drawer.removeClass("half");
            drawer.addClass("closed");
        } else if(drawer.hasClass("full")){
            content.show();
            
            content.animate({'width': '50%'}, 400, 'swing', function(){content.find('.dv-window').data('dv-window').redraw();});
            drawer.animate({'width': '49%'});
            
            drawer.removeClass("full");
            drawer.addClass("half");
            content.removeClass("closed");
        }
    });*/
    
    $('.listCheck').click(function() {
		var targetClass = $(this).attr('data-targetClass');
		var checkProp = parseInt($(this).attr('data-checkProp'));
		// First toggle any descendants of this element that match
		$(this).find('.' + targetClass).prop('checked',checkProp);
		// Then any siblings of this element that match
		$(this).siblings('.' + targetClass).prop('checked',checkProp);
		// Then any descendants of siblings
		$(this).siblings().find('.' + targetClass).prop('checked',checkProp);
		return true;
	});
    
    $('.externLink').click(function() {
        var url = $(this).data('url');
        var target = $(this).data('target');
        window.open(url, target)
    });
});
