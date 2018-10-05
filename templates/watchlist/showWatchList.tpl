<script type="text/javascript">
$('#wlResultDiv').ready(function () {
	$('#wlResultDiv').on('click','.wfCbCheck',function() {
        var checkProp = $(this).data('checkprop');
        $('#watchListTable').find('.wlRemoveCheck').prop('checked',checkProp);
        return true;
    });
    
    $('.removeFromWatchList').unbind('click');
    $('#wlResultDiv').on('click','.removeFromWatchList', function() {
        var wlChecked = $('.wlRemoveCheck:checked');
        
        if (wlChecked.length == 0) {
            showDialog('No Cases Selected','No cases were selected for removal from the watchlist.');
            return false;
        }
        
        var remove = [];
        $(wlChecked).each(function (i,e) {
            remove.push($(e).data('casenum'));
        });
        
        var removeCases = remove.join(",");
        
        {literal}var postData = {removeCases: removeCases};{/literal}
        var url = "/watchlist/bulkWlRemove.php";
        
        $.ajax({
            url: url,
            data: postData,
            async: false,
            success: function(data) {
                var hide = data.removed;
                for (i=0; i < hide.length; i++) {
                    var cn = hide[i];
                    $('#wlRow-' + cn).hide();
                }
                // Are there any left?
                var remaining = $('.wlRow:visible').length;
                if (remaining == 0) {
                    $('#wlResultDiv').html('There are currently no cases on your watch list.');
                }
                return false;
            }
        })
        
        return false;
    });
});
</script>

<div class="container-fluid">

    <div class="h1" style="text-align: left; margin-top: 10px; font-weight: bold">
        My Case Watchlist
    </div>
    
    <div id="wlResultDiv">
        {if $watchList|@count > 0}
        <table id="watchListTable">
            <thead>
                <th>Case Number</th>
                <th>Case Style</th>
                <th>
                    Remove
                    <br/>
                    <a class="wfCbCheck" data-checkprop="1">Select All</a>
                    <a class="wfCbCheck" data-checkprop="0">Unselect All</a>
                </th>
            </thead>
            
            <tbody>
                {foreach $watchList as $case}
                <tr id="wlRow-{$case.CaseNumber}" class="wlRow">
                    <td style="width: 15em"><a class="caseLink" data-casenum="{$case.CaseNumber}">{$case.CaseNumber}</a></td>
                    <td style="width: 30em">{$case.CaseStyle}</td>
                    <td style="text-align: center"><input type="checkbox" class="wlRemoveCheck" data-casenum="{$case.CaseNumber}"></td>
                </tr>
                {/foreach}
                
                <tr>
                    <td colspan="3">
                        <button type="button" class="btn btn-primary removeFromWatchList">
                           <i class="fa fa-trash-o"></i> Remove Selected Cases from Watchlist
                        </button>
                    </td>
                </tr>
            </tbody>
        </table>
        {else}
        There are currently no cases on your watch list.
        {/if}
    </div>

</div>