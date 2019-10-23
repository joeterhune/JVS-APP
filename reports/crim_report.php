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
//$DIVLIMIT = "and c.DivisionID in ('S','B','T')";
$DIVLIMIT = '';

$casetypes = array('CF','CT','MM','MO','CO','AP','TR');

$casetypesString = sprintf("('%s')", implode("','", $casetypes));

$trialtypes="('NJ - NON JURY TRIAL','IT - INFRACTION TRIAL','JT - JURY TRIAL')";

// The outpath path for reports
$outpath = $config->{'reportPath'} . "/crim";

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
$reportCols = array('CaseNumber','CaseStyle','Sex','DOB','InJail','DaysServed','CaseAge','FileDate','CaseType','CaseStatus',
                    'LastActivity','NumCharges','TopChargeDesc','MostRecentEventDate','MostRecentEventType',
                    'FarthestEventDate','FarthestEventType','MergedNotesFlags');


// Structures used throughout the program
$caselist  = array();
$reopened = array();
$divList = array();
$noHearings = array();
$warrants = array();
$charges = array();
$topCharges = array();
$chargePending = array();
$lastDocket = array();
$lastDockets = array();
$lastActivity = array();
$trialCases = array();
$juryTrialEvents = array();
$infractionTrialEvents = array();
$nonJuryTrialEvents = array();
$jailTime = array();

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

// Need to get appeals, too.
//array_push($CRIMCODES, "'AP'");
//$courtcodes="(" . join(",", $CRIMCODES) . ")";

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

buildCaseList($dbh, $caselist, $reopened, $divList);

// An array of the case numbers from $caselist
$justCases = array_keys($caselist);

buildNoHearings($dbh, $noHearings, $caselist);

if ($MSGS) {
    print "starting buildWarrants " . date($datefmt) . "\n";
}

buildWarrants($dbh, $warrants, $caselist);

foreach ($warrants as $casenum => $warrant) {
    $caselist[$casenum]['Warrants'] = $warrant;
}

if ($MSGS) {
    print "starting buildCharges " . date($datefmt) . "\n";
}

buildCharges($dbh, $charges, $chargePending, $caselist);

foreach ($charges as $casenum => $chargelist) {
    //$caselist[$casenum]['Charges'] = $chargelist;
    $caselist[$casenum]['NumCharges'] = count($chargelist);
}

if ($MSGS) {
    print "starting buildLastDocket " . date($datefmt) . "\n";
}

buildLastDocket($dbh, $caselist);

if ($MSGS) {
    print "starting buildEvents " . date($datefmt) . "\n";
}

buildEvents($caselist);

if ($MSGS) {
    print "starting buildNotes " . date($datefmt) . "\n";
}

buildNotes($caselist);

if ($MSGS) {
    print "starting buildTrialCases " . date($datefmt) . "\n";
}

buildTrialCases($dbh, $trialCases, $juryTrialEvents, $infractionTrialEvents, $nonJuryTrialEvents, $caselist);

if ($MSGS) {
    print "Starting buildInCustody " . date($datefmt) . "\n";
}

buildInCustody($dbh, $caselist);

if ($MSGS) {
    print "starting report " . date($datefmt) . "\n";
}

if ($MSGS) {
    print "Writing all case info to '$outpath/allCaseInfo.json'... " . date($datefmt) . "\n\n";
}
//writeJsonFile($caselist, "$outpath/allCaseInfo.json");

//print "There are " . count($caselist) . " total cases.\n"; exit;

doReport($caselist);

exit;


// Functions below this line

function doReport ($caselist) {
    global $outpath, $DEBUG, $MSGS, $datefmt, $divList, $county, $today, $reportCols;
    
    foreach ($divList as $div => $casetype) {
        if ($MSGS) {
            print "Building reports for division '$div' ... " . date($datefmt) . "\n";
        }
        
        $ctDesc = getDesc($casetype, $div);
        $yearMonth = date('Y-m');
        
        $rptTitle = sprintf("%s County - %s Division %s", $county, $ctDesc, $div);
        
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
        $pending = array();
        $pendingWithEvents = array();
        $pendingNoEvents = array();
        $reopened = array();
        $reopenedWithEvents = array();
        $reopenedNoEvents = array();
        $openWarrants = array();
        $trialsThisMonth = array();
        $juryTrials = array();
        $infractionTrials = array();
        $nonJuryTrials = array();
        $otherStatuses = array();
        
        // Now loop through the case list, once for each division
        foreach ($caselist as $case) {
            
            if ($case['DivisionID'] != $div) {
                continue;
            }
            
            if ($case['Warrants']) {
                // Case has open warrant(s)
                array_push($openWarrants, $case);
            } elseif ($case['Reopened']) {
                // One of the Reopened statuses
                array_push($reopened, $case);
                if ($case['FarthestEventType'] == '') {
                    // No future events
                    array_push($reopenedNoEvents, $case);
                } else {
                    array_push($reopenedWithEvents, $case);
                }
            } elseif ($case['CaseStatus'] != 'Open') {
                // Not matched above, but status is not 'Open'
                array_push($otherStatuses, $case);
            } else {
                // A normal pending case
                array_push($pending, $case);
                if ($case['FarthestEventType'] == '') {
                    // No future events
                    array_push($pendingNoEvents, $case);
                } else {
                    array_push($pendingWithEvents, $case);
                }
            }
            
            if ($case['JuryTrial']) {
                array_push($trialsThisMonth, $case);
                array_push($juryTrials, $case);
            } elseif ($case['NonJuryTrial']) {
                array_push($trialsThisMonth, $case);
                array_push($nonJuryTrials, $case);
            } elseif ($case['InfractionTrial']) {
                array_push($trialsThisMonth, $case);
                array_push($infractionTrials, $case);
            }
        }
        
        $indexPage = array(
            'Division' => $div,
            'ReportDate' => $today,
            'Title' => "$county County",
            'Subtitle' => "$ctDesc Division $div",
            'CaseCounts' => array(
                array(
                      'type' => 'Pending Cases',
                      'count' => count($pending),
                      'rpttype' => 'pend'
                ),
                array(
                      'type' => 'Pending With Events',
                      'count' => count($pendingWithEvents),
                      'rpttype' => 'pendwe'
                ),
                array(
                      'type' => 'Pending No Events',
                      'count' => count($pendingNoEvents),
                      'rpttype' => 'pendne'
                ),
                array(
                      'blank' => 1
                ),
                array(
                      'type' => 'Reopened',
                      'count' => count($reopened),
                      'rpttype' => 'reopened'
                ),
                array(
                      'type' => 'Reopened With Events',
                      'count' => count($reopenedWithEvents),
                      'rpttype' => 'reopenedwe'
                ),
                array(
                      'type' => 'Reopened No Events',
                      'count' => count($reopenedNoEvents),
                      'rpttype' => 'reopenedne'
                ),
                array(
                      'blank' => 1
                ),
                array(
                      'type' => 'Outstanding Warrants',
                      'count' => count($openWarrants),
                      'rpttype' => 'warrants'
                ),
                array(
                      'blank' => 1
                ),
                array(
                      'type' => 'Other',
                      'count' => count($otherStatuses),
                      'rpttype' => 'other'
                ),
                array(
                      'blank' => 1
                ),
                array(
                      'type' => 'Cases With Trial Events This Month',
                      'count' => count($trialsThisMonth),
                      'rpttype' => 'trials'
                ),
                array(
                      'type' => 'Jury',
                      'count' => count($juryTrials),
                      'rpttype' => 'jurytrials'
                ),
                array(
                      'type' => 'Non-Jury',
                      'count' => count($nonJuryTrials),
                      'rpttype' => 'nonjurytrials'
                ),
                array(
                      'type' => 'Infraction',
                      'count' => count($infractionTrials),
                      'rpttype' => 'infractiontrials'
                )
            )
        );
        
        writeJsonFile($indexPage, "$rptPath/index.json");
        
        if (file_exists("$outpath/div$div/index.json")) {
            // Make sure this symlink points to the correct directory
            unlink("$outpath/div$div/index.json");
        }
        
        symlink("$rptPath/index.json", "$outpath/div$div/index.json");
        
        writeReportFile($rptPath, $rptTitle, "Pending Cases", $pending, "pend.json");
        writeReportFile($rptPath, $rptTitle, "Pending Cases With Events", $pendingWithEvents, "pendwe.json");
        writeReportFile($rptPath, $rptTitle, "Pending Cases With No Events", $pendingNoEvents, "pendne.json");
        writeReportFile($rptPath, $rptTitle, "Reopened Cases", $reopened, "reopened.json");
        writeReportFile($rptPath, $rptTitle, "Reopened Cases With Events", $reopenedWithEvents, "reopenedwe.json");
        writeReportFile($rptPath, $rptTitle, "Reopened Cases With No Events", $reopenedNoEvents, "reopenedne.json");
        writeReportFile($rptPath, $rptTitle, "Cases With Open Warrants", $openWarrants, "warrants.json");
        writeReportFile($rptPath, $rptTitle, "Other Status", $otherStatuses, "other.json");
        writeReportFile($rptPath, $rptTitle, "Cases With Trials This Month", $trialsThisMonth, "trials.json");
        writeReportFile($rptPath, $rptTitle, "Cases With Jury Trials This Month", $juryTrials, "jurytrials.json");
        writeReportFile($rptPath, $rptTitle, "Cases With Non-Jury Trials This Month", $nonJuryTrials, "nonjurytrials.json");
        writeReportFile($rptPath, $rptTitle, "Cases With Infraction Trials This Month", $infractionTrials, "infractiontrials.json");
    }
}


function getDesc ($casetype, $div) {
    $retVal = "";

    if ($div == "") {
        return "Criminal No ";
    } else {
        switch($casetype) {
            case "Felony":
                if (($div == "Y") || ($div == "YD")) {
                    $retVal = "Circuit & County Criminal";
                } elseif ($div == "CFMH") {
                    $retVal = "Mental Health";
                } else {
                    $retVal = "Circuit Criminal";
                }
                break;
            default:
                switch($div) {
                    case "KD":
                        $retVal = "Circuit Criminal";
                        break;
                    case "Y":
                    case "YD":
                        $retVal = "Circuit & County Criminal";
                        break;
                    default:
                        $retVal = "County Criminal";
                        break;
                }
                break;
        }
    }
    return $retVal;
}


function buildInCustody ($dbh, &$caselist){
    global $outpath, $DEBUG, $MSGS, $NOTACTIVE, $DIVLIMIT, $casetypesString, $datefmt, $justCases;
    
    $rawArrests = array();
    $rawPBSOCases = array();
    $rawPBSOInCustody = array();
    
    $raFile = "$outpath/rawarrests.json";
    $rcFile = "$outpath/rawpbsocases.json";
    
    $raLoaded = 0;
    $rcLoaded = 0;
    
    if ($DEBUG) {
        if (file_exists($raFile)) {
            if ($MSGS) {
                print "Loading raw arrests from $raFile ... " . date($datefmt) . "\n";
            }
            readJsonFile($rawArrests, $raFile);
            $raLoaded = 1;
        }
        
        if (file_exists($rcFile)) {
            if ($MSGS) {
                print "Loading raw PBSO cases from $rcFile ... " . date($datefmt) . "\n";
            }
            readJsonFile($rawPBSOCases, $rcFile);
            $rcLoaded = 1;
        }
    }
    
    if (!$raLoaded) {
        // Didn't load raw arrests from a file. So go get 'em
        // The BookingSheetNumber is the PBSO Case Number!
        
        if ($MSGS) {
            print "Reading raw arrests from Clerk system ..." . date($datefmt) . "\n\n";;
        }
       
        $count = 0;
        $perQuery = 1000;
        
        while ($count < count($justCases)) {
            // Make a comma-separated list of case numbers (extract $perQuery case numbers from
            // $caselist), being sure to quote each one.
            $inString = sprintf("'%s'", implode("','", array_slice($justCases, $count, $perQuery)));
            
            $query = "
                select
                    a.CaseNumber,
                    a.BookingSheetNumber,
                    a.CountyID
                from
                    vCase c with(nolock),
                    vArrest a with(nolock)
                where
                    c.CaseID=a.CaseID
                    and c.CaseStatus not in $NOTACTIVE
                    and c.CaseNumber in ($inString)
                    $DIVLIMIT
            ";
            
            getData($rawArrests, $query, $dbh, null, 'CaseNumber');
            
            $count += $perQuery;
        }
        
        if ($MSGS) {
            print "Writing raw arrests to '$raFile'... " . date($datefmt) . "\n";
        }
        
        writeJsonFile($rawArrests, $raFile);
    }
    
    if (!$rcLoaded) {
        // Didn't load PBSO cases from the file. Go get them from PBSO, using the
        // BookingSheetNumbers from $rawArrests
        
        // Built an array of the BookingSheetNumbers
        $bsns = array();
        
        foreach ($rawArrests as $casenum => $arrestArray) {
            // $arrestArray is itself an array (though usually with just one element)
            foreach ($arrestArray as $arrest) {
                $bsn = $arrest['BookingSheetNumber'];
                array_push($bsns, "'$bsn'");
            }
        }
        
        // Now connect to PBSO and get the arrest info for the individual bookings
        $pbsodb = dbConnect('pbso2',600);
        
        if ($MSGS) {
            print "Getting raw case info from PBSO... " . date($datefmt) . "\n";
        }
        
        $count = 0;
        $perQuery = 1000;
        
        while ($count < count($bsns)) {
            $temp = array_slice($bsns, $count, $perQuery);
            $inString = implode(",", $temp);
            
            $query = "
                select
                    distinct casenumber as PBSOCase,
                    CONVERT(varchar(10),BookingDate,110) as BookingDate,
                    inmateid as InmateID,
                    BookingID as BookingID,
                    CASE
                        WHEN releasedate IS NULL
                            THEN ''
                        ELSE CONVERT(varchar(10),releasedate,110)
                    END as ReleaseDate,
                    ISNULL(assignedcellid,'') as AssignedCellID
                from
                    vw_PBSOQueryBookingInfo
                where
                    casenumber in ($inString)
                order by
                    casenumber desc
            ";
            
            getData($rawPBSOCases, $query, $pbsodb, null, 'PBSOCase', 1);
            
            $count += $perQuery;
        }
        
        if ($MSGS) {
            print "Writing raw PBSO cases to '$rcFile' ... " . date($datefmt) . "\n";
        }
        
        writeJsonFile($rawPBSOCases, $rcFile);
    }
    
    // At this point, we have the arrest/booking history for the cases in $caselist.
    // Built the inCustody list
    if ($MSGS) {
        print "Building inCustody list... " . date($datefmt) . "\n";
    }
    
    $arrests = array();
    
    foreach ($caselist as $casenum => &$case) {
        $case['InJail'] = 'N';
        $case['DaysServed'] = 0;
        $case['AssignedCellID'] = '';
        
        if (key_exists($casenum, $rawArrests)) {
            foreach ($rawArrests[$casenum] as $arrest) {
                $bsn = $arrest['BookingSheetNumber'];
                
                if (key_exists($bsn, $rawPBSOCases)) {
                    $booking = $rawPBSOCases[$bsn];
                    if (!preg_match('/\d\d-\d\d-\d\d\d\d/', $booking['BookingDate'])) {
                        // Don't have a booking date that we can use
                        continue;
                    }
                    
                    $startDate = date_create_from_format('m-d-Y', $booking['BookingDate']);
                    $bd = $startDate->format('Y-m-d');
                    
                    if (key_exists($bd, $arrests)) {
                        // We've already looked at an arrest on this date for this case
                        continue;
                    }
                    
                    $arrests[$bd] = 1;
                    
                    if ($booking['ReleaseDate'] == '') {
                        // Defendant is still in custody for this BSN
                        $case['InJail'] = 'Y';
                        $case['AssignedCellID'] = $booking['AssignedCellID'];
                        
                        // Special cases - days under these conditions do not count!
                        switch($booking['AssignedCellID']) {
                            case "WEEKENDER OUT":
                                $case['InJail'] = "W";
                                break;
                            case "IN-HOUSE ARREST":
                                $case['InJail'] = "H";
                                break;
                            case "ESCAPED":
                                $case['InJail'] = "E";
                                break;
                            default:
                                // Ok, if we're here, calculate days served
                                // Person is actually in jail
                                $endDate = date_create(date('Y-m-d'));
                                $ddiff = date_diff($startDate, $endDate);
                                $served = $ddiff->format('%a'); // date_diff doesn't include both start and end
                                
                                if ($served < 0) {
                                    $served = 0;
                                }
                        }
                        
                        $case['DaysServed'] += $served;
                    } else {
                        // The inmate has been released.
                        $endDate = date_create_from_format('m-d-Y', $booking['ReleaseDate']);;
                        $ddiff = date_diff($startDate, $endDate);
                        $served = $ddiff->format('%a') + 1; // date_diff doesn't include both start and end
                        
                        if ($served < 0) {
                            $served = 0;
                        }
                        
                        $case['DaysServed'] += $served;
                    }
                }
            }
        }
    }
}

function buildTrialCases ($dbh, &$trialCases, &$juryTrialEvents, &$infractionTrialEvents, &$nonJuryTrialEvents, &$caselist) {
    global $outpath, $DEBUG, $MSGS, $NOTACTIVE, $casetypesString, $trialtypes, $datefmt, $justCases;
    
    $tcFile = "$outpath/tcases.json";
    
	if ($DEBUG && (file_exists ($tcFile))) {
		print "DEBUG: Reading $tcFile..." . date($datefmt) . "\n";
        
        readJsonFile($trialCases, $tcFile);
        
	} else {
        $count = 0;
        $perQuery = 2000;
        
        while ($count < count($justCases)) {
            // Make a comma-separated list of case numbers (extract $perQuery case numbers from
            // $caselist), being sure to quote each one.
            $inString = sprintf("'%s'", implode("','", array_slice($justCases, $count, $perQuery)));
            
            $query = "
                select
                    CaseNumber,
                    CourtEventType
                from
                    vCourtEvent e with(nolock)
                where
                    CourtEventType in $trialtypes
                    and substring(convert(varchar(10),CourtEventDate,101),1,2) =
                        substring(convert(varchar(10),GETDATE(),101),1,2)
                    and substring(convert(varchar(10),CourtEventDate,101),7,4) =
                        substring(convert(varchar(10),GETDATE(),101),7,4)
                    and CaseNumber in ($inString)
                    and Cancelled = 'No'
                order by
                    CaseNumber
            ";
            
            getData($trialCases, $query, $dbh, null, 'CaseNumber', 1);
            
            $count += $perQuery;

        }
    }
        
    foreach ($trialCases as $casenum => $case) {
        switch($case['CourtEventType']) {
            case 'JT - JURY TRIAL':
                $juryTrialEvents[$casenum] = $case;
                $caselist[$casenum]['JuryTrial'] = 1;
                break;
            case 'IT - INFRACTION TRIAL':
                $infractionTrialEvents[$casenum] = $case;
                $caselist[$casenum]['InfractionTrial'] = 1;
                break;
            case 'NJ - NON JURY TRIAL':
                $nonJuryTrialEvents[$casenum] = $case;
                $caselist[$casenum]['NonJuryTrial'] = 1;
                break;
            default:
                break;
        }
    }
    
    writeJsonFile($trialCases, $tcFile);
    writeJsonFile($juryTrialEvents, "$outpath/jtevents.json");
    writeJsonFile($infractionTrialEvents, "$outpath/itevents.json");
    writeJsonFile($nonJuryTrialEvents, "$outpath/njevents.json");
}


function buildCharges ($dbh, &$charges, &$chargePending, &$caselist) {
    global $outpath, $DEBUG, $MSGS, $DIVLIMIT, $NOTACTIVE, $datefmt, $casetypesString, $csDegrees, $justCases;
    
    $chargeFile = "$outpath/charges.json";
    $chargePendingFile = "$outpath/chargepending.json";
    
    $chargeList = array();
    $rawCharges = array();
    
    if ($DEBUG && (file_exists($chargeFile))) { 
		print "DEBUG: Reading $chargeFile " . date($datefmt) . "\n";
        
        readJsonFile($rawCharges, $chargeFile);
	} else {
        
        $count = 0;
        $perQuery = 1000;
        
        while ($count < count($justCases)) {
            // Make a comma-separated list of case numbers (extract $perQuery case numbers from
            // $caselist), being sure to quote each one.
            $inString = sprintf("'%s'", implode("','", array_slice($justCases, $count, $perQuery)));
            
            $query = "
                select
                    c.CaseNumber,
                    ChargeCount,
                    CASE
                        WHEN ChargeDate IS NULL
                            THEN ''
                        ELSE
                            CONVERT(varchar(10),ChargeDate,101)
                    END as ChargeDate,
                    CourtStatuteNumber,
                    CourtStatuteNumSubSect,
                    CourtStatuteDescription,
                    CourtStatuteLevel,
                    CASE
                        WHEN CourtStatuteDegree = ''
                            THEN 'N'
                        ELSE
                            ISNULL(CourtStatuteDegree,'N')
                    END as CourtStatuteDegree,
                    ISNULL(chg.Disposition,'') as Disposition,
                    CASE
                        WHEN chg.DispositionDate IS NULL
                            THEN ''
                        ELSE
                            CONVERT(varchar(20),chg.DispositionDate,101)
                    END as DispositionDate,
                    1 as fcic
                from
                    vCharge chg with(nolock),
                    vCase c with(nolock)
                where
                    chg.CaseID=c.CaseID
                    and CaseStatus not in $NOTACTIVE
                    and c.CourtType in $casetypesString
                    and c.CaseNumber in ($inString)
                    $DIVLIMIT
                order by
                    c.CaseNumber,
                    ChargeCount
            ";
            
            getData($rawCharges, $query, $dbh, null, 'CaseNumber');
            
            $count += $perQuery;
        }
    }
    
    foreach ($rawCharges as $casenum => $rawCharge) {
        if (key_exists($casenum, $caselist)) {
            $charges[$casenum] = $rawCharge;
            //$caselist[$casenum]['Charges'] = $rawCharge;
            foreach ($charges[$casenum] as $charge) {
                if ($csDegrees[$charge['CourtStatuteDegree']]['val'] < $csDegrees[$caselist[$casenum]['TopChargeDegree']]['val']) {
                    $caselist[$casenum]['TopChargeDegree'] = $charge['CourtStatuteDegree'];
                    $caselist[$casenum]['TopChargeDesc'] = $csDegrees[$charge['CourtStatuteDegree']]['desc'];
                }
                if ($charge['DispositionDate'] == "") {
                    $chargePending[$casenum] = 1;
                    $caselist[$casenum]['ChargePending'] = 1;
                }
            }
        }
    }
    
    if ($MSGS) {
        print "Writing file $chargeFile " . date($datefmt) ."\n\n";
    }
        
    writeJsonFile($charges, $chargeFile);
	
    if ($MSGS) {
        print "Done writing file $chargeFile " . date($datefmt) ."\n\n";
        print "Writing file $chargePendingFile " . date($datefmt) ."\n\n";    
    }
    
    writeJsonFile($chargePending, $chargePendingFile);
    
    if ($MSGS) {
        print "Done writing file $chargePendingFile " . date($datefmt) ."\n\n";
    }
}

function buildWarrants ($dbh, &$warrants, &$caselist) {
    global $outpath, $DEBUG, $MSGS, $NOTACTIVE, $DIVLIMIT, $casetypesString;
    
    $warrFile = "$outpath/warrants.json";
    
    if ($DEBUG && (file_exists($warrFile))) {
        // Read warrants from the JSON file if it exists
		print "DEBUG: Reading $warrFile\n";
        if (!(readJsonFile($warrants, $warrFile))) {
            if ($MSGS) {
                print "Error reading data from '$warrFile'. Will perform lookups.\n";
            }
        }
        foreach ($warrants as $casenum => $warr) {
            $caselist[$casenum]['Warrants'] = 1;
        }
    } else {
		$query = "
			select
				c.CaseNumber
			from
				vWarrant w with(nolock),
				vCase c with(nolock)
			where
				w.CaseID=c.CaseID
				and c.CaseStatus not in $NOTACTIVE
				and c.CourtType in $casetypesString
				and w.Closed = 'N'
				$DIVLIMIT
			order by
				c.LegacyCaseNumber
		";
        
		$rawwarrants = array();
        getData($rawwarrants, $query, $dbh, null, "CaseNumber", 1);
        writeJsonFile($rawwarrants, "$outpath/rawwarrants.json");
        
		foreach ($rawwarrants as $casenum => $warrant) {
            if (key_exists($casenum,$caselist)) {
                $warrants[$casenum] = 1;
                $caselist[$casenum]['Warrants'] = 1;
            }
		}
        
        if ($MSGS) {
			print "\n\n" . count($rawwarrants) . " raw Outstanding warrants\n";
			print count($warrants) . " Outstanding warrants for cases we want \n\n";
		}
        
        writeJsonFile($warrants,"$outpath/warrants.json");
	}
}


function buildCaseList ($dbh, &$caselist, &$reopened, &$divList) {
    global $outpath, $DEBUG, $JUVDIVS, $DIVLIMIT, $NOTACTIVE, $MSGS, $datefmt, $casetypesString;
    
    // Not the global $today, because we want the date in a different format here
    $today = date('m/d/Y');
    
    $rawcases = array();
    
    $rcFile = "$outpath/rawcase.json";
    
    $divassign = array();
    $jdbh = dbConnect("judge-divs");
    $query = "
        select
            division_id as DivisionID,
            division_type as DivisionType
        from
            divisions
        where
            (division_type like '%Misdemeanor%')
            or (division_type like '%Felony%')
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
            select
                c.CaseNumber,
                c.DivisionID,
                c.CaseStyle,
                p.LastName,
                p.FirstName,
                ISNULL(p.MiddleName,'') as MiddleName,
                ISNULL(p.Sex,'') as Sex,
                c.CaseStatus,
                c.CourtType,
                CONVERT(varchar(10),c.FileDate,101) as FileDate,
                CASE
                    WHEN c.DispositionDate IS NULL
                        THEN ''
                    ELSE
                        CONVERT(varchar(10), c.DispositionDate,101)
                END as DispositionDate,
                CASE
                    WHEN c.ReopenDate IS NULL
                        THEN ''
                    ELSE
                        CONVERT(varchar(10), c.ReopenDate,101)
                END as ReopenDate,
                CASE
                    WHEN c.ReopenCloseDate IS NULL
                        THEN ''
                    ELSE
                        CONVERT(varchar(10), c.ReopenCloseDate,101)
                END as ReopenCloseDate,
                c.CaseType,
                CASE
                    WHEN p.DOB IS NULL
                        THEN ''
                    ELSE
                        CONVERT(varchar(10), p.DOB,101)
                END as DOB,
                CaseCounts
            from
                vCase c with(nolock)
                    left outer join vParty p with(nolock) on (c.CaseID = p.CaseID)
            where
                p.PartyTypeDescription in ('DEFENDANT','APPELLANT')
                and c.CourtType in $casetypesString
                and c.CaseStatus not in $NOTACTIVE
                and c.Sealed = 'N'
                and c.Expunged = 'N'
                $DIVLIMIT
            order by
                c.CaseNumber";
        
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
        $caselist[$casenum]['Warrants'] = 0;
        $caselist[$casenum]['NumCharges'] = 0;
        $caselist[$casenum]['TopChargeDegree'] = 'N';
        $caselist[$casenum]['TopChargeDesc'] = 'N - Not Applicable';
        $caselist[$casenum]['LastActivity'] = '';
        $caselist[$casenum]['LastDocketDate'] ='';
        $caselist[$casenum]['LastDocketCode'] = '';
        $caselist[$casenum]['MostRecentEventDate'] = '';
        $caselist[$casenum]['MostRecentEventType'] = '';
        $caselist[$casenum]['FarthestEventDate'] = '';
        $caselist[$casenum]['FarthestEventType'] = '';
        $caselist[$casenum]['FlagsNotes'] = '';
        $caselist[$casenum]['ChargePending'] = 0;
        $caselist[$casenum]['JuryTrial'] = 0;
        $caselist[$casenum]['InfractionTrial'] = 0;
        $caselist[$casenum]['NonJuryTrial'] = 0;
        $caselist[$casenum]['MergedNotesFlags'] = '';
        $caselist[$casenum]['Reopened'] = 0;
        
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