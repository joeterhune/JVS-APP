
{if $archives|@count}
{foreach $archives as $month}
<a href="/reports/div_summ.php?divName={$divname}&type={$type}&yearmonth={$month.yearmonth}">{$month.words}</a><br>
{/foreach}
{else}
There were no older reports found for Division {$divname}.
{/if}