<div id="{$queueName}queue" class="tab-pane active wfqueue" class="tab-pane" data-queuename="{$queueName}" data-queuetitle="{$queueName}">	
	<input type="hidden" class="queuename" value="{$queueName}"/>	
	{if $cansign > 0}
    	<select name="signAs" class="signAs" style="display:none">
        	<option value="" selected="selected">Please select a signature to apply</option>
           	{foreach $esigs as $signame}
	        	{$sel = ""}
	            	{if ($cansign == 1)}
	                	{$sel = "selected=\"selected\""}
	                {/if}
	        	<option value="{$signame.user_id}" {$sel}>{$signame.fullname}</option>
	    	{/foreach}
		</select>
	{/if}
	{foreach from=$queueItems item=items}
		{* count the number that need signatures or efiling *}
        {$needsig = 0}
        {$needefile = 0}
        {if $item.esigned == 'N'}
            {$needsig = $needsig + 1}
        {/if}
        {if $item.efiled == 'N'}
        	{$needefile = $needefile + 1}
        {/if}
	{/foreach}
	{if $items|@count == 0}
    	{if $queueName == "my"}
        	{$msg = "No items in your Workflow Queue at this time."}
        {else}
        	{$msg = "No items in this Workflow Queue at this time."}
        {/if}
        <h3>{$msg}</h3>
        <button class="addToQueue btn btn-primary btn-sm" style="margin: 3px 5px 5px 0" data-queue="{$queueName}"><i class="fa fa-plus"></i> Add</button>
		<button class="showQFinished btn btn-primary btn-sm" style="margin: 3px 5px 5px 0" data-queue="{$queueName}"><i class="fa fa-eye"></i> Show Finished</button>
		<button class="showQDeleted btn btn-primary btn-sm" style="margin: 3px 5px 5px 0" data-queue="{$queueName}"><i class="fa fa-trash-o"></i> Show Deleted</button>
		
		{if $queueName == "my"}
			<button class="showQMyDocuments btn btn-primary btn-sm" style="margin: 3px 5px 5px 0" data-queue="{$queueName}"><i class="fa fa-file-text-o"></i> Show Documents I've Created</button>
			<button class="showQMyAuditLog btn btn-primary btn-sm" style="margin: 3px 5px 5px 0" data-queue="{$queueName}"><i class="fa fa-tasks"></i> Show My Activity Log</button>
		{/if}
		
        {if $qType == "div"}
			<button onclick="window.location.href='/workflow/show_ols_docs.php?division={$queueName}'" class="btn btn-primary btn-sm" style="margin: 3px 5px 5px 0"><i class="fa fa-file-text-o"></i> View OLS e-Courtesy</button>
		{/if}
	{else}
		{if $queueName == "my"}
			{$queueName = "myqueue"}
		{/if}
		{$resetClass = {$queueName}|cat:"-reset"}
		<div id="wf-columns">
			Show/Hide Columns: 
			<a id="TypeLink" class="hideCol" data-colname="Type">Type</a>&nbsp;
			<a id="AgreedLink" class="hideCol" data-colname="Agreed">Agreed</a>
			<a id="UCNLink" class="hideCol" data-colname="UCN">UCN</a>&nbsp;
			<a id="CaseStyleLink" class="hideCol" data-colname="CaseStyle">Case Style</a>&nbsp;
			<a id="FlaggedLink" class="hideCol" data-colname="Flagged">Flagged</a>&nbsp;
			<a id="TitleLink" class="hideCol" data-colname="Title">Title</a>&nbsp;
			<a id="CategoryLink" class="hideCol" data-colname="Category">Category</a>&nbsp;
			<a id="DueLink" class="hideCol" data-colname="Due">Due</a>&nbsp;
			<a id="CreatorLink" class="hideCol" data-colname="Creator">Creator</a>&nbsp;
			<a id="CreatedLink" class="hideCol" data-colname="Created">Created</a>&nbsp;
			<a id="EventTypeLink" class="hideCol" data-colname="EventType">Event Type</a>&nbsp;
			<a id="EventDateLink" class="hideCol" data-colname="EventDate">Event Date</a>&nbsp;
			<a id="DaysInQueueLink" class="hideCol" data-colname="DaysInQueue">Days in Queue</a>&nbsp;
			<a id="ESignedLink" class="hideCol" data-colname="ESigned">E-Signed</a>&nbsp;
			<!--<a id="EFiledLink" class="hideCol" data-colname="EFiled">E-Filed</a>&nbsp;-->
			<a id="TransferLink" class="hideCol" data-colname="Transfer">Transfer</a>&nbsp;
			<a id="ActionsLink" class="hideCol" data-colname="Actions">Actions</a>&nbsp;
			<a id="CommentsLink" class="hideCol" data-colname="Comments">Comments</a>
		</div>
		<button class="addToQueue btn btn-primary btn-sm" style="margin: 3px 5px 5px 0" data-queue="{$queueName}"><i class="fa fa-plus"></i> Add</button>
		<button class="showQFinished btn btn-primary btn-sm" style="margin: 3px 5px 5px 0" data-queue="{$queueName}"><i class="fa fa-eye"></i> Show Finished</button>
		<button class="showQDeleted btn btn-primary btn-sm" style="margin: 3px 5px 5px 0" data-queue="{$queueName}"><i class="fa fa-trash-o"></i> Show Deleted</button>
		
		{if $queueName == "myqueue"}
			
			<button class="showQMyDocuments btn btn-primary btn-sm" style="margin: 3px 5px 5px 0" data-queue="{$queueName}"><i class="fa fa-file-text-o"></i> Show Documents I've Created</button>
			<button class="showQMyAuditLog btn btn-primary btn-sm" style="margin: 3px 5px 5px 0" data-queue="{$queueName}"><i class="fa fa fa-tasks"></i> Show My Activity Log</button> 
		{/if}
		<button onclick="window.location.href='/workflow.php?queueName={$queueName}'" class="btn btn-primary btn-sm" style="margin: 3px 5px 5px 0" data-queue="{$queueName}"><i class="fa fa-refresh"></i> Refresh Queue</button>
		<button class= "{$resetClass} btn btn-primary btn-sm" style="margin: 3px 5px 5px 0" data-queue="{$queueName}"><i class="fa fa-retweet"></i> Reset Filters</button>
		
		{if $qType == "div"}
			<button onclick="window.location.href='/workflow/show_ols_docs.php?division={$queueName}'" class="btn btn-primary btn-sm" style="margin: 3px 5px 5px 0"><i class="fa fa-file-text-o"></i> View OLS e-Courtesy</button>
		{/if}
		<table id="wf_maintable_{$queueName}" class="qtable" data-qname="{$queueName}" style="width:100%">
			<thead>
				<tr class="tablesorter-headerRow">
					<th class="Type type filter-select" id="wfHeaderFirst">Type</th>
					<th class="Agreed agreed filter-select" data-placeholder="Select">Agreed</th>
					<th class="UCN ucn filter-match" data-placeholder="Part of case number">UCN</th>
					<th class="CaseStyle ucn filter-match" data-placeholder="Part of case style">Case Style</th>
					<th class="Flagged smallNum filter-select" data-placeholder="Select">Flagged</th>
					<th class="Title title filter-match" data-placeholder="Part of title">Title</th>
					<th class="Category category filter-select" data-placeholder="Select">Category</th>
					<th class="Due dateCol filter-select" data-placeholder="Select">Due</th>
					<th class="Creator creator filter-select" data-placeholder="Select">Creator</th>
					<th class="Created dateCol filter-select" data-placeholder="Select">Created</th>
					<th class="EventType filter-select" data-placeholder="Select">Event Type</th>
					<th class="EventDate dateCol filter-select" data-placeholder="Select">Event Date</th>
					<th class="DaysInQueue smallNum filter-select" data-placeholder="Select">Days<br/>in<br/>Queue</th>
					<th class="ESigned esigned cbCol filter-select" data-placeholder="Select">
						E-Signed
						<br/>
						{if $cansign > 0}
							<!--<button class="bulksign" data-queue="{$queueName}">Sign All Checked</button>
							<br/>
							<a class="wfAllCheck" data-targetclass="signCheck">Check All</a>-->
						{/if}
					</th>
					<!--<th class="EFiled esigned cbCol filter-select" data-placeholder="Select">
						E-Filed
						<br/>
						<button class="bulkefile" data-queue="{$queueName}">E-File All Checked</button>
						<br/>
						<a class="wfAllCheck" data-targetclass="fileCheck">Check All</a>
					</th>-->
					<th class="Transfer cbCol filter-select" data-placeholder="Select">
						Transfer
						<br/>
						<button class="bulkxfer" data-queue="{$queueName}">Transfer All Checked</button>
						<br/>
						<a class="wfAllCheck" data-targetclass="xferCheck">Check All</a>
					</th>
					<th class="Actions actions filter-false">Actions</th>
					<th class="Comments comments filter-match" data-placeholder="Part of comment">Comment</th>
				</tr>
			</thead>
			<tbody>
				{foreach $queueItems as $item}
					{$docLinkClass = "docLink"}
	                {if $item.doc_type == "Task"}
	                	{$docLinkClass = "notesAttach"}
	                {/if}
					<tr class="{$item.doc_type} wfTableRow" id="doc-{$item.doc_id}">
						<td class="Type type {$item.doc_type}">{$item.doc_type}</td>
						<td class="Agreed agreed {$item.doc_type}">
							{if $item.agreed == "N"}
				            	<span class="bad">{$item.agreed}</span>
				            {else if $item.agreed == "Y"}
				            	<span class="good">{$item.agreed}</span>
			                {else}
				                 &nbsp;
			                {/if}
						</td>
						<td class="UCN {$item.doc_type}">
							<a class="caseLink" data-casenum="{$item.ucn}" href="/cgi-bin/search.cgi?name={$item.ucn}">
								{$item.ucn}
							</a>
						</td>
						<td class="CaseStyle {$item.doc_type}">
							{$item.case_style}
						</td>
						<td class="Flagged {$item.doc_type}"><div class="{if $item.flagged == 'Y'}flagIcon{/if} hideThis">{$item.flagged}</div></td>
						<td class="Title {$item.doc_type}">
							<a class="{$docLinkClass}" {if $docLinkClass == "docLink"}href="/orders/preview.php?fromWF=1&ucn={$item.ucn}&docid={$item.doc_id}{if $item.doc_type == 'IGO'}&isOrder=1{else}&isOrder=0{/if}"{else}data-docid={$item.doc_id} data-casenum={$item.ucn}{/if}>{$item.title}</a>
							{getSuppDocs doc_id={$item.doc_id} assign="suppDocs"}
		                   	{if !empty($suppDocs)}
		                    	<br/>
		                   		<a href="#\" class="showAttachments" data-id="{$item.doc_id}" style="color:blue"><strong>View Attachments</strong></a>
		                   		<div id="attachments_{$item.doc_id}" style="display:none; text-align:left;color:blue">
		                   			{$aCount = 1}
		                   			{foreach from=$suppDocs item=d}
			                   			{$aCount}. <a href="{if !$d['jvs_doc']}{$olsURL}/{/if}{$d['file']}" target="_blank" style="color:blue">{$d['document_title']}</a><br/>
			                   			{$aCount = $aCount + 1}
			                   		{/foreach}
		                   		</div>
		                   	{/if}
						</td>
						<td class="Category category {$item.doc_type}"><div class="wfcircle" style="background:{$item.color}; float: left"></div> {$item.color}</td>
						<td class="Due dateCol {$item.dueDateClass} {$item.doc_type}">{$item.due_date}</td>
						<td class="Creator {$item.doc_type}">{$item.creator}</td>
						<td class="Created dateCol {$item.doc_type}">{$item.creation_date}</td>
						<td class="EventType {$item.doc_type}">{$item.event_name}</td>
						<td class="EventDate dateCol {$item.doc_type}">{$item.event_date}</td>
						<td class="DaysInQueue smallNum {$item.doc_type}">{$item.Age}</td>
						<td class="ESigned esigStat {$item.doc_type}">
			                {if $item.esigned == 'N'}
			                    {if $cansign && ($item.doc_type == "IGO" || ($item.doc_type == "DVI"))}
			                    	<!--<input type="checkbox" class="signCheck" value="{$item.doc_id}"/>-->
			                    	<span class="bad">N</span>
			                    {else}
			                    	<span class="bad">N</span>
			                    {/if}
			                {else}
			                    <span class="good">Y</span>
			                {/if}
						</td>
						<!--<td class="EFiled efileStat {$item.doc_type}">
							{if $item.efiled == 'N'}
			                    {if $item.esigned == "N" || empty($item.signed_filename)}
				                    <span class="bad">{$item.efiled}</span>
			                    {else}
				                    <input type="checkbox" class="fileCheck" value="{$item.doc_id}" data-casenum="{$item.ucn}" data-pdf="/tmp/{$item.signed_filename}" data-doc_id="{$item.doc_id}"/>
			                    {/if}
			                {else if $item.efiled == 'PQ'}
			                    <span class="bad">{$item.efiled}</span>
			                {else}
			                	<span class="good">{$item.efiled}</span>
			                {/if}
						</td>-->
						<td class="Transfer {$item.doc_type}"><input type="checkbox" class="xferCheck" value="{$item.doc_id}"/></td>
						<td class="Actions {$item.doc_type}">
							{if $item.esigned == 'N'}
			                    {if $cansign && ($item.doc_type == "IGO" || ($item.doc_type == "DVI"))}
			                    	<!--<button class="{$item.doc_type} sigBtn" data-ucn="{$item.ucn}" data-doc_id="{$item.doc_id}">Sign</button>--><button class="{$item.btntype}" data-ucn="{$item.ucn}" data-doc_id="{$item.doc_id}">Action</button> 
			                    	<a class="orders printhide" style="display: none" data-parent-tab="case-{$item.ucn}" data-ucn="{$item.ucn}" data-doc_id="{$item.doc_id}">hidden</a>
			                    {else}
			                    	<button class="{$item.btntype} sigBtn" data-ucn="{$item.ucn}" data-doc_id="{$item.doc_id}">Action</button>
			                    	<a class="orders printhide" style="display: none" data-parent-tab="case-{$item.ucn}" data-ucn="{$item.ucn}" data-doc_id="{$item.doc_id}">hidden</a>
			                    {/if}
			                {else}
			                    <button class="{$item.btntype} sigBtn" data-ucn="{$item.ucn}" data-doc_id="{$item.doc_id}">Action</button>
			                    <a class="orders printhide" style="display: none" data-parent-tab="case-{$item.ucn}" data-ucn="{$item.ucn}" data-doc_id="{$item.doc_id}">hidden</a>
			            	{/if}
						</td>
						<td class="Comments {$item.doc_type}">
							<button class="wf_add_comment_but" data-queue="{$queueName}" data-ucn="{$item.ucn}" data-title="{$item.title}"
								data-comment="{$item.comments}" data-wfid="{$item.doc_id}">Add</button>
							<div style="display:block; max-height:80px; max-width:300px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;" class="comment_field comment_{$item.ucn}" data-ucn="{$item.ucn}">
								{if !empty($item.comments)}
									<span style="color:green">{$item.comments}<br/></span>
								{/if}
								{if !empty($item.user_comments)}
									<span style="color:blue">{$item.user_comments}</span>
								{/if}
							</div>
						</td>
					</tr>
				{/foreach}
			</tbody>
		</table>
	{/if}
</div>