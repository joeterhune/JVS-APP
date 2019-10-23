<script type="text/javascript">
	$('#{$tab}_link_div').ready(function () {
    	var pane = $('#{$tab}_link_div');
                
        $(pane).find('.listTable').bind('filterEnd', function () {
        	countRows(pane);
        });
                
        $(pane).find('.listTable').tablesorter ({
        	widgets: ['zebra','filter'],
            widgetOptions: {
            	filter_columnFilters: true,
                filter_saveFilters: false,
                filter_reset : '.reset'
            }
        });
                      
	    $(pane).find('.listTable').tablesorterPager({
	    	container: $(".{$tab}_link_div-pager"), 
	        positionFixed: false, size: 100
	    });
                
        var cookieVal = $(location).attr('href');
        $.cookie("ICMS_2", cookieVal);
                
        $('input, textarea').placeholder();
        $(pane).find('.listTable').first().trigger('update');
        return true;
	});
            
    function countRows(pane) {
    	// Count the rows displayed, and show it in the table header.
        var displayedEvents = 0;
        var listTable = $(pane).find('.listTable').first();
        var rows = $(listTable).find('.eventRow');
        $(listTable).find('.eventRow').each(function (i,e) {
        	if ($(e).css('display') != 'none') {
            	displayedEvents += 1;
            }
        });
                
        var rowWord = " Rows";
        if (displayedEvents == 1) {
        	rowWord = " Row"
        }
        $(pane).find('.eventcount').html(displayedEvents + rowWord);
	}
</script>

<div id="{$tab}_link_div" style="margin-top:2%">

	<div class="buttondiv">
    	<button type="button" class="reset" title="Reset Filters">Reset Filters</button>
    </div>
            
    <div id="{$tab}_link_div-pager" class="{$tab}_link_div-pager pager tablesorter-pager" style="top: 40px;">
    	<form>
        	<img class="first disabled" alt="first" src="/images/first.png"/>
            <img class="prev disabled" alt="prev" src="/images/prev.png"/>
            <input class="pagedisplay" type="text"/>
            <img class="next disabled" alt="next" src="/images/next.png"/>
            <img class="last disabled" alt="last" src="/images/last.png"/>
            <select class="pagesize">
            	<option value="10">10 per page</option>
                <option value="25">25 per page</option>
                <option value="50">50 per page</option>
                <option value="100">100 per page</option>
                <option value="500">500 per page</option>
                <option value="1000">1000 per page</option>
                <option value="5000">5000 per page</option>
                <option value="10000">10000 per page</option>
 			</select>
		</form>
	</div>
            
	<div class="rptdiv">
    	<table class="summary" style="width: 100%; font-size: 9pt">
        	<tr>
            	<td class="rptname title" style="font-size: 150%" >
                	Related Case Search <span class="eventcount">&nbsp;</span>
                </td>
            </tr>
            <tr>
            	<td>
                	<table style="width: 100%" class="listTable">
                    	<thead>
                        	<tr class="title">
                            	<th class="sel" data-placeholder="Part of Name">
                                	Name
                                </th>
                                        
                                <th class="sel datecol filter-select" data-placeholder="DOB">
                                	DOB
                                </th>
                                        
                               	<th class="sel filter-select" data-placeholder="Select">
                                	Party Type
                                </th>
                                        
                                <th class="sel" style="width: 15em" data-placeholder="Part of case #">
                               		Case #
                               	</th>
                                        
                                <th class="sel datecol filter-select" data-placeholder="Sel">
                                	File
                                    <br/>
                                    Date
                                </th>
                                        
                                <th class="sel filter-select" style="max-width: 4em" data-placeholder="Sel">
                                	Div
                                </th>
                                        
                                <th class="sel filter-select" style="max-width: 4em" data-placeholder="Sel">
                                	Type
                                </th>
                                        
                                <th class="sel filter-select" data-placeholder="Sel">
                                	Status
                                </th>
                        	</tr>
 						</thead>
                                
                        <tbody style="text-align: center">
                        	{if ($parties|@count) > 0 && ($parties != "")}
	                        	{foreach from=$parties item=case}
	                            	<tr class="eventRow">
	                                    <td style="text-align: left">
	                                        {$case.FirstName} {$case.MiddleName} {$case.LastName} {$case.Suffix}
	                                    </td>
	                                    <td class="datecol">
	                                    	{$case.DOB}
	                                    </td>
	                                    <td>
	                                    	{$case.PartyTypeDescription}
	                                    </td>
	                                    <td>
	                                    	{if $case.HasWarrant == 'Yes'} <img src="/asterisk.png" />{/if}
	                                    	<a class="caseLink" data-casenum="{$case.CaseNumber}">{$case.CaseNumber}</a>
	                                    </td>
	                                    <td class="datecol">
	                                    	{$case.FileDate}
	                                    </td>
	                                    <td>
	                                    	{$case.DivisionID}
	                                    </td>
	                                    <td>
	                                        {$case.CaseType}
	                                    </td>
	                                    <td>
	                                        {$case.CaseStatus}
	                                    </td>
	                                </tr>
	                        	{/foreach}
	                        	{else}
	                        		<tr class="eventRow">
	                        			<td colspan="8">No related cases found.</td>
	                        		</tr>
                        	{/if}
                     	</tbody>
                	</table>
            	</td>
        	</tr>
    	</table>    
	</div>
            
    <div id="{$tab}_link_div-pager" class="{$tab}_link_div-pager pager tablesorter-pager" style="top: 40px;">
    	<form>
        	<img class="first disabled" alt="first" src="/images/first.png"/>
            <img class="prev disabled" alt="prev" src="/images/prev.png"/>
            <input class="pagedisplay" type="text"/>
            <img class="next disabled" alt="next" src="/images/next.png"/>
            <img class="last disabled" alt="last" src="/images/last.png"/>
            <select class="pagesize">
            	<option value="10">10 per page</option>
                <option value="25">25 per page</option>
                <option value="50">50 per page</option>
                <option value="100">100 per page</option>
                <option value="500">500 per page</option>
                <option value="1000">1000 per page</option>
                <option value="5000">5000 per page</option>
                <option value="10000">10000 per page</option>
            </select>
		</form>
	</div>         
</div>