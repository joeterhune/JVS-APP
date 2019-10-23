{if $orderfields|@count == 0}
<div class="row">
	<div class="col-md-12">
		There are no form fields to fill in.  Please click Edit Document to preview the order.
	</div>
</div>
{/if}

<script type="text/javascript">
	function toggleField(parent, value){
		var values = value.split("|");
		
		$("#formdiv :visible").each(function() {
		    if($(this).attr('data-tl_parent') == parent){
		    	$(this).val("");
		    	$(this).hide();
		    }
		});
		
		for(var i = 0; i < values.length; i++){
			values[i] = values[i].replace(/[^a-zA-Z0-9]+/g, '');
			
			var inputVal = $("input[name='"+parent+"']").val();
			if(inputVal){
				inputVal = inputVal.replace(/[^a-zA-Z0-9]+/g, '');
			}
			else{
				inputVal = "";
			}
			
			var selectVal = $("select[name='"+parent+"']").val();
			if(selectVal){
				selectVal = selectVal.replace(/[^a-zA-Z0-9]+/g, '');
			}
			else{
				selectVal = "";
			}

			if($("input[name='"+parent+"']").attr('type') != 'checkbox'){
				if((inputVal == values[i]) || (selectVal == values[i])){
					$(".show-" + parent + "-" + values[i]).show();
					if($(".show-" + parent + "-" + values[i] + " option").length){
						$(".show-" + parent + "-" + values[i] + " option").show();
					}
				}
				else{
					$(".show-" + parent + "-" + values[i]).hide();
				}
			}
			else{
				if($("input[name='"+parent+"']").is(":checked")){
					$(".show-" + parent + "-" + values[i]).show();
					if($(".show-" + parent + "-" + values[i] + " option").length){
						$(".show-" + parent + "-" + values[i] + " option").show();
					}
				}
				else{
					$(".show-" + parent + "-" + values[i]).hide();
				}
			}
		}
	}
	$(document).ready(function (){
		{foreach $orderfields as $ofld}
			{if !empty($ofld.trigger_parent_field)}
			
				var attr = $("select[name='{$ofld.trigger_parent_field}']").attr('onchange');
				var trigger_parent_value = "{$ofld.trigger_parent_value}";
				trigger_parent_value = trigger_parent_value.replace(/[^a-zA-Z0-9]+/g, '');
				
				if(typeof attr !== typeof undefined && attr !== false){
					var start_pos = attr.indexOf(',') + 2;
					var end_pos = attr.indexOf(')', start_pos);
					var current_val = attr.substring(start_pos, end_pos);
					current_val = current_val.replace(/[^a-zA-Z0-9|]+/g, '');
					
					$("input[name='{$ofld.trigger_parent_field}']").attr("onchange", "toggleField('{$ofld.trigger_parent_field}', '" + current_val + "|" + trigger_parent_value + "')");
					$("select[name='{$ofld.trigger_parent_field}']").attr("onchange", "toggleField('{$ofld.trigger_parent_field}', '" + current_val + "|" + trigger_parent_value + "')");
				}
				else{
					$("input[name='{$ofld.trigger_parent_field}']").attr("onchange", "toggleField('{$ofld.trigger_parent_field}', '" + trigger_parent_value + "')");
					$("select[name='{$ofld.trigger_parent_field}']").attr("onchange", "toggleField('{$ofld.trigger_parent_field}', '" + trigger_parent_value + "')");
				}
				
				
				//Select only?  Also need inputs?
				var values = $("input[name='{$ofld.trigger_parent_field}']").val();
				if(values != "" && (typeof value != 'undefined')){
					values = values.split("|");
					
					for(var i = 0; i < values.length; i++){
						if(values[i] == trigger_parent_value){
							$(".show-{$ofld.trigger_parent_field}-" + trigger_parent_value).show();
						}
						else{
							$(".show-{$ofld.trigger_parent_field}-" + trigger_parent_value).hide();
						}
					}
				}
				else{
					$(".show-{$ofld.trigger_parent_field}-" + trigger_parent_value).hide();
				}
				
				var values = $("select[name='{$ofld.trigger_parent_field}']").val();
				if(values != "" && (typeof value != 'undefined')){
					values = values.split("|");
					for(var i = 0; i < values.length; i++){
						if(values[i] == trigger_parent_value){
							$(".show-{$ofld.trigger_parent_field}-" + trigger_parent_value).show();
							
							if($(".show-{$ofld.trigger_parent_field}-" + trigger_parent_value + " option").length){
								$(".show-{$ofld.trigger_parent_field}-" + trigger_parent_value + " option").show();
							}
						}
						else{
							$(".show-{$ofld.trigger_parent_field}-" + trigger_parent_value).hide();
						}
					}
				}
				else{
					$(".show-{$ofld.trigger_parent_field}-" + trigger_parent_value).hide();
				}
				
				{if isset($saved_form_data[$ofld.trigger_parent_field]) && !empty($saved_form_data[$ofld.trigger_parent_field])}
					{assign var="filteredValue" value=$saved_form_data[$ofld.trigger_parent_field]|regex_replace: '/[^a-zA-Z0-9]+/' : ''}
					$(".show-{$ofld.trigger_parent_field}-{$filteredValue}").show();
				{/if}
			{/if}
		{/foreach}
	});
</script>
<style type="text/css">
	textarea.form-control {
	  height: 100% !important;
	}
</style>

    {foreach $orderfields as $ofld}
    {$fldcode = $ofld.field_code}
    {if !empty($ofld.trigger_parent_field)}
    	{$trigger_parent_value = $ofld.trigger_parent_value}
    	{$trigger_parent_value = $trigger_parent_value|regex_replace:"/[^A-Za-z0-9]/":""}
    	
    	{$show = "style=\"display:none\""}
    	{$showClass = "show-"|cat:$ofld.trigger_parent_field|cat:"-"|cat:$trigger_parent_value}
    {else}
    	{$show = ""}
    	{$showClass = ""}
    {/if}
    {if $ofld.field_type == "LABEL"}
    	<div class="form-group form-group-sm col-sm-12 {$showClass}" {$show} data-tl_parent="{$ofld.top_level_parent}">
        	<label for="{$ofld.field_code}" class="control-label col-sm-3 col-md-4 col-lg-5 pull-left {$showClass}" {$show} data-tl_parent="{$ofld.top_level_parent}">{$ofld.field_description}</label>
		</div>
    {else if ($ofld.field_type != "BUILTIN") && ($ofld.field_type != "ESIG")}
		<div class="form-group form-group-sm col-sm-12 {$showClass}" {$show} data-tl_parent="{$ofld.top_level_parent}">
        <label for="{$ofld.field_code}" class="control-label col-sm-3 col-md-4 col-lg-5 pull-left {$showClass}" {$show} data-tl_parent="{$ofld.top_level_parent}">{$ofld.field_description}</label>
		<div class="col-sm-6">
        {if $ofld.field_code == 'event_date'}
		<div class="input-group col-md-6 {$showClass}" {$show} data-tl_parent="{$ofld.top_level_parent}">
			<input type="text" class="datepicker form-control {$showClass}" name="{$ofld.field_code}" value="{$saved_form_data[$fldcode]}" {$show} data-tl_parent="{$ofld.top_level_parent}">
		</div>
        {else if $ofld.field_type == 'DATE'}
		<div class="input-group date col-md-6 {$showClass}" {$show} data-tl_parent="{$ofld.top_level_parent}">
			<input type="text" class="datepicker form-control {$showClass}" name="{$ofld.field_code}" value="{$saved_form_data[$fldcode]}" {$show} data-tl_parent="{$ofld.top_level_parent}">
			
		</div>
		{else if $ofld.field_code == 'event_time' || ($ofld.field_type == 'TIME')}
			<div class="col-sm-6 {$showClass}" {$show} data-tl_parent="{$ofld.top_level_parent}">
	            <div class="form-group">
	                <div class="input-group date timepicker {$showClass}">
	                    <input type="text" class="form-control {$showClass}" name="{$ofld.field_code}" value="{$saved_form_data[$fldcode]}" {$show} data-tl_parent="{$ofld.top_level_parent}" />
	                    <span class="input-group-addon {$showClass}" {$show} data-tl_parent="{$ofld.top_level_parent}">
	                        <span class="glyphicon glyphicon-time"></span>
	                    </span>
	                </div>
	            </div>
	        </div>
		 {else if $ofld.field_type == 'NUMBER'}
			<div class="input-group col-md-3 time {$showClass}" {$show} data-tl_parent="{$ofld.top_level_parent}">
				<input type="number" class="form-control {$showClass}" name="{$ofld.field_code}" value="{$saved_form_data[$fldcode]}" {$show} data-tl_parent="{$ofld.top_level_parent}">
			</div>
		{else if $ofld.field_type == 'TEXTAREA'}
			<div class="input-group col-md-8 {$showClass}" {$show} data-tl_parent="{$ofld.top_level_parent}">
				<textarea type="number" rows="10"  class="form-control {$showClass}" name="{$ofld.field_code}" wrap="hard" {$show} data-tl_parent="{$ofld.top_level_parent}">{$saved_form_data[$fldcode]}</textarea>
			</div>
        {else if $ofld.field_type == 'CHECKBOX'}
			<input type="checkbox" class="{$showClass}" name="{$ofld.field_code}" title="{$ofld.field_description}" {if $saved_form_data[$fldcode]== 1}checked="checked"{/if} value=1 {$show} data-tl_parent="{$ofld.top_level_parent}">
        {else if $ofld.field_type == 'SELECT'}
        	{if $ofld.field_code == "magistrate"}
        		<div class="col-md-8 {$showClass}" {$show} data-tl_parent="{$ofld.top_level_parent}">
	            <select class="form-control {$showClass}" style="margin-left:-15px" name="{$ofld.field_code}" data-tl_parent="{$ofld.top_level_parent}">
	            	 {foreach $magistrates as $m}
	            	 	<option value="{$m}" {$show} {if isset($saved_form_data[$fldcode]) && ($saved_form_data[$fldcode] == $m)}selected="selected"{else if $ofld.field_default == $m}selected="selected"{/if}>{$m}</option>
	            	 {/foreach}
	            </select>
				</div>
			{else if $ofld.field_code == "newmagistrate"}
        		<div class="col-md-8 {$showClass}" {$show} data-tl_parent="{$ofld.top_level_parent}">
	            <select class="form-control {$showClass}" style="margin-left:-15px" name="{$ofld.field_code}" data-tl_parent="{$ofld.top_level_parent}">
	            	 {foreach $magistrates as $m}
	            	 	<option value="{$m}" {$show}  {if isset($saved_form_data[$fldcode]) && ($saved_form_data[$fldcode] == $m)}selected="selected"{else if $ofld.field_default == $m}selected="selected"{/if}>{$m}</option>
	            	 {/foreach}
	            </select>
				</div>	
			{else if $ofld.field_code == "ufcCaseManager"}
        		<div class="col-md-8 {$showClass}" {$show} data-tl_parent="{$ofld.top_level_parent}">
	            <select class="form-control {$showClass}" style="margin-left:-15px" name="{$ofld.field_code}" data-tl_parent="{$ofld.top_level_parent}">
	            	 {foreach $ufc_cm_names as $u}
	            	 	<option value="{$u}" {$show} {if isset($saved_form_data[$fldcode]) && ($saved_form_data[$fldcode] == $u)}selected="selected"{else if $ofld.field_default == $u}selected="selected"{/if}>{$u}</option>
	            	 {/foreach}
	            </select>
				</div>
			{else if $ofld.field_code == "PetAndRespAddresses"}
        		<div class="col-md-8 {$showClass}" {$show} data-tl_parent="{$ofld.top_level_parent}">
	            <select class="form-control {$showClass}" style="margin-left:-15px" name="{$ofld.field_code}" data-tl_parent="{$ofld.top_level_parent}">
	            	 {foreach $addresses as $key => $a}
	            	 	<option value="{$key}" {$show} {if isset($saved_form_data[$fldcode]) && ($saved_form_data[$fldcode] == $key)}selected="selected"{else if $ofld.field_default == $key}selected="selected"{/if}>{$a}</option>
	            	 {/foreach}
	            </select>
				</div>
			{else if $ofld.field_code == "PetAndRespFilerName"}
        		<div class="col-md-8 {$showClass}" {$show} data-tl_parent="{$ofld.top_level_parent}">
	            <select class="form-control {$showClass}" style="margin-left:-15px" name="{$ofld.field_code}" data-tl_parent="{$ofld.top_level_parent}">
	            	 {foreach $names as $key => $n}
	            	 	<option value="{$key}" {$show} {if isset($saved_form_data[$fldcode]) && ($saved_form_data[$fldcode] == $key)}selected="selected"{else if $ofld.field_default == $key}selected="selected"{/if}>{$n}</option>
	            	 {/foreach}
	            </select>
				</div>
			{else if $ofld.field_code == "PetAndRespRespondingName"}
        		<div class="col-md-8 {$showClass}" {$show} data-tl_parent="{$ofld.top_level_parent}">
	            <select class="form-control {$showClass}" style="margin-left:-15px" name="{$ofld.field_code}" data-tl_parent="{$ofld.top_level_parent}">
	            	 {foreach $names as $key => $n}
	            	 	<option value="{$key}" {$show} {if isset($saved_form_data[$fldcode]) && ($saved_form_data[$fldcode] == $key)}selected="selected"{else if $ofld.field_default == $key}selected="selected"{/if}>{$n}</option>
	            	 {/foreach}
	            </select>
				</div>
        	{else}
				<div class="col-md-8 {$showClass}" {$show}>
	            <select class="form-control {$showClass}" style="margin-left:-15px" name="{$ofld.field_code}" data-tl_parent="{$ofld.top_level_parent}">
	                {$vals = $ofld.field_values}
	                {assign var="selopts" value="\r\n"|explode:$vals}
	                {foreach $selopts as $selopt}
	                	<option  value="{$selopt}" 
	                		{if $saved_form_data[$fldcode] == $selopt}
	                			selected="selected"
	                		{else if $ofld.field_default == $selopt}
	                			selected="selected"
	                		{/if} {$show}>
	                		{$selopt}
	                	</option>
	                {/foreach}
	            </select>
				</div>
			{/if}
		{else if $ofld.field_code == 'courtroom'}
			<div class="input-group col-md-3 time {$showClass}" {$show} data-tl_parent="{$ofld.top_level_parent}">
				<input type="text" class="form-control {$showClass}" name="{$ofld.field_code}" value="{$saved_form_data[$fldcode]}" {$show} data-tl_parent="{$ofld.top_level_parent}">
			</div>
        {else if $ofld.field_type == 'TEXT'}
			<input type="text" class="form-control col-sm-4 col-md-6 col-lg-8 {$showClass}" name="{$fldcode}"  value="{$saved_form_data[$fldcode]}" {$show} data-tl_parent="{$ofld.top_level_parent}"/>
			
			{if $ofld.field_code == "Event Location"}
            <label for="{$ofld.field_code}" class="control-label col-sm-2 {$showClass}" {$show} data-tl_parent="{$ofld.top_level_parent}">Event Courthouse:</label>
                <select class="chaddress" name="courthouse_address" {$show} data-tl_parent="{$ofld.top_level_parent}">
                    {foreach from=$chaddress  key=ch item=addr}
                    <option value="$addr" {if isset($saved_form_data[$fldcode]) && ($saved_form_data[$fldcode] == $addr)}selected="selected"{else if $ofld.field_default == $addr}selected="selected"{/if}>$ch</option>
                    {/foreach}
                </select>
            
			{/if}
			</div>
        {/if}
		</div></div>
    {/if}
    {/foreach}

<input type="hidden" class="docket_line_text" name="docket_line_text" value="{$dockline}"/>
<input type="hidden" class="form_id" name="form_id" value="{$formid}"/>
<input type="hidden" class="form_name" name="form_name" value="{$formname}"/>
<input type="hidden" class="mailedby" name="mailedby" value="{$formdata.mailedby}"/>
<input type="hidden" class="efiledby" name="efiledby" value="{$formdata.efiledby}"/>
<input type="hidden" class="efiledid" name="efiledid" value="{$formdata.efiledid}"/>
<!--# now add the field to hold the html for the resulting order...-->
