<style type="text/css">
	a:visited{
		color:purple;
	}
	td.tablesorter-pager{
		background-color:#FFFFFE !important;
	}
</style>
<script src="/javascript/jquery/widget-pager.js" type="text/javascript"></script>
<script type="text/javascript">
	$(document).ready(function (){
	
		$('#deletedItems').tablesorter ({
	        widgets: ['filter', 'zebra', 'pager'],
	        widthFixed: true,
	        //sortList: [[1,0],[6,1]],
	        widgetOptions: {
	            filter_columnFilters: true,
	            filter_saveFilters: false,
	            filter_reset : '#deletedItems-reset',
		        {literal}
		            pager_output: 'Showing rows {startRow} - {endRow} of {totalRows}, page {page} of {totalPages}.',
		        {/literal}
		        pager_processAjaxOnInit: true,
	            pager_updateArrows: true,
	            pager_startPage: 0,
	            pager_size: 100,
	            pager_savePages: true,
	            pager_storageKey: 'tablesorter-pager-showdeleted',
	            pager_ajaxUrl: '/workflow/show_deleted.php?queue={$queue}&ajax=1&pagenum={literal}{page}{/literal}&{literal}{filterList:filter}{/literal}&{literal}{sortList:column}{/literal}&pagesize={literal}{size}{/literal}',
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
					      
					$("#deletedItems").find('input').placeholder();
					
					//This screws up paging...
					$('#deletedItems').trigger('sortupdate');
					$('#deletedItems').trigger("appendCache");
					//$("#documents").trigger('updateComplete');

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
		              for (c in d[r]) {
		                if (typeof(c) === "string") {
		                  // match the key with the header to get the proper column index
		                  indx = $.inArray(c, headerXref);
		                  // add each table cell data to row array
		                  if (indx >= 0) {
		                  	var theRow = "";
		                  	if(c == 'UCN'){
		                  		theRow += '<td class="' + headerInfo[indx]['cellClass'] + '" style="text-align:center"><a href="/cgi-bin/search.cgi?name=' + d[r][c] + '">' + d[r][c] + '</a></td>';
		                  	}
		                  	else if(c == 'Title'){
		                  		theRow += '<td class="' + headerInfo[indx]['cellClass'] + '"><a href="/orders/preview.php?fromWF=1&ucn='+ d[r]['UCN'] + '&docid=' + d[r]['doc_id'] + '&isOrder=' + d[r]['isOrder'] +'">' + d[r][c] + '</a></td>';
		                  	}
		                  	else if(c == 'ReturnItemtoQueue'){
		                  		theRow += '<td class="' + headerInfo[indx]['cellClass'] + '" style="text-align:center"><a class="unfinish" data-doc_id="'+ d[r]['doc_id'] + '"><img src="/images/back_undo.png"/></a></td>';
		                  	}
		                  	else{
		                  		theRow += '<td class="' + headerInfo[indx]['cellClass'] + ' ' + headerInfo[indx]['class'] + '">' + d[r][c] + '</td>';
		                  	}

		                    row[indx] = theRow;
		                  }
		                }
		              }
		              rows.push(row); // add new row array to rows array
		            }
		            
		            var headerLength = headers.length;
		            headers = [];
		            for(i = 0; i < headerLength; i++){
		            	var theHeaderRow = "";
		            	if(headerInfo[i]['class'] == 'caseLink'){
		            		theHeaderRow += '<span class="' + headerInfo[i]['filter_type'] + '" data-placeholder="' + headerInfo[i]['filter_placeholder'] +'">' + headerInfo[i]['name'] + '</span>';
		            	}
		            	else{
		            		theHeaderRow += '<span class="' + headerInfo[i]['filter_type'] + ' ' + headerInfo[i]['class'] + headerInfo[i]['filter_placeholder'] +'">' + headerInfo[i]['name'] + '</span>';
		            	}
		            	
		            	//Not working
		            	//headers[i] = theHeaderRow;
		            	
		            	headers[i] = headerInfo[i]['name'];
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
	    
	    $('#deleted-reset').click(function(){
			$('table').trigger('filterReset').trigger('sortReset');
		    return false;
		});
	
		$(document).on('click','.unfinish',function() {
	    	var doc_id = $(this).data('doc_id');
	        
	        $('#dialogSpan').html("Are you sure you want to return this item to the workflow queue?");
			$('#dialogDiv').dialog({
				resizable: false,
				minheight: 150,
				width: 500,
				modal: true,
				title: 'Return Item to Workflow Queue',
				buttons: {
					"Yes": function() {
						{literal}
							$.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait </h1>', fadeIn: 0});
			                $.ajax({
			                    url: "/workflow/unfinish.php",
			                    type: 'POST',
			                    data: {doc_id : doc_id},
			                    success: function(data) {
			                        window.location.reload();
			                    }
			                });
			            {/literal}
						return true;
					},
					"No": function() {
						$(this).dialog( "close" );
						return false;
					}
				}
			});
		});
	});
</script>
<div style="padding:1%">
	{if $deleted|@count > 0}
	<div>
        <button id="deleted-reset">Reset Sort/Filters</button>
    </div>
	<table id="deletedItems" style="width:100%">
	    <thead>
	    	<tr class="tablesorter-ignoreRow">
		      <td class="pager" colspan="7">
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
	            <th style="min-width:10em" data-placeholder="Part of Case #">UCN</th>
	            <th data-placeholder="Part of Case Style">Case Style</th>
	            <th data-placeholder="Part of Title">Title</th>
	            <th class="filter-select">Creator</th>
	            <th class="filter-select">Creation Date</th>
	            <th class="filter-select">Deletion Date</th>
	            <th data-placeholder="Part of Comment">Comments</th>
	            <th class="filter-false">Return Item to Queue</th>
	        </tr>
	    </thead>
	    <tbody>
	    
	    </tbody>
	</table>
	{else}
		No deleted items were found for this queue.
	{/if}
</div>