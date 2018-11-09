{if isset($filingdate)}
	<div>
		<p>
			<span style="color: red">ATTENTION: </span>These documents replace documents sent in this case on {$filingdate}.
		</p>

		<ol>
			<li>
				The original order received was never filed because of a document error.
			</li>
			<li>
				The new order replaces the first order you received.
			</li>
		</ol>
	</div>
{/if}

<ul>
	<li>
		This email is from the Fifteenth Judicial Circuit
	</li>
	<li>
		Case Number:  {$ucn}
	</li>
	<li>
		{$casestyle}
	</li>
	<li>
		Orders Attached:
		<ul>{foreach $orders as $order}
			<li>{$order.filedesc} ({$order.shortname})</li>{/foreach}
		</ul>
	</li>
	{if isset($division)}
	<li>
		Division {$division}, {$divphone}
	</li>
	{/if}
</ul>
<br/>

{if isset($addlcomments)}
<b>Additional comments:</b>
<br/>
<br/>
{$addlcomments}
{/if}

<p>
	In accordance with the 15th Judicial Circuit's Administrative Order 2.310-4/13, please ensure that
	primary and secondary email addresses are registered with Court Administration at
	<a href="https://e-services.co.Sarasota-beach.fl.us/scheduling/">https://e-services.co.Sarasota-beach.fl.us/scheduling/</a>.
</p>
<p>
	For a better translation of this document, contact
	<a href="mailto:CAD-ADA@jud12.flcourts.org">CAD-ADA@jud12.flcourts.org</a>.
</p>
