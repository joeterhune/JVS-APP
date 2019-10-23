<style type="text/css">
	.h2{
		font-size:20px;
	}
	button, #buttons input {
		font-size:14px;
	}
</style>

<script src="/javascript/jquery/jquery.form.js" type="text/javascript"></script>
<script type="text/javascript">
	OIVTOP = 'https://oiv.15thcircuit.com/solr/';
	$(document).ready(function (){
	
		$("input:text").first().focus();
        	 
    	$(document).on('click','.search',function() {
	    	if(!$.trim($("#searchname").val()).length && !$.trim($("#searchcitation").val()).length){
	    		$('#dialogSpan').html(" Please enter a name, case number, or citation number and try again. ");
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
        
        $('.docSearchBtn').click(function() {
        	var searchTerm = $.trim($('#dsSearchTerm').val());
            if (searchTerm == "") {
            	showDialog("Search Term Required", "You must enter a search term.");
                return false;
            }
            
            {literal}    
            	$.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait</h1>', fadeIn: 0});
            {/literal}
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
                	{literal}    
                    	$.unblockUI();
                    {/literal}
                    return false;
                }
            });
                
            return true;
        });
        
        $(document).keypress(function(e) {
			if(e.which == 13) {
				e.preventDefault();
				if($("#dsSearchTerm").is(":focus")){
					$('.docSearchBtn').click();
				}
				else if($("#searchname").is(":focus")){
					$('.search').click();
				}
			}
		});
	});
</script>
<div style="padding-left:1%">
	
    <div style="float: right">
        <a class="helpLink" data-context="main">
            <img class="toolbarBtn" style="height: 20px !important; width: 20px;" alt="Help" title="Help" src="/images/help_icon.png">
        </a>
    </div>
    
    <form id="mainSearchForm" method="post" action="/cgi-bin/search.cgi">
    	<input type="hidden" name="div" id="div"/>
		<table style="width:75%;">
			<tr>
				<td><br/></td>
			</tr>
		    <tr>
	            <td colspan="3">
	                <span style="font-size:30px; color:blue; font-weight:bold">
	            		Search
	            	</span>	
	            	<div style="background:blue; width:100%; height:2px;">&nbsp;</div>
	            	<br/>
	            </td>
	        </tr>
		    <tr>
	            <td style="text-align:right; vertical-align:top; width: 130px">
	                <span>
	            		Name or Case #:
	                </span>
	            </td>
	
	            <td class="textinput">
	                <div>
	                    <div style="padding-bottom:1%">
	                        <input placeholder="Enter Name or Case Number to Search" style="line-height: 1.25em" type="text" id="searchname" name="name" size="30" title="Enter Name or Case Number to Search" />
	                        <button style="height: 2em" type="submit" class="search" title="Search Button">Search</button>
	                        <!--<input style="height: 2em" type="submit" name="gosearch" class="search" value="Search"/>-->
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
	                                        Search Business Names &nbsp;
	                                    </div>
	                                    <div style="display: table-cell">
	                                        <span style="color: red">
	                                            To broaden your search results, use an asterisk (*). For example, searching
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
	
	                    <div style="padding-top:1%">
	                        <button style="height: 2em" class="toggleSearchOpts" type="button" title="Toggle Search Options">Show/Hide Advanced Search Options</button>
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
												{for $inc=0; $inc < $perCol; $inc++}{if isset($divlist[$count + $inc])}{$div = $divlist[$count + $inc]}{else}{$div = ""}{/if}
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
	                                            {for $inc=0; $inc < $perCol; $inc++}{if isset($divtypes[$count + $inc])}{$divtype = $divtypes[$count + $inc]}{else}{$divtype=""}{/if}
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
												{for $inc=0; $inc < $perCol; $inc++}{if isset($partyTypes[$count + $inc])}{$partytype = $partyTypes[$count + $inc]}{/if}
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
	                                        {if (($inc == $perCol) || (isset($charges) && ($charges|@end)))}
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
	                                        {if (($inc == $perCol) || ($charges|@end))}
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
				<td><br/></td>
			</tr>
	        <tr>
	            <td style="text-align:right; vertical-align:top;">
	                <span>
	                    Citation #:
	                </span>
	
	            </td>
	
	            <td class="textinput">
	                <div>
	                    <input placeholder="Search by Citation #" style="line-height: 1.25em" type="text" id="searchcitation" name="citation" size="30" title="Enter Citation #"/>
	                    <button style="height: 2em" type="submit" class="search" title="Search Button">Search</button>
	                </div>
	
	            </td>
		    </tr>
		</form> 

	        <!--<tr>
	            <td>&nbsp;</td>
	            <td style="padding-top:1%">
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
	                                    Case Number(s) (Overrides other settings - separate multiple cases with spaces or commas)
	                                </div>
	                                <div class="docSearchCell docSearchHeader" style="display: table-cell" title="Enter Search Term">
	                                    Search Term(s) (separate multiple search terms with spaces or commas)
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
	                        <br/><br/>
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
	        </tr>-->
	        <tr>
	            <td colspan="2">
	            	<br/>
	                <span class="h3">
	                    <a href="/cgi-bin/casenotes/flaggedCaseSearch.cgi">
	                        Flagged Case Search
	                    </a>
	                </span>
	            </td>
	        </tr>
	        <tr>
	            <td colspan="2">
	                <span class="h3">
	                    <a href="/cgi-bin/PBSO/pbsolookup.cgi" data-tab="pbsolookup">
	                        PBSO Search
	                    </a>
	                </span>
	            </td>
	        </tr>
		</table>
	    <table style="width:75%;">
            <tr>
				<td><br/></td>
			</tr>    
		    <tr>
	            <td colspan="3">
	                <span style="font-size:30px; color:blue; font-weight:bold">
	            		Manage
	            	</span>	
	            	<div style="background:blue; width:100%; height:2px;">&nbsp;</div>
	            	<br/>
	            </td>
	        </tr>

	        <tr>
	            <td colspan="2">
	                <span class="h3">
	                    <a href="/cgi-bin/casenotes/bulkflag.cgi">
	                        Bulk Case Flagging/Unflagging
	                    </a>
	                </span>
	            </td>
	        </tr>
	        
	        <tr>
	            <td colspan="2">
	                <span class="h3">
	                    <a href="/cgi-bin/casenotes/bulknote.cgi">
	                        Add Bulk Case Notes
	                    </a>
	                </span>
	            </td>
	        </tr>
	        
	        <tr>
	            <td colspan="2">
	                <span class="h3">
	                    <a href="/cgi-bin/eservice/showFilings.cgi">
	                        View My e-Filing Status
	                    </a>
	                </span>
	            </td>
	        </tr>
	        
	        <tr>
	            <td colspan="2">
	                <span class="h3">
	                    <a href="/watchlist/showWatchList.php">
	                        Show My Case Watchlist
	                    </a>
	                </span>
	            </td>
	        </tr>
	    <tr>
			<td><br/></td>
		</tr>    
        <tr>
            <td colspan="3">
            	<span style="font-size:30px; color:blue; font-weight:bold">
	            	Reports
	            </span>	
	        </td>
	    </tr>
	    <tr>
	    	<td colspan="3">
	    		<div style="background:blue; width:100%; height:2px;">&nbsp;</div>
	    	</td>
	    </tr>
	    <tr>
	    	<td style="width:33%">
	            <div class="h2">
	            	All Judges
	            </div>
            </td>
            <td style="width:33%">
	        	<div class="h2">
	            	All Magistrates
	            </div>
	        </td>
	        <td>
				<div class="h2">
					All Divisions
				</div>
			</td>
        </tr>
		<tr>
		    <td>
				<span class="h3"></span>
				<select name="judgexy" title="Select Judge" style="min-width: 15em">
	            	{foreach from=$judges key=judge item=divs}
	                	<option value="{$judge}~{$divs}" title="{$judge}">{$judge}</option>
	                {/foreach}
	            </select>
				<button type="button" class="reportView judgeRpt" title="Submit Button" onclick="gojudge3();">View</button>
		    </td>
		    <td>
				<span class="h3"></span>
				<select name="magistratexy" style="min-width: 15em">
					{foreach from=$magistrates key=m item=mag}
						<option value="{$mag}">{$m}</option>
					{/foreach}
				</select>
				<button type="button" class="reportView magRpt" title="Submit Button" onclick="gomag();">View</button>
		    </td>
		    <td>
				<span class="h3"></span>
	            <select name="divxy_all" title="Select Division" style="min-width: 15em">
	               	{foreach from=$divlist item=div}
	                   	{if !in_array($div,$skipDivs)}
	                    	<option value="{$divisions.$div.opt}" title="{$divisions.$div.courtType} Division {$div}">{$div} {if $div != 'VA'}({$divisions.$div.courtType}){/if}</option>
	                    {/if}
	                {/foreach}
                 </select>
                <button type="button" class="reportView divRpt" title="Submit Button" onclick="godiv('all');">View</button>
            </td>
		</tr>
			<tr>
				<td>
					<div class="h2">
						Criminal Divisions
					</div>
				</td>
				<td>
					<div class="h2">
						Civil Divisions
					</div>
				</td>
				<td>
					<div class="h2">
						Family Divisions
					</div>
				</td>
			</tr>
			<tr>
                <td>
                	<span class="h3"></span>
	            	<select name="divxy_crim" title="Select Division" style="min-width: 15em">
	                	{foreach from=$crim_divlist item=div}
	                    	{if !in_array($div,$skipDivs)}
	                        	<option value="{$divisions.$div.opt}" title="{$divisions.$div.courtType} Division {$div}">{$div} {if $div != 'VA'}({$divisions.$div.courtType}){/if}</option>
	                        {/if}
	                    {/foreach}
                    </select>
                    <button type="button" class="reportView divRpt" title="Submit Button" onclick="godiv('crim');">View</button>
                </td>
                <td>
                	<span class="h3"></span>
	            	<select name="divxy_civ" title="Select Division" style="min-width: 15em">
	                	{foreach from=$civ_divlist item=div}
	                    	{if !in_array($div,$skipDivs)}
	                        	<option value="{$divisions.$div.opt}" title="{$divisions.$div.courtType} Division {$div}">{$div} {if $div != 'VA'}({$divisions.$div.courtType}){/if}</option>
	                        {/if}
	                    {/foreach}
                    </select>
                    <button type="button" class="reportView divRpt" title="Submit Button" onclick="godiv('civ');">View</button>
                </td>
                <td>
					<span class="h3"></span>
	            	<select name="divxy_fam" title="Select Division" style="min-width: 15em">
	                	{foreach from=$fam_divlist item=div}
	                    	{if !in_array($div,$skipDivs)}
	                        	<option value="{$divisions.$div.opt}" title="{$divisions.$div.courtType} Division {$div}">{$div} {if $div != 'VA'}({$divisions.$div.courtType}){/if}</option>
	                        {/if}
	                    {/foreach}
                    </select>
                    <button type="button" class="reportView divRpt" title="Submit Button" onclick="godiv('fam');">View</button>
                </td>
	        </tr>
		    <tr>
				<td>
					<div class="h2">
						Juvenile Divisions
					</div>
				</td>
				<td>
					<div class="h2">
						Probate Divisions
					</div>
				</td>
				<td style="width:33%">
		        	<div class="h2">
		            	&nbsp;
		            </div>
		        </td>
			</tr>
			<tr>
                <td>
                	<span class="h3"></span>
	            	<select name="divxy_juv" title="Select Division" style="min-width: 15em">
	                	{foreach from=$juv_divlist item=div}
	                    	{if !in_array($div,$skipDivs)}
	                        	<option value="{$divisions.$div.opt}" title="{$divisions.$div.courtType} Division {$div}">{$div} {if $div != 'VA'}({$divisions.$div.courtType}){/if}</option>
	                        {/if}
	                    {/foreach}
                    </select>
                    <button type="button" class="reportView divRpt" title="Submit Button" onclick="godiv('juv');">View</button>
                </td>
                <td>
                	<span class="h3"></span>
	            	<select name="divxy_pro" title="Select Division" style="min-width: 15em">
	                	{foreach from=$pro_divlist item=div}
	                    	{if !in_array($div,$skipDivs)}
	                        	<option value="{$divisions.$div.opt}" title="{$divisions.$div.courtType} Division {$div}">{$div} {if $div != 'VA'}({$divisions.$div.courtType}){/if}</option>
	                        {/if}
	                    {/foreach}
                    </select>
                    <button type="button" class="reportView divRpt" title="Submit Button" onclick="godiv('pro');">View</button>
                </td>
                <td>
		        	<div class="h2">
		            	&nbsp;
		            </div>
		        </td>
			</tr>
		<tr>
			<td><br/></td>
		</tr>  	
		<tr style="vertical-align: top">
			<td colspan="3">
				<span style="font-size:30px; color:blue; font-weight:bold">
	            	Calendars
	            </span>	
	            <div style="background:blue; width:100%; height:2px;">&nbsp;</div>
	        </td>
	    <tr>
	    	<td>
				<div class="h2">
					Circuit Civil
				</div>
			</td>
			<td>
				<div class="h2">
					County Civil
				</div>
			</td>
			<td>
				<div class="h2">
					Criminal
				</div>
			</td>
		</tr>
		<tr>
			<td id="civsel">
				<span class="h3"></span>
				<select style="min-width: 15em" class="divsel" name="caldiv" id="caldiv" title="Select a Civil Division">
					<option value="" title="Select a Division">Select a Division</option>
                    {foreach from=$circivdivs key=div item=info}
                    	<option value="{$div}" title="Division {$div}">{$div} ({$info.courtType})</option>
                    {/foreach}
				</select>
                <button type="button" class="calsubmit" name="calType" value="civcal">View</button>
		    </td>
		    <td id="cocivselsel">
		    	<span class="h3"></span>
				<select style="min-width: 15em" class="divsel" name="cocivdiv" id="cocivdiv" title="Select a Civil Division">
					<option value="" title="Select a Division">Select a Division</option>
                    {foreach from=$cocivdivs key=div item=info}
                    <option value="{$div}" title="Division {$div}">{$div} ({$info.courtType})</option>
                    {/foreach}
				</select>
                <button class="calsubmit" name="calType" value="cocivcal">View</button>
		    </td>
		    <td id="crimsel">
		    	<span class="h3"></span>
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
				<div class="h2">
					Family
				</div>
			</td>
			<td>
				<div class="h2">
					Juvenile
				</div>
			</td>
			<td>
				<div class="h2">
					Magistrates
				</div>
			</td>
		</tr>
		<tr>
			<td id="famsel">
		    	<span class="h3"></span>
				<select style="min-width: 15em" class="divsel"  name="famdiv" id="famdiv" title="Select Family Division">
                    <option value="" title="Select a Division">Select a Division</option>
                    {foreach from=$famdivs key=div item=info}
                    <option value="{$div}" title="Division {$div}">{$div} ({$info.courtType})</option>
                    {/foreach}
				</select>
                <button class="calsubmit" name="calType" value="famcal" title="Submit Button">View</button>
		    </td>
			<td id="juvsel">
				<span class="h3"></span>
				<select style="min-width: 15em" class="divsel"  name="juvdiv" id="juvdiv" title="Select Juvenile Division">
					<option value="" title="Select a Division">Select a Division</option>
                    {foreach from=$juvdivs key=div item=info}
                    <option title="Division {$div}" value="{$div}">{$div} ({$info.courtType})</option>
                    {/foreach}
				</select>
                <button class="calsubmit" name="calType" value="juvcal" title="Submit Button">View</button>
		    </td>
		    <td id="magsel">
		    	<span class="h3"></span>
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
				<div class="h2">
					Probate
				</div>
			</td>
			<td>
				<div class="h2">
					First Appearance
				</div>
			</td>
			<td>
				<div class="h2">
					Civil Traffic
				</div>
			</td>
		</tr>
		<tr>
			<td id="prosel">
		    	<span class="h3"></span>
				<select style="min-width: 15em" class="divsel"  name="prodiv" id="prodiv" title="Select Probate Division">
                    <option value="" title="Select a Division">Select a Division</option>
                    {foreach from=$prodivs key=div item=info}
                    <option value="{$div}" title="Division {$div}">{$div} ({$info.courtType})</option>
                    {/foreach}
				</select>
                <button class="calsubmit" name="calType" value="procal" title="Submit Button">View</button>
		    </td>
			<td id="fapsel">
		    	<span class="h3"></span>
				<select title="Select Courthouse for First Appearance" style="min-width: 15em" class="divsel"  name="fapch" id="fapch">
					<option value="" title="Select a Location">Select a Location</option>
                    {foreach from=$faps item=info}
                    <option title="{$info.courthouse_nickname} Courthouse" value="{$info.courthouse_id}">{$info.courthouse_nickname}</option>
                    {/foreach}
				</select>
                <button class="calsubmit" name="calType" value="fapcal" title="Submit Button">View</button>
		    </td>
			<td>
				<span class="h3"></span>
				<select title="Select a Traffic Court Type" style="min-width: 15em" class="divsel" name="civ_traffic" id="civ_traffic">
					<option value="Civil Traffic" title="Select a Traffic Court Type">Civil Traffic</option>
				</select>
                <button type="button" class="reportView divRpt" title="Submit Button" onclick="go_civ_traffic();">View</button>
			</td>
		</tr>
		<tr>
			<td>
				<div class="h2">
					Mediation
				</div>
			</td>
			<td>
				<div class="h2">
					Ex-Parte
				</div>
			</td>
			<td>
				<div class="h2">
					Mental Health
				</div>
			</td>
		</tr>
		<tr>
			<td id="medsel">
		    	<span class="h3"></span>
				<select style="min-width: 15em" class="divsel" name="medch" id="medch">
					<option value="all">All Mediators</option>
                    {foreach from=$mediators key=key item=m}
                    	<option value="{$m['mediator_id']}">{$m['name']}</option>
                    {/foreach}
				</select>
                <button class="calsubmit" name="calType" value="medcal">View</button>
                <input type="hidden" name="medcal" id="medcal" value=""/>
		    </td>
		    <td>
				<span class="h3"></span>
				<select title="Select an Ex-Parte Division" style="min-width: 15em" class="divsel" name="ex_parte" id="ex_parte">
					<option value="all">All Divisions</option>
                    {foreach from=$expdivs key=div item=info}
                    	<option value="{$div}" title="Division {$div}">{$div} ({$info.courtType})</option>
                    {/foreach}
				</select>
                <button class="calsubmit" name="calType" value="expcal">View</button>
                <input type="hidden" name="expcal" id="expcal" value=""/>
			</td>
			<td>
				<span class="h3"></span>
				<select title="Select a Mental Health Calendar" style="min-width: 15em" class="divsel" name="mental_health" id="mental_health">
					<option value="all">All Mental Health Calendars</option>
                    {foreach from=$mh_divs key=div item=div_name}
                    	<option value="{$div}" title="{$div_name}">{$div_name}</option>
                    {/foreach}
				</select>
                <button class="calsubmit" name="calType" value="mhcal">View</button>
                <input type="hidden" name="mhcal" id="mhcal" value=""/>
			</td>
		</tr>
	</table>
	<br/><br/>