
#!/usr/bin/perl

use ICMS;

# test -- test connectivity to dbh database.

if (!dbconnect("icms")) {
print "dbname=$dbname\n";
print "dbhost=$dbhost\n";
print "dbpath=$dbpath\n";
print "user name=$user\n";
print "password=$pass\n";
 print "Can't connect to casenotes database server..."; }
print "I am connected to casenotes db!!!!!\n";

