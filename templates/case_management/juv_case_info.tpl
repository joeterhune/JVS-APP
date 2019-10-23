<form method="post" action="juvenile.php?case_number={$case_number}" id="cm_form">
	<div style="float:right;">
		<button type="submit" name="submit" id="submit">Save Changes</button>
	</div>
	<span style="font-size:20px"><strong>CLS Attorney/GAL/Case Manager</strong></span> <span class="collapseCLS ascArrow">&nbsp;</span>
	<br/>
	<div id="clsSection" style="border:1px solid #800020; padding:1%; width:75%;">
		<table style="width:100%; text-align:center;">
			<thead>
				<th>CLS Attorney Name</th>
				<th>GAL Name</th>
				<th>GAL Attorney Name</th>
				<th>Case Manager Name</th>
			</thead>
			<tbody>
				<tr>
					<td><input type="text" name="cls_attorney" id="cls_attorney" value="{$cls_attorney}" size="30"/></td>
					<td><input type="text" name="gal_name" id="gal_name" value="{$gal_name}" size="30"/></td>
					<td><input type="text" name="gal_attorney_name" id="gal_attorney_name" value="{$gal_attorney_name}" size="30"/></td>
					<td><input type="text" name="dcm_name" id="dcm_name" value="{$dcm_name}" size="30"/></td>
				</tr>
			</tbody>
		</table>
	</div>
	<br/>
	<span style="font-size:20px"><strong>Case Plan(s)</strong></span> <span class="collapseCPs ascArrow">&nbsp;</span>
	<br/>
	<div id="cpSection" style="border:1px solid #800020; padding:1%; width:85%;">
		<table style="width:100%; text-align:center;">
			<thead>
				<th>Case Plan</th>
				<th>Date Filed</th>
				<th>Executed</th>
				<th>Executed Date</th>
				<th>Goal Date</th>
				<th>Order Date</th>
				<th>Parties Bound</th>
			</thead>
			<tbody>
				{foreach $case_plans as $cp}
					<tr>
						<td><a class="imageLink" data-docketcode="{$cp['DocketCode']}" data-casenum="{$cp['CaseNumber']}" data-ucnobj="{$cp['UCNObj']}" data-docname="{$cp['DocketDescription']}" data-caseid="{$cp['CaseID']}">Image</a></td>
						<td>
							{$cp['EnteredDate']}
							<input type="hidden" name="cp_{$cp['ObjectID']}_ent_date" id="cp_{$cp['ObjectID']}_ent_date" value="{$cp['EnteredDate']}"/>
						</td>
						<td>
							<select name="cp_{$cp['ObjectID']}_exec" id="cp_{$cp['ObjectID']}_exec" class="cp_executed">
								<option value=""></option>
								<option value="Yes" {if $cp['executed'] == 'Yes'}selected{/if}>Yes</option>
								<option value="No"{if $cp['executed'] == 'No'}selected{/if}>No</option>
							</select>
						</td>
						<!--<td class="exec_date" {if $cp['executed'] != 'Yes'}style="display:none"{/if}>-->
						<td>
							<input type="text" name="cp_{$cp['ObjectID']}_exec_date" id="cp_{$cp['ObjectID']}_exec_date" class="datepicker" value="{$cp['executed_date']}"/>
						</td>
						<!--<td class="exp_date" {if $cp['executed'] != 'Yes'}style="display:none"{/if}>-->
						<td>
							<input type="text" name="cp_{$cp['ObjectID']}_goal_date" id="cp_{$cp['ObjectID']}_goal_date" class="datepicker" value="{$cp['goal_date']}"/>
						</td>
						<td>
							<input type="text" name="cp_{$cp['ObjectID']}_order_date" id="cp_{$cp['ObjectID']}_order_date" class="datepicker" value="{$cp['order_date']}"/>
						</td>
						<td>
							<select name="cp_relates_to~{$cp['ObjectID']}[]" multiple>
								{$selected = ""}
								{foreach $cp['relates_to'] as $rc}
									{if $rc == "999"}
										{$selected = "selected"}
									{/if}
								{/foreach}
								<option value="999" {$selected}>N/A</option>
								{foreach $children as $key => $c}
									{$selected = ""}
									{foreach $cp['relates_to'] as $rc}
										{if $rc == $c['PersonID']}
											{$selected = "selected"}
										{/if}
									{/foreach}
									<option value="{$c['PersonID']}" {$selected}>Child - {$c['FirstName']} {$c['MiddleName']} {$c['LastName']}</option>
								{/foreach}
								{foreach $fathers as $key => $f}
									{$selected = ""}
									{foreach $cp['relates_to'] as $rc}
										{if $rc == $f['PersonID']}
											{$selected = "selected"}
										{/if}
									{/foreach}
									<option value="{$f['PersonID']}" {$selected}>Father - {$f['FirstName']} {$f['MiddleName']} {$f['LastName']}</option>
								{/foreach}
								{$selected = ""}
								{foreach $cp['relates_to'] as $rc}
									{if $rc == $mother['PersonID']}
										{$selected = "selected"}
									{/if}
								{/foreach}
								<option value="{$mother['PersonID']}" {$selected}>Mother - {$mother['FirstName']} {$mother['MiddleName']} {$mother['LastName']}</option>
							</select>
						</td>
					</tr>
				{/foreach}
				{if empty($case_plans)}
					<tr>
						<td colspan="7">No case plans have been filed.</td>
					</tr>
				{/if}
			</tbody>
		</table>
	</div>
	<br/>
	{if $previousOrders|@count > 0}
		<span style="font-size:20px"><strong>Previously Ordered</strong></span> <span class="collapsePrevOrdered ascArrow">&nbsp;</span>
		<br/>
		<div id="prevOrderedSection" style="border:1px solid #800020; padding:1%; width:85%;">
			<table style="width:100%; text-align:center;">
				<thead>
					<th>Order Title</th>
					<th>Order Date</th>
					<th>Due Date</th>
					<th>Who?</th>
					<th>Completed Date</th>
				</thead>
				<tbody>
					{foreach $previousOrders as $po}
						<tr>
							<td>
								{$po['order_title']}
							</td>
							<td>
								{$po['order_date']}
							</td>
							<td>
								{$po['due_date']}
							</td>
							<td>
								{foreach $children as $key => $c}
									{$selected = ""}
									{foreach $po['order_for'] as $of}
										{if $of == $c['PersonID']}
											Child - {$c['FirstName']} {$c['MiddleName']} {$c['LastName']}
											<br/>
										{/if}
									{/foreach}
								{/foreach}
								{foreach $fathers as $key => $f}
									{$selected = ""}
									{foreach $po['order_for'] as $of}
										{if $of == $f['PersonID']}
											Father - {$f['FirstName']} {$f['MiddleName']} {$f['LastName']}
											<br/>
										{/if}
									{/foreach}
								{/foreach}
								{$selected = ""}
								{foreach $co['order_for'] as $of}
									{if $of == $mother['PersonID']}
										Mother - {$mother['FirstName']} {$mother['MiddleName']} {$mother['LastName']}
										<br/>
									{/if}
								{/foreach}
							</td>
							<td>{$po['completed_date']}</td>
						</tr>
					{/foreach}
				</tbody>
			</table>
		</div>
		<br/>
	{/if}
	<span style="font-size:20px"><strong>Ordered</strong></span> <span class="collapseOrdered ascArrow">&nbsp;</span>
	<br/>
	<div id="orderedSection" style="border:1px solid #800020; padding:1%; width:85%;">
		<table style="width:100%; text-align:center;" id="currentOrders">
			<thead>
				<th>Order Title</th>
				<th>Order Date</th>
				<th>Due Date</th>
				<th>Who?</th>
				<th>Completed?</th>
			</thead>
			<tbody>
				{foreach $orders as $co}
					{if $co['completed']}
						<tr>
							<td>{$co['order_title']}</td>
							<td>{$co['order_date']}</td>
							<td>{$co['due_date']}</td>
							<td>x</td>
							<td>{$co['completed']}</td>
						</tr>
					{else}
						<tr id="orderRow-{$co['juv_order_id']}">
							<td>
								<input size="50" type="text" name="co_{$co['juv_order_id']}_order_title" id="co_{$co['juv_order_id']}_order_title" value="{$co['order_title']}"/>
							</td>
							<td>
								<input type="text" name="co_{$co['juv_order_id']}_order_date" id="co_{$co['juv_order_id']}_order_date" class="datepicker" value="{$co['order_date']}"/>
							</td>
							<td>
								<input type="text" name="co_{$co['juv_order_id']}_due_date" id="co_{$co['juv_order_id']}_due_date" class="datepicker" value="{$co['due_date']}"/>
							</td>
							<td>
								<select name="co_order_for~{$co['juv_order_id']}[]" multiple>
									<!--<option value="All">All</option>-->
									{foreach $children as $key => $c}
										{$selected = ""}
										{foreach $co['order_for'] as $of}
											{if $of == $c['PersonID']}
												{$selected = "selected"}
											{/if}
										{/foreach}
										<option value="{$c['PersonID']}" {$selected}>Child - {$c['FirstName']} {$c['MiddleName']} {$c['LastName']}</option>
									{/foreach}
									{foreach $fathers as $key => $f}
										{$selected = ""}
										{foreach $co['order_for'] as $of}
											{if $of == $f['PersonID']}
												{$selected = "selected"}
											{/if}
										{/foreach}
										<option value="{$f['PersonID']}" {$selected}>Father - {$f['FirstName']} {$f['MiddleName']} {$f['LastName']}</option>
									{/foreach}
									{$selected = ""}
									{foreach $co['order_for'] as $of}
										{if $of == $mother['PersonID']}
											{$selected = "selected"}
										{/if}
									{/foreach}
									<option value="{$mother['PersonID']}" {$selected}>Mother - {$mother['FirstName']} {$mother['MiddleName']} {$mother['LastName']}</option>
								</select>
							</td>
							<td><button type="button" class="order_completed" id="{$co['juv_order_id']}">Complete</button></td>
						</tr>
					{/if}
				{/foreach}
				{if empty($orders)}
					<tr>
						<td colspan="5" id="noOrders">No orders have been directed.</td>
					</tr>
				{/if}
			</tbody>
			<tbody>
				<tr>
					<td><a href="#/" class="newOrderLink">Add a New Order</a></td>
				</tr>
			</tbody>
		</table>
	</div>
	<br/>
	<span style="font-size:20px"><strong>Related Cases</strong></span> <span class="collapseRelated ascArrow">&nbsp;</span>
	<div id="relatedSection" style="border:1px solid #800020; padding:1%; width:85%;">
		<table style="text-align:center; width:100%" class="relatedTable">
			<thead>
				<tr>
					<th data-placeholder="Part of Case #">Case Number</th>
					<th class="filter-select">Case Type</th>
					<th class="filter-select">Case Status</th>
					<th class="filter-select">File Date</th>
					<th data-placeholder="Part of Case Style">Case Style</th>
					<th class="filter-select">Division</th>
					<th class="filter-false">Related To</th>
				</tr>
			</thead>
			<tbody>
				{foreach $related_cases as $key => $r}
					<tr>
						<td>{if $r['HasWarrant'] == 'Yes'}<img src="/asterisk.png" alt="Open Warrants" />{/if} <a href="/cgi-bin/search.cgi?name={$r['ToCaseNumber']}" target="_blank">{$r['ToCaseNumber']}</a></td>
						<td>{$r['CaseType']}</td>
						<td>{$r['CaseStatus']}</td>
						<td>{$r['FileDate']}</td>
						<td>{$r['CaseStyle']}</td>
						<td>{$r['DivisionID']}</td>
						<td>
							<select name="related~{$r['ToCaseNumber']}~{$r['CaseID']}[]" multiple>
								<!--<option value="All">All</option>-->
								{foreach $children as $key => $c}
									{$selected = ""}
									{foreach $c['related_cases'] as $rc}
										{if $rc == $r['CaseID']}
											{$selected = "selected"}
										{/if}
									{/foreach}
									<option value="{$c['PersonID']}" {$selected}>Child - {$c['FirstName']} {$c['MiddleName']} {$c['LastName']}</option>
								{/foreach}
								{foreach $fathers as $key => $f}
									{$selected = ""}
									{foreach $f['related_cases'] as $rc}
										{if $rc == $r['CaseID']}
											{$selected = "selected"}
										{/if}
									{/foreach}
									<option value="{$f['PersonID']}" {$selected}>Father - {$f['FirstName']} {$f['MiddleName']} {$f['LastName']}</option>
								{/foreach}
								{$selected = ""}
								{foreach $mother['related_cases'] as $rc}
									{if $rc == $r['CaseID']}
										{$selected = "selected"}
									{/if}
								{/foreach}
								<option value="{$mother['PersonID']}" {$selected}>Mother - {$mother['FirstName']} {$mother['MiddleName']} {$mother['LastName']}</option>
							</select>
						</td>
					</tr>
				{/foreach}
				{if empty($related_cases)}
					<tr>
						<td colspan="7" id="noRelated">No related cases have been added.</td>
					</tr>
				{/if}
			</tbody>
			<tbody class="remove-me tablesorter-no-sort">
				<tr>
					<td><a href="#/" class="add-related">Add a New Case</a></td>
				</tr>
			</tbody>
		</table>
	</div>
	<br/><br/>
	{foreach $children as $key => $c}
		<span style="font-size:28px"><strong>Child {$key} - {$c['FirstName']} {$c['MiddleName']} {$c['LastName']} - {$c['DOB']} ({$c['Age']}) {if !empty($c['special_identifiers_string'])}<span class="error">({$c['special_identifiers_string']})</span>{/if} </strong></span> <span class="collapseChild ascArrow" id="{$c['PersonID']}">&nbsp;</span>
		<input type="hidden" name="child_{$c['PersonID']}_person_id" id="child_{$c['PersonID']}_person_id" value="{$c['PersonID']}"/>
		<input type="hidden" name="child_{$c['PersonID']}_name" id="child_{$c['PersonID']}_name" value="{$c['FirstName']} {$c['MiddleName']} {$c['LastName']}"/>
		<input type="hidden" name="child_{$c['PersonID']}_dob" id="child_{$c['PersonID']}_dob" value="{$c['sqlDOB']}"/>
		<div id="childSection-{$c['PersonID']}">
			<br/>
			<span style="font-size:20px"><strong>Attorney(s)</strong></span> <span class="collapseAttorneysChild ascArrow" id="{$c['PersonID']}">&nbsp;</span>
			<br/>
			<div id="attorneysSectionChild-{$c['PersonID']}" style="border:1px solid #800020; padding:1%; width:65%;">
				<table style="width:100%; text-align:center;" id="childAttorneys">
					<thead>
						<tr>
							<th>Type</th>
							<th>Name</th>
							<th>Active</th>
						</tr>
					</thead>
					<tbody>
						{$attCount = 1}
						{foreach $c['attorneys'] as $a}
							<tr>
								<td>
									<select name="child_{$c['PersonID']}_attorney_type_{$attCount}" id="child_{$c['PersonID']}_attorney_type_{$attCount}">
										<option value=""></option>
										<option value="FCP" {if $a['attorney_type'] == "FCP"}selected{/if}>FCP</option>
										<option value="JAP" {if $a['attorney_type'] == "JAP"}selected{/if}>JAP</option>
										<option value="Attorney Ad Litem" {if $a['attorney_type'] == "Attorney Ad Litem"}selected{/if}>Attorney Ad Litem</option>
										<option value="Guardian Ad Litem" {if $a['attorney_type'] == "Guardian Ad Litem"}selected{/if}>Guardian Ad Litem</option>
										<option value="GAL Attorney" {if $a['attorney_type'] == "GAL Attorney"}selected{/if}>GAL Attorney</option>
										<option value="Other" {if $a['attorney_type'] == "Other"}selected{/if}>Other</option>
									</select>
								</td>
								<td>
									<input size="50" type="text" name="child_{$c['PersonID']}_attorney_name_{$attCount}" id="child_{$c['PersonID']}_attorney_name_{$attCount}" value="{$a['attorney_name']}"/>
								</td>
								<td>
									<select name="child_{$c['PersonID']}_attorney_active_{$attCount}" id="child_{$c['PersonID']}_attorney_active_{$attCount}">
										<option value="Yes" {if $a['attorney_active'] == "Yes"}selected{/if}>Yes</option>
										<option value="No" {if $a['attorney_active'] == "No"}selected{/if}>No</option>
									</select>
									<input type="hidden" name="child_{$c['PersonID']}_attorney_id_{$attCount}" id="child_{$c['PersonID']}_attorney_id_{$attCount}" value="{$a['attorney_id']}"/>
								</td>
							</tr>
							{$attCount = $attCount + 1}
						{/foreach}
						{if empty($c['attorneys'])}
							<tr>
								<td colspan="3" class="noAttorneysChild">No attorneys have been added.<br/></td>
							</tr>
						{/if}
					</tbody>
					<tbody>
						<tr>
							<td><a href="#/" class="newAttorneyLink_child" id="{$c['PersonID']}">Add a New Attorney</a></td>
						</tr>
					</tbody>
				</table>
			</div>
			<br/>
			{if $c['previous_placements']|@count > 0}
				{$count = 1}
				<span style="font-size:20px"><strong>Previous Placements</strong></span> <span class="collapsePrevPlacements ascArrow" id="{$c['PersonID']}">&nbsp;</span>
				<br/>
				<div id="prevPlacementsSection-{$c['PersonID']}" style="border:1px solid #800020; padding:1%; width:90%;">
					<table style="width:100%; text-align:center;">
						<thead>
							<th>&nbsp;</th>
							<th>Date Placed</th>
							<th>Where was Child?</th>
							<th>Who was Child Placed with?</th>
							<th>Address</th>
							<th>Approved Home Study</th>
						</thead>
						<tbody>
							{foreach $c['previous_placements'] as $pp}
								<tr>
									<td>{$count}</td>
									<td>{$pp['date_placed']}</td>
									<td>{$pp['child_where']}</td>
									<td>{$pp['child_with']}</td>
									<td>{$pp['child_address']}</td>
									<td>
										<table style="width:100%; text-align:center">
											<thead>
												<tr>
													<th>Y/N</th>
													<th>Date Approved</th>
													<th>Date Filed</th>
												</tr>
											</thead>
											<tbody>
												<tr>
													<td>{$pp['home_study_ind']}</select>
													</td>
													<td>{$pp['home_study_approved_date']}</td>
													<td>{$pp['home_study_filed_date']}</td>
												</tr>
											</tbody>
										</table>
									</td>
								</tr>
								{$count = $count + 1}
							{/foreach}
						</tbody>
					</table>
				</div>
				<br/>
			{/if}
			<span style="font-size:20px"><strong>Current Information</strong></span> <span class="collapseCurrPlacement ascArrow" id="{$c['PersonID']}">&nbsp;</span>
			<br/>
			<div id="currPlacementSection-{$c['PersonID']}" style="border:1px solid #800020; padding:1%; width:90%;">
				<table style="width:100%; text-align:center;">
					<thead>
						<tr>
							<th>Alerts</th>
							<th>Father</th>
							<th>Type of Father</th>
						</tr>
					</thead>
					<tbody>
						<tr id="other-{$c['PersonID']}">
							<td>
								<select name="child_{$c['PersonID']}_special_identifiers[]" id="child_{$c['PersonID']}_special_identifiers" multiple>
									<option value=""></option>
									{foreach $special_identifiers as $si}
										{$selected = ""}
										{foreach $c['special_identifiers'] as $csi}
											{if $csi == $si}
												{$selected = "selected"}
											{/if}
										{/foreach}
										<option value="{$si}" {$selected}>{$si}</option>
									{/foreach}
								</select>
							</td>
							<td>
								<select data-child_id="{$c['PersonID']}" class="fatherPicker" name="child_{$c['PersonID']}_father" id="child_{$c['PersonID']}_father">
									<option value=""></option>
									{foreach $fathers as $key => $f}
										<option value="{$f['PersonID']}~{$f['FirstName']} {$f['MiddleName']} {$f['LastName']}" {if $c['FatherPersonID'] == $f['PersonID']}selected{/if}>
											{$f['FirstName']} {$f['MiddleName']} {$f['LastName']}
										</option>
									{/foreach}
									<option value="Other">Other</option>
								</select>
							</td>
							<td>
								<select name="child_{$c['PersonID']}_father_type" id="child_{$c['PersonID']}_father_type">
									<option value=""></option>
									<option value="Legal" {if $c['type_of_father'] == "Legal"}selected{/if}>Legal</option>
									<option value="Putative" {if $c['type_of_father'] == "Putative"}selected{/if}>Putative</option>
									<option value="Biological" {if $c['type_of_father'] == "Biological"}selected{/if}>Biological</option>
								</select>
							</td>
						</tr>
					</tbody>
				</table>
				<br/><br/>
				<table style="width:100%; text-align:center;">
					<thead>
						<tr>
							<th>New Placement?</th>
							<th>Where is Child?</th>
							<th>Who is Child Placed With?</th>
							<th>Address</th>
							<th>Date Placed</th>
						</tr>
					</thead>
					<tbody>
						<tr>
							<td>
								<input type="checkbox" name="child_{$c['PersonID']}_new_placement" id="child_{$c['PersonID']}_new_placement"/>
							</td>
							<td>
								<select name="child_{$c['PersonID']}_where" id="child_{$c['PersonID']}_where">
									<option value=""></option>
									<option value="Relative" {if $c['ChildWhere'] == "Relative"}selected{/if}>Relative</option>
									<option value="Parents" {if $c['ChildWhere'] == "Parents"}selected{/if}>Parents</option>
									<option value="Non-Relative" {if $c['ChildWhere'] == "Non-Relative"}selected{/if}>Non-Relative</option>
									<option value="Licensed Care" {if $c['ChildWhere'] == "Licensed Care"}selected{/if}>Licensed Care</option>
									<option value="Permanent Guardianship" {if $c['ChildWhere'] == "Permanent Guardianship"}selected{/if}>Permanent Guardianship</option>
									<option value="Adopted" {if $c['ChildWhere'] == "Adopted"}selected{/if}>Adopted</option>
									<option value="Unknown" {if $c['ChildWhere'] == "Unknown"}selected{/if}>Unknown</option>
								</select>
							</td>
							<td>
								<input type="text" name="child_{$c['PersonID']}_who" id="child_{$c['PersonID']}_who" value="{$c['ChildWith']}"/>
							</td>
							<td>
								<textarea id="child_{$c['PersonID']}_address" name="child_{$c['PersonID']}_address" rows="4" cols="30">{$c['child_address']}</textarea>
							</td>
							<td>
								<input type="text" name="child_{$c['PersonID']}_date_placed" id="child_{$c['PersonID']}_date_placed" class="datepicker" value="{$c['date_placed']}"/>
							</td>
						</tr>
					</tbody>
				</table>
				<br/>
				<table style="width:100%; text-align:center">
					<thead>
						<tr>
							<th>Approved Home Study</th>
							<th>TICO</th>
							<th>Additional Notes</th>
						</tr>
					</thead>
					<tbody>
						<tr>
							<td>
								<table style="width:100%; text-align:center">
									<thead>
										<tr>
											<th>Y/N</th>
											<th class="hs_date-{$c['PersonID']}" {if $c['home_study_ind'] != 'Yes'}style="display:none"{/if}>Date Approved</th>
											<th class="hs_date-{$c['PersonID']}" {if $c['home_study_ind'] != 'Yes'}style="display:none"{/if}>Date Filed</th>
										</tr>
									</thead>
									<tbody>
										<tr>
											<td>
												<select name="child_{$c['PersonID']}_home_study_ind" id="child_{$c['PersonID']}_home_study_ind" class="hs_ind">
													<option value=""></option>
													<option value="Yes" {if $c['home_study_ind'] == 'Yes'}selected{/if}>Yes</option>
													<option value="No" {if $c['home_study_ind'] == 'No'}selected{/if}>No</option>
												</select>
											</td>
											<td class="hs_date-{$c['PersonID']}" {if $c['home_study_ind'] != 'Yes'}style="display:none"{/if}>
												<input type="text" name="child_{$c['PersonID']}_home_study_approved_date" id="child_{$c['PersonID']}_home_study_approved_date" class="datepicker" value="{$c['home_study_approved_date']}"/>
											</td>
											<td class="hs_date-{$c['PersonID']}" {if $c['home_study_ind'] != 'Yes'}style="display:none"{/if}>
												<input type="text" name="child_{$c['PersonID']}_home_study_filed_date" id="child_{$c['PersonID']}_home_study_filed_date" class="datepicker" value="{$c['home_study_filed_date']}"/>
											</td>
										</tr>
									</tbody>
								</table>
							</td>
							<td>
								<select name="child_{$c['PersonID']}_tico" id="child_{$c['PersonID']}_tico">
									<option value=""></option>
									<option value="Yes" {if $c['TICO'] == 'Yes'}selected{/if}>Yes</option>
									<option value="No" {if $c['TICO'] == 'No'}selected{/if}>No</option>
								</select>
							</td>
							<td>
								<textarea name="child_{$c['PersonID']}_notes" id="child_{$c['PersonID']}_notes" rows="4" cols="30">{$c['notes']}</textarea>
							</td>
						</tr>
					</tbody>
				</table>
				<br/>
				<table style="width:100%; text-align:center">
					<thead>
						<tr>
							<th>Psychotropic Medications</th>
						</tr>
					</thead>
					<tbody>
						<tr>
							<td>
								<table style="width:100%; text-align:center">
									<thead>
										<tr>
											<th>Requested By</th>
											<th>Requested Date</th>
											<th>Affidavit Filed</th>
											<th>Order Entered</th>
											<th>Order Date</th>
											<th>Medications</th>
										</tr>
									</thead>
									<tbody>
										{$pmCount = 1}
										{foreach $c['psych_meds'] as $p}
											<tr>
												<td>
													<select name="child_{$c['PersonID']}_psych_meds_requested_by_{$pmCount}" id="child_{$c['PersonID']}_psych_meds_requested_by_{$pmCount}">
	                                                    <option value=""></option>
	                                                    <option value="Oral" {if $p['psych_meds_requested_by'] == 'Oral'}selected{/if}>Oral</option>
	                                                    <option value="Motion" {if $p['psych_meds_requested_by'] == 'Motion'}selected{/if}>Motion</option>
	                                                    <option value="Agreed Order" {if $p['psych_meds_requested_by'] == 'Agreed Order'}selected{/if}>Agreed Order</option>
	                                                </select>
												</td>
												<td>
													<input class="datepicker" id="child_{$c['PersonID']}_psych_meds_requested_date_{$pmCount}" name="child_{$c['PersonID']}_psych_meds_requested_date_{$pmCount}" value="{$p['psych_meds_requested_date']}"/>
												</td>
												<td>
													<select name="child_{$c['PersonID']}_psych_meds_affidavit_filed_{$pmCount}" id="child_{$c['PersonID']}_psych_meds_affidavit_filed_{$pmCount}">
	                                                	<option value=""></option>
	                                                    <option value="Yes" {if $p['psych_meds_affidavit_filed'] == 'Yes'}selected{/if}>Yes</option>
	                                                    <option value="No" {if $p['psych_meds_affidavit_filed'] == 'No'}selected{/if}>No</option>
													</select>
												</td>
												<td>
													<select name="child_{$c['PersonID']}_psych_meds_order_filed_{$pmCount}" id="child_{$c['PersonID']}_psych_meds_order_filed_{$pmCount}">
	                                              		<option value=""></option>
	                                                    <option value="Yes" {if $p['psych_meds_order_filed'] == 'Yes'}selected{/if}>Yes</option>
	                                                    <option value="No" {if $p['psych_meds_order_filed'] == 'No'}selected{/if}>No</option>
	                                                    <option value="Parental Consent" {if $p['psych_meds_order_filed'] == 'Parental Consent'}selected{/if}>Parental Consent</option>
	                                            	</select>
												</td>
												<td>
													<input class="datepicker" id="child_{$c['PersonID']}_psych_meds_order_date_{$pmCount}" name="child_{$c['PersonID']}_psych_meds_order_date_{$pmCount}" value="{$p['psych_meds_order_date']}"/>
												</td>
												<td>
													<textarea id="child_{$c['PersonID']}_psych_meds_{$pmCount}" name="child_{$c['PersonID']}_psych_meds_{$pmCount}" rows="5" cols="50">{$p['psych_meds']}</textarea>
													<input type="hidden" name="child_{$c['PersonID']}_pm_id_{$attCount}" id="child_{$c['PersonID']}_pm_id_{$attCount}" value="{$p['pm_id']}"/>
												</td>
											</tr>
											{$pmCount = $pmCount + 1}
										{/foreach}
										{if empty($c['psych_meds'])}
											<tr class="noPsychMeds">
												<td colspan="6">No psychotropic medications have been added.<br/></td>
											</tr>
										{/if}
									</tbody>
									<tbody>
										<tr>
											<td><a href="#/" class="newPsychMedLink" id="{$c['PersonID']}">Add a New Psychotropic Medication</a></td>
										</tr>
									</tbody>
								</table>
							</td>
						</tr>
					</tbody>
				</table>
				<br/>
			</div>
		</div>
		<br/><br/>
	{/foreach}
	<div style="float:right;">
		<button type="submit" name="submit" id="submit">Save Changes</button>
	</div>
	{if !empty($mother)}
		<table style="width:50%;">
			<tr>
				<td style="font-size:28px">
					<strong>Mother - {$mother['FirstName']} {$mother['MiddleName']} {$mother['LastName']} {if !empty($mother['special_identifiers_string'])}<span class="error">({$mother['special_identifiers_string']})</span>{/if}</strong> <span class="collapsePerson ascArrow" id="{$mother['PersonID']}">&nbsp;</span>
					<input type="hidden" name="mother_{$mother['PersonID']}_name" id="mother_{$mother['PersonID']}_name" value="{$mother['FirstName']} {$mother['MiddleName']} {$mother['LastName']}"/>
				</td>
			</tr>
		</table>
		<br/>
		<div id="personSection-{$mother['PersonID']}">
			<span style="font-size:20px"><strong>Attorney(s)</strong></span> <span class="collapseAttorneysMother ascArrow" id="{$c['PersonID']}">&nbsp;</span>
			<br/>
			<div id="attorneysSectionMother-{$mother['PersonID']}" style="border:1px solid #800020; padding:1%; width:65%;">
				<table style="width:100%; text-align:center;" id="motherAttorneys">
					<thead>
						<tr>
							<th>Name</th>
							<th>Active</th>
						</tr>
					</thead>
					<tbody>
						{$attCount = 1}
						{foreach $mother['attorneys'] as $a}
							<tr>
								<td>
									<input size="50" type="text" name="mother_{$mother['PersonID']}_attorney_name_{$attCount}" id="mother_{$mother['PersonID']}_attorney_name_{$attCount}" value="{$a['attorney_name']}"/>
								</td>
								<td>
									<select name="mother_{$mother['PersonID']}_attorney_active_{$attCount}" id="mother_{$mother['PersonID']}_attorney_active_{$attCount}">
										<option value="Yes" {if $a['attorney_active'] == "Yes"}selected{/if}>Yes</option>
										<option value="No" {if $a['attorney_active'] == "No"}selected{/if}>No</option>
									</select>
									<input type="hidden" name="mother_{$mother['PersonID']}_attorney_id_{$attCount}" id="mother_{$mother['PersonID']}_attorney_id_{$attCount}" value="{$a['attorney_id']}"/>
								</td>
							</tr>
							{$attCount = $attCount + 1}
						{/foreach}
						{if empty($mother['attorneys'])}
							<tr>
								<td colspan="3" class="noAttorneysMother">No attorneys have been added.<br/></td>
							</tr>
						{/if}
					</tbody>
					<tbody>
						<tr>
							<td><a href="#/" class="newAttorneyLink_mother" id="{$mother['PersonID']}">Add a New Attorney</a></td>
						</tr>
					</tbody>
				</table>
			</div>
			<br/>
			<span style="font-size:20px"><strong>Current Information</strong></span> <span class="collapseCurrPlacement ascArrow" id="{$mother['PersonID']}">&nbsp;</span>
			<br/>
			<div id="currPlacementSection-{$mother['PersonID']}"style="border:1px solid #800020; padding:1%; width:90%;">
				<table style="text-align:center; width:100%">
						<thead>
							<tr>
								<th>Alerts</th>
								<th>Offending</th>
								<th>In Custody</th>
								<!--<th>Warrant?</th>-->
								<th>No Contact Order</th>
								<th>Additional Notes</th>
							</tr>
						</thead>
						<tbody>
						<tr>
							<td>
								<select name="mother_{$mother['PersonID']}_special_identifiers[]" id="mother_{$mother['PersonID']}_special_identifiers" multiple>
									<option value=""></option>
									{foreach $special_identifiers as $si}
										{$selected = ""}
										{foreach $mother['special_identifiers'] as $msi}
											{if $msi == $si}
												{$selected = "selected"}
											{/if}
										{/foreach}
										<option value="{$si}" {$selected}>{$si}</option>
									{/foreach}
								</select>
							</td>
							<td>
								<select name="mother_{$mother['PersonID']}_off" id="mother_{$mother['PersonID']}_off">
									<option value=""></option>
									<option value="Yes" {if $mother['Offending'] == 'Yes'}selected{/if}>Yes</option>
									<option value="No" {if $mother['Offending'] == 'No'}selected{/if}>No</option>
								</select>
							</td>
							<td>
								<table style="width:100%">
									<thead>
										<tr>
											<th>Y/N</th>
											<th class="in_custody_yes-{$mother['PersonID']}" {if $mother['in_custody_ind'] != 'Yes'}style="display:none"{/if}>Where?</th>
										</tr>
									</thead>
									<tbody>
										<tr>
											<td>
												<select name="mother_{$mother['PersonID']}_in_custody_ind" id="mother_{$mother['PersonID']}_in_custody_ind" class="in_custody_ind">
													<option value=""></option>
													<option value="Yes" {if $mother['in_custody_ind'] == 'Yes'}selected{/if}>Yes</option>
													<option value="No" {if $mother['in_custody_ind'] == 'No'}selected{/if}>No</option>
												</select>
											</td>
											<td class="in_custody_yes-{$mother['PersonID']}" {if $mother['in_custody_ind'] != 'Yes'}style="display:none"{/if}>
												<textarea type="text" name="mother_{$mother['PersonID']}_in_custody_where" id="mother_{$mother['PersonID']}_in_custody_where" rows="4" cols="30">{$mother['in_custody_where']}</textarea>
											</td>
										</tr>
									</tbody>
								</table>
							</td>
							<!--<td>
								x
							</td>-->
							<td>
								<table style="width:100%">
									<thead>
										<tr>
											<th>Y/N</th>
											<th class="no_contact_yes-{$mother['PersonID']}" {if $mother['no_contact_ind'] != 'Yes'}style="display:none"{/if}>Date Entered</th>
											<th class="no_contact_yes-{$mother['PersonID']}" {if $mother['no_contact_ind'] != 'Yes'}style="display:none"{/if}>Date Vacated</th>
											<th class="no_contact_yes-{$mother['PersonID']}" {if $mother['no_contact_ind'] != 'Yes'}style="display:none"{/if}>Who?</th>
										</tr>
									</thead>
									<tbody>
										<tr>
											<td>
												<select name="mother_{$mother['PersonID']}_no_contact_ind" id="mother_{$mother['PersonID']}_no_contact_ind" class="no_contact_ind">
													<option value=""></option>
													<option value="Yes" {if $mother['no_contact_ind'] == 'Yes'}selected{/if}>Yes</option>
													<option value="No" {if $mother['no_contact_ind'] == 'No'}selected{/if}>No</option>
												</select>
											</td>
											<td class="no_contact_yes-{$mother['PersonID']}" {if $mother['no_contact_ind'] != 'Yes'}style="display:none"{/if}>
												<input class="datepicker" type="text" name="mother_{$mother['PersonID']}_no_contact_entered" id="mother_{$mother['PersonID']}_no_contact_entered" value="{$mother['no_contact_entered']}"/>
											</td>
											<td class="no_contact_yes-{$mother['PersonID']}" {if $mother['no_contact_ind'] != 'Yes'}style="display:none"{/if}>
												<input class="datepicker" type="text" name="mother_{$mother['PersonID']}_no_contact_vacated" id="mother_{$mother['PersonID']}_no_contact_vacated" value="{$mother['no_contact_vacated']}"/>
											</td>
											<td class="no_contact_yes-{$mother['PersonID']}" {if $mother['no_contact_ind'] != 'Yes'}style="display:none"{/if}>
												<select name="mother_{$mother['PersonID']}_no_contact_with[]" multiple>
													{foreach $mother['no_contact_with'] as $nc}
														{if $nc == "999"}
															{$selected = "selected"}
														{/if}
													{/foreach}
													<option value="999" {$selected}>Non-Party</option>
													<!--<option value="All">All</option>-->
													{foreach $children as $key => $c}
														{$selected = ""}
														{foreach $mother['no_contact_with'] as $nc}
															{if $nc == $c['PersonID']}
																{$selected = "selected"}
															{/if}
														{/foreach}
														<option value="{$c['PersonID']}" {$selected}>Child - {$c['FirstName']} {$c['MiddleName']} {$c['LastName']}</option>
													{/foreach}
													{foreach $fathers as $key => $f}
														{$selected = ""}
														{foreach $mother['no_contact_with'] as $nc}
															{if $nc == $f['PersonID']}
																{$selected = "selected"}
															{/if}
														{/foreach}
														<option value="{$f['PersonID']}" {$selected}>Father - {$f['FirstName']} {$f['MiddleName']} {$f['LastName']}</option>
													{/foreach}
												</select>
											</td>
										</tr>
									</tbody>
								</table>
							</td>
							<td>
								<textarea name="mother_{$mother['PersonID']}_recom" id="mother_{$mother['PersonID']}_recom" rows="4" cols="30">{$mother['recom']}</textarea>
							</td>
						</tr>
					</tbody>
				</table>
				<br/>
				<table style="width:100%; text-align:center">
					<thead>
						<tr>
							<th>Petitions (Dates of Service)</th>
						</tr>
					</thead>
					<tbody>
						<tr>
							<td>
								<table style="width:100%">
									<thead>
										<tr>
											<th>Shelter</th>
											<th>Arraignment</th>
											<th>Dependency</th>
											<th>Supplemental Findings</th>
											<th>TPR</th>
										</tr>
									</thead>
									<tbody>
										<tr>
											<td><input type="text" name="mother_{$mother['PersonID']}_shelter_dos" id="mother_{$mother['PersonID']}_shelter_dos" class="datepicker" value="{$mother['shelter_dos']}"/></td>
											<td>
												<input type="text" name="mother_{$mother['PersonID']}_arraignment_dos" id="mother_{$mother['PersonID']}_arraignment_dos" class="datepicker" value="{$mother['arraignment_dos']}"/>
											</td>
											<td><input type="text" onchange="eraseValue('mother_{$mother['PersonID']}_supp_findings_dos')" name="mother_{$mother['PersonID']}_dependency_dos" id="mother_{$mother['PersonID']}_dependency_dos" class="datepicker" value="{$mother['dependency_dos']}"/></td>
											<td><input type="text" onchange="eraseValue('mother_{$mother['PersonID']}_dependency_dos')" name="mother_{$mother['PersonID']}_supp_findings_dos" id="mother_{$mother['PersonID']}_supp_findings_dos" class="datepicker" value="{$mother['supp_findings_dos']}"/></td>
											<td><input type="text" name="mother_{$mother['PersonID']}_tpr_dos" id="mother_{$mother['PersonID']}_tpr_dos" class="datepicker" value="{$mother['tpr_dos']}"/></td>
										</tr>
									</tbody>
								</table>
							</td>				
						</tr>
					</tbody>
				</table>
				<br/>
				<table style="width:100%; text-align:center">
					<thead>
						<tr>
							<th>Petitions (Orders Filed)</th>
						</tr>
					</thead>
					<tbody>
						<tr>
							<td>
								<table style="width:100%">
									<thead>
										<tr>
											<th>Shelter</th>
											<th>Arraignment</th>
											<th>Dependency</th>
											<th>Supplemental Findings</th>
											<th>TPR</th>
										</tr>
									</thead>
									<tbody>
										<tr>
											<td><input type="text" name="mother_{$mother['PersonID']}_shelter_order_filed" id="mother_{$mother['PersonID']}_shelter_order_filed" class="datepicker" value="{$mother['shelter_order_filed']}"/></td>
											<td>
												<input type="text" name="mother_{$mother['PersonID']}_arraignment_order_filed" id="mother_{$mother['PersonID']}_arraignment_order_filed" class="datepicker" value="{$mother['arraignment_order_filed']}"/>
											</td>
											<td><input type="text" onchange="eraseValue('mother_{$mother['PersonID']}_supp_findings_order_filed')" name="mother_{$mother['PersonID']}_dependency_order_filed" id="mother_{$mother['PersonID']}_dependency_order_filed" class="datepicker" value="{$mother['dependency_order_filed']}"/></td>
											<td><input type="text" onchange="eraseValue('mother_{$mother['PersonID']}_dependency_order_filed')" name="mother_{$mother['PersonID']}_supp_findings_order_filed" id="mother_{$mother['PersonID']}_supp_findings_order_filed" class="datepicker" value="{$mother['supp_findings_order_filed']}"/></td>
											<td><input type="text" name="mother_{$mother['PersonID']}_tpr_order_filed" id="mother_{$mother['PersonID']}_tpr_order_filed" class="datepicker" value="{$mother['tpr_order_filed']}"/></td>
										</tr>
									</tbody>
								</table>
							</td>				
						</tr>
					</tbody>
				</table>
			</div>
		</div>
		<br/>
	{/if}
	<br/>
	{foreach $fathers as $key => $f}
		<table style="width:50%;">
			<tr>
				<td style="font-size:28px">
					<strong>Father {$key} - {$f['FirstName']} {$f['MiddleName']} {$f['LastName']} {if !empty($f['special_identifiers_string'])}<span class="error">({$f['special_identifiers_string']})</span>{/if}</strong> <span class="collapsePerson ascArrow" id="{$f['PersonID']}">&nbsp;</span>
					<input type="hidden" id="father_{$f['PersonID']}_name" name="father_{$f['PersonID']}_name" value="{$f['FirstName']} {$f['MiddleName']} {$f['LastName']}"/>
				</td>
			</tr>
		</table>
		<br/>
		<div id="personSection-{$f['PersonID']}">
			<span style="font-size:20px"><strong>Attorney(s)</strong></span> <span class="collapseAttorneysFather ascArrow" id="{$f['PersonID']}">&nbsp;</span>
			<br/>
			<div id="attorneysSectionFather-{$f['PersonID']}" style="border:1px solid #800020; padding:1%; width:65%;">
				<table style="width:100%; text-align:center;" id="fatherAttorneys">
					<thead>
						<tr>
							<th>Name</th>
							<th>Active</th>
						</tr>
					</thead>
					<tbody>
						{$attCount = 1}
						{foreach $f['attorneys'] as $a}
							<tr>
								<td>
									<input size="50" type="text" name="father_{$f['PersonID']}_attorney_name_{$attCount}" id="father_{$f['PersonID']}_attorney_name_{$attCount}" value="{$a['attorney_name']}"/>
								</td>
								<td>
									<select name="father_{$f['PersonID']}_attorney_active_{$attCount}" id="father_{$f['PersonID']}_attorney_active_{$attCount}">
										<option value="Yes" {if $a['attorney_active'] == "Yes"}selected{/if}>Yes</option>
										<option value="No" {if $a['attorney_active'] == "No"}selected{/if}>No</option>
									</select>
									<input type="hidden" name="father_{$f['PersonID']}_attorney_id_{$attCount}" id="father_{$f['PersonID']}_attorney_id_{$attCount}" value="{$a['attorney_id']}"/>
								</td>
							</tr>
							{$attCount = $attCount + 1}
						{/foreach}
						{if empty($f['attorneys'])}
							<tr>
								<td colspan="3" class="noAttorneysFather">No attorneys have been added.<br/></td>
							</tr>
						{/if}
					</tbody>
					<tbody>
						<tr>
							<td><a href="#/" class="newAttorneyLink_father" id="{$f['PersonID']}">Add a New Attorney</a></td>
						</tr>
					</tbody>
				</table>
			</div>
			<br/>
			<span style="font-size:20px"><strong>Current Information</strong></span> <span class="collapseCurrPlacement ascArrow" id="{$f['PersonID']}">&nbsp;</span>
			<br/>
			<div id="currPlacementSection-{$f['PersonID']}"style="border:1px solid #800020; padding:1%; width:90%;">
				<table style="text-align:center; width:100%">
					<thead>
						<tr>
							<th>Alerts</th>
							<th>Offending</th>
							<th>In Custody</th>
							<!--<th>Warrant?</th>-->
							<th>No Contact Order</th>
							<th>Additional Notes</th>
						</tr>
					</thead>
					<tbody>
						<tr>
							<td>
								<select name="father_{$f['PersonID']}_special_identifiers[]" id="father_{$f['PersonID']}_special_identifiers" multiple>
									<option value=""></option>
									{foreach $special_identifiers as $si}
										{$selected = ""}
										{foreach $f['special_identifiers'] as $fsi}
											{if $fsi == $si}
												{$selected = "selected"}
											{/if}
										{/foreach}
										<option value="{$si}" {$selected}>{$si}</option>
									{/foreach}
								</select>
							</td>
							<td>
								<select name="father_{$f['PersonID']}_off" id="father_{$f['PersonID']}_off">
									<option value=""></option>
									<option value="Yes" {if $f['Offending'] == 'Yes'}selected{/if}>Yes</option>
									<option value="No" {if $f['Offending'] == 'No'}selected{/if}>No</option>
								</select>
							</td>
							<td>
								<table style="width:100%">
									<thead>
										<tr>
											<th>Y/N</th>
											<th class="in_custody_yes-{$f['PersonID']}" {if $f['in_custody_ind'] != 'Yes'}style="display:none"{/if}>Where?</th>
										</tr>
									</thead>
									<tbody>
										<tr>
											<td>
												<select name="father_{$f['PersonID']}_in_custody_ind" id="father_{$f['PersonID']}_in_custody_ind" class="in_custody_ind">
													<option value=""></option>
													<option value="Yes" {if $f['in_custody_ind'] == 'Yes'}selected{/if}>Yes</option>
													<option value="No" {if $f['in_custody_ind'] == 'No'}selected{/if}>No</option>
												</select>
											</td>
											<td class="in_custody_yes-{$f['PersonID']}" {if $f['in_custody_ind'] != 'Yes'}style="display:none"{/if}>
												<textarea type="text" name="father_{$f['PersonID']}_in_custody_where" id="father_{$f['PersonID']}_in_custody_where" rows="4" cols="30">{$f['in_custody_where']}</textarea>
											</td>
										</tr>
									</tbody>
								</table>
							</td>
							<!--<td>
								x
							</td>-->
							<td>
								<table style="width:100%">
									<thead>
										<tr>
											<th>Y/N</th>
											<th class="no_contact_yes-{$f['PersonID']}" {if $f['no_contact_ind'] != 'Yes'}style="display:none"{/if}>Date Entered</th>
											<th class="no_contact_yes-{$f['PersonID']}" {if $f['no_contact_ind'] != 'Yes'}style="display:none"{/if}>Date Vacated</th>
											<th class="no_contact_yes-{$f['PersonID']}" {if $f['no_contact_ind'] != 'Yes'}style="display:none"{/if}>Who?</th>
										</tr>
									</thead>
									<tbody>
										<tr>
											<td>
												<select name="father_{$f['PersonID']}_no_contact_ind" id="father_{$f['PersonID']}_no_contact_ind" class="no_contact_ind">
													<option value=""></option>
													<option value="Yes" {if $f['no_contact_ind'] == 'Yes'}selected{/if}>Yes</option>
													<option value="No" {if $f['no_contact_ind'] == 'No'}selected{/if}>No</option>
												</select>
											</td>
											<td class="no_contact_yes-{$f['PersonID']}" {if $f['no_contact_ind'] != 'Yes'}style="display:none"{/if}>
												<input class="datepicker" type="text" name="father_{$f['PersonID']}_no_contact_entered" id="father_{$f['PersonID']}_no_contact_entered" value="{$f['no_contact_entered']}"/>
											</td>
											<td class="no_contact_yes-{$f['PersonID']}" {if $f['no_contact_ind'] != 'Yes'}style="display:none"{/if}>
												<input class="datepicker" type="text" name="father_{$f['PersonID']}_no_contact_vacated" id="father_{$f['PersonID']}_no_contact_vacated" value="{$f['no_contact_vacated']}"/>
											</td>
											<td class="no_contact_yes-{$f['PersonID']}" {if $f['no_contact_ind'] != 'Yes'}style="display:none"{/if}>
												<select name="father_{$f['PersonID']}_no_contact_with[]" multiple>
													<!--<option value="All">All</option>-->
													{foreach $f['no_contact_with'] as $nc}
														{if $nc == "999"}
															{$selected = "selected"}
														{/if}
													{/foreach}
													<option value="999" {$selected}>Non-Party</option>
													{foreach $children as $key => $c}
														{$selected = ""}
														{foreach $f['no_contact_with'] as $nc}
															{if $nc == $c['PersonID']}
																{$selected = "selected"}
															{/if}
														{/foreach}
														<option value="{$c['PersonID']}" {$selected}>Child - {$c['FirstName']} {$c['MiddleName']} {$c['LastName']}</option>
													{/foreach}
													{$selected = ""}
													{foreach $f['no_contact_with'] as $nc}
														{if $nc == $c['PersonID']}
															{$selected = "selected"}
														{/if}
													{/foreach}
													<option value="{$mother['PersonID']}" {$selected}>Mother - {$mother['FirstName']} {$mother['MiddleName']} {$mother['LastName']}</option>
												</select>
											</td>
										</tr>
									</tbody>
								</table>
							</td>
							<td>
								<textarea name="father_{$f['PersonID']}_recom" id="father_{$f['PersonID']}_recom" rows="4" cols="30">{$f['recom']}</textarea>
							</td>
						</tr>
					</tbody>
				</table>
				<br/>
				<table style="width:100%; text-align:center">
					<thead>
						<tr>
							<th>Petitions (Dates of Service)</th>
						</tr>
					</thead>
					<tbody>
						<tr>
							<td>
								<table style="width:100%">
									<thead>
										<tr>
											<th>Shelter</th>
											<th>Arraignment</th>
											<th>Dependency</th>
											<th>Supplemental Findings</th>
											<th>TPR</th>
										</tr>
									</thead>
									<tbody>
										<tr>
											<td><input type="text" name="father_{$f['PersonID']}_shelter_dos" id="father_{$f['PersonID']}_shelter_dos" class="datepicker" value="{$f['shelter_dos']}"/></td>
											<td>
												<input type="text" name="father_{$f['PersonID']}_arraignment_dos" id="father_{$f['PersonID']}_arraignment_dos" class="datepicker" value="{$f['arraignment_dos']}"/>
											</td>
											<td><input type="text" onchange="eraseValue('father_{$f['PersonID']}_supp_findings_dos')" name="father_{$f['PersonID']}_dependency_dos" id="father_{$f['PersonID']}_dependency_dos" class="datepicker" value="{$f['dependency_dos']}"/></td>
											<td><input type="text" onchange="eraseValue('father_{$f['PersonID']}_dependency_dos')" name="father_{$f['PersonID']}_supp_findings_dos" id="father_{$f['PersonID']}_supp_findings_dos" class="datepicker" value="{$f['supp_findings_dos']}"/></td>
											<td><input type="text" name="father_{$f['PersonID']}_tpr_dos" id="father_{$f['PersonID']}_tpr_dos" class="datepicker" value="{$f['tpr_dos']}"/></td>
										</tr>
									</tbody>
								</table>
							</td>				
						</tr>
					</tbody>
				</table>
				<br/>
				<table style="width:100%; text-align:center">
					<thead>
						<tr>
							<th>Petitions (Orders Filed)</th>
						</tr>
					</thead>
					<tbody>
						<tr>
							<td>
								<table style="width:100%">
									<thead>
										<tr>
											<th>Shelter</th>
											<th>Arraignment</th>
											<th>Dependency</th>
											<th>Supplemental Findings</th>
											<th>TPR</th>
										</tr>
									</thead>
									<tbody>
										<tr>
											<td><input type="text" name="father_{$f['PersonID']}_shelter_order_filed" id="father_{$f['PersonID']}_shelter_order_filed" class="datepicker" value="{$f['shelter_order_filed']}"/></td>
											<td>
												<input type="text" name="father_{$f['PersonID']}_arraignment_order_filed" id="father_{$f['PersonID']}_arraignment_order_filed" class="datepicker" value="{$f['arraignment_order_filed']}"/>
											</td>
											<td><input type="text" onchange="eraseValue('father_{$f['PersonID']}_supp_findings_order_filed')" name="father_{$f['PersonID']}_dependency_order_filed" id="father_{$f['PersonID']}_dependency_order_filed" class="datepicker" value="{$f['dependency_order_filed']}"/></td>
											<td><input type="text" onchange="eraseValue('father_{$f['PersonID']}_dependency_order_filed')" name="father_{$f['PersonID']}_supp_findings_order_filed" id="father_{$f['PersonID']}_supp_findings_order_filed" class="datepicker" value="{$f['supp_findings_order_filed']}"/></td>		
											<td><input type="text" name="father_{$f['PersonID']}_tpr_order_filed" id="father_{$f['PersonID']}_tpr_order_filed" class="datepicker" value="{$f['tpr_order_filed']}"/></td>
										</tr>
									</tbody>
								</table>
							</td>				
						</tr>
					</tbody>
				</table>
			</div>
		</div>
		<br/>
	{/foreach}
	<div style="font-size:20px">
		<strong>Event Notes</strong> <span class="collapseNotes ascArrow">&nbsp;</span>
	</div>
	<div id="notesSection" style="border:1px solid #800020; padding:1%; width:55%;">
		<table style="width:100%">
			<thead>
				<tr>
					<th>Event Date</th>
					<th>Note</th>
				</tr>
			</thead>
			<tbody>
				<tr>
					<td><input type="text" id="event_date" name="event_date" value="{$smarty.now|date_format:"%m/%d/%Y"}" readonly="readonly"/></td>
					<td><textarea id="event_notes" name="event_notes" rows="10" cols="80"></textarea></td>
				</tr>
			</tbody>
		</table>
	</div>
	<br/>
	{if !empty($notes)}
		<div style="font-size:20px">
			<strong>Previous Event Notes</strong> <span class="collapsePrevNotes ascArrow">&nbsp;</span>
		</div>
		<div id="prevNotesSection" style="border:1px solid #800020; padding:1%; width:75%;">
			<table style="width:100%;">
				<thead>
					<tr>
						<th>Event Date</th>
						<th>Note</th>
						<th>Entered By</th>
						<th>Delete</th>
					</tr>
				</thead>
				<tbody>
					{foreach $notes as $key => $n}
						<tr id="note-{$n['note_id']}">
							<td>{$n['event_date']}</td>
							<td style="width:50%">{$n['note']}</td>
							<td>{$n['created_by']}</td>
							<td style="text-align:center"><a href="#/" class="deleteNote" id="{$n['note_id']}"><img src="/jvsicons/delete.png"/></a></td>
						</tr>
					{/foreach}
				</tbody>
			</table>
		</div>
	{/if}
	</table>
	<br/>
	<input type="hidden" id="case_number" name="case_number" value="{$case_number}" />
	<input type="hidden" id="case_id" name="case_id" value="{$case_id}"/>
	<div style="float:right;">
		<button type="submit" name="submit" id="submit">Save Changes</button>
	</div>
</form>

<div id="cloneMe" style="display:none">
	<!--<option value="All">All</option>-->
	{foreach $children as $key => $c}
		<option value="{$c['PersonID']}">Child - {$c['FirstName']} {$c['MiddleName']} {$c['LastName']}</option>
	{/foreach}
	{foreach $fathers as $key => $f}
		<option value="{$f['PersonID']}">Father - {$f['FirstName']} {$f['MiddleName']} {$f['LastName']}</option>
	{/foreach}
	<option value="{$mother['PersonID']}">Mother - {$mother['FirstName']} {$mother['MiddleName']} {$mother['LastName']}</option>
	</select>
</div>		

<table id="cloneNewOrder" style="display:none">
	<tr class="aNewOrder">
		<td>
			<input size="50" type="text" name="co_order_title_ORDCOUNT" id="co_order_title_ORDCOUNT" />
		</td>
		<td>
			<input type="text" name="co_order_date_ORDCOUNT" id="co_order_date_ORDCOUNT" class="newOrdDatePicker" />
		</td>
		<td>
			<input type="text" name="co_due_date_ORDCOUNT" id="co_due_date_ORDCOUNT" class="newOrdDatePicker" />
		</td>
		<td >
			<select name="co_order_for_ORDCOUNT[]" multiple>
				<!--<option value="All">All</option>-->
				{foreach $children as $key => $c}
					<option value="{$c['PersonID']}">Child - {$c['FirstName']} {$c['MiddleName']} {$c['LastName']}</option>
				{/foreach}
				{foreach $fathers as $key => $f}
					<option value="{$f['PersonID']}">Father - {$f['FirstName']} {$f['MiddleName']} {$f['LastName']}</option>
				{/foreach}
				<option value="{$mother['PersonID']}">Mother - {$mother['FirstName']} {$mother['MiddleName']} {$mother['LastName']}</option>
			</select>
		</td>
		<td>&nbsp;</td>
	</tr>	
</table>		

<table id="cloneNewAttorneyChild" style="display:none">
	<tr class="aNewAttorney">
		<td>
			<select name="child_CHILDID_attorney_type_ATTCOUNT" id="child_CHILDID_attorney_type_ATTCOUNT">
				<option value=""></option>
				<option value="FCP">FCP</option>
				<option value="JAP">JAP</option>
				<option value="Attorney Ad Litem">Attorney Ad Litem</option>
				<option value="Guardian Ad Litem">Guardian Ad Litem</option>
				<option value="Other">Other</option>
			</select>
		</td>
		<td class="newAttorney">
			<input size="50" type="text" name="child_CHILDID_attorney_name_ATTCOUNT" id="child_CHILDID_attorney_name_ATTCOUNT" />
		</td>
		<td class="newAttorney">
			<select name="child_CHILDID_attorney_active_ATTCOUNT" id="child_CHILDID_attorney_active_ATTCOUNT">
				<option value="Yes">Yes</option>
				<option value="No">No</option>
			</select>
		</td>
	</tr>	
</table>

<table id="cloneNewPsychMed" style="display:none">
	<tr>
		<td>
			<select name="child_CHILDID_psych_meds_requested_by_PMCOUNT" id="child_CHILDID_psych_meds_requested_by_PMCOUNT">
	        	<option value=""></option>
	            <option value="Oral">Oral</option>
	            <option value="Motion">Motion</option>
	            <option value="Agreed Order">Agreed Order</option>
	        </select>
		</td>
		<td>
			<input class="pmDatepicker" id="child_CHILDID_psych_meds_requested_date_PMCOUNT" name="child_CHILDID_psych_meds_requested_date_PMCOUNT" />
		</td>
		<td>
			<select name="child_CHILDID_psych_meds_affidavit_filed_PMCOUNT" id="child_CHILDID_psych_meds_affidavit_filed_PMCOUNT">
	        	<option value=""></option>
	            <option value="Yes">Yes</option>
	            <option value="No">No</option>
			</select>
		</td>
		<td>
			<select name="child_CHILDID_psych_meds_order_filed_PMCOUNT" id="child_CHILDID_psych_meds_order_filed_PMCOUNT">
	        	<option value=""></option>
	            <option value="Yes">Yes</option>
	            <option value="No">No</option>
	            <option value="Parental Consent">Parental Consent</option>
	    	</select>
		</td>
		<td>
			<input class="pmDatepicker" id="child_CHILDID_psych_meds_order_date_PMCOUNT" name="child_CHILDID_psych_meds_order_date_PMCOUNT"/>
		</td>
		<td>
			<textarea id="child_CHILDID_psych_meds_PMCOUNT" name="child_CHILDID_psych_meds_PMCOUNT" rows="5" cols="50"></textarea>
		</td>
	</tr>
</table>

<table id="cloneNewAttorneyFather" style="display:none">
	<tr class="aNewAttorney">
		<td class="newAttorney">
			<input size="50" type="text" name="father_FATHERID_attorney_name_ATTCOUNT" id="father_FATHERID_attorney_name_ATTCOUNT" />
		</td>
		<td class="newAttorney">
			<select name="father_FATHERID_attorney_active_ATTCOUNT" id="father_FATHERID_attorney_active_ATTCOUNT">
				<option value="Yes">Yes</option>
				<option value="No">No</option>
			</select>
		</td>
	</tr>	
</table>

<table id="cloneNewAttorneyMother" style="display:none">
	<tr class="aNewAttorney">
		<td class="newAttorney">
			<input size="50" type="text" name="mother_MOTHERID_attorney_name_ATTCOUNT" id="mother_MOTHERID_attorney_name_ATTCOUNT" />
		</td>
		<td class="newAttorney">
			<select name="mother_MOTHERID_attorney_active_ATTCOUNT" id="mother_MOTHERID_attorney_active_ATTCOUNT">
				<option value="Yes">Yes</option>
				<option value="No">No</option>
			</select>
		</td>
	</tr>	
</table>