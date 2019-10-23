#!/usr/bin/perl

BEGIN {
    use lib "$ENV{'JVS_PERL5LIB'}";
}

use CGI;
use JSON;

use strict;

use ICMS15 qw (
    no_cache_header
    get_group_memberships
    load_module_config
    save_module_config
);

use DB_Functions qw (
    dbConnect
    getData
    ldapLookup
    inGroup
    ldapConnect
    getDivs
    getCustomQueues
    getSubscribedQueues
	getSharedQueues
	getQueues
);

use Common qw (
    dumpVar
    doTemplate
    $templateDir
    buildName
    createTab
    getUser
    getSession
    checkLoggedIn
);

use POSIX qw (
    strftime
);

checkLoggedIn();

#
# MAIN PROGRAM
#
my $DEBUG=0;
my $info=new CGI;
my $user = getUser();
my $session = getSession();

my $dbh=dbConnect("icms");
my %data;
$data{'username'} = $user;

my @myqueues = ($user);
my @sharedqueues;

getSubscribedQueues($user, $dbh, \@myqueues);
getSharedQueues($user, $dbh, \@sharedqueues);
my @allqueues = (@myqueues, @sharedqueues);
my %queueItems;

my $wfcount = getQueues(\%queueItems, \@allqueues, $dbh);

my $config_ref = load_module_config($user, 'config');

my %subscriptions;

foreach my $key ('calendars','alerts','reports','queues') {
    my $subDivs = $config_ref->{$key};
    my @divs = split(",", $subDivs);
    foreach my $div (@divs) {
        if (!defined($subscriptions{$div})) {
            $subscriptions{$div} = {};
        }
        $subscriptions{$div}->{$key} = 1;
    }
}

$data{'subscriptions'} = \%subscriptions;
$data{'shared_with'} = $config_ref->{'shared_with'};
$data{'priv_notes_shared_with'} = $config_ref->{'priv_notes_shared_with'};
$data{'transfer_to'} = $config_ref->{'transfer_to'};

no_cache_header();

my %GROUPS;

# Connect once, for multiple lookups
my $ldap = ldapConnect();

get_group_memberships($user, \%GROUPS, $ldap);
$data{'groups'} = \%GROUPS;

if (inGroup($user, 'CAD-ICMS-ODPS', $ldap)) {
    $data{'formedit'} = 1;
}

$data{'divlist'} = {};

my $jdbh = dbConnect("judge-divs");
getDivs($data{'divlist'}, $jdbh);
getCustomQueues($data{'divlist'}, $jdbh);


my $flag=0;
my @users;
my @userRef;

my $query = qq {
    select
        userid,
        first_name as FirstName,
        middle_name as MiddleName,
        last_name as LastName,
        suffix as Suffix
    from
        users
    order by
        LastName, FirstName
};

getData(\@userRef, $query, $dbh);

foreach my $u (@userRef) {
	my %user;
	$user{'FirstName'} = $u->{'FirstName'};
	$user{'MiddleName'} = $u->{'MiddleName'};
	$user{'LastName'} = $u->{'LastName'};
	
	#my $name = buildName(\%user);
	
	my $name = $u->{'LastName'} . ", " . $u->{'FirstName'};
	if($u->{'MiddleName'} ne ""){
		$name .= " " . $u->{'MiddleName'} . ".";
	}
	
	$user{'name'} = $name;
	$user{'userid'} = $u->{'userid'};
	push(@users, \%user);
}

$data{'users'} = \@users;
$data{'thisUser'} = lc($user);

# THIS BLOCK 

$data{'wfCount'} = $wfcount;
$data{'active'} = "settings";
$data{'tabs'} = $session->get('tabs');

doTemplate(\%data, "$templateDir/top", "header.tt", 1);
doTemplate(\%data,"$templateDir/settings", "index.tt",1);
exit;

# END OF BLOCK


print "<h3>Options</h3>";
print "<div style='width:500px'>";
print "Share Queue With: ";
print "<span id=sharedlist></span><br><select id=sharedselect style=\"font-size:10pt\"><option>";
foreach my $userid (@users) {
   my $fullname=$userid->{'userid'};
   print "<option value=$userid>$fullname";
}
print "</select> <input type=button id=sharedadd value='Add'> <input type=button id=shareddel value='Delete'><p>";
print "<table id=opt>";
my $opt_checked = '';
if ($config_ref->{'opt_cal_dragdrop'}) {
   $opt_checked = 'checked';
}
print "<tr>";
print "<td width='60%'>Calendar Drag & Drop</td>";
print "<td width='40%'><input type=checkbox id='opt_cal_dragdrop' value='1' $opt_checked></td>";
print "</tr>";



my $sharedwith=$config_ref->{'shared_with'};
my $tab_selected = 'selected="selected"';
my $popout_selected = '';
my $docviewer_selected = '';
my $sidebyside_selected = '';

my $docviewer = $config_ref->{'docviewer'};

if ($docviewer eq "tab") {
    $tab_selected = 'selected="selected"';
    $popout_selected = '';
    $docviewer_selected = '';
    $sidebyside_selected = '';
} elsif ($docviewer eq "popout"){
    $popout_selected = 'selected="selected"';
    $tab_selected = '';
    $docviewer_selected = '';
    $sidebyside_selected = '';
} elsif ($docviewer eq "docviewer") {
    $docviewer_selected = 'selected="selected"';
    $tab_selected = '';
    $popout_selected = '';
    $sidebyside_selected = '';
} elsif ($docviewer eq "sidebyside") {
    $docviewer_selected = '';
    $tab_selected = '';
    $popout_selected = '';
    $sidebyside_selected = 'selected="selected"';    
}


# PDF Open Parameters
my $pdf_viewer_acrobat_selected='selected="selected"';
my $pdf_viewer_pdfjs_selected='';

$config_ref->{'pdf_viewer'} = "pdfjs";

if($config_ref->{'pdf_viewer'} eq 'pdfjs'){
  $pdf_viewer_acrobat_selected='';
  $pdf_viewer_pdfjs_selected='selected="selected"';
} else {
  $pdf_viewer_acrobat_selected='selected="selected"';
  $pdf_viewer_pdfjs_selected='';
}

my $pdf_toolbar_selected='selected="selected"';
my $no_pdf_toolbar_selected='';

if($config_ref->{'pdf_toolbar'} == 1){
  $pdf_toolbar_selected='selected="selected"';
  $no_pdf_toolbar_selected='';
} else {
  $pdf_toolbar_selected='';
  $no_pdf_toolbar_selected='selected="selected"';
}

my $pdf_scrollbar_selected='selected="selected"';
my $no_pdf_scrollbar_selected='';

if($config_ref->{'pdf_scrollbar'} == 1){
  $pdf_scrollbar_selected='selected="selected"';
  $no_pdf_scrollbar_selected='';
} else {
  $pdf_scrollbar_selected='';
  $no_pdf_scrollbar_selected='selected="selected"';
}

my $pdf_statusbar_selected='selected="selected"';
my $no_pdf_statusbar_selected='';

if($config_ref->{'pdf_statusbar'} == 1){
  $pdf_statusbar_selected='selected="selected"';
  $no_pdf_statusbar_selected='';
} else {
  $pdf_statusbar_selected='';
  $no_pdf_statusbar_selected='selected="selected"';
}

my $pdf_navpanes_selected='';
my $no_pdf_navpanes_selected='selected="selected"';

if($config_ref->{'pdf_navpanes'} == 1){
  $pdf_navpanes_selected='selected="selected"';
  $no_pdf_navpanes_selected='';
} else {
  $pdf_navpanes_selected='';
  $no_pdf_navpanes_selected='selected="selected"';
}

my $pdf_fit_selected='';
my $pdf_fith_selected='';
my $pdf_fitb_selected='';
my $pdf_fitv_selected='';
my $pdf_fitbh_selected='';
my $pdf_fitbv_selected='';
my $pdf_zoom_selected='';

my $pdfView= $config_ref->{'pdf_view'};

if ($pdfView eq "Fit") {
    $pdf_fit_selected='selected="selected"'
} elsif ($pdfView eq "FitH") {
    $pdf_fith_selected='selected="selected"'
} elsif ($pdfView eq "FitB") {
    $pdf_fitb_selected='selected="selected"';
} elsif ($pdfView eq "FitV") {
    $pdf_fitv_selected='selected="selected"';
} elsif ($pdfView eq "FitBH") {
    $pdf_fitbh_selected='selected="selected"';
} elsif ($pdfView eq "FitBV") {
    $pdf_fitbv_selected='selected="selected"';
} elsif ($pdfView eq "Zoom") {
    $pdf_zoom_selected='selected="selected"';
}

my $pdf_zoom='100';
if($config_ref->{'pdf_zoom'} != "") {
  $pdf_zoom=$config_ref->{'pdf_zoom'};
}

print <<EOS;
<tr>
  <td>
    <label for="docviewer">Open Documents In:&nbsp;&nbsp;</label>
  </td>
  <td>
    <select id="docviewer" name="docviewer">
      <option value="tab" $tab_selected>New Tab</option>
      <option value="popout" $popout_selected>Popup Window</option>
      <option value="docviewer" $docviewer_selected>Multi-Pane Document Viewer</option>
      <option value="sidebyside" $sidebyside_selected>Side-By-Side Viewer</option>
    </select>
  </td>
</tr>
<tr>
  <td>
    <label><strong>PDF Open Parameters:</strong>&nbsp;&nbsp;</label>
  </td>
  <td></td>
</tr>
<tr>
  <td>
    <label>Viewer:&nbsp;&nbsp;</label>
  </td>
  <td>
    <select id="pdf_viewer" name="pdf_viewer">
      <option value="acrobat" $pdf_viewer_acrobat_selected>Acrobat/System</option>
      <option value="pdfjs" $pdf_viewer_pdfjs_selected>PDFJS</option>
    </select>
  </td>
</tr>
<tr>
  <td>
    <label>Display Toolbar:&nbsp;&nbsp;</label>
  </td>
  <td>
    <select id="pdf_toolbar" name="pdf_toolbar">
      <option value="1" $pdf_toolbar_selected>Yes</option>
      <option value="0" $no_pdf_toolbar_selected>No</option>
    </select>
  </td>
</tr>
<tr>
  <td>
    <label>Display Scrollbar:&nbsp;&nbsp;</label>
  </td>
  <td>
    <select id="pdf_scrollbar" name="pdf_scrollbar">
      <option value="1" $pdf_scrollbar_selected>Yes</option>
      <option value="0" $no_pdf_scrollbar_selected>No</option>
    </select>
  </td>
</tr>
<tr class="acrobat-opt">
  <td>
    <label>Display Status Bar&nbsp;&nbsp;</label>
  </td>
  <td>
    <select id="pdf_statusbar" name="pdf_statusbar">
      <option value="1" $pdf_statusbar_selected>Yes</option>
      <option value="0" $no_pdf_statusbar_selected>No</option>
    </select>
  </td>
</tr>
<tr>
  <td>
    <label>Display Nav Panes:&nbsp;&nbsp;</label>
  </td>
  <td>
    <select id="pdf_navpanes" name="pdf_navpanes">
      <option value="1" $pdf_navpanes_selected>Yes</option>
      <option value="0" $no_pdf_navpanes_selected>No</option>
    </select>
  </td>
</tr>
<tr>
  <td>
    <label>View:&nbsp;&nbsp;</label>
  </td>
  <td>
    <select id="pdf_view" name="pdf_view">
      <option value="Fit" $pdf_fit_selected>Fit</option>
      <option value="FitH" $pdf_fith_selected>FitH</option>
      <option value="FitV" $pdf_fitv_selected>FitV</option>
      <option value="FitB" $pdf_fitb_selected>FitB</option>
      <option value="FitBH" $pdf_fitbh_selected>FitBH</option>
      <option value="FitBV" $pdf_fitbv_selected>FitBV</option>
      <option value="Zoom" $pdf_zoom_selected>Zoom</option>
    </select>
  </td>
</tr>
<tr id="opt_zoom">
  <td>
    <label>Zoom:&nbsp;&nbsp;</label>
  </td>
  <td>
    <input id="pdf_zoom" name="pdf_zoom" value="$pdf_zoom" size="4" />%
  </td>
</tr>
EOS


print "</table>";
print "</div>";
print "<h3>Subscriptions</h3><div style='width:500px'><i>Check the appropriate boxes for the divisions you desire. Checking and un-checking the All box at the end selects or un-selects all the features for that division. If you don't have permissions to a division it will appear <span style='color:grey'>greyed out</span>.</i></div></div>";
print "<p><table id=setsubs><thead><tr><td>Division</td><td>Description</td><td><td>Calendar</td><td>Reports</td><td>Queues</td><td>Alerts</td><td>All</td></tr></thead><tbody>";
my %divshash=build_all_divs_hash();

my($calck,$queck,$rptck,$alrtck,$allck,$dis,$sty);
my $already="";
foreach my $div (sort keys %divshash) {
    my $showdiv=0;
   my $divname=$divshash{$div};
   if ($config_ref->{"calendars"} ne "" && $config_ref->{"calendars"}=~/$div/) { $calck="checked"; $showdiv++ }
   else { $calck=""; }
   if ($config_ref->{"reports"} ne "" && $config_ref->{"reports"}=~/$div/) { $rptck="checked"; $showdiv++ }
   else { $rptck=""; }
   if ($config_ref->{"queues"} ne "" && $config_ref->{"queues"}=~/$div/) { $queck="checked"; $showdiv++ }
   else { $queck=""; }
   if ($config_ref->{"alerts"} ne "" && $config_ref->{"alerts"}=~/$div/) { $alrtck="checked"; $showdiv++ }
   else { $alrtck=""; }
   
   # note; the division AD thing is Alachua only at this time, but
   #       causes no harm..
   if (($div=~/CJ/ && !is_in_group($user,'DELINQUENCY')) ||
       ($div=~/DP/ && !is_in_group($user,'DEPENDENCY')) ||
       ($div=~/MH/ && !is_in_group($user,'SEALED')) ||
       ($div=~/AD/ && !is_in_group($user,'ADOPTION'))
      ) { 
       $dis="disabled";
       $sty='style="color:grey"';
   } else { $dis=""; $sty=""; }
    if ($showdiv) {
      print "<tr><td><span $sty>$div<span></td><td $sty>$divname<td align=center><td align=center><input type=checkbox id='cal$div'  $calck $dis></td><td align=center><input type=checkbox id='rpt$div'  $rptck $dis></td><td align=center><input type=checkbox id='que$div' $queck $dis></td><td align=center><input type=checkbox id='alrt$div' $alrtck $dis></td><td><input type=checkbox id='all$div' class=allck $allck$dis></td></tr>\n";
      $already.="$div: ";
    }
}
print "</tbody></table>Add Division: <select id=stnewdiv><option>";
foreach my $div (sort keys %divshash) {
   my $divname=$divshash{$div};
   if (not $already=~/$div:/) {
       print "<option value=$div>$div: $divname";
   }
}
print "</select> <input type=button id=stnewdivbutton value=Add onClick=SettingsNewDivAdd();>";
print "<input type=hidden id=\"shared_with\" name=\"shared_with\" value=\"$sharedwith\">";
print "</div>";
