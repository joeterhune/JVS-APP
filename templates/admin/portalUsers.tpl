 
	<div class='col-md-12' style="padding: 20px;">
		
		<h3 style="padding-left: 20px; padding-right: 20px; width: 100%">Portal Users <span style="float: right"> Log in as: {$loginUser} </span></h3>
		
	</div>

 

 
	<div class="col-md-6" style="padding: 40px;">
		<span style="width: 100%; text-align: right">
			<a href="addPortalUser.php" class='btn btn-primary'> <i class="fa fa-plus"></i> Add Portal User </a>
		</span>
		<br><bR>
		
		
		<table class=" tablesorter" style="  width: 100%">
			<thead>
				<tr>
					<th width="200px">User</th>
					<th width="200px">View Details</th>

				</tr>
			</thead>

				{foreach from=$portalUsers item=user}

			<tbody>
				<tr class="{cycle values="odd,even"}">
					<td>{$user.judge_first_name} {$user.judge_middle_name} {$user.judge_last_name} </td>

					<td align="center">  <a href="portalUserDetail.php?u={$user.user_id}"><i class="fa fa-pencil-square-o "></i> View/Edit Details </a> </td>
				</tr>
			</tbody>
				{/foreach}

		</table>
	
	</div>
	<div class="col-md-6">
	
	</div>
	
	
 
 