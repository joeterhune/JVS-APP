// $Id: utils.js 2223 2015-08-26 19:03:53Z rhaney $

$(document).ready(function () {
    // Since there are pieces of the page loading asynchronously and may have these checkboxes in them,
    // be sure they're handled at all times.
    $(document).on("click", ".checkallboxes", function () {
        $(this).closest('table').find(':checkbox').prop('checked', true);
    });
    
    $(document).on("click", ".uncheckallboxes", function () {
        $(this).closest('table').find(':checkbox').prop('checked', false);
    });
    
    $(document).on("click", ".togglePBSO", function () {
        $(this).closest('.pbsodiv').find('.pbsoHistoryTable').toggle();
        position = $(this).closest('.pbsodiv').position();
        scroll(0,position.top);
    });
    
    $(document).on("click", ".toggleDocket", function () {
        $(this).closest('.docketdiv').find('.docketTable').toggle();
        position = $(this).closest('.docketTable').position();
        //scroll(0,position.top);
    });
    
    $(document).on("click", ".toggleJuvCMData", function () {
        $("#juvCMData").toggle();
    });
    
    $(document).on("click", ".toggleChildPlacements", function () {
    	var person_id = $(this).attr('data-person_id');
        $("#placements-" + person_id).toggle();
    });
    
    $(document).on('click', '.imageLink', function() {
        var pane = $(this).closest('.caseTab');
        var ucn = $(this).attr('data-casenum');
        var ucnobj = $(this).attr('data-ucnobj');
        var caseid = $(this).attr('data-caseid');
		var docketId = $(this).attr('data-docketid');
        var tabTitle = $(this).attr('data-docname');
        var parentTab = $(this).attr('data-parentTab');
        var showTif = $(this).attr('data-showTif');
        if(showTif == 1){
        	showTif = "&showTif=1";
        }
        else{
        	showTif = "";
        }
        if (parentTab == undefined) {
            parentTab = $(this).closest('.caseTab').attr('id');
        }
        var pieces = ucnobj.split("|");
        var objID = pieces[1];
        var tabname = parentTab + '-' + objID;
        // Commented 11/05/2018 jmt calling Benchmark image handler
        //window.open('/cgi-bin/image-new.cgi?ucn=' + ucn + '&objid=' + objID +'&caseid=' + caseid + showTif, '_blank');
		window.open('/cgi-bin/bmImage.cgi?ucn=' + ucn + '&objid=' + objID +'&caseid=' + caseid + '&docketid='+ docketId + showTif, '_blank');
        
        //LK - I took this out for now 1/6/16
        //ViewImage(ucn,objID,ucn,tabTitle,1,parentTab,612,704,'Image',$(this).data('docketcode'));
        
        return true;
        
        createTab(tabname, tabTitle, parentTab, 'imagePane', 0);
        postData = {ucnobj: ucnobj, tab: tabname};
        url = '/cgi-bin/scimage.cgi',
        $.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait </h1>', fadeIn: 0});
        $.ajax({
            url: url,
            data: postData,
            async: true,
            success: function(data) {
                showImageTab(data)
            }
        });
        return false;
    });
    
    $(document).on('click', '.bannerImageLink', function() {
        casenum = $(this).attr('data-casenum');
        seq = $(this).attr('data-sequence')
        tabTitle = $(this).attr('data-docname');
        
        caseTab = $(this).closest('.caseTab').attr('id');
        tabname = caseTab + '-' + seq;
        createTab(tabname, tabTitle, caseTab, 'imagePane', 0);
        postData = {casenum: casenum, num: seq, tab: tabname};
        url = '/cgi-bin/image.cgi',
        $.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait </h1>', fadeIn: 0});
        $.ajax({
            url: url,
            data: postData,
            async: true,
            success: showImageTab
        });
        return false;
    });
    
    $(document).on('click', '.collapseAttorneys', function() {
    	$("#attorneysSection").toggle();
    	$(this).toggleClass("descArrow ascArrow");
    });
    
    $(document).on('click', '.collapseCLS', function() {
    	$("#clsSection").toggle();
    	$(this).toggleClass("descArrow ascArrow");
    });
    
    $(document).on('click', '.collapseCPs', function() {
    	$("#cpSection").toggle();
    	$(this).toggleClass("descArrow ascArrow");
    });
    
    $(document).on('click', '.collapseOrdered', function() {
    	$("#orderedSection").toggle();
    	$(this).toggleClass("descArrow ascArrow");
    });
    
    $(document).on('click', '.collapsePerson', function() {
    	var person_id = $(this).attr('id');
    	$("#personSection-" + person_id).toggle();
    	$(this).toggleClass("descArrow ascArrow");
    });
    
    $(document).on('click', '.collapseEventNotes', function() {
    	$("#eventNotesSection").toggle();
    	$(this).toggleClass("descArrow ascArrow");
    });
});

function showImageTab (json) {
    $.unblockUI();
    var redirect = json.imageUrl;
    var tabid = json.tab;
    var imgTab = $('#' + tabid);
    var html = '<div style="height: 95%; width: 100%"><embed width="100%" height="100%" src="' + redirect + '" type="application/pdf"></div>';
    
    var url = "/cgi-bin/pdfjs.cgi?file=" + redirect;
    
    html = "<iframe  src='" + url + "'></iframe>"
    
    $(imgTab).html(html);
    var topTab = $(imgTab).closest('.topPane').attr('id');
    $('#caseLink').trigger('click');
    
    var parentID = $(imgTab).closest('.caseTab').attr('id');
    if (parentID != undefined) {
        $('#cases a[href="#' + parentID + '"]').tab('show');
        $('#' + parentID + ' a[href="#' + tabid + '"]').tab('show');   
    } else {
        $('#' + topTab + ' a[href="#' + tabid + '"]').tab('show');   
    }
    
    var p = imgTab.parent();
    imgTab.find("iframe").css("height", p.innerHeight() - 20 + "px");
    imgTab.find("iframe").css("width", p.innerWidth() - 20 + "px");
    
    $(window).resize(function(){
        var p = imgTab.parent();
        imgTab.find("iframe").css("height", p.innerHeight() - 20 + "px");
        imgTab.find("iframe").css("width", p.innerWidth() - 20 + "px");
    });
    
    
    return false;
}