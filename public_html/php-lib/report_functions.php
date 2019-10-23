<?php

function buildNoHearings($dbh, &$noHearings, &$caselist) {
    global $MSGS, $MOTIONS, $datefmt, $today;
    
    // Is there an event scheduled after today for the case?
    
    if ($MSGS) {
        print "Starting buildNoHearings " . date($datefmt) . "\n";
    }
    
    $cases = array_keys($caselist);
    
    if ($MSGS) {
        print "Starting event lookup " . date($datefmt) . "\n\n";
        print "Looking for all events after $today... " . date($datefmt) . "\n";
    }
    
    $events = array();
    
    getVrbEventsByCaseList($cases, $events, 0, $today);
    
    writeJsonFile($events, "/tmp/events.json");
    
    foreach ($caselist as $casenum => $case) {
        if (!key_exists($casenum, $events)) {
	        # No event at all for this case after the earliest date
            $noHearings[$casenum] = 1;
            $caselist[$casenum]['NoHearings'] = 1;
            continue;
	    }
    }
    
    if ($MSGS) {
        print "Done event lookup " . date($datefmt) . "\n";
    }
}


function getLastDocketFromList($cases, $docketlist, &$docketref, $dbh) {
    // It is assumed that the elements in $docketlist are NOT quoted/
    
    $inDocket = sprintf("'%s'", implode("','", $docketlist));
    
    $count = 0;
    $perQuery = 1000;
    
    $dockets = array();
    
    while ($count < count($cases)) {
        $inCase = sprintf("'%s'", implode("','", array_slice($cases, $count, $perQuery)));
        
        $query = "
            select
                DocketCode,
                CONVERT(char(10),EffectiveDate,120) as EffectiveDate,
                CaseNumber
            from
                vDocket with(nolock)
            where
                DocketCode in ($inDocket)
                and CaseNumber in ($inCase)
            order by
                EffectiveDate desc
        ";
        
        getData($dockets, $query, $dbh, null, "CaseNumber", 1);
        
        $count += $perQuery;
    }
    
    foreach ($cases as $casenum) {
        if (key_exists($casenum, $dockets)) {
            $docketref[$casenum] = $dockets[$casenum];
        }
    }
    
    return;
}


function getVrbEventsByCaseList ($cases, &$eventRef, $past=0, $startDate = null){
    
    $count = 0;
    $perQuery = 100;
    
    if ($startDate==null) {
        $startDate = "NOW()";
        if ($past) {
            $dateStr = "and start_date < $startDate";
        } else {
            $dateStr = "and start_date >= $startDate";
        }
    } else {
        if ($past) {
            $dateStr = "and start_date < '$startDate'";
        } else {
            $dateStr = "and start_date >= '$startDate'";
        }
    }
    
    $dbh = dbConnect("vrb2");
    
    while ($count < count($cases)) {
        $inString = sprintf("'%s'", implode("','", array_slice($cases, $count, $perQuery)));
        
        $query = "
            select
                ec.case_num as CaseNumber,
                ec.event_id as EventID,
                DATE_FORMAT(e.start_date,'%m/%d/%Y') as EventDate,
                DATE_FORMAT(e.start_date,'%Y-%m-%d') as ISODate,
                e.event_name as EventType
            from
                event_cases ec
                    left outer join events e on (ec.event_id = e.event_id)
            where
                case_num in ($inString)
                $dateStr
            order by
                start_date desc
        ";
        
        getData($eventRef, $query, $dbh, null, "CaseNumber", 1);
        
        $count += $perQuery;
    }
    
}


function buildNotes (&$caselist) {
    global $outpath, $DEBUG, $MSGS, $datefmt, $justCases, $casetypesString;
    
    $merged = array();
    
    $mergedFile = "$outpath/mergedNotesFlags.json";

    if ($MSGS) {
        print "Merging flags and most recent notes for cases... " . date($datefmt) . "\n";
    }
    
    $icmsDbh = dbConnect("icms");
    
    $cases = array_keys($caselist);
    
    $count = 0;
    $perQuery = 1000;
    
    $notes = array();
    $flags = array();
    
    while ($count < count($cases)) {
        
        $inString = sprintf("'%s'", implode("','", array_slice($cases, $count, $perQuery)));
        
        $query = "
            select
                casenum as CaseNumber,
                note as CaseNote,
                date as NoteDate
            from
                casenotes
            where
                casenum in ($inString)
                and private = 0
            order by
                date desc
        ";
        
        getData($notes, $query, $icmsDbh, null, "CaseNumber", 1);
    
    
        $query = "
            select
                f.casenum as CaseNumber,
                f.flagtype as FlagType,
                f.idnum as FlagID,
                ft.dscr as FlagDesc
            from
                flags f
                    left outer join flagtypes ft on f.flagtype = ft.flagtype
            where
                casenum in ($inString)
            order by
                casenum desc,
                idnum
        ";
    
        getData($flags, $query, $icmsDbh, null, "CaseNumber");
        
        $count += $perQuery;
    }
    
    mergeNotesAndFlags($notes, $flags, $merged);
    
    foreach ($merged as $casenum => $note) {
        if (key_exists($casenum, $caselist)) {
            $caselist[$casenum]['MergedNotesFlags'] = $note;
        }
    }
    
    if ($MSGS) {
        print "Writing merged notes and flags to '$mergedFile'..." . date($datefmt) . "\n";
    }
    
    writeJsonFile($merged, $mergedFile);
}


function mergeNotesAndFlags ($notes, $flags, &$merged) {
    // Merge the last note for a case (which is what $notes should be) with all of the
    // existing flags as a single string.
    
    foreach ($notes as $casenum => $note) {
        $merged[$casenum] = htmlentities($note['CaseNote']);
    }
    
    foreach ($flags as $casenum => $flagArr) {
        if (!key_exists($casenum, $merged)) {
            // Make sure the key is defined (there may not have been a note to define it above)
            $merged[$casenum] = '';
        }
        
        $imgTag = '';
        $spanTag = '<span style="font-color: green; font-weight: bold">&Dagger;';
        
        foreach ($flagArr as $flag) {
            if (preg_match('/Requires Action|Judge/', $flag['FlagDesc'])) {
                $imgTag = '<img src="/images/flag-red.gif">';
                $spanTag = '<span style="font-color: red; font-weight: bold">';
            } elseif (preg_match('/CM Action/', $flag['FlagDesc'])) {
                $imgTag = '<img src="/images/flag-cm.gif">';
                $spanTag = '<span style="font-color: green; font-weight: bold">';
            }
            $merged[$casenum] = sprintf("%s%s%s</span>;%s", $imgTag, $spanTag,
                                        $flag['FlagDesc'], $merged[$casenum]);
        }
    }
}


function writeReportFile ($rptPath, $title, $subtitle, $data, $outFile) {
    global $today, $reportCols;
    
    $reportData = array(
        'date' => $today,
        'title' => $title,
        'subtitle' => $subtitle,
        'reportCols' => $reportCols,
        'reportData' => $data
    );
    
    writeJsonFile($reportData, "$rptPath/$outFile");
}


function buildLastDocket ($dbh, &$caselist) {
    global $outpath, $DEBUG, $MSGS, $DIVLIMIT, $NOTACTIVE, $casetypesString, $datefmt, $justCases;
    
    $docketFile = "$outpath/lastdocket.json";
    $lastActFile = "$outpath/lastactivity.json";
    
    $readDocket = 0;
    $readLastAct = 0;
    
	$rawlastdocket = array();
    $lastDocket = array();
    $lastDockets = array();
    $lastActivity = array();
    
	if ($DEBUG) {
        if (file_exists ($docketFile)) {
            print "DEBUG: Reading $docketFile " . date($datefmt) . "\n";
            readJsonFile($lastDocket, $docketFile);
            $readDocket = 1;
            // Populate $lastDockets from this
            foreach ($lastDocket as $casenum => $docket) {
                array_push($lastDockets, $docket);
                $caselist[$casenum]['LastDocketDate'] = $docket['EffectiveDate'];
                $caselist[$casenum]['LastDocketCode'] = $docket['DocketCode'];
            }
        }
        if (file_exists ($lastActFile)) {
            print "DEBUG: Reading $lastActFile " . date($datefmt) . "\n";
            readJsonFile($lastActivity, $lastActFile);
            foreach ($lastActivity as $casenum => $activity) {
                $caselist[$casenum]['LastActivity'] = $activity;
            }
            $readLastAct = 1;
        }
	}
    
    if (!$readDocket) {
        
        $count = 0;
        $perQuery = 1000;
        $tempdockets = array();
        
        if ($MSGS) {
            print "Reading last dockets from database... " . date($datefmt) . "\n";
        }    
        
        while ($count < count($justCases)) {
            // Make a comma-separated list of case numbers (extract $perQuery case numbers from
            // $caselist), being sure to quote each one.
            $inString = sprintf("'%s'", implode("','", array_slice($justCases, $count, $perQuery)));
            
            $query = "
                select
                    c.CaseNumber,
                    CONVERT(varchar(10),x.EffectiveDate,101) as EffectiveDate,
                    x.DocketCode,
                    c.CaseID
                from
                    vCase c with(nolock),
                    (
                        select
                            d1.CaseNumber,
                            CONVERT(varchar(10),d1.EffectiveDate,101) as EffectiveDate,
                            d1.DocketCode,
                            d1.SeqPos,
                            d1.CaseID
                        from
                            vDocket d1 with(nolock)
                        where
                            d1.EffectiveDate = (
                                select
                                    MAX(d2.EffectiveDate)
                                from
                                    vDocket d2 with(nolock)
                                where
                                    d2.CaseID = d1.CaseID
                            )
                    ) as x
                where
                    x.CaseID = c.CaseID
                    and CaseStatus not in  $NOTACTIVE
                    and CourtType in $casetypesString
                    and c.CaseNumber in ($inString)
                    $DIVLIMIT
                order by
                    c.CaseNumber asc
            ";
            
            getData($tempdockets, $query, $dbh, null, 'CaseNumber');
            
            $count += $perQuery;
        }
        
        if ($MSGS) {
            print "Done reading last dockets from database... " . date($datefmt) . "\n";
        }
        
		print "Selected " . count($tempdockets) . " rows. " . date($datefmt) . "\n"; 
        
        foreach ($tempdockets as $casenum => $row) {
            array_push($lastDockets, $row[0]);
            $lastDocket[$casenum] = $row[0];
            $caselist[$casenum]['LastDocketDate'] = $row[0]['EffectiveDate'];
            $caselist[$casenum]['LastDocketCode'] = $row[0]['DocketCode'];
		}
        
        if ($MSGS) {
            print "Kept " . count($lastDockets) . " rows. " . date($datefmt) . "\n";
            print "Writing $docketFile..." . date($datefmt) . "\n";
        }
        
        writeJsonFile($lastDocket, $docketFile);
        
        if ($MSGS) {
            print "Finished writing $docketFile " . date($datefmt) . "\n";
        }
    }
    
    if (!$readLastAct) {
        # Need to populate the %lastactivity hash
        
        foreach ($lastDockets as $lastdocket) {
            $casenum = $lastdocket['CaseNumber'];
            $lastActivity[$casenum] = $lastdocket['EffectiveDate'];
            $caselist[$casenum]['LastActivity'] = $lastdocket['EffectiveDate'];
        }
        
        if ($MSGS) {
            print "Writing $lastActFile... " . date($datefmt) . "\n";
        }
        
        writeJsonFile($lastActivity, $lastActFile);
        
        if ($MSGS) {
            print "Finished writing $lastActFile " . date($datefmt) . "\n";
        }
    }
}


function buildEvents (&$caselist) {
    global $outpath, $DEBUG, $MSGS, $datefmt, $justCases;
    
    $events = array();
    $lastEvent = array();
    
    $eventsFile = "$outpath/events.json";
    $lastEventFile = "$outpath/lastevents.json";

    $readEvents = 0;
    $readLastEvent = 0;
    
	if ($DEBUG ) {
        if (file_exists($eventsFile)) {
            print "DEBUG: Reading $eventsFile" . date($datefmt) . "\n";
            readJsonFile($events, $eventsFile);
            $readEvents = 1;
        }
        if (file_exists($lastEventFile)) {
            print "DEBUG: Reading $lastEventFile" . date($datefmt) . "\n";
            readJsonFile($lastEvent, $lastEventFile);
            $readLastEvent = 1;
        }
	}
    
    if ((!$readEvents) || (!$readLastEvent)){
        if ($MSGS) {
            print "Getting events - farthest and most recent..." . date($datefmt) . "\n\n";
        }
        
        getVrbEventsByCaseList($justCases, $events, 0);
        getVrbEventsByCaseList($justCases, $lastEvent, 1);
        
        if ($MSGS) {
            print "I found " . count($events) . " farthest events and " . count($lastEvent) . " most recent events.\n\n";
        }
        
        if ($MSGS) {
            print "Writing $eventsFile and $lastEventFile... " . date($datefmt) . "\n";
        }
        
        writeJsonFile($events, $eventsFile);
        writeJsonFile($lastEvent, $lastEventFile);
        
        if ($MSGS) {
            print "Finished writing $eventsFile and $lastEventFile " . date($datefmt) . "\n";
        }
    }
    
    foreach ($justCases as $casenum) {
        if (key_exists($casenum, $events)) {
            $caselist[$casenum]['FarthestEventDate'] = $events[$casenum]['EventDate'];
            $caselist[$casenum]['FarthestEventType'] = $events[$casenum]['EventType'];
        }
        if (key_exists($casenum, $lastEvent)) {
            $caselist[$casenum]['MostRecentEventDate'] = $lastEvent[$casenum]['EventDate'];
            $caselist[$casenum]['MostRecentEventType'] = $lastEvent[$casenum]['EventType'];
        }
    }
}

?>