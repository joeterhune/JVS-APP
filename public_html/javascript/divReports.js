$(document).on('click','.oldReports',function() {
    var divname = $(this).data('divName');
    var rpath = $(this).data('rpath');
    //var parentTab = $(this).closest('.topPane').attr('id');
    
    var url = "/genarchive.php";
    
    var tabTitle = "Previous Reports for Division " + divname;
    var tabName = "archReports_" + divname;
    
    var postData = {rpath: rpath, div: divname, tab: tabName, show: 1};
    
    createTab(tabName, tabTitle, 'casetop', 'innerTab', 0);
    
    $.ajax({
        url: url,
        async: false,
        data: postData,
        success: function(data) {
            showTab(data);
        }
    })

    return false;
});

$(document).on('click','.flaggedSearch',function() {
	
	var divname = $(this).data('divName');
    
    var url = "/cgi-bin/casenotes/flaggedCaseSearch.cgi?lev=3";
    
    var tabTitle = "Flagged Case Search";
    var tabName = "flaggedSearch_" + divname;
    
    var postData = {tabname: tabName, show: 1};
    
    createTab(tabName, tabTitle, 'casetop', 'innerTab', 0);
    
    $.ajax({
        url: url,
        async: false,
        data: postData,
        success: function(data) {
            showTab(data);
        }
    })

    return false;
});

$(document).on('click','.showDivCal',function() {
	
	var divname = $(this).data('divName');
    
    var url = "/cgi-bin/calendars/showCal.cgi?lev=3&div=" + divname;
    
    var tabTitle = "Division " + divname + " Calendar";
    var tabName = "cal_" + divname;
    
    var postData = {tab: tabName, show: 1};
    
    createTab(tabName, tabTitle, 'casetop', 'innerTab', 0);
    
    $.ajax({
        url: url,
        async: false,
        data: postData,
        success: function(data) {
            showTab(data);
        }
    })

    return false;
});