<!-- $Id: index.tpl 2239 2015-09-03 20:55:42Z rhaney $ -->

    <script type="text/javascript">
        CTDIVS = '{$ctDivs}';
        ALLDIVS = {$allDivs};
        OIVTOP = 'https://oiv.15thcircuit.com/solr/';
        VRBURL = '{$vrbUrl}'
        
{literal}        
        $(document).ready(function () {
            
            $(document).on('click','.helpLink',function() {
                var context = $(this).data('context');
                var url = "/help/" + context + ".html?1.1";
                window.open(url,"helpWin", "width=500,height=500,scrollbars=1").focus();
                return false;
            });
            
            $(document).on('click','.helpLinkContact',function() {
                var url = "/help/support.php";
                window.open(url, "helpContactWin", "width=750,height=750,scrollbars=1").focus();
                return false;
            });
            
            $(document).on('click','.videolink', function() {
                var videolink = $(this).data('videolink');
                window.open(videolink,"videoWin", "width=1000");
                return false;
            });
            
            $(document).on('click','.rptExport', function(e) {
                e.preventDefault();
                var rpath = $(this).data('rpath');
                var header = $(this).data('header');
                
                var url = "/cgi-bin/export.cgi?rpath=" + rpath + "&header=" + header;
                window.open(url,"export");
                return true;
            });
            
            $(document).on('click','.docLink', function(e) {
                e.preventDefault();
                // Handle clicking on the document name.
                var ucn = $(this).data('casenum');
                var docid = $(this).data('docid');
                var thisRow = $(this).closest('tr');
                wfchosen = $(thisRow).find('.wfmenubut2,.wfmenubut');
                //
                //if ($(wfchosen).length == 0) {
                //    wfchosen = $(this);
                //}
                
                WorkFlowDoIt(docid,ucn,'viewetc');
                return false;
            });
            
            
            $('#searchCore').change(function() {              
                var courtType = $(this).val();
                if (courtType == "all") {
                    var showDivs = ALLDIVS;
                } else {
                    var ctdJson = $.parseJSON(CTDIVS);
                    var showDivs = $(ctdJson).attr(courtType);
                }
                
                // Build the select options list.
                $('#searchDiv').html($('<option>').prop('selected',true).val('all').html('All'));
                $(showDivs).each(function(i,e) {
                    var newOpt = $('<option>').val(e).html(e);
                    $('#searchDiv').append($(newOpt));
                });
                return false;
            });
                    
            $('#dsCaseNumSearch').change(function() {
                var casenums = $(this).val();
                var searchnums = casenums.split(/[,\s+]/);
                var url = 'https://icms-web.15thcircuit.com/isValidCase';
                
                var maxCount = searchnums.length;
                
                var styles = [];
                var validCases = [];
                
                $('#searchStyleTable').html('');
                
                for (var i = 0; i < maxCount; i++) {
                    var casenum = searchnums[i];
                    if (casenum == "") {
                        continue;
                    }
                    {literal}var postData = {casenum: casenum};{/literal}
                  
                    $.ajax({
                        url: url,
                        data: postData,
                        method: 'POST',
                        async: false,
                        success: function(data) {
                            var newRow = $('<div>').css('display','table-row');
                            if (data.ValidCase == 0) {
                                $(newRow).append(
                                                 $('<div>').css('display','table-cell').css('color','red').css('padding-right','2em').html(casenum),
                                                 $('<div>').css('display','table-cell').css('color','red').html('No Matching Case Found')
                                                );
                                $('#dsCaseNumSearch').val('');
                            } else {
                                $(newRow).append(
                                                 $('<div>').css('display','table-cell').css('color','green').css('padding-right','2em').html(data.CaseNumber),
                                                 $('<div>').css('display','table-cell').css('color','green').html(data.CaseStyle)
                                                );
                                validCases.push(data.CaseNumber);
                            }
                            
                            $('#searchStyleTable').append($(newRow));
                            
                            return true;
                        }
                    });    
                }
                $.unblockUI();
                var searchCases = validCases.join(",");
                $('#dsCaseNumSearch').val(searchCases);
            });
            
            $('.docSearchBtn').click(function() {
                var searchTerm = $.trim($('#dsSearchTerm').val());
                if (searchTerm == "") {
                    alert("You must enter a search term.");
                    return false;
                }
                
                $.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait</h1>', fadeIn: 0});
                var url = "/docSearch.php";
                $('#docSearchForm').ajaxSubmit({
                    url: url,
                    async: false,
                    success: function(data) {
                        $.unblockUI();
                        var json = $.parseJSON(data);
                        $('#docSearchTableBody').html('');
                        var docCount = json.length;
                        $('#searchCount').html(docCount);
                        $(json).each(function(i,e) {
                            var pathPieces = e.path.split("/");
                            var imgLink = $('<a>').attr('href',OIVTOP + e.path).html(pathPieces[1]).attr('target','_blank').attr('title',OIVTOP + e.path);
                            var caseNum = $('<a>').attr('href','#').addClass('caseLink').html(e.case_number).data('casenum',e.case_number).attr('title',e.case_number);
                            var highlights = e.highlights.split("(...)");
                            var hlStr = highlights.join("<br/><br/>");
                            var newRow = $('<tr>').append(
                                $('<td>').css('vertical-align','top').css('padding-right','2em').html(caseNum),
                                $('<td>').css('vertical-align','top').css('padding-right','2em').html(imgLink),
                                $('<td>').css('vertical-align','top').css('padding-right','2em').html(hlStr)
                            );
                            
                            $('#docSearchTableBody').append($(newRow));
                            $('#docSearchResults').show();
                        });
                    },
                    error: function(data) {
                        $.unblockUI();
                        return false;
                    }
                });
                
                return true;
            });
            
            $('.toggleSearchOpts').click(function(event){
                event.preventDefault();
                $('#searchOpts').toggle();
            });
            
            $('.docSearchToggle').click(function(event){
                event.preventDefault();
                $('#docSearchTop').toggle();
            });
            
            $('.toggleDocSearchResults').click(function(event){
                event.preventDefault();
                $('#totalSearch').toggle();
            });
            
            $('.dftCheck, .attyCheck').click(function(event) {
                // Toggle attorney or defendant party types to match the main checkbox
                var target = $(this).data('targetclass');
                $('.' + target).prop('checked',$(this).prop('checked'));
            });
            
            $('.allOptsCheck').click(function() {
                // Find the subsection
                var optsdiv = $(this).closest('.optsTop').find('div.optsDiv').first();
                if ($(this).prop('checked') == true) {
                    // Hide the optsDiv and uncheck all of the checkboxes in it
                    $(optsdiv).css('display','none');
                    $(optsdiv).find('input[type=checkbox]').prop('checked',false);
                } else {
                    // Show the optsDiv
                    $(optsdiv).css('display','table');
                }
            });
            
            $('.trafficDocket').click(function () {
                createTab('trafficDocketTab','Traffic Docket','searchtop', 'innerPane',1);
                postData = {tab:'trafficDocketTab', show: 1};
                url = "/cgi-bin/calendars/trafficDocket.cgi";
                $.ajax({
                    url: url,
                    data: postData,
                    async: true,
                    success: showTab
                })
            });
            
            $(document).on('click','a.caseLink',function () {
                casenum = $(this).data('casenum');
                
                if($(this).data('caseid')){
                	caseid = $(this).data('caseid');
                }
                else{
                	caseid = "";
                }
                
                url="/cgi-bin/search.cgi";
                $.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait</h1>', fadeIn: 0});
                $('.blockOverlay').attr('title','Click to unblock').click($.unblockUI); 
                $.ajax({
                    url: url,
                    data: {
                        name: casenum,
                        caseid: caseid
                    },
                    async: true,
                    success: showSearchResult
                });
                return false;
            });
            
            $(document).on('click','a.divRpt', function() {
                var rpath = $(this).data('rpath');
                var rpttype = $(this).data('rpttype');
                var yearmonth = $(this).data('yearmonth');
                var divname = $(this).data('divname');
                
                var tabname = 'report_' + divname + '_' + yearmonth + '_' + rpttype;
                var tableid = '#table-' + divname + '-' + yearmonth + '-' + rpttype;
                var tabtitle = 'Div. ' + divname + ' Case Report';
                
                var postData = {rpath: rpath, rpttype: rpttype, yearmonth: yearmonth, divname: divname, tab: tabname};

                var ageRange = $(this).data('agerange');
                if ((ageRange != undefined) && (ageRange >= 0)) {
                    postData.ageRange = ageRange;
                    switch (ageRange) {
                        case 0:
                            tabtitle += " (0-120 Days)";
                            break;
                        case 1:
                            tabtitle += " (121-180 Days)";
                            break;
                        case 2:
                            tabtitle += " (180+ Days)"
                            break;
                        default:
                            break;
                    }
                }
                
                var lop = $(this).data('lop');
                if (lop != undefined) {
                    postData.lop = 1;
                }
                
                // If the tab doesn't already exist, create it in the Cases top tab
                createTab(tabname,tabtitle,'casetop','innerPane');
                
                var tabsel = '#' + tabname;
                
                $.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait </h1>', fadeIn: 0});
                $.ajax({
                    url: '/genlist.php',
                    data: postData,
                    async: true,
                    success: function(data) {
                        $.unblockUI();
                        showTab(data);
                    }
                });
                
                cleanRestrictedLinks($(tabsel));
                
                // Activate the reports tab and deactivate any that are currently active
                $('#caseLink').trigger('click');
                $('#cases a[href="' + tabsel + '"]').tab('show');
                
                // Sort the table based on the first column
                $(tableid).trigger('update');
                
                return false;
            });
            
            $(document).on('click','.miscLink',function() {
                var url = $(this).data('script');
                var tabName = $(this).data('tab');
                var tabTitle = $(this).data('tabTitle');
                var topPane = $(this).closest('.topPane').attr('id');
                var targetTop = topPane + 'top';
                $.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait </h1>', fadeIn: 0});
                createTab(tabName,tabTitle,targetTop,'innerPane');
                loadTab(tabName,url,1);
                $.unblockUI();
                return true;
            });
            
            $(document).on('click','.divLink',function() {
                var url = $(this).data('script');
                var tabName = $(this).data('tab');
                var tabTitle = $(this).data('tabTitle');
                var topPane = $(this).closest('.topPane').attr('id');
                var targetTop = topPane + 'top';
                createTab(tabName,tabTitle,targetTop,'innerPane');
                var postData = {type: $(this).data('type'), tab: tabName, show: 1};
                $.ajax({
                    url: url,
                    data: postData,
                    async: true,
                    success: showTab
                });
                return true;
            });
            
            
            $(document).on('click','.reportView',function () {
                var postData = {};
                if ($(this).is('button')) {
                    var selOpt = $(this).siblings('select').val();
                } else {
                    var selOpt = $(this).data('selopt');
                }
                var tabname = "";
                var tabtitle = ""
                var arr;
                var jName;
                var tabname;
                var tabtitle;
                var url;
                var rpath;
                
                if ($(this).hasClass('judgeRpt')) {
                    arr = selOpt.split("~");
                    jName = arr[0].replace(/\s+/g,"");
                    jName = jName.replace(/,/, "");
                    jName = jName.replace(/\./, "");
                    tabname = "judgeRpt_" + jName;
                    tabtitle = "HON. " + arr[0];
                    url = "/judge.php";
                    postData = {val: selOpt, tabname: tabname};
                } 
                else if ($(this).hasClass('magRpt')) {
                    arr = selOpt.split("~");
                    mName = arr[0].replace(/\s+/g,"");
                    mName = mName.replace(/,/, "");
                    mName = mName.replace(/\./, "");
                    tabname = "magRpt_" + mName;
                    tabtitle = "MAGISTRATE " + arr[0];
                    url = "/mag.php";
                    postData = {val: selOpt, tabname: tabname};
                }
                else {
                    arr = selOpt.split("~");
                    tabname = "divRpt_" + arr[0];
                    tabtitle = "Division " + arr[0];
                    rpath = "/Palm/" + arr[1] + "/div" + arr[0];
                    url = "/gensumm.php";
                    postData = {rpath: rpath, tabname: tabname, divName: arr[0]};
                }
                
                // If the tab doesn't already exist, create it in the Reports top tab
                createTab(tabname,tabtitle,'casetop','innerPane');
                var tabsel = '#' + tabname;
                
                $.ajax({
                    url: url,
                    data: postData,
                    async: false,
                    success: function(data) {
                        showTab(data);
                    }
                });
                
                // Activate the reports tab and deactivate any that are currently active
                $('#caseLink').trigger('click');
                $('#cases a[href="' + tabsel + '"]').tab('show');
                
                return false;
            });
            
			$(".datepicker").datepicker({
                showOn: "both",
                buttonImageOnly: true,
                buttonText: "Select date",
                format: 'mm/dd/yyyy',
                buttonImage: "/style/images/calendar.gif",
				autoclose: true,
				todayHighlight: true,
				todayBtn: 'linked',
                changeMonth: true,
                changeYear: true,
                yearRange: "-1:+15"
			});
			
			$('.clearDates').click(function () {
                $(this).closest(".datePickerDiv").find('.datepicker').each(function(i,e) {
                    $(e).val(''); 
                });
				return false;
			});
            
            $('.calsubmit').click(function () {
                division = $(this).parent().find('.divsel').val();
                calType = $(this).val();
                
                if (division == "") {
                    $('#dialogSpan').html("Please select a division from the list.");
                    $('#dialogDiv').dialog({
                        resizable: false,
                        minheight: 150,
                        width: 500,
                        modal: true,
                        title: 'No Division Selected',
                        buttons: {
                            "OK": function() {
                                $(this).dialog( "close" );
                                return false;
                            }
                        }
                    });
                    return false;
                };
                tabname = 'cal_div_' + division;
                if (calType == "fapcal") {
                    tabtitle = "First Appearance Calendar";
                } 
                else if(calType == "magcal"){
                	tabtitle = "Magistrate Calendar";
                }else {
                    tabtitle = "Division " + division + " Calendar";
                }
                
                createTab(tabname,tabtitle,'calendartop','innerPane');
                
                url = "/cgi-bin/calendars/showCal.cgi";
                postData = {div: division, tab: tabname, show: 1, calType: calType};
                
                if (calType == "fapcal") {
                    postData.fapch = $('#fapch').val();
                }
                
                $.ajax({
                    url: url,
                    data: postData,
                    async: true,
                    success: showTab
                });
                //$('#theform').attr('action','/cgi-bin/calendars/showCal.cgi');
                //$('#div').val(division);
                //$('#theform').submit();
                return false;
            });
            
            $('#searchname, #searchcitation').keypress(function(event) {
                if (event.which == 13) {
                    event.preventDefault();
                    $('.search').first().trigger('click');
                }
            });
            
            $('#searchform').on('click','.search',function () {
                setAutoSave(mainSearchForm);
                var searchname = $.trim($('#searchname').val());
                $('#searchname').val(searchname);
                var searchcitation = $.trim($('#searchcitation').val());
                $('#searchcitation').val(searchcitation);
                if ((searchname == "") && (searchcitation == "")) {
                    $('#dialogSpan').html("Please enter a name, case number, or citation number and try again.");
                    $('#dialogDiv').dialog({
                        resizable: false,
                        minheight: 150,
                        width: 500,
                        modal: true,
                        title: 'No Search Parameters Entered',
                        buttons: {
                            "OK": function() {
                                $(this).dialog( "close" );
                                return false;
                            }
                        }
                    });
                    return false;
                }
                
                var searchType = $('input[name=searchtype]:checked').val();
                if (searchType == 'others') {
                    var selVals = $('#partyTypeSel').val();
                    if ($(selVals).length == 1) {
                        // Only 1 selected - be sure it's not the "Please select"
                        if ($(selVals)[0] == "") {
                            $('#dialogSpan').html("Please select the party type(s) to search.");
                            $('#dialogDiv').dialog({
                                resizable: false,
                                minheight: 150,
                                width: 500,
                                modal: true,
                                title: 'No Party Types Specified',
                                buttons: {
                                    "OK": function() {
                                        $(this).dialog( "close" );
                                        return false;
                                    }
                                }
                            });
                            return false;
                        }
                    }
                }
                
                var url="/cgi-bin/search.cgi";
                
                $.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait</h1>', fadeIn: 0});
                
                $('#mainSearchForm').ajaxSubmit({
                    url: url,
                    async: false,
                    success: function(data) {
                        showSearchResult(data);
                    }
                });
                
                return false;
            });
            
            var initUCN = $('#initialUCN');
            if (initUCN != undefined) {
                $(initUCN).trigger('click');
            }
        });
        
        function showSearchResult(data) {
            $.unblockUI();
            
            var json;
            
            if (data.html == undefined) {
                json = $.parseJSON(data);
            } else {
                json = data;
            }
            
            var tabname = json.tab;
            var tabtitle = json.tabname;
            
            // If the tab doesn't already exist, create it in the Search top tab
            var tabsel;
            if (tabname == 'searchresult') {
                createTab(tabname,tabtitle,'searchtop','innerPane',0);
                var tabsel = '#' + tabname;
                $('#searchLink').trigger('click');
                $('#search a[href="#' + tabname + '"]').tab('show');
                // Add the content and make it active.
                $(tabsel).html(json.html);
                $('#' + tabname + ' a[href="' + tabsel + '"]').tab('show');
                cleanRestrictedLinks($(tabsel));
            } else {
                createTab(tabname,tabtitle,'casetop','caseTab',1);
                createTab(tabname + '-details', 'Case Details', tabname, 'innerPane', 0);
                var tabsel = '#' + tabname + "-details";
                // Activate the case tab and deactivate any that are currently active
                $('#caseLink').trigger('click');
                $('#cases a[href="#' + tabname + '"]').tab('show');
                // Add the content and make it active.
                $(tabsel).html(json.html);
                $('#' + tabname + ' a[href="' + tabsel + '"]').tab('show');
            }
            
            $(tabsel).animate({scrollTop: "0px"});
            $(tabsel).find('.tablesorter').trigger('update');
            AdjustHeights();
            return true;
        }
        
        function cleanRestrictedLinks (pane) {
            setTimeout(function () {
                $(pane).find('.caseStyle,.CaseStyle').each(function(i,e) {
                var style=$(e).html();
                if (style == '-- restricted case --') {
                    // Restricted case.  Remove the caseLink hyperlink.
                    var cell = $(e).closest('tr').find('td.caseLink,td.CaseNumber');
                    var casenum = $(cell).text();
                    $(cell).html(casenum);
                }
                });
            }, 500);
            
            return false;
        }
        
	</script>
    {/literal}

	<div class="container-fluid">
	
    <input type="hidden" name="countyone" value="All" />
	<input type="hidden" name="types" value="All" />
	<input type="hidden" name="referer" value="/index.php" />
	<input type="hidden" name="div" id="div"/>
	
    <div style="float: right">
        <a class="helpLink" data-context="main">
            <img class="toolbarBtn" style="height: 20px !important; width: 20px;" alt="Help" title="Help" src="/images/help_icon.png">
        </a>
    </div>
    
	<table>
        <form id="mainSearchForm">
	    <tr>
            <td colspan="2">
                <span class="h2">
            	Circuit-Wide Search
                </span>
            </td>
            </tr>
	    <tr>
            <td style="text-align:right; vertical-align:top; width: 130px">
                <span class="h3">
            	Name or Case #:
                </span>
            </td>

            <td class="textinput">
                <div>
                    <div>
                        <input placeholder="Enter Name or Case Number to Search" style="line-height: 1.25em" type="text" id="searchname" name="name" size="30" title="Enter Name or Case Number to Search"/>
                        <button style="height: 2em" type="button" class="search" title="Search Button">Search</button>
                        <!--<input style="height: 2em" type="submit" name="gosearch" class="search" value="Search"/>-->
                    </div>

                    <div>
                        <button style="height: 2em" class="toggleSearchOpts" type="button" title="Toggle Search Options">Show/Hide Search Options</button>
                    </div>
                    
                    <div id="searchOpts" style="display: none">
                        <div>
                            <div class="datePickerDiv" style="display: table; line-height: normal; margin-top: 1em">
                                <div style="display: table-row">
                                    <div style="display: table-cell; width: 9em">
                                        <input placeholder="DOB" style="line-height: 1.25em; width: 6em; margin-right: .5em;" class="datepicker" id="DOB" name="DOB"/>
                                    </div>
                                    <div style="display: table-cell;">
                                        DOB (will only list cases where DOB matches) &nbsp;  
                                    </div>
                                     <div style="display: table-cell;">
                                        <input type="checkbox" id="fuzzyDOB" name="fuzzyDOB" checked="checked" value="1">
                                     </div>
                                     <div style="display: table-cell;">
                                        Approximate DOB (will search 15 days before and after)&nbsp;
                                     </div>
                                     <div style="display: table-cell; vertical-align: middle">
                                        <button type="button" class="clearDates" title="Clear Date of Birth">Clear DOB</button>
                                     </div>
                                </div>
                            </div>
                            
                            <div class="datePickerDiv" style="display: table; line-height: normal">
                                <div style="display: table-row">
                                    <div style="display: table-cell">
                                        File Dates Between
                                    </div>
                                    <div style="display: table-cell: width: 9em">
                                        <input placeholder="Begin" style="line-height: 1.25em; width: 6em; margin-right: .5em;" class="datepicker" id="searchStart" name="searchStart"/>
                                    </div>
                                    <div style="display: table-cell; padding-left: .5em; padding-right: .5em;">
                                        and
                                    </div>
                                    <div style="display: table-cell; width: 9em">
                                        <input placeholder="End" style="line-height: 1.25em; width: 6em; margin-right: .5em;" class="datepicker" id="searchEnd" name="searchEnd"/>
                                    </div>
                                    <div style="display: table-cell">
                                        Name searches only &nbsp;
                                    </div>
                                    <div style="display: table-cell">
                                        <button type="button" class="clearDates" title="Clear Dates">Clear Dates</button> 
                                    </div>
                                </div>
                            </div>
                            
                            <div id="soundexSearchOpts" style="display: table; line-height: normal">
                                <div style="display: table-row">
                                    <div style="display: table-cell">
                                        <input type="checkbox" name="soundex" value="1"/>
                                    </div>
                                    <div style="display: table-cell; padding-left: .5em" title="Search for Name Sounding Like Entered Value">
                                        'Sounds Like' Name Search
                                    </div>
                                </div>
                            </div>
                            
                            <div id="busNameSearchOpts" style="display: table; line-height: normal">
                                <div style="display: table-row">
                                    <div style="display: table-cell">
                                        <input type="checkbox" name="business" value="1"/>
                                    </div>
                                    <div style="display: table-cell; width: 12em; padding-left: .5em" title="Search for Business Names Only">
                                        Business Names Only &nbsp;
                                    </div>
                                    <div style="display: table-cell">
                                        <span style="color: red">
                                            Use * as a root or word expander. For example, searching
                                            <span style="font-style: italic; font-weight: bold">exxon*</span>
                                            will return "Exxon", "Exxon Mobil", "Exxon Corp", etc. </span>
                                    </div>
                                </div>
                            </div>
                            
                            <div id="bookingPhotoSearchOpts" style="display: table; line-height: normal;">
                                <div style="display: table-row">
                                    <div style="display: table-cell">
                                        <input type="checkbox" name="photos" value="1"/>
                                    </div>
                                    <div style="display: table-cell; padding-left: .5em" title="Search Booking Photos (if applicable)">
                                        Show Booking Photos
                                    </div>
                                </div>
                            </div>
                            
                            
                            <div id="divSeachOptsGroup" class="optsTop">
                                <div id="divisionSearchOptsTitle" style="display: table; line-height: normal; margin-top: 1em;">
                                    <div style="display: table-row">
                                        <div style="display: table-cell;">
                                            <span class="h2">Divisions</span>
                                        </div>
                                    </div>
                                </div>
                                <div id="divisionSearchOptsAll" class="allDiv" style="display: table; line-height: normal">
                                    <div style="display: table-row" class="allOptsDiv">
                                        <div style="display: table-cell; width: 1em; margin-right: 1em;">
                                            <input type="checkbox" class="allOptsCheck" name="limitdiv" value="All" checked="checked"/>
                                        </div>
                                        <div style="display: table-cell;">
                                            All (uncheck to choose individual divisions)
                                        </div>
                                    </div>
                                </div>
                                <div id="divisionSearchOpts" class="optsDiv" style="display: none; line-height: normal;">
                                    <div style="display: table" class="optsDiv">
                                        {$count = 0} {$perCol = 10}
                                        {while $count < $divlist|@count} 
                                        <div style="display: table-row">
                                            {for $inc=0; $inc < $perCol; $inc++}{$div = $divlist[$count + $inc]}
                                            {if $div != ""}
                                            <div style="display: table-cell; width: 1em; margin-right: 1em;">
                                                <input type="checkbox" class="optCheck" name="limitdiv" value="{$div}"/>
                                            </div>
                                            <div style="display: table-cell; width: 10em; margin-right: 2em" title="Divison {$div}">
                                                {$div}
                                            </div>
                                            {/if}
                                            {/for}
                                        </div>
                                        {$count = $count + $perCol}
                                        {/while}
                                    </div>
                                </div>
                            </div>
                            
                            <div id="courtTypeSearchOptsGroup" class="optsTop">
                                <div id="courtTypeSearchOptsTitle" style="display: table; line-height: normal; margin-top: 1em;">
                                    <div style="display: table-row">
                                        <div style="display: table-cell;">
                                            <span class="h2">Court Types</span>
                                        </div>
                                    </div>
                                </div>
                                
                                <div id="courtTypeSearchOptsAll" class="allDiv" style="display: table; line-height: normal;">
                                    <div style="display: table-row" class="allOptsDiv">
                                        <div style="display: table-cell; width: 1em; margin-right: 1em;">
                                            <input type="checkbox" class="allOptsCheck" name="limittype" value="All" checked="checked"/>
                                        </div>
                                        <div style="display: table-cell;">
                                            All (uncheck to choose individual divisions)
                                        </div>
                                    </div>
                                </div>
                                
                                <div id="courtTypeSearchOpts" class="optsDiv" style="display: none; line-height: normal;">
                                    <div style="display: table" class="optsDiv">
                                        {$count = 0} {$perCol = 3}
                                        {while $count < $divtypes|@count} 
                                        <div style="display: table-row">
                                            {for $inc=0; $inc < $perCol; $inc++}{$divtype = $divtypes[$count + $inc]}
                                            {if $divtype != ""}
                                            <div style="display: table-cell; width: 20em; margin-right: 2em" title="{$divtype.division_type}">
                                                <input type="checkbox" class="optCheck" name="limittype" value="{$divtype.division_type}"/>{$divtype.division_type}
                                            </div>
                                            {/if}
                                            {/for}
                                        </div>
                                        {$count = $count + $perCol}
                                        {/while}
                                    </div>
                                </div>
                            </div>
                            
                            <div id="PartyTypeSearchOptsGroup" class="optsTop">
                                <div id="PartyTypeSearchOpts" style="display: table; line-height: normal; margin-top: 1em;">
                                    <div style="display: table-row">
                                        <div style="display: table-cell;">
                                            <span class="h2">Party Types</span>
                                        </div>
                                    </div>
                                    <div style="display: table-row" class="allOptsDiv">
                                        <div style="display: table-cell" title="Select All Party Types">
                                            <input type="checkbox" class="allOptsCheck" name="partyTypeLimit" value="All" checked="checked"/>All (uncheck to choose specific types)
                                        </div>
                                    </div>
                                </div>
                                <div id="PartyTypeSearchOptsSpecial" style="display: table; line-height: normal;">
                                    <div style="display: none" class="optsDiv">
                                        <div style="display: table-row">
                                            <div style="display: table-cell; width: 1em; margin-right: 2em">
                                                <input type="checkbox" class="attyCheck" data-targetclass="attyParty" style="margin-right: .5em"/>
                                            </div>
                                            <div style="display: table-cell" title="Select All Attorney Types">
                                                <strong>All Attorney Parties</strong>
                                            </div>
                                            <div style="display: table-cell; width: 1em; margin-right: 2em">
                                                <input type="checkbox" class="dftCheck" data-targetclass="dftParty" style="margin-right: .5em"/>
                                            </div>
                                            <div style="display: table-cell" title="Select All Defendant Types">
                                                <strong>All Defendant Parties</strong>
                                            </div>
                                        </div>
                                        {$count = 0} {$perCol = 3}
                                        {while $count < $partyTypes|@count} 
                                        <div style="display: table-row">
                                            {for $inc=0; $inc < $perCol; $inc++}{$partytype = $partyTypes[$count + $inc]}
                                            {if $partytype.PartyTypeDescription != ""}
                                            <div style="display: table-cell; width: 1em; margin-right: 2em">
                                                <input type="checkbox" class="optCheck {$partytype.PartyClass}" name="partyTypeLimit" value="{$partytype.PartyType}"/>
                                            </div>
                                            <div style="display: table-cell; width: 20em; margin-right: 2em; padding-right: 1em" title="{$partytype.PartyTypeDescription}">
                                                {$partytype.PartyTypeDescription}
                                            </div>
                                            {/if}
                                            {/for}
                                        </div>
                                        {$count = $count + $perCol}
                                        {/while}
                                    </div>
                                </div>
                            </div>
                            
                            <div id="chargeSearchOptsGroup" class="optsTop">
                                <div id="chargeSearchOpts" style="display: table; line-height: normal; margin-top: 1em; margin-bottom: 2em;">
                                    <div style="display: table-row">
                                        <div style="display: table-cell;">
                                            <span class="h2">Charge Types (Criminal Cases Only)</span>
                                        </div>
                                    </div>
                                    <div style="display: table-row" class="allOptsDiv">
                                        <div style="display: table-cell">
                                            <input type="checkbox" class="allOptsCheck" name="chargetype" value="All" checked="checked"/>All (uncheck to choose specific types)
                                        </div>
                                    </div>
                                    <div style="display: none;" class="optsDiv">
                                        {$count = 0} {$perCol = 3}
                                        {$charges = $searchParams.Charges}
                                        {$inc = 0}
                                        <div style="display: table-row;">
                                        {foreach $charges as $key => $val}
                                            <div style="display: table-cell; width: 1em; margin-right: 2em">
                                                <input type="checkbox" class="optCheck" name="chargetype" value="{$val}"/>
                                            </div>
                                            <div style="display: table-cell; width: 20em; margin-right: 2em; padding-right: 1em" title="{$key}">
                                                {$key}
                                            </div>
                                            {$inc = $inc + 1}
                                        {if (($inc == $perCol) || ($charges.last))}
                                        {$inc = 0}
                                        </div>
                                        <div style="display: table-row;">
                                        {/if}
                                        
                                        {/foreach}
                                        </div>
                                    </div>
                                </div>
                            </div>
                            
                            <div id="causeSearchOptsGroup" class="optsTop">
                                <div id="causeSearchOpts" style="display: table; line-height: normal; margin-top: 1em; margin-bottom: 2em;">
                                    <div style="display: table-row">
                                        <div style="display: table-cell;">
                                            <span class="h2">Causes of Action (Non-Criminal)</span>
                                        </div>
                                    </div>
                                    <div style="display: table-row" class="allOptsDiv">
                                        <div style="display: table-cell">
                                            <input type="checkbox" class="allOptsCheck" name="causetype" value="All" checked="checked"/>All (uncheck to choose specific types)
                                        </div>
                                    </div>
                                    <div style="display: none;" class="optsDiv">
                                        {$count = 0} {$perCol = 3}
                                        {$charges = $searchParams.Causes}
                                        {$inc = 0}
                                        <div style="display: table-row;">
                                        {foreach $charges as $key => $val}
                                            <div style="display: table-cell; width: 1em; margin-right: 2em">
                                                <input type="checkbox" class="optCheck" name="causetype" value="{$val}"/>
                                            </div>
                                            <div style="display: table-cell; width: 20em; margin-right: 2em; padding-right: 1em" title="{$key}">
                                                {$key}
                                            </div>
                                            {$inc = $inc + 1}
                                        {if (($inc == $perCol) || ($charges.last))}
                                        {$inc = 0}
                                        </div>
                                        <div style="display: table-row;">
                                        {/if}
                                        
                                        {/foreach}
                                        </div>
                                    </div>
                                </div>
                            </div>
                            
                    <div>
                        
                        
                    <div style="display: table; line-height: normal;">
                        <div style="display: table-row">
                            <div style="display: table-cell">
                                <input type="checkbox" name="active" value="1"/>
                            </div>
                            <div style="display: table-cell; padding-left: .5em" title="Search Only Active Cases">
                                Active Cases Only &nbsp;&nbsp;
                            </div>
                            <div style="display: table-cell">
                                <input type="checkbox" name="charges" checked="checked" value="1"/>
                            </div>
                            <div style="display: table-cell; padding-left: .5em" title="Search Charges">
                                Show Charge Information
                            </div>
                        </div>
                    </div>

                    <div style="display: table; line-height: normal;">
                        <div style="display: table-row">
                            <div style="display: table-cell">
                                <input id="crimonly" type="checkbox" name="criminal" value="1" onchange="toggleOpposite('crimonly','civonly')"/>
                            </div>
                            <div style="display: table-cell; padding-left: .5em" title="Search Only Criminal and Traffic Cases">
                                Criminal and Traffic Cases Only
                            </div>
                        </div>
                    </div>

                    <div style="display: table; line-height: normal;">
                        <div style="display: table-row">
                            <div style="display: table-cell">
                                <input id="civonly" type="checkbox" name="nocriminal" value="1" onchange="toggleOpposite('civonly','crimonly')"/>
                            </div>
                            <div style="display: table-cell; padding-left: .5em" title="Search Only Civil Cases">
                                Civil Cases Only
                            </div>
                        </div>
                    </div>
                </div>


                        </div>
                    </div>
                </div>
            </td>
	    </tr>

	    <tr>
            <td colspan="2">
                <input type="hidden" name="type" value=""/>
            </td>
        </tr>

        <tr>
            <td style="text-align:right; vertical-align:top;">
                <span class="h3">
                    Citation #:
                </span>

            </td>

            <td class="textinput">
                <div>
                    <input placeholder="Search by Citation #" style="line-height: 1.25em" type="text" id="searchcitation" name="citation" size="30" title="Enter Citation #"/>
                    <button style="height: 2em" type="button" class="search" title="Search Button">Search</button>
                </div>

            </td>
	    </tr>
                </form>

        <tr>
            <td>&nbsp;</td>
            <td>
                <button type="button" class="docSearchToggle">Show/Hide Document Search</button>
                
                <div id="docSearchTop" style="display: none">
                    <form id="docSearchForm">
                        <div id="docSearchDiv" style="display: table">
                            <div id="docSearchHeaders" style="display: table-header-group;">
                                <div class="docSearchCell docSearchHeader" style="display: table-cell" title="Select Court Type to Search">
                                    Court Type
                                </div>
                                <div class="docSearchCell docSearchHeader" style="display: table-cell" title="Select Division to Search">
                                    Division
                                </div>
                                <div class="docSearchCell docSearchHeader" style="display: table-cell" title="Select Case Numbers to Search">
                                    Case Numbers (Overrides other settings - separate multiple cases with spaces or commas)
                                </div>
                                <div class="docSearchCell docSearchHeader" style="display: table-cell" title="Enter Search Term">
                                    Search Term
                                </div>
                            </div>
                            
                            <div id="docSearchSelects" style="display: table-row-group">
                                <div class="docSearchCell" id="ds_courtTypeDiv" style="display: table-cell">
                                    <select id="searchCore" name="searchCore">
                                        <option value="all" selected="selected" title="All Court Types">All</option>
                                        <option value="civil" title="Civil Divisions">Civil</option>
                                        <option value="criminal" title="Criminal Divisions">Criminal</option>
                                        <option value="family" title="Family Divisions">Family</option>
                                        <option value="juvenile" title="Juvenile Divisions">Juvenile</option>
                                        <option value="probate" title="Probate Divisions">Probate</option>
                                    </select>
                                </div>
                                <div class="docSearchCell" id="ds_divisionDiv" style="display: table-cell">
                                    <select id="searchDiv" name="searchDiv">
                                        <option value="all" selected="selected" title="Search All Divisions">All</option>
                                        {foreach $allDivsArray as $div}
                                        <option value="{$div}" title="Division {$div}">{$div}</option>
                                        {/foreach}
                                    </select>
                                </div>
                                <div class="docSearchCell" id="ds_caseNum" style="display: table-cell">
                                    <input type="text" style="width: 35em" name="dsCaseNumSearch" id="dsCaseNumSearch" placeholder="Case Number" title="Enter Case Number(s) to Search">
                                </div>
                                
                                <div class="docSearchCell" id="ds_serchTerm" style="display: table-cell">
                                    <input type="text" name="dsSearchTerm" id="dsSearchTerm" placeholder="Search Term" title="Enter Search Term"/>
                                    <button type="button" class="docSearchBtn">Search</button>
                                </div>
                            </div>
                            
                            <div style="display: table-row-group">
                                <div class="docSearchCell" style="display: table-cell">&nbsp;</div>
                                <div class="docSearchCell" style="display: table-cell">&nbsp;</div>
                                <div class="docSearchCell" id="searchCaseStyle" style="display: table-cell; width: 40em; max-width: 40em;">
                                    <div style="display: table" id="searchStyleTable">
                                        
                                    </div>
                                </div>
                                <div class="docSearchCell" style="display: table-cell"></div>
                            </div>
                        </div>
                    </form>
                    
                    <div id="docSearchResults" style="display: none">
                        <button type="button" class="toggleDocSearchResults">Show/Hide Search Results</button>
                        <div id="totalSearch">
                            <span style="font-size: 120%; font-weight: bold"><span id="searchCount"></span> matching documents found.</span>
                            <table id="docSearchTable">
                                <thead>
                                    <tr>
                                        <th>Case Number</th>
                                        <th>Document</th>
                                        <th>Highlights</th>
                                    </tr>
                                </thead>
                                <tbody id="docSearchTableBody">
                                
                                </tbody>
                            </table>
                        </div>
                    </div>
                    
                </div>
            </td>
        </tr>
                
	    <tr>
		<td colspan="2">
		    &nbsp;
		</td>
	    </tr>

	    <tr>
            <td colspan="2">
                <span class="h3">
                    <a href="#" data-script="/cgi-bin/casenotes/flaggedCaseSearch.cgi" data-tab="flagsearch" data-foo="bar"
                       data-tab-title="Flagged Case Search" class="miscLink" title="Flagged Case Search">
                        Flagged Case Search
                    </a>
                </span>
            </td>
        </tr>
        
        <tr>
            <td colspan="2">
                <span class="h3">
                    <a href="#" data-script="/cgi-bin/casenotes/bulkflag.cgi" data-tab="bulkflag"
                       data-tab-title="Bulk Case Flagging/Unflagging" class="miscLink" title="Bulk Case Flagging/Unflagging">
                        Bulk Case Flagging/Unflagging
                    </a>
                </span>
            </td>
        </tr>

        <tr>
            <td colspan="2">
                <span class="h3">
                    <a href="#" data-script="/cgi-bin/PBSO/pbsolookup.cgi" data-tab="pbsolookup"
                       data-tab-title="PBSO Search" class="miscLink" title="PBSO Search">
                        PBSO Search
                    </a>
                </span>
            </td>
        </tr>
        
        <tr>
            <td colspan="2">
                <span class="h3">
                    <a href="#" data-script="/cgi-bin/eservice/showFilings.cgi" data-tab="efilings"
                       data-tab-title="My E-Filing Status" class="miscLink" title="Show My e-Filing Status">
                        <span style="color:red">NEW!</span>View my e-Filing Status
                    </a>
                </span>
            </td>
        </tr>
        
        <tr>
            <td colspan="2">
                <span class="h3">
                    <a href="#" data-script="/watchlist/showWatchList.php" data-tab="watchList"
                       data-tab-title="My Case Watchlist" class="miscLink" title="Show My Case Watchlist">
                        Show My Case Watchlist
                    </a>
                </span>
            </td>
        </tr>
    </table>
    
    <br/>

    <table style="border:none">
        <tr>
            <td>
                <div class="h2">
                    Judge Reports
                </div>
            </td>
        </tr>
        
        <tr>
            <td>
                <span class="h3">
                    
                </span>
                
                <select name="judgexy" title="Select Judge">
                    {foreach from=$judges key=judge item=divs}
                    <option value="{$judge}~{$divs}" title="{$judge}">{$judge}</option>
                    {/foreach}
                </select>
                <button type="button" class="reportView judgeRpt" title="Submit Button">View</button>
	    </td>
	</tr>
	
	<tr>
		<td colspan="2">
			&nbsp;
		</td>
	</tr>
	<tr>
    	<td>
        	<div class="h2">
            	Magistrate Reports
            </div>
        </td>
    </tr>
    <tr>
	    <td>
		<span class="h3">

		</span>
		<select name="magistratexy">
			{foreach from=$magistrates key=m item=mag}
				<option value="{$mag}">{$m}</option>
			{/foreach}
		</select>
		<button type="button" class="reportView magRpt" title="Submit Button">View</button>
	    </td>
	</tr>

	<tr>
	    <td>
		<table style="border:none">
            <tr>
                <td>
                    <div class="h2">
                        Division Reports
                    </div>
                </td>
            </tr>
            
            <tr>
				<td>
				    <span class="h3">

				    </span>
                    <select name="divxy" title="Select Division">
                        {foreach from=$divlist item=div}
                        {if !in_array($div,$skipDivs)}
                        <option value="{$divisions.$div.opt}" title="{$divisions.$div.courtType} Division {$div}">{$div} {if $div != 'VA'}({$divisions.$div.courtType}){/if}</option>
                        {/if}
                        {/foreach}
                    </select>
                    <button type="button" class="reportView divRpt" title="Submit Button">View</button>
                </td>
                
            </tr>

            <tr>
                <td>
                    <span class="h3">
                        <a href="#" data-script="/cgi-bin/alldivs.cgi" data-tab="allcrimdivs" data-type="crim"
                           data-tab-title="All Criminal Divisions" class="divLink" title="Show All Criminal Divisions">
                            All Criminal Divisions
                        </a>
                    </span>
                </td>
		    </tr>

		    <tr>
                <td>
                    <span class="h3">
                        <a href="#" data-script="/cgi-bin/alldivs.cgi" data-tab="allcivdivs" data-type="civ"
                           data-tab-title="All Civil Divisions" class="divLink" title="Show All Civil Divisions">
                            All Civil Divisions
                        </a>
                    </span>
                </td>
		    </tr>

		    <tr>
                <td>
                    <span class="h3">
                        <a href="#" data-script="/cgi-bin/alldivs.cgi" data-tab="allfamdivs" data-type="fam"
                           data-tab-title="All Family Divisions" class="divLink" title="Show All Family Divisions">
                            All Family Divisions
                        </a>
                    </span>
                </td>
		    </tr>
            
            <tr>
                <td>
                    <span class="h3">
                        <a href="#" data-script="/cgi-bin/alldivs.cgi" data-tab="alljuvdivs" data-type="juv"
                           data-tab-title="All Juvenile Divisions" class="divLink" title="Show All Juvenile Divisions">
                            All Juvenile Divisions
                        </a>
                    </span>
                </td>
		    </tr>
            
            <tr>
                <td>
                    <span class="h3">
                        <a href="#" data-script="/cgi-bin/alldivs.cgi" data-tab="allprodivs" data-type="pro"
                           data-tab-title="All Probate Divisions" class="divLink" title="Show All Probate Divisions">
                            All Probate Divisions
                        </a>
                    </span>
                </td>
		    </tr>
		</table>
	    </td>
	</tr>
	</table>

	<table style="border:none">
		<tr style="vertical-align: top">
			<td>
				<div class="h2">
					Circuit Civil Calendars
				</div>
			</td>
		</tr>
		<tr>
			<td id="civsel">
				<select style="min-width: 15em" class="divsel" name="caldiv" id="caldiv" title="Select a Civil Division">
					<option value="" title="Select a Division">Select a Division</option>
                    {foreach from=$olsdiv item=div}
                    <option value="{$div}" title="Division {$div}">Division {$div|strtoupper}</option>
                    {/foreach}
				</select>
                <button class="calsubmit" name="calType" value="civcal" title="Submit Button">View</button>
		    </td>
		</tr>

		<tr>
			<td>
				&nbsp;
			</td>
		</tr>
		
		<tr style="vertical-align: top">
			<td>
				<div class="h2">
					County Civil Calendars
				</div>
			</td>
		</tr>
		<tr>
			<td id="cocivselsel">
				<select style="min-width: 15em" class="divsel" name="cocivdiv" id="cocivdiv" title="Select a Civil Division">
					<option value="" title="Select a Division">Select a Division</option>
                    {foreach from=$cocivdivs key=div item=info}
                    <option value="{$div}" title="Division {$div}">{$div} ({$info.courtType})</option>
                    {/foreach}
				</select>
                <button class="calsubmit" name="calType" value="cocivvcal" title="Submit Button">View</button>
		    </td>
		</tr>

		<tr>
			<td>
				&nbsp;
			</td>
		</tr>

		<tr style="vertical-align: top">
			<td>
				<div class="h2">
					Criminal Calendars
				</div>
			</td>
		</tr>
		<tr>
			<td id="crimsel">
				<select style="min-width: 15em" class="divsel"  name="crimdiv" id="crimdiv" title="Select Criminal Division">
                    <option value="" title="Select a Division">Select a Division</option>
                    {foreach from=$crimdivs key=div item=info}
                    <option value="{$div}" title="Division {$div}">{$div} ({$info.courtType})</option>
                    {/foreach}
				</select>
                <button class="calsubmit" name="calType" value="crimcal" title="Submit Button">View</button>
		    </td>
		</tr>

        <tr>
			<td>
				&nbsp;
			</td>
		</tr>

        <tr style="vertical-align: top">
			<td>
				<div class="h2">
					Juvenile Calendars
				</div>
			</td>
		</tr>
		<tr>
			<td id="juvsel">
				<select style="min-width: 15em" class="divsel"  name="juvdiv" id="juvdiv" title="Select Juvenile Division">
					<option value="" title="Select a Division">Select a Division</option>
                    {foreach from=$juvdivs key=div item=info}
                    <option title="Division {$div}" value="{$div}">{$div} ({$info.courtType})</option>
                    {/foreach}
				</select>
                <button class="calsubmit" name="calType" value="juvcal" title="Submit Button">View</button>
		    </td>
		</tr>
        
        
		<tr>
			<td>
				&nbsp;
			</td>
		</tr>
		
		<tr style="vertical-align: top">
			<td>
				<div class="h2">
					Magistrate Calendars
				</div>
			</td>
		</tr>
        
        <tr>
			<td id="magsel">
				<select style="min-width: 15em" class="divsel"  name="magch" id="magch">
                    {foreach from=$calMagistrates key=key item=m}
                    	<option value="{$key}">{$m}</option>
                    {/foreach}
				</select>
                <button class="calsubmit" name="calType" value="magcal">View</button>
                <input type="hidden" name="magcal" id="magcal" value=""/>
		    </td>
		</tr>

		
		<tr>
			<td>
				&nbsp;
			</td>
		</tr>
		

        <tr style="vertical-align: top">
			<td>
				<div class="h2">
					First Appearance Calendars
				</div>
			</td>
		</tr>
        
        <tr>
			<td id="fapsel">
				<select title="Select Courthouse for First Appearance" style="min-width: 15em" class="divsel"  name="fapch" id="fapch">
					<option value="" title="Select a Location">Select a Location</option>
                    {foreach from=$faps item=info}
                    <option title="{$info.courthouse_nickname} Courthouse" value="{$info.courthouse_id}">{$info.courthouse_nickname}</option>
                    {/foreach}
				</select>
                <button class="calsubmit" name="calType" value="fapcal" title="Submit Button">View</button>
		    </td>
		</tr>

		
		<tr>
			<td>
				&nbsp;
			</td>
		</tr>
		
		<tr>
			<td>
                <a class="trafficDocket" style="text-decoration: underline; cursor: pointer" title="Show Traffic Dockets">
                <!--<a href="/cgi-bin/calendars/trafficDocket.cgi">-->
                    Traffic Dockets
                </a>
            </td>
		</tr>


	</table>

	<br/>

	<div class="probs">
		<div class="probstitle">
			Problems?
		</div>

		Please e-mail <a href="mailto:cad-web@pbcgov.com">cad-web@pbcgov.com</a>
		to report any problems with this system.
	</div>

	<div class="disc">
		<strong>
		    Disclaimer
		</strong>
		<br/>
		The Court warrants that the images viewed on this site are what
		they purport to be. However, the Court makes no warranty as to
		whether additional documents exist that could affect a case,
		but do not yet appear on the docket. Furthermore, the Court
		does not warrant whether any data entered by the Clerk
		(including the docket index) is accurate.
	</div>

	<div style="font-size:50%">
		Court Technology Department, Fifteenth Judicial
		Circuit of Florida
    </div>
	
	</div>
