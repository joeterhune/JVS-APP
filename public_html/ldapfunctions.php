<?php

// -----------------------------------------------------------------------------
// ldapgroups.txt processing functions
// -----------------------------------------------------------------------------

//
// Read the ldapgroups.txt text file to determine if a user is in a group.
// Case insensitive compare.
//
// Returns true if the user is part of the group.  Else, false (including if
// the file is not found.
//

$CAD_OU="Enterprise";
$LDAPHOST = "ldaps://pbcgccdc1.pbcgov.org";
$LDAPBINDDN = "cn=cad icms,ou=Services,ou=CAD,ou=$CAD_OU,DC=PBCGOV,DC=ORG";
$LDAPBINDPW = "password99";
$LDAPBASE = "ou=Users,ou=CAD,ou=$CAD_OU,dc=PBCGOV,dc=ORG";
$LDAPSVCBASE = "ou=Services,ou=CAD,ou=$CAD_OU,dc=PBCGOV,dc=ORG";

function inGroup($user,$group) {
	global $LDAPHOST;
	global $LDAPBINDDN;
	global $LDAPBINDPW;
	global $LDAPBASE;
	global $LDAPSVCBASE;

	if ((!isset($user)) || (!isset ($group))) {
        return 0;
    }

	$ldapFilter = "(sAMAccountName=$user)";

	$fields = array('distinguishedName');
	putenv('LDAPTLS_REQCERT=never');
	$ldap = ldap_connect($LDAPHOST);

	if (!ldap_bind($ldap,$LDAPBINDDN,$LDAPBINDPW)) {
		return 0;
	}

	$result = ldap_search($ldap,$LDAPBASE,$ldapFilter,$fields);
	$users = ldap_get_entries($ldap,$result);

	if ($users['count'] == 0) {
		return 0;
	} else {
		# Ok, we now know the user's DN; check the group
		$userdn = $users[0]['dn'];

		# Get the DN of the group
		$ldapFilter = "(sAMAccountName=$group)";
		$ldapBase = "ou=CAD,ou=Enterprise,dc=PBCGOV,dc=ORG";

		$result = ldap_search($ldap,$ldapBase,$ldapFilter,$fields);
		$groups = ldap_get_entries($ldap,$result);
		if ($groups['count'] == 0) {
			return 0;
		} else {
			// Ok, we also have the group
			$groupdn = $groups[0]['dn'];

			$ldapFilter = "(memberof:1.2.840.113556.1.4.1941:=$groupdn)";
			$result = ldap_search($ldap,$userdn,$ldapFilter,$fields);
			$matches = ldap_get_entries($ldap,$result);
			if ($matches['count'] == 0) {
				return 0;
			} else {
				// This will indicate a match
				return 1;
			}
		}
	}

	// We really shouldn't be here
	return 0;
}


?>
