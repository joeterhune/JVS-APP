<div style="padding-left:1%">
	<div style="float: right">
	    <a class="helpLink" data-context="divreport">
	        <img class="toolbarBtn" style="height: 20px !important; width: 20px;" alt="Help" title="Help" src="/images/help_icon.png">
	    </a>
	</div>
	
	<div class="h1">
	    Cases for HON. {$judgeName}
	</div>
	
	{if (isset($rptdate))}
	{$rptdate}
	{/if}
	
	<div id="thetable" style="margin-top: 20px">
	    <table>
	        <tr>
	            <td colspan=2 style="background-color: #428bca;">
	                <div class="h2" style="color:#FFFFFE">
	                    Divisions
	                </div>
	
	                {foreach $divList as $div}
	                <tr>
	                    <td style="width: 270px; background-color: #FFFFFE">
	                        <span class="rptlabel">
	                            <a href="gensumm.php?rpath=/Palm/{$div.divType}/div{$div.divName}/index.txt&divName={$div.divName}">
	                                {$div.divDesc} Division {$div.divName}
	                            </a>
	                        </span>
	                    </td>
	                    
	                    <td style="width: 45px; background-color: #FFFFFE; text-align: right">
	                        <span class="rptnum">{$div.total_num}</span>
	                    </td>
	                </tr>
	                {/foreach}
	            </td>
	        </tr>
	    </table>
	</div>
</div>