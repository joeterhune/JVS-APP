
<br><br> 
<div class="clear"></div>

	<div class='col-md-12'  >
		
		<h3 style="padding-left: 20px; padding-right: 20px; width: 100%">Signatures <span style="float: right"> Log in as: {$loginUser} </span></h3>
		
	</div>

 
 
 
	<div class='form-group col-md-12' >
		<form action="xAddSignatureUser.php" method="post" enctype="multipart/form-data">
		
			
			
			<div class='form-group col-md-6' >
				<label> User Type </label>
			 	<select name='userId' class='form-control'>
					{foreach from=$users item=user}
					<option value="{$user["user_id"]}">  {$user["judge_first_name"]} {$user["judge_middle_name"]} {$user["judge_last_name"]}   </option>
					{/foreach}
				</select>
			</div>
			<div class="clear">
			</div>
			<br><Br>
			<div class='form-group col-md-3' >
				<label> Signature</label>
				<input type="file" name='signature' >
				 
				
			</div>
			<div class="clear">
			</div>
			<br>
			
			
			<input type="submit" name="Update" value="Add Signature to User">
			
		
		</form>
	</div>
 
	
 
 
 





 