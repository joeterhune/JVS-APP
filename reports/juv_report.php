<?php

require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/common.php");
require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/db_functions.php");
require_once($_SERVER['JVS_DOCROOT'] . "/php-lib/report_functions.php");

require_once('Smarty/Smarty.class.php');

$datefmt = "Y-m-d H:i:s";

$scriptName = $argv[0];

$options = getopt("qD");

$DEBUG = key_exists('D', $options);
$MSGS = !(key_exists('q', $options));

$config = simplexml_load_file($icmsXml);

$today = date('Y-m-d');

// ***** IMPORTANT *****
// Useful for shortcutting queries, to get a smaller subset for testing.
// In production, this should be an empty string.
// $DIVLIMIT = "and c.DivisionID in ('JK')";
$DIVLIMIT = '';

$casetypes = array('CJ','DP');

$casetypesString = sprintf("('%s')", implode("','", $casetypes));

$stattypes="('Open', 'Reopen')";

// The outpath path for reports
$outpath = $config->{'reportPath'} . "/juv";

// Make sure it exists
if (!file_exists($outpath)) {
    mkdir($outpath, 0755, true);
}

// For report generation
$county = $config->{'county'};

$resultDir = sprintf("%s/%s", $_SERVER['JVS_ROOT'], $resultSubDir);

if (!file_exists($resultDir)) {
    mkdir($resultDir,0700,true);
}

// Get an exclusive lock on the lock file, to ensure that only one instance
// of this script is running
$lockfile = sprintf("%s/reports/results/%s.lock", $_SERVER['JVS_ROOT'], $scriptName);
$lfp = fopen($lockfile, "w");
if (!getFileLock($lfp, 5)) {
    print "I was unable to obtain the file lock. Another process is probably running.\n\n";
    exit(CANNOT_OBTAIN_LOCK);
}

// The column names (from $caselist) that will actually be used in the report. This will be stored
// with the JSON file as the reportCols element. Order matters here!!
$reportCols = array('CaseNumber','CaseStyle','DOB','FileDate','CaseAge','CaseType','CaseStatus',
                    'LastActivity','LastDocketCode','FarthestEventType','FarthestEventDate','MergedNotesFlags');


// Structures used throughout the program
$caseList  = array();
$reopened = array();
$divList = array();
$los = array();
$noHearings = array();
$lastDocket = array();
$lastDockets = array();
$lastActivity = array();
$trialCases = array();

// Ranking for the CourtStatuteDegree - so we can determine the highest degree
// of charge for a case.
$csDegrees = array(
    'C' => array('val' => 0, 'desc' => 'C - Capital'),
    'L' => array('val' => 1, 'desc' => 'L - Life'),
    'P' => array('val' => 2, 'desc' => 'P - 1st Punishable by Life'),
    'F' => array('val' => 3, 'desc' => 'F - 1st'),
    'S' => array('val' => 4, 'desc' => 'S - 2nd'),
    'T' => array('val' => 5, 'desc' => 'T - 3rd'),
    'N' => array('val' => 6, 'desc' => 'N = Not Applicable')
);

$schema = getDbSchema('showcase-rpt');

$dbh = dbConnect("showcase-rpt", 600);

if (!$dbh) {
    print "Error connecting to database 'showcase-rpt'. Exiting.\n\n";
    exit(DB_CONNECT_ERROR);
}

if ($MSGS) {
    print "Starting criminal report generation at " . date($datefmt) . "...\n";
}

if ($MSGS) {
    print "Starting buildCaseList() " . date($datefmt) . "\n";
}

buildCaseList($dbh, $caseList, $reopened, $divList);

if ($MSGS) {
    print "Starting getDOBs() " . date($datefmt) . "\n";
}

$justCases = array_keys($caseList);

getDOBs($caseList, $dbh);

if($MSGS) {
    print "starting buildNoHearings " . date($datefmt) . "\n";
}

buildNoHearings($dbh, $noHearings, $caseList);

if ($MSGS) {
    print "starting buildLastDocket " . date($datefmt) . "\n";
}

buildLastDocket($dbh, $caseList);

if ($MSGS) {
    print "starting buildEvents " . date($datefmt) . "\n";
}

buildEvents($caseList);

if ($MSGS) {
    print "starting buildNotes " . date($datefmt) . "\n";
}

buildNotes($caseList);

if ($MSGS) {
    print "starting report " . date($datefmt) . "\n";
}

if ($MSGS) {
    print "Writing all case info to '$outpath/allCaseInfo.json'... " . date($datefmt) . "\n\n";
}
writeJsonFile($caseList, "$outpath/allCaseInfo.json");

//print "There are " . count($caselist) . " total cases.\n"; exit;

doReport($caseList);

exit;


// Functions below this line

function getDOBs (&$caselist, $dbh) {
    
    $count = 0;
    $perQuery = 1000;
    
    $cases = array_keys($caselist);
    
    $dobs = array();
    
    while ($count < count($cases)) {
        $inString = sprintf("'%s'", implode("','", array_slice($cases, $count, $perQuery)));
        
        $query = "
            SELECT
                CaseNumber,
                1 AS SeqNo,
                PersonID,
                CONVERT(VARCHAR(10), DOB, 101) AS DOB
            FROM
                vAllParties
            WHERE
                CaseNumber IN ($inString)
                AND (
                    PartyType = 'CHLD'
                    OR (
                        PartyType = 'HYBRID'
                        AND PartyTypeDescription = 'CHILD (CJ)'
                    )
                )
            order by
                DOB asc
        ";
        
        getData($dobs, $query, $dbh, null, "CaseNumber");
        
        $count += $perQuery;
    }
    
    
    // Ok, we should now have an associative array of hashes, containing (possibly) multiple
    // DOBs per case. They're sorted with the earliest first, so take the first one in the
    // list to get the target DOB for the case
    foreach ($dobs as $casenum => $dob) {
        $caselist[$casenum]['DOB'] = $dob[0]['DOB'];
    }
}


function doReport ($caselist) {
    global $outpath, $DEBUG, $MSGS, $datefmt, $divList, $county, $today, $reportCols;
    
    foreach ($divList as $div => $casetype) {
        if ($MSGS) {
            print "Building reports for division '$div' ... " . date($datefmt) . "\n";
        }
        
        $yearMonth = date('Y-m');
        
        $rptTitle = sprintf("%s County - %s Division %s", $county, $casetype, $div);
        
        $rptPath = "$outpath/div$div/$yearMonth";
        
        if (!file_exists($rptPath)) {
            if ($MSGS) {
                print "Creating report path '$rptPath'...\n";
            }
            mkdir($rptPath,0755,true);
		}
        
        // Types of statuses - cases can be in multiple lists (such as pending, which will also be
        // in either pendingWithEvents or pendingNoEvents)
        // Include details (titles, date) etc. in the array so they're in the JSON file
        $penddep = array();
        $penddep_0_120 = array();
        $penddep_121_180 = array();
        $penddep_181 = array();
        $penddep_ne = array();
        $penddep_we = array();

        $rodep = array();
        $rodep_0_120 = array();
        $rodep_121_180 = array();
        $rodep_181 = array();
        $rodep_ne = array();
        $rodep_we = array();
        
        $penddel = array();
        $penddel_0_120 = array();
        $penddel_121_180 = array();
        $penddel_181 = array();
        $penddel_ne = array();
        $penddel_we = array();

        $rodel = array();
        $rodel_0_120 = array();
        $rodel_121_180 = array();
        $rodel_181 = array();
        $rodel_ne = array();
        $rodel_we = array();

        $warrants = array();
        
        // Now loop through the case list, once for each division
        foreach ($caselist as $case) {
            if ($case['DivisionID'] != $div) {
                continue;
            }
            
            switch ($case['CaseType']) {
                case 'DP':
                    $ro = &$rodep;
                    $rowe = &$rodep_we;
                    $rone = &$rodep_ne;
                    $ro_0_120 = &$rodep_0_120;
                    $ro_121_180 = &$rodep_121_180;
                    $ro_181 = &$rodep_181;
                    $pend = &$penddep;
                    $pendwe = &$penddep_we;
                    $pendne = &$penddep_ne;
                    $pend_0_120 = &$penddep_0_120;
                    $pend_121_180 = &$penddep_121_180;
                    $pend_181 = &$penddep_181;
                    break;
                case 'CJ':
                    $ro = &$rodel;
                    $rowe = &$rodel_we;
                    $rone = &$rodel_ne;
                    $ro_0_120 = &$rodel_0_120;
                    $ro_121_180 = &$rodel_121_180;
                    $ro_181 = &$rodel_181;
                    $pend = &$penddel;
                    $pendwe = &$penddel_we;
                    $pendne = &$penddel_ne;
                    $pend_0_120 = &$penddel_0_120;
                    $pend_121_180 = &$penddel_121_180;
                    $pend_181 = &$penddel_181;
                    break;
                default:
                    continue;
            }
            
            if ($case['Reopened']) {
                // One of the Reopened statuses
                array_push($ro, $case);
                
                if ($case['FarthestEventType'] == '') {
                    // No future events
                    array_push($rone, $case);
                } else {
                    array_push($rowe, $case);
                }
                
                // And group by case age
                if ($case['CaseAge'] >= 181) {
                    array_push($ro_181, $case);
                } elseif ($case['CaseAge'] >= 121) {
                    array_push($ro_121_180, $case);
                } else {
                    array_push($ro_0_120, $case);
                }
                
                // Any of them have trial events?
            } elseif ($case['CaseStatus'] != 'Open') {
                // Not matched above, but status is not 'Open'
                continue;
            } else {
                // A normal pending case
                array_push($pend, $case);
                
                if ($case['FarthestEventType'] == '') {
                    // No future events
                    array_push($pendwe, $case);
                } else {
                    array_push($pendne, $case);
                }
                
                // And group by case age
                if ($case['CaseAge'] >= 181) {
                    array_push($pend_181, $case);
                } elseif ($case['CaseAge'] >= 121) {
                    array_push($pend_121_180, $case);
                } else {
                    array_push($pend_0_120, $case);
                }
            }
        }
        
        $indexPage = array(
            'Division' => $div,
            'ReportDate' => $today,
            'Title' => "$county County",
            'Subtitle' => "$casetype Division $div",
            'CaseCounts' => array(
                array(
                      'type' => 'Pending Cases - Dependency',
                      'count' => count($penddep),
                      'rpttype' => 'penddep'
                ),
                array(
                      'type' => 'Pending Cases With Events - Dependency',
                      'count' => count($penddep_we),
                      'rpttype' => 'penddep_we'
                ),
                array(
                      'type' => 'Pending Cases With No Events - Dependency',
                      'count' => count($penddep_ne),
                      'rpttype' => 'penddep_ne'
                ),
                array(
                      'type' => 'Reopened Cases - Dependency',
                      'count' => count($rodep),
                      'rpttype' => 'rodep'
                ),
                array(
                      'type' => 'Reopened Cases With Events - Dependency',
                      'count' => count($rodep_we),
                      'rpttype' => 'rodep_we'
                ),
                array(
                      'type' => 'Reopened Cases With No Events - Dependency',
                      'count' => count($rodep_ne),
                      'rpttype' => 'rodep_ne'
                )
            )
        );
        
        writeJsonFile($indexPage, "$rptPath/index.json");
        
        if (file_exists("$outpath/div$div/index.json")) {
            // Make sure this symlink points to the correct directory
            unlink("$outpath/div$div/index.json");
        }
        
        symlink("$rptPath/index.json", "$outpath/div$div/index.json");
        
        writeReportFile($rptPath, $rptTitle, "Pending Cases - Dependency", $penddep, "penddep.json");
        writeReportFile($rptPath, $rptTitle, "Pending Cases - Dependency - With Events", $penddep_we, "penddep_we.json");
        writeReportFile($rptPath, $rptTitle, "Pending Cases - Dependency - With No Events", $penddep_we, "penddep_ne.json");
        writeReportFile($rptPath, $rptTitle, "Pending Cases - Dependency - 0-120 Days", $penddep_0_120, "penddep_0-120.json");
        writeReportFile($rptPath, $rptTitle, "Pending Cases - Dependency - 121-180 Days", $penddep_121_180, "penddep_121-180.json");
        writeReportFile($rptPath, $rptTitle, "Pending Cases - Dependency - 181+ Days", $penddep_181, "penddep_181.json");
        writeReportFile($rptPath, $rptTitle, "Reopened Cases - Dependency", $rodep, "rodep.json");
        writeReportFile($rptPath, $rptTitle, "Reopened Cases - Dependency - With Events", $rodep_we, "rodep_we.json");
        writeReportFile($rptPath, $rptTitle, "Reopened Cases - Dependency - With No Events", $rodep_ne, "rodep_ne.json");
        writeReportFile($rptPath, $rptTitle, "Reopened Cases - Dependency - 0-120 Days", $rodep_0_120, "rodep_0-120.json");
        writeReportFile($rptPath, $rptTitle, "Reopened Cases - Dependency - 121-180 Days", $rodep_121_180, "rodep_121-180.json");
        writeReportFile($rptPath, $rptTitle, "Reopened Cases - Dependency - 181+ Days", $rodep_181, "rodep_181.json");
        
        writeReportFile($rptPath, $rptTitle, "Pending Cases - Delinquency", $penddel, "penddel.json");
        writeReportFile($rptPath, $rptTitle, "Pending Cases - Delinquency - With Events", $penddel_we, "penddel_we.json");
        writeReportFile($rptPath, $rptTitle, "Pending Cases - Delinquency - With No Events", $penddel_we, "penddel_ne.json");
        writeReportFile($rptPath, $rptTitle, "Pending Cases - Delinquency - 0-120 Days", $penddel_0_120, "penddel_0-120.json");
        writeReportFile($rptPath, $rptTitle, "Pending Cases - Delinquency - 121-180 Days", $penddel_121_180, "penddel_121-180.json");
        writeReportFile($rptPath, $rptTitle, "Pending Cases - Delinquency - 181+ Days", $penddel_181, "penddel_181.json");
        writeReportFile($rptPath, $rptTitle, "Reopened Cases - Delinquency", $rodel, "rodel.json");
        writeReportFile($rptPath, $rptTitle, "Reopened Cases - Delinquency - With Events", $rodel_we, "rodel_we.json");
        writeReportFile($rptPath, $rptTitle, "Reopened Cases - Delinquency - With No Events", $rodel_ne, "rodel_ne.json");
        writeReportFile($rptPath, $rptTitle, "Reopened Cases - Delinquency - 0-120 Days", $rodel_0_120, "rodel_0-120.json");
        writeReportFile($rptPath, $rptTitle, "Reopened Cases - Delinquency - 121-180 Days", $rodel_121_180, "rodel_121-180.json");
        writeReportFile($rptPath, $rptTitle, "Reopened Cases - Delinquency - 181+ Days", $rodel_181, "rodel_181.json");
    }
}

function buildCaseList ($dbh, &$caselist, &$reopened, &$divList) {
    global $outpath, $DEBUG, $JUVDIVS, $DIVLIMIT, $NOTACTIVE, $MSGS, $datefmt, $casetypesString;
    
    // Not the global $today, because we want the date in a different format here
    $today = date('m/d/Y');
    
    $divassign = array();
    $rawcases = array();
    
    $rcFile = "$outpath/rawcase.json";
    
    $jdbh = dbConnect("judge-divs");
    
    $query = "
        select
            division_id as DivisionID,
            division_type as DivisionType
        from
            divisions
        where
            division_type like '%Juvenile%'
        order by
            DivisionID
    ";
    
    getData($divassign, $query, $jdbh, null, "DivisionID", 1);
    
    foreach ($divassign as $divID => $divinfo) {
        $divList[$divID] = $divinfo['DivisionType'];
    }
    
    # Now get the raw case listing
    $doLookups = 1;
    
    if ($DEBUG && (file_exists($rcFile))) {
        // Read divAssign from the JSON file if it exists
		print "DEBUG: Reading $rcFile\n";
        if (!(readJsonFile($rawcases, $rcFile))) {
            if ($MSGS) {
                print "Error reading data from '$rcFile'. Will perform lookups.\n";
            }
        } else {
            $doLookups = 0;
        }
    }
    
    if ($doLookups) {
        if ($MSGS) {
            print "Starting rawcase query " . date($datefmt) . "\n";
		}
                
        $query = "
            SELECT
                c.CaseNumber,
                c.DivisionID,
                c.CaseStyle,
                c.CaseStatus,
                c.CourtType,
                CONVERT(varchar(10), c.FileDate, 101) AS FileDate,
                CONVERT(varchar(10), c.DispositionDate, 101) AS DispositionDate,
                CONVERT(varchar(10), c.ReopenDate, 101) AS ReopenDate,
                CONVERT(varchar(10), c.ReopenCloseDate, 101) AS ReopenCloseDate,
                c.CaseType
            FROM
                vCase c
                    INNER JOIN
                        vDivision_Judge j with(nolock) ON c.DivisionID = j.DivisionID
                            AND j.Division_Active = 'Yes'
            WHERE
                c.CourtType IN $casetypesString
                AND (
                    c.CaseStatus not in $NOTACTIVE
                    OR (
                        c.CaseStatus IN $NOTACTIVE
                        AND c.CaseID IN (
                            SELECT e.CaseID
                            FROM vCourtEvent e
                            WHERE e.CaseID = c.CaseID
                            AND e.CourtEventDate >= CURRENT_TIMESTAMP
                        )
                    )
                )
                AND c.Sealed = 'N'
                AND c.Expunged = 'N'
                $DIVLIMIT
        ";
        
        getData($rawcases, $query, $dbh, null, "CaseNumber", 1);
        
        if ($MSGS) {
			print "Got all the rawcase rows - " . count($rawcases) . " of them. " . date($datefmt) . "\n";
		}
        
        if (!writeJsonFile($rawcases, $rcFile)) {
            // Not a fatal error, but still say it failed if $MSGS on
            if ($MSGS) {
                print "Failure writing file '$rcFile'. Continuing.\n";
            }
        };
    }
    
    if ($MSGS) {
		print "Coursing through rawcase hash - filling caselist... " . date($datefmt) . "\n";
	}
    
    foreach ($rawcases as $casenum => $case) {
        $caselist[$casenum] = $case;
                
        // A few placeholders for items that may or may not be populated in
        // later routines
        $caselist[$casenum]['NoHearings'] = 0;
        $caselist[$casenum]['LastActivity'] = '';
        $caselist[$casenum]['LastDocketDate'] ='';
        $caselist[$casenum]['LastDocketCode'] = '';
        $caselist[$casenum]['MostRecentEventDate'] = '';
        $caselist[$casenum]['MostRecentEventType'] = '';
        $caselist[$casenum]['FarthestEventDate'] = '';
        $caselist[$casenum]['FarthestEventType'] = '';
        $caselist[$casenum]['MergedNotesFlags'] = '';
        $caselist[$casenum]['Reopened'] = 0;
        $caselist[$casenum]['LOS'] = 0;
        $caselist[$casenum]['JuryTrial'] = 0;
        
        $caselist[$casenum]['CaseAge'] = getCaseAge($caselist[$casenum], $today);
        // CaseType isn't always defined in ShowCase
        $caselist[$casenum]['CaseType'] = getSCcasetype($caselist[$casenum]['CaseType'],$caselist[$casenum]['CourtType']);
        
        if (in_array($case['CaseStatus'],array('Reopen','Reopen VOP'))) {
			$reopened[$casenum]=1;
            $caselist[$casenum]['Reopened'] = 1;
		}
    }
    
    if (!writeJsonFile($caselist, "$outpath/caselist.json")) {
        // Not a fatal error, but still say it failed if $MSGS on
        if ($MSGS) {
            print "Failure writing file '$outpath/caselist.json'. Continuing.\n";
        }
    };
    
    if (!writeJsonFile($reopened, "$outpath/reopened.json")) {
        // Not a fatal error, but still say it failed if $MSGS on
        if ($MSGS) {
            print "Failure writing file '$outpath/reopened.json'. Continuing.\n";
        }
    };
    
    if ($MSGS) {
		print "Done building caselist. " . date($datefmt) . "\n";
	}
}


?>