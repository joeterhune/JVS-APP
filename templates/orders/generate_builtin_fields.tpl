{foreach from=$data key=code item=val}
<input type="hidden" id="{$code}" name="{$code}" value="{$val}"/>
{/foreach}