<div style="padding-left:1%">
	<div style="float: right">
	    <a class="helpLink" data-context="divreport">
	        <img class="toolbarBtn" style="height: 20px !important; width: 20px;" alt="Help" title="Help" src="/images/help_icon.png">
	    </a>
	</div>
	
	<div class="h1">
	    {$county} County
	</div>
	
	<p class="instructions">
	    As of {$prettyDate}
	</p>
	<table id="gensumm_{$divName}">
	    <tr>
	        <td id="rptname_{$divName}" style="background-color: #428bca;">
	            <div class="h2" style="color:#FFFFFE">
	                {$divDesc} Division {$divName}
	            </div>
	            
	            <tr style="vertical-align: top">
	                <td>
	                    <table>
	                        {foreach $caseTypes as $caseType}
							<tr>
	                            {if isset($caseType.blank)}
	                            <td colspan="2">&nbsp;</td>
	                            {else}
	                            <td class="label1">
	                                <a href="/reports/div_list.php?type={$courttype}&divname={$divName}&rpttype={$caseType.rpttype}&yearmonth={$yearMonth}">
	                                    {$caseType.type}
	                                </a>
	                            </td>
	                            <td class="data1">
	                                {$caseType.count}
	                            </td>
	                            {/if}
	                        </tr>
	                        {/foreach}
	                    </table>
	                </td>
	            </tr>
	        </td>
	    </tr>
	</table>
	
	<p>
		&nbsp;
	</p>
	
	<p>
	    <a href="/reports/archive.php?type={$courttype}&div={$divName}">
	        Older Reports
	    </a>
	</p>
	
	<p>
	    <a href="/cgi-bin/casenotes/flaggedCaseSearch.cgi?div={$divName}">
	        Flagged Cases
	    </a>
	</p>
	
	<p>
	    <a href="/cgi-bin/calendars/showCal.cgi?div={$divName}">
	        Show Divisional Calendar
	    </a>
	</p>
</div>	