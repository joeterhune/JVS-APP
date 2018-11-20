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
        
        <link rel="stylesheet" href="/style/ICMS.css?3.0"/>
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
        <script src="/javascript/orders.js?2.3" type="text/javascript"></script>
        <script src="/icms.js" type="text/javascript"></script>
        <script type="text/javascript">
        	$(document).ready(function (){
        	
	        	$(window).bind('keydown', function(event) {
				    if (event.ctrlKey || event.metaKey) {
				        switch (String.fromCharCode(event.which).toLowerCase()) {
				        case 's':
				            event.preventDefault();
				            $("#submit").click();
				        }
				    }
				});
        	
        		$(document).on('click', '.newOrderLink', function() {
        			//$("#noOrders").hide();
        			$("#noOrders").parents('tr').remove();
			    	var currentRows = $(this).parents('table').find('tr.aNewOrder').length + 1;
			    	var orderClone = $("#cloneNewOrder").html();
			    	orderClone = orderClone.replace(/ORDCOUNT/g, currentRows);
			    	$('#currentOrders > tbody:last').before(orderClone);
			    	
			    	$("#co_due_date_" + currentRows).datepicker({
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
					    yearRange: "-5:+5"
					});
					
					$("#co_order_date_" + currentRows).datepicker({
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
					    yearRange: "-5:+5"
					});
			    });
			    
			    $(document).on('click', '.newAttorneyLink_child', function() {
			    	$(".noAttorneysChild").parents('tr').remove();
			    	var child_id = $(this).attr('id');
        			//$("#noAttorneys").hide();
			    	var currentRows = $(this).parents('table').find('tr').length - 1;
			    	var attorneyClone = $("#cloneNewAttorneyChild").html();
			    	attorneyClone = attorneyClone.replace(/ATTCOUNT/g, currentRows);
			    	attorneyClone = attorneyClone.replace(/CHILDID/g, child_id);
			    	$(this).parents('table').find("tbody").last().before(attorneyClone);
			    });
			    
			    $(document).on('click', '.newPsychMedLink', function() {
			    	$(".noPsychMeds").remove();
			    	var child_id = $(this).attr('id');
        			//$("#noAttorneys").hide();
			    	var currentRows = $(this).closest('table').find('tr').length - 1;
			    	var pmClone = $("#cloneNewPsychMed").html();
			    	pmClone = pmClone.replace(/PMCOUNT/g, currentRows);
			    	pmClone = pmClone.replace(/CHILDID/g, child_id);
			    	$(this).parents('table').find("tbody").last().before(pmClone);
			    	
			    	$("#child_" + child_id + "_psych_meds_requested_date_" + currentRows).datepicker({
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
					    yearRange: "-5:+5"
					});
					
					$("#child_" + child_id + "_psych_meds_order_date_" + currentRows).datepicker({
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
					    yearRange: "-5:+5"
					});
			    });
			    
			    $(document).on('click', '.newAttorneyLink_father', function() {
			    	$(".noAttorneysFather").parents('tr').remove();
			    	var father_id = $(this).attr('id');
        			//$("#noAttorneys").hide();
			    	var currentRows = $(this).parents('table').find('tr').length - 1;
			    	var attorneyClone = $("#cloneNewAttorneyFather").html();
			    	attorneyClone = attorneyClone.replace(/ATTCOUNT/g, currentRows);
			    	attorneyClone = attorneyClone.replace(/FATHERID/g, father_id);
			    	$(this).parents('table').find("tbody").last().before(attorneyClone);
			    });
			    
			    $(document).on('click', '.newAttorneyLink_mother', function() {
			    	$(".noAttorneysMother").parents('tr').remove();
			    	var mother_id = $(this).attr('id');
        			//$("#noAttorneys").hide();
			    	var currentRows = $(this).parents('table').find('tr').length - 1;
			    	var attorneyClone = $("#cloneNewAttorneyMother").html();
			    	attorneyClone = attorneyClone.replace(/ATTCOUNT/g, currentRows);
			    	attorneyClone = attorneyClone.replace(/MOTHERID/g, mother_id);
			    	$(this).parents('table').find("tbody").last().before(attorneyClone);
			    });
			    
			    $(document).on('click', '.deleteNote', function() {
			    	var note_id = $(this).attr('id'); 
			    	
			    	$('#dialogSpan').html("Are you sure you want to delete this note?");
				    $('#dialogDiv').dialog({
				    	resizable: false,
				        modal: true,
				        minheight: 150,
			        	width: 500,
				        title: 'Complete?',
				        buttons: {
				        	"Yes": function() {
				        		$(this).dialog( "close" );
				            	{literal}
			        				var postData = {note_id: note_id};
			        			{/literal}
						    	$.ajax({
			                        url: '/case_management/deleteNote.php',
			                        data: postData,
			                        async: true,
			                        success: function(data) {
			                        	$("#note-" + note_id).hide();
			                        }
			                    });
				                return false;
				            },
				            "No": function(){
				            	$(this).dialog( "close" );
				                return false;
				            }
				        }
					});
			    });
        	
        		$(document).on('click', '.order_completed', function() {
			    	var order_id = $(this).attr('id'); 
			    	
			    	$('#dialogSpan').html("Are you sure you want to mark this item complete?");
				    $('#dialogDiv').dialog({
				    	resizable: false,
				        modal: true,
				        minheight: 150,
			        	width: 500,
				        title: 'Complete?',
				        buttons: {
				        	"Yes": function() {
				        		$(this).dialog( "close" );
				            	{literal}
			        				var postData = {order_id: order_id};
			        			{/literal}
						    	$.ajax({
			                        url: '/case_management/completeOrder.php',
			                        data: postData,
			                        async: true,
			                        success: function(data) {
			                        	$("#orderRow-" + order_id).hide();
			                        }
			                    });
				                return false;
				            },
				            "No": function(){
				            	$(this).dialog( "close" );
				                return false;
				            }
				        }
					});
			    });
        	
        		$(document).on('click', '.imageLink', function() {
			        var ucn = $(this).attr('data-casenum');
			        var ucnobj = $(this).attr('data-ucnobj');
			        var caseid = $(this).attr('data-caseid');
			        var tabTitle = $(this).attr('data-docname');

			        var pieces = ucnobj.split("|");
			        var objID = pieces[1];
			        
			        window.open('/cgi-bin/image-new.cgi?ucn=' + ucn + '&objid=' + objID +'&caseid=' + caseid, '_blank');
					return true;
			    });
        	
        		$(document).on('click', '.relCaseLookup', function(e) {
        			var original_element = $(this);
        			{literal}
        				$.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait </h1>', fadeIn: 0});
        			{/literal}
        			var case_number = $("#relCaseNumber").val();
        			if(case_number == ""){
	        			$('#dialogSpan').html("Please enter a case number.");
						$('#dialogDiv').dialog({
							resizable: false,
							minheight: 150,
							width: 500,
							modal: true,
							title: 'No Case Number Entered',
							buttons: {
								"OK": function() {
									$.unblockUI();
									$(this).dialog( "close" );
									return false;
								}
							}
						});
        			}
        			{literal}
        				var postData = {case_number: case_number};
        			{/literal}
		        	 $.ajax({
                        url: '/case_management/getRelatedCaseInfo.php',
                        data: postData,
                        async: true,
                        success: function(data) {
                        	$.unblockUI();

                        	var data_html = $.parseHTML(data);
                        	var case_num, case_style, division_id;
                        	$.each($(data_html[0]).find('td'), function(i, el) {
                        		if(i == 0){
                        			case_num = $(this).text();
                        		}
                        		if(i == 4){
                        			case_style = $(this).text();
                        		}
                        		if(i == 5){
                        			division_id = $(this).text();
                        		}
							});
                        	
                        	if(case_num){
	                        	$('#dialogSpan').html("<strong>Case Number:</strong> " + case_num + "<br/><strong>Case Style:</strong> " + case_style + "<br/><strong>Division:</strong> " + division_id + "<br/><br/>Is this correct?");
								$('#dialogDiv').dialog({
									resizable: false,
									minheight: 150,
									width: 500,
									title: 'Confirm Case',
									modal: true,
									buttons: {
										"Yes": function() {
											$(this).dialog( "close" );
											
											$(original_element).parent().parent().replaceWith(data);
							                var new_id = $(".partiesHere").attr('id');
							                var case_vals = new_id.split('~');
							                var case_id = case_vals[2];
							                var case_number = case_vals[1];
							                
				                            var new_multi_select = $("#cloneMe").html();
				                            new_multi_select = new_multi_select.replace(/case_number_here/g, case_number);
				                            new_multi_select = new_multi_select.replace(/case_id_here/g, case_id);
				                            var putHere = $(".partiesHere");
				                            $(putHere).html(new_multi_select);
				                            $('.relatedTable').trigger('update');
							        		$('.relatedTable').trigger('appendCache');
				                            return false;
								        },
								        "No": function() {
								     	  	$(this).dialog( "close" );
								            return false;
								        }
									}
								});
							}
							else{
								$('#dialogSpan').html("No cases were found matching " + case_number + ".");
								$('#dialogDiv').dialog({
									resizable: false,
									minheight: 150,
									width: 500,
									modal: true,
									title: 'Case Number Not Found',
									buttons: {
										"OK": function() {
											$.unblockUI();
											$(this).dialog( "close" );
											return false;
										}
									}
								});
							}
                        }
                    });
	            });
        		
        		$(document).on('click', '#caseLookup', function() {
        			{literal}
        				$.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait </h1>', fadeIn: 0});
        			{/literal}
        			var case_number = $("#case_number_initial").val();
        			if(case_number == ""){
	        			$('#dialogSpan').html("Please enter a case number.");
						$('#dialogDiv').dialog({
							resizable: false,
							minheight: 150,
							width: 500,
							modal: true,
							title: 'No Case Number Entered',
							buttons: {
								"OK": function() {
									$.unblockUI();
									$(this).dialog( "close" );
									return false;
								}
							}
						});
        			}
        			{literal}
        				var postData = {case_number: case_number};
        			{/literal}
		        	 $.ajax({
                        url: '/case_management/getJuvCaseInfo.php',
                        data: postData,
                        async: true,
                        success: function(data) {
                        	$.unblockUI();
                            $("#juv_case_results").html(data);
                            $("#case_number_initial").val($("#case_number").val());
                            
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
					            yearRange: "-5:+5"
							});
							
							$('.relatedTable').tablesorter ({
						        widgets: ['filter', 'zebra'],
						        widthFixed: false,
						        //sortList: [[1,0],[6,1]],
						        widgetOptions: {
						            filter_columnFilters: true,
						            filter_saveFilters: false
						        },
						        cssInfoBlock : "tablesorter-no-sort",
	                    		selectorRemove : "tr.remove-me"
						    });
						    
						    $('.relatedTable').find('input').placeholder();
							
                            return false;
                        }
                    });
	            });
	            
	            if($("#case_number_initial").val() != ""){
        			$("#caseLookup").click();
        		}
        		
        		$(document).on('click', '.fatherPicker', function() {
        			if($(this).val() == 'Other'){
        				var child_id = $(this).data('child_id');
        				if($("#child_" + child_id + "_father_custom_row").length){
        					$("#child_" + child_id + "_father_custom_row").show();
        				}
        				else{
        					$("#other-" + child_id).after("<tr id=\"child_" + child_id + "_father_custom_row\" style=\"text-align:center\"><td>&nbsp;</td><td>Father's Name: &nbsp;&nbsp;<input type=\"text\" name=\"child_" + child_id + "_father_custom\" id=\"child_" + child_id + "_father_custom\"/></td></tr>");
        				}
        			}
        			else{
        				var child_id = $(this).data('child_id');
        				$("#child_" + child_id + "_father_custom_row").hide();
        			}
        		});
        		
        		$(document).on('change', '.cp_executed', function() {
        			if($(this).val() == 'Yes'){
        				//$(".exec_date").show();
        				//$(".exp_date").show();
        			}
        			else{
        				//$(".exec_date").hide();
        				//$(".exp_date").hide();
        			}
        		});
        		
        		$(document).on('change', '.hs_ind', function() {
        			var select_id = $(this).attr('id');
        			var pieces = select_id.split('_');
        			var child_id = pieces[1];

        			if($(this).val() == 'Yes'){
        				$(".hs_date-" + child_id).show();
        			}
        			else{
        				$(".hs_date-" + child_id).hide();
        			}
        		});
        		
        		$(document).on('change', '.psych_ind', function() {
        			var select_id = $(this).attr('id');
        			var pieces = select_id.split('_');
        			var child_id = pieces[1];
        			
        			if($(this).val() == 'Yes'){
        				$(".psych_yes-" + child_id).show();
        			}
        			else{
        				$(".psych_yes-" + child_id).hide();
        			}
        		});
        		
        		$(document).on('change', '.in_custody_ind', function() {
        			var select_id = $(this).attr('id');
        			var pieces = select_id.split('_');
        			var person_id = pieces[1];
        			
        			if($(this).val() == 'Yes'){
        				$(".in_custody_yes-" + person_id).show();
        			}
        			else{
        				$(".in_custody_yes-" + person_id).hide();
        			}
        		});
        		
        		$(document).on('change', '.no_contact_ind', function() {
        			var select_id = $(this).attr('id');
        			var pieces = select_id.split('_');
        			var person_id = pieces[1];
        			
        			if($(this).val() == 'Yes'){
        				$(".no_contact_yes-" + person_id).show();
        			}
        			else{
        				$(".no_contact_yes-" + person_id).hide();
        			}
        		});
        		
        		$(document).on('click', '.add-related', function() {
        			$("#noRelated").hide();
        			$("<tr><td>Case Number:</td><td><input type=\"text\" name=\"relCaseNumber\" id=\"relCaseNumber\" size=\"25\"/></td><td><button type=\"button\" class=\"relCaseLookup\">Search</button></td></td><td></td></tr>").insertBefore($(this).parent().parent());
        			$('.relatedTable').trigger('update');
			        $('.relatedTable').trigger('appendCache');
        		});
        		
        		$(document).on('click', '.collapsePrevOrdered', function() {
			    	$("#prevOrderedSection").toggle();
			    	$(this).toggleClass("descArrow ascArrow");
			    });
        		
        		$(document).on('click', '.collapseOrdered', function() {
			    	$("#orderedSection").toggle();
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
			    
			    $(document).on('click', '.collapseRelated', function() {
			    	$("#relatedSection").toggle();
			    	$(this).toggleClass("descArrow ascArrow");
			    });
			    
			    $(document).on('click', '.collapseChild', function() {
			    	var person_id = $(this).attr('id');
			    	$("#childSection-" + person_id).toggle();
			    	$(this).toggleClass("descArrow ascArrow");
			    });
			    
			    $(document).on('click', '.collapseAttorneysChild', function() {
			    	var person_id = $(this).attr('id');
			    	$("#attorneysSectionChild-" + person_id).toggle();
			    	$(this).toggleClass("descArrow ascArrow");
			    });
			    
			    $(document).on('click', '.collapseAttorneysFather', function() {
			    	var person_id = $(this).attr('id');
			    	$("#attorneysSectionFather-" + person_id).toggle();
			    	$(this).toggleClass("descArrow ascArrow");
			    });
			    
			    $(document).on('click', '.collapseAttorneysMother', function() {
			    	var person_id = $(this).attr('id');
			    	$("#attorneysSectionMother-" + person_id).toggle();
			    	$(this).toggleClass("descArrow ascArrow");
			    });
			    
			    $(document).on('click', '.collapsePerson', function() {
			    	var person_id = $(this).attr('id');
			    	$("#personSection-" + person_id).toggle();
			    	$(this).toggleClass("descArrow ascArrow");
			    });
			    
			    $(document).on('click', '.collapseNotes', function() {
			    	$("#notesSection").toggle();
			    	$(this).toggleClass("descArrow ascArrow");
			    });
			    
			    $(document).on('click', '.collapsePrevNotes', function() {
			    	$("#prevNotesSection").toggle();
			    	$(this).toggleClass("descArrow ascArrow");
			    });
			    
			    $(document).on('click', '.collapsePrevPlacements', function() {
			    	var person_id = $(this).attr('id');
			    	$("#prevPlacementsSection-" + person_id).toggle();
			    	$(this).toggleClass("descArrow ascArrow");
			    });
			    
			    $(document).on('click', '.collapseCurrPlacement', function() {
			    	var person_id = $(this).attr('id');
			    	$("#currPlacementSection-" + person_id).toggle();
			    	$(this).toggleClass("descArrow ascArrow");
			    });
        	});
        	
        	function eraseValue(id){
        		$("#" + id).val("");
        	}
        </script>
        <style type="text/css">
        	#caseLookup, #juv_case_results button{
            	background-color:#800020;
            }
            #juv_case_results tbody th, thead th{
            	color:#800020;
            	border-color:#800020;
            	background-color:#cc99a5;
            }
            
            #juv_case_results table.tablesorter tbody tr td {
			    background-color: #fffffe !important;
			}
            
            #juv_case_results table.tablesorter tbody tr.even td {
			    background-color: #cc99a5 !important;
			}
			
			#juv_case_results a{
				color:blue;
			}
        </style>
        </head>
	    <body>
	    	<div class="container-fluid">
	    		<div id="dialogDiv">
	                <span id="dialogSpan" style="font-size: 80%"></span>
	            </div>
	            <br/>
	    		<span style="font-size:28px"><strong>Dependency Case Management</strong></span>
	    		<br/><br/>
				<form method="post" onsubmit="return false;">
					<table>
						<tr>
							<td>Case Number: </td>
							<td><input class="cn" type="text" name="case_number_initial" id="case_number_initial" value="{$case_number}" size="30"/></td>
							<td><button type="button" class="caseLookup" id="caseLookup">Search</button></td>
						</tr>
					</table>
				</form>
				<br/>
				<div id="juv_case_results">
				</div>
			</div>
		</body>