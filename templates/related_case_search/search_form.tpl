<script type="text/javascript">
	{literal}
		$(document).ready(function(){
			$(".processRelatedSearch").click(function(event){
				event.preventDefault();
			    var pane = $(this).closest('.caseTab');
			    var casenum = $(pane).find('.ucn').val();
			    var parties = {};
			    var count = 0;
			    
			    $("#other").val($("#otherParty").val());
			    
			    $('#checkboxes input:checked').each(function() {
			    	parties[count] = {}

			    	if($(this).attr('id') == "other"){
			    		var name = $(this).val();
			    		var res = name.split(" ");
			    		
						if(name[2] != null && (typeof(name[2]) != "undefined")){
							parties[count]['first_name'] = res[0];
					    	parties[count]['middle_name'] = res[1];
					    	parties[count]['last_name'] = res[2];
						}
						else if(res[2] == null || (typeof(res[2]) == "undefined") && (res[1] != null || (typeof(res[1]) != "undefined"))){
							parties[count]['first_name'] = res[0];
					    	parties[count]['middle_name'] = "";
					    	parties[count]['last_name'] = res[1];
						}
						else{
							parties[count]['first_name'] = "";
					    	parties[count]['middle_name'] = "";
					    	parties[count]['last_name'] = res[0];
						}
			    				
				    	parties[count]['dob'] = "";
			    	}
			    	else{
			    		parties[count]['first_name'] = $(this).attr('data-first');
				    	parties[count]['middle_name'] = $(this).attr('data-middle');
				    	parties[count]['last_name'] = $(this).attr('data-last');
				    	parties[count]['dob'] = $(this).attr('data-dob');
			    	}
			    	
			    	count++;
			    });
			    
			    $("#searchTheseParties").val(JSON.stringify(parties));
			    
			    if(count == 0){
			    	$('#dialogSpan').html("Please select a party to find related cases.");
                    $('#dialogDiv').dialog({
                        resizable: false,
                        minheight: 150,
                        width: 500,
                        modal: true,
                        title: 'No Parties Selected',
                        buttons: {
                            "OK": function() {
                                $(this).dialog( "close" );
                                return false;
                            }
                        }
                    });
                    
                    return false;
			    }
			    
			    
				$("#searchForm").submit();
			});
		});
	{/literal}
</script>
<h1>Find Related Cases for Parties</h1>
<br/>
<div id="dialogSpan"></div>
<div id="checkboxes">
	<form action="search.php" method="post" id="searchForm">
		{foreach $partyList as $c}
			{if !empty($c['LastName']) && !empty($c['FirstName'])}
				{$search = $c['LastName']|cat:", "|cat:$c['FirstName']} 
			{else}
				{$search = $c['LastName']}
			{/if}
			<input type="checkbox" name="parties[]" data-first="{$c['FirstName']}" data-middle="{$c['MiddleName']}" data-last="{$c['LastName']}" data-dob="{$c['DOB']}"/> 
			{$c['PartyTypeDescription']} {$c['FirstName']} {$c['MiddleName']} {$c['LastName']} <br/>
		{/foreach}
		<input type="checkbox" id="other" /> Other <input type="text" name="otherParty" id="otherParty" />
		<input type="hidden" id="searchTheseParties" name="searchTheseParties" value=""/>
		<input type="hidden" id="ucn" name="ucn" value="{$ucn}"/>
		<br/>
		<button class="processRelatedSearch">Search</button>
	</form>	
</div>