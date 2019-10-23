 
	<div class='col-md-12' style="padding: 20px;">
		
		<h3 style="padding-left: 20px; padding-right: 20px; width: 100%">Signatures <span style="float: right"> Log in as: {$loginUser} </span></h3>
		
	</div>

 


 
	<div class="col-md-8"  >
		 <span style="width: 100%; text-align: right">
			<a href="addSignatureUser.php" class='btn btn-primary'> <i class="fa fa-plus"></i> Add Signature User</a>
		</span>
		<br><br>
		
		
		<table class=" tablesorter" style="  width: 100%">
			<thead>
				<tr>
					<th width="200px">User</th>
					<th width="200px">View Details</th>

				</tr>
			</thead>

				{foreach from=$users item=user}

			<tbody>
				<tr class="{cycle values="odd,even"}">
					<td>{$user.first_name} {$user.last_name} </td>

					<td align="center">  <a href="signatureDetail.php?u={$user.user_id}"> View Details </a> </td>
				</tr>
			</tbody>
				{/foreach}

		</table>
	
	</div>
 




 





 