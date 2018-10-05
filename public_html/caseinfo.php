<?php
#
# caseinfo.php - PHP routines to pull deta 
#                use by view.php & order gen stuff..
#
# 5/3/13 derived from view.php
#
#

require_once 'php-lib/common.php';
require_once 'php-lib/db_functions.php';

include_once "icmslib.php";  

$DEBUG=getenv("DEBUG");

global $attorneyTypes;
$attorneyTypes = array("AAG", "ADJJ", "AFCP", "AGAL", "APD", "ASA", "ATFV", "ATTY", "CTAP", "CWLS", "PD");

# prettytime takes a partially-formatted hh:mm:ss:mmm time from sql
# and returns a nicely formatted value (via a call to fix_time)

function pretty_time($t) {
   if (stripos($t,"m")) { return $t; } # already formatted
   return fix_time(str_replace(":","-",$t));
}

#
# is_adoption returns 1 if a case in an adoption case, 0 otherwise
#
function is_adoption($baseinfo) {
   if (($baseinfo[ucn_type]==2 && $baseinfo[privacy]==3) || preg_match("/DEPENDENCY\/ADOP|ADOPT|ADOPTION/i",$baseinfo[action_code_description])) { return 1; }
   return 0;
}


#
# get the name, role, and roletype for the signer if present; transmogrify based on
# case type (from County to Acting Circuit, for example)
#
function get_name_and_role (&$orderObj) {
    if (isset($orderObj['dbh'])) {
        $dbh = $orderObj['dbh'];
    } else {
        $dbh = dbConnect("icms");
    }
    
    $query = "
        select
            first_name as FirstName,
            middle_name as MiddleName,
            last_name as LastName,
            suffix as Suffix,
            role,
            roletype,
            office,
            courthouse
        from
            users
        where
            userid = :userid
    ";
    
    $userarr = getDataOne($query, $dbh, array('userid' => $orderObj['userid']));
    
    if (sizeof($userarr)) {
        foreach ($userarr as $key => $val) {
            $orderObj[$key] = $val;
        }
        
        $orderObj['username'] = buildName($userarr);
    
        # for county judges on circuit cases, list as "acting circuit"
        if (preg_match("/county/i",$orderObj['role']) && preg_match("/judge/i",$orderObj['role'])) {
            # NOTE: INCOMPLETE LIST...
            if (preg_match("/CA|CF|DR|GA|DP|CJ|CP/",$orderObj['ucn'])) {
                $orderObj['role'] = "Acting Circuit Judge";
            }
        }
    }
}


function getObjInfo(&$orderObj) {
    if (isset($orderObj['dbh'])) {
        $dbh = $orderObj['dbh'];
    } else {
        $dbh = dbConnect("icms");
    }

    if ($orderObj['docid'] != null) {
        $query = "
            select
                ucn,
                CASE
                    WHEN signature_img is null THEN 'N'
                    ELSE 'Y'
                END as esigned,
                queue,
                formname,
                CASE doc_type
                	WHEN 'FORMORDER' then 'IGO'
        		    WHEN 'DVI' then 'DVI'
                 	WHEN 'OLSORDER' then 'PropOrd'
        		 	WHEN 'WARRANT' then 'Warrant'
        		 	WHEN 'EMERGENCYMOTION' then 'EmerMot'
    			 	ELSE 'PropOrd'
                END as DocType
            from
                workflow
            where
                doc_id = :docid
        ";
        
        $doc = getDataOne($query, $dbh, array('docid' => $orderObj['docid']));
        
        foreach (array_keys($doc) as $key) {
            $orderObj[$key] = $doc[$key];
        }
        
        if (array_key_exists('ucn', $doc)) {
            get_esig_status($orderObj);
        }
    
        //if (sizeof($orderObj['docInfo'])) {
        //    get_esig_status($orderObj['docInfo']);
        //}
    } else {
        $orderObj['allsigned'] = 0;
        $orderObj['formname'] = "";
        $orderObj['queue'] = $orderObj['userid'];
    }
}



#
# get_pioneer_notes pulls notes from the Pioneer database
#

function get_pioneer_notes($dbh,$id) {
   $x=sqlarrayp($dbh,"SELECT Convert(varchar(10),NoteDate,121),UserLogin,NoteText,CaseNoteID,null,null,PrivateNote FROM tblCaseNote a, tblParty b WHERE b.PartyID=a.CreateByUserID and a.CaseId=? order by NoteDate desc",array($id));
   # at DISPLAY time, we need to match userid to ICMS userids
   # turns out in at least one pioneer county, ICMS user grammerj=Pioneer users jgrammer.
   # for now, we'll assume all pioneer systems are like that.
   # we only deal with one other, and no judge notes there...
   if (count($x)>0) {
      for ($i=0;$i<count($x);$i++) {
          $x[$i][1]=substr($x[$i][1],1).substr($x[$i][1],0,1);
      }
   } else { $x=array(); }
   return $x;
}



#
# field_sort sorts a multi-dimensional array by creating a joined, 
# keyed version, sorting that, and then restoring it to the original format.
#
# direction=0; ascending; direction=1; descending

function field_sort($arr,$keycol,$direction) {
   if (!$arr) { return($arr); }
   for ($i=0;$i<count($arr);$i++) {
      $key=$arr[$i][$keycol];
      $karr[$key]=$i;
#     echo "*$key:$i<br>";
   }
   if ($direction==0) { ksort($karr); }
   else { krsort($karr); }
   $i=0;
   foreach ($karr as $key=>$val) {
#     echo "*$key:$val<br>";
      $newarr[$i]=$arr[$val];
      $i++;
   }
   return $newarr;
}


#
# get_notes_and_flags gets the notes and flags data from 
#                     the icms db (or icms 2.5's db if this is circuit8
#
function get_notes_and_flags($ucn,$id,$dbh,$dbtype) {
   global $USER,$GROUPS,$DEBUG;
   $notesarr=array();
   $icms=db_connect("icms");
   if ($GROUPS[CASENOTES]) { 
      $cls="<span class='ui-icon ui-icon-close noteclose' style='display:inline-block; cursor:pointer'></span>";
      $clsflag="<span class='ui-icon ui-icon-close flagclose' style='display:inline-block; cursor:pointer'></span>";
   } else {
      $cls="";
      $clsflag="";
   }
   $canseeprivate=sqlgetonep($icms,"select json from config where user=? and module='canseeprivate'",array($USER));
   $notesarr=sqlarrayp($icms,"select date,userid,note,seq,docref,attachments,private from casenotes where casenum=? order by date desc,seq desc",array($ucn));
   if ($dbtype=="pioneer") { # add pioneer casenotes
      $pnotes=get_pioneer_notes($dbh,$id);
      if ($DEBUG) {  echo "\n\n***",count($pnotes),"\n\n"; }
#      if (count($notesarr)==0) { $notesarr=array(); }
      $notesarr=array_merge($notesarr,$pnotes);
   }
#   echo count($notesarr)," new notes found\n";
   #
   # FLAGS
   #
   $flagsarr=sqlarrayp($icms,"select idnum,date,userid,dscr,color from flags,flagtypes where flags.flagtype=flagtypes.flagtype and casenum=? order by date desc,idnum desc",array($ucn));
   #######################################################################
   # FOR the 8th, which has legacy case notes not yet integrated
   # A TEMPORARY, BUT PORTABLE, HACK TO SNAG NOTES AND FLAGS FROM 2.5....
   ########################################################################
   if (db_exists("icms2.5")) {
      $dbh=db_connect("icms2.5");
      $notesarrX=sqlarrayp($dbh,"select date,userid,note,seq,0,0,0 from casenotes where casenum=? order by date desc, seq desc",array($ucn));
      $notesarr=array_merge($notesarr,$notesarrX);
      $notesarr=field_sort($notesarr,0,1);
      $flagsarrX=sqlarrayp($dbh,"select idnum,date,userid,dscr from flags,flagtypes where flags.flagtype=flagtypes.flagtype and casenum=?",array($ucn));
      $flagsarr=array_merge($flagsarr,$flagsarrX);
      $flagsarr=field_sort($flagsarr,1,1);
   }
   # gen the html for the notes list
   foreach ($notesarr as $anote) {
      list($date,$userid,$note,$seq,$docref,$attach,$private)=$anote;
      if ($DEBUG) { echo "\n***$date;$userid;$note;$seq;$docref;$attach;$private\n"; }
#      $date=$note[0];
      $date=substr($date,5,2)."/".substr($date,8,2)."/".substr($date,0,4);
      $notesuf="";
      # for now, one attachment
      if ($attach) {
         $notesuf=" <img src=icons/document.png onClick=NotesShowAttach($seq);>";
      }
      # and one doc ref
      if ($docref) {
         $notesuf.=" <img src=icons/document.png onClick=NotesShowDocRef('$docref');>";
      }
      if ($private && $USER!=$userid && strpos($canseeprivate,$userid)===false) {
         if ($DEBUG) { echo "\n\n***skipping private note for $userid ($USER)\n"; }
         continue;   # skip this private note
      }
      if ($private) { $bgcolor="#F9A7B0"; } # was #FFFF88
      else { $bgcolor="yellow"; }
      $notes.="<tr><td>$date</td><td>$userid</td><td style='background-color:$bgcolor'>$note</td><td>$notesuf</td><td style='display:none'>$seq</td><td>$cls</td></tr>";
   }
   # now generate the html for the flags list
   foreach ($flagsarr as $flag) {
      list($id,$date,$user,$txt,$color)=$flag;
      $date=substr($date,5,2)."/".substr($date,8,2)."/".substr($date,0,4);
      $flags.="<tr><td>$date</td><td>$user</td><td><div class=wfcircle style=\"background:$color\"><td>$txt</td><td style=\"display:none\">$id</td><td>$clsflag</td></tr>";
   }
   # OK, now look at the new stuff...
   return(array($notes,$flags,$notesarr,$flagsarr));
}


$CASEGLOBAL=array(); # used for new visions stuff...



#
# get_bar_emails looks at the bar_members table in the
#                olscheduling database to pull the "official"
#                bar emails for each user;
# TODO: Needs to look at the default and per-case emails as well
#       once we get the eservice interface running...
# 2/2/15 NO LONGER USED...

function get_bar_emails($dbh,$schedb,$ucn,$id,$dbtype) {
   global $CASEGLOBAL;
   # get some bar #s
   if ($dbtype=="clericus") {
      $q="select attorneybarnumber from vw_party_details where caseid=? and attorneybarnumber>0";
   } elseif ($dbtype=="crtv" || $dbtype=="courtview") {
      $q="select b.bar_cd from ptyatty a,atty b where a.case_id=? and a.atty_id=b.atty_id and b.bar_cd>0";
   } elseif ($dbtype=="facts") { 
       return array(); # STUB
   } elseif ($dbtype=="pioneer") {
      $q="select tblParty.BarNumber from tblCaseParty JOIN tblParty ON tblCaseParty.PartyId = tblParty.PartyId where tblCaseParty.CasePartyType='ATT' and tblCaseParty.CaseId=? and tblCaseParty.DeactivateDate is null and tblParty.BarNumber is not null and tblParty.BarNumber != ''";
   } elseif ($dbtype=="new vision") {
        $suffix=substr($CASEGLOBAL[$ucn][table_source],-2);
        $ts="atty_$suffix";
        $q="select atty_code from $ts where case_id=?";
   } else { echo "get_bar_emails: Unsupported dbtype of $dbytpe"; exit; }
   $barnums=sqlarrayp($dbh,$q,array($id));
   for ($i=0;$i<count($barnums);$i++) { $barnumlist.=$barnums[$i][0].","; }
   $barnumlist=substr($barnumlist,0,-1);
   $q="select bar_num,email from bar_members where bar_num=?";
   $baremailsraw=sqlarrayp($schedb,$q,array($barnumlist));
   for ($i=0;$i<count($baremailsraw);$i++) {
      $baremails[$baremailsraw[$i][0]]=$baremailsraw[$i][1];
   }
   return $baremails;
}

   class BaseRequestType {
      public $ApplicationID;
      public $ApplicationName;
      public $UserID;
      public $RequestTime;
      public $ClientIP;
      public $UserOrganizationID_x0020_;
   }

   class GetElectronicServiceListCaseRequestType extends BaseRequestType {
      public $UniformCaseNumber;
      public $CaseId;
      public $LogonName;
      public $PassWord;
   }

#
# get_portal_emails queries the statewide e-Filing Portal
#     and returns a two-dimensional array:
#     [ [name,bar #,email1, email2, email3, uid ]... ]
#     for each active and "opted-in" filer...

function get_portal_emails($ccisucn) {
   global $DEBUG;
   $settings=load_conf_file("eservice.json");
   if (!$settings) {
      echo "get_portal_emails: trouble reading eservice.json file\n<br>";
      logerr("get_portal_emails: trouble reading eservice.json file");
      return array();
   }
   $client = new SoapClient($settings->{WSDL},
       array("features"   => SOAP_SINGLE_ELEMENT_ARRAYS | SOAP_USE_XSI_ARRAY_TYPE,
             "encoding"   => "utf-8",
             "trace"      => 1, # enable trace to view what is happening
             "exceptions" => 0, # disable exceptions
             "cache_wsdl" => 1) # disable any caching on the wsdl, encase you alter the wsdl server
   );

   $req = new GetElectronicServiceListCaseRequestType();
   $req->LogonName = $settings->{username};
   $req->PassWord = $settings->{password};
   $req->UniformCaseNumber = $ccisucn;

   $req->UserID = 0;
   $req->CaseId = 0;
   $req->UserOrganizationID_x0020_ = 0;
   $req->RequestTime = "0001-01-01T00:00:00";

   $resp = $client->GetElectronicServiceListCase(array("request" => $req));
   if ($DEBUG) { var_dump($resp); }
   $arr=array();

   if ($resp != null && isset($resp->GetElectronicServiceListCaseResult)){
      $resp = $resp->GetElectronicServiceListCaseResult;
      if ($resp->OperationSuccessful && isset($resp->ElectronicServiceListCase)) {
         $filers = $resp->ElectronicServiceListCase->Filers;
         foreach($filers as $filer) {
            $x[0]=$filer->Name;
            $x[1]=$filer->BarNumber;
            $x[2]=$filer->PrimaryEmailAddress;
            if (isset($filer->AlternateEmailAddress1)){
               $x[3]=$filer->AlternateEmailAddress1;
            }
            if (isset($filer->AlternateEmailAddress2)){
               $x[4]=$filer->AlternateEmailAddress2;
            }
            if (isset($filer->EPortalUserId)) {
               $x[5]=$filer->EPortalUserId;
           }
            $arr[]=$x;
         }
      }
   }
   return $arr;
}



#
# get_processes_courtview pulls clericus processes from the CLERICUS database
#

function get_processes_courtview($dbh,$id) {
   $q="select convert(varchar,issue_dt,101),c.first_name,c.middle_name,c.last_name,c.sffx_cd,d.dscr,e.first_name,e.middle_name,e.last_name,e.sffx_cd,convert(varchar,served_dt,101),convert(varchar,cancel_dt,101) from wrnt a,jdg b,idnt c,wrntcd d,idnt e where case_id=? and wrnt_jdg_id=b.jdg_id and b.idnt_id=c.idnt_id and a.wrnt_cd=d.wrnt_cd and a.idnt_id=e.idnt_id order by issue_dt desc";
   $rawprocesses=sqlarrayp($dbh,$q,array($id));
   $i=0;
   foreach ($rawprocesses as $process) {
      list($idate,$first,$middle,$last,$suffix,$desc,$pfirst,$pmiddle,$plast,$psuffix,$serveddt,$canceldt)=$process;
      if ($serveddt!="") { $disstr="$serveddt SERVED"; }
      if ($canceldt!="") { $disstr="$canceldt CANCELLED"; }
      $dparty="$pfirst $pmiddle $plast $psuffix";
      $processes[$i++]=array($idate,"$first $middle $last $suffix",$desc,$disstr,$dparty);
   }
   return $processes;
}



#
# get_process_dispositions returns a lookup table for process_disposition
#                          codes for CLERICUS
#
function get_process_dispositions($dbh) {
   $q="select process_disposition_ID,process_disposition_description from cd_process_disposition";
   $rawprosdispos=sqlarrayp($dbh,$q,array());
   for ($i=0;$i<count($rawprosdispos);$i++) {
      $prosdispos[$rawprosdispos[$i][0]]=$rawprosdispos[$i][1];
   }
   return $prosdispos;
}


#
# get_processes_clericus pulls clericus processes from the CLERICUS database
#

function get_processes_clericus($dbh,$id) {
   # snag process dispo table...
   $prosdispos=get_process_dispositions($dbh);
   $processes=array();
   $q="select convert(varchar,a.IssueDate,101),JudgeFullName,JudgeSuffix,a.ProcessDescription,b.FullName,b.Suffix,convert(varchar,DisposedDate,101),c.process_disposition_id from vw_active_process_details a,vw_active_process_party_details b,active_process c,party d where a.Active_Process_ID=b.Active_Process_ID and a.Active_Process_ID=c.Active_Process_ID and a.partyid=d.party_id and d.case_id=? order by issuedate desc";
   $rawprocesses=sqlarrayp($dbh,$q,array($id));
   $i=0;
   foreach ($rawprocesses as $process) {
      list($idate,$jname,$jsuff,$desc,$dparty,$dsuffix,$disdate,$dispid)=$process;
      $processes[$i++]=array($idate,"$jname $jsuff",$desc,"$disdate $prosdispos[$dispid]",$dparty);
   }
   return $processes;
}

#
# get_processes_pioneer - Retrieves processes from Pioneer system
#

function get_processes_pioneer($dbh,$id) {
  $q="select Convert(varchar(10), tblCaseProcessAction.IssueDate,101) as IssueDate, tblProcessActionType.ProcessActionTypeDescription, Judge.FirstName as JudgeFirstName, Judge.MiddleName as JudgeMiddleName, Judge.LastOrBusinessName as JudgeLastName, Defendant.FirstName as DefendantFirstName, Defendant.MiddleName as DefendantMiddleName, Defendant.LastOrBusinessName as DefendantLastName, tblLookup.Description, Convert(varchar(10), tblCaseProcessAction.ExecuteDate,101) as ExecuteDate 
        from tblCaseProcessAction
        left join tblProcessActionType on tblCaseProcessAction.ProcessActionTypeID = tblProcessActionType.ProcessActionTypeID left join tblPartyName as Judge on tblCaseProcessAction.PartyJudgeID = Judge.PartyID left join tblPartyName as Defendant on tblCaseProcessAction.IssuedToPartyID = Defendant.PartyID
        left join tblLookup on tblLookup.Code = tblCaseProcessAction.ExecuteStatusCode
        where tblCaseProcessAction.CaseID = ? and tblLookup.LookupGroup = 'ExecuteStatus'";
    $res=sqlarrayp($dbh,$q,array($id));

  $processes=array();
  for ($i=0;$i<count($res);$i++) {
    list($idate, $desc, $jfname, $jmname, $jlname, $dfname, $dmname, $dlname, $dispo, $dispodate)=$res[$i];
    $processes[$i][0]=$idate;
    $processes[$i][1]=trim($jfname.' '.$jmname. ' '.$jlname);
    $processes[$i][2]=$desc;
    $processes[$i][3]="$dispodate $dispo";
    $processes[$i][4]=trim($dfname.' '.$dmname. ' '.$dlname);
  }
  
  return $processes;
}



function get_processes_facts($dbh,$id) {

$q = <<< EOT
SELECT
    TO_CHAR(fcs_writ_mstr.issue_dt, '%m/%d/%Y'),
    fcs_writ_mstr.jugde_cd,
    fcb_judge.judge_nm,
    fcs_writ_typ.dessc,
    fcs_writ_mstr.part_id,
    doc_num
FROM
    fcs_writ_mstr
LEFT JOIN fcb_judge ON fcs_writ_mstr.jugde_cd = fcb_judge.judge
LEFT JOIN fcs_writ_typ ON fcs_writ_mstr.writ_typ = fcs_writ_typ.writ_typ
WHERE 
    fcs_writ_mstr.cs_id=?
EOT;


$q_parties = <<< EOT
SELECT
    fcs_prty_nm_mstr.part_id,
    fcs_prty_nm_mstr.prty_nm_21 AS last_name,
    fcs_prty_nm_mstr.prty_nm_22 AS first_name,
    fcs_prty_nm_mstr.prty_nm_23 AS middle_name,
    fcs_prty_nm_mstr.suffix AS suffix_name
FROM fcs_prty_nm_mstr
WHERE fcs_prty_nm_mstr.cs_id = ?
EOT;


  $res_parties = sqlarrayp($dbh,$q_parties,array($id));

  $parties=array();
  for ($i=0;$i<count($res_parties);$i++) {
    list($part_id, $party_lname, $party_fname, $party_mname, $party_suffix)=$res_parties[$i];
    $parties[$part_id] = trim($party_fname . ' ' . $party_mname . '  ' . $party_lname . ' ' . $party_suffix);
  }

  $res = sqlarrayp($dbh, $q, array($id));
  # make a list of doc_nums for the next query
   for ($i=0;$i<count($res);$i++) {
      if ($i!=0) {$docnums.=","; }
      $docnums.=$res[$i][5];
   }
   if ($docnums!="") {
     # now find cancellation or served dates and times
     $q2="SELECT
           doc_num,
           TO_CHAR(can_dt, '%m/%d/%Y'),
           fcs_writ_reasn_cd.desc,
           TO_CHAR(srvc_dt, '%m/%d/%Y'),
           caa16340003
        FROM fcs_writ_srvc
        LEFT JOIN caa16340 ON
           caa16340001=srvc_flg_cd
        LEFT JOIN fcs_writ_reasn_cd ON
           fcs_writ_srvc.can_reasn = fcs_writ_reasn_cd.writ_reasn_cd
        WHERE doc_num IN ($docnums)
        ORDER BY attpmt_num";
     if ($DEBUG) { echo "***running $q2 now;docnum=$docnums\n"; }
     $arr2=sqlarrayp($dbh,$q2,array());
     for ($i=0;$i<count($arr2);$i++) {
        $writstat[$arr2[$i][0]]=array($arr2[$i][1],$arr2[$i][2],$arr2[$i][3],$arr2[$i][4]);
     }
  }
  $processes=array();
  for ($i=0;$i<count($res);$i++) {
    list($idate, $judge, $judge_nm, $desc, $part_id, $doc_num)=$res[$i];
    list($service_cancel_dt, $service_cancel_reason, $service_dt,$dispo)=$writstat[$doc_num];
    $processes[$i][0]=$idate;

    $judge_nm = preg_replace("/[^A-Z ]/", '', strtoupper($judge_nm));
    list(  $jfn, $jmn, $jln ) = split( ' ', $judge_nm );

    if ( $jln ) {
        $processes[$i][1]=trim($jfn . ' ' . $jmn . ' ' . $jln);
    }
    else {
        $processes[$i][1]=trim($judge);
    }

    if ($service_dt) {
      $dispodate = $service_dt;
    } else {
      $dispodate = $service_cancel_dt;
      $disp = $service_cancel_reason;
    }

    $processes[$i][2]=$desc;
    $processes[$i][3]="$dispodate $dispo";
    $processes[$i][4]=$parties[$part_id];
  }
  
  return $processes;
}


#
# get_processes_new_vision pulls process from the new vision database
# NOTE: CURRENTLY JUST A STUB

function get_processes_new_vision($dbh,$id) {
   return array(); # STUB
}

#
# get_processes pulls processes from the clerk database
#

function get_processes($dbh,$id,$dbtype) {
   switch ($dbtype) {
      case 'clericus': 
         $processes=get_processes_clericus($dbh,$id);
         break;
      case 'crtv': 
      case 'courtview': 
         $processes=get_processes_courtview($dbh,$id);
         break;
      case 'facts': 
         $processes=get_processes_facts($dbh, $id);
         break;
      case 'pioneer': 
         $processes=get_processes_pioneer($dbh,$id);
         break;
      case 'new vision': 
         $processes=get_processes_new_vision($dbh,$id);
         break;
      default:
        echo "get_processes: Unsupported dbtype $dbtype for $id\n";
        exit(1);
    }
   return $processes;
}


#
# function show_processes creates the appropriate table lines..
#
function show_processes($processes) {
   for ($i=0;$i<count($processes);$i++) {
     list($idate,$jname,$desc,$dispo,$dparty)=$processes[$i];
     echo "<tr><td>$idate</td><td>$jname</td><td>$desc</td><td>$dispo</td><td>$dparty</td></tr>";
   }
}



function get_events_clericus($dbh,$id) {
   $q="select CalendarDate,CalendarTime, EventTypeDescription,LocationDescription+' - '+Room,ResultsDescription from vw_event_details where caseID=? order by CalendarDateTime desc";
   $events=sqlarrayp($dbh,$q,array($id));
   return $events;
}



# NOTE: don't think i'm using event_cd,last,first,middle currently.

function get_events_courtview($dbh,$id) {
   # date,time,description, location
   $q="SELECT CONVERT(varchar,c.blk_dt,101), CONVERT(varchar,c.start_tm,114),
         d.dscr, c.loc_cd, g.dscr
        FROM evnt a 
        JOIN evnttm b ON a.evnt_id=b.evnt_id
        JOIN jdgblktm c ON b.jdg_blktm_id=c.jdg_blktm_id 
        JOIN evntcd d ON  a.evnt_cd=d.evnt_cd 
        LEFT JOIN rsltcd g ON a.rslt_cd=g.rslt_cd
        WHERE a.case_id=?
        ORDER by c.blk_dt desc";
   $events=sqlarrayp($dbh,$q,array($id));
   return $events;
}

#
# get_events_pioneer - Retrieves events from pioneer system
#

# CourtResult 

function get_events_pioneer($dbh,$id) {
  $q="SELECT Convert(varchar(10), tblCaseEvent.CaseStartDateTime,101) as [Date], Convert(varchar(20),tblCaseEvent.CaseStartDateTime,114) as [Time], tblEventType.EventTypeDescription, tblEvent.CourtRoomCode, tblLookup.Description
    FROM tblCaseEvent LEFT JOIN tblEvent ON tblCaseEvent.EventID = tblEvent.EventID LEFT JOIN tblEventType ON tblCaseEvent.CaseEventTypeId = tblEventType.EventTypeId 
    LEFT JOIN tbllookup ON (tblCaseEvent.CourtResult=tblLookup.Code and tbllookup.lookupgroup='CourtResult')
    WHERE CaseID = ?
    ORDER BY CaseStartDateTime DESC";
# and (tbllookup.lookupgroup='CourtResult' or tbllookup.lookupgroup is null)

  $res=sqlarrayp($dbh,$q,array($id));


  return $res;
}

#
# get_events_facts - Retrieves events from FACTS system
#
function get_events_facts($dbh,$id) {
   $q="SELECT
          fcl_calndr_actvty.cal_dt,
          fcl_cal_schd_matr.app_tm,
          fcb_matter_type.matter_typ_desc,
          fca_crt_room.crtrm_desc,
          fcl_cal_schd_itm.schd_matter_id
       FROM
          fcl_cal_schd_itm
          JOIN fcl_cal_schd_matr ON
             fcl_cal_schd_itm.schd_matter_id = fcl_cal_schd_matr.schd_matr_id
          JOIN fcl_calndr_act_dtl ON
             fcl_cal_schd_matr.actvty_dtl_id = fcl_calndr_act_dtl.actvty_dtl_id
          JOIN fcl_calndr_actvty ON
             fcl_calndr_act_dtl.actvty_id = fcl_calndr_actvty.actvty_id
          JOIN fcb_matter_type ON
             fcl_cal_schd_matr.matter_typ = fcb_matter_type.matter_typ
          JOIN fca_crt_room ON
             fcl_calndr_actvty.matter_loc = fca_crt_room.crtrm_num
          WHERE
             fcl_cal_schd_itm.cs_id=?
          ORDER BY 
             fcl_calndr_actvty.cal_dt desc";
   $res=sqlarrayp($dbh,$q,array($id));
   $q2="select caa62640021,caa60640002 from caa62640,caa60640 where caa62640009='C' and caa62640021 is not null and caa626400018=? and caa62640017=caa60640001";
   $arr2=sqlarrayp($dbh,$q2,array($id));
   # build an evtstatus lookup table by schd_matter_id
   for ($i=0;$i<count($arr2);$i++) {
      $evtstatus[$arr2[$i][0]]=$arr2[$i][1];
   }
   for ($i=0;$i<count($res);$i++) { 
      $res[$i][0]=pretty_date($res[$i][0]);  # prettyfy date
      $res[$i][4]=$evtstatus[$res[$i][4]]; # substitute matter id for event status
   }
   return $res;
}


#
# get_events_new_vision - Retrieves events from New Vision database
#

function get_events_new_vision($dbh,$ucn,$id) {
   global $CASEGLOBAL,$DEBUG;
   $suffix=substr($CASEGLOBAL[$ucn][table_source],-2);
   $ts="calendar_$suffix";
   $q="SELECT Convert(varchar(10), pk_cal_date,101) , Convert(varchar(20),pk_cal_tme,114), motion, crt_location FROM $ts where case_id=? ORDER BY pk_cal_date DESC";
  $res=sqlarrayp($dbh,$q,array($id));
  return $res;
}



#
# get_events pulls events from the clerk database
#                  and eventually icms and opencourt...
# TODO: look at those other databases...OpenCourt...
# icms & icms classic events...

function get_events($dbh,$icmsdb,$opencourtdb,$id,$ucn,$dbtype) {
   switch ($dbtype) {
      case 'clericus': 
         $events=get_events_clericus($dbh,$id);
         break;
      case 'crtv': 
      case 'courtview':
         $events=get_events_courtview($dbh,$id);
         break;
      case 'facts': 
         $events=get_events_facts($dbh,$id);
         break;
      case 'pioneer': 
         $events=get_events_pioneer($dbh,$id);
         break;
      case 'new vision': 
         $events=get_events_new_vision($dbh,$ucn,$id);
         break;
      default:
        echo "get_events: Unsupported dbtype $dbtype for $id\n";
        exit(1);
    }
   if (db_exists("circuit8")) { # ICMS classic - pull old events (I'm assuming no other events entered, so I'm not bothering with a sort)
       $circuit8db=db_connect("circuit8");
       $oldevents=sqlarrayp($circuit8db,"select to_char(edate,'MM/DD/YYYY'),to_char(estart,'HH:MI am'),dscr,eloc from events, eventtypes where casenum=? and events.etype=eventtypes.etype order by edate desc",array($ucn));
       foreach ($oldevents as $x) {
          $x[2].="<span style='font-size:8pt'><i>(ICMS)</i></span>";
          $events[]=$x;
       }      
   }
   # now pull events from ICMS calendar
   $icmsevts=sqlarrayp($icmsdb," select date_format(event_dt,'%m/%d/%Y'),date_format(event_start_tm,'%h:%i %p'),dscr,loc_dscr from calendar_icms where ucn=? and cancelled=0",array($ucn));
   for ($i=0;$i<count($icmsevts);$i++) {
       list($dt,$tm,$desc,$loc)=$icmsevts[$i];
       $desc.=" <span style='font-size:8pt'><i>(ICMS3)</i></span>";
       $events[]=array($dt,$tm,$desc,$loc);
   }
   return $events;
}


#
# get_ticklers pulls ticklers from clerk database--only support for 
#   CourtView currently

function get_ticklers($dbh,$id,$dbtype) {
   if ($dbtype=="courtview" || $dbtype=="crtv") {
      $ticklers=sqlarrayp($dbh,"select a.tkl_cd, b.dscr, convert(varchar(10),a.due_dt,101),convert(varchar(10),a.completion_dt,101) from tkl a, tklcd b where case_id=? and a.tkl_cd=b.tkl_cd order by a.due_dt desc",array($id));
   } else {
      $ticklers=array();
   }
   return $ticklers;
}

#
# get_parties_clericus gets party info & addresses for the case id $id
#

function get_parties_clericus($dbh,$caseid) {
   $q="SELECT party.party_ID,party_type_desc,convert(varchar,dismissal_date,101),last_name,first_name,middle_name,suffix_title,business_name,convert(varchar,DOB,101),address1,address2,address3,city,state_title,zip,party_attorney_id,e_mail FROM party LEFT JOIN names ON party.name_ID=names.name_ID LEFT JOIN sys_party_type ON party.party_type_ID=sys_party_type.party_type_id LEFT JOIN cd_names_suffix ON names.suffix_id=cd_names_suffix.suffix_ID LEFT JOIN demographics ON names.demographic_ID=demographics.demographic_ID LEFT JOIN address ON party.mail_address_id=address.address_id LEFT JOIN sys_states ON address.state_ID=sys_states.state_ID WHERE party.case_ID=? order by party.party_ID";

   $res=sqlarrayp($dbh,$q,array($caseid));
   for ($i=0;$i<count($res);$i++) {
      list($ptyid,$ptytype,$disdate,$last,$first,$middle,$suffix,$company,$dob,$add1,$add2,$add3,$city,$state,$zip,$attyid,$email)=$res[$i];
      $parties[$i][0]=$ptyid;
      $parties[$i][1]=$ptytype;
      $parties[$i][2]=$disdate;
      if ($company!="") { 
         $parties[$i][3]=$company; # was &#x26 instead of &amp;
         $parties[$i][9]=1; # is_company
         $parties[$i][3]=str_replace("&","&amp;",$parties[$i][3]); 
      } else {
         $parties[$i][3]="$first $middle $last";
         $parties[$i][9]=0; # is_company
         if ($suffix!="") { $parties[$i][3].=", $suffix"; }
         $parties[$i][3]=str_replace("&","&amp;",$parties[$i][3]); 
      }
      $parties[$i][4]=$dob;
      $address="";
      if ($add1!="") { $address.="$add1\n"; }
      if ($add2!="") { $address.="$add2\n"; }
      if ($add3!="") { $address.="$add3\n"; }
      if ($city!="") { $address.="$city, $state $zip"; }
      $parties[$i][5]=$address;
      $parties[$i][6]=$attyid;
      $parties[$i][7]=NULL; #  $email; # 2/2/15 disbled; use portal e-mails
   }
   return $parties;
}



function trim_value(&$value)
{
    $value = trim($value);
}

function trim_array($x) {
   for ($i=0;$i<count($x);$i++) {
       array_walk($x[$i], 'trim_value');
   }
   return $x;
}


function make_lookup($x) {
   for ($i=0;$i<count($x);$i++) {
       $out[$x[$i][0]]=array_slice($x[$i],1);
   }
   return $out;
}



#
# get_parties_facts($dbh,$caseid)
#


function get_parties_facts($dbh,$caseid) {
   $suffarr=sqlarrayp($dbh,"select suffix, suffix_desc from fcb_suffix",array());
   $suffarr=make_lookup($suffarr); # makes a lookup table...
   $q="SELECT a.part_id,prty_typ_desc,prty_nm_22,prty_nm_23,prty_nm_21,birth_dt,suffix,prty_nm_2,addrss_seq FROM fcs_prty_nm_mstr a LEFT JOIN fcb_prty_typ b ON a.prty_typ=b.prty_typ_cd WHERE cs_id=? ORDER BY prty_num";
   $res=sqlarrayp($dbh,$q,array($caseid));
   $res=trim_array($res);
   for ($i=0;$i<count($res);$i++) {
      list($ptyid,$ptytype,$first,$middle,$last,$dob,$suffix,$company)=$res[$i];
      $dob=pretty_date($dob);
      # company only set for...well...companies.
      if ($first!="") { $company=""; }
      # some suffix vals appear direct, some are keys in fcb_suffix
      if (trim($suffarr[$suffix])!="") { $suffix=$suffarr[$suffix]; }
      $parties[$i][0]=$ptyid;
      $parties[$i][1]=$ptytype;
      $parties[$i][2]=$disdate;
      if ($company!="") {
         $parties[$i][3]=$company;
         $parties[$i][9]=1; # is_company
         $parties[$i][3]=str_replace("&","&#x26",$parties[$i][3]);
      } else {
         $parties[$i][3]="$first $middle $last";
         $parties[$i][9]=0; # is_company
         if ($suffix!="") { $parties[$i][3].=", $suffix"; }
         $parties[$i][3]=str_replace("&","&#x26",$parties[$i][3]);
      }
      $parties[$i][4]=$dob;
   }
   # now get addresses
   for ($j=0;$j<count($res);$j++) {
      if ($res[$j][8]!="") {
         $addrs=sqlarrayp($dbh,"SELECT part_id,addrss_ln_1,addrss_ln_2,addrss_ln_3,city_desc,state,zip_cd FROM fcs_part_addrss WHERE part_id=? and seq=?",array($res[$j][0],$res[$j][8]));
         $addrs=trim_array($addrs);
         for ($i=0;$i<count($addrs);$i++) { # usually only 1 will match...
            list($pid,$add1,$add2,$add3,$city,$state,$zip)=$addrs[$i];
            $address="";
            if ($add1!="") { $address.="$add1\n"; }
            if ($add2!="") { $address.="$add2\n"; }
            if ($add3!="") { $address.="$add3\n"; }
            if ($city!="") { $address.="$city, $state $zip"; }
            $parties[$j][5]=$address;
         }
      }
   }
   return $parties;
}

#
# get_parties_courtview gets party info & addresses for the case id $id
#

# uses an acc alias, so would need modification for other courtview sites
# setting atty id to 0 because there can be more than one, and if I join the
# attys in, I get duplicates on parties...

function get_parties_courtview($dbh,$caseid,&$case) {
   $q="select a.seq,f.dscr,convert(varchar,a.dismiss_dt,101),first_name,middle_name,last_name,sffx_cd,company_name,convert(varchar,dob,101),addr_line1,addr_line2,addr_line3,city,st_cd,zip_cd,email_addr from pty a JOIN idnt b ON  a.idnt_id=b.idnt_id JOIN ptycd f on a.pty_cd=f.pty_cd LEFT JOIN acc_v_current_pty_address g ON (a.case_id=g.case_id AND a.seq=g.seq) LEFT JOIN ptyemail i ON (a.case_id=i.case_id AND a.seq=i.seq) LEFT JOIN email j ON (i.email_id=j.email_id) WHERE a.case_id=? ORDER BY a.seq";
   $res=sqlarrayp($dbh,$q,array($caseid));
   for ($i=0;$i<count($res);$i++) {
      list($ptyid,$ptytype,$disdate,$first,$middle,$last,$suffix,$company,$dob,$add1,$add2,$add3,$city,$state,$zip,$email)=$res[$i];
      $parties[$i][0]=$ptyid;
      $pxref[$ptyid]=$i; # xref for below..
      $parties[$i][1]=$ptytype;
      $parties[$i][2]=$disdate;
      if ($company!="") { 
         $parties[$i][3]=$company; 
         $parties[$i][9]=1; # is_company
         $parties[$i][3]=str_replace("&","&#x26",$parties[$i][3]); 
      } else {
         $parties[$i][3]="$first $middle $last";
         $parties[$i][9]=0; # is_company
         if ($suffix!="") { $parties[$i][3].=", $suffix"; }
         $parties[$i][3]=str_replace("&","&#x26",$parties[$i][3]); 
         if (preg_match("/expunged/i",$parties[$i][3])) { 
            $case[expunged]=1;
         }
      }
      $parties[$i][4]=$dob;
      $address="";
      if ($add1!="") { $address.="$add1\n"; }
      if ($add2!="") { $address.="$add2\n"; }
      if ($add3!="") { $address.="$add3\n"; }
      if ($city!="") { $address.="$city, $state $zip"; }
      $parties[$i][5]=$address;
      $parties[$i][6]=""; #  populate below
      $parties[$i][7]=NULL; # $email; # disabled 2/2/15; use portal emails
   }
   if (!$case[expunged]) { $case[expunged]=0; } # set to 1 or 0
   # now populate the multi-value party id...sortying by atty_cd desc so
   # Primary attorney (P) comes ahead of co-counsel (CC).
   $q="select seq,atty_id from ptyatty where case_id=? order by seq,atty_cd desc";
   $res2=sqlarrayp($dbh,$q,array($caseid));
   for ($i=0;$i<count($res2);$i++) {
      list($ptyid,$attyid)=$res2[$i];
      $attyid=trim($attyid);
      $ind=$pxref[$ptyid];
      if ($parties[$ind][6]!="") { # already one entry
         $parties[$ind][6].=",$attyid";
      } else {
         $parties[$ind][6]="$attyid";
      }
   }
   return $parties;
}

#
# get_parties_pioneer gets party info & addresses for the specified case id
# 

function get_parties_pioneer($dbh, $caseid){
  $q="SELECT tblCaseParty.CasePartyId, tblCasePartyType.Description, tblPartyName.FirstName, tblPartyName.MiddleName, tblPartyName.LastOrBusinessName, Convert(varchar(10), tblParty.DOB,101) as DOB, tblParty.EmailAddress, tblPartyAddress.Address1, tblPartyAddress.Address2, tblPartyAddress.City, tblPartyAddress.State, tblPartyAddress.Zip, tblCaseParty.DeactivateDate
    FROM tblCaseParty JOIN tblCase ON tblCaseParty.CaseID = tblCase.CaseID LEFT JOIN tblCasePartyType ON tblCaseParty.CasePartyType = tblCasePartyType.CasePartyType AND tblCasePartyType.CaseTypeID = tblCase.CaseTypeID  AND tblCasePartyType.CourtTypeID = tblCase.CourtTypeID LEFT JOIN tblParty ON tblCaseParty.PartyId = tblParty.PartyId LEFT JOIN tblPartyName ON tblParty.PartyId = tblPartyName.PartyId LEFT JOIN tblPartyAddress ON tblParty.PartyId = tblPartyAddress.PartyId
    WHERE tblCaseParty.CasePartyType NOT IN('JDG', 'ATT') AND tblCaseParty.CaseID = ? AND tblCaseParty.PartyId > 0 AND tblPartyName.PartyNameType=0 ORDER BY tblCaseParty.PartySequence, tblPartyAddress.Active,tblPartyAddress.ModifyDate desc";
  $res=sqlarrayp($dbh,$q,array($caseid));

  $parties=array();

  $j=0;
  for ($i=0;$i<count($res);$i++) {
    list($ptyid, $ptytype, $fname, $mname, $lname, $dob, $email, $address1, $address2, $city, $state, $zip, $dismissaldate)=$res[$i];
    if (!$ptyhit[$ptyid]) { # pick first of duplicate addresses
       $parties[$j][0]=$ptyid;
       $parties[$j][1]=$ptytype;
       $parties[$j][2]=$dismissaldate;
       if ($fname=="" && $mname=="") {
          $parties[$j][9]=1; # is_company
          $parties[$j][3]=trim($lname);
       } else {
          $parties[$j][3]=trim($fname.' '.$mname. ' '.$lname);
          $parties[$j][9]=0; # is_company
       }
       $parties[$j][4]=$dob;
       $parties[$j][5]=concat_address($address1, $address2, "", $city, $state, $zip);
       $parties[$j][6]=""; # TODO: This is provided on the attorney, not on the defendant
       $parties[$j][7]=NULL; #  trim($email); # disabled 2/2/15, use portal emails
       $ptyhit[$ptyid]++;
       $j++;
     }
  }
   return $parties;
}




#
# get_parties_new_vision gets party info & addresses for the specified case id
# 

function get_parties_new_vision($dbh, $ucn,$caseid) {
# ap_party_cr ; appellant
   global $CASEGLOBAL,$DEBUG;
   $suffix=substr($CASEGLOBAL[$ucn][table_source],-2);
   $ts="party_$suffix";
   if ($DEBUG) { echo "***get_parties_new_vision: $ts<br>\n"; }
   $q="select pk_id as party_id,party_code,party_name,party_fname,convert(varchar(10),dob,101) as DOB,email_add,add_1,add_2,city,state,zip,atty_code from $ts where case_id=? order by party_seq";
  $res=sqlarrayp($dbh,$q,array($caseid));
  $parties=array();

  $j=0;
  for ($i=0;$i<count($res);$i++) {
    list($ptyid, $ptytype, $name,$fname, $dob, $email, $address1, $address2, $city, $state, $zip, $attycode)=$res[$i];
#    list($ptyid, $ptytype, $fname, $mname, $lname, $dob, $email, $address1, $address2, $city, $state, $zip, $dismissaldate)=$res[$i];
    if (!$ptyhit[$ptyid]) { # pick first of duplicate addresses
       $parties[$j][0]=$ptyid;
       $ptytype=trim($ptytype);
       if ($ptytype=="P") { $parties[$j][1]="Plaintiff"; }
       else if ($ptytype=="D") { $parties[$j][1]="Defendant"; }
       else { $parties[$j][1]="*$ptytype*"; }
       $parties[$j][2]=""; # was $dismissaldate;
       $parties[$j][3]=trim($name);
       if ($fname=="") {
          $parties[$j][9]=1; # is_company
       } else {
          $parties[$j][9]=0; # is_company
       }
       $parties[$j][4]=$dob;
       $parties[$j][5]=concat_address($address1, $address2, "", $city, $state, $zip);
       $parties[$j][6]=""; # TODO: This is provided on the attorney, not on the defendant
       $parties[$j][7]=NULL; # trim($email); # disabled 2/2/15; use portal e-mails
       $ptyhit[$ptyid]++;
       $j++;
     }
  }
   return $parties;
}





#
# get_parties returns a party list with addresses & e-mails
#
# it will eventually look at the sched db for any registered e-mails there.
#
# Array Key:
# 0 - party id (unique)
# 1 - party type
# 2 - dismissal date 
# 3 - full name
# 4 - DOB
# 5 - snail-mail address in text
# 6 - attorney id
# 7 - e-mail address from clerk DB
# 8 - e-portal addresses (comma-separated) [RESERVED]
# 9 - is_company (1 if company name, 0 otherwise)
#
# FOR CourtView cases, it also sets $case[expunged] if a party has 
#     the name EXPUNGED...

function get_parties($dbh,$schedb,$ucn,$caseid,$dbtype,&$case) {
   switch ($dbtype) {
      case 'clericus':
         $parties=get_parties_clericus($dbh,$caseid);
         break;
      case 'crtv':
      case 'courtview':
         $parties=get_parties_courtview($dbh,$caseid,$case);
         break;
      case 'facts':
         $parties=get_parties_facts($dbh,$caseid);
         break;
      case 'pioneer':
         $parties=get_parties_pioneer($dbh,$caseid);
         break;
      case 'new vision':
         $parties=get_parties_new_vision($dbh,$ucn,$caseid);
         break;
      case 'default':
         echo "get_parties: Unsupported dbtype $dbtype for $caseid\n";
         exit(1);
   }
   return $parties;
}


#
# populate_bar_emails looks at the bar_members table in the
#                olscheduling database to pull the "official"
#                bar emails for each attorney, populating field 6 of address
# NO LONGER USED; use portal e-mails instead

function populate_bar_emails($schedb,$attorneys) {
   for ($i=0;$i<count($attorneys);$i++) {
      if ($attorneys[$i][4]!="") {
        $q="select email from bar_members where bar_num=?";
        $attorneys[$i][7]=sqlgetonep($schedb,$q,array($attorneys[$i][4]));
      }
   }
   return $attorneys;
}


#
# get_attorneys_clericus fills out the $attorneys array for CLERICUS
#                        casses...
#

function get_attorneys_clericus($dbh,$caseid) {
  # attorney appointment dates from old get_atty_dates
  $appredates=sqlarrayp($dbh,"select attorney_id, convert(varchar,Notice_of_appearance_date,101),convert(varchar,withdrawal_date,101) from xref_party_attorney a,party b where a.party_id=b.party_id and case_id=?",array($caseid));
   foreach ($appredates as $x) {
      $attydates[$x[0]][0]=$x[0];
      $attydates[$x[0]][1]=$x[1];
      $attydates[$x[0]][2]=$x[2];
   }
  # Now do the main attorney query...
   $q="SELECT party.party_attorney_ID,party.party_ID,names.last_name,names.first_name,names.middle_name,cd_names_suffix.suffix_title,bar_number,address1,address2,address3,city,state_title,zip,e_mail FROM party JOIN attorney ON party.party_attorney_id=attorney.attorney_id LEFT JOIN names ON attorney.name_id=names.name_ID LEFT JOIN address ON attorney.address_id=address.address_id  LEFT JOIN sys_states on sys_states.state_id=address.state_id LEFT JOIN cd_names_suffix ON names.suffix_ID=cd_names_suffix.suffix_ID WHERE case_id=?";
   $res=sqlarrayp($dbh,$q,array($caseid));
   for ($i=0;$i<count($res);$i++) {
      list($attyid,$ptyid,$last,$first,$middle,$suffix,$barnum,$add1,$add2,$add3,$city,$state,$zip,$email)=$res[$i];
      $email=trim($email);
      $attorneys[$i][0]=$attyid;
      $attorneys[$i][1]=$ptyid;
      $attorneys[$i][2]="$first $middle $last";
      if ($suffix!="") { $attorneys[$i][2].=", $suffix"; }
      $attorneys[$i][3]=$attydates[$attyid][1];
      $attorneys[$i][4]=$barnum;
      $address="";
      if (trim($add1)!="") { $address.="$add1\n"; }
      if (trim($add2)!="") { $address.="$add2\n"; }
      if ($add3!="") { $address.="$add3\n"; }
      if ($city!="") { $address.="$city, $state $zip"; }
      $attorneys[$i][5]=$address;
      $attorneys[$i][6]=NULL; # $email; # disabled 2/2/15; use portal e-mails
      $attorneys[$i][9]=0; # is_company
   }
   return $attorneys;
}


#
# get_attorneys_courtview fills out the $attorneys array for CourtView
#                        cases...
#

function get_attorneys_courtview($dbh,$caseid) {
   $q="select distinct a.atty_id,a.seq,c.last_name,c.first_name,c.middle_name,c.sffx_cd,CONVERT(varchar,a.appoint_dt,101),b.bar_cd,addr_line1,addr_line2,addr_line3,city,st_cd,zip_cd from ptyatty a JOIN atty b ON a.atty_id=b.atty_id JOIN idnt c ON b.idnt_id=c.idnt_id LEFT JOIN acc_v_current_atty_address d ON (a.atty_id=d.atty_id)  WHERE a.case_id=? AND a.dismiss_dt is null";
   $res=sqlarrayp($dbh,$q,array($caseid));

   # get email addresses, since I had issues getting another couple of joins in
# DISABLED 2/2/15 since clerk emails are not authoritative
#   $q2="select a.atty_id,c.email_addr from ptyatty a,atyemail b,email c where a.atty_id=b.atty_id and b.email_id=c.email_id and a.case_id=?";
#   $res2=sqlarrayp($dbh,$q2,array($caseid));
#   foreach ($res2 as $emailrec) {
#     $attyemail[$emailrec[0]]=$emailrec[1];
#   }

   for ($i=0;$i<count($res);$i++) {
      list($attyid,$ptyid,$last,$first,$middle,$suffix,$startdate,$barnum,$add1,$add2,$add3,$city,$state,$zip,$startdate)=$res[$i];
      $email=NULL; #  trim($attyemail[$attyid]); 
      $attorneys[$i][0]=$attyid;
      $attorneys[$i][1]=$ptyid;
      $attorneys[$i][2]="$first $middle $last";
      if ($suffix!="") { $attorneys[$i][2].=", $suffix"; }
      $attorneys[$i][3]=$startdate;
      $attorneys[$i][4]=$barnum;
      $attorneys[$i][5]=concat_address($add1, $add2, $add3, $city, $state, $zip);
      $attorneys[$i][6]=$email;
      $attorneys[$i][9]=0; # is_company
   }
   return $attorneys;
}

#
# get_attorneys_pioneer retrives attorneys from pioneer system
#

function get_attorneys_pioneer($dbh,$caseid) {
  $q="SELECT tblCaseParty.PartyId, tblCaseParty.ParentCasePartyId, tblPartyName.FirstName, tblPartyName.MiddleName, tblPartyName.LastOrBusinessName, tblParty.EmailAddress, tblParty.BarNumber, tblCaseParty.AppointDate, tblPartyAddress.Address1, tblPartyAddress.Address2, tblPartyAddress.City, tblPartyAddress.State, tblPartyAddress.Zip
    FROM tblCaseParty LEFT JOIN tblParty ON tblCaseParty.PartyId = tblParty.PartyId LEFT JOIN tblPartyName ON tblParty.PartyId = tblPartyName.PartyId LEFT JOIN tblPartyAddress ON tblParty.PartyId = tblPartyAddress.PartyId
    WHERE tblCaseParty.CasePartyType = 'ATT' AND tblCaseParty.CaseID = ? AND tblCaseParty.DeactivateDate IS NULL AND tblCaseParty.PartyId > 0 AND tblPartyAddress.Active = 1;";
  $res=sqlarrayp($dbh,$q,array($caseid));

  $attorneys=array();
  for ($i=0;$i<count($res);$i++) {
    list($attorneyid, $ptyid, $fname, $mname, $lname, $email, $barnumber, $startdate, $address1, $address2, $city, $state, $zip)=$res[$i];
    $attorneys[$i][0]=$attorneyid;
    $attorneys[$i][1]=$ptyid;
    if ($fname=="" && $mname=="") { # company
       $attorneys[$i][2]=trim($lname);
       $attorneys[$i][9]=1; # is_company
    } else {
       $attorneys[$i][2]=trim($fname.' '.$mname. ' '.$lname);
       $attorneys[$i][9]=0; # is_company
    }
    $attorneys[$i][3]=$startdate;
    $attorneys[$i][4]=$barnumber;
    $attorneys[$i][5]=concat_address($address1, $address2, "", $city, $state, $zip);
    $attorneys[$i][6]=NULL; # trim($email); disabled 2/2/15; use portal e-mails
  }

  return $attorneys;
}


function get_attorneys_facts($dbh, $caseid) {
   $q = <<<EOT
  SELECT
    fcs_prty_atty.prty_typ,
    fcs_prty_atty.prty_num,
    fcs_prty_atty.prty_atty,
    fcb_atty.atty_nm,
    fcb_atty.email_addr,
    TO_CHAR(fcs_prty_atty.ss_dt, '%m/%d/%Y'),
    fcb_atty.adr_1,
    fcb_atty.adr_2,
    fcb_atty.city,
    fcb_atty.state,
    fcb_atty.zip
  FROM
     fcs_prty_atty JOIN fcb_atty ON fcs_prty_atty.prty_atty = fcb_atty.atty_cd_2
  WHERE
    fcs_prty_atty.cs_id = ? AND fcs_prty_atty.atty_inactive_flg <> 'Y'
EOT;

# Name, firm name, address all seem a bit lacking from FACTS itself, may be better to pull from eServices/bar_members.  Have hand checked a few 
# prty_atty's against bar_members and they do match up.

   $res=sqlarrayp($dbh, $q, array($caseid));
   # now get party id, typ, and num to cross-ref with the typ and num above...
   $q2="SELECT part_id,prty_typ,prty_num from fcs_prty_nm_mstr where cs_id=?";
   $arr2=sqlarrayp($dbh,$q2,array($caseid));
   for ($i=0;$i<count($arr2);$i++) {
      list($partid,$typ,$num)=$arr2[$i];
      $xref["$typ:$num"]=$partid;
   }
   $attorneys=array();
   for ($i=0;$i<count($res);$i++) {
      list($typ,$num, $attorneyid, $atty_name, $email, $startdate, $address1, $address2, $city, $state, $zip)=$res[$i];
      $ptyid=$xref["$typ:$num"];
      $attorneys[$i][0]=$attorneyid;
      $attorneys[$i][1]=$ptyid;

      $attorneys[$i][2]=trim($atty_name);
      $attorneys[$i][9]=0; # is_company

      $attorneys[$i][3]=$startdate;
      $attorneys[$i][4]=$attorneyid;
      $attorneys[$i][5]=concat_address($address1, $address2, "", $city, $state, $zip);
      $attorneys[$i][6]=NULL; # trim($email); # disabled 2/2/15; use portal e-mails
   }
   return $attorneys;
}


#
# get_attorneys_new_vision retrieves attorneys from the new vision DB
#

function get_attorneys_new_vision($dbh,$ucn,$caseid) {
   global $CASEGLOBAL,$DEBUG;
   $suffix=substr($CASEGLOBAL[$ucn][table_source],-2);
   $ts="atty_$suffix";
   if ($DEBUG) { echo "***get_attorneys_new_vision: $ts<br>\n"; }
   $q="SELECT atty_code,party_id,code_atty.value_1,email_add,value_2,value_3,value_4,value_5,value_6 FROM $ts LEFT JOIN code_atty ON code_atty.pk_key_value_1=$ts.atty_code WHERE case_id=? and atty_code is not null";
# ($pid,$barnum,$name,$add1,$add2,$city,$state,$zip,$email)

  $res=sqlarrayp($dbh,$q,array($caseid));
  $attorneys=array();
  for ($i=0;$i<count($res);$i++) {
    list($barnum, $ptyid, $name, $email, $address1, $address2, $city, $state, $zip)=$res[$i];
    $attorneys[$i][0]=$barnum;
    $attorneys[$i][1]=$ptyid;
    $attorneys[$i][2]=trim($lname);
    $attorneys[$i][9]=0; # is_company
#    $attorneys[$i][3]=$startdate;
    $attorneys[$i][4]=$barnum;
    $attorneys[$i][5]=concat_address($address1, $address2, "", $city, $state, $zip);
    $attorneys[$i][6]=NULL; # trim($email); # disabled 2/2/15; use portal e-mails
  }

  return $attorneys;
}





#
# populate_portal_emails fills field 8 of the $attorneys table with
#    a comma-separated list of emails from the portal (if present)
#

function populate_portal_emails($ucn,$attorneys) {
   $addrs=get_portal_emails($ucn);
   if (!is_array($addrs)) {
      echo "Error pulling e-mail addresses from portal; please try again later.<br>$addrs"; 
      exit;
   }
   for ($i=0;$i<count($addrs);$i++) {
      list($name,$barnum,$email1,$email2,$email3,$uid)=$addrs[$i];
      $barnum=str_replace("FL","",$barnum);  # new FL bar prefix being added...
      $flag=array();
      $emailstr="";
      for ($j=0;$j<count($attorneys);$j++) {
         if ($barnum==$attorneys[$j][4]) { # A MATCH
            $flag++;
            $emailstr="$email1";
            if ($email2!="") { $emailstr.=",$email2"; }
            if ($email3!="") { $emailstr.=",$email3"; }
            $attorneys[$j][8]=$emailstr;
            $attorneys[$j][9]=$uid; 
            $flag[$i]=1; # mark this portal address as used...
         } 
      }
   }
   # now see if there are any portal addresses that don't match an attorney,
   # 
  return $attorneys;
}

#
# get_attorneys is a new function that makes a list of parties,
#               handling multiple attorneys for a party.
# (also will handle multiple DB types...)
#
# 0 - attorney id (unique)
# 1 - party id
# 2 - attorney name
# 3 - start date (date of appointment)
# 4 - bar #
# 5 - snail-mail address in text
# 6 - e-mail address from clerk DB 
# 7 - bar e-mail address 
# 8 - e-portal addresses (comma-separated)
# 9 - e-portal uid (if defined)

function get_attorneys($dbh,$schedb,$caseid,$dbtype,$ucn) {
   global $SETTINGS;
   switch ($dbtype) {
      case 'clericus':
         $attorneys=get_attorneys_clericus($dbh,$caseid);
         break;
      case 'crtv':
      case 'courtview':
         $attorneys=get_attorneys_courtview($dbh,$caseid);
         break;
      case 'facts':
         $attorneys = get_attorneys_facts($dbh, $caseid);
         break;
      case 'pioneer':
         $attorneys=get_attorneys_pioneer($dbh,$caseid);
         break;
      case 'new vision':
         $attorneys=get_attorneys_new_vision($dbh,$ucn,$caseid);
         break;
      default:
        echo "get_attorneys: Unsupported dbtype $dbtype for $caseid/$ucn\n";
        exit(1);
   }

   # add bar emails to the list above...
   # DISABLED 2/2/15 as portal e-mails are the authoritative ones...
   #   $attorneys=populate_bar_emails($schedb,$attorneys); 

   if ($SETTINGS[CHECKPORTAL]) {
      $attorneys=populate_portal_emails($ucn,$attorneys);
   }
   return $attorneys;
}


#
# get_charges_clericus get the charges for this case from a CLERICUS db...
#
function get_charges_clericus($dbh,$id) {
   $charges=array();
   $q="SELECT SequenceNumber,PhaseTypeID, OffenseDate, ProsecutorFileDate, ProsecutorAction,CourtDecisionDate,CourtAction,StatuteDescription,LevelID,DegreeID,StatuteChapter,StatuteSection,StatuteSubSection FROM vw_charge_details WHERE CaseID = ? order by SequenceNumber,PhaseTypeID";
   # there can be duplicate entries for each charge here; we use the information
   # at the last phase, whatever it is, for display purposes, so sorting by sequence
   # and phasetypeid handles that nicely.
   $chargesraw=sqlarrayp($dbh,$q,array($id));   
   $levels=array("","F","M","I","CO","MO");
   $degrees=array("","C","L","1L","1","2","3","");
   for ($i=0;$i<count($chargesraw);$i++) {
      list($seq,$phase,$offdate,$prodat,$proact,$courtdecdate,$courtaction,$statdesc,$level,$degree,$statchap,$statsec,$statsub)=$chargesraw[$i];
      if ($statsub!="") { 
         $statute="&#167;$statchap.$statsec($statsub)";
      } else {
         $statute="&#167;$statchap.$statsec";
      }
      $charges[$seq-1]="$seq~$offdate~$degrees[$degree]$levels[$level]~$statute: $statdesc~$prodat $proact~$courtdecdate $courtaction";
   }
  return $charges;
}


#
# get_charges_courtview get the charges for this case from a CLERICUS db...
#
function get_charges_courtview($dbh,$id) {
   $charges=array();
   $q="SELECT a.chrg_nbr,CONVERT(varchar,a.offense_dt,101),a.actn_cd,a.dgof_cd,c.dscr,e.dscr,CONVERT(varchar,a.dcsn_dt,101),d.actn_cd,d.dgof_cd,d.chrg_dscr,f.dscr,CONVERT(varchar,d.filing_dt,101),d.count_nbr from ptychrg a JOIN cases b ON a.case_id=b.case_id JOIN actncd c ON a.actn_cd=c.actn_cd LEFT JOIN pcobtspp d on (a.case_id=d.case_id and a.chrg_nbr=d.chrg_nbr) LEFT JOIN dcsncd e ON a.dcsn_cd=e.dcsn_cd LEFT JOIN obtsfacd f ON d.pfa_cd=f.pfa_cd WHERE a.case_id=? ORDER BY d.count_nbr,a.chrg_nbr";

# need to link in pfa codes and judge decision codes...

   $chargesraw=sqlarrayp($dbh,$q,array($id));
   foreach ($chargesraw as $chargeraw) {
#      echo "**",implode("~",$chargeraw),"<br>";

      list($seq,$offdate,$offstat,$offdeg,$offdesc,$jdgdcsn,$jdgdate,$prostat,$prodeg,$prodesc,$proact,$prodate,$cnt)=$chargeraw;
      $statute=$offstat;
      $degree=$offdeg;
      $desc=$offdesc;
      if ($prostat!="") { $statute=$prostat; }
      if ($prodeg!="") { $degree=$prodeg; }
      if ($prodesc!="") { $desc=$prodesc; }
      $statute="&#167;$statute";
      if ($cnt!="") {$seq=$cnt; } # count trumps charge...
      $charges[$seq-1]="$seq~$offdate~$degree~$statute: $desc~$proact $prodate~$jdgdcsn $jdgdate";
   }

  return $charges;
}


#
# get_charges_pioneer retrieve charges from pioneer system
#

$pioneer_courtactions = array(
    "1" => "Guilty", # Found this in old Pioneer implementation
    "A" => "Acquitted",
    "I" => "Acquitted by Reason of Insanity",
    "D" => "Dismissed Upon Payment of Restitution/Court Cost",
    "T" => "Dismissed Speedy Trial",
    "M" => "Mentally/Physically Unable to Stand Trial",
    "G" => "Adjudicated Guilty/Delinquent in Juvenile Court",
    "H" => "Pre-Trial Diversion", 
    "W" => "Adjudication Withheld",
    "V" => "Change of Venue",
    "Z" => "Extradition",
    "K" => "Adjudged Delinquent",
    "B" => "Bond Estreature", 
    "X" => "Stipulated Deportation",
    "Q" => "Waived to adult court",
    "Y" => "Decline to Adjudicate",
  );

function get_charges_pioneer($dbh, $caseid){
  

  $q="select tblCaseCharge.InitialSequenceNumber, Convert(varchar(10), tblCaseCharge.OffenseDate,101) as OffenseDate, tblStatute.ChargeLevel, tblStatute.ChargeDegree, tblStatute.StatuteShortDescription, tblStatute.StatuteNumber,
    tblProsecutorFinalAction.Description, Convert(varchar(10), tblCaseCharge.ProsecutorFinalDecisionDate,101) as ProsecutorFinalDecisionDate, tblCaseCharge.CourtActionTaken, Convert(varchar(10), tblCaseCharge.CourtDecisionDate,101) as CourtDecisionDate
    from tblCaseCharge left join tblStatute on tblCaseCharge.InitialStatuteId = tblStatute.StatuteId left join tblProsecutorFinalAction on tblCaseCharge.ProsecutorFinalAction = tblProsecutorFinalAction.ProsecutorCode
    where tblCaseCharge.CaseId = ? and tblCaseCharge.InitialStatuteID > 0 order by tblCaseCharge.InitialSequenceNumber asc;";
  $res=sqlarrayp($dbh,$q,array($caseid));
  $charges=array();

  for ($i=0;$i<count($res);$i++) {
    list($seq, $odate, $level, $degree, $desc, $statute, $proact, $prodate, $jdgdcsn, $jdgdate)=$res[$i];
    $statute="&#167;$statute";
    $jdgdcsn=$pioneer_courtactions[$jdgdcsn];

    $charges[$i]="$seq~$odate~$degree$level~$statute: $desc~$proact $prodate~$jdgdcsn $jdgdate";
  }

  return $charges;
}

function get_charges_facts($dbh, $caseid) {

  $charges = array();

$q=<<<EOT
  SELECT fcs_prctr_cnt.prctr_seq,
  fcs_prctr_cnt.offns_dt,
  fcs_prctr_cnt.caa28640030 AS chrg_lvl,
  fcb_chrg_class_cd.rpt_label AS degree,
  fcb_chrg_codes.crg_desc_abbr,
  fcb_chrg_codes.full_chrg,
  fcb_prctr_actn_cd.desc AS prctr_action_desc,
  fcs_prctr_cnt.final_actn_dt,
  fcs_prctr_cnt.prty_num 
FROM 
  fcs_prctr_cnt
LEFT JOIN fcb_chrg_codes ON fcs_prctr_cnt.chrg_cd = fcb_chrg_codes.full_chrg
LEFT JOIN fcb_chrg_class_cd ON fcs_prctr_cnt.chrg_class = fcb_chrg_class_cd.chrg_class_cd
LEFT JOIN fcb_prctr_actn_cd ON fcs_prctr_cnt.prctr_final_actn = fcb_prctr_actn_cd.prctr_actn_cd  
WHERE
  fcs_prctr_cnt.cs_id = ?
ORDER BY
  fcs_prctr_cnt.prctr_seq ASC
EOT;

$q_disp=<<<EOT
SELECT
  fcs_dsptn_crml.ct,
  fcb_final_dsptn.fnl_disp_desc,
  fcs_dsptn_crml.disp_dt
FROM 
  fcs_dsptn_crml
LEFT JOIN fcb_final_dsptn ON fcs_dsptn_crml.fnl_disptn = fcb_final_dsptn.fnl_disp    
WHERE
  fcs_dsptn_crml.cs_id = ? AND fcs_dsptn_crml.prty_num = ? 
ORDER BY
  fcs_dsptn_crml.ct ASC
EOT;

  $res = sqlarrayp($dbh, $q, array($caseid));
  for ($i=0; $i < count($res); $i++) {
    list($seq, $odate, $level, $degree, $desc, $statute, $proact, $prodate, $prty_num)=$res[$i];
    if ($i == 0) {    
      $res_disp = sqlarrayp($dbh, $q_disp, array($caseid, $prty_num));
    }
    list($dispcount, $dispdesc, $dispdate) = $res_disp[$i];
    $statute="&#167;$statute";
    $charges[$i]="$seq~$odate~$degree $level~$statute: $desc~$proact $prodate~$dispdesc $dispdate";
  }
  return $charges;
}


#
# get_charges_new_vision gets the charges for a New Vision case.

# CURRENTLY JUST A STUB AS WE DON'T HAVE CRIMINAL 
# (will need it for CJ, though)

function get_charges_new_vision($dbh,$caseid) {
  return array(); # STUB
}

#
# get_charges get the charges for this case
#
function get_charges($dbh,$caseid,$dbtype) {
  switch ($dbtype) {
      case 'clericus':
         $charges=get_charges_clericus($dbh,$caseid);
         break;
      case 'crtv':
      case 'courtview':
         $charges=get_charges_courtview($dbh,$caseid);
         break;
      case 'facts':
         $charges=get_charges_facts($dbh, $caseid);
         break;
      case 'pioneer':
         $charges=get_charges_pioneer($dbh,$caseid);
         break;
      case 'new vision':
         $charges=get_charges_new_vision($dbh,$caseid);
         break;
      default:
        echo "get_charges: Unsupported dbtype $dbtype for $casid\n";
        exit(1);
   }
   return $charges;
}

#
# get_cases_charges_clericus gets the charges for multiple cases
#

function get_cases_charges_clericus($dbh,$caseids) {
   $charges=array();

   $q="SELECT 
        CaseID,
        SequenceNumber,
        PhaseTypeID, 
        OffenseDate, 
        ProsecutorFileDate, 
        ProsecutorAction,
        CourtDecisionDate,
        CourtAction,
        StatuteDescription,
        LevelID,
        DegreeID,
        StatuteChapter,
        StatuteSection,
        StatuteSubSection 
      FROM 
        vw_charge_details 
      WHERE 
        CaseID IN (" . implode(',', $caseids) . ")
      ORDER BY 
        CaseID, SequenceNumber,PhaseTypeID";

   # there can be duplicate entries for each charge here; we use the information
   # at the last phase, whatever it is, for display purposes, so sorting by sequence
   # and phasetypeid handles that nicesly.

   $chargesraw=sqlarrayp($dbh,$q,array());   
   $levels=array("","F","M","I","CO","MO");
   $degrees=array("","C","L","1L","1","2","3","s");
   for ($i=0;$i<count($chargesraw);$i++) {
      list($caseid,$seq,$phase,$offdate,$prodat,$proact,$courtdecdate,$courtaction,$statdesc,$level,$degree,$statchap,$statsec,$statsub)=$chargesraw[$i];
      if ($statsub!="") { 
         $statute="&#167;$statchap.$statsec($statsub)";
      } else {
         $statute="&#167;$statchap.$statsec";
      }
      $charges[trim($caseid)][$seq-1]="$seq~$offdate~$degrees[$degree]$levels[$level]~$statute: $statdesc~$prodat $proact~$courtdecdate $courtaction";
   }
  return $charges;
}


#
# get_cases_charges_courtview get the charges for multiples case from a Courtview db...
#
function get_cases_charges_courtview($dbh,$caseids) {
   $charges=array();

   $q="SELECT 
        a.case_id,
        a.chrg_nbr,
        CONVERT(varchar,a.offense_dt,101),
        a.actn_cd,
        a.dgof_cd,
        c.dscr,
        e.dscr,
        CONVERT(varchar,a.dcsn_dt,101),
        d.actn_cd,
        d.dgof_cd,
        d.chrg_dscr,
        f.dscr,
        CONVERT(varchar,d.filing_dt,101) 
      from 
        ptychrg a 
      JOIN cases b ON a.case_id=b.case_id 
      JOIN actncd c ON a.actn_cd=c.actn_cd 
      LEFT JOIN pcobtspp d on (a.case_id=d.case_id and a.chrg_nbr=d.chrg_nbr) 
      LEFT JOIN dcsncd e ON a.dcsn_cd=e.dcsn_cd 
      LEFT JOIN obtsfacd f ON d.pfa_cd=f.pfa_cd 
      WHERE 
        a.case_id IN (" . implode(',', $caseids) . ") " . 
      "ORDER BY a.chrg_nbr";
      
# need to link in pfa codes and judge decision codes...

   $chargesraw=sqlarrayp($dbh,$q, array()); 

   foreach ($chargesraw as $chargeraw) {

      list($caseid, $seq,$offdate,$offstat,$offdeg,$offdesc,$jdgdcsn,$jdgdate,$prostat,$prodeg,$prodesc,$proact,$prodate)=$chargeraw;
      $statute=$offstat;
      $degree=$offdeg;
      $desc=$offdesc;
      if ($prostat!="") { $statute=$prostat; }
      if ($prodeg!="") { $degree=$prodeg; }
      if ($prodesc!="") { $desc=$prodesc; }
      $statute="&#167;$statute";
      $charges[trim($caseid)][$seq-1]="$seq~$offdate~$degree~$statute: $desc~$proact $prodate~$jdgdcsn $jdgdate";
#      $charges[$caseid][$seq-1]="$statute: $desc";
   }
  return $charges;
}

#
# get_cases_charges_pioneer retrieve charges from pioneer system for multiple cases
#

function get_cases_charges_pioneer($dbh, $caseids){

  $q="select 
      tblCaseCharge.CaseId,
      tblCaseCharge.InitialSequenceNumber, 
      Convert(varchar(10), tblCaseCharge.OffenseDate,101) as OffenseDate, 
      tblStatute.ChargeLevel, 
      tblStatute.ChargeDegree, 
      tblStatute.StatuteShortDescription, 
      tblStatute.StatuteNumber,
      tblProsecutorFinalAction.Description, 
      Convert(varchar(10), tblCaseCharge.ProsecutorFinalDecisionDate,101) as ProsecutorFinalDecisionDate, 
      tblCaseCharge.CourtActionTaken, 
      Convert(varchar(10), tblCaseCharge.CourtDecisionDate,101) as CourtDecisionDate
    from 
      tblCaseCharge left join tblStatute on tblCaseCharge.InitialStatuteId = tblStatute.StatuteId left join tblProsecutorFinalAction on tblCaseCharge.ProsecutorFinalAction = tblProsecutorFinalAction.ProsecutorCode
    where 
      tblCaseCharge.CaseId IN (" . implode(',', $caseids) . ")
    and 
      tblCaseCharge.InitialStatuteID > 0 
    order by 
      tblCaseCharge.CaseId asc, tblCaseCharge.InitialSequenceNumber asc;";

  $res=sqlarrayp($dbh,$q,array());
  $charges=array();

  for ($i=0;$i<count($res);$i++) {
    list($caseid, $seq, $odate, $level, $degree, $desc, $statute, $proact, $prodate, $jdgdcsn, $jdgdate)=$res[$i];
    $statute="&#167;$statute";
    $jdgdcsn=$pioneer_courtactions[$jdgdcsn];

    $charges[trim($caseid)][$i]="$seq~$odate~$degree$level~$statute: $desc~$proact $prodate~$jdgdcsn $jdgdate";
  }

  return $charges;
}

function get_cases_charges_facts($dbh, $caseids) {

  $charges = array();
  $caseids_joined = implode(',', $caseids);
  $q=<<<EOT
    SELECT
      fcs_prctr_cnt.cs_id,
      fcs_prctr_cnt.prctr_seq,
      fcs_prctr_cnt.offns_dt,
      fcs_prctr_cnt.caa28640030 AS chrg_lvl,
      fcb_chrg_class_cd.rpt_label AS degree,
      fcb_chrg_codes.crg_desc_abbr,
      fcb_chrg_codes.full_chrg,
      fcb_prctr_actn_cd.desc AS prctr_action_desc,
      fcs_prctr_cnt.final_actn_dt,
      fcs_prctr_cnt.prty_num 
    FROM 
      fcs_prctr_cnt
    LEFT JOIN fcb_chrg_codes ON fcs_prctr_cnt.chrg_cd = fcb_chrg_codes.full_chrg
    LEFT JOIN fcb_chrg_class_cd ON fcs_prctr_cnt.chrg_class = fcb_chrg_class_cd.chrg_class_cd
    LEFT JOIN fcb_prctr_actn_cd ON fcs_prctr_cnt.prctr_final_actn = fcb_prctr_actn_cd.prctr_actn_cd  
    WHERE
      fcs_prctr_cnt.cs_id IN ($caseids_joined)
    ORDER BY
      fcs_prctr_cnt.prctr_seq ASC
EOT;

  # We're not displaying the disposition on the schedule / multi case view, so no reason to incur
  # the overhead of retrieving it.
  #$q_disp=<<<EOT
  #  SELECT
  #    fcs_dsptn_crml.ct,
  #    fcb_final_dsptn.fnl_disp_desc,
  #    fcs_dsptn_crml.disp_dt
  #  FROM 
  #    fcs_dsptn_crml
  #  LEFT JOIN fcb_final_dsptn ON fcs_dsptn_crml.fnl_disptn = fcb_final_dsptn.fnl_disp    
  #  WHERE
  #    fcs_dsptn_crml.cs_id = ? AND fcs_dsptn_crml.prty_num = ? 
  #  ORDER BY
  #    fcs_dsptn_crml.ct ASC
  #EOT;

  $res = sqlarrayp($dbh, $q, array($caseid));
  for ($i=0; $i < count($res); $i++) {
    list($caseid, $seq, $odate, $level, $degree, $desc, $statute, $proact, $prodate, $prty_num)=$res[$i];
    #if ($i == 0) {    
    #  $res_disp = sqlarrayp($dbh, $q_disp, array($caseid, $prty_num));
    #}
    #list($dispdesc, $dispdate) = $res_disp[$i];
    $statute="&#167;$statute";
    $charges[trim($caseid)][$i]="$seq~$odate~$degree $level~$statute: $desc~$proact $prodate";
  }
  return $charges;
}

#
# get_cases_charges get the charges for multiple case IDs.
#
function get_cases_charges($dbh,$caseids,$dbtype) {
  switch ($dbtype) {
      case 'clericus':
         $charges=get_cases_charges_clericus($dbh,$caseids);
         break;
      case 'crtv':
      case 'courtview':
         $charges=get_cases_charges_courtview($dbh,$caseids);
         break;
      case 'facts':
         $charges=get_cases_charges_facts($dbh, $caseids);
         break;
      case 'pioneer':
         $charges=get_cases_charges_pioneer($dbh,$caseids);
         break;
      default:
        echo "get_charges: Unsupported dbtype $dbtype for $casid\n";
        exit(1);
   }
   return $charges;
}

#
#
#



#
# show_charges displays the charges created by get_charges...
#
function show_charges($charges) {
   for ($i=0;$i<count($charges);$i++) {
      list($num,$odate,$degree,$desc,$pros,$decision)=explode("~",$charges[$i]);
      echo "<tr><td>$num</td><td>$odate</td><td>$degree</td><td>$desc</td><td>$pros</td><td>$decision</td></tr>";
   }   
}

#
# get_docket_colors gets the color definitions for this county from the
#                   icms database...
#
function get_docket_colors($icmsdb,$countynum) {
   $q="select code,color from docketcodes where countynum=?";
   $docketcolorsraw=sqlarrayp($icmsdb,$q,array($countynum));
   for ($i=0;$i<count($docketcolorsraw);$i++) {
      $docketcolorsraw[$i][0]=trim($docketcolorsraw[$i][0]);
      $docketcolors[$docketcolorsraw[$i][0]]=$docketcolorsraw[$i][1];
   }
   return $docketcolors;
}



#
# get_docket_info_CLERICUS - Retrieve docket info from CourtView system
#

function get_docket_info_clericus($dbh,$id) {
   $q="SELECT docket_ID, cd_docket_code.docket_code_title, docket.docket_description, convert(varchar,docket_filed_date,101), image_filename, docket.image_privacy_id FROM docket LEFT JOIN cd_docket_code ON docket.docket_code_ID = cd_docket_code.docket_code_ID WHERE Case_ID=? and privacy_id<>6 order by docket_filed_date desc";
   $dockets=sqlarrayp($dbh,$q,array($id));
   for ($i=0;$i<count($dockets);$i++) {
       list($did,$code,$desc,$date,$imagefile,$privacy)=$dockets[$i];
       if ($privacy!=1) { 
          $dockets[$i][5]=1; 
          if ($privacy==3 || $privacy==2) {
             $dockets[$i][2].=" [Confidential]"; 
          } else {
             $dockets[$i][2].=" [Sealed]"; 
          }
       } else { $dockets[$i][5]=0; }
   }
   return $dockets;
}


#
# get_docket_info_courtview - Retrieve docket info from CourtView system
#

function get_docket_info_courtview($dbh,$id,$sealed_codes) {
   if (count($sealed_codes)==0) {
      echo "<Error: sealed docket code information not available; please correct";
      exit;
   }
   $q="SELECT dkt.dkt_id,dkt_cd,dkt_text,convert(varchar,dt,101),images_flg,0 FROM dkt LEFT JOIN dktsort ON dkt.dkt_id=dktsort.dkt_id WHERE (dkt_st_cd IS NULL OR dkt_st_cd!='D') and dt IS NOT NULL AND case_id=? AND dkt.dkt_id IS NOT NULL ORDER BY dt desc,dktsort.curr_seq DESC, dkt.ins_dttm DESC";
   $dockets=sqlarrayp($dbh,$q,array($id));
   # now check the "odkt" table for any additions...
   $q="select a.dkt_id,a.segm,a.data from odkt a,dkt b where a.dkt_id=b.dkt_id and b.case_id=? and b.dkt_st_cd is null order by a.segm";
   $odktraw=sqlarrayp($dbh,$q,array($id));
   if (count($odktraw)>0) { # we have supps...
      # this is less efficient that it should be, but the counts will be low...
      for ($i=0;$i<count($odktraw);$i++) {
         list($did,$segm,$data)=$odktraw[$i];
         $ind=-1;
         for ($j=0;$j<count($dockets);$j++) {
            if ($dockets[$j][0]==$did) { 
               $ind=$j;
               break;
            }
         }
         if ($ind!=-1) {
            $dockets[$j][2]=substr($dockets[$j][2],0,-4).$data;
         }
      }
   }
   # now check for sealed codes
   for ($j=0;$j<count($dockets);$j++) {
      if (in_array($dockets[$j][1],$sealed_codes)) {
         $dockets[$j][5]=1;
         $dockets[$j][2].=" [Sealed]";
      }
   }
   return $dockets;
}


#
# get_docket_info_pioneer - Retrieve docket info from Pioneer system
#
function get_docket_info_pioneer($dbh,$id) {
  $q="SELECT vCaseDocket.CaseDocketID, vCaseDocket.DocketCode, vCaseDocket.DocketText, Convert(varchar(10), vCaseDocket.DocketDate,101) as [Date], vCaseDocketDocuments.DocumentPath, tblCaseDocket.issealed, tblCaseDocket.hidefromweb
    FROM view_CaseDocket AS vCaseDocket 
    LEFT JOIN tblDocketCode 
       ON vCaseDocket.DocketCodeID = tblDocketCode.DocketCodeID 
    LEFT JOIN view_CaseDocketDocuments AS vCaseDocketDocuments 
       ON (vCaseDocket.CaseDocketID = vCaseDocketDocuments.CaseDocketID AND vCaseDocketDocuments.PageSequence = 1)
    LEFT JOIN tblCaseDocket
       ON (vCaseDocket.CaseDocketID=tblCaseDocket.CaseDocketId)
    WHERE vCaseDocket.CaseID = ? ORDER BY vCaseDocket.DocketDate DESC, vCaseDocket.DocketSequenceNumber DESC";
  $dockets=sqlarrayp($dbh,$q,array($id));
   # now check for sealed codes
   for ($j=0;$j<count($dockets);$j++) {
      if ($dockets[$j][5]==1 || $dockets[$j][6]==1) {
         if ($dockets[$j][5]==1) {
            $dockets[$j][2].=" [Sealed]";
         } else {
            $dockets[$j][2].=" [Confidential]";
         }
         $dockets[$j][5]=1;
      }
   }
  return $dockets;
}



function get_docket_info_facts($dbh, $id) {
   # THE MAIN QUERY
   $q_ldgr = "SELECT
         ldgr.barcode_id, ldgr.evnt_srvc_cd, fcb_evnt_srvc.desc_evnt_cd, ldgr.evnt_dt,
         ldgr.barcode_id, ldgr.evnt_seq_num,  caa07640001, caa07640008
       FROM
          fcs_evnt_ldgr ldgr
       LEFT JOIN
          fcb_evnt_srvc
       ON
          evnt_cd_1=evnt_srvc_cd
       LEFT JOIN
          caa07640
       ON (caa076400018=ldgr.cs_id AND  caa07640003=ldgr.evnt_dt AND caa07640004=ldgr.evnt_seq_num)
       WHERE
          ldgr.cs_id=?
       ORDER BY
          ldgr.evnt_dt DESC,ldgr.evnt_seq_num ASC";
   $ledgers=sqlarrayp($dbh,$q_ldgr,array($id));
   # make a list of descriptions to use later, this will populate the desc_extra field
   $q_desc = "SELECT
        evnt_dt,evnt_seq_num,cmnt_60
       FROM
         fcs_evnt_ldgr_desc
       WHERE
          cs_id =?
       ORDER BY evnt_desc_num";
   $ledgdescraw=sqlarrayp($dbh,$q_desc,array($id));
   for ($i=0;$i<count($ledgdescraw);$i++) {
      list($dt,$seq,$desc)=$ledgdescraw[$i];
      if (!$ledgdesc["$dt:$seq"]) { $ledgdesc["$dt:$seq"]=array(); }
      $ledgdesc["$dt:$seq"][]=$desc;
   }
   # get all the ledger descriptions...
   $dockets = array();
   $dc = 0;
   for ($i=0;$i<count($ledgers);$i++) {
      list($id,$code,$desc,$dt,$did,$seq,$imgname,$doc_id)=$ledgers[$i];

      $dockets[$dc][0] = $id;
      $dockets[$dc][1] = $code;
      $dockets[$dc][2] = trim($desc);

      $dockets[$dc][3] = pretty_date($dt);
      $dockets[$dc][4] = $imgname;
      $dockets[$dc][5] = 0;  # Sealed; NEED TO IMPROVE
      $dockets[$dc][6] = $imgname;
      $dockets[$dc][7] = $seq;
      $dockets[$dc][8] = $doc_id;
      $dockets[$dc][9] = $ledgdesc["$dt:$seq"];
      $dc++;
   }
   return $dockets;
}



#
# get_docket_info_new_vision - Retrieve docket info from New Vision system
#
function get_docket_info_new_vision($dbh,$ucn,$id) {
   global $CASEGLOBAL,$DEBUG;
   $suffix=substr($CASEGLOBAL[$ucn][table_source],-2);
   $ts="docket_$suffix";
   $q="SELECT doc_id,doc_type,doc_action,convert(varchar(10),docket_dte,101),confid_flag FROM $ts WHERE pk_case_id=? order by pk_case_seq desc";
  $dockets=sqlarrayp($dbh,$q,array($id));
   # now check for sealed codes
   for ($j=0;$j<count($dockets);$j++) {
      if ($dockets[$j][5]==1) {
         $dockets[$j][2].=" [Sealed]";
      }
   }
  return $dockets;
}




#
# get_docket_info 
#

# $docket[] layout
# [0] - Docket ID
# [1] - Docket Code
# [2] - Docket Text
# [3] - Docket Date
# [4] - Docket image filename
# [5] - Docket Sealed (1/0) - to be compared to user's SEALED setting.
# [6] = Docket Document ID
# [7] - Docket Sequence
# [8] - Docket File Sequence
# [9] - Docket Extra Text Array (Brevard)


function get_docket_info($dbh,$id,$dbtype,$icmsdb,$ucn,$sealed_codes) {
   switch ($dbtype) {
      case 'clericus':
         $dockets=get_docket_info_clericus($dbh,$id);
         break;
      case 'crtv':
      case 'courtview':
         $dockets=get_docket_info_courtview($dbh,$id,$sealed_codes);
         break;
      case 'facts':
         $dockets=get_docket_info_facts($dbh,$id);
         break;
      case 'pioneer':
         $dockets=get_docket_info_pioneer($dbh,$id);
         break;
      case 'new vision':
         $dockets=get_docket_info_new_vision($dbh,$ucn,$id);
         break;
      default:
         echo "get_docket_info: unsupported dbtype of $dbtype\n";
         exit(1);
   }
   # now add any docketnotes created by the calendar system
   $icmsnotes=sqlarrayp($icmsdb,"select seq,date_format(date,'%m/%d/%Y'),userid,note from docketnotes where casenum=?",array($ucn));
   for ($i=0;$i<count($icmsnotes);$i++) {
       list($seq,$dt,$author,$note)=$icmsnotes[$i];
       $desc.=" <span style='font-size:8pt'><i>(ICMS)</i></span>";
       $dockets[]=array($seq,'ICMSNOTE',"$note - $author <i>(ICMS)</i>",$dt,NULL);
   }
   return $dockets;
}


function show_docket($countynum, $dockets,$docketcolors,$ucn,$tabname,$ccisucn,$docketimageinfo) {

   global $GROUPS;
   for ($i=0;$i<count($dockets);$i++) {
      list($did,$code,$desc,$fdate,$imgname,$sealed, $doc_id, $seq, $doc_seq, $desc_extra)=$dockets[$i];
      $desc=htmlspecialchars($desc);
      $desc=str_replace("/","&#x2F;",$desc); # escape forward slash, per OWASP
      $imgname=str_replace("\\","/",$imgname);
      if ($imgname!="" && $imgname!="0") { # if there's an image...
         if ($sealed==1 && !$GROUPS[SEALED]) { # it's sealed; you can't see it
            $docicon="<img src=icons/docsealed.png title='document is sealed; access restricted'>";
            $code=trim($code);
            if ($docketcolors[$code]) {
               $col="style='font-weight: bold; color:$docketcolors[$code]'";
            } else { 
              $col=""; 
            }
            echo "<tr class='viewnoimagesrow'>";
            echo "<td>$fdate</td>";
            if ($countynum == "05") {
              echo "<td>$seq</td>";
              echo "<td>$doc_seq</td>";
            }
            echo "<td $col>$docicon</td>";
            echo "<td width='100%' $col>";

            echo "<span $act>$desc<span id=\"dockmatch$did\" class=\"dockmatch\"></span></span>";
            if (count($desc_extra)) {  # brevard facts "extra" docket information
                echo "<table width='100%'>";
                foreach ($dockets[$i][9] as $xtra) {
                    echo "<tr style='background-color: inherit;'><td width='100%'>$xtra</td></tr>";
                }
                echo "</table>";
             }
             echo "</td>";


            echo "<td>$code</td>";
            echo "</tr>\n";

            continue;  
         }
         # IMAGES USER CAN SEE:
         # is it a good image? is it searchable?  the icons tell all, via docketimageinfo

         $did=trim($did);
         if (!$docketimageinfo[$did]) { # nothing in the documents database
            $docicon="<img src=icons/docquestion.png title='document has not yet been retrieved; click to retrieve.'>";
         } else if ($docketimageinfo[$did][1]) {  # isgoodocr
            $docicon="<img src=icons/docok.png title='document is viewable and searchable'>";
         } else if ($docketimageinfo[$did][0]) { # good doc, bad ocr
            $docicon="<img src=icons/docbadocr.png title='document is viewable, but not yet searchable'>";
         } else { # bad doc, bad ocr
            $docicon="<img src=icons/docbad.png title='document could not be retrieved; error has been logged'>";
         }
         $descx=urlencode($desc);
         $act="style=\"cursor:pointer\" onClick=\"ViewImage('$ucn',$did,'$ccisucn','$descx','$imgname','$tabname',612,704,'Image', '$code');\"";
         $code=trim($code);

         if ($docketcolors[$code]) {
            $col="style='font-weight: bold; text-decoration:underline; color:$docketcolors[$code]'";
         } else { 
            $col="style='text-decoration:underline'"; 
         }

         if ($did != $last_did || $did == '') {
           echo "<tr class='viewimagesrow' data-docket-code='$code' data-docket-id='$did' data-ccisucn='$ccisucn' data-docket-desc='$descx' data-image-name='$imgname' data-tab-name='$tabname'>";
           echo "<td>$fdate</td>";
           if ($countynum == "05") {
             echo "<td>$seq</td>";
             echo "<td>$doc_seq</td>";
           }
           echo "<td $col><span $act>$docicon</span></td>";

           echo "<td width='100%' $col>";
           echo "<span $act>$desc<span id=\"dockmatch$did\" class=\"dockmatch\"></span></span>";

           if (count($desc_extra)) {  # brevard facts "extra" docket information
             echo "<table width='100%'>";
             foreach ($dockets[$i][9] as $xtra) {
                 echo "<tr style='background-color: inherit;'><td width='100%'>$xtra</td></tr>";
             }
             echo "</table>";
           }
           echo "</td>";

           echo "<td>$code</td>";
           echo "</tr>\n";
         }

      } else {

         if ($docketcolors[$code]) {
            $col="style='font-weight: bold; color:$docketcolors[$code]'";
         } elseif ($code=="ICMSNOTE") { # ICMS docket note
            $col="style='background-color: yellow'";
         } else { 
            $col=""; 
         }

         if ($countynum == "05") {
            echo "<tr class='viewnoimagesrow'>";
            echo "<td>$fdate</td>";
            echo "<td>$seq</td>";
            echo "<td>$doc_seq</td>";
            echo "<td $col></td>";

           echo "<td width='100%' $col>";
           echo "<span $act>$desc<span id=\"dockmatch$did\" class=\"dockmatch\"></span></span>";

           if (count($desc_extra)) {  # brevard facts "extra" docket information
             echo "<table width='100%'>";
             foreach ($dockets[$i][9] as $xtra) {
                 echo "<tr style='background-color: inherit;'><td width='100%'>$xtra</td></tr>";
             }
             echo "</table>";
           }
           echo "</td>";

            echo "<td>$code</td>";
            echo "</tr>\n";
         } else {
           echo "<tr class='viewnoimagesrow'><td>$fdate</td><td $col></td><td $col><div>$desc</div></td><td>$code</td></tr>\n";
         }
      }
   }
}

#
# add_email adds an e-mail address to the "allemails" var passed it
#           IF the address isn't already on the list (eliminates
#           duplicates that way, a common problem since we have
#           multiple sources of e-mail addresses...
#           the ; separator works well for Outlook...

function add_email($allemails,$email) {
   if ($email!="" && stripos($allemails,$email.";")===false) { 
      $allemails.="$email;"; 
   }
   return $allemails;
}


function group_denied($group) {
   echo "This is a $group case, and you do not appear to be a member of the $group access group.<p>";
   echo "Please contact your technical support staff to be added to this group.";
   exit;
}


#
# ccis_search_ucn returns a CCIS/CLERICUS style UCN search string from the standard UCN provided
#
function ccis_search_ucn($ucn) {
   $ccisucn=str_replace('-','',$ucn);
   # does this case have an suffix?
   $suffix=substr($ucn,18);
   if ($suffix!="") {
      $ccisucn=substr($ccisucn,0,14)."__$suffix%";
   } else {
      $ccisucn.="%";
   }
   return $ccisucn;
}

#
# courtview_search_ucn returns a CourtView style UCN search string 
# from the standard UCN provided
#
function courtview_search_ucn($ucn) {
   $courtviewucn=str_replace('-',' ',substr($ucn,3))."%";
   return $courtviewucn;
}


#
# pioneer_search_ucn returns a Pioneer style UCN search string
# from the standard UCN provided
#
function pioneer_search_ucn($ucn) {
   $pioneerucn=str_replace('-',' ',substr($ucn,3))."%";
   return $pioneerucn;
}


#
# facts_ucn returns a FACTS style UCN search string 
# from the standard UCN provided
#
function facts_search_ucn($ucn) {
   # does this case have an suffix?
   $suffix=substr($ucn,18);
   if ($suffix!="") {
      $factsucn=substr($ucn,0,17)."%";
   } else {
      $factsucn=substr($ucn,0,18)."%";
   }
   return $factsucn;
}


#
# new_vision_search_ucn returns a New Vision style UCN search
# string from the standard UCN provided
#
function new_vision_search_ucn($ucn) {
   # does this case have an suffix?
   $ucn=substr($ucn,3);
   $ucn=str_replace("-","",$ucn);
   $ucn.="%";
   return $ucn;
}


#
# xml_case_style produces a case style suitable for an XML form order
#
# it's used by orders/xmlfields.php, but not much else at this point
# it needs the $ucn and the $parties array created by get_parties

# NEEDS MORE CASETYPES, AND MORE DB TYPES?

function xml_case_style($ucn,$parties) {
   $casetype=substr($ucn,8,2);
   if (preg_match("/TR|CF|CT|MM|MO|CO/",$casetype)) {   
      foreach ($parties as $party) {
        if (preg_match("/^defendant$/i",$party[1])) { # CLERICUS style
           return "<double>STATE OF FLORIDA</double><indent><double>Plaintiff</double></indent><double>-vs-</double><double>".$party[3]."</double><indent>Defendant</indent>";
        }
      }
      return "case_style: Defendant not found!";
   } elseif ($casetype=="CA") {   
      $ptf="";
      $def="";
      foreach ($parties as $party) {
         if (preg_match("/^defendant$/i",$party[1])) { # CLERICUS/courtview style
            if ($def=="") { $def=$party[3]; }
            else { $def.="~".$party[3]; }
         } elseif (preg_match("/^plaintiff$/i",$party[1])) { # CLERICUS/courtview style
            if ($ptf=="") { $ptf=$party[3]; }
            else { $ptf.="~".$party[3]; }
         }
      }
      $ptf="<line>".str_replace("~","</line><line>",$ptf)."</line>";
      $def="<line>".str_replace("~","</line><line>",$def)."</line>";
      $sty="<double>$ptf</double><indent><double>Plaintiff</double></indent><double>-vs-</double><double>$def</double><indent>Defendant</indent>";
#      file_put_contents('php://stderr',"STYLE: $sty",FILE_APPEND);
      return $sty;
   } else {
      $str="caseinfo ERROR: $casettype:  ";
      foreach ($parties as $party) { $str.="*".$party[1]."*:".$party[3]."\n"; }
      file_put_contents('php://stderr',$str,FILE_APPEND);
     return "casetype $casetype not yet supported";
   }
}


# build_case_style_long returns a case style as a multi-line text string

function build_case_caption ($ucn, $partylist) {
    $conf = simplexml_load_file($_SERVER['APP_ROOT'] . "/conf/ICMS.xml");
    $url = sprintf("%s/caseCaption", (string) $conf->{'icmsWebService'});
    
    $fields = array(
        'casenum' => urlencode($ucn)
    );
    
    $return = curlJson($url, $fields);
    $json = json_decode($return,true);
    $caption = $json['CaseCaption'];
    return $caption;
}



#
# cc_list returns a list of CC addresses in xmlorder markup from the
#         $ucn, $parties, and $ptyaddrs variable passed it.
#
#  NEEDS MORE CASETYPES, AND MORE DB TYPES?

function cc_list($ucn,$parties,$ptyaddrs) {
   $retval="";
   $casetype=substr($ucn,8,2);
   if ($casetype=="TR") {   
       foreach ($parties as $party) {
          if (preg_match("/^defendant$/i",$party["type"])){ # CLERICUS style
             $id=$party["id"];
             if ($ptyaddrs[$id][1]!="") { # we have a party e-mail address
                $retval="<p>".$party["name"]." ".$ptyaddrs[$id][1]."</p>";
             } else if ($ptyaddrs[$id][2]!="") { # just  a snail-mail address
                $retval="<line>".$party["name"]."\n".$ptyaddrs[$id][2]."</line>";
             } # otherwise no address--no mailing...
             return $retval;
          } 
       }
   } else {
     return "casetype $casetype not yet supported";
   }
}



# keys: ucn,id,ccisucn,casenum,age,status,type,type_description,judge,action_code, action_code_description

function case_base_info_facts($icms,$dbh,$ucn) {
   $caseid=find_case_id($icms,$dbh,$ucn,'facts'); # from icms search table, database
   $q="SELECT cs_id, caa44340041,(today-date(filing_dt)),cs_sts_desc,a.cs_cat,c.cs_cat_nm,judge,a.cs_typ,d.cs_typ_nm FROM fcs_cs_mstr a,fcb_sts_cd b,fcb_cs_category c,fcb_cs_typ d WHERE a.cs_sts=b.cs_sts AND a.cs_cat=c.cs_cat AND a.cs_typ=d.cs_typ and cs_id=$caseid";
   $res=sqlarrayp($dbh,$q,array());
   if (count($res)==0) {
      echo "Case # not found! ($ucn,$caseid)\n";
      return "";
   }
   $jdgcd=$res[0][6];
   if ($jdgcd!="") {
      $judge=sqlgetonep($dbh,"select judge_nm from fcb_judge where judge=?",array($jdgcd));
} else { $judge=""; }

   $case[ucn]=$ucn;
   $case[id]=$res[0][0];
   $case[ccisucn]=$res[0][1];
   $case[casenum]=$res[0][1];
   $case[age]=$res[0][2];
   $case[status]=$res[0][3];
   $case[type]=$res[0][4];
   $case[type_description]=$res[0][5];
   $case[judge]=$judge;
   $case[action_code]=$res[0][7];
   $case[action_code_description]=$res[0][8];
   return $case;
}





function case_base_info_clericus($icms,$dbh,$ucn) {
   $caseid=find_case_id($icms,$dbh,$ucn,'clericus'); # from icms search table
   #
   # SINCE THE CURRENT VERSION OF php5-sybase doesn't support quoted 
   # table names
   # and SINCE "case" is a reserved word, I'm using vw_case_details here, 
   # which is probably slower...IT ALSO DOESN'T PRESERVE NEWLINES...
   # DANG IT...
   $q="select top 1 caseID as id,UCN as ccisucn,CaseNumber as casenum,DATEDIFF(day,FiledDate,SYSDATETIME()) as age,CaseStatus as status,CaseType as type,UCN_TypeDescription as type_description,AssignedJudge as judge,UCN_TypeID as ucn_type,PrivacyID as privacy from vw_case_details where caseID=?";
   # CLERICUS sometimes has dups in vw_case_details...ignore..
   $res=sqlhashp($dbh,$q,array($caseid));
   if (count($res)==0) {
      echo "Case # not found! ($ucn,clericus)\n";
      return "";
   }
   $case=$res[0];
   if ($case["privacy"]==6) { $case["expunged"]=1; }
   else { $case["expunged"]=0; }
   if ($case["privacy"]==4) { $case["sealed"]=1; }
   else { $case["sealed"]=0; }
   # there MAY be a filing entry for this case; but maybe not...
   list($actcode,$actdesc)=sqlgetonerowp($dbh,"select top 1 filing_type_title,filing_type_desc from cd_filing_type a,filing b where a.filing_type_ID=b.filing_type_id and case_id=? order by filing_date desc",array($case["id"]));
   $case["action_code"]=$actcode;
   $case["action_code_description"]=$actdesc;
   $case["ucn"]=$ucn;
   return $case;
}



# id,ucn,ccisucn,casenum,age,status,type,type_description,judge,ucn_type,privacy,action_code,action_code_description,ticket_number

function case_base_info_courtview($icms,$dbh,$ucn) {
   $caseid=find_case_id($icms,$dbh,$ucn,'crtv'); # from icms search table
   $q="select case_id as id,dscr as casenum,DATEDIFF(day,file_dt,SYSDATETIME()) as age,stat_cd as status,case_cd as type,actn_cd as action_code,ticket_nbr as ticket_number from real_case where case_id=?";
   $q="SELECT c.case_id AS id, c.dscr AS casenum, DATEDIFF(day,COALESCE(dsproo.scr_dt, c.file_dt), SYSDATETIME()) AS age, c.stat_cd AS status, statcd.dscr AS status_description, c.case_cd AS type, casecd.dscr AS type_description, c.actn_cd AS action_code, actncd.dscr AS action_code_description, c.ticket_nbr AS ticket_number,
        (idnt.first_name+' '+ idnt.middle_name + ' '+ idnt.last_name) AS judge, dspjdg2.jdg_id AS judge_id
        FROM real_case as c
        LEFT JOIN casecd ON casecd.case_cd = c.case_cd
        LEFT JOIN actncd ON actncd.actn_cd = c.actn_cd
        LEFT JOIN statcd ON statcd.stat_cd = c.stat_cd
        LEFT JOIN (
          SELECT case_id, MIN(scr_dt) as scr_dt FROM dsp WHERE scr_cd IN('RO', 'ROC', 'ROCF', 'ROCJ', 'RODP', 'ROM', 'ROO') AND dsp_dt IS NULL GROUP BY case_id
        ) dsproo ON dsproo.case_id = c.case_id
        LEFT JOIN (
          SELECT case_id, MAX(seq) seq FROM dspjdg GROUP BY case_id
        ) dspjdg ON dspjdg.case_id = c.case_id
        LEFT JOIN dspjdg dspjdg2 ON dspjdg2.case_id = c.case_id AND dspjdg2.seq = dspjdg.seq
        LEFT JOIN jdg ON jdg.jdg_id = dspjdg2.jdg_id
        LEFT JOIN idnt ON idnt.idnt_id = jdg.idnt_id
        WHERE c.case_id = ?";

   $res=sqlhashp($dbh,$q,array($caseid));
   if (count($res)==0) {
      echo "Case # not found! ($ucn,$caseid,courtview)\n";
      return $case;
   }
   $case=$res[0];
   $case[ucn]=$ucn;
   $ccisucn=$ucn;
   $ccisucn=str_replace("-","",$ccisucn);
   $ccisucn="${ccisucn}XXXXXX";
   $case["ccisucn"]=$ccisucn;
   if ($case[status]=="S" || preg_match("/SLD$/",$case[type])) {
      $case["sealed"]=1;
   } else { $case["sealed"]=0; }
   # expunged is set by get_parties_clericus for courtview...
   return $case;
}


#
# case_base_info_pioneer provides case data for pioneer database
#
function case_base_info_pioneer($icms, $dbh, $ucn) {
  $caseid=find_case_id($icms,$dbh,$ucn,'pioneer');

  $q="SELECT TOP 1 tblCase.UniformCaseNumber as ccisucn, tblCase.CaseID as id, tblCase.CaseStatus as status, tblCase.CaseNumber as casenum, tblCaseType.CaseType as action_code, tblCaseType.CaseTypeDescription as action_code_description, tblPartyName.FirstName as judge_first_name, tblPartyName.MiddleName as judge_middle_name, tblPartyName.LastOrBusinessName as judge_last_name, DATEDIFF(DAY, tblCase.CaseOpenDate, SYSDATETIME()) as age,
    tblCourtType.CourtType as type, tblCourtType.CourtTypeDescription as type_description,tblCase.CaseSecurity
    FROM tblCase LEFT JOIN tblCaseType ON tblCase.CaseTypeID = tblCaseType.CaseTypeID LEFT JOIN tblPartyName ON tblCase.JudgeId = tblPartyName.PartyId LEFT JOIN tblCourtType ON tblCase.CourtTypeID = tblCourtType.CourtTypeID WHERE CaseID = ?";

  $res=sqlhashp($dbh,$q,array($caseid));
  if (count($res)==0) {
    echo "Case # not found! ($ucn,pioneer)\n";
    return "";
  }

  $case=$res[0];
  $case[ucn]=$ucn;
  $case[status_description]=sqlgetonep($dbh,"select dscr from statcd where stat_cd=?",array(trim($case[status])));
  $case[judge]=trim($case[judge_first_name].' '.$case[judge_middle_name].' '.$case[judge_last_name]);
  # "sealed" or "hidefromweb" here...
  if ($case[CaseSecurity]==1 || $case[CaseSecurity]==3) { $case[sealed]=1; }
  else { $case[sealed]=0; }
  if ($case[CaseSecurity]==2) { $case[expunged]=1; }
  else { $case[expunged]=0; }
  return $case;
}


#
# base info for new_vision cases
#

function case_base_info_new_vision($icms,$dbh,$ucn) {
   global $CASEGLOBAL,$DEBUG;
   $caseid=find_case_id($icms,$dbh,$ucn,'new vision'); # from icms search table
   if ($DEBUG) { echo "***case_base_info_new_vision: caseid=$caseid\n"; }
   # first question, which of four possible tables is this case in?
   # would love to have this represented in the search table.
   $ts=$CASEGLOBAL[$ucn][table_source];
   if (!$ts) { # more digging required
      $ts=new_vision_get_table_source($dbh,$ucn,$caseid);
   }
   $countynum=substr($ucn,0,2);
   if ($DEBUG) { echo "***case_base_info: ts=$ts, caseid=$caseid<br>\n"; }
   if (!$ts) {
      echo "Could not determine table type for $ucn ($ts)<br>\n";
      exit;
   }
   $q="select pk_case_id as id,cus_case_id as casenum,case_new_div as type,DATEDIFF(day,filing_dte,SYSDATETIME()) as age,case_status as status,case_type as action_code,action as action_code_description,code_division.value_1 as type_description,conf_flag as is_sealed,section_num as division,concat(section_num,': ',code_sections.value_1) as judge from $ts LEFT JOIN code_division ON code_division.pk_key_value_2=case_new_div LEFT JOIN code_sections ON section_num=code_sections.pk_key_value_1 where pk_case_id=?";

   $res=sqlhashp($dbh,$q,array($caseid));
   if (count($res)==0) {
      echo "Case # not found! ($ucn,clericus)\n";
      return "";
   }
   $case=$res[0];
#   if ($case["privacy"]==6) { $case["expunged"]=1; }
#   else { $case["expunged"]=0; }
#   if ($case["privacy"]==4) { $case["sealed"]=1; }
#   else { $case["sealed"]=0; }
   $case["ucn"]=$ucn;
   return $case;
}



#
# case_base_info provides initial case info (including case_id) for a given ucn...
#
# keys: ucn,id,ccisucn,casenum,age,status,type,type_description,judge,action_code,
#       action_code_description

function case_base_info($icms,$dbh,$ucn,$dbtype) {
   switch ($dbtype) {
      case 'clericus':
         return case_base_info_clericus($icms,$dbh,$ucn);
         break;
      case 'crtv':
      case 'courtview':
         return case_base_info_courtview($icms,$dbh,$ucn);
         break;
      case 'facts':
         return case_base_info_facts($icms,$dbh,$ucn);
         break;
      case 'pioneer':
         return case_base_info_pioneer($icms,$dbh,$ucn);
         break;
      case 'new vision':
         return case_base_info_new_vision($icms,$dbh,$ucn);
         break;
      default:
         echo "case_base_info: unsupported dbtype of $dbtype";
         exit;
   }
}



# used to store (for the moment) the table source for a New Vision case


function new_vision_get_case_id($db,$ucn,$nvucn) {
   global $CASEGLOBAL,$DEBUG;
   $ts=$CASEGLOBAL[$ucn][table_source]; # see if we have this handy
   if (!$ts) {  # we know what table
      # determine case table via casetype
      $casetype=substr($ucn,8,2);
      switch ($casetype) {
         case 'CC':
         case 'CO':
           $ts="case_co";
           break;
         case 'DP':
         case 'CJ':
            $ts="case_jv";
            break;
         case 'AD': 
         case 'AP':
         case 'DV':
         case 'XT':
            $ts="case_cr";
            break;
         case 'CP':
         case 'MH':
         case 'ZZ':
            $ts="case_pb";
            break;
         case 'CA':
         case 'DR':
            $year=substr($ucn,3,4);
            if ($year<1992) {
               $ts="?";
            } else {
               $ts="case_cr";
            }
            break;
      }
   }
   if ($DEBUG) { echo "***ts=$ts<br>"; }
   if ($ts=="?") { # an older CA/DR case
      $caseid=sqlgetonep($db,"select pk_case_id from case_cr where cus_case_id like ?",array($nvucn));
      $ts="case_cr";
      if (!$caseid) {
         $caseid=sqlgetonep($db,"select pk_case_id from case_ra where cus_case_id like ?",array($nvucn));      
      } else { $ts="case_ra"; }
   } else {
      $caseid=sqlgetonep($db,"select pk_case_id from $ts where cus_case_id like ?",array($nvucn));
   }
   if ($DEBUG) { echo "***new_vision_get_case_id=$ucn,$nvucn,$caseid<br>"; }
   if ($caseid) {
      $CASEGLOBAL[$ucn][table_source]=$ts;
   }
   return $caseid;
}


#
# this returns the table source for a given ucn, setting
#      $CASEGLOBAL[$ucn][table_source] as a side effect
#

function new_vision_get_table_source($db,$ucn,$caseid) {
   global $CASEGLOBAL,$DEBUG;
   $ts=$CASEGLOBAL[$ucn][table_source]; # see if we have this handy
   if (!$ts) {  # we know what table
      # determine case table via casetype
      $casetype=substr($ucn,8,2);
      switch ($casetype) {
         case 'CC':
         case 'SC':
           $ts="case_co";
           break;
         case 'DP':
         case 'CJ':
            $ts="case_jv";
            break;
         case 'AD': 
         case 'AP':
         case 'DV':
         case 'XT':
            $ts="case_cr";
            break;
         case 'CP':
         case 'MH':
         case 'ZZ':
            $ts="case_pb";
            break;
         case 'CA':
         case 'DR':
            $year=substr($ucn,3,4);
            if ($year<1992) {
               $ts="?";
            } else {
               $ts="case_cr";
            }
            break;
      }
   }
   if ($DEBUG) { echo "***ts=$ts<br>"; }
   if ($ts=="?") { # an older CA/DR case
      $caseidx=sqlgetonep($db,"select pk_case_id from case_cr where pk_case_id=?",array($caseid));
      $xts="case_cr";
      if (!$caseidx) {
         if ($DEBUG) { echo "***couldn't find $caseid in $xts, checking ra<br>\n"; }
         $caseidx=sqlgetonep($db,"select pk_case_id from case_ra where pk_case_id=?",array($caseid));      
         $xts="case_ra";
      }
      if ($caseidx) { $ts=$xts; }
   }
   if ($DEBUG) { echo "***new_vision_get_table_source_id=$ucn,$caseid,$ts<br>"; }
   if ($ts) {
      $CASEGLOBAL[$ucn][table_source]=$ts;
   }
   return $ts;
}


# look in the ICMS db, then the county's DB for the caseid for a case
# DB or not.  CLERICUS ONLY on part B right now...

function find_case_id($icms,$db,$ucn,$dbtype) {
   global $DEBUG,$CASEGLOBAL;
   if ($DEBUG) { echo "***find_case_id<p>"; } 
   $caseid=sqlgetonep($icms,"select case_id from search where ucn=? limit 1",array($ucn));
   if ($DEBUG) { echo "***find_case_id: $ucn: from search: $caseid<br>\n"; }
   if ($caseid=="") { # not in index, check db (SLOWER)
      switch ($dbtype) {
         case 'clericus':
            $ccisucn=ccis_search_ucn($ucn);
            $caseid=sqlgetonep($db,"select top 1 caseID from vw_case_details where UCN like ?",array($ccisucn));
            break;
         case 'crtv':
         case 'courtview':
            $courtviewucn=courtview_search_ucn($ucn);
            $caseid=sqlgetonep($db,"select case_id from cases where dscr like ?",array($courtviewucn));
            break;
         case 'facts':
            $factsucn=facts_search_ucn($ucn);
            $caseid=sqlgetonep($db,"select cs_id from fcs_cs_mstr where caa44340041 like ?",array($factsucn));
      if ($caseid=="") { echo "couldn't find match for $factsucn\n"; }
            break;
         case 'new vision':
             $nvucn=new_vision_search_ucn($ucn);
             if ($DEBUG) { echo "***nvucn=$nvucn<br>"; }
             $caseid=new_vision_get_case_id($db,$ucn,$nvucn);
      if ($caseid=="") { echo "couldn't find match for $nv\n"; }
             break;

         default:
            echo "find_case_id: unsupported dbtype of $dbtype";
            exit;
      }
   }
   return $caseid;
}



# makes a list of attorneys named "pro se" for later ignoring...
# (common in Alachua CourtView)

function pro_se_attorney_list($attorneys) {
   $attnew=array();
   foreach ($attorneys as $att) {
      if (preg_match("/PRO SE/",$att[2])) {
         $attnew[trim($att[0])]=1;
      }
   }
   return $attnew;
}


function getEserviceAddress (&$party, $ucn, $dbh) {
    $proSe = 1;
    if ($party['BarNumber'] != "") {
        $proSe = 0;
    }
    
    $party['ServiceList'] = array();
    
    if (!$proSe) {
        # First, check the case_emails.
        $query = "
            select
                email_addr
            from
                email_addresses e,
                case_emails c,
                users 
            where
                c.user_id in (
                    select
                        email_addr_id
                )
        ";
    }
}


function getScParties(&$partylist, $ucn, $dbh, $schema = "dbo") {
	
	$caseIdQuery = "SELECT CaseID
					FROM $schema.vCase
					WHERE CaseNumber = :casenum";
	
	$row = getDataOne($caseIdQuery, $dbh, array('casenum' => $ucn));
	$caseID = $row['CaseID'];
	
    $query = "
        select
            DISTINCT p.PersonID,
            p.FirstName,
            p.MiddleName,
            p.LastName,
            p.PartyType,
            p.BarNumber,
            p.PersonID as PartyID,
            CASE
				WHEN a.Represented_PersonID IS NOT NULL
				THEN 0
				ELSE 1
			END AS ProSe,
            p.CaseID,
            eMailAddress AS email_addr
        from
            $schema.vAllParties p with(nolock)
        left outer join
        	$schema.vAttorney a with(nolock)
        	on p.CaseID = a.CaseID
			and p.PersonID = a.Represented_PersonID
        where
            p.CaseID = :case_id
            and p.Active = 'Yes'
            and p.PartyType NOT IN ('JUDG', 'WIT', 'CHLD', 'DECD')
            AND (p.Discharged IS NULL OR p.Discharged = 0)
            -- AND (p.CourtAction IS NULL OR p.CourtAction NOT LIKE 'Disposed%') 
    ";
    
    $allParties = array();
    
    getData($allParties, $query, $dbh, array('case_id' => $caseID));
    
    $barnums = array();
    $personids = array();
    $caseid = "";
    foreach ($allParties as &$party) {
        $party['check'] = 1;
        if ($party['BarNumber'] != null) {
            $string = sprintf("'%s'", $party['BarNumber']);
            array_push($barnums, $string);
        } elseif ($party['PartyID'] != null && ($party['ProSe'] == '1') && empty($party['BarNumber'])) {
            array_push($personids, $party['PartyID']);
        }
        
        $caseid = $party['CaseID'];
    }
    
    // Now get the addressesof non-attorney parties
    $partyidstring = implode(",", $personids);

    $barnumstring = implode(",", $barnums);
    
    if($partyidstring != ""){
	    $query = "
	        select
	            FirstName,
	            MiddleName,
	            LastName,
	            AddressType,
	            Address1,
	            Address2,
	            City,
	            State,
	            ZipCode,
	            PartyID,
	            PartyTypeDescription
	        from
	            $schema.vAllPartyAddress with(nolock)
	        where
	            CaseID = :CaseID
	            and PartyID in ($partyidstring)
	            and DefaultAddress='Yes'
	            and AddressActive = 'Yes'
	            and PartyActive = 'Yes'
	    ";
	    
	    $parties = array();
	    getData($parties, $query, $dbh, array('CaseID' => $caseid));
    }
    
    // Now loop through these and merge them with the elements in $allParties
    foreach ($allParties as &$party) {
    	$pushed = false;
        $party['ServiceList'] = array();
        
        if(!empty($party['email_addr'])){
        	array_push($party['ServiceList'], trim($party['email_addr']));
        }
        
        if(isset($parties) && !empty($parties)){
	        foreach ($parties as $inner) {
	            if ($party['PartyID'] != $inner['PartyID']) {
	                continue;
	            }
	            $result = array_merge($party, $inner);
	            array_push($partylist['Parties'], $result);
	            $pushed = true;
	            break;
	        }
        }
        
        global $attorneyTypes;
        if(!$pushed && ($party['ProSe'] == '1') && (!in_array($party['PartyType'], $attorneyTypes))){
        	array_push($partylist['Parties'], $party);
        }
    }
    
    if ($barnumstring != "") {
        $attorneys = array();
        $query = "
            select
            	DISTINCT BarNumber,
                Address1,
                Address2,
                City,
                State,
                Zip as ZipCode,
                PartyType as PartyTypeDescription
            from
                $schema.vAttorney with(nolock)
            where
                CaseID = :CaseID
                and BarNumber in ($barnumstring)
        ";
        
        getData($attorneys, $query, $dbh, array('CaseID' => $caseid));
        
        // Now loop through these and merge them with the elements in $allParties
        foreach ($attorneys as $attorney) {
            foreach ($allParties as $inner) {
                if ($attorney['BarNumber'] != $inner['BarNumber']) {
                    continue;
                }
                $result = array_merge($attorney, $inner);
                array_push($partylist['Attorneys'], $result);
                break;
            }
        }
    }

    foreach($partylist['Attorneys'] as $key => &$a){
    	$oldBar = $a['BarNumber']; 
    	$a['BarNumber'] = "FL" . ltrim($a['BarNumber'], '0');	
    
    	//If they are representing a disposed party, take them off...
    	$disposedQuery = "
	    	SELECT
	    		COUNT(Represented_PersonID) AS PartyCount,
	    		SUM(
	    			CASE
	    			WHEN p.CourtAction LIKE '%Disposed%'
	    			THEN 1
	    			ELSE 0
	    			END
	    		) AS DisposedCount
	    	FROM
	    		$schema.vAttorney a
	    	INNER JOIN
	    		$schema.vParty p
	    		ON a.CaseID = p.CaseID
	    		AND a.Represented_PersonID = p.PersonID
	    	WHERE
	    		a.CaseID = :case_id
	    	AND
	    		a.BarNumber = :bar_number";
    	
    	$countRow = getDataOne($disposedQuery, $dbh, array("case_id" => $caseid, "bar_number" => $oldBar));
    	
    	if($countRow['DisposedCount'] >= $countRow['PartyCount']){
    		//unset($partylist['Attorneys'][$key]);
    		//$partylist['Attorneys'] = array_values($partylist['Attorneys']);
   	 	}
    }
}

function getBannerParties (&$partylist, $ucn, $dbh) {
    $query = '
        select
            spriden_pidm as "PIDM",
            spriden_first_name as "FirstName",
            spriden_mi as "MiddleName",
            spriden_last_name as "LastName",
            cdrcpty_ptyp_code as "PartyType",
            cdrcpty_assoc_with as "Represents",
            cdrcpty_seq_no as "Sequence",
            CASE
                WHEN REGEXP_LIKE(spriden_id, \'^\d\') THEN \'FL\' || TO_NUMBER(spriden_id)
                ELSE null
            END as "BarNumber",
            CASE
                WHEN REGEXP_LIKE(spriden_id, \'^\D\') THEN spriden_id
                ELSE null
            END as "PartyID",
            1 as "ProSe",
            1 as "check",
            spraddr_strt_no || \' \' || spraddr_strt_frct || \' \' || spraddr_strt_pda || \' \' || spraddr_strt_name ||
                \' \'  || spraddr_strt_sufa || \' \' || spraddr_strt_PODA as "Address1",
            spraddr_sec_ada || \' \' || spraddr_sec_add_unit || \' \' ||
                spraddr_bldf_sec_name as "Address2",
            spraddr_city as "City",
            spraddr_zip as "ZipCode",
            spraddr_stat_code as "State",
            spraddr_atyp_code as "AddrType",
            spraddr_seqno as "AddrSeq"
        from
            spriden
                left outer join cdrcpty on (spriden_pidm = cdrcpty_pidm)
                left outer join spraddr on (spriden_pidm = spraddr_pidm)
        where
            cdrcpty_case_id = :casenum
            and spriden_change_ind is null
            and cdrcpty_end_date is null
            and cdrcpty_ptyp_code <> \'JUDG\'
            and spraddr_to_date is null
        order by decode(spraddr_atyp_code,
            \'MA\',1,
            \'BU\',2,
            \'RE\',3,
            \'AL\',4,
            5)
    ';
    
    $allParties = array();
    getData($allParties, $query, $dbh, array('casenum' => $ucn), 'PIDM', 0);
    
    // Ok, this is a hash, keyed on the pidm, of arrays of the parties. Since
    // we've flattened it and selected the addresses in the preferred order, we
    // only need to move it into the array.
    foreach (array_keys($allParties) as $pidm) {
        foreach ($allParties[$pidm] as &$party) {
            if ($party['BarNumber'] != null) {
                $bar = $party['BarNumber'];
                if ($party['Represents'] != null) {
                    $repseq = $party['Represents'];
                    
                    // Find the appropriate party and mark as not pro se
                    foreach (array_keys($allParties) as $innerpidm) {
                        $ifound = 0;
                        foreach ($allParties[$innerpidm] as &$repParty) {
                            if ($repParty['Sequence'] != $repseq) {
                                continue;
                            }
                            $repParty['ProSe'] = 0;
                            $ifound = 1;
                            break;
                        }
                        if ($ifound) {
                            // Break out of the outer loop - we found what we needed
                            break;
                        }
                    }
                }
                // And check to ensure we're not adding this attorney more than once.
                $found = 0;
                foreach ($partylist['Attorneys'] as $added) {
                    if ($added['BarNumber'] != $bar) {
                        continue;
                    }
                    $found = 1;
                    break;
                }
                if (!$found) {
                    array_push($partylist['Attorneys'], $party);
                }
            } else {
                // Add to the Parties list if not already there
                $found = 0;
                
                foreach ($partylist['Parties'] as $existing) {
                    if ($existing['PIDM'] == $pidm) {
                        $found = 1;
                        continue;
                    }
                }
                if (!$found) {
                    if ($allParties[$pidm][0]['ProSe']) {
                        array_push($partylist['Parties'], $allParties[$pidm][0]);   
                    }
                }
            }
        }
    }
    
    // Now that we have a listing of attorneys, go through the list and add Pro Se parties.
    //foreach (array_keys($allParties) as $pidm) {
    //    if (($allParties[$pidm][0]['BarNumber'] != "") || (!$allParties[$pidm][0]['ProSe'])) {
    //        continue;
    //    }
    //    array_push($partylist['Parties'], $allParties[$pidm][0]);
    //}
}


# build_cc_list builds the CCLIST array from clerk, bar, and other sources
# $CCLIST[0]=checkbox, $CCLIST[1]=Name, $CCLIST[2]=Emails, $CCLIST[3]=Snail-mail

function build_cc_list($icms,$ucn, &$parties) {
    $listTypes = array('Attorneys','Parties');

    list($ucn, $casetype) = sanitizeCaseNumber($ucn);
    $xml = simplexml_load_file($_SERVER['APP_ROOT'] . "/conf/ICMS.xml");
    if (empty($xml->showCaseDb)) {
    	$dbName = "showcase-prod";
    }
    else{
    	$dbName = (string)$xml->showCaseDb;
    }
    
    $cmsdbh = dbConnect($dbName);
    
    foreach ($listTypes as $listType) {
        $parties[$listType] = array();
    }
        
    $schema = getDbSchema($dbName);
    getScParties($parties, $ucn, $cmsdbh, $schema);   

    foreach ($listTypes as $listType) {
        foreach ($parties[$listType] as &$party) {
            buildAddress($party);
        }
    }
    
    getServiceList($parties, $ucn);
    $suppressed = getSuppressedAddresses($ucn);
    $additional = getAdditionalAddresses($ucn);
    $agency = getAgencyAddresses($ucn);
    
    //Remove suppressed addresses
    if(count($suppressed) > 0){
      foreach($parties['Attorneys'] as &$a){
          foreach($a['ServiceList'] as $key => &$s){
              if(in_array($s, $suppressed)){
                  unset($a['ServiceList'][$key]);
              }
          }
      }
      foreach($parties['Parties'] as &$p){
          foreach($p['ServiceList'] as $key => &$s){
              if(in_array($s, $suppressed)){
                  unset($p['ServiceList'][$key]);
              }
          }
      }
    }
    
    //Add additional e-mails
    if(count($additional) > 0){
		$count = count($parties['Parties']);
      	foreach($additional as $ad){
      		$parties['Parties'][$count]['check'] = 1;
      		$parties['Parties'][$count]['FullName'] = 'No Name Available';
         	$parties['Parties'][$count]['ServiceList'] = array($ad['email_addr']);
         	$count++;
      	}
    }
    
    //Add agency e-mails - add to PD or ASA already on the case, if there is one
    if(count($agency) > 0){
    	$count = count($parties['Parties']);
    	foreach($agency as $ag){
    		$found = false;
    		foreach($parties['Parties'] as $key => $p){
    			if($p['PartyType'] == "ASA" && (stripos($ag['email_addr'], "sa15") !== false)){
    				if(!in_array(strtolower($ag['email_addr']), array_map('strtolower', $parties['Parties'][$key]['ServiceList']))){
		    			$parties['Parties'][$key]['ServiceList'][] = $ag['email_addr'];
    				}
		    		$found = true;
    			}
    			else if($p['PartyType'] == "PD" && (stripos($ag['email_addr'], "pd15") !== false)){
    				if(!in_array(strtolower($ag['email_addr']), array_map('strtolower', $parties['Parties'][$key]['ServiceList']))){
		    			$parties['Parties'][$key]['ServiceList'][] = $ag['email_addr'];
    				}
		    		$found = true;
    			}
    		}
    		
    		if(!$found){
    			$parties['Parties'][$count]['check'] = 1;
    			$parties['Parties'][$count]['FullName'] = 'No Name Available';
    			$parties['Parties'][$count]['ServiceList'] = array($ag['email_addr']);
    			$count++;
    		}
    	}
    }
    
    //Remove blanks?
    foreach($parties['Parties'] as $key2 => $p2){
    	if(empty($p2['FullName']) && empty($p2['ServiceList']) && empty($p2['FullAddress']) || (!isset($p2['FullAddress']) && empty($p2['ServiceList']))){
    		unset($parties['Parties'][$key2]);
    		$parties['Parties'] = array_values($parties['Parties']);
    	}
    	
    	//This is a one-off... remove Carey Haughwout's e-mail from e-service on MH cases
    	if($p2['BarNumber'] == "FL375675" && (strpos($ucn, "MH") !== false)){
    		$parties['Parties'][$key2]['ServiceList'] = array("mentalhealth@pd15.org");
    	}
    	
    	//Another one-off.. remove Magistrate Fanelli's e-mail address from e-service
    	if($p2['BarNumber'] == "FL510335"){
    		$parties['Parties'][$key2]['ServiceList'] = array();
    	}
    }
    
    return;
}

function getSuppressedAddresses($ucn){
   $dbh = dbConnect("eservice");
   $results = array();
   $sup = array();
   
   $query = "  SELECT email_addr
               FROM suppress_emails
               WHERE casenum = :ucn";     
               
   getData($results, $query, $dbh, array("ucn" => $ucn));
   
   foreach($results as $r){
      $sup[] = $r['email_addr'];
   }
   
   return $sup;
}

function getAdditionalAddresses($ucn){
   $dbh = dbConnect("eservice");
   $results = array();
   
   $query = "  SELECT email_addr
               FROM reuse_emails
               WHERE casenum = :ucn";
               
   getData($results, $query, $dbh, array("ucn" => $ucn));
   
   return $results;
}

function getAgencyAddresses($ucn) {
    $edbh = dbConnect("eservice");
    $sdbh = dbConnect("showcase-prod");
    $schema = getDbSchema("showcase-prod");
    $addressRef = array();
    
    $hasPD = 0;
    $hasSA = 0;
    $hasORCC = 0;

    $query = "SELECT 
    			DivisionID,
    			CaseID,
    			CaseType
    		  FROM $schema.vCase
    		  WHERE CaseNumber = :ucn";
    
    $divRow = getDataOne($query, $sdbh, array("ucn" => $ucn));
    
    $div = $divRow['DivisionID'];
    $case_id = $divRow['CaseID'];
    $case_type = $divRow['CaseType'];
    
    if (empty($div)) {
        return;
    }
    
    $parties = array();
    $query = " 
    		select
                PartyType,
                BarNumber,
                LastName
            from
                $schema.vAllParties with(nolock)
            where
                CaseID = :caseid
                and Active = 'Yes'";
    
    getData($parties, $query, $sdbh, array("caseid" => $case_id));
    
    $includePD = 0;
    foreach($parties as $party) {
    	//This is Carey Haughwout's bar number.  We are going to include the PD MH e-mail instead of hers.  This is done elsewhere.
    	if($party['BarNumber'] == '0375675'){
    		$includePD = 0;
    	}
    	
        if (in_array($party['PartyType'], array('PD','APD','PPD'))) {
            $hasPD = 1;
        }
        
        if (in_array($party['PartyType'], array('SA','ASA')) || (strpos($ucn, "DP") === false)) {
            $hasSA = 1;
        }
        
        if (in_array($party['PartyType'], array('ORCC')) || ($party['BarNumber'] == "ORCC") || ($party['LastName'] == "REGIONALCONFLICTCOUNSEL")) {
            $hasORCC = 1;
        }
    }
    
    $types = array();
    if ($hasPD) {
    	$types[] = "'PD'";
    }
    if ($hasSA) {
        $types[] = "'SA'";
    }
    if ($hasORCC) {
        $types[] = "'ORCC'";
    }
    
    if (count($types) > 0) {
        $inString = implode(",", $types);
        $query = "
            select
                email_addr,
                0 as from_portal,
                1 as agency
            from
                agency_div_addresses
            where
                division = :division
                and agency in ($inString)
        ";
        getData($addressRef, $query, $edbh, array("division" => $div));
    }
    
    $pdAdd = array();
    //PD wants certain addresses copied on MH cases
    if ((strpos($ucn, 'MH') !== false) && ($includePD == '1')){
    	$pdAdd['email_addr'] = "mentalhealth@pd15.org";
    	$pdAdd['from_portal'] = 0;
    	$pdAdd['agency'] = 1;
    	$addressRef[] = $pdAdd;
	}
	
	$orccAdd = array();
	//I'm going to do ORCC separately...
	if($hasORCC){
		//Civil e-mail address for juvenile dependency, mental health, and guardianship cases
		if((strpos($ucn, "DP") !== false) || (strpos($ucn, "MH") !== false) || (strpos($ucn, "GA") !== false)){
			$orccAdd['email_addr'] = "WPBCivilDocket@rc-4.com";
			$orccAdd['from_portal'] = 0;
			$orccAdd['agency'] = 1;
			$addressRef[] = $orccAdd;
		}
		//Appellate e-mail address for appellate cases (duh)
		else if(strpos($ucn, "AP") !== false){
			$orccAdd['email_addr'] = "RC4AppellateFilings@rc-4.com";
			$orccAdd['from_portal'] = 0;
			$orccAdd['agency'] = 1;
			$addressRef[] = $orccAdd;
		}
		//Criminal address for the rest (criminal and juvenile delinquency)
		else{
			$orccAdd['email_addr'] = "WPBCriminalDocket@rc-4.com";
			$orccAdd['from_portal'] = 0;
			$orccAdd['agency'] = 1;
			$addressRef[] = $orccAdd;
		}
	}
	
	//Baker Acts
	if($case_type == "BA" && (strpos($ucn, "MH") !== false)){
		$baPDAdd = array();
		$baPDAdd['email_addr'] = "E-BakerAct@pd15.org";
		$baPDAdd['from_portal'] = 0;
		$baPDAdd['agency'] = 1;
		$addressRef[] = $baPDAdd;

		$baSAAdd = array();
		$baSAAdd['email_addr'] = "E-BakerAct@sa15.org";
		$baSAAdd['from_portal'] = 0;
		$baSAAdd['agency'] = 1;
		$addressRef[] = $baSAAdd;
	}
	
	return $addressRef;
}


# save_party_address saves the array passed it as a JSON object to file path $fname
# NOT using json_encode, as it turns null-valued things into associative arrays.

function save_party_address($fname,$cclist,$casestyle) {
    $obj=new stdClass();
    $obj->casestyle=$casestyle;
    $obj->cclist=$cclist;

#   $json=encode_json($obj);
#   $json="[";
#   for ($i=0;$i<count($cclist);$i++) {
#      list($chk,$name,$email,$address)=$cclist[$i];
#      if ($name=="") { continue; } # skip blanks; otherwise they accumulate...
#      $address=str_replace("\n",'\r\n',$address);
#      if ($flag) { $json.=","; }
#     $json.="[\"$chk\",\"$name\",\"$email\",\"$address\"]";
#      $flag=1;
#   }
#   $json.="]";
   file_put_contents($fname,json_encode($obj));
}


# get_case_style easy returns the style of the case with just a UCN.
#  don't use it inside a loop!  we need a more efficient one than this.

function get_case_style_easy($ucn) {
   $counties=load_conf_file("county_db_info.json");
   $icms=db_connect("icms");
   $countynum=substr($ucn,0,2);
   $db=db_connect("$countynum");
   $dbtype=$counties->{$countynum}->{database_type};
   $caseid=find_case_id($icms,$db,$ucn,$dbtype);
   $schedb=db_connect("eservice");
   # leaving schedb as null -- not actually used yet anyway
   $parties=get_parties($db,"",$ucn,$caseid,$dbtype,$unused);
   foreach ($parties as $party) {
      list($id,$role,$x,$name)=$party;
      $name=str_replace("  "," ",$name);
      $role=strtolower($role);
      if (!$ptypes[$role]) { $ptypes[$role]=$name; }
      elseif (strpos($ptypes[$role],"et al.")===false) {
         $ptypes[$role].=", et al.";
      }
   }   
   if ($ptypes["child (dependent)"]!="") { # plaintiff-defendant pair
       return "Dependency of ".$ptypes["child (dependent)"];
   } elseif ($ptypes["plaintiff"]!="") { # plaintiff-defendant pair
       return $ptypes["plaintiff"]." v. ".$ptypes["defendant"];
   } elseif ($ptypes["petitioner"]!="") { # petitioner/respondent pair
       return $ptypes["petitioner"]." v. ".$ptypes["respondent"];
   } elseif ( $ptypes["defendant"]) { # defendant only
       return $ptypes["defendant"];
   } elseif ( $ptypes["decedent"]) { # probate
       return "Estate of ".$ptypes["decedent"];
   } elseif ( $ptypes["decedent/deceased"]) { # probate
       return "Estate of ".$ptypes["decedent/deceased"];
   } elseif ( $ptypes["respondent"]) { # mental health
       return "In Re: The Commitment of ".$ptypes["respondent"];
   } elseif ( $ptypes["ward"]) { # guardianship
       return "Guardianship of ".$ptypes["ward"];
   } elseif ( $ptypes["grantor"]) {  
       return $ptypes["grantor"]." v. ".$ptypes["trustee"];
   } else { 
       return "ERROR: not yet supported: ".join(",",array_keys($ptypes));
   }
}


# get_docket_image_info gets the info about the images for this ucn
# whether they've been snagged, and ocred correctly...

function get_docket_image_info($icmsdb,$ucn) {
  $docketimageinforaw=sqlarrayp($icmsdb,"select did,isgood,isgoodocr from documents where ucn=?",array($ucn));
  foreach ($docketimageinforaw as $x) {
     $docketimageinfo[$x[0]][0]=$x[1];
     $docketimageinfo[$x[0]][1]=$x[2];
  }
  return $docketimageinfo;
}



#
# get_akas checks the ICMS index for any ALSO KNOWN AS entries for this case...
#
function get_akas($icms,$ucn) {
   $q="select party_id,last_name,first_name,middle_name,suffix_name from search where ucn=? and partytype='ALSO KNOWN AS'";
   $arr=sqlarrayp($icms,$q,array($ucn));
   $akas=array();
   foreach ($arr as $line) {
      list($id,$last,$first,$middle,$suffix)=$line;
      $name="$first $middle $last";
      if ($suffix!="") { $name.=", $suffix"; }
      if ($akas[$id]) { $akas[$id].="<br>$name"; }
      else { $akas[$id].="$name"; }
   }
   return $akas;
}

function concat_address($add1, $add2, $add3, $city, $state, $zip){
  $address="";
  if (trim($add1)!="") { $address.="$add1\n"; }
  if (trim($add2)!="") { $address.="$add2\n"; }
  if ($add3!="") { $address.="$add3\n"; }
  if ($city!="") { $address.="$city, $state $zip"; }

  return $address;
}

function get_view_case_type($ucn){
  $parts=explode("-", $ucn);
  return "$parts[0]-$parts[2]";
}

function get_saved_view_buttons($icmsdb, $ucn, $user){
  $type=get_view_case_type($ucn);
  $json=sqlgetonep($icmsdb,"select json from config where user='ALL' and module='views'", array());
  $hasqueue=has_work_queue($icmsdb,$user);
  $config = json_decode($json, true);
  $out = "<div class='saved-view-buttons' data-case-type='$type'>";

  if($config["views"] && $config["views"][$type]){
    foreach ($config["views"][$type] as $name => $view) {
      $button = <<<EOS
       <div class="button-set" data-view-name="$name" data-case-type="$type">
        <div>
          <button class="saved-view-open" data-view-name="$name" data-case-type="$type">$name</button>
          <button>Select an action</button>
        </div>
        <ul style="position: absolute; z-index: 9999;">
          <li><a href="#" class="saved-view-open" data-view-name="$name" data-case-type="$type">Open</a></li>
EOS;
      if ($hasqueue) {
        $button .= <<<EOS
          <li><a href="#" class="saved-view-delete" data-view-name="$name" data-case-type="$type">Delete</a></li>
EOS;
      }
        $button .= <<<EOS
          <li><a href="#" class="saved-view-default" data-view-name="$name" data-case-type="$type">Default</a></li>
        </ul>
      </div>
EOS;
      $out .= $button;
    }
  }

  $out .= "</div>";

  return $out;
}

?>
