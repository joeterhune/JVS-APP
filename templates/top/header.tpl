{$vrbUrl = "http://vrb.15thcircuit.com"}
<!DOCTYPE html>
<html>
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
        <meta http-equiv="cache-control" content="max-age=0" />
		<meta http-equiv="cache-control" content="no-cache" />
		<meta http-equiv="expires" content="0" />
		<meta http-equiv="expires" content="Tue, 01 Jan 1980 1:00:00 GMT" />
		<meta http-equiv="pragma" content="no-cache" />
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="Author" content="Default" />
        <meta http-equiv="X-UA-Compatible" content="IE=Edge" >

        <title>
        	15th Circuit Case Management System
        </title>
	
        <link rel="stylesheet" type="text/css" href="/style/normalize.css"/>
        <link rel="stylesheet" type="text/css" href="/javascript/bootstrap/3.2.0/css/bootstrap.css"/>
        <link href="/style/jquery-ui.css?1.2" type="text/css" rel="stylesheet"/>
        
        <link rel="stylesheet" href="/style/ICMS.css?4.1"/>
        <link rel="stylesheet" href="/style/font-awesome.min.css?1.1"/>
        <link rel="stylesheet" href="/style/docviewer.css?1.1"/>
        <link rel="stylesheet" href="/style/toastr.min.css?1.1"/>
        <link rel="stylesheet" href="/style/fullcalendar.css?1.1" type="text/css"/>
        <link rel="stylesheet" type="text/css" href="/style/bootstrap-datetimepicker.min.css"/>
		
        <script src="/javascript/jquery/jquery-1.11.0.js" type="text/javascript"></script>
        <script src="/javascript/bootstrap/3.2.0/js/bootstrap.min.js" type="text/javascript"></script>
        <script src="/javascript/bootstrap-datetimepicker.min.js" type="text/javascript"></script>
        <script type="text/javascript" src="/javascript/jquery-ui-1.10.4.min.js"></script>
        <script type="text/javascript" src="/javascript/jquery.blockUI.js"></script>
        
		<script src="/javascript/jquery/jquery.tablesorter.js" type="text/javascript"></script>
		<script src="/javascript/jquery/jquery.tablesorter.widgets.js" type="text/javascript"></script>
		<script src="/javascript/jquery/jquery.tablesorter.pager.js" type="text/javascript"></script>
		<link rel="stylesheet" href="/javascript/jquery/jquery.tablesorter.pager.css" type="text/css" />
		
        <script src="/javascript/jquery.cookie.js" type="text/javascript"></script>
        <script type="text/javascript" src="/javascript/jquery.placeholder.js"></script>
        
        <script src="/javascript/main.js?1.8" type="text/javascript"></script>
        <script src="/javascript/ICMS.js?2.1" type="text/javascript"></script>
        <script src="/javascript/ajax.js?1.6" type="text/javascript"></script>
        <script src="/javascript/orders.js?2.9" type="text/javascript"></script>
        <script src="/icms.js" type="text/javascript"></script>
        
        <script src="/javascript/signature_pad.js" type="text/javascript"></script>
        
        <script type="text/javascript">
        	var onResize = function() {
				// apply dynamic padding at the top of the body according to the fixed navbar height
				$("body").css("padding-top", $(".navbar-fixed-top").height());
			};
				
        	$(document).ready(function (){
        	
        		setInterval(function() {
				    $.ajax({
		          		url: "/workflow/getWFCount.php",
		          		dataType: "text",
		          		success: function(data) {
		            		$("#wfcount").html(data);
		          		}
		        	} );
				}, 60000);
        	
				// attach the function to the window resize event
				$(window).resize(onResize);
			
				// call it also when the page is ready after load or reload
				onResize();
        	 
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
        	 
        	 	$('button.IGO, button.DVI').click(function() {
			        var docid = $(this).data('doc_id');
			        
			        var esigSelect = $('#workflow').find('.signAs').first();
			        var optCount = $(esigSelect).find('option').size();
			        if (optCount == 2) {
			            var signUser = $(esigSelect).val();
			        } else {
			            $(esigSelect).show();
			            return false;
			        }
			        
			        WorkFlowSignFormOrder(docid, signUser);
			        return false;
			    });
            
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
					            window.location.href = url;
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
            	
            	/*$('.tabLink').click(function() {
            		window.location.href = $(this).attr('href');
                });*/
                
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
	            
	            $(document).on('click','.caseLink',function() {
	                var case_num = $(this).data('casenum');
	                var case_id = $(this).data('caseid');
	                var url = "/cgi-bin/search.cgi?name=" + case_num;
	                window.location.href = url;
	                return false;
	            });
	            
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
	            
	            $('.calsubmit').click(function () {
	                var foo = $(this).siblings();
					var btnid = $(this).attr('id');
					var division = $(this).parent().find('.divsel').val();
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
	
					if($(this).attr('value') == 'fapcal'){
						$("#fapcal").val(true);
					}
					
					$('#mainSearchForm').attr('action','/cgi-bin/calendars/showCal.cgi');
					$('#div').val(division);
					$('#mainSearchForm').submit();
					return true;
				});
				
				if ($(".datepicker").length){
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
				}
				
				$(document).on('click','.printTab',function() {
                    var tabClass = $(this).data('print');
                    var orientation = $(this).data('orientation');
                    if (orientation == undefined) {
                        orientation = 'portrait';
                    }
                    
                    var printContents = $('.' + tabClass).clone();
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
                
                $(document).on('click','.closeTab',function() {
                	$(this).parent().parent().fadeOut( "fast", function() {
						// Animation complete.
					});
					{literal}
						$.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait </h1>', fadeIn: 0});
					{/literal}
                });
        	});    	
        	
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
    </head>
    <body>
        
        <div class="container-fluid">

          	<div id="dialogDiv">
                <span id="dialogSpan"></span>
            </div>
		    <nav class="navbar navbar-default navbar-fixed-top">
		    	<ul id="masterTabs" class="nav nav-tabs navbar navbar-left leftTitleBox">
		        	<li {if $active == "index"}class="active topTab"{else}class="topTab"{/if} id="searchTop" title="Main Search Tab">
		            	<a href="/tabs.php"><span style="text-decoration:none"><i class="fa fa-home">&nbsp;&nbsp;</i></span>Search/Main</a>
		            </li>
		            <li {if $active == "cases"}class="active topTab"{else}class="topTab"{/if} id="caseTop" title="Cases Tab">
		            	<a href="/goTo.php?parent=cases"><span style="text-decoration:none"><i class="fa fa-briefcase">&nbsp;&nbsp;</i></span>Cases</a>
		            </li>
		            <li {if $active == "reports"}class="active topTab"{else}class="topTab"{/if} id="reportTop" title="Reports Tab">
		            	<a href="/reports/index.php"><span style="text-decoration:none"><i class="fa fa-bar-chart-o">&nbsp;&nbsp;</i></span>Reports</a>
		           	</li>
		            <li class="topTab" id="calendarTop" title="Calendars Tab">
		            	<a href="/goTo.php?parent=calendars"><span style="text-decoration:none"><i class="fa fa-calendar">&nbsp;&nbsp;</i></span>Calendars</a>
		            </li>
		            <li {if $active == "workflow"}class="active topTab"{else}class="topTab"{/if} id="workflowTop" title="Workflow Tab">
		            	<a href="/workflow.php"><span style="text-decoration:none"><i class="fa fa-files-o">&nbsp;&nbsp;</i></span>Queue (<span id="wfcount">{$wfCount}</span>)</a>
		            </li>
		            <li {if $active == "links"}class="active topTab"{else}class="topTab"{/if} id="linksTop" title="Links Tab">
		            	<a href="/links.php"><span style="text-decoration:none"><i class="fa fa-link">&nbsp;&nbsp;</i></span>Links</a>
		            </li>
		            <li {if $active == "settings"}class="active topTab"{else}class="topTab"{/if} id="settingsTop" title="Settings Tab">
		            	<a href="/settings/index.cgi"><span style="text-decoration:none"><i class="fa fa-cog">&nbsp;&nbsp;</i></span>Settings</a>
		            </li>
		  			<li class="topTab" id="logoutTop" title="Logout Tab">
		                <a href="/cgi-bin/logout.cgi"><span style="text-decoration:none"><i class="fa fa-sign-out">&nbsp;&nbsp;</i></span>Logout</a>
		            </li>
		            {if $tabs|@count > 1}
			            <li class="topTab" id="closeOutTop" title="Close All Tabs">
			            	<a href="/close_all.php"><span style="text-decoration:none"><i class="fa fa-times">&nbsp;&nbsp;</i></span>Close All Tabs</a>
			            </li>
		            {/if}
				</ul>
				<div class="pull-right rightTitleBox">
					<div id="logoDiv" class="pull-right">
						<a href="/"><img class="homeLink img img-responsive"  src="/images/JVSLOGO-Wide.jpg" style="max-height:75px; 0 -30px 0 0" title="JVS Logo" alt="JVS" /></a>
					</div>
					<ul class="nav nav-tabs navbar pull-left">
						<!--<a class="btn btn-default" href="file://///c:/OIVFiles/index.html" target="_blank">OIV</a> -->
						<a class="btn btn-default" href="https://e-services.co.Sarasota-beach.fl.us/scheduling" target="_blank">OLS</a>&nbsp;
						<a class="btn btn-default" href="https://e-services.co.Sarasota-beach.fl.us/scheduling/admin" target="_blank">OLS Admin</a>&nbsp;
						<!--<a class="btn btn-default"href="{$vrbUrl}/scheduler/calendar" target="_blank">VRB</a> -->
						<a class="btn btn-danger dropdown-toggle" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false"><i class="fa fa-question-circle"></i> Help <span class="caret"></span></a>
						<ul class="dropdown-menu" aria-labeledby="Help Dropdown">
							<li><a class="helpLink" data-context="top"><i class="fa fa-fw fa-link"></i> View Help Topics</a></li>
							<li><a class="helpLinkContact"><i class="fa fa-envelope fa-fw"></i> Contact Support</a></li>
						</ul>
					</ul>
				</div>
				<ul id="toplist" class="nav nav-tabs leftTitleBox">
					{for $i = 0; $i < count($tabs); $i++}
						{if $active == $tabs[$i].parent}
							<li title="{$tabs[$i].name}" {if $tabs[$i].active == '1'}class="active" {$activeTab = $tabs[$i].name}{/if}>
								<a href="{$tabs[$i].href}">{$tabs[$i].name}</a>
								{if $tabs[$i].close}
									<a href="/cgi-bin/close.cgi?type=outer&outer_key={$i}"><button class="closeTab">X</button></a>
								{/if}
							</li>
						{/if}
					{/for}
					<div id="casetoptabs" style="clear:both">
						<div class="tabbable">
							<ul id="second_row_list" class="nav nav-tabs">
								{$thirdRow = 0}
								{foreach from=$tabs key=key item=tab}
									{if $tab.tabs && ($active == $tab.parent)}
										{foreach from=$tab.tabs key=inner_key item=inner_tab}
											{if $activeTab == $inner_tab.parent}
												{$thirdRow = 1}
												<li title="{$inner_tab.name}" {if $inner_tab.active == '1'}class="active"{/if}>
													<a href="{$inner_tab.href}">{$inner_tab.name}</a> 
													{if $inner_tab.close}
														<a href="/cgi-bin/close.cgi?type=inner&inner_key={$inner_key}&outer_key={$key}"><button class="closeTab">X</button></a>
													{/if}
												</li>
											{/if} 
										{/foreach}
									
									{/if}
								{/foreach}
							</ul>
						</div>
					</div>
				</ul>
			</nav>
		</div>	