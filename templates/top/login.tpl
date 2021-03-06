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
        	12th Circuit Case Management System
        </title>
	
        <link rel="stylesheet" type="text/css" href="/style/normalize.css"/>
        <link rel="stylesheet" type="text/css" href="/javascript/bootstrap/3.2.0/css/bootstrap.css"/>
        <link href="/style/jquery-ui.css" type="text/css" rel="stylesheet"/>
        
        <link rel="stylesheet" href="/style/ICMS.css?2.1"/>
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
        
        <script src="/javascript/main.js?1.7" type="text/javascript"></script>
        <script src="/javascript/ICMS.js?2.0" type="text/javascript"></script>
        <script src="/javascript/ajax.js?1.6" type="text/javascript"></script>
        
        <script src="/javascript/orders.js?1.6" type="text/javascript"></script>
        
        <script type="text/javascript">
        	 $(document).ready(function (){
        	 
        	 	$('#loginForm').on('submit', function() {
				  if($("#user").val() == "" || ($("#password").val() == "")){
	            		showDialog("Error", "You must enter a username and password.", "errorDialog");
	            		return false;
	            	}
	            	else{
	            		$("#loginForm").submit();
	            	}
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
            
            	$('img').on('dragstart', function(event) { 
            		event.preventDefault(); 
            	});
            	
            	$('.tabLink').click(function() {
            		window.location.href = $(this).attr('href');
                })
                
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
        </script>       
    </head>
    <body>
        
        <div class="container-fluid">

          	<div id="dialogDiv">
                <span id="dialogSpan" style="font-size: 80%"></span>
            </div>
		    <nav class="navbar navbar-default navbar-fixed-top">
				<div id="logoDiv" class="pull-right hidden-xs" >
					<a href="/"><img class="homeLink img img-responsive"  src="/images/JVSLOGO-Wide.jpg" style="max-height:75px; 0 -30px 0 0" title="JVS Logo" alt="JVS" /></a>
				</div>
				<ul class="nav nav-tabs navbar navbar-right hidden-sm hidden-xs">
					<!--<a class="btn btn-default" href="file://///c:/OIVFiles/index.html" target="_blank">OIV</a> -->
					<a class="btn btn-default" href="https://ols.jud12.local" target="_blank">OLS</a>&nbsp;
					<a class="btn btn-default" href="https://ols.jud12.local/admin" target="_blank">OLS Admin</a>&nbsp;
					<!--<a class="btn btn-default"href="{$vrbUrl}/scheduler/calendar" target="_blank">VRB</a> -->
					<a class="btn btn-danger dropdown-toggle" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false"><i class="fa fa-question-circle"></i> Help <span class="caret"></span></a>
					<ul class="dropdown-menu" aria-labeledby="Help Dropdown">
						<li><a class="helpLink" data-context="top"><i class="fa fa-fw fa-link"></i> View Help Topics</a></li>
						<li><a class="helpLinkContact"><i class="fa fa-envelope fa-fw"></i> Contact Support</a></li>
					</ul>
		                
				</ul>
						
		    </nav>
		</div>		
	</div>
	<br class="clear"/><br class="clear"/><br class="clear"/><br class="clear"/>
	<br/>
	<div align="center">
		{if $error}
			<span class="error">{$errorText}</span>
		{/if}
		<form action="/login.php" method="post" id="loginForm">
			<table>
				<tr>
					<td>User Name:</td>
					<td><input type="text" name="user" id="user"/></td>
				</tr>
				<tr>	
					<td>Password:</td>
					<td><input type="password" name="password" id="password"/><td>
				</tr>
				<tr>
					<td>&nbsp;</td>
					<td align="right"><button type="submit" id="submit" name="submit">Login</button></td>
				</tr>
			</table>
			<input type="hidden" id="ref" name="ref" value="{$ref}"/>
		</form>
	</div>