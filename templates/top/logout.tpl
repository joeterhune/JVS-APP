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
        <script src="/javascript/workflow.js?1.6" type="text/javascript"></script>     
    </head>
    <body>
        
        <div class="container-fluid">

          <div id="dialogDiv">
                <span id="dialogSpan" style="font-size: 80%"></span>
            </div>
			<div class="row">
		        <nav class="navbar navbar-default navbar-fixed-top" style="height:81px;" role="navigation">
						<div id="logoDiv" class="pull-right hidden-xs" >
							<a href="/"><img class="homeLink img img-responsive"  src="/images/JVSLOGO-Wide.jpg" style="max-height:75px; 0 -30px 0 0" title="JVS Logo" alt="JVS" /></a>
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
			</div>
			<br class="clear"/><br class="clear"/><br class="clear"/><br class="clear"/>
			<br/>
			<div align="center">
				You have successfully logged out.
				<br/><br/>
				<a href="/login.php">Return to Login Page</a>
			</div>