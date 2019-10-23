
	<div class='col-md-12' style="padding: 20px;">
	<h3 style="padding-left: 20px;">Add Portal User</h3>
	</div>


	<div class="col-md-6 col-sm-6">
		 <h3> Steps </h3>
		<hr>
	 	<ol>
			<li> <a href="https://www.myflcourtaccess.com/default.aspx" target="_blank" > Login to Portal (myflcourtaccess.com)</a> </li>
			<li>Go to Judicial Review > Administration > Fifteenth Circuit Judicial Profile > Users > New </li>
			<li>For the username, use the format “ADusername_15th.”  THOs are prefixed with tho_ and mediators are prefixed with med_.  For example: lkries_15th, tho_lkries_15th, or med_lkries_15th.  Select the appropriate role (Judge, Mediator, Hearing Officer, Magistrate.)  </li>
			<li>Use the Florida bar lookup to find the user’s Bar number - <a href="https://www.floridabar.org/directories/find-mbr/" target="_blank">https://www.floridabar.org/directories/find-mbr/</a>. For the primary e-mail, enter your own e-mail address, because you will need to confirm the account.
			</li>
			<li>When you receive the confirmation e-mail, click the link.  Login to the account with the username you just created, and use the temporary password <b>eportal</b>.</li>
			<li>Change the password to viewer15.  Choose a security question and answer. <br> After you have confirmed, you will receive another e-mail.
			</li>
			<li>Log back in to the Portal using our admin account (jud15) and change the e-mail address on the newly created account.  If it’s a Judge, use his/her divisional address (CAD-DivisionXX@pbcgov.org.)  For Magistrates and Mediators, user their personal e-mail address.  For THOs, use CAD-THO@pbcgov.org.  </li>
			
			
		</ol>
	</div>
	 
	<div class="col-md-6 col-sm-6" >
	<h3>  Add Portal Filer </h3>
		<hr>
		<form action="xAddPortalUser.php" method="post" style="padding-left: 20px;">
			
			<div class='form-group col-md-6' >
				<label> User Id </label>
			 	<input type="text" name="userId" placeholder="" class='form-control '>
			</div>
			<div class='form-group col-md-6' >
				<label for="portalId"> 	Portal Id </label>
			 	<input type="text" name="portalId" placeholder="" class='form-control'>
			</div>
			<div class='form-group col-md-6' >
				<label> Password </label>
				<input type="text" name="password" placeholder="" style="color: #ccc; background-color: #fafafa; border: 1px solid #ccc" class='form-control'>
			</div>
			<div class='form-group col-md-6' >
				<label> Bar Number </label>
				<input type="text" name="barNumber" placeholder="" class='form-control'>
			</div>
			<div class='form-group col-md-6' >
				<label> User Type </label>
			 	<select name='userType' class='form-control'>
					{foreach from=$userType item=type}
					<option value="{$type["portal_user_type_id"]}">  {$type["portal_user_type_desc"]} </option>
					{/foreach}
				</select>
			</div>
		
			
			<div class='form-group col-md-12' >
				<br >
				<input type="submit" value="Add User">
			</div>

		</form>
		 
	</div>
	 
 


