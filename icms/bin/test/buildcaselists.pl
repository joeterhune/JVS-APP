#!/usr/bin/perl

use ICMS;
use strict;

#my @list=sqllist("select spriden_id,spriden_last_name,spriden_first_name,spriden_mi from spriden where spriden_pidm=$judge");

dbconnect("wpb-banner-rpt");
my @list=sqllist("select cdbcase_id,cdbcase_dtyp_code_status from cdbcase where (cdbcase_dtyp_code_status<>'CLSD' or cdbcase_dtyp_code_status is null) and cdbcase_cort_code='CF' order by cdbcase_id");
print scalar @list," Felony Cases found";
open OUTFILE,">felony.txt" or die "Nope!";
foreach (@list) { print OUTFILE "$_\n"; }
close OUTFILE;

my @list=sqllist("select cdbcase_id,cdbcase_dtyp_code_status from cdbcase where (cdbcase_dtyp_code_status<>'CLSD' or cdbcase_dtyp_code_status is null) and cdbcase_cort_code in ('MM','MO','CO','CT') order by cdbcase_id");
print scalar @list," Misdemeanor Cases found";
open OUTFILE,">mis.txt" or die "Nope!";
foreach (@list) { print OUTFILE "$_\n"; }
close OUTFILE;
