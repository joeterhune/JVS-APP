#!/usr/bin/perl

use ICMS;

# test -- test connectivity to dbh database.


if (!dbconnect("wpb-images")) {
print "dbname=$dbname\n";
print "dbhost=$dbhost\n";
print "dbpath=$dbpath\n";
print "user name=$user\n";
print "password=$pass\n";
 print"Can't connect to image database server...";}
print " Iam connected to Image DB!!!!!\n";
 
