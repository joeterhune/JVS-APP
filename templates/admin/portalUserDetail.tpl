 
	<div class='col-md-12' style="padding: 20px;">
		
		<h3 style="padding-left: 20px; padding-right: 20px; width: 100%">Portal User Detail <span style="float: right"> Log in as: {$loginUser} </span></h3>
		
	</div>
 

 
	<div class="col-md-6" style="padding: 40px;">
		 
		  
		
		<form action="xPortalUserUpdate.php" method="post">
			
			<input type="hidden" name="userId" value="{$user['user_id']}" >  
			
			<div class='form-group' >
				<label> PortalId: </label>
				<input type="text" name="portalId" value="{$user['portal_id']}" class='form-control' >
			</div>
			 
		 	<div class='form-group' >
				<label>Password:   </label>
				<input type="text" name="password" value="{$user['password']}" class='form-control'>
			</div>
			<div class='form-group' >
				<label> Bar Number:</label>
				<input type="text" name="barNumber" value="{$user['bar_num']}" class='form-control'> 
			</div>
			<div class='form-group' >
				<label> User Type: </label>
				<select name="userType" class="form-control">
					{foreach from=$userType item=type}
						
					
						<option value="{$type.portal_user_type_id}" 
								{if $type.portal_user_type_id == $user['portal_user_type_id'] }
								selected
								{/if}

								> {$type.portal_user_type_desc} 
						</option>
					{/foreach}
					
				</select>
				
				 
			</div>
			<div class='form-group' >
				<label>First Name: </label>
				<input type="text" name="name" value="{$user['judge_first_name']}" class='form-control' >
			</div>
			<div class='form-group' >
				<label>Middle Name:  </label>
				<input type="text" name="middleName" value="{$user['judge_middle_name']}" class='form-control'> 
			</div>
			<div class='form-group' >
				<label>Lastname: </label>
				<input type="text" name="lastname" value="{$user['judge_last_name']}" class='form-control' >
			</div>
			<div class='form-group' >
				<label>Judge Suffix:  </label>
				<input type="text" name="suffix" value="{$user['judge_suffix']}" class='form-control'> 
			</div>
			<!--
			<div class='form-group' >
				<label> Judge Id:</label>
				<input type="text" name="judgeId" value="{$user['judge_id']}" class='form-control'> 
			</div>
			-->
			<br>
			<input type="submit" value="Save Changes" class='btn btn-default  '>
			
		</form>
		
		
		
		 
	
	</div>
 





 





 