 
	<div class='col-md-12' style="padding: 20px;">
		
	<h3 style="padding-left: 20px;">Sudo</h3>
		
	</div>

 
	
	<div class="col-md-8">
		<table class=" tablesorter"  >
			<thead>
				<tr>
					<th width="200px">User</th>
					<th width="200px">Email</th>
					<th width="200px" >Sudo</th>
				</tr>
			</thead>

				{foreach from=$users item=user}

			<tbody>
				<tr class="{cycle values="odd,even"}">
					<td>{$user.first_name} {$user.last_name} </td>
					<td>{$user.email}</td>
					<td align="center"> <a href="xsudo.php?u={$user.userid}" class="btn btn-xs btn-default"># Sudo </a> </td>
				</tr>
			</tbody>
				{/foreach}

		</table>
	</div>
 


 


 