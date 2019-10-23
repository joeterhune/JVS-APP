#!/usr/bin/perl

use ICMS;

# test -- test connectivity to dbh database.

if (!dbconnect("wpb-banner-rpt")) {
print "dbname=$dbname\n";
print "dbhost=$dbhost\n";
print "dbpath=$dbpath\n";
print "user name=$user\n";
print "password=$pass\n";
 print "Can't connect to J10 reports database server..."; }
print "I am connected to J10 banner db!!!!!\n";
