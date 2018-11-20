<?php
/* Smarty version 3.1.31, created on 2018-06-29 11:44:45
  from "/var/jvs/templates/top/login.tpl" */

/* @var Smarty_Internal_Template $_smarty_tpl */
if ($_smarty_tpl->_decodeProperties($_smarty_tpl, array (
  'version' => '3.1.31',
  'unifunc' => 'content_5b3653ed52d369_72211432',
  'has_nocache_code' => false,
  'file_dependency' => 
  array (
    'bf26ce37a02d34fb7efb9af8303d1aa062df43b0' => 
    array (
      0 => '/var/jvs/templates/top/login.tpl',
      1 => 1530277458,
      2 => 'file',
    ),
  ),
  'includes' => 
  array (
  ),
),false)) {
function content_5b3653ed52d369_72211432 (Smarty_Internal_Template $_smarty_tpl) {
$_smarty_tpl->_assignInScope('vrbUrl', "http://vrb.15thcircuit.com");
?>
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
	
        <link rel="stylesheet" type="text/css" href="/case/style/normalize.css"/>
        <link rel="stylesheet" type="text/css" href="/case/javascript/bootstrap/3.2.0/css/bootstrap.css"/>
        <link href="/case/style/jquery-ui.css" type="text/css" rel="stylesheet"/>
        
        <link rel="stylesheet" href="/case/style/ICMS.css?2.1"/>
        <link rel="stylesheet" href="/case/style/font-awesome.min.css?1.1"/>
        <link rel="stylesheet" href="/case/style/docviewer.css?1.1"/>
        <link rel="stylesheet" href="/case/style/toastr.min.css?1.1"/>
        <link rel="stylesheet" href="/case/style/fullcalendar.css?1.1" type="text/css"/>
        <link rel="stylesheet" type="text/css" href="/case/style/bootstrap-datetimepicker.min.css"/>
        
        <?php echo '<script'; ?>
 src="/case/javascript/jquery/jquery-1.11.0.js" type="text/javascript"><?php echo '</script'; ?>
>
        <?php echo '<script'; ?>
 src="/case/javascript/bootstrap/3.2.0/js/bootstrap.min.js" type="text/javascript"><?php echo '</script'; ?>
>
        <?php echo '<script'; ?>
 src="/case/javascript/bootstrap-datetimepicker.min.js" type="text/javascript"><?php echo '</script'; ?>
>
        <?php echo '<script'; ?>
 type="text/javascript" src="/case/javascript/jquery-ui-1.10.4.min.js"><?php echo '</script'; ?>
>
        <?php echo '<script'; ?>
 type="text/javascript" src="/case/javascript/jquery.blockUI.js"><?php echo '</script'; ?>
>
        
		<?php echo '<script'; ?>
 src="/case/javascript/jquery/jquery.tablesorter.js" type="text/javascript"><?php echo '</script'; ?>
>
		<?php echo '<script'; ?>
 src="/case/javascript/jquery/jquery.tablesorter.widgets.js" type="text/javascript"><?php echo '</script'; ?>
>
		<?php echo '<script'; ?>
 src="/case/javascript/jquery/jquery.tablesorter.pager.js" type="text/javascript"><?php echo '</script'; ?>
>
		<link rel="stylesheet" href="/case/javascript/jquery/jquery.tablesorter.pager.css" type="text/css" />
		
        <?php echo '<script'; ?>
 src="/case/javascript/jquery.cookie.js" type="text/javascript"><?php echo '</script'; ?>
>
        <?php echo '<script'; ?>
 type="text/javascript" src="/case/javascript/jquery.placeholder.js"><?php echo '</script'; ?>
>
        
        <?php echo '<script'; ?>
 src="/case/javascript/main.js?1.7" type="text/javascript"><?php echo '</script'; ?>
>
        <?php echo '<script'; ?>
 src="/case/javascript/ICMS.js?2.0" type="text/javascript"><?php echo '</script'; ?>
>
        <?php echo '<script'; ?>
 src="/case/javascript/ajax.js?1.6" type="text/javascript"><?php echo '</script'; ?>
>
        
        <?php echo '<script'; ?>
 src="/case/javascript/orders.js?1.6" type="text/javascript"><?php echo '</script'; ?>
>
        
        <?php echo '<script'; ?>
 type="text/javascript">
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
	                var url = "/case/help/" + context + ".html?1.1";
	                window.open(url,"helpWin", "width=500,height=500,scrollbars=1").focus();
	                return false;
	            });
	            
	            $(document).on('click','.helpLinkContact',function() {
	                var url = "/case/help/support.php";
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
	                var url = "/cgi-bin/case/search.cgi?name=" + case_num;
	                window.location.href = url;
	                return false;
	            });
	            
	            $(document).on('click','.helpLink',function() {
	                var context = $(this).data('context');
	                var url = "/case/help/" + context + ".html?1.1";
	                window.open(url,"helpWin", "width=500,height=500,scrollbars=1").focus();
	                return false;
	            });
	            
	            $(document).on('click','.helpLinkContact',function() {
	                var url = "/case/help/support.php";
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
	                
	                var url = "/cgi-bin/case/export.cgi?rpath=" + rpath + "&header=" + header;
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
					
					$('#mainSearchForm').attr('action','/cgi-bin/case/calendars/showCal.cgi');
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
		                buttonImage: "/case/style/images/calendar.gif",
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
        <?php echo '</script'; ?>
>       
    </head>
    <body>
        
        <div class="container-fluid">

          	<div id="dialogDiv">
                <span id="dialogSpan" style="font-size: 80%"></span>
            </div>
		    <nav class="navbar navbar-default navbar-fixed-top">
				<div id="logoDiv" class="pull-right hidden-xs" >
					<a href="/"><img class="homeLink img img-responsive"  src="/case/images/JVSLOGO-Wide.jpg" style="max-height:75px; 0 -30px 0 0" title="JVS Logo" alt="JVS" /></a>
				</div>
				<ul class="nav nav-tabs navbar navbar-right hidden-sm hidden-xs">
					<!--<a class="btn btn-default" href="file://///c:/OIVFiles/index.html" target="_blank">OIV</a> -->
					<a class="btn btn-default" href="https://e-services.co.Sarasota-beach.fl.us/scheduling" target="_blank">OLS</a>&nbsp;
					<a class="btn btn-default" href="https://e-services.co.Sarasota-beach.fl.us/scheduling/admin" target="_blank">OLS Admin</a>&nbsp;
					<!--<a class="btn btn-default"href="<?php echo $_smarty_tpl->tpl_vars['vrbUrl']->value;?>
/scheduler/calendar" target="_blank">VRB</a> -->
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
		<?php if ($_smarty_tpl->tpl_vars['error']->value) {?>
			<span class="error"><?php echo $_smarty_tpl->tpl_vars['errorText']->value;?>
</span>
		<?php }?>
		<form action="/case/login.php" method="post" id="loginForm">
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
			<input type="hidden" id="ref" name="ref" value="<?php echo $_smarty_tpl->tpl_vars['ref']->value;?>
"/>
		</form>
	</div><?php }
}
