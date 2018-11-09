<!DOCTYPE html>
    
<!-- $Id: tabs.tpl 2246 2015-09-08 18:46:26Z rhaney $ -->

<html>

    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
        <meta http-equiv="pragma" content="no-cache"/>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="Author" content="Default" />

        <title>
        	15th Circuit Case Management System
        </title>
	
        <link rel="stylesheet" type="text/css" href="/style/normalize.css"/>
        <link rel="stylesheet" type="text/css" href="/javascript/bootstrap/3.2.0/css/bootstrap.css"/>
        <link href="https://e-services.co.Sarasota-beach.fl.us/cdn/style/jquery-ui-1.10.4/themes/south-street/jquery-ui.css" type="text/css" rel="stylesheet"/>
        
        <link rel="stylesheet" type="text/css" href="/icms1.css?1.2" />
        <link rel="stylesheet" type="text/css" href="/style/reports.css?1.2" />
        <link rel="stylesheet" type="text/css" href="/style/calendars.css?1.1" />
        
        <link rel="stylesheet" href="/style/ICMS.css?1.5" />
        <link rel="stylesheet" href="/style/ICMS2.css?1.3" />
        <link rel="stylesheet" href="/style/image-cgi.css?1.1" />
        <link rel="stylesheet" href="/style/nav.css?1.1" />
        <link rel="stylesheet" href="/style/view.css?1.1" />
        <link rel="stylesheet" href="/style/font-awesome.min.css?1.1" />
        <link rel="stylesheet" href="/style/docviewer.css?1.1" />
        <link rel="stylesheet" href="/style/toastr.min.css?1.1" />
        <link rel="stylesheet" href="/style/fullcalendar.css?1.1" type="text/css" />
        <link rel="stylesheet" href="/style/eservice.css?1.5" type="text/css" />
        <link rel="stylesheet" type="text/css" href="https://e-services.co.Sarasota-beach.fl.us/cdn/style/bootstrap/bootstrap-datetimepicker.min.css"/>
		
        <script src="/javascript/jquery/jquery-1.11.0.js" type="text/javascript"></script>
        <script src="/javascript/bootstrap/3.2.0/js/bootstrap.min.js" type="text/javascript"></script>
        <script src="https://e-services.co.Sarasota-beach.fl.us/cdn/jslib/bootstrap/bootstrap-datetimepicker.min.js" type="text/javascript"></script>
        <script type="text/javascript" src="https://e-services.co.Sarasota-beach.fl.us/cdn/jslib/jquery-ui-1.10.4.min.js"></script>
        <script type="text/javascript" src="https://e-services.co.Sarasota-beach.fl.us/cdn/jslib/jquery.blockUI.js"></script>
		<script src="https://e-services.co.Sarasota-beach.fl.us/cdn/jslib/jquery.tablesorter-2.16.1.js" type="text/javascript"></script>
		<script src="https://e-services.co.Sarasota-beach.fl.us/cdn/jslib/jquery.tablesorter.widgets-2.16.1.js" type="text/javascript"></script>
		<script src="https://e-services.co.Sarasota-beach.fl.us/cdn/jslib/jquery.tablesorter.pager.min.js" type="text/javascript"></script>
        <script src="https://e-services.co.Sarasota-beach.fl.us/cdn/jslib/jquery.cookie.js" type="text/javascript"></script>
        <script src="/javascript/jquery.shim.js?1.1"></script>
        <script src="/javascript/docviewer.js?1.1"></script>
        <script src="/javascript/notes.js?1.1"></script>
        <script src="/javascript/ckeditor/ckeditor.js"></script>
        <script type="text/javascript">
                // do this before the first CKEDITOR.replace( ... )
                CKEDITOR.timestamp = +new Date;
        </script>
        <script src="/javascript/ckeditor/adapters/jquery.js"></script>
        <script type="text/javascript" src="https://e-services.co.Sarasota-beach.fl.us/cdn/jslib/jquery.placeholder.js"></script>
        <script src="/icms.js?1.1" type="text/javascript"></script>
        <script src="/javascript/casenotes/notesAndFlags.js?1.4" type="text/javascript"></script>
        <script src="/javascript/ICMS.js?1.1" type="text/javascript"></script>
        <script src="/javascript/main.js?1.1" type="text/javascript"></script>
        <script src="/javascript/ajax.js?1.1" type="text/javascript"></script>
        <script src="/javascript/casedetails.js?1.8" type="text/javascript"></script>
        <script src="/javascript/orders.js?1.5" type="text/javascript"></script>
        <script src="/javascript/calendars/utils.js?1.2" type="text/javascript"></script>
        <script src="/javascript/casedetails/utils.js?1.2" type="text/javascript"></script>
        <script src="/javascript/settings.js?1.1" type="text/javascript"></script>
        <script src="/javascript/workflow.js?1.5" type="text/javascript"></script>
        <script src="/javascript/eservice.js?1.2" type="text/javascript"></script>
        <script src="/javascript/vrb.js?1.1" type="text/javascript"></script>
        <script src="/javascript/divReports.js?1.1" type="text/javascript"></script>
        <script src="/javascript/jquery/jquery.form.js"></script> 
        <script src="/javascript/jquery/jquery.ui-contextmenu.js?1.1"></script>
        <script src="/javascript/jquery.pleasewait.js?1.1" type="text/javascript"></script>
        <script src="/javascript/fusioncharts/fusioncharts.js?1.1"></script>
        <script src="/javascript/fusioncharts/fusioncharts.charts.js?1.1"></script>
        <script src="/javascript/fusioncharts/fusioncharts-jquery-plugin.js?1.1"></script>
        <script src="/javascript/fusioncharts/themes/fusioncharts.theme.fint.js?1.1"></script>        
    </head>

    <body>
        <script type="text/javascript">
            var USER = '{$userid}';
            var ySize;
            var tabHeight;
            var headerHeight;
            var pageHeight;
            var innerPaneHeight;
            
            //Reloading WF tab every minute
            window.setInterval(function(){
				loadWfTab(1);
			}, 120000);
            
            $.ajaxSetup({ cache: false });
            
            function changeCss(className, classValue) {
                // Handy function by Matthew Wolf, from
                // http://stackoverflow.com/questions/11474430/change-css-class-properties-with-jquery
                
                // we need invisible container to store additional css definitions
                var cssMainContainer = $('#css-modifier-container');
                if (cssMainContainer.length == 0) {
                    var cssMainContainer = $('<div id="css-modifier-container"></div>');
                    cssMainContainer.hide();
                    cssMainContainer.appendTo($('body'));
                }
                
                // and we need one div for each class
                classContainer = cssMainContainer.find('div[data-class="' + className + '"]');
                if (classContainer.length == 0) {
                    classContainer = $('<div data-class="' + className + '"></div>');
                    classContainer.appendTo(cssMainContainer);
                }
                
                // append additional style
                classContainer.html('<style>' + className + ' { ' + classValue + ' }</style>');
            }
            
            function raiseTab (tabName) {
                tabSel = '#' + tabName;
                parentTab = $(tabSel).parents
                ('.tab-pane');
                if ($(parentTab).length) {
                    raiseTab($(parentTab).attr('id'));
                }
                alert(tabSel);
                return true;
            }
            
            function createTab (tabName, tabTitle, parentTab, tabClass, hasChildren) {
                // If the tab doesn't already exist, create it.
                var tabSel = '#' + tabName;
                if (!$(tabSel).length) {
                    // Doesn't exist.  Create it in the topTab
                    var parentListSel = '#' + parentTab + 'list';
                    var parentTopSel = '#' + parentTab + 'tabs';
                    var pls = $(parentListSel);
                    var pts = $(parentTopSel);
                    $(parentListSel).append('<li title="' + tabTitle + '"><a id="' + tabSel + '_link" href="' + tabSel + '" data-toggle="tab">' + tabTitle + '<button class="closeTab">x</button></a></li>');
                    $(parentTopSel).append('<div class="tab-pane" id="'+ tabName + '">');
                    
                    if ((hasChildren != undefined) && (hasChildren)) {
                        $(tabSel).append('<ul id="' + tabName + 'list" class="nav nav-tabs">');
                        $(tabSel).append('<div class="tab-content" id="'+ tabName + 'tabs">');
                    }
                }
                if (tabClass != undefined) {
                    $(tabSel).addClass(tabClass);
                }
            }
            
            
            function countRows(tableid, target) {
                // Count the rows displayed, and show it in the table header.
                displayedEvents = 0;
                tbody = $('#' + tableid).find('tbody');
                $(tbody).find('tr').each(function (i,e) {
                    if ($(e).css('display') != 'none') {
                        displayedEvents += 1;
                    }
                });
                
                rowWord = " Rows";
                if (displayedEvents == 1) {
                    rowWord = " Row"
                }
                
                $('#' + target).html(displayedEvents + rowWord);
            };
            
            $(document).ready(function (){
            
            	{if $pendCount['pendCount']}
					$('#dialogSpan').html("You have items in the e-Filing portal's Pending Queue that require attention.");
					$('#dialogDiv').dialog({
						resizable: false,
						minheight: 150,
						width: 500,
						modal: true,
						title: 'Filings in Pending Queue',
						buttons: {
							"Review e-Filing Queue": function() {
								$(this).dialog( "close" );
								var url = '/cgi-bin/eservice/showFilings.cgi';
				                var tabName = 'efilings';
				                var tabTitle = 'My E-Filing Status';
				                var topPane = 'search';
				                var targetTop = topPane + 'top';
				                {literal}
				                	$.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait </h1>', fadeIn: 0});
				                {/literal}
				                createTab(tabName,tabTitle,targetTop,'innerPane');
				                loadTab(tabName,url,1);
				                $.unblockUI();
								return true;
							},
							"Cancel": function() {
								$(this).dialog( "close" );
								return false;
							}
						}
					});
				{/if}
            
            	$('img').on('dragstart', function(event) { 
            		event.preventDefault(); 
            	});
            
            	 var url = window.location.search.substring(1);
            	 var plainUrl = url.substring(url.lastIndexOf('/') + 1);
    			 plainUrl = plainUrl.split("?")[0];   
				 var urlVars = url.split('&');
				 
				 var param = urlVars[0].split('=');
				 
				 if(param[0] == 'ext'){
				 	if(param[1] == 'Y'){
				 		var param2 = urlVars[1].split('=');
				 		if(param2[0] == "ucn"){
				 			$("#searchname").val(param2[1]);
				 			$('.search').click();
				 			window.history.pushState("", "15th Circuit Case Management", location.protocol + '//' + location.host + location.pathname);
				 		}
				 	}
				 }

            
                WFTIMESTAMP=0;
                
                $('.tabLink').click(function() {
                    //if ($(this).attr('id') != 'reportLink') {
                    //    $('#reports').hide();
                    //}
                    if ($(this).attr('id') == 'workflowLink') {
                        // Since the tab is hidden when the page loads, the zebra widget doesn't apply.  So apply it
                        // when the tab is shown.
                        $('#workflow').find('.tablesorter').trigger('update');
                        return true;
                    }
                })
                
                ySize = $(window).height();
                tabHeight = $('#masterTabs').height();
                headerHeight = $('#logoDiv').height();
                // calculate the height of the "top" panes, leaving room for bottom scroll bars.
                pageHeight = ySize - tabHeight - headerHeight - 20;
                innerPaneHeight = pageHeight - 100;
                
                loadTab('reports');
                loadWfTab();
                loadTab('settings','/settings/index.cgi');
                
                $('.homeLink').click(function() {
                    // If the logo is clicked, raise the main search form.
                    $('#searchLink').trigger('click');
                    $('#search a[href="#searchform"]').tab('show');
                    return true;
                });
                
                $(window).resize(function() {
                    //var ySize = $(window).height();
                    //var tabHeight = $('#masterTabs').height();
                    //var headerHeight = $('#logoDiv').height();
                    //var pageHeight = ySize - tabHeight - headerHeight - 20;
                    //var innerPaneHeight = pageHeight - 100;
                    AdjustHeights();
                    return true;
                });
				
				$(document).on('click','.noaccess',function(){
					// this presents a dialog message with the link title passed as the body message
					var msg = $(this).attr('title');
					$('#dialogSpan').html(msg);
                    $('#dialogDiv').dialog({
                        resizable: false,
                        minheight: 150,
                        width: 500,
                        modal: true,
                        title: 'No Access',
                        buttons: {
                            "OK": function() {
                                $(this).dialog( "close" );
                                return false;
                            }
                        }
                    });
					
					
				});
                
                $(document).on('click','.closeTab',function(){
                   var target = $(this).parent().attr('href');
                   $(target).remove();
                     /* ADDED TO RETURN BACK TO MAIN TAB IF NOTHING OPEN */
                     var parentTab = $(this).closest('.tab-pane').attr('id');
                     var num = $("#"+parentTab).find('ul').children().length;
                     if(num <= 1)$('a[href="#search"]').tab('show');
                     /* END ADD */
                     $(this).parent().parent().parent().find('a:first').tab('show');
                   $(this).parent().parent().remove();
                   return true;
               });
                
                $(document).on('click','.printTab',function() {
                    var tabID = $(this).closest('.tab-pane').attr('id');
                    var orientation = $(this).data('orientation');
                    if (orientation == undefined) {
                        orientation = 'portrait';
                    }
                    
                    var printContents = $('#' + tabID).clone();
                    // Remove elements that don't make sense on a printed page
                    $(printContents).find('.tablesorter-filter-row').remove();
                    $(printContents).find('.printHide').hide();
                    
                    var myWindow = window.open("", "popup","scrollbars=yes,resizable=yes," +
                                               "toolbar=no,directories=no,location=no,menubar=yes,status=no,left=0,top=0");
                    var doc = myWindow.document;
                    
                    doc.open();
                    
                    doc.write($(printContents).html());
                    $(doc).find('body').addClass('page');
                    $(doc).find('head').append('<link href="/style/print_' + orientation + '.css?1.1" rel="stylesheet" type="text/css"/>');
                    doc.close();
                    myWindow.print();
                    
                    return false;
                });
                
                $(document).on('click','.qRefresh',function() {
                    loadWfTab(1);
                });
                
                return true;
            });
            
            function loadWfTab(doReload) {
                doReload = typeof doReload !== 'undefined' ? 1 : 0;
                
                //See if we were originally on the WF tab, if not we aren't going to open it
                var topTab = $("#masterTabs .active").attr("id");
				if(topTab == "workflowTop"){
                	var curTab = $("#workflowlist .active a").attr("href");
                }
                else{
                	var curTab = "";
                }
                
                if (doReload == 0) {
                    if (WFTIMESTAMP == 0) {
                        doReload = 1;
                    } else {
                        var url = "/workflow/checkQtime.php";
                        $.ajax({
                            url: url,
                            async: true,
                            success: function(data) {
                                return true;
                            }
                        });
                    }
                }
                
                if (doReload != 0) {
                    var url = "/workflow/index.php";
                    
                    $.ajax({
                    	method: "POST",
                        url: url,
                        data: postData,
                        async: true,
                        success: function(data) {
                            WFTIMESTAMP = data.timestamp;
                            showTab(data);
                            
                            //Let's go back to the tab we were on before
                            if(curTab != "" && curTab != undefined){
	                            // Need to display the selected tab.
	                            var topTabSel = $("#workflowlist").closest('.topPane').attr('id');
	                            // Show the top-level tab containing the target
					            $('a[href=#' + topTabSel + ']').tab('show');
					            
	                            if(curTab.indexOf("finished") > -1){
	                            	//In this case, we want to click the right finished button
	                            	var whichQueue = curTab.split('-');
	                            	var thisQueue = whichQueue[1];
	                            	var user = "{$userid}";
		                            if(user == thisQueue){
		                            	thisQueue = "my";
		                            }
	                            	// And then show the target
					           		$('a[href=#' + thisQueue + 'queue]').tab('show');
					           		$('#' + thisQueue + 'queue').find('.showQFinished').first().click();
	                            }
	                            else{
	                            	// And then show the target
					            	$('a[href="' + curTab + '"]').tab('show');
	                            }
			                }
                        }
                    });
                }
                
                return true;
            }
            
            function loadTab(tabname, url, show) {
                // If no URL was specified, default to /tabname/index.php (where tabname is variable)
                url = typeof url !== 'undefined' ? url : '/' + tabname + '/index.php';
                
                show = typeof show !== 'undefined' ? show : 0;
                
                {literal}postData = {tabname: tabname, show: show};{/literal}
                
                // Async load content
                $.ajax({
                	method: "POST",
                    url: url,
                    data: postData,
                    async: true,
                    success: function(data) {
                        showTab(data);
                    }
                });
                return true;
            }
            
            function showTab(data) {
                var json;
                if (data.html == undefined) {
                    json = $.parseJSON(data);
                } else {
                    json = data;
                }
                var tabName = json.tab;
                var tabSel = '#' + tabName;
                var linkSel = tabSel + '_link';
                $(tabSel).html(json.html);
                if (json.show) {
                    // Need to display the selected tab.
                    var topTabSel = $(tabSel).closest('.topPane').attr('id');
                    // Show the top-level tab containing the target
                    $('a[href=#' + topTabSel + ']').tab('show');
                    // And then show the target
                    $('a[href="' + tabSel + '"]').tab('show');
                }
                AdjustHeights();
                return true;
            }
        </script>
        
        <div class="container-fluid">

          <div id="dialogDiv">
                <span id="dialogSpan" style="font-size: 80%"></span>
            </div>
	<div class="row">
	
        <nav class="navbar navbar-default navbar-fixed-top" style="height:81px;" role="navigation">
            
                <ul id="masterTabs" class="nav nav-tabs navbar navbar-left" style="margin-top:43px;">
                    <li class="active topTab" id="searchTop" title="Main Search Tab">
                        <a class="tabLink" id="searchLink" href="#search" data-toggle="tab">Search/Main</a>
                    </li>
                    <li class="topTab" id="caseTop" title="Cases Tab">
                        <a class="tabLink" id="caseLink" href="#cases" data-toggle="tab">Cases</a>
                    </li>
                    <li class="topTab" id="reportTop" title="Reports Tab">
                        <a class="tabLink" id="reportLink" href="#reports" data-toggle="tab">Reports</a>
                    </li>
                    <li class="topTab" id="calendarTop" title="Calendars Tab">
                        <a class="tabLink" id="calendarLink" href="#calendars" data-toggle="tab">Calendars</a>
                    </li>
                    <li class="topTab" id="workflowTop" title="Workflow Tab">
                        <a class="tabLink" id="workflowLink" href="#workflow" data-toggle="tab">Workflow (<span id="wfcount"></span>)</a>
                    </li>
                    <li class="topTab" id="linksTop" title="Links Tab">
                        <a class="tabLink" href="#links" data-toggle="tab">Links</a>
                    </li>
                    <li class="topTab" id="settingsTop" title="Settings Tab">
                        <a class="tabLink" href="#settings" data-toggle="tab">Settings</a>
                    </li>
  
                </ul>
				<div id="logoDiv" class="pull-right hidden-xs" >
					<a href="/"><img class="homeLink img img-responsive"  src="images/JVSLOGO-Wide.jpg" style="max-height:75px; 0 -30px 0 0" title="JVS Logo" alt="JVS" /></a>
				 </div>
				<ul class="nav nav-tabs navbar navbar-right hidden-sm hidden-xs">
				
                    
					<!--<a class="btn btn-default" href="file://///c:/OIVFiles/index.html" target="_blank">OIV</a> -->
					<a class="btn btn-default" href="https://e-services.co.Sarasota-beach.fl.us/scheduling" target="_blank">OLS</a>&nbsp;
					<a class="btn btn-default" href="https://e-services.co.Sarasota-beach.fl.us/scheduling/admin" target="_blank">OLS Admin</a>&nbsp;
					<!-- <a class="btn btn-default"href="{$vrbUrl}/scheduler/calendar" target="_blank">VRB</a> -->
					<a class="btn btn-danger dropdown-toggle" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false"><i class="fa fa-question-circle"></i> Help <span class="caret"></span></a>
					<ul class="dropdown-menu" aria-labeledby="Help Dropdown">
						<li><a class="helpLink" data-context="top"><i class="fa fa-fw fa-link"></i> View Help Topics</a></li>
						<li><a class="helpLinkContact"><i class="fa fa-envelope fa-fw"></i> Contact Support</a></li>
					</ul>
                
				</ul>
				
            </nav>
		</div>
			<div class="tabbable" id="tabs" style="margin-top:80px;">
                <div id="toptabs" class="tab-content">
                    <div class="tab-pane active topPane" id="search">
                        <div class="tabbable">
                            <ul id="searchtoplist" class="nav nav-tabs">
                                <li class="active" title="Main Form">
                                    <a href="#searchform" data-toggle="tab">Main Form</a>
                                </li>
                            </ul>
                        
                            <div id="searchtoptabs" class="tab-content">
                                <div class="tab-pane active innerPane" id="searchform">
                                    {$searchform}
                                </div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="tab-pane topPane" id="cases" style="overflow-y: hidden">
                        <div class="tabbable" style="margin-bottom: 0px">
                            <ul id="casetoplist" class="nav nav-tabs"></ul>
                        </div>
                        
                        <div id="casetoptabs" class="tab-content">
                        </div>
                    </div>

                    <div class="tab-pane topPane" id="reports">
                        <div class="tabbable">
                            <ul id="reporttoplist" class="nav nav-tabs"></ul>
                        </div>
                        
                        <div id="reporttoptabs" class="tab-content">
                        </div>
                    </div>
                    
                    <div class="tab-pane topPane" id="calendars">
                        <div class="tabbable">
                            <ul id="calendartoplist" class="nav nav-tabs"></ul>
                        </div>
                        
                        <div id="calendartoptabs" class="tab-content">
                        </div>
                    </div>
                    
                    <div class="tab-pane topPane" id="workflow">
                    </div>
                    
                    <div class="tab-pane topPane" id="links">
                        <div class="pull-right">
                            <a class="helpLink" data-context="links">
                                <img class="toolbarBtn" style="height: 20px !important; width: 20px;" alt="Help" title="Help" src="/images/help_icon.png">
                            </a>
                        </div>
                        
                        <div class="linksDiv">
                            <span class="sectionHeader">Commonly Used Links</span>
                            <hr/>
                            <table class="linksTable">
                                <tbody>
                                    <tr>
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="Westlaw" class="externLink" data-url="http://www.westlaw.com" data-target="westlaw">WestLaw</a>
                                                </li>           
                                            </ul>
                                        </td>
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="LexisNexis" class="externLink" data-url="http://www.lexisnexis.com/gov/stateandlocal/research/" data-target="LexisNexis">LexisNexis</a>
                                                </li>
                                            </ul>
                                        </td>
                                    </tr>
                                    
                                    <tr>
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="Florida Statutes Online" class="externLink" data-url="http://www.leg.state.fl.us/statutes/" data-target="FLStatutes">Florida Statutes Online</a>
                                                </li>
                                            </ul>
                                        </td>
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="Jury Instructions" class="externLink" data-url="http://www.floridasupremecourt.org/jury_instructions.shtml" data-target="JuryInstructions">Jury Instructions (Civil and Criminal)</a>
                                                </li>
                                            </ul>
                                        </td>
                                    </tr>
                                    
                                    <tr>
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="OSCA - Court Education Resource Library" class="externLink" data-url="https://intranet.flcourts.org/osca/Judicial_Education/Library/librarymain.shtml" data-target="OSCACERL">OSCA - Court Education Resource Library</a>
                                                </li>           
                                            </ul>
                                        </td>
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="Twelfth Circuit Website" class="externLink" data-url="http://www.15thcircuit.com/" data-target="Circuit15">Twelfth Circuit Website</a>
                                                </li>                  
                                            </ul>
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                        
                        <div class="linksDiv">
                            <span class="sectionHeader">Florida Rules of Procedure</span>
                            <hr/>

                            <table class="linksTable">
                                <tbody>
                                    <tr>
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="Appellate Rules of Procedure" class="externLink" data-url="http://www.floridabar.org/TFB/TFBResources.nsf/Attachments/830A6BC6B90DA05685256B29004BFAC0/$FILE/Appellate.pdf?OpenElement"
                                                       data-target="Appellate Rules of Procedure">
                                                        Appellate
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>
                                        
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="Rules of Judicial Administration" class="externLink" data-url="http://www.floridabar.org/TFB/TFBResources.nsf/Attachments/F854D695BA7136B085257316005E7DE7/$FILE/Judicial.pdf"
                                                       target="RJA">
                                                        Judicial Administration
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>
                                    </tr>
                                    
                                    <tr>
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="FL Civil Rules of Procedure" class="externLink" data-url="http://www.floridabar.org/TFB/TFBResources.nsf/Attachments/10C69DF6FF15185085256B29004BF823/$FILE/Civil.pdf?OpenElement"
                                                       target="CivilRules">
                                                        Civil
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>
                                        
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="Probate" class="externLink" data-url="http://www.floridabar.org/TFB/TFBResources.nsf/Attachments/6C2FEF97C5969ACD85256B29004BFA12/$FILE/Probate.pdf?OpenElement"
                                                       target="ProbateRules">
                                                        Probate
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>
                                    </tr>
                                    
                                    <tr>
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="FL Rules of Criminal Procedure" class="externLink" data-url="http://www.floridabar.org/TFB/TFBResources.nsf/Attachments/BDFE1551AD291A3F85256B29004BF892/$FILE/Criminal.pdf?OpenElement"
                                                       target="CrimRules">
                                                        Criminal
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>
                                        
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="FL Small Claims" class="externLink" data-url="http://www.floridabar.org/TFB/TFBResources.nsf/Attachments/5E3D51AF15EE8DCD85256B29004BFA62/$FILE/Small%20Claims.pdf?OpenElement"
                                                       target="SmallClaimsRules">
                                                        Small Claims
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>
                                    </tr>
                                    
                                    <tr>
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="FL Family Rules of Procedure" class="externLink" data-url="http://www.floridabar.org/TFB/TFBResources.nsf/Attachments/416879C4A88CBF0485256B29004BFAF8/$FILE/Family.pdf?OpenElement"
                                                       target="FamilyRules">
                                                        Family
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="Fl Rules of Traffic" class="externLink" data-url="http://www.floridabar.org/TFB/TFBResources.nsf/Attachments/0FF693985C17374385256B29004BFA46/$FILE/Traffic.pdf?OpenElement"
                                                       target="TrafficRules">
                                                        Traffic
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                        
                        <div class="linksDiv">
                            <span class="sectionHeader">
                                BenchBooks
                            </span>
                            <hr/>
                            
                            <table class="linksTable">
                                <tbody>
                                    <tr>
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="Circuit Criminal Bench Book" class="externLink" data-url="https://intranet.flcourts.org/osca/judicial_education/Library/bin/CriminalBenchguideCircuitJudges.pdf"
                                                       target="CirCrimBenchBook">
                                                        Circuit Criminal
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="Domestic Violence Bench Book" class="externLink" data-url="http://www.flcourts.org/core/fileparse.php/273/urlt/ElectronicBenchbook2014O-OAccessibilityOcheckedO1-26-2015.pdf"
                                                       target="DVBenchBook">
                                                        Domestic Violence
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>
                                    </tr>
                                    
                                    <tr>
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="Contempt Bench Book" class="externLink" data-url="https://intranet.flcourts.org/osca/judicial_education/Library/bin/ContemptBenchguide.pdf"
                                                       target="ClosingArgumentsBenchBook">
                                                        Contempt
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="Interpreting Bench Book" class="externLink" data-url="https://intranet.flcourts.org/osca/judicial_education/Library/bin/CourtInterpreting.pdf"
                                                       target="InterpBenchBook">
                                                        Interpreting
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>
                                    </tr>

                                    <tr>
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="Delinquency Bench Book" class="externLink" data-url="http://www.flcourts.org/core/fileparse.php/539/urlt/DelinquencyBenchbook.pdf"
                                                       target="DelBenchBook">
                                                        Delinquency
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="Judicial Administration Bench Book" class="externLink" data-url="https://intranet.flcourts.org/osca/judicial_education/Library/bin/JudicialAdminBenchguide.pdf"
                                                       target="JudAdminBenchBook">
                                                        Judicial Administration
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>
                                    </tr>
                                    
                                    <tr>
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="Dependency Bench Book" class="externLink" data-url="http://www.flcourts.org/core/fileparse.php/304/urlt/2011_Dependency_Benchbook_Final.pdf"
                                                       target="DepBenchBook">
                                                        Dependency
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="Residential Foreclosure Bench Book" class="externLink" data-url="https://intranet.flcourts.org/osca/judicial_education/Library/bin/ResidentialForeclosureBenchBook.pdf"
                                                       target="resForenBenchBook">
                                                        Residential Foreclosure
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                        
                        <div class="linksDiv">
                            <span class="sectionHeader">
                                Ordinances
                            </span>
                            <hr/>
                            
                            <table class="linksTable">
                                <tbody>
                                    <tr>
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="Sarasota County Ordinances" class="externLink" data-url="https://www.municode.com/library/fl/Sarasota_beach_county/codes/code_of_ordinances"
                                                       target="PBCOrdinances">
                                                        Sarasota County
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="Jupiter City Ordinances" class="externLink" data-url="https://www.municode.com/library/fl/jupiter/codes/code_of_ordinances"
                                                       target="JupiterOrdinances">
                                                        Jupiter
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>
                                    </tr>

                                    <tr>
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="Atlantis City Ordinances" class="externLink" data-url="https://www.municode.com/library/fl/atlantis/codes/code_of_ordinances"
                                                       target="AtlantisOrdinances">
                                                        Atlantis
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>
                                        
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="Lake Worth City Ordinances" class="externLink" data-url="https://www.municode.com/library/fl/lake_worth/codes/code_of_ordinances"
                                                       target="LWOrdinances">
                                                        Lake Worth
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="Boca Raton City Ordinances" class="externLink" data-url="https://www.municode.com/library/fl/boca_raton/codes/code_of_ordinances"
                                                       target="BocaOrdinances">
                                                        Boca Raton
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>

                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="Sarasota City Ordinances" class="externLink" data-url="https://www.municode.com/library/fl/Sarasota_beach/codes/code_of_ordinances"
                                                       target="PBOrdinances">
                                                        Sarasota
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>
                                    </tr>
                                    
                                    <tr>
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="Boynton Beach City Ordinances" class="externLink" data-url="http://www.boynton-beach.org/departments/city_clerk/ordinances.php"
                                                       target="BoyntonOrdinances">
                                                        Boynton Beach
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>
                                        
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="Sarasota Gardens City Ordinances" class="externLink" data-url="https://www.municode.com/library/fl/Sarasota_beach_gardens/codes/code_of_ordinances"
                                                       target="PBGOrdinances">
                                                        Sarasota Gardens
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>
                                        
                                    </tr>
                                    
                                    <tr>
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="Clewiston City Ordinances" class="externLink" data-url="https://www.municode.com/library/fl/clewiston/codes/code_of_ordinances"
                                                       target="ClewistonOrdinances">
                                                        Clewiston
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>
                                        
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="Riviera Beach City Ordinances" class="externLink" data-url="https://www.municode.com/library/fl/riviera_beach/codes/code_of_ordinances"
                                                       target="RBOrdinances">
                                                        Riviera Beach
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>
                                    </tr>
                                    
                                    <tr>
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="Delray Beach City Ordinances" class="externLink" data-url="https://www.municode.com/library/fl/delray_beach/codes/code_of_ordinances"
                                                       target="DelrayOrdinances">
                                                        Delray Beach
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>
                                        
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="Wellington City Ordinances" class="externLink" data-url="https://www.municode.com/library/fl/wellington/codes/code_of_ordinances"
                                                       target="WellingtonOrdinances">
                                                        Wellington
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>
                                    </tr>
                                    
                                    <tr>
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="Greenacres City Ordinances" class="externLink" data-url="https://www.municode.com/library/fl/greenacres/codes/code_of_ordinances"
                                                       target="GreenacresOrdinances">
                                                        Greenacres
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>
                                    
                                        <td>
                                            <ul>
                                                <li>
                                                    <a title="West Sarasota City Ordinances" class="externLink" data-url="https://www.municode.com/library/fl/west_Sarasota_beach/codes/code_of_ordinances"
                                                       target="WPBOrdinances">
                                                        West Sarasota
                                                    </a>
                                                </li>
                                            </ul>
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                        
                    </div>
                    
                    <div class="tab-pane topPane" id="settings">
                    </div>
                </div>
       
            
        </div>
        
        <!--                          -->
        <!-- NOTES ADD/EDIT DIALOG -->
        <!--                          -->
        
        <div id="nt_add_dialog" style="display:none" title="Case Notes Add/Edit">
            <form id="nt_add_form" action="/casenotes/addnote.php" method="post">
                <fieldset>
                    <label for="nt_casenum_display">
                        Case #
                    </label>
                    <span id="nt_casenum_display" style="font-weight:bold"></span>
                    <br/>
                    <label for="nt_note">
                        Note
                    </label>
                    <textarea rows="8" cols="80" id="nt_note" name="nt_note"></textarea>
                    <br/>
                    <table>
                        <tr id="nt_file_row">
                            <td>
                                <label for="nt_file">Attachment</label>
                            </td>
                            <td>
                                <input type="file" name="nt_file" id="nt_file" size=50 class="text ui-widgit-content ui-corner-all"/>
                            </td>
                        </tr>
                    </table>
                    <input type="hidden" name="nt_seq" id="nt_seq"/>
                    <input type="hidden" name="nt_casenum" id="nt_casenum"/>
                    <input type="hidden" name="nt_docref" id="nt_docref"/>
                    <button type="button" class="wfNoteSave">Save</button>
                </fieldset>
            </form>
        </div>
        
        <!-- Workflow Transfer Dialog -->
        <div id="wf_xferdialog" style="display: none">
            Who would you like to transfer this document to?
            <p>
                <select id="wf_xferqueue" name="wf_xferqueue">
                    {foreach $xferqueues as $xferqueue}<option value="{$xferqueue.queue}">{$xferqueue.queuedscr}{/foreach}</option>
                </select>
                <input id="wf_xferfromqueue" type="hidden" name="wf_xferfromqueue" />
                <input id="wf_xferid" type="hidden" name="wf_xferid" />
                <button class="queuexfer">Transfer</button>
            </p>
        </div>
        
        <!-- Workflow bulk transfer dialog -->
        <div id="wf_bulkxferdialog" style="display: none">
            Who would you like to transfer these documents to?
            <p>
                <select id="wf_bulkxferqueue" name="wf_bulkxferqueue">
                    {foreach $xferqueues as $xferqueue}<option value="{$xferqueue.queue}">{$xferqueue.queuedscr}{/foreach}</option>
                </select>
                <!--<input id="wf_bulkxferfromqueue" type="hidden" name="wf_xferfromqueue" />-->
                <!--<input id="wf_bulkxferid" type="hidden" name="wf_xferid" />-->
                <button class="bulkqueuexfer">Transfer</button>
            </p>
        </div>
        
        
        <!-- Workflow add/edit dialog -->
        <div id="wf_add_dialog" style="display:none" title="Add/Edit Document" z-index:100>
            <form id="wf_add_form" action="workflow/wfupload.php" method="post">
                <fieldset>
                    <table>
                        <tr>
                            <td>
                                <label for="wf_ucn">
                                    Case #
                                </label>
                            </td>
                            <td>
                                <input type="text" style="width: 20em" name="wf_ucn" id="wf_ucn" class="text ui-widgit-content ui-corner-all" onChange="HandleWorkFlowAddCaseChange();"/>
                                <input type="button" class="button" id="wf_findcase" value="Find" onClick="HandleWorkFlowCaseFind();"/>
                            </td>
                        </tr>
                        
                        <tr id="wf_upload_row">
                            <td>
                                <label for="wf_file">
                                    File to Upload
                                </label>
                            </td>
                            <td>
                                <input type="file" name="wf_file" id="wf_file" size=50 class="text ui-widgit-content ui-corner-all"/>
                            </td>
                        </tr>
                        
                        <tr>
                            <td>
                                <label for="wf_queue">
                                    Work Queue
                                </label>
                            </td>
                            <td>
                                <select id="wf_queue" name="wf_queue">
                                    {foreach $xferqueues as $xferqueue}<option value="{$xferqueue.queue}">{$xferqueue.queuedscr}{/foreach}</option>
                                </select>
                            </td>
                        </tr>
                        
                        <tr>
                            <td>
                                <label for="wf_title">
                                    Title
                                </label>
                            </td>
                            <td>
                                <input type="text" name="wf_title" id="wf_title" size=50 class="text ui-widgit-content ui-corner-all"/>
                                <br/>
                            </td>
                        </tr>
                        
                        <tr>
                            <td>
                                <label for="priority">
                                    Category
                                </label>
                            </td>
                            <td>
                                <select name="wf_priority" id="wf_priority">
                                    <option value="Red">Red</option>
                                    <option value="Orange">Orange</option>
                                    <option value="Yellow">Yellow</option>
                                    <option value="Green">Green</option>
                                    <option value="Blue">Blue</option>
                                    <option value="Indigo">Indigo</option>
                                    <option value="Violet">Violet</option>
                                    <option value="Black">Black</option>
                                    <option value="Gray">Gray</option>
                                    <option value="White">White</option>
                                </select>
                            </td>
                        </tr>
                        
                        <tr>
                            <td>
                                <label for="wf_due_date">
                                    Due Date
                                </label>
                            </td>
                            <td>
                                <input type="text" name="wf_due_date" id="wf_due_date" class="text ui-widget-content"/>
                            </td>
                        </tr>
                    </table>
                    
                    <label for="wf_comments">
                        Comments
                    </label>
                    
                    <textarea rows="8" cols="80" id="wf_comments" name="wf_comments"></textarea>
                    <br/>
                    
<!--                    <span id="wf_an_order_span">
                        <label for="wf_an_order">
                            This document is a proposed order
                        </label>
                        <input type='checkbox' id="wf_an_order" name="wf_an_order" onclick="WorkFlowAddToggle();"/>
                        <br/>
                    </span>-->
                    
                    <div id="wf_order_details" style="display:none">
                        <label for="wf_need_judge">
                            Needs Judge Signature
                        </label>
                        
                        <input type="checkbox" id="wf_need_judge" name="wf_need_judge" checked="checked"/>
                        <br/>
                        
                        <div id="wf_docket_as_div">
                            <label for="wf_docket_as">
                                Docket As:
                            </label>
                            <select id="wf_docket_as" name="wf_docket_as">
                                <option></option>
                            </select>
                        </div>
                    </div>
                    
                    <input type=hidden name="wf_id" id="wf_id"/>
                    <input type=hidden name="wf_docref" id="wf_docref"/>
                    <input type=hidden name="wf_doctype" id="wf_doctype"/>
                    <button type="button" class="wf_add_save_btn">Save</button>
                </fieldset>
            </form>
        </div>
        
        
        <!-- The new recip div for eservice - this is cloned on each page as required -->
        <div id="newrecip" style="display: none">
            <div style="clear: both">
                <input style="float: left" class="check newcheck" type="checkbox" name="newRecip" disabled="disabled"/>
                <div style="clear: right">
                    <input type="text" class="email" style="width: 25em"/>
                    <button type="button" class="addEmail">Add</button>
                </div>
            </div>
        </div>
        
        
        <!-- Workflow Reject Dialog -->
        <div id="wf_reject_dialog" style="display:none; z-index:100" title="Reject Document">
            <label for="wf_reject_comments">Reason for Rejection</label>
            <textarea rows="6" cols="80" id="wf_reject_comments" name="wf_reject_comments"></textarea>
            <br/>
            <input type="hidden" name="wf_reject_id" id="wf_reject_id"/>
            <input type="hidden" name="wf_reject_creator" id="wf_reject_creator"/>
            <input type="hidden" name="wf_reject_queue" id="wf_reject_queue"/>
            <input type="hidden" name="wf_reject_ucn" id="wf_reject_ucn"/>
            <button class="rejectBtn">Save</button>
        </div>
        
        <!-- WORKFLOW ACTION MENU -->
        
        <ul class="wfmenu" id="wfmenu" style="width:150px;display:none;cursor:pointer">
            <li class="wfmenuitem" data-choice="viewetc">View</li>
            <li class="wfmenuitem" id="wfdocedits1" data-choice="settings">Edit Settings</li>
            <!--<li class="wfmenuitem">Parties &amp; Addresses</li>-->
            <!--<li class="wfmenuitem" id=wfdoceditd>Edit Document</li>-->
            <!--<li class="wfmenuitem" id=wfdocedits>Edit Settings</li>-->
            <li class="wfmenuitem" data-choice="transfer">Transfer to another Queue</li>
            <!--<li class="wfmenuitem">Envelopes for Parties</li>-->
            <!--<li class="wfmenuitem" id=wfdocemail>E-mail to Parties</li>-->
            <!--<li class="wfmenuitem" id=wfdocefile>E-File with Clerk</li>-->
            <li class="wfmenuitem" data-choice="flag">Flag/Unflag</li>
            <li class="wfmenuitem" data-choice="revert">Revert</li>
            <li class="wfmenuitem" data-choice="reject">Reject</li>
            <li class="wfmenuitem" data-choice="delete">Delete</li>
            <li class="wfmenuitem" data-choice="finish" id=wfdocfinish>Finish</li>
        </ul>
        
        
        <!--                                     -->
        <!-- WORKFLOW ACTION MENU - FORM ORDERS -->
        <!--                                     -->
        
        <ul class="wfmenu" id="wfmenufo" style="width:150px;display:none;cursor:pointer">
            <li class="wfmenuitem" data-choice="viewetc">View/etc...</li>
            <li class="wfmenuitem" id="wfdocedits1" data-choice="settings">Edit Settings</li>
            <li class="wfmenuitem" data-choice="transfer">Transfer to another Queue</li>
            <li class="wfmenuitem" data-choice="flag">Flag/Unflag</li>
            <li class="wfmenuitem" data-choice="revert">Revert</li>
            <li class="wfmenuitem" data-choice="reject">Reject</li>
            <li class="wfmenuitem" data-choice="delete">Delete</li>
            <li class="wfmenuitem" data-choice="finish">Finish</li>
        </ul>
        
        <!--                                     -->
        <!-- WORKFLOW ACTION MENU - REMINDERS    -->
        <!--                                     -->
        
        <ul class="wfmenu" id="wfmenurem" style="width:150px;display:none;cursor:pointer">
            <li class="wfmenuitem" id="wfdocedit" data-choice="settings">Edit Settings</li>
            <li class="wfmenuitem" data-choice="transfer">Transfer to another Queue</li>
            <li class="wfmenuitem" data-choice="flag">Flag/Unflag</li>
            <li class="wfmenuitem" data-choice="delete">Delete</li>
            <li class="wfmenuitem" data-choice="finish">Finish</li>
        </ul>
        
        <div style="display: none">
            {if isset($initialUCN)}<a id="initialUCN" class="caseLink" data-casenum="{$initialUCN}"/></a>{/if}
        </div>
        
        
        <div class="mainDialog" id="save-view" title="Save Docket Configuration" style="display:none;">
            <div style="font-size; 120%; font-weight: bold;">
                Saving docket configuration for case type "<span id="save-view-case-type"></span>"
            </div>
            
            <!--<label>Name:</label>
            <input type="text" id="view-name" value="name" /><br />-->
            
            <div class="current-docket-codes">
                <strong>Currently Displayed Dockets:</strong>
                <ol id="current-dockets" class="sortable-dockets">
                    
                </ol>
                <button class="add-all-dockets">Add all</button>
            </div>
            
            <div class="saved-docket-codes">
                <strong>Saved Configuration</strong>
                <ol id="saved-dockets" class="sortable-dockets">
                    
                </ol>
            </div>
            
            <div class="clear"></div>
            
            <div>
                <strong>Add additional dockets:</strong><br />
                <input type="text" id="docket-code" value="" />
                <input type="hidden" id="save-view-ucn" value="" />
                <button class="add-docket-code">Add</button>
            </div>
        </div>
        
        <div id="confirm-dialog" title="" style="display:none;">
            
        </div>
        
    </body>
</html>
