#!/usr/bin/perl

#
# savesettings.cgi saves the settings info from the /icms/settings/index.cgi 
#                  page to a JSON file for this user.
#

BEGIN {
    use lib $ENV{'PERL5LIB'};
}

use CGI;
use JSON;
use ICMS15 qw (
    save_module_config
);
use strict;

use Common qw (
    dumpVar
    getUser
);

use DB_Functions qw (
    dbConnect
    getData
    doQuery
);

# rebuild_sharedqueues_settings rebuilds the sharedqueues settings for
# ALL users 

sub rebuild_sharedqueues_settings {
    my $dbh = shift;
    my @arr;
    
    my $query = qq {
        select
            user,
            json
        from
            config
        where
            module='config'  
    };
    getData(\@arr, $query, $dbh);
    
    my %sharedqueue;
    foreach my $elem (@arr) {
        my($user,$json)=($elem->{'user'},$elem->{'json'});
        
        my $config=decode_json $json;
        
        my $sharedwith=$config->{"shared_with"};
        
        if ($sharedwith ne "") {
            # a setting
            my @recips=split ',',$sharedwith;
            foreach my $recip (@recips) {
                if ($sharedqueue{$recip}) {
                    $sharedqueue{$recip}.=",$user";
                } else {
                    $sharedqueue{$recip}.=$user;
                }
            }
        }
    }
    
    # Delete any old ones for each user, then re-add them.
	$query = qq {
		delete from
	    	config
	    where
	    	module = 'sharedqueues'
	};
	doQuery($query, $dbh);
    
    foreach my $key (sort keys %sharedqueue) {

		#Now re-add them
    	if($sharedqueue{$key} ne ""){
	        $query = qq {
	            replace into
	                config (
	                    user,
	                    module,
	                    json
	                ) values (
	                   ?,?,? 
	                )
	        };
	        doQuery($query, $dbh, [$key, 'sharedqueues', $sharedqueue{$key}]);
        }
    }
}

sub rebuild_sharednotes_settings {
    my $dbh = shift;
    my @arr;
    
    my $query = qq {
        select
            user,
            json
        from
            config
        where
            module='config'  
    };
    getData(\@arr, $query, $dbh);
    
    my %sharedqueue;
    foreach my $elem (@arr) {
        my($user,$json)=($elem->{'user'},$elem->{'json'});
        
        my $config=decode_json $json;
        
        my $sharedwith=$config->{"priv_notes_shared_with"};
        
        if ($sharedwith ne "") {
            # a setting
            my @recips=split ',',$sharedwith;
            foreach my $recip (@recips) {
                if ($sharedqueue{$recip}) {
                    $sharedqueue{$recip}.=",$user";
                } else {
                    $sharedqueue{$recip}.=$user;
                }
            }
        }
    }
    
    # Delete any old ones for each user
	$query = qq {
		delete from
	    	config
	    where
	    	module = 'sharednotes'
	};
	doQuery($query, $dbh);
    
    foreach my $key (sort keys %sharedqueue) {

		#Now re-add them
    	if($sharedqueue{$key} ne ""){
	        $query = qq {
	            replace into
	                config (
	                    user,
	                    module,
	                    json
	                ) values (
	                   ?,?,? 
	                )
	        };
	        
	        doQuery($query, $dbh, [$key, 'sharednotes', $sharedqueue{$key}]);
        }
    }
}

sub rebuild_transferlist_settings {
    my $dbh = shift;
    my $transfer_to = shift;
    my @arr;
    
    my $query = qq {
        select
            user,
            json
        from
            config
        where
            module='config'  
    };
    getData(\@arr, $query, $dbh);
    
    my %transferqueue;
    foreach my $elem (@arr) {
        my($user,$json)=($elem->{'user'},$elem->{'json'});
        
        my $config=decode_json $json;
        
        my $transfer_to=$config->{"transfer_to"};
        
        if ($transfer_to ne "") {
            # a setting
            my @recips=split ',',$transfer_to;
            foreach my $recip (@recips) {
                if ($transferqueue{$recip}) {
                    $transferqueue{$recip}.=",$user";
                } else {
                    $transferqueue{$recip}.=$user;
                }
            }
        }
    }
    
    # Delete any old ones for this user, then re-add them.
    $query = qq {
        delete from
            config
        where
            module = 'transferlist'
        and 
        	user = ?
    };
    doQuery($query,$dbh,[lc(getUser())]);
    
    #foreach my $key (sort keys %transferqueue) {
        $query = qq {
            replace into
                config (
                    user,
                    module,
                    json
                ) values (
                   ?,?,? 
                )
        };
        doQuery($query, $dbh, [lc(getUser()), 'transferlist', $transfer_to]);
    #}
}



my $info = new CGI;

my %params = $info->Vars;

my $user = lc(getUser());

my $email = $params{'email'};
my $filings = $params{"filings"};
my $calendars = $params{"calendars"};
my $reports = $params{"reports"};
my $queues = $params{"queues"};
my $alerts = $params{"alerts"};

my %settings = ();

$settings{'filings'} = $filings;
$settings{'calendars'} = $calendars;
$settings{'reports'} = $reports;
$settings{'queues'} = $queues;
$settings{'alerts'} = $alerts;
$settings{'email'} = $email;

print STDERR $settings{'alerts'};

$settings{'opt_cal_dragdrop'} = $params{'opt_cal_dragdrop'};
$settings{'docviewer'} = $params{'docviewer'};
$settings{'pdf_toolbar'} = $params{'pdf_toolbar'};
$settings{'pdf_scrollbar'} = $params{'pdf_scrollbar'};
$settings{'pdf_statusbar'} = $params{'pdf_statusbar'};
$settings{'pdf_navpanes'} = $params{'pdf_navpanes'};
$settings{'pdf_view'} = $params{'pdf_view'};
$settings{'pdf_viewer'} = $params{'pdf_viewer'};
$settings{'pdf_zoom'} = $params{'pdf_zoom'};
$settings{'shared_with'} = $params{'shared_with'};
$settings{'priv_notes_shared_with'} = $params{'priv_notes_shared_with'};
$settings{'transfer_to'} = $params{'transfer_to'};

save_module_config($user, 'config', \%settings);

my $dbh=dbConnect("icms");
my $query = qq {
    update
        users
    set
        email = ?
    where
        userid = ?
};

doQuery($query,$dbh,[$email, $user]);

print $info->header();

$dbh->begin_work;
rebuild_sharedqueues_settings($dbh);
rebuild_sharednotes_settings($dbh);
rebuild_transferlist_settings($dbh, $params{'transfer_to'});
$dbh->commit;

#print $info->header();
print "OK";
