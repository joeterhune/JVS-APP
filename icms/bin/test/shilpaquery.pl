
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

//$dbconn is your db connection
$tableList = pg_exec("select * from pg_tables");
$numrows = pg_numrows($tableList);
print "Number of rows = $numrows<BR>";
for ($i=0; $i < $numrows; $i++) {
$tab_rows = pg_fetch_row($tableList, $i);
print "TableName[$i]: $tab_rows[0]<BR>\n";
};

