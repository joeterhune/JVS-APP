package ICMS15;

BEGIN {
    use lib "$ENV{'PERL5LIB'}";
}

use strict;
use warnings;

use Common qw (
    dumpVar
);

use DB_Functions qw (
    dbConnect
    getData
    getDataOne
    doQuery
    ldapLookup
    lastInsert
);

use POSIX qw (
    strftime  
);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    load_module_config
    save_module_config
    no_cache_header
    get_group_memberships
);

sub get_group_memberships {
    my $user = shift;
    my $groupref = shift;
    my $ldap = shift;
    
    # First, get the user's DN from AD
    my $ldapFilter = sprintf('sAMAccountName=%s', $user);
    my $users = [];
    ldapLookup($users, $ldapFilter,$ldap,['sAMAccountName','distinguishedName']);
    if (defined($users)) {
        my $userRec = $users->[0];
        
        # Ok, now we know the user's DN.  Find any ICMS groups that this person is a member of.  Be sure to specify
        # the different search base!
        my $newFilter = sprintf('(&(sAMAccountName=CAD-ICMS-*)(member=%s))', $userRec->{'distinguishedName'});
        
        my $groups = [];
        ldapLookup($groups, $newFilter, $ldap, ['sAMAccountName'],'ou=Services,ou=CAD,ou=Enterprise,dc=jud12.flcourts,dc=ORG');
        
        foreach my $group (@{$groups}) {
            $groupref->{$group->{'sAMAccountName'}} = 1;
        }
    }
}

sub load_module_config {
    my $user = shift;
    my $module = shift;
    
    my $dbh = dbConnect("icms");
    my $query = qq {
        SELECT
            json
        FROM
            config
        WHERE
            user = ?
            and module = ?
    };

    my $config = getDataOne($query, $dbh, [$user, $module]);
    
    my $json = JSON->new->allow_nonref;

    if (defined($config)) {
        return $json->decode($config->{'json'});
    } else {
        return new_module_config($user,$module);
    }
}

sub new_module_config {
    my $user = shift;
    my $module = shift;
    
    my $json = {};
    my $count = save_module_config($user, $module, $json);

    return $json;
}

sub save_module_config {
    my $user       = shift;
    my $module     = shift;
    my $config_ref = shift;
    
    my $dbh = dbConnect("icms");
    
    my $json = JSON->new->allow_nonref;
    $dbh->begin_work;
    
    my $query = qq {
        delete from
            config
        where
            module = ?
            and user = ?
    };
    doQuery($query, $dbh, [$module, $user]);
    
    $query = qq {
        replace into
            config (
                user,
                module,
                json
            )
        values (?,?,?)
    };
    my $count = doQuery($query, $dbh, [$user, $module, $json->encode($config_ref)]);
    $dbh->commit;
    
    return $count;
}



sub no_cache_header {
   print CGI::header(
    # date in the past
    -expires       => 'Sat, 26 Jul 1997 05:00:00 GMT',
    # always modified
    -Last_Modified => strftime('%a, %d %b %Y %H:%M:%S GMT', gmtime),
    # HTTP/1.0
    -Pragma        => 'no-cache',
    # HTTP/1.1 + IE-specific (pre|post)-check
    -Cache_Control => join(', ', qw(
        private
        no-cache
        no-store
        must-revalidate
        max-age=0
        pre-check=0
        post-check=0
    )),
    );
}


1;
