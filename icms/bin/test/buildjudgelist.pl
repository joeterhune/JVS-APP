#!/usr/bin/perl
# buildjudgelist: this program creates the /usr/local/icms/etc/judgepage.conf

use ICMS;
use strict;

dbconnect("wpb-banner-rpt");

my @list=sqllist("select distinct spriden_pidm from cdbcase,spriden,cdrcpty where spriden_pidm=cdrcpty_pidm and cdrcpty_case_id=cdbcase_id and cdrcpty_ptyp_code='JUDG' and (cdbcase_dtyp_code_status<>'CLSD' or cdbcase_dtyp_code_status is null) and cdbcase_cort_code in ('CF','MM','MO','CO','CT')");
my $jpidms=join ',',@list;
$jpidms=~s/,/','/g;
$jpidms="'".$jpidms."'";

# using a hash on spriden_pidm will suppress any duplicate names for a given pidm...
my %jnames=sqlhash("select spriden_pidm,spriden_last_name,spriden_first_name,spriden_mi,spriden_id from spriden where spriden_pidm in ($jpidms)");

my @div;
my @list2;
foreach (keys %jnames) {
    my($pidm,$last,$first,$middle,$id)=split '~',$jnames{$_};
    push @list2,"$last, $first $middle~$pidm~$id\n";
    push @div,"$id~$last, $first $middle\n";
}
@list2=sort @list2;
open OUTFILE,">/usr/local/icms/etc/judgepage.conf" or die "Nope!";
print OUTFILE @list2;
close OUTFILE;

#@div=sort(@div);
#print @div;
