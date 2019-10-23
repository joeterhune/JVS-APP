<?php
set_time_limit(30);
error_reporting(E_ALL);
ini_set('error_reporting', E_ALL);
ini_set('display_errors',1);

// config
$ldapserver = 'JUDSARDC05.jud12.local';
$ldapuser      = 'jud12\XeroxLDAP';  
$ldappass     = 'magi$ter';
$ldaptree    = "DC=JUD12,DC=LOCAL";

// connect 
$ldapconn = ldap_connect($ldapserver) or die("Could not connect to LDAP server.");
ldap_set_option($ldapconn, LDAP_OPT_PROTOCOL_VERSION, 3);
ldap_set_option($ldapconn, LDAP_OPT_REFERRALS, 0);
if($ldapconn) {
    // binding to ldap server
    $ldapbind = ldap_bind($ldapconn, $ldapuser, $ldappass) or die ("Error trying to bind: ".ldap_error($ldapconn));
    // verify binding
    if ($ldapbind) {
        echo "LDAP bind successful...<br /><br />";
        $filter = "(&(objectClass=user)(sAMAccountName=dmenendez))";
        $result = ldap_search($ldapconn,$ldaptree,$filter) or die ("Error in search query: ".ldap_error($ldapconn));
        $data = ldap_get_entries($ldapconn, $result);
        
        // SHOW ALL DATA
        echo '<h1>Dump all data</h1><pre>';
        print_r($data);    
        echo '</pre>';        
    } else {
        echo "LDAP bind failed...";
    }

}

// all done? clean up
ldap_close($ldapconn);
?>