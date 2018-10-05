<?php
require_once("php-lib/common.php");
require_once("php-lib/db_functions.php");

################################################
#    icmslib.php - PHP library for ICMS        #
################################################
# derived from OpenCourt's oclib.php 

# next five vars used by sqlconnect, which is deprecated; use db_connect
# instead...
$DBH="";
$CONFIG['DBTYPE']="mysql";
$CONFIG['DBNAME']="icms";
$CONFIG['DBUSER']="icmsuser";
$CONFIG['DBPASS']="2Acc3ss";
$USER=strtolower($_SESSION['user']);
$ROLE=""; # the short subcategory of a role (JUDGE,JA,GM,STAFF)
$FULLROLE="";
$FULLNAME="";
$TODAY=date("m/d/Y");
$SETTINGS=array(); # system-wide settings from database...
$PROFILE=getenv("DBPROFILE");  # set for DBPROFILE stderr output...

$PROFCOUNT=0;
$PROFTOT=0;
$PROFMAX=0;
$PROFMIN=9999;

$WEBPATH="/icmsdata/workflow/documents";
$DOCPATH="/var/www$WEBPATH";
//$SIGPATH="/var/icms/conf/signatures"; # where raw esigs are stored...
$SETTINGSPATH="/var/www/icmsdata/settings"; # user settings stored here
$TMPPATH="/var/www/icmsdata/tmp"; # temp files go here...
$GROUPS=array();

################## SQL ROUTINES (via OpenCourt) ##################
$CONFPATH = "/usr/local/icms/etc";
$DATABASES="";

#
# has_allow_group returns a 1 if the system has an ALLOW group defined, 0 otherwise.
#
function has_allow_group() {
  $str=`grep ^ALLOW /var/icms/conf/ldap.conf`;
  if ($str!="") { return 1; }
  return 0;
}

#
# is_conf_file returns 1 if a conf file exists, 0 otherwise
#
function is_conf_file($confname) {
   global $CONFPATH;
   $fpath="$CONFPATH/$confname";
   if (file_exists($fpath)) { return 1; }
   return 0;
}


#
# load_conf_file loads a given JSON configuration file and 
#                returns a PHP object.

function load_conf_file($confname) {
   global $CONFPATH;
   $fpath="$CONFPATH/$confname";
   if (!file_exists($fpath)) {
      echo "load_conf_file: can't load $fpath\n";
      exit(1);
   }

   return json_decode(file_get_contents($fpath));
}


# load_settings_file loads the specified JSON settings file, or returns NULL
# it's a stub that actually now loads the settings info from the database...

function load_settings_file($filename) {
   $filename=strtolower($filename); # force lowercase
   $userid=str_replace(".json","",$filename);
   $dbh=db_connect("icms");
   $jsonarr=sqlarrayp($dbh,"select json from config where user=? and module='config'",array($userid));
   $json=$jsonarr[0][0];
#   $json=sqlgetonep($dbh,"select json from config where user=? and module='config'",array($userid));
   if ($json=="") { return false; }
   return json_decode($json);
}

#
# get_user_config returns an object from the config table 
# for the userid and config type specified

function get_user_config($userid,$config,$icmsdb) {
   $jsonarr=sqlarrayp($icmsdb,"select json from config where user=? and module=?",array($userid,$config));
   $json=$jsonarr[0][0];
   if ($json=="") { return false; }
   return json_decode($json);
} 


#
# db_connect() connects to any database defined in the Databases.json file...
#
//function db_connect($dbname) {
//   global $DATABASES,$DBH;
//   if ($DATABASES=="") { # first time use...
//      $DATABASES=load_conf_file("Databases.json");
//   }
//   if (!$DATABASES->{$dbname}) { 
//      echo "db_connect: Error looking up database $dbname\n";
//      exit(1);
//   }
//   # Databases.json was set up for Perl DBI, so we do some transmogrification
//   $data_source=$DATABASES->{$dbname}->{data_source};
//   $username=$DATABASES->{$dbname}->{username};
//   $password=$DATABASES->{$dbname}->{password};
//   $host_ip=$DATABASES->{$dbname}->{host_ip};
//   $port=$DATABASES->{$dbname}->{port};
//   $database_name=$DATABASES->{$dbname}->{database_name};
//    if ($port=="") { $port="1433"; }
//   if ($host_ip=="" || $database_name=="") {
//     echo "db_connect: Error: need a host_ip and database_name specified in Databases.json for $dbname (for now)\n";
//     exit(1);
//   }
//#   echo "data source is $data_source: $host_ip, $database_name, $username, $password\n";
//   if (preg_match('/Sybase/',$data_source,$matches)) { # microsoft sql server
//      try {
//        $connstring="dblib:host=$host_ip:$port;dbname=$database_name";
//        $DBH=new PDO($connstring,$username,$password);
//      } catch (PDOException $e) {
//         print "SQLconnect Error!: ".$e->getMessage()." for $connstring<br>";
//         die();
//      }
//      return $DBH;
//   } elseif (preg_match('/mysql/',$data_source,$matches)) { # mysql
//      try {
//        $connstring="mysql:host=$host_ip;dbname=$database_name";
//        $DBH=new PDO($connstring,$username,$password);
//      } catch (PDOException $e) {
//         print "SQLconnect Error!: ".$e->getMessage()." for $connstring<br>";
//         die();
//      }
//      return $DBH;
//   } elseif (preg_match('/Pg/',$data_source,$matches)) { # postgresql
//      try {
//        $connstring="pgsql:host=$host_ip;dbname=$database_name";
//        $DBH=new PDO($connstring,$username,$password);
//      } catch (PDOException $e) {
//         print "SQLconnect Error!: ".$e->getMessage()." for $connstring<br>";
//         die();
//      }
//      return $DBH;
//   } elseif (preg_match('/Informi/',$data_source,$matches)) { # informix
//      putenv("INFORMIXDIR=/opt/IBM/informix"); # need this for the Informix Client stuff...
//      $connstring=$DATABASES->{$dbname}->{pdo_dsn};
//      if ($connstring=="") {
//          echo "db_connect: Error: need a pdo_dsn set in Databases.json for $dbname\n";
//          exit(1);
//      }
//      try {
//        $DBH=new PDO($connstring,$username,$password);
//      } catch (PDOException $e) {
//         print "SQLconnect Error!: ".$e->getMessage()." for $connstring<br>";
//         die();
//      }
//      return $DBH;
//   } else {
//      echo "db_connect: Unknown database type for $dbname\n";
//      exit(1);
//   }
//}



#
# db_exists returns 1 if a database exists in the config file...
#
function db_exists($dbname) {
   global $DATABASES,$DBH;
   if ($DATABASES=="") { # first time use...
      $DATABASES=load_conf_file("Databases.json");
   }
   if (!$DATABASES->{$dbname}) { 
      return 0;
   }
   return 1;
}


#
# profstat records statistics collected by the sqlarrayp command with $PROFILE set..
#

function profstat($elapsed) {
  global $PROFCOUNT,$PROFTOT,$PROFMAX,$PROFMIN;
  $PROFCOUNT++;
  $PROFTOT+=$elapsed;
  if ($PROFMAX<$elapsed) { $PROFMAX=$elapsed; }
  if ($PROFMIN>$elapsed) { $PROFMIN=$elapsed; }
}

function profresults() {
  global $PROFCOUNT,$PROFTOT,$PROFMAX,$PROFMIN;
  $profavg=$PROFTOT/$PROFCOUNT;
  file_put_contents('php://stderr',"$PROFCOUNT queries, $PROFTOT total seconds\n$profavg average, $PROFMIN minimum, $PROFMAX maximum\n"); 
}

#
# sqlarrayp returns a two-dimensional array, via a parameterized call
#
function sqlarrayp($dbh,$query,$params) {
   global $PROFILE;
   if ($PROFILE) { $st=microtime(true); }
   try {
      $pdo=$dbh->prepare($query);
      if ($pdo===false) { 
         echo "Error: "; 
         print_r($dbh->errorInfo()); 
         return (array()); 
      }
      if ($pdo->execute($params)===false) {
         echo "Error: $query***\n<br>",print_r($params),"<br>",print_r($pdo->errorInfo());
      }
      $x=$pdo->fetchAll(PDO::FETCH_NUM);
      if ($PROFILE) { 
         $elapsed=microtime(true)-$st;
         file_put_contents('php://stderr',"*** $elapsed sec for\n   $query\n"); 
         profstat($elapsed); # record stats...
        }
      return $x;
   } catch (PDOException $e) {
      print "Error!: ".$e->getMessage()."<br>";
      die();
   }
}


#
# sqlhashp returns a two-dimensional associative array via a parameterized call
#
function sqlhashp($dbh,$query,$params) {
   global $PROFILE;
   if ($PROFILE) { $st=microtime(true); }
   try {
      $pdo=$dbh->prepare($query);
      if ($pdo===false) { return (array()); }
      if (!$pdo->execute($params)) {
         echo "Error: $query\n<br>";
      }
      if ($PROFILE) { 
         $elapsed=microtime(true)-$st;
         file_put_contents('php://stderr',"$elapsed sec for\n   $query\n"); 
         profstat($elapsed); # record stats...
        }
      return $pdo->fetchAll(PDO::FETCH_ASSOC);
   } catch (PDOException $e) {
      print "Error!: ".$e->getMessage()."<br>";
      die();
   }
}




#
# sqlgetonep returns a single value from a query via a paramaterized query
#
function sqlgetonep($dbh,$query,$params) {
    global $PROFILE;
    if ($PROFILE) {
        $st=microtime(true);
    }
    
    try {
        $res=$dbh->prepare($query);
        if ($res===false) {
            return "";
        }
        $res->execute($params);
        $vals=$res->fetchAll(PDO::FETCH_NUM);
        if (count($vals)>1) {
            echo "sqlgetonep: more than one result!".count($vals);
        }
        if ($PROFILE) {
            $elapsed=microtime(true)-$st;
            file_put_contents('php://stderr',"$elapsed sec for\n   $query\n");
            profstat($elapsed); # record stats...
        }
        return $vals[0][0];
    } catch (PDOException $e) {
        print "Error!: ".$e->getMessage()."<br>";
        die();
    }
}


#
# sqlgetonerowp returns a single row from a query via a paramaterized query
#
function sqlgetonerowp($dbh,$query,$params) {
   global $PROFILE;
   if ($PROFILE) { $st=microtime(true); }
   try {
      $res=$dbh->prepare($query);
      if ($res===false) { return ""; }
      $res->execute($params);
      $vals=$res->fetchAll(PDO::FETCH_NUM);
      if (count($vals)>1) {
         echo "sqlgetonerowp: more than one result!";
       }
      if ($PROFILE) { 
         $elapsed=microtime(true)-$st;
         file_put_contents('php://stderr',"$elapsed sec for\n   $query\n"); 
         profstat($elapsed); # record stats...
        }
       return $vals[0];
   } catch (PDOException $e) {
      print "Error!: ".$e->getMessage()."<br>";
      die();
   }
}


#
# sqlexecp executes a query and returns true on success, false on failure
#

function sqlexecp($dbh,$query,$params) {
   global $PROFILE;
   if ($PROFILE) { $st=microtime(true); }
   try {
      $sth=$dbh->prepare($query);
      if ($sth===false) { return false; }
      $res=$sth->execute($params);
      if ($PROFILE) { 
         $elapsed=microtime(true)-$st;
         file_put_contents('php://stderr',"$elapsed sec for\n   $query\n"); 
         profstat($elapsed); # record stats...
        }
      return $res;
   } catch (PDOException $e) {
      print "Error!: ".$e->getMessage()."<br>";
      file_put_contents('php://stderr',"SQL ERROR: ".$e->getMessage(),FILE_APPEND);
      return false;
   }
}



###########################################
### LEGACY SQL ROUTINES (DEPRECATED);
############################################


#
# sqlarray returns a two-dimentional array
#
function sqlarray($query) {
  global $DBH;
   try {
      $pdo=$DBH->query($query);
      if ($pdo===false) { return (array()); }
      return $pdo->fetchAll(PDO::FETCH_NUM);
   } catch (PDOException $e) {
      print "Error!: ".$e->getMessage()."<br>";
      die();
   }
}


#
#
# sqlgetonerow returns a single row of data from a query
#
function sqlgetonerow($query) {
  global $DBH;
   try {
      $res=$DBH->query($query);
      $vals=$res->fetchAll(PDO::FETCH_NUM);
      return $vals[0];
   } catch (PDOException $e) {
      print "Error!: ".$e->getMessage()."<br>";
      die();
   }
}


#
# sqlgetone returns a single value from a query
#
function sqlgetone($query) {
  global $DBH;
   try {
      $res=$DBH->query($query);
      $vals=$res->fetchAll(PDO::FETCH_NUM);
       return $vals[0][0];
   } catch (PDOException $e) {
      print "Error!: ".$e->getMessage()."<br>";
      die();
   }
}


#
# sqlexec executes a query and returns the # of affected rows
#

function sqlexec($query) {
  global $DBH;
   try {
      $x=$DBH->exec($query);
      return $x;
   } catch (PDOException $e) {
      print "Error!: ".$e->getMessage()."<br>";
      return -1;
   }
}

###########################################################


#
# get_setting returns the value of a given setting string in the $SETTINGS table
#
function get_setting($setkey) {
    global $SETTINGS;
    return($SETTINGS[$setkey]);
}

#
# set_setting updates a setting in the settings table, and the local $SETTINGS 
#            array...
#
function set_setting($setkey,$setval) {
   global $SETTINGS;
   # connect to the db if you haven't already...
   $dbh=db_connect("icms");
   $res=sqlgetonerowp($dbh,"select setkey from settings where setkey=?",array($setkey));
   if ($res=="") { # a new key, add it.
      $res=sqlexecp($dbh,"insert into settings (setkey,setval) values (?,?)",array($setkey,$setval));
      if ($res!=1) {
         echo "Error updating settings: return value $res<br>";
         exit;
      }
   } else {
       # update it...
       $res=sqlexecp($dbh,"update settings set setval='$setval' where setkey=?",array($setkey));
    }
   $SETTINGS[$setkey]=$setval;
}




#
# load_system_settings() loads the $SETTINGS array from the ICMS DB
#
function load_system_settings() {
    global $SETTINGS;
    $dbh = dbConnect("icms");
    $arr = array();
    $query = "
        select
            setkey,
            setval
        from
            settings
    ";
    getData($arr,$query,$dbh);
    foreach ($arr as $row) {
        $SETTINGS[$row['setkey']]=$row['setval'];
    }
}

function get_user_config_json($dbh,$user){
   $arr=sqlarrayp($dbh,"SELECT module,json FROM config WHERE (user='ALL' || user=?) AND module IN('views', 'config', 'default_views')",array($user));
   $config = array();
   foreach ($arr as $row) {
    $config[$row[0]] = $row[1]; 
   }

   return $config;
}


################## END SQL ROUTINES (via OpenCourt) ##################


function get_image_dir($ucn) {
    return substr($ucn,0,2)."/".substr($ucn,3,4)."/".substr($ucn,8,2)."/".substr($ucn,11,3)."/".$ucn;
}

#
# get_full_image_path takes a ucn and did and returns the full path to
#                     the file, if it exists; it creates the parent
#                     directory if it doesn't already exist as well
#

function get_full_image_path($ucn,$did) {
    $dir=get_image_dir($ucn);
    $fullpath="/var/www/icmsdata/documents/$dir";
    if (!is_dir($fullpath)) { mkdir($fullpath,0777,true); } # create the directory path owned by www-data.
    return "$fullpath/$ucn.$did.pdf";
}

#
# get_web_image_path returns the path to the image for $ucn & $did
#
function get_web_image_path($ucn,$did) {
    $dir=get_image_dir($ucn);
    return "/icmsdata/documents/$dir/$ucn.$did.pdf";
}


#
# getres returns (x,y) resolution for an image file
#
function getres($file) {
  $line=`/usr/bin/file $file`;
  if (preg_match("#(\d+ x \d+)#",$line,$matches)) {
     $list=explode("x",$matches[1]);
     $list[0]=intval($list[0]);
     $list[1]=intval($list[1]);
     return($list);
  }
  return(array());
}


#
# pretty_timeX takes a db time value and displays it in user-friendly format
#
function pretty_timeX($time) {
   if ($time=="") { return ""; }
   list($h,$m)=explode(":",$time);
   if ($h>=12) { $ampm="pm"; }
   else { $ampm="am"; }
   if ($h>12) { $h-=12; }
   if ($h==0) { $h=12; }
   return sprintf("%2d:%02d%s",$h,$m,$ampm);
}


#
# pretty_date takes a db date field and displays it in user-friendly format
#
function pretty_date($date) {
   if ($date=="") { return ""; }
   list($Y,$M,$D)=explode("-",$date);
   return sprintf("%02d/%02d/%04d",$M,$D,$Y);
}



#
# pretty_timestamp takes a timestamp pulled from a db timestamp and displays it in user-friendly format
#
function pretty_timestamp($timestamp) {
   list($date,$time)=explode(' ',$timestamp);
   $date=pretty_date($date);
   $time=pretty_timeX($time);
   return "$date $time";
}

#   list($Y,$M,$D)=explode("-",$date);
#   list($h,$m)=explode(":",$time);
#   if ($h>=12) { $ampm="pm"; }
#   else { $ampm="am"; }
#   if ($h>12) { $h-=12; }
#   if ($h==0) { $h=12; }
#   return sprintf("%d/%d/%d %2d:%02d%s",$M,$D,$Y % 100,$h,$m,$ampm);





#
# db_date takes a pretty m/d/y date and turns it into db-friendly format
#
function db_date($date) {
   if ($date=="") { return ""; }
   list($M,$D,$Y)=explode("/",$date);
   return sprintf("%04d-%02d-%02d",$Y,$M,$D);
}

#
# build_all_divs makes an array of divisions codes and names based
#                on the json config file data

function build_all_divs() {
    $counties=load_conf_file("county_db_info.json");
    $defaultdivs=load_conf_file("Divisions.Default.json");
    $divslist=array();
    if (!$counties) {
        echo "counties didn't load!<br>";
    }
    foreach ($counties as $countynum=>$val) {
        $county=$counties->{$countynum}->{name};
        $custdivs=$defaultdivs; # assume default
        if (is_conf_file("Divisions.$countynum.json")) { # custom Divisions
            $custdivs=load_conf_file("Divisions.$countynum.json");
        }
        foreach ($custdivs as $divs=>$val) {
            $divcodes=explode(',',$val->{divisions});
            $divname=$divcodes[0];
            $divslist["$countynum-$divname"]=$county." ".$val->{name};
        }
    }
   return $divslist;
}

function getDivList($dbh, &$divlist) {
    $query = "
        select
            d.division_id as DivisionID,
            d.division_type as CourtType,
            p.court_type_id as CourtTypeID,
            p.portal_court_type as PortalCourtType,
            p.portal_namespace as PortalNameSpace,
    		'0' as CustomQueue
        from
            divisions d left outer join court_type_map p on (d.division_type = p.icms_court_type)
        where
            d.show_icms_list = 1
        order by
            division_id
    ";
    getData($divlist, $query, $dbh, null, 'DivisionID', 1);
}

function getCustomQueues($dbh, &$divlist) {
	$query = "
        select
            queue_name as DivisionID,
            queue_type as CourtType,
            '' as CourtTypeID,
           '' as PortalCourtType,
            '' as PortalNameSpace,
			'1' as CustomQueue
        from
        	custom_queues
        order by
            queue_name
    ";
	getData($divlist, $query, $dbh, null, 'DivisionID', 1);
}


#
# get_division_text returns the text description of the court division for the UCN provided
#
# NOTE: Doesn't work for Alachua Split divisions...
#
function get_division_text($ucn) {
   $dbh=db_connect("icms");
   $countynum=substr($ucn,0,2);
   $div=sqlgetonep($dbh,"select division from search where ucn=? limit 1",array($ucn));
   if (!$div) { $div=substr($ucn,8,2); } # fallback to case cd...
   if (is_conf_file("Divisions.$countynum.json")) {
      $ctydivs=load_conf_file("Divisions.$countynum.json");
   } else {
      $ctydivs=load_conf_file("Divisions.Default.json");
   }
   foreach ($ctydivs as $adiv=>$vals) {
      if (strpos($vals->{divisions},$div)!==false) { return $vals->{name}; }
   }
   return "";
}


# queuesoptions returns a string listing all work queues as a series
#               of OPTIONs--division and local; it lists as 
#               selected the option you pass it as selected
# it needs a $divnames created by build_all_divs...

function queuesoptions($divnames,$selval) {
   $list=sqlarray("select userid,name from users order by userid");
   $res="";
   foreach ($list as $line) {
     if ($line[0]==$selval) { $sel="selected"; }
     else { $sel=""; }
     $res.="<option value=$line[0] $sel>$line[1]";
   }
   $res.="<option disabled style=\"background-color:lightgreen\">DIVISION QUEUES";
   foreach ($divnames as $div=>$name) {
     if ($name!="My Queue") {  $res.="<option value=$div>$name"; }
   }
   return $res;
}


 
# showqueues list all work queues to the page

function showqueues($divnames) {
   echo queuesoptions($divnames,"");
}


# showcolorstyle takes a color name and returns an appropriate style

function showcolorstyle($color) {
   if ($color=="Black" || $color=="Indigo" || $color=="Blue") { $txtcolor="color:white;"; }
   else { $txtcolor=""; }
   return "style='$txtcolor background-color:$color'";
}



# showcolors shows the options for a select statement to assign a color to a 
#            workqueue object

function showcolors() {
   $list=array("Red","Orange","Yellow","Green","Blue","Indigo","Violet","Black","Gray","White");
   foreach ($list as $color) {
      echo "<option value='$color'>$color";
   }
}



# set_user_globals set the  global variable for this user $USER 
# From $USER, sets $ROLE, $LONGROLE, and $FULLNAME

function set_user_globals($dbh) {
    global $USER,$ROLE,$FULLROLE,$FULLNAME;
    $query="
        select
            role,
            first_name as FirstName,
            middle_name as MiddleName,
            last_name as LastName,
            suffix as Suffix,
            roletype
        from
            users
        where
            userid = :user
    ";
    $vals = getDataOne($query,$dbh,array('user' => $USER));
    $role=$vals['role'];
    $name = buildName($vals);
    $roletype=$vals['roletype'];
    $FULLROLE=$role;
    $FULLNAME = $name;
    $ROLE=$roletype;
    if ($ROLE=="") {
        $ROLE="NONE";
    }
}

#
# set_groups sets the GROUPS global based on the contents of the ICMS group_cache table
#            it currently requires an icms db handle, and only sets values for those groups 
#            a user is actually in...
function set_groups($icmsdb) {
   global $USER,$GROUPS;
   $liststr=sqlgetonep($icmsdb,"select groups from group_cache where userid=?",array($USER));
   $list=explode(" ",$liststr);
   foreach ($list as $group) {
      $GROUPS{$group}=1; 
   }
}


# emailhost returns the e-mail host for this server from the LDAP configuration file

function emailhost() {
  $emailhost=`grep LDAPEMAIL /var/icms/conf/ldap.conf`;
  $emailarr=explode('=',$emailhost);
  $emailhost=substr($emailarr[1],0,-1); # the value for that key...
  return $emailhost;
}

# from http://www.finalwebsites.com/forums/topic/php-e-mail-attachment-script, with mods...

#
# mail_attachment sends an e-mail (with a file attachment) where specified...
#

function mail_attachment($file, $mailto, $from_mail, $from_name, $subject, $message) {
    $plaintext = strip_tags($message, "<br>");
    
    if(is_array($mailto)){
    	$recips = implode(",", $mailto);
    }
    else{
    	$recips = $mailto;
    }
    
    $plaintext = str_replace("<br>", "\r\n", $plaintext);
    
    $filename=basename($file);
    $content=file_get_contents($file);
    $content = chunk_split(base64_encode($content));
    $uid = md5(uniqid(time()));
    $name = basename($file);
    
    $header = "From: ".$from_name." <".$from_mail.">\r\n";
    $header .= "cc: $from_mail\r\n";
    $header .= "MIME-Version: 1.0\r\n";
    $header .= "Content-Type: multipart/alternative; boundary=\"".$uid."\"\r\n\r\n";
    //$header .= "This is a multi-part message in MIME format.\r\n";
    
    $mMessage .= "--".$uid."\r\n";
    $mMessage .= "Content-type:text/plain; charset=iso-8859-1\r\n";
    $mMessage .= "Content-Transfer-Encoding: quoted-printable\r\n\r\n";
    $mMessage .= $plaintext."\r\n\r\n";
    $mMessage .= "--".$uid."\r\n";
    
    $mMessage .= "Content-type:text/html; charset=iso-8859-1\r\n";
    $mMessage .= "Content-Transfer-Encoding: 7bit\r\n\r\n";
    $mMessage .= $message."\r\n\r\n";
    $mMessage .= "--".$uid."\r\n";

    $mMessage .= "Content-Type: application/octet-stream; name=\"".$filename."\"\r\n"; // use different content types here
    $mMessage .= "Content-Transfer-Encoding: base64\r\n";
    $mMessage .= "Content-Disposition: attachment; filename=\"".$filename."\"\r\n\r\n";
    $mMessage .= $content."\r\n\r\n";
    $mMessage .= "--".$uid."--";
    
    if (mail($recips, $subject, $mMessage, $header)) {
        return(true);
    } else {
        return(false);
    }
}


// encrypt encrypts a string using the DES algorithm 

function encrypt($str, $key)
{
    $block = mcrypt_get_block_size('des', 'ecb');
    $pad = $block - (strlen($str) % $block);
    $str .= str_repeat(chr($pad), $pad);

    return mcrypt_encrypt(MCRYPT_DES, $key, $str, MCRYPT_MODE_ECB);
}

// decrypt decrypts a string using the DES algorithm 

function decrypt($str, $key)
{
    $str = mcrypt_decrypt(MCRYPT_DES, $key, $str, MCRYPT_MODE_ECB);
    $block = mcrypt_get_block_size('des', 'ecb');
    $pad = ord($str[($len = strlen($str)) - 1]);
    return substr($str, 0, strlen($str) - $pad);
}


# returns a 1 if the given user has a work queue defined, 0 otherwise

function has_work_queue($icmsdb,$user) {
  $user=strtolower($user); # just in case.
  return sqlgetonep($icmsdb,"select count(userid) from users where userid=?",array($user));
}


#
# fix_time takes a time pulled from a filename and displays it in user-friendly format
#
function fix_time($time) {
   list($h,$m)=explode("-",$time);
   if ($h>=12) { $ampm="pm"; }
   else { $ampm="am"; }
   if ($h>12) { $h-=12; }
   if ($h==0) { $h=12; }
   return sprintf("%2d:%02d%s",$h,$m,$ampm);
   }


# show_time_options - show various time options with a 15 minute interval,
#                   showing the current value ($curval) as selected
#                   $curval must be a mysql form time value: hhmmss, or
#                   174500 for 5:45pm, for example.

function show_time_options($curval) {
  for ($h=8;$h<24;$h++) {
     for ($m=0;$m<60;$m+=5) {
#        $opttime=$h*10000+$m*100; # mysql style time value
        $pretty=fix_time("$h-$m");
#        if ($opttime==$curval) { $sel=" selected"; }
         if ($pretty==$curval) { $sel=" selected"; }
        else { $sel=""; }
        echo "<option value=\"$pretty\" $sel>$pretty";
     }
  }
}


function minutes_to_hr($m) {
   if ($m<60) { return "$m minutes"; }
   $h=$m / 60;
   $hint=intval($h);
   $frac=$h-$hint;
   if ($h==1) { return "1 hour"; }
   if ($frac==0.25) { return "$hint &frac14; hours"; }
   if ($frac==0.50) { return "$hint &frac12; hours"; }
   if ($frac==0.75) { return "$hint &frac34; hours"; }
   return "$h hours";
}


function show_event_durations($curdur) {
   $d=5;
   for ($m=10;$m<=480;$m+=$d) {
       echo "<option value=$m>".minutes_to_hr($m);
       if ($m==30) { $d=15; } # 10,15,20,15,30,45,60,75, etc...
   }
}


function pretty_percent($frac) {
    return sprintf("%5.2f%%",$frac*100);
}


function is_valid_docid($icmsdb,$docid) {
   $di=sqlgeonep($icmsdb,"select doc_id from workflow where doc_id=?",array($docid));
   return ($di!="");
}


#
# a quick way to output a timestamped message to stderr (usually the apache error log)
#

function logerr($str) {
   $ts=date("m/d/Y h:i:s A");
   file_put_contents('php://stderr',"$ts: $str\n",FILE_APPEND);
}



#
#  fix_request populates the $_REQUEST & $_POST strings if the program's been
#     called from the command line with key=val parameters passed
#     (much like perl .cgi handles things)
#
function fix_request() {
  global $_REQUEST,$_POST,$argv;
   if (php_sapi_name()=="cli") {
      # populate $_REQUEST from command line
      for ($i=0;$i<count($argv);$i++) {
         $param=$argv[$i];
         list($key,$val)=explode("=",$param);
         $val=urldecode($val);
         $_REQUEST[$key]=$val;
         $_POST[$key]=$val;
      }
   }
}

#################################################
#               FORM FUNCTIONS
#################################################

#
# get_form_fields returns a array_key array with value=1 for all form fields
#         found the the form body passed it.
#
function get_form_fields($formbody) {
    $formbody = html_entity_decode($formbody);
    //print "<pre>$formbody</pre>";
    
    // Build an array of control variables in Template::Toolkit that might trip up
    // variable name parsing
    $ttReserved = array(
        'ELSE','END'
    );
    $loopControls = array (
        'FOREACH', 'FOR', 'IF'
    );
    $offset=0;
    $fields = array();
    while (($start = strpos($formbody, "[%", $offset)) != false) {
        $offset = $start;
        $end = strpos($formbody, "%]", $start);
        $offset = $end;
        $length = $end - $start;
        $piece = substr($formbody, $start, $length);
        $words = preg_split('/\s+/', $piece);
        $first = $words[1];
        if (in_array($first, $ttReserved)) {
            continue;
        }
        if (in_array(strToUpper($first), $loopControls)) {
            // The first word is a loop control.  Look at the second word.
            $first = $words[2];
        }
        if (!in_array($first, $fields)) {
            array_push($fields, $first);
        }
    }
    
    return $fields;  # PRESERVING THE ORDER THEY APPEAR IN THE FORM...
}


# build_form_fields,
# passed a $fields list from get_form_fields, it creates default
# info for the form_fields field in the forms table by looking each field up
# in the form_fields table, producing warning messages if there's an error.

function build_form_fields_json($dbh,$fields) {
    $query = "
        select
            field_code,
            field_name,
            field_description,
            field_type,
            field_values,
            field_default
        from
            form_fields
        order by
            field_code
    ";
    
    $fflds = array();
    getData($fflds, $query, $dbh);
    
    # make a cross-ref for defined fields by field_code
    for ($i=0;$i<count($fflds);$i++) {
        $ffldsx[$fflds[$i]['field_code']]=$i;
    }
    
    $jsonobj=array();
    $order=0;
    $errarr=array();
    
    foreach ($fields as $field) {
        $j=$ffldsx[$field];
        if (!isset($ffldsx[$field])) {
            $errarr[]="Field <b>$field</b> unknown; please correct on form or add to Form Field Definitions";
        } else {
            $type = $fflds[$j]['field_type'];
            if (($type == "BUILTIN") || ($type == "ESIG")) { continue; }  # skip built-ins & esig-related
            # NOTE: possible exception: courthouse if there are more than one
            $x=new stdClass();
            $x->field_code=$fflds[$j]['field_code'];
            $x->field_name=$fflds[$j]['field_name'];
            $x->field_description=$fflds[$j]['field_description'];
            $x->field_type=$type;
            $x->field_values=$fflds[$j]['field_values'];
            $x->field_default=$fflds[$j]['field_default'];
            $jsonobj[$order++]=$x;
        }
    }
    return array(json_encode($jsonobj),$errarr);
}


# merge_form_fields,
# passed a $fields list from get_form_fields and a json $formfields object from forms table, it merges the 
# info from the form_fields field in the forms table by comparing to the form and adding/dropping the appropriate fields
# (checking against the form_fields table), producing warning messages if there's an error.

function merge_form_fields_json($dbh,$fields,$formfields) {
    $errarr=array();
    
    $query = "
        select
            field_code,
            field_name,
            field_description,
            field_type,
            field_values,
            field_default
        from
            form_fields
        order by
            field_code
    ";
    $fflds = array();
    getData($fflds, $query, $dbh);
    
    #
    # make a cross-ref for all defined fields by field_code
    #
    
    for ($i=0;$i<count($fflds);$i++) {
        $ffldsx[$fflds[$i]['field_code']]=$i;
    }
    
    # get the form fields for this form...
    $jsonobj=json_decode($formfields, true);
    
    # make xref for fields in the json object
    for ($i=0;$i<count($jsonobj);$i++) {
        $jsonxref[$jsonobj[$i]->field_code]=$i;
    }
    
    # make xref for fields in the new fields list
    for ($i=0;$i<count($fields);$i++) {
        $fieldxref[$fields[$i]]=$i;
    }
    
    # delete any now-vanished fields in the json object; remove duplicates
    $already = array();
    for ($i=0;$i<count($jsonobj);$i++) {
        if (!isset($fieldxref[$jsonobj[$i]->field_code])) {
            unset($jsonobj[$i]);
        } else if (array_key_exists($jsonobj[$i]->field_code, $already)) {
            unset($jsonobj[$i]);
        }
        
        $already[$jsonobj[$i]->field_code]=1; # to detect duplicates
    }
    
    $jsonobj=array_values($jsonobj);
    
    # check to see if the fields in fields are legit...
    foreach ($fields as $field) {
        $j=$ffldsx[$field];
        if (!isset($ffldsx[$field])) {
            $errarr[]="Field <b>$field</b> unknown; please correct on form or add to Form Field Definitions";
        } else {
            $type = $fflds[$j]['field_type'];
            if (($type == "BUILTIN") || ($type == "ESIG")) {
                continue;
            }  # skip built-ins & esig-related
            if (!isset($jsonxref[$field])) {
                $x=new stdClass();
                $x->field_code=$fflds[$j]['field_code'];
                $x->field_name=$fflds[$j]['field_name'];
                $x->field_description=$fflds[$j]['field_description'];
                $x->field_type=$type;
                $x->field_values=$fflds[$j]['field_values'];
                $x->field_default=$fflds[$j]['field_default'];
                $jsonobj[$order++]=$x;   
            }
        }
    }
    return array(json_encode($jsonobj),$errarr);
}

# returns a colorized string showing the current signature status
# UPdateEsigStatus in /orders/index.php is similar...

function get_esig_status(&$docInfo) {
    if ($docInfo['esigned'] == 'N') {
        $str = '<span style="font-weight: bold; color: red">N</span> ';
    } else {
        $str = '<span style="color:green">Y</span> ';
    }
    
    $docInfo['status'] = $str;
}


#
# function get_judge_vars returns an array containing values for various judge fields given a userid provided...
#
function get_judge_vars($dbh,$userid) {
    $jvars=array();
    $query = "
        select
            userid,
            first_name as FirstName,
            middle_name as MiddleName,
            last_name as LastName,
            suffix as Suffix,
            office,
            courthouse,
            role,
            roletype
        from
            users
        where
            userid = :userid
    ";
    $judge = getDataOne($query, $dbh, array('userid' => $userid));
    
    $name = buildName($judge);
    $office = $judge['office'];
    $courthouse = $judge['courthouse'];
    $courthouseaddr=substr($courthouse,strpos($courthouse,",")+1);
    
    
    $query = "
        select
            a.first_name as FirstName,
            a.middle_name as MiddleName,
            a.last_name as LastName,
            a.suffix as Suffix,
            a.phone,
            a.email,
            a.role,
            a.roletype
        from
            users a,
            users b
        where a.userid=b.assistant
            and b.userid = :userid
    ";
    
    $ja = getDataOne($query, $dbh, array('userid' => $userid));
    if (isset($ja['LastName'])) {
        $ja_name = buildName($ja);
        $ja_phone = $ja['phone'];
        $emails = explode(",", $ja['email']);
        $ja_email = $emails[0];
    } else {
        $ja_name = "";
        $ja_phone = "";
        $ja_email = "";
    }
    
    $jvars['JUDGE_NAME']=strtoupper($name);
    $jvars['JUDGE_LAST_NAME']= strtoupper($judge['LastName']);
    $jvars['JUDGE_JA_NAME']=strtoupper($ja_name);
    $jvars['JUDGE_ROLE'] = $judge['role'];
    $jvars['JUDGE_ROLE_TYPE'] = $judge['roletype'];
    $jvars['ja_phone']=$ja_phone;
    $jvars['ja_email']=$ja_email;
    $jvars['judge_office']=$office;
    $jvars['judge_courthouse']=$courthouseaddr;
    return $jvars;
}

function getUserList (&$users, $dbh = null) {
    if ($dbh == null) {
        $dbh = dbConnect("icms");
    }
    
    $query = "
        select
            userid,
            first_name as FirstName,
            middle_name as MiddleName,
            last_name as LastName,
            suffix as Suffix
        from
            users
        order by
            LastName
    ";
    
    getData($users, $query, $dbh);
    foreach ($users as &$user) {
        $user['fullname'] = buildName($user,1);
    }
}


#############################
#          MAIN PROGRAM
#############################
$dbh = dbConnect("icms");
set_user_globals($dbh);
load_system_settings();
?>
