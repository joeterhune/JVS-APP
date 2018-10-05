// REQUIRES jQuery!!!

function doCalSort(tableID) {
    //debugger;
    tableSel = '#' + tableID + '-listTable';
    pagerSel = '#' + tableID + '-pager';
    
    $(tableSel).tablesorter({
        widgets: ['saveSort', 'zebra','filter'],
        sortList: [[3,0],[4,0]],
        widgetOptions: {
            filter_columnFilters: true,
            filter_saveFilters: true,
            filter_reset : '.' + tableID + '-reset'
        }
    });
    $(tableSel).tablesorterPager({container: $(pagerSel), positionFixed: false, size: 1000 });
}

function countCalRows(tableID) {
    //debugger;
    // Count the rows displayed, and show it in the table header.
    tableSel = '#' + tableID + '-listTable';
    
    var displayedEvents = 0;
    var rows = $(tableSel).find('.eventRow');
    $(tableSel).find('.eventRow').each(function (i,e) {
        if ($(e).css('display') != 'none') {
            displayedEvents += 1;
        }
    });
    
    var rowWord = " Rows";
    if (displayedEvents == 1) {
        rowWord = " Row"
    }
    
    $('#' + tableID + '-eventcount').html(displayedEvents + rowWord);
}