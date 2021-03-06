<!DOCTYPE html>

<?php
require_once($_SERVER['OLS_DOCROOT'] . "/php-lib/db_functions.php");

$jdbh = dbConnect('judge-divs');

$judges = array();
$divisions = array();
getJudgeDivs($judges,$divisions,$jdbh);

$x=array_keys($divisions);
sort($x);

# Also build the listing of OLS divisions.  And Criminal.  And Juvenile.
$olsdiv = array();
$crimdivs = array();
$juvdivs = array();
foreach ($x as $adiv) {
    if ($divisions[$adiv]['has_ols']) {
        $string = "$adiv~Divison $adiv";
        array_push($olsdiv,$string);
    }

    if (preg_match('/\~crim$/', $divisions[$adiv]['opt'])) {
        $crimdivs[$adiv] = $divisions[$adiv];
    }

    if (preg_match('/\~juv$/', $divisions[$adiv]['opt'])) {
        $juvdivs[$adiv] = $divisions[$adiv];
    }
}

$query = "
    select
        distinct(division_type)
    from
        divisions
    where
        division_type not in ('Shadow')
";

$divtypes = array();
getData($divtypes, $query, $jdbh);

$query = "
    select
    	distinct(courthouse_nickname),
        c.courthouse_id
    from
    	divisions d left outer join courthouses c on (d.courthouse_id=c.courthouse_id)
    where	
    	first_appearance = 1
";

$faps = array();
getData($faps, $query, $jdbh);

$jdbh = null;

asort($divtypes);

$fdbh = dbConnect("icms");

$flagTypes = array();
$query = "
    select
        flagtype,
        dscr
    from
        flagtypes
    order by
        dscr
";

getData($flagTypes,$query,$fdbh);

$fdbh = null;

?>


<html>

<head>
    <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
    <meta name="GENERATOR" content="Mozilla/4.72 [en] (Windows NT 5.0; I) [Netscape]" />
	<meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="Author" content="Default" />

    <title>
		12th Circuit Case Management System
    </title>
	
	<link rel="stylesheet" type="text/css" href="https://e-services.co.palm-beach.fl.us/cdn/style/bootstrap/bootstrap.css"/>
	<link href="https://e-services.co.palm-beach.fl.us/cdn/style/jquery-ui-1.10.4/themes/south-street/jquery-ui.css" type="text/css" rel="stylesheet"/>
	<link rel="stylesheet" type="text/css" href="icms1.css?1.1" />
	<script src="https://e-services.co.palm-beach.fl.us/cdn/jslib/jquery-1.11.0.min.js" type="text/javascript"></script>
	<script src="https://e-services.co.palm-beach.fl.us/cdn/jslib/bootstrap/bootstrap.min.js" type="text/javascript"></script>
	<script type="text/javascript" src="https://e-services.co.palm-beach.fl.us/cdn/jslib/jquery-ui-1.10.4.min.js"></script>
	<script type="text/javascript" src="https://e-services.co.palm-beach.fl.us/cdn/jslib/jquery.blockUI.js"></script>
	<script src="/icms.js" type="text/javascript"></script>
    <script src="/javascript/main.js" type="text/javascript"></script>
</head>

<body onload="SetBack('ICMS_0'); SetBack('ICMS_1'); document.theform.name.focus(); document.theform.type.value='';">
	<script type="text/javascript">
		$(document).ready(function () {
			$(".datepicker").datepicker({
                showOn: "both",
                buttonImageOnly: true,
                buttonText: "Select date",
                format: 'mm/dd/yyyy',
                buttonImage: "/style/images/calendar.gif",
				autoclose: true,
				todayHighlight: true,
				todayBtn: 'linked',
                changeMonth: true,
                changeYear: true,
                yearRange: "-80:+0"
			});
			
			$('.clearDates').click(function () {
                $(this).parent("div").find('.datepicker').each(function(i,e) {
                    $(e).val(''); 
                });
				return false;
			});
			
			$('.calsubmit').click(function () {
                var btnid = $(this).attr('id');
				var division = $(this).parent().find('.divsel').val();
				if (division == "") {
					$('#dialogSpan').html("Please select a division from the list.");
					$('#dialogDiv').dialog({
						resizable: false,
						minheight: 150,
						width: 500,
						modal: true,
						title: 'No Division Selected',
						buttons: {
							"OK": function() {
								$(this).dialog( "close" );
								return false;
							}
						}
					});
					return false;
				}
				$('#theform').attr('action','/cgi-bin/calendars/showCal.cgi');
				$('#div').val(division);
				$('#theform').submit();
				return true;
			});
			$('.search').click(function () {
				var searchname = $.trim($('#searchname').val());
				$('#searchname').val(searchname);
				var searchcitation = $.trim($('#searchcitation').val());
				$('#searchcitation').val(searchcitation);
				if ((searchname == "") && (searchcitation == "")) {
					$('#dialogSpan').html("Please enter a name, case number, or citation number and try again.");
					$('#dialogDiv').dialog({
						resizable: false,
						minheight: 150,
						width: 500,
						modal: true,
						title: 'No Search Parameters Entered',
						buttons: {
							"OK": function() {
								$(this).dialog( "close" );
								return false;
							}
						}
					});
					return false;
				}
				$.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait </h1>', fadeIn: 0});
				$('#theform').submit();
				return true;
			});
		});
	</script>

	<div class="container">
	<div id="dialogDiv">
		<span id="dialogSpan" style="font-size: 80%"></span>
	</div>

    <form name="theform" id="theform" method="post" action="/cgi-bin/search.cgi">
	<input type="hidden" name="countyone" value="All" />
	<input type="hidden" name="types" value="All" />
	<input type="hidden" name="referer" value="/index.php" />
	<input type="hidden" name="div" id="div"/>

	<img src="icmslogo.jpg" alt="ICMS" />

	<table style="border:none">
	    <tr style="vertical-align:top">
		<td>
		    <input type="button" name="helpbutton" value="Help"
			       onclick="popup('help/icmshelp.html','Help')"/>
		</td>
	    </tr>
	</table>

	<table>
	    <tr>
            <td colspan="3">
                <span class="h2">
            	Circuit-Wide Search
                </span>
            </td>
            </tr>
	    <tr>
            <td style="text-align:right; vertical-align:top; width: 130px">
                <span class="h3">
            	Name or Case #:
                </span>
            </td>

            <td class="textinput">
                <div>
                    <div>
                        <input style="line-height: 1.25em" type="text" id="searchname" name="name" size="30"/>
                        <input style="height: 2em" type="submit" name="gosearch" class="search" value="Search"/>
                    </div>

                    <div>
						<div>
							<input style="line-height: 1.25em; width: 10em; margin-right: .5em;" class="datepicker" id="DOB" name="DOB"/> DOB (will only list cases where DOB matches)
                            <input type="checkbox" name="fuzzyDOB" checked="checked" value="1">Approximate DOB (will search 15 days before and after)
							<button type="button" class="clearDates" style="height: 2em">Clear DOB </button>
						</div>
                        <div>
                            <select name="limitdiv" style="margin-right: .5em; width: 10em;">
                                <option value="All" selected="selected">All Divisions</option>
                                <?php
                                foreach ($x as $div) {
                                    print "<option value=\"" . $divisions[$div]['opt'] . "\">$div</option>\n";
                                }
                                ?>
                            </select>Limit search to this division (name searches only)
                        </div>

                        <div>
                            <select name="limittype" style="margin-right: .5em; width: 10em;">
                                <option value="All" selected="selected">All Court Types</option>
                                <?php
                                foreach ($divtypes as $div) {
                                    print "<option value=\"" . $div['division_type'] . "\">" . $div['division_type'] . "</option>\n";
                                }
                                ?>
                            </select>Limit search to this court type (name searches only). <span style="color: red">OVERRIDES DIVISION SELECTION.</span>
                        </div>
                        <div>
                            File Dates Between
                            <input style="line-height: 1.25em; width: 10em; margin-right: .5em;" class="datepicker" id="searchStart" name="searchStart"/>
                            and
                            <input style="line-height: 1.25em; width: 10em; margin-right: .5em;" class="datepicker" id="searchEnd" name="searchEnd"/>
                            Name searches only
                            <button type="button" class="clearDates" style="height: 2em">Clear Dates</button> 
                        </div>

                        <div>
                            <input type="checkbox" name="soundex"/>'Sounds Like' Name Search
                        </div>

                        <div>
                            <input type="checkbox" name="business"/>Business Names Only  <span style="color: red">Use * as a root or word expander. For example, searching
                            <span style="font-style: italic; font-weight: bold">exxon*</span> will return "Exxon", "Exxon Mobil", "Exxon Corp", etc. </span>
                        </div>

                        <div>
                            <input type="radio" name="searchtype" value="regular" checked="checked" />All Party Search
                        </div>

                        <div>
                            <input type="radio" name="searchtype" value="attorney"/>Attorney Party Search
                        </div>

                        <div>
                            <input type="radio" name="searchtype" value="defendant"/>Defendant Party Search
                        </div>

                        <div>
                            <input type="checkbox" name="photos"/>Show Booking Photos
                        </div>
                    </div>
                </div>
            </td>
	    </tr>

	    <tr>
            <td colspan="3">
                <input type="hidden" name="type" value=""/>
            </td>
        </tr>

        <tr>
            <td style="text-align:right; vertical-align:top;">
                <span class="h3">
                    Citation #:
                </span>

            </td>

            <td class="textinput">
                <div>
                    <input style="line-height: 1.25em" type="text" id="searchcitation" name="citation" size="30"/>
                    <input style="height: 2em" type="submit" name="gosearch" class="search" value="Search"/>
                </div>

                <div>
                    <div>
                        <input type="checkbox" name="active"/>
                        Active Cases Only
                        &nbsp;&nbsp;
                        <input type="checkbox" name="charges" checked="checked"/>Show Charge Information
                    </div>

                    <div>
                        <input id="crimonly" type="checkbox" name="criminal" onchange="toggleOpposite('crimonly','civonly')"/>
                        Criminal and Traffic Cases Only
                    </div>

                    <div>
                        <input id="civonly" type="checkbox" name="nocriminal" onchange="toggleOpposite('civonly','crimonly')"/>
                        Civil Cases Only
                    </div>
                </div>
            </td>
	    </tr>

	    <tr>
		<td colspan="3">
		    &nbsp;
		</td>
	    </tr>

	    <tr>
		<td colspan="3">
		    <span class="h3">
			<a href="/cgi-bin/flaggedCaseSearch.cgi">
			    Flagged Case Search
			</a>
		    </span>
		</td>
	    </tr>
        
        <tr>
		<td colspan="3">
		    <span class="h3">
			<a href="/cgi-bin/casenotes/bulkflag.cgi">
			    Bulk Case Flagging/Unflagging
			</a>
		    </span>
		</td>
	    </tr>

	    <tr>
		<td colspan="3">
		    <span class="h3">
			<a href="/pbso/pbsolookup.php?lev=1">
			    PBSO Search
			</a>
		    </span>
		</td>
	    </tr>
	</table>

    <br/>



    <table style="border:none">
        <tr>
            <td>
                <div class="h2">
                    Judge Reports
                </div>
            </td>
        </tr>
	<tr>
	    <td>
		<span class="h3">

		</span>
		<select name="judgexy">
<?php
foreach (array_keys($judges) as $ajudge) {
    echo "<option value=\"$ajudge~$judges[$ajudge]\">$ajudge</option>\n";
}
?>
		</select>
		<input type="button" name="foo2" value="View" onclick="gojudge3()"/>
	    </td>
	</tr>

	<tr>
	    <td>
		<table style="border:none">
			<tr>
				<td colspan="2">
				    &nbsp;
				</td>
		    </tr>

		    <tr style="vertical-align:top">
				<td colspan="2">
					<div class="h2">
						Division Reports
					</div>
				</td>
		    </tr>
		    <tr>
				<td colspan="1">
				    <span class="h3">

				    </span>
                    <select name="divxy">
<?php
    foreach ($x as $adiv) {
    	if (!in_array($adiv,array("","AK","AP"))) {
    		echo '<option value="' . $divisions[$adiv]['opt'] . '">' . $adiv ;
    		if ($adiv != "VA") {
    			echo " (" . $divisions[$adiv]['courtType']. ")";
    		}
    		echo "</option>\n";
    	}
    }
?>
                    </select>
                </td>
                <td>
                    <input type="button" name="foo3" value="View" onclick="godiv();"/>
                </td>
            </tr>

            <tr>
                <td colspan="2">
                    <span class="h3">
                        <a href="/cgi-bin/alldivs.cgi?type=crim">
                            All Criminal Divisions
                        </a>
                    </span>
                </td>
		    </tr>

		    <tr>
                <td colspan="2">
                    <span class="h3">
                        <a href="/cgi-bin/alldivs.cgi?type=civ">
                            All Civil Divisions
                        </a>
                    </span>
                </td>
		    </tr>

		    <tr>
                <td colspan="2">
                    <span class="h3">
                        <a href="/cgi-bin/alldivs.cgi?type=fam">
                            All Family Divisions
                        </a>
                    </span>
                </td>
		    </tr>
            
            <tr>
                <td colspan="2">
                    <span class="h3">
                        <a href="/cgi-bin/alldivs.cgi?type=juv">
                            All Juvenile Divisions
                        </a>
                    </span>
                </td>
		    </tr>
            
            <tr>
                <td colspan="2">
                    <span class="h3">
                        <a href="/cgi-bin/alldivs.cgi?type=pro">
                            All Probate Divisions
                        </a>
                    </span>
                </td>
		    </tr>
		</table>
	    </td>
	</tr>
	</table>

	<table style="border:none">
	    <tr style="vertical-align:top">
		<td>
			<div class="h2">
			    Flagged Case Reports
			</div>
		    </td>
		</tr>
		<tr>
			<td>
				<span class="h3">
					Please use 
					<a href="/cgi-bin/flaggedCaseSearch.cgi">
						Flagged Case Search
					</a>
				</span>
			</td>
			
<!--		    <td>
			<span class="h3">

			</span>
			<select name="flagxy">

<?php
foreach($flagTypes as $flag)  {
    if ($flag['dscr'] != "") {
        echo '<option value="' . $flag['flagtype'] . '~' . $flag['dscr'] . '">'.
            $flag['dscr'] . '</option>';
    }
}
?>
			</select>
			<input type="button" name="fooflag" value="View"
			       onclick="goflag()"/>
		    </td>
-->		</tr>
	    </table>
	
	<br/>

	<table style="border:none">
		<tr style="vertical-align: top">
			<td>
				<div class="h2">
					Civil Calendars
				</div>
			</td>
		</tr>
		<tr>
			<td id="civsel">
				<select style="min-width: 15em" class="divsel" name="caldiv" id="caldiv">
					<option value="">Select a Division</option>
				<?php
					foreach($olsdiv as $div)  {
						list($type,$dscr)=explode("~",$div);
						$type = strtolower($type);
						if ($type != "") {
							echo "<option value=\"$type\">$dscr</option>\n";
						}
					}
				?>
				</select>
                <button class="calsubmit" name="calType" value="civcal">View</button>
		    </td>
		</tr>

		<tr>
			<td>
				&nbsp;
			</td>
		</tr>
	<!--</table>-->
	<!---->
	<!--<br/>-->
	<!---->
	<!--<table style="border:none">-->
		<tr style="vertical-align: top">
			<td>
				<div class="h2">
					Criminal Calendars
				</div>
			</td>
		</tr>
		<tr>
			<td id="crimsel">
				<select style="min-width: 15em" class="divsel"  name="crimdiv" id="crimdiv">
					<option value="">Select a Division</option>

<?php
$y=array_keys($crimdivs);
sort($y);

foreach ($y as $divname) {
    $dscr = $crimdivs[$divname]['courtType'];
    echo "<option value=\"$divname\">$divname ($dscr)</option>\n";
}
?>

				</select>
                <button class="calsubmit" name="calType" value="crimcal">View</button>
		    </td>
		</tr>

        <tr>
			<td>
				&nbsp;
			</td>
		</tr>

        <tr style="vertical-align: top">
			<td>
				<div class="h2">
					Juvenile Calendars
				</div>
			</td>
		</tr>
		<tr>
			<td id="juvsel">
				<select style="min-width: 15em" class="divsel"  name="juvdiv" id="juvdiv">
					<option value="">Select a Division</option>

<?php
$y=array_keys($juvdivs);
sort($y);

foreach ($y as $divname) {
    $dscr = $juvdivs[$divname]['courtType'];
    echo "<option value=\"$divname\">$divname ($dscr)</option>\n";
}
?>

				</select>
                <button class="calsubmit" name="calType" value="juvcal">View</button>
		    </td>
		</tr>
        
        
		<tr>
			<td>
				&nbsp;
			</td>
		</tr>
		

        <tr style="vertical-align: top">
			<td>
				<div class="h2">
					First Appearance Calendars
				</div>
			</td>
		</tr>
        
        <tr>
			<td id="fapsel">
				<select style="min-width: 15em" class="divsel"  name="fapch" id="fapch">
					<option value="">Select a Location</option>
                    <?php foreach ($faps as $fap) { ?>
                    <option value="<?php echo $fap['courthouse_id']; ?>"><?php echo $fap['courthouse_nickname']; ?></option>
                    <?php } ?>
				</select>
                <button class="calsubmit" name="calType" value="fapcal">View</button>
		    </td>
		</tr>

		
		<tr>
			<td>
				&nbsp;
			</td>
		</tr>
		
		<tr>
			<td><a href="/cgi-bin/calendars/trafficDocket.cgi">Traffic Dockets</a></td>
		</tr>


	</table>

	<br/>

	<div class="probs">
		<div class="probstitle">
			Problems?
		</div>

		Please e-mail <a href="mailto:webhelp@jud12.flcourts.com">webhelp@jud12.flcourts.com</a>
		to report any problems with this system.
	</div>

	<div class="disc">
		<strong>
		    Disclaimer
		</strong>
		<br/>
		The Court warrants that the images viewed on this site are what
		they purport to be. However, the Court makes no warranty as to
		whether additional documents exist that could affect a case,
		but do not yet appear on the docket. Furthermore, the Court
		does not warrant whether any data entered by the Clerk
		(including the docket index) is accurate.
	</div>

	<div style="font-size:50%">
		Court Technology Department, Twelfth Judicial
		Circuit of Florida
    </div>
    </form>
	
	</div>

    </body>
</html>
