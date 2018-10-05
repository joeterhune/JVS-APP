
<div class="container" style="padding:20px;" >
<div class="row">
<div class="col-md-12">
    <div>
        Order for <span style="font-weight: bold">{$ucn}</span>&nbsp;
		Division: <span style="font-weight: bold">{$DivisionID}</span>
    </div>
    <div class="row" style="margin-bottom:15px;">
    <div class="input-group">
        {if !isset($formid)}
        {$formid = -999}
        {/if}
        {if $forms|@count > 0}
        {$single = ($forms|@count == 1)}
        Use Form:
        <select class="formid">
            {if !$single}
            <option value="" selected="selected">
                Select
            </option>
            {/if}
            {foreach $forms as $form}
				{assign var="div_checks" value=","|explode:$form.case_div}
					{foreach from=$div_checks item=div_check}
				
						{if   $div_check == "" ||
							( (strpos($div_check, '!')===false ) && $div_check == $DivisionID ) ||
							( (strpos($div_check, '!')!==false ) && ($div_check != $DivCheck ) ) }
							<option value="{$form.form_id}" {if ($single) || ($form.form_id == $formid)}selected="selected"{/if}>
								{$form.form_name}
							</option>
						{/if}
					{/foreach}
            {/foreach}
        </select>
		
        {else}
        <span style="color: red">No forms available for this case type.</span>
        {/if}
    </div>
	</div>
    <div class="container-fluid">
		<div class="row" style="max-height:550px; height:80%; overflow-y:auto;">
		<div class="col-md-12">
			<form class="formdiv form-horizontal" autocomplete="on"></form>
			
		</div>
		</div>
	</div>
		<div class="row" style="margin-top:20px;">
		<div class="col-md-2">
			<button data-type="preview" class="btn btn-success btn-xl xmlbutton previewbutton pull-right" type="submit"><i class="fa fa-eye"></i> Preview Order</button>
		</div>
		</div>
</div>
</div>
</div>
<script type="text/javascript">
$('#orderDiv-{$ucn}').ready(function () {
    OrderDisplayFields('#orderDiv-{$ucn}'); // display the form fields for this form
    $(".formid").change(function () {
        OrderDisplayFields('#orderDiv-{$ucn}')
    });
});
</script>

