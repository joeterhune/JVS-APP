<style type="text/css">
	td.tablesorter-pager{
		background-color:#FFFFFE !important;
	}
</style>
<script src="/javascript/jquery/widget-pager.js" type="text/javascript"></script>
<script type="text/javascript">
	{literal}
    	$.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait </h1>', fadeIn: 0});
    {/literal}
	$(document).ready(function() { 
	
	    $('#table-{$data.divname}-{$data.yearmonth}-{$data.rpttype}').tablesorter ({
	        widgets: ['saveSort', 'filter', 'zebra', 'pager'],
	        widthFixed: true,
	        //sortList: [[1,0],[6,1]],
	        widgetOptions: {
	            filter_columnFilters: true,
	            filter_saveFilters: true,
	            filter_reset : '.table-{$data.divname}-{$data.yearmonth}-{$data.rpttype}-reset',
	            filter_functions: {
	                {$data.config.CaseAgeColumn}: {
	                    "0-120 days"    : function(e, n, f, i, $r, c, data) { return n <= 120; },
	                    "121-180 days"  : function(e, n, f, i, $r, c, data) { return n >= 121 && n <=180; },
	                    "180+ days"     : function(e, n, f, i, $r, c, data) { return n > 180; }
	                }
	            },
	            {literal}
	            	pager_output: 'Showing rows {startRow} - {endRow} of {totalRows}, page {page} of {totalPages}.',
	            {/literal}
	            pager_processAjaxOnInit: true,
	            pager_updateArrows: true,
	            pager_startPage: 0,
	            pager_size: 100,
	            pager_savePages: true,
	            pager_storageKey: 'tablesorter-pager-genlist',
	            pager_ajaxUrl: '/reports/div_list.php?type={$courttype}&divname={$divname}&rpttype={$rpttype}&yearmonth={$yearmonth}&ajax=1&pagenum={literal}{page}{/literal}&{literal}{filterList:filter}{/literal}&{literal}{sortList:column}{/literal}&pagesize={literal}{size}{/literal}',
	            pager_customAjaxUrl:  function(table, url) {
		            // manipulate the url string as you desire
		            // url += '&currPage=' + window.location.pathname;
		            // trigger my custom event
		            $(table).trigger('changingUrl', url);
		            // send the server the current page
		            return url;
		        },
		        pager_ajaxError: null,
		        pager_ajaxObject: {
		          type: 'GET', // default setting
		          dataType: 'json',
		          success : function(data) {
					var pane = $('#report-{$data.divname}-{$data.yearmonth}-{$data.rpttype}');
				        	
					$('#table-{$data.divname}-{$data.yearmonth}-{$data.rpttype} tbody').find('tr').each(function(i,e){
						var age = parseInt($(e).find('td').eq({$data.config.CaseAgeColumn}).text());
					    if (age > 180) {
					    	$(e).addClass('pastStandard');
					    } else if (age > 120) {
					    	$(e).addClass('nearStandard');
					    }
					});
					      
					$(pane).find('input').placeholder();
					
					//This screws up paging...
					$('#table-{$data.divname}-{$data.yearmonth}-{$data.rpttype}').trigger('sortupdate');
					$('#table-{$data.divname}-{$data.yearmonth}-{$data.rpttype}').trigger("appendCache");

					$.unblockUI();
		          }
		        },
	            pager_ajaxProcessing: function(data){
		          if (data && data.hasOwnProperty('rows')) {
		            var indx, r, row, c, d = data.rows,
		            // total number of rows (required)
		            total = data.total_rows,
		            
		            // array of header names (optional)
		            headers = data.headers,
		            
		            headerInfo = data.headerInfo,
		            
		            // cross-reference to match JSON key within data (no spaces)
		            headerXref = headers.join(',').replace(/\s+/g,'').split(','),
		            
		            // all rows: array of arrays; each internal array has the table cell data for that row
		            rows = [],
		            // len should match pager set size (c.size)
		            len = d.length;

		            for (r = 0; r < len; r++) {
		              row = []; // new row array
					  for (var c in d[r]) {
		                if (typeof(c) === "string") {
		                  // match the key with the header to get the proper column index
						  var indx = $.inArray(c, headerXref);
		                  // add each table cell data to row array
		                  if (indx >= 0) {
		                  	var theRow = "";
		                  	if(c == 'CaseNumber'){
		                  		theRow += '<td class="' + headerInfo[c]['cellClass'] + '" style="text-align:center"><a href="/cgi-bin/search.cgi?name=' + d[r][c] + '">' + d[r][c] + '</a></td>';
		                  	}
		                  	else{
		                  		theRow += '<td class="' + headerInfo[c]['cellClass'] + ' ' + headerInfo[c]['class'] + '">' + d[r][c] + '</td>';
		                  	}

		                    row[indx] = theRow;
		                  }
		                }
		              }
		              rows.push(row); // add new row array to rows array
		            }
		            
		            var headerLength = headers.length;
		            var headers = [];
					for (var col in headerInfo) {
						var theHeaderRow = "";
		            	if(headerInfo[col]['class'] == 'caseLink'){
		            		theHeaderRow += '<span class="' + headerInfo[col]['filter_type'] + '" data-placeholder="' + headerInfo[col]['filter_placeholder'] +'">' + headerInfo[col]['name'] + '</span>';
		            	}
		            	else{
		            		theHeaderRow += '<span class="' + headerInfo[col]['filter_type'] + ' ' + headerInfo[col]['class'] + headerInfo[col]['filter_placeholder'] +'">' + headerInfo[col]['name'] + '</span>';
		            	}
		            	
		            	//Not working
		            	//headers[i] = theHeaderRow;
		            	
		            	headers[col] = headerInfo[col]['name'];
		            }
		            
		            // in version 2.10, you can optionally return $(rows) a set of table rows within a jQuery object
		            return [ total, rows, headers ];
		          }
		        },
		        pager_css: {
		          container   : 'tablesorter-pager',
		          errorRow    : 'tablesorter-errorRow', // error information row (don't include period at beginning)
		          disabled    : 'disabled'              // class added to arrows @ extremes (i.e. prev/first arrows "disabled" on first page)
		        },
		        pager_selectors: {
		          container   : '.pager',       // target the pager markup (wrapper)
		          first       : '.first',       // go to first page arrow
		          prev        : '.prev',        // previous page arrow
		          next        : '.next',        // next page arrow
		          last        : '.last',        // go to last page arrow
		          gotoPage    : '.gotoPage',    // go to page selector - select dropdown that sets the current page
		          pageDisplay : '.pagedisplay', // location of where the "output" is displayed
		          pageSize    : '.pagesize'     // page size selector - select dropdown that sets the "size" option
		
		        },

	        },
	    });
	    
	    $('.table-{$data.divname}-{$data.yearmonth}-{$data.rpttype}-reset').click(function(){
			$('table').trigger('filterReset').trigger('sortReset');
		    return false;
		});
	    
        $('#report-{$data.divname}-{$data.yearmonth}-{$data.rpttype}').on('click','.lopSubmit',function(e) {
            e.preventDefault;
            var checked = $('#table-{$data.divname}-{$data.yearmonth}-{$data.rpttype}').find('.flagLOP:checked');
            var count = $(checked).length;
            if (count == 0) {
                showDialog('No Cases Selected','No case numbers were selected.');
                return false;
            } else {
                var html = "<p>Submit " + count + " selected cases to the LOP queue?</p>" +
                    "<p>This will ONLY put the cases into the queue for further review.  It will NOT generate any orders.</p>";
                $('#dialogSpan').html(html);
                $('#dialogDiv').dialog({
                    resizable: false,
                    minheight: 150,
                    width: 500,
                    modal: true,
                    title: 'Confirm Submission',
                    buttons: {
                        "OK": function() {
                            $(this).dialog( "close" );
                            $('#form-{$data.divname}-{$data.yearmonth}-{$data.rpttype}').ajaxSubmit({
                                async: false,
                                success: function(data) {
                                    return true;
                                }
                            });
                            return false;
                        },
                        "Cancel": function() {
                            $(this).dialog("close");
                            return false;
                        }
                    }
                });
            }
            return false;
        });
	        
        $('#report-{$data.divname}-{$data.yearmonth}-{$data.rpttype}').on('click','.tagLOP',function(e) {
            e.preventDefault;
            $('#table-{$data.divname}-{$data.yearmonth}-{$data.rpttype}').find('.flagLOP').prop('checked',true);
            return true;
        });

	});
</script>

<div style="float: right">
    <a class="helpLink" data-context="divreport">
        <img class="toolbarBtn" style="height: 20px !important; width: 20px;" alt="Help" title="Help" src="/images/help_icon.png">
    </a>
</div>

<div id="report-{$data.divname}-{$data.yearmonth}-{$data.rpttype}" class="pendReport" style="margin-top:1%">
    <div>
        <button class="table-{$data.divname}-{$data.yearmonth}-{$data.rpttype}-reset">Reset Sort/Filters</button>
        <button class="printTab printHide" data-print="pendReport" data-orientation="landscape">Print This</button>
        <button class="rptExport" data-rpath="{$data.rpath}" data-header="1">Export</button>
    </div>
                    
    <div class="h1">
        {$data.config.title1} - {$data.config.title2} - {$rowCount} Rows
    </div>
    
    <div class="h2">
    	{$data.config.rptdate}
    </div>
    
    {if isset($lop)}
	    <form action="/workflow/queueLOP.php" method="POST" id="form-{$data.divname}-{$data.yearmonth}-{$data.rpttype}">
	    <button class="lopSubmit" type="button">Submit Selected Cases to LOP Queue</button>
	    <br/>
	    <a href="#" class="tagLOP">Select All Cases</a>
    {/if}
    
    <table class="summary" id="table-{$data.divname}-{$data.yearmonth}-{$data.rpttype}" style="width: 100%">
        <thead>
        	<tr class="tablesorter-ignoreRow">
		      <td class="pager" colspan="{$data.config.fields|@count}">
		        <img src="/images/first.png" class="first"/>
		        <img src="/images/prev.png" class="prev"/>
		        <span class="pagedisplay"></span> <!-- this can be any element, including an input -->
		        <img src="/images/next.png" class="next"/>
		        <img src="/images/last.png" class="last"/>
		        <select class="pagesize">
		          <option value="5">5</option>
		          <option value="10">10</option>
		          <option value="25">25</option>
		          <option value="50">50</option>
		          <option value="100" selected="selected">100</option>
		          <option value="250">250</option>
		          <option value="500">500</option>
		          <option value="1000">1000</option>
		          <option value="2500">2500</option>
		          <option value="5000">5000</option>
		        </select>
		        rows per page
		      </td>
		    </tr>
            <tr>
                {foreach $data.config.fields as $field}
                	<th class="{if $field.class != "caseLink"}{$field.class}{/if} {$field.filter_type}" data-placeholder="{$field.filter_placeholder}">{$field.name}</th>
                {/foreach}
            </tr>
        </thead>
        <tbody>
            
        </tbody>
        <tfoot>
        	
		</tfoot>
    </table>
    
    {if isset($lop)}
    <input type="hidden" name="reportDiv" value="{$data.divname}"/>
    </form>
    {/if}
</div>