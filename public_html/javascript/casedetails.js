// $Id: casedetails.js 2214 2015-08-25 15:18:23Z rhaney $

var VRBURL = "https://demo-vrb.15thcircuit.com";

function scGetAsync (ucn, casenum, mjid, casetype, caseid) {
    getFlags(casenum);
    getNotes(casenum);
    
    $('#docketdiv_' + casenum).block({
        message: '<h1><img src="/images/busy.gif"/> Please Wait... loading dockets </h1>', fadeIn: 0
    });
    
    $.ajax({
        url: "/cgi-bin/scGetDocket.cgi",
        data: {casenum: casenum, casetype: casetype, caseid: caseid},
        async: true,
        success: function(data) {
            content = data.html;
            casenum = data.casenum;
            
            $('#docketdiv_' + casenum).html(content);
                
            docketCount = $('#dockets_' + casenum).find('tr').length;
				
            $('#dockets_' + casenum).tablesorter({
                widgets: ['zebra','filter'],
                sortList: [[0,1],[2,1]],
                widgetOptions: {
                    filter_columnFilters: true,
                    filter_saveFilters: false,
                    filter_reset : '.reset'
                },
                headers: {6: {sorter: false, filter: false}, 7: {sorter: false, filter: false}}
            });
            pdforder = $.cookie("pdforder");
            if ((pdforder == undefined) || (pdforder == 'desc')) {
                $('#buildDesc_' + casenum).attr('checked',true);
            } else {
                $('#buildAsc_' + casenum).attr('checked',true);
            }
            $('#docketdiv_' + casenum).unblock();
            return true;
        }
    });
    
    $.ajax({
        url: "/cgi-bin/getBookingHistory.cgi",
        data: {mjid: mjid, casenum: casenum},
        async: true,
        success: function(data) {
            json = $.parseJSON(data);
            content = json.html;
            $('#pbsodiv_' + casenum).html(content);
        }
    });
    
    $.ajax({
        url: "/cgi-bin/scGetLinkedCases.cgi",
        data: {casenum: casenum, caseid: caseid},
        async: true,
        success: function(data) {
            var content = data.html;
            $('#relatedcasesdiv_' + casenum).html(content);
            return true;
        }
    });
    
    $.ajax({
        url: "/cgi-bin/scGetOtherCases.cgi",
        data: {mjid: mjid, casenum: casenum, caseid: caseid},
        async: true,
        success: function (data) {
            json = $.parseJSON(data);
            content = json.html;
            $('#fullOtherCaseDiv_' + casenum).html(content);
            $('#othercases_' + casenum).tablesorter({widgets: ['zebra'], sortList: [[0,1]],headers: {4: {sorter: false}}});
        }
    });
    
	    // Get Docket Images
	$.ajax({
        url: "/cgi-bin/bmGetCaseImages.cgi",
        data: {ucn: ucn, caseid: caseid},
        async: true,
        success: function(data) {
            return true;
        }
    });

	return true;
}



function sc_civilGetAsync (ucn, casenum, casetype, caseid) {
    getFlags(casenum);
    getNotes(casenum);
    
    $.ajax({
        url: "/cgi-bin/scCivilGetDocket.cgi",
        data: {casenum: casenum, casetype: casetype, caseid: caseid},
        async: true,
        success: function(data) {
            var content = data.html;
            var casenum = data.casenum;
            
            $('#docketdiv_' + casenum).html(content);
                
            var docketCount = $('#dockets_' + casenum).find('tr').length;
				
            $('#dockets_' + casenum).tablesorter({
                widgets: ['zebra','filter'],
                sortList: [[1,1],[2,1]],
                widgetOptions: {
                    filter_columnFilters: true,
                    filter_saveFilters: false,
                    filter_reset : '.reset'
                },
                headers: {7: {sorter: false, filter: false}, 8: {sorter: false, filter: false}}});
            var pdforder = $.cookie("pdforder");
            if ((pdforder == undefined) || (pdforder == 'desc')) {
                $('#buildDesc_' + casenum).attr('checked',true);
            } else {
                $('#buildAsc_' + casenum).attr('checked',true);
            }
            return true;
        }
    });
    
    $.ajax({
        url: "/cgi-bin/scCivilGetRegistry.cgi",
        data: {casenum: casenum, caseid: caseid},
        async: true,
        success: function(data) {
            var content = data.html;
            var casenum = data.casenum;
            $('#registrydiv_' + casenum).html(content);
            return true;
        }
    });
    
    $.ajax({
        url: "/cgi-bin/scCivilGetLinkedCases.cgi",
        data: {casenum: casenum, caseid: caseid},
        async: true,
        success: function(data) {
            var content = data.html;
            $('#relcasediv_' + casenum).html(content);
            return true;
        }
    });
    
    $.ajax({
        url: "/cgi-bin/scGetEServiceAddresses.cgi",
        data: {casenum: casenum, caseid: caseid},
        async: true,
        success: function (data) {
            json = $.parseJSON(data);
            addresses = json.addresses;
            $.each(addresses, function(index, obj){
            	if(obj && (obj != "")){
            		$(".isEServicePartyShow-" + index).show();
            		$("#eserviceHeaderShow-" + index).show();
            		$("#eserviceColumnShow-" + index).show();
            		$("#eserviceColumnShow-" + index).html("<span style=\"color:green\">" + obj + "</span>");
            		$(".isEServiceShow-" + index).show();
            		$(".eService-" + index).show();
            		$(".eService-" + index).html("<span style=\"color:green\">" + obj + "</span>");
            	}
            	else{
            		$(".eService-" + index).show();
            		$(".eService-" + index).html("<span style=\"color:red\">No e-Service Address Available</span>");
            	}
            });
            
            $(".eservice").each(function(index) {
            	if($(this).html() == 'Loading...'){
            		$(this).html("<span style=\"color:red\">No e-Service Address Available</span>");
            	}
            });
        },
        error: function (textStatus, errorThrown) {
        	$(".eservice").each(function(index) {
            	if($(this).html() == 'Loading...'){
            		$(this).html("<span style=\"color:red\">Unable to Load e-Service Addresses</span>");
            	}
            });
        }
    });

	$.ajax({
        url: "/cgi-bin/bmGetCaseImages.cgi",
        data: {ucn: ucn, caseid: caseid},
        async: true,
        success: function(data) {
            return true;
        }
    });

	
    return true;
}


$(document).on('click','.orders', function (e) {
    e.preventDefault;
    var parentTab = $(this).data('parentTab');
    if (parentTab == undefined) {
        parentTab = $(this).closest('.caseTab').attr('id');
    }
    var ucn = $(this).data('ucn');
    var docid = $(this).data('doc_id');
    var tabName = parentTab + '-ordergen';
    var tabTitle = 'Order Creation';
    
    createTab(tabName, tabTitle, parentTab, 'innerPane', 0);
    
    $('a[href="#cases"]').tab('show');
    $('a[href="#' + parentTab + '"]').tab('show');
    $('#'+tabName).css('overflow-y','hidden');
    $('a[href="#' + tabName + '"]').tab('show');
    
    var url = '/orders/index.php';
    var postData = {ucn: ucn, docid: docid, tab: tabName, show: 1};
    
    var filingId = $(this).data('filingId');
    if (filingId != undefined) {
        postData.filingId = filingId;
    }
    
    $.ajax({
        url: url,
        data: postData,
        async: true,
        success: function(data) {
            showTab(data);
            if (docid != undefined) {
                // It's an existing order.  Display the Preview div instead of the Form div
                //debugger;
                var json = $.parseJSON(data);
                var pane = $('#'+json.tab);
                var pvBtn = $(pane).find('.previewbutton');
                var pvDiv = $(pane).find('.previewdiv');
                var formDiv = $(pane).find('.htmlformdiv');
                $(formDiv).css('display','none');
                $(pvDiv).css('display','normal');
                //$(pvBtn).trigger('click');
                setTimeout(function() {
                    $(pvBtn).trigger('click');
                },2000);
                //$(pvBtn).trigger('click');
            }
        }
    });
    
    return true;
});

$(document).on('click','.searchRelatedOneParty', function() {
	var parties = {};
	
	parties[0] = {};
	parties[0].first_name = $(this).attr('data-first');
    parties[0].middle_name = $(this).attr('data-middle');
    parties[0].last_name = $(this).attr('data-last');
    if($.trim($(this).attr('data-dob')) == ""){
    	parties[0].dob = "";
    }
    else{
    	parties[0].dob = $(this).attr('data-dob');
    }
    
    window.location.href= "/related_case_search/search.php?searchTheseParties=" + JSON.stringify(parties) + "&ucn=" + $(this).attr('data-ucn');
});


$(document).on('click','.changeWatch',function() {
    var casenum = $(this).data('casenum');
    var url = $(this).data('url');
    var postData = {casenum: casenum};
    var target = $(this).closest('.watchList');
    
    $.ajax({
        url: url,
        data: postData,
        async: true,
        success: function(data) {
            $(target).html(data.html);
        }
    });
});

$(document).on('click','.vrbCase',function() {
    var casenum = $(this).data('ucn');
    var vrbAuth = doVrbAuth(VRBURL);
    setTimeout(function() {
        var scheduler = VRBURL + "/scheduler/calendar?casenum=" + casenum;
        window.open(scheduler,"vrb","width=1280,height=1024").focus();
    },300);
    
});


$(document).on('click','.vrbDate',function() {
    var eventID = $(this).data('event_id');
    var vrbAuth = doVrbAuth(VRBURL);
    setTimeout(function() {
        var scheduler = VRBURL + "/scheduler/calendar?event_id=" + eventID;
        window.open(scheduler,"vrb").focus();
        //window.open(scheduler,"vrb","width=1280,height=1024").focus();
    },300);
    
});

function doVrbAuth(vrbUrl) {
    var creds = {};
    getCreds(creds);
    
    var authUrl = vrbUrl + '/scheduler/extern_auth?callback=?'
    
    var queryString = 'user=' + creds.user + '&password=' + encodeURIComponent(creds.pass);
    var authed;
    $.getJSON(authUrl,queryString, function (res) {
        return true;
    });
    
    return false;
}

function getCreds(creds) {
    var url = "/vrb/getCreds.php";
    $.ajax({
        url: url,
        async: false,
        success: function(data) {
            creds.user = data.user
            creds.pass = data.pw;
        }
    })
}
