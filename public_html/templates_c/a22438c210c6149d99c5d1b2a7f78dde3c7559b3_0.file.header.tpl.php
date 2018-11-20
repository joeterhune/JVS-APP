<?php
/* Smarty version 3.1.31, created on 2018-06-29 12:05:40
  from "/var/jvs/templates/top/header.tpl" */

/* @var Smarty_Internal_Template $_smarty_tpl */
if ($_smarty_tpl->_decodeProperties($_smarty_tpl, array (
  'version' => '3.1.31',
  'unifunc' => 'content_5b3658d4535488_43434999',
  'has_nocache_code' => false,
  'file_dependency' => 
  array (
    'a22438c210c6149d99c5d1b2a7f78dde3c7559b3' => 
    array (
      0 => '/var/jvs/templates/top/header.tpl',
      1 => 1530288338,
      2 => 'file',
    ),
  ),
  'includes' => 
  array (
  ),
),false)) {
function content_5b3658d4535488_43434999 (Smarty_Internal_Template $_smarty_tpl) {
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
	
        <link rel="stylesheet" type="text/css" href="/style/normalize.css"/>
        <link rel="stylesheet" type="text/css" href="/javascript/bootstrap/3.2.0/css/bootstrap.css"/>
        <link href="/style/jquery-ui.css?1.2" type="text/css" rel="stylesheet"/>
        
        <link rel="stylesheet" href="/style/ICMS.css?4.1"/>
        <link rel="stylesheet" href="/style/font-awesome.min.css?1.1"/>
        <link rel="stylesheet" href="/style/docviewer.css?1.1"/>
        <link rel="stylesheet" href="/style/toastr.min.css?1.1"/>
        <link rel="stylesheet" href="/style/fullcalendar.css?1.1" type="text/css"/>
        <link rel="stylesheet" type="text/css" href="/style/bootstrap-datetimepicker.min.css"/>
		
        <?php echo '<script'; ?>
 src="/javascript/jquery/jquery-1.11.0.js" type="text/javascript"><?php echo '</script'; ?>
>
        <?php echo '<script'; ?>
 src="/javascript/bootstrap/3.2.0/js/bootstrap.min.js" type="text/javascript"><?php echo '</script'; ?>
>
        <?php echo '<script'; ?>
 src="/javascript/bootstrap-datetimepicker.min.js" type="text/javascript"><?php echo '</script'; ?>
>
        <?php echo '<script'; ?>
 type="text/javascript" src="/javascript/jquery-ui-1.10.4.min.js"><?php echo '</script'; ?>
>
        <?php echo '<script'; ?>
 type="text/javascript" src="/javascript/jquery.blockUI.js"><?php echo '</script'; ?>
>
        
		<?php echo '<script'; ?>
 src="/javascript/jquery/jquery.tablesorter.js" type="text/javascript"><?php echo '</script'; ?>
>
		<?php echo '<script'; ?>
 src="/javascript/jquery/jquery.tablesorter.widgets.js" type="text/javascript"><?php echo '</script'; ?>
>
		<?php echo '<script'; ?>
 src="/javascript/jquery/jquery.tablesorter.pager.js" type="text/javascript"><?php echo '</script'; ?>
>
		<link rel="stylesheet" href="/javascript/jquery/jquery.tablesorter.pager.css" type="text/css" />
		
        <?php echo '<script'; ?>
 src="/javascript/jquery.cookie.js" type="text/javascript"><?php echo '</script'; ?>
>
        <?php echo '<script'; ?>
 type="text/javascript" src="/javascript/jquery.placeholder.js"><?php echo '</script'; ?>
>
        
        <?php echo '<script'; ?>
 src="/javascript/main.js?1.8" type="text/javascript"><?php echo '</script'; ?>
>
        <?php echo '<script'; ?>
 src="/javascript/ICMS.js?2.1" type="text/javascript"><?php echo '</script'; ?>
>
        <?php echo '<script'; ?>
 src="/javascript/ajax.js?1.6" type="text/javascript"><?php echo '</script'; ?>
>
        <?php echo '<script'; ?>
 src="/javascript/orders.js?2.9" type="text/javascript"><?php echo '</script'; ?>
>
        <?php echo '<script'; ?>
 src="/icms.js" type="text/javascript"><?php echo '</script'; ?>
>
        
        <?php echo '<script'; ?>
 src="/javascript/signature_pad.js" type="text/javascript"><?php echo '</script'; ?>
>
        
        <?php echo '<script'; ?>
 type="text/javascript">
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
            
            	<?php if ($_smarty_tpl->tpl_vars['pendCount']->value['pendCount']) {?>
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
				                
				                	$.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait </h1>', fadeIn: 0});
				                
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
				<?php }?>
            
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
					
						$.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait </h1>', fadeIn: 0});
					
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
        <?php echo '</script'; ?>
>       
    </head>
    <body>
        
        <div class="container-fluid">

          	<div id="dialogDiv">
                <span id="dialogSpan"></span>
            </div>
		    <nav class="navbar navbar-default navbar-fixed-top">
		    	<ul id="masterTabs" class="nav nav-tabs navbar navbar-left leftTitleBox">
		        	<li <?php if ($_smarty_tpl->tpl_vars['active']->value == "index") {?>class="active topTab"<?php } else { ?>class="topTab"<?php }?> id="searchTop" title="Main Search Tab">
		            	<a href="/tabs.php"><span style="text-decoration:none"><i class="fa fa-home">&nbsp;&nbsp;</i></span>Search/Main</a>
		            </li>
		            <li <?php if ($_smarty_tpl->tpl_vars['active']->value == "cases") {?>class="active topTab"<?php } else { ?>class="topTab"<?php }?> id="caseTop" title="Cases Tab">
		            	<a href="/goTo.php?parent=cases"><span style="text-decoration:none"><i class="fa fa-briefcase">&nbsp;&nbsp;</i></span>Cases</a>
		            </li>
		            <li <?php if ($_smarty_tpl->tpl_vars['active']->value == "reports") {?>class="active topTab"<?php } else { ?>class="topTab"<?php }?> id="reportTop" title="Reports Tab">
		            	<a href="/reports/index.php"><span style="text-decoration:none"><i class="fa fa-bar-chart-o">&nbsp;&nbsp;</i></span>Reports</a>
		           	</li>
		            <li class="topTab" id="calendarTop" title="Calendars Tab">
		            	<a href="/goTo.php?parent=calendars"><span style="text-decoration:none"><i class="fa fa-calendar">&nbsp;&nbsp;</i></span>Calendars</a>
		            </li>
		            <li <?php if ($_smarty_tpl->tpl_vars['active']->value == "workflow") {?>class="active topTab"<?php } else { ?>class="topTab"<?php }?> id="workflowTop" title="Workflow Tab">
		            	<a href="/workflow.php"><span style="text-decoration:none"><i class="fa fa-files-o">&nbsp;&nbsp;</i></span>Queue (<span id="wfcount"><?php echo $_smarty_tpl->tpl_vars['wfCount']->value;?>
</span>)</a>
		            </li>
		            <li <?php if ($_smarty_tpl->tpl_vars['active']->value == "links") {?>class="active topTab"<?php } else { ?>class="topTab"<?php }?> id="linksTop" title="Links Tab">
		            	<a href="/links.php"><span style="text-decoration:none"><i class="fa fa-link">&nbsp;&nbsp;</i></span>Links</a>
		            </li>
		            <li <?php if ($_smarty_tpl->tpl_vars['active']->value == "settings") {?>class="active topTab"<?php } else { ?>class="topTab"<?php }?> id="settingsTop" title="Settings Tab">
		            	<a href="/settings/index.cgi"><span style="text-decoration:none"><i class="fa fa-cog">&nbsp;&nbsp;</i></span>Settings</a>
		            </li>
		  			<li class="topTab" id="logoutTop" title="Logout Tab">
		                <a href="/cgi-bin/logout.cgi"><span style="text-decoration:none"><i class="fa fa-sign-out">&nbsp;&nbsp;</i></span>Logout</a>
		            </li>
		            <?php if (count($_smarty_tpl->tpl_vars['tabs']->value) > 1) {?>
			            <li class="topTab" id="closeOutTop" title="Close All Tabs">
			            	<a href="/close_all.php"><span style="text-decoration:none"><i class="fa fa-times">&nbsp;&nbsp;</i></span>Close All Tabs</a>
			            </li>
		            <?php }?>
				</ul>
				<div class="pull-right rightTitleBox">
					<div id="logoDiv" class="pull-right">
						<a href="/"><img class="homeLink img img-responsive"  src="/images/JVSLOGO-Wide.jpg" style="max-height:75px; 0 -30px 0 0" title="JVS Logo" alt="JVS" /></a>
					</div>
					<ul class="nav nav-tabs navbar pull-left">
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
				</div>
				<ul id="toplist" class="nav nav-tabs leftTitleBox">
					<?php
$_smarty_tpl->tpl_vars['i'] = new Smarty_Variable(null, $_smarty_tpl->isRenderingCache);
$_smarty_tpl->tpl_vars['i']->value = 0;
if ($_smarty_tpl->tpl_vars['i']->value < count($_smarty_tpl->tpl_vars['tabs']->value)) {
for ($_foo=true;$_smarty_tpl->tpl_vars['i']->value < count($_smarty_tpl->tpl_vars['tabs']->value); $_smarty_tpl->tpl_vars['i']->value++) {
?>
						<?php if ($_smarty_tpl->tpl_vars['active']->value == $_smarty_tpl->tpl_vars['tabs']->value[$_smarty_tpl->tpl_vars['i']->value]['parent']) {?>
							<li title="<?php echo $_smarty_tpl->tpl_vars['tabs']->value[$_smarty_tpl->tpl_vars['i']->value]['name'];?>
" <?php if ($_smarty_tpl->tpl_vars['tabs']->value[$_smarty_tpl->tpl_vars['i']->value]['active'] == '1') {?>class="active" <?php $_smarty_tpl->_assignInScope('activeTab', $_smarty_tpl->tpl_vars['tabs']->value[$_smarty_tpl->tpl_vars['i']->value]['name']);
}?>>
								<a href="<?php echo $_smarty_tpl->tpl_vars['tabs']->value[$_smarty_tpl->tpl_vars['i']->value]['href'];?>
"><?php echo $_smarty_tpl->tpl_vars['tabs']->value[$_smarty_tpl->tpl_vars['i']->value]['name'];?>
</a>
								<?php if ($_smarty_tpl->tpl_vars['tabs']->value[$_smarty_tpl->tpl_vars['i']->value]['close']) {?>
									<a href="/cgi-bin/close.cgi?type=outer&outer_key=<?php echo $_smarty_tpl->tpl_vars['i']->value;?>
"><button class="closeTab">X</button></a>
								<?php }?>
							</li>
						<?php }?>
					<?php }
}
?>

					<div id="casetoptabs" style="clear:both">
						<div class="tabbable">
							<ul id="second_row_list" class="nav nav-tabs">
								<?php $_smarty_tpl->_assignInScope('thirdRow', 0);
?>
								<?php
$_from = $_smarty_tpl->smarty->ext->_foreach->init($_smarty_tpl, $_smarty_tpl->tpl_vars['tabs']->value, 'tab', false, 'key');
if ($_from !== null) {
foreach ($_from as $_smarty_tpl->tpl_vars['key']->value => $_smarty_tpl->tpl_vars['tab']->value) {
?>
									<?php if ($_smarty_tpl->tpl_vars['tab']->value['tabs'] && ($_smarty_tpl->tpl_vars['active']->value == $_smarty_tpl->tpl_vars['tab']->value['parent'])) {?>
										<?php
$_from = $_smarty_tpl->smarty->ext->_foreach->init($_smarty_tpl, $_smarty_tpl->tpl_vars['tab']->value['tabs'], 'inner_tab', false, 'inner_key');
if ($_from !== null) {
foreach ($_from as $_smarty_tpl->tpl_vars['inner_key']->value => $_smarty_tpl->tpl_vars['inner_tab']->value) {
?>
											<?php if ($_smarty_tpl->tpl_vars['activeTab']->value == $_smarty_tpl->tpl_vars['inner_tab']->value['parent']) {?>
												<?php $_smarty_tpl->_assignInScope('thirdRow', 1);
?>
												<li title="<?php echo $_smarty_tpl->tpl_vars['inner_tab']->value['name'];?>
" <?php if ($_smarty_tpl->tpl_vars['inner_tab']->value['active'] == '1') {?>class="active"<?php }?>>
													<a href="<?php echo $_smarty_tpl->tpl_vars['inner_tab']->value['href'];?>
"><?php echo $_smarty_tpl->tpl_vars['inner_tab']->value['name'];?>
</a> 
													<?php if ($_smarty_tpl->tpl_vars['inner_tab']->value['close']) {?>
														<a href="/cgi-bin/close.cgi?type=inner&inner_key=<?php echo $_smarty_tpl->tpl_vars['inner_key']->value;?>
&outer_key=<?php echo $_smarty_tpl->tpl_vars['key']->value;?>
"><button class="closeTab">X</button></a>
													<?php }?>
												</li>
											<?php }?> 
										<?php
}
}
$_smarty_tpl->smarty->ext->_foreach->restore($_smarty_tpl, 1);
?>

									
									<?php }?>
								<?php
}
}
$_smarty_tpl->smarty->ext->_foreach->restore($_smarty_tpl, 1);
?>

							</ul>
						</div>
					</div>
				</ul>
			</nav>
		</div>	<?php }
}
