 
	<div class='col-md-12'  >
		
		<h3 style="padding-left: 20px; padding-right: 20px; width: 100%">Signatures <span style="float: right"> Log in as: {$loginUser} </span></h3>
		
	</div>

 
	<div class="col-md-6">
	<h3>  {$sigUser["first_name"]} {$sigUser["middle_name"]} {$sigUser["last_name"]}</h3>

	Authorized Users:
		
		 
		<ol>
			{foreach from=$authorizedUsers item=aUser}
			<li> {$aUser.user_id} | <a href="xRemoveSignature.php?u={$aUser.user_id}&s={$sigUser["user_id"]}">Remove</a> </li>
			{/foreach}
		</ol>
		
		
		<br><br>
		
	Authorize New User:
		<form method="post" action="xAddSignature.php" name="form1">
		<select name="user">
			{foreach from=$users item=user}
			<option value="{$user.userid}" > {$user.first_name} {$user.middle_name} {$user.last_name} </option>
			{/foreach}
			
		</select>
			
			<input type="submit" Value="Add User">
			<input type="hidden" name="signature" value="{$sigUser["user_id"]}">
		</form>
		
		
		<br><br>
	</div>

	<div class="col-md-6">
		 
		<img src="data:image/jpg;base64,{$signature}" >
		<br><br>
		<hr>
		<form action="updateSignature.php" method="post" enctype="multipart/form-data" >
			<input type="file" name='signature' >
			<input type="hidden" name="signatureUser" value="{$sigUser["user_id"]}">
			<input type="submit" name="Update" value="Update Signature">
		</form>

	</div>
	
 
 





 