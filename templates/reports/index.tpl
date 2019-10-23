<script src="/javascript/chartjs/Chart.bundle.js"></script>
<script src="/javascript/chartjs/utils.js"></script>
<script type="text/javascript">
	$(document).ready(function (){
	    {foreach $allGraphs as $divGraphs}
	    	{foreach $divGraphs.graphArr as $graphType => $data}
	    		{$data}
	    	{/foreach}
	    {/foreach}
    });
    
    function showDivRpt(division,month,divtype,rpttype,range,lop) {
		var url = "/reports/div_list.php?divname=" + division + "&type=" + divtype + "&rpttype=" + rpttype + "&yearmonth=" + month;
	    
	    if (lop != undefined) {
	    	url += "&lop=1";
	    }
	    window.location.href = url;
	    return false;
    }
</script>

<div style="float: right">
    <a class="helpLink" data-context="graphs">
        <img class="toolbarBtn" style="height: 20px !important; width: 20px;" alt="Help" title="Help" src="/images/help_icon.png">
    </a>
</div>

{foreach $allGraphs as $divGraphs}
<div id="graphDiv_{$divGraphs.div}" style="float: none; clear: both; margin-top: 2em">
    <p style="font-face: bold; font-size: 120%">{$divGraphs.divType} Division {$divGraphs.div} Reports</p>
    {foreach $divGraphs.graphArr as $graphType => $data}
    	<!--<div id="{$graphType}ChartDiv-{$divGraphs.div}" style="float: left; margin-right: 50px; width: 350px; height: 300px;"></div>-->
    	<div style="float: left; margin-right: 25px; width: 450px; height: 400px;">
    		<canvas id="{$graphType}ChartjsDiv-{$divGraphs.div}"></canvas>
    	</div>
    {/foreach}
</div>
<br style="clear: both"/>
<br style="clear: both"/>
{/foreach}