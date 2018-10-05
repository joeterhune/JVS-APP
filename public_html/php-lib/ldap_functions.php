<?php
function ldapLookup(&$data, $filter, $config, $ldap=null, $fields, $base, $scope=null) {
    if ($ldap == null) {
        $host = (string) $config->{'ldapHost'}[0];
        $ldap = ldap_connect($config->ldapHost[0]);
        $r = ldap_bind($ldap, $config->{'bindDn'}, $config->{'bindPw'});
    }
    
    if ($base == null) {
        $base = (string) $config->{'ldapBase'};
    }
    
    $sr = ldap_search($ldap, $base, $filter, $fields);
    
    $data = ldap_get_entries($ldap, $sr);
}

?>