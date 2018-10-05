<?php

function getDbConfig($dbname) {
    
    $conf = simplexml_load_file($_SERVER['APP_ROOT'] . "/conf/ICMS.xml");
    
    $found = 0;
    foreach ($conf->dbConfig as $dbConfig) {
        if ($dbConfig->{'name'} != $dbname) {
            continue;
        }
        $found = 1;
        break;
    }

    if ($found) {
        return $dbConfig;
    } else {
        return null;
    }
}

function handleDbError(PDOException $e) {
    //echo "<pre>"; print_r($e); die;
    print "A database error occurred while running the application. \n\nError Code: " . $e->getMessage() . "\n\nPlease contact your system administration.\n\n ";
}


function dbConnect ($dbname) {
    $config = simplexml_load_file(__DIR__ . "/../../conf/ICMS.xml");

    $found = 0;
    foreach ($config->dbConfig as $dbConfig) {
        if ($dbConfig->name != $dbname) {
            continue;
        }
        $found = 1;
        break;
    }

    if (!$found) {
        print "No database config found for '$dbname'.  Exiting.";
        exit;
    }
    
    if ($dbConfig->dbType == 'postgres') {
        $dbConfig->dbType = 'pgsql';
    }

    // These changes are necessary to allow the use of the same config file that
    // is used by existing Perl code.
    if ($dbConfig->dbType == 'mssql') {
        $dbConfig->dbType = 'dblib';
        $dbConfig->dbHost = preg_replace('/server=/','',$dbConfig->dbHost);
        $attrs = array();
    } else if ($dbConfig->dbType == 'oracle') {
        $dbConfig->dbType = 'oci';
        $attrs = array(PDO::ATTR_PERSISTENT => true);
    } else {
        $attrs = array(PDO::ATTR_PERSISTENT => true);
    }
    
    if ($dbConfig->dbType == 'oci') {
        $dsn = sprintf("%s:dbname=%s", $dbConfig->dbType,
                   $dbConfig->dbHost);    
    } else {
        $dsn = sprintf("%s:dbname=%s;host=%s", $dbConfig->dbType, $dbConfig->dbName,
                   $dbConfig->dbHost);
    
    }
    
    try {
        $dbh = new PDO($dsn,$dbConfig->dbUser,$dbConfig->dbPass,$attrs);
        if ($dbConfig->dbType == 'dblib') {
            // This is nexessary to overcome a connection bug in the dblib driver.
            doQuery("set ansi_nulls on; set ansi_warnings on;", $dbh);
        }
    }
    catch (PDOException $ex) {
        handleDbError($ex); exit;
    }

    
    $dbh->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    return $dbh;
}



function getData(&$arrayref, $query, $dbh, $args = null, $key = null, $flatten = 0) {
    // Grabs all rows for the query and pushes them onto the $arrayref array

    // If $args is specified, it must be an associative array, of values to be
    // substituted into a paramaterized query.  The query should use the :name - type
    // format that PDO expects, and the key names in the array should match those values
    // (without the colon).

    try {
        $sth = $dbh->prepare($query);
        
        if (!isset($args)) {
            $sth->execute();
        } else {
            $count = 1;
            foreach ($args as $field => $val) {
                $sth->bindParam(':'.$field, ${$field});
                ${$field} = $val;
            }
            $sth->execute();
        }

        while ($row = $sth->fetch(PDO::FETCH_ASSOC)) {
            if (!isset($key)) {
                // Just a regular array
                array_push($arrayref,$row);
            } else {
                // The resulting structure will be an associative array (keyed on $key)
                // that has as its elements arrays of records that match $key.  Of course,
                // $key must be one of the columns
                if ((!isset($arrayref[$row[$key]])) && (!$flatten)) {
                    // Create the array for the $key if it doesn't already exist.
                    $arrayref[$row[$key]] = array();
                }
                if (!$flatten) {
                    // Push the row onto that array
                    array_push($arrayref[$row[$key]], $row);
                } else {
                    // Told to flatten it - the row will have a single case
                    $arrayref[$row[$key]] = $row;
                }
            }
        }
    }
    catch (PDOException $ex) {
        handleDbError($ex); exit;
    }
}


function doQuery($query, $dbh, $args = null) {
    try {
        $sth = $dbh->prepare($query);
        if (!isset($args)) {
            $sth->execute();
        } else {
            $count = 1;
            foreach ($args as $field => $val) {
                $sth->bindParam(':'.$field, ${$field});
                ${$field} = $val;
            }
            $sth->execute();
        }
        return $sth->rowCount();
    }

    catch (PDOException $ex) {
        handleDbError($ex); exit;
    }
}


function getJudgeDivs (&$judgeArr, &$divArr, $dbh) {
    $query = "
        select
            j.last_name,
            j.middle_name,
            j.first_name,
            d.division_type,
            d.division_id,
            IFNULL(d.has_ols,0) as has_ols
        from
            judges j,
            judge_divisions jd,
            divisions d
        where
            jd.judge_id = j.judge_id
            and d.division_id = jd.division_id
            and d.show_icms_list = 1
        order by
            last_name
    ";

    $judges = array();
    getData($judges, $query, $dbh);

    foreach ($judges as $judge) {
        if ((isset($judge['middle_name'])) && ($judge['middle_name'] != "")) {
            if (strlen($judge['middle_name']) == 1) {
                $judge['middle_name'] .= ".";
            }
            $fullname = sprintf("%s, %s %s", $judge['last_name'], $judge['first_name'],
                                $judge['middle_name']);
        } else {
            $fullname = sprintf("%s, %s", $judge['last_name'], $judge['first_name']);
        }

        if (isset($judgeArr[$fullname])) {
            $judgeArr[$fullname] .= sprintf("%s,%s;", $judge['division_id'],
                                            $judge['division_type']);
        } else {
            $judgeArr[$fullname] = sprintf("%s,%s;", $judge['division_id'],
                                            $judge['division_type']);
        }

        # Build $divArr, too
        if (preg_match('/Criminal|Misdemeanor|Felony|VA|Mental/',$judge['division_type'])) {
            $rptType = "crim";
        } else if (preg_match('/Civil|Family|Foreclosure/',$judge['division_type'])) {
            $rptType = "civ";
        } else if (preg_match('/Juvenile/', $judge['division_type'])) {
            $rptType = "juv";
        } else if (preg_match('/Probate/', $judge['division_type'])) {
            $rptType = "pro";
        }


        if (isset($rptType)) {
            $opt = sprintf("%s~%s", $judge['division_id'], $rptType);
            $divArr[$judge['division_id']] = array(
                'opt' => $opt,
                'courtType' => $judge['division_type'],
                'has_ols' => $judge['has_ols']
            );
        }
    }
}


function getDataOne($query, $dbh, $args = null) {
    // Grabs all rows for the query and pushes them onto the $arrayref array

    // If $args is specified, it must be an associative array, of values to be
    // substituted into a paramaterized query.  The query should use the :name - type format
    // that PDO expects, and the key names in the array should match those values (without the colon).
    try {
        $sth = $dbh->prepare($query);
        if (!isset($args)) {
            $sth->execute();
        } else {
            $count = 1;
            foreach ($args as $field => $val) {
                $sth->bindParam(':'.$field, ${$field});
                ${$field} = $val;
            }
            $sth->execute();
        }
        $row = array();
        
        while ($thisrow = $sth->fetch(PDO::FETCH_ASSOC)) {
            foreach ($thisrow as $key => $val) {
                if (!isset($thisrow[$key])) {
                    continue;
                }
                $thisrow[$key] = preg_replace("/^\s+/","",$thisrow[$key]);
                $thisrow[$key] = preg_replace("/\s+$/","",$thisrow[$key]);
                $thisrow[$key] = preg_replace("/~/","",$thisrow[$key]);
            }

            $row = $thisrow;
        }
        return $row;
    }
    catch (PDOException $ex) {
        handleDbError($ex); exit;
    }
}


function getDbSchema ($dbname) {
    # Gets the schema defined for the database in ICMS.xml.  If not defined,
    # defaults to "dbo".
    
    $config = simplexml_load_file($_SERVER['APP_ROOT'] . "/conf/ICMS.xml");
    
    $found = 0;
    foreach ($config->dbConfig as $dbConfig) {
        if ($dbConfig->name != $dbname) {
            continue;
        }
        $found = 1;
        break;
    }

    if (!$found) {
        print "No database config found for '$dbname'.  Exiting.";
        exit;
    }
    
    if (isset($dbConfig->{'schema'})) {
        $schema = (string) $dbConfig->{'schema'};
        return $schema;
    }
    # No schema defined; return DBO.
    return "dbo";
}

function getLastInsert($dbh) {
    // Gets the ID of the last insert on the session for a MySQL database
    $query = "
        select
            last_insert_id() as LastInsert
    ";
    $val = getDataOne($query, $dbh);
    return $val['LastInsert'];
}

function load_module_config($user, $module, $dbh = null) {
    if ($dbh == null) {
        $dbh = dbConnect("icms");
    }
    
    $query = "
        select
            json
        from
            config
        where
            user = :user
            and module = :module
    ";
    
    $rec = getDataOne($query, $dbh, array('user' => $user, 'module' => $module));
    
    if (array_key_exists('json',$rec)) {
        return json_decode($rec['json']);
    } else {
        $newConfig = new_module_config($user, $module, $dbh);
        return json_decode($newConfig);
    }
}

function new_module_config ($user, $module, $dbh = null) {
    
    if ($dbh == null) {
        $dbh = dbConnect("icms");
    }

    $json = array();
    
    $json['id'] = save_module_config($user, $module, $json, $dbh);
    
    return $json;
}


function save_module_config ($user, $module, &$config, $dbh = null) {
    if ($dbh == null) {
        $dbh = dbConnect("icms");
    }
    
    $query = "
        update
            config
        set
            json = :json
        where
            id = :id
    ";
    if (array_key_exists('id',$config)) {
        doQuery($query, $dbh, array('json' => json_encode($config), 'id' => $config['id']));
    } else {
        $args = array('user' => $user, 'module' => $module, 'json' => json_encode($config));
    
        $insert = "
            replace into
                config (
                    user,
                    module,
                    json
                ) values (
                    :user,
                    :module,
                    :json
                )
        ";
        
        doQuery($insert, $dbh, $args);
        
        $config['id'] = getLastInsert($dbh);
        doQuery($query, $dbh, array('json' => json_encode($config), 'id' => $config['id']));
    }
    
    return $config['id'];
}

?>
