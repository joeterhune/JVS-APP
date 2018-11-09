<?php
// 01/13/10 lms new page for accessing flagged cases
// 05/13/10 lms Add Active cases only checkbox.
// 06/23/10 lms add db connection below for icms
// 04/11/11 lms Making flags a multiple choice.
// 06/10/11 lms Check Active Cases as a default.
require_once $_SERVER['DOCUMENT_ROOT']."/case/php-lib/db_functions.php";

$lev = 1;
if (isset($_REQUEST['lev'])) {
    $lev=$_REQUEST['lev'];
}

$selection_months = '<option value="" selected="selected">&nbsp;</option>
					<option value="1" >01</option>
					<option value="2" >02</option>
					<option value="3" >03</option>
					<option value="4" >04</option>
					<option value="5" >05</option>
					<option value="6" >06</option>
					<option value="7" >07</option>
					<option value="8" >08</option>
					<option value="9" >09</option>
					<option value="10" >10</option>
					<option value="11" >11</option>
					<option value="12" >12</option>';


// generate a list of all flag types
$dbh = dbConnect("icms");

if(isset($dbh)) {
	$flagtypes = array();
	$query = "
		select
			flagtype,
			dscr
		from
			flagtypes
		order by
			dscr
	";
	getData($flagtypes, $query, $dbh);

	// number to show in the drop down list
	$showcnt = sizeof($flagtypes);
	if($showcnt > 25) {
		$showcnt = 15;
	}

    // generate a list of all divisions using judge page list
	$fp=fopen("/usr/local/icms/etc/judgepage.conf","r");
	while (!feof($fp)) {
		$line=fgets($fp,1024);
		$line=substr($line,0,-1);
		if (!preg_match('/~/',$line)) {
			continue;
		}
		list($name,$div,$casetype)=explode('~',$line);
		$arr[]="$div~$casetype~$name";
	}
    fclose($fp);
    sort($arr);
}

?>
<html>
	<head>
		<title>Lookup Flagged Cases</title>
		<link rel="stylesheet" type="text/css" href="/case/style/jquery-ui.css">
		<link rel="stylesheet" type="text/css" href="/case/icms1.css">

		<script src="https://e-services.co.Sarasota-beach.fl.us/cdn/jslib/jquery-1.8.3.min.js" type="text/javascript"></script>
		<script src="https://e-services.co.Sarasota-beach.fl.us/cdn/jslib/jquery-ui-1.10.3.min.js" type="text/javascript"></script>
		<script src="https://e-services.co.Sarasota-beach.fl.us/cdn/jslib/date.js" type="text/javascript"></script>
		<script src="/case/icms.js" type="text/javascript"></script>

		<script type="text/javascript">
		function dosearch(level) {
			var form = $('#flaggedcases');
			var startDate = new Date($('#startDate').val());
			var endDate = new Date($('#endDate').val());

			if (endDate < startDate) {
				alert("The start date must be before or equal to the end date.");
				return false;
			}

			$('<input>').attr({
				type: 'hidden',
				name:'lev',
				value: level
			}).appendTo(form);

			$(form).submit();
			return true;
		}

		$(document).ready(function () {
			$(".datepicker").datepicker({
				showOn: "both",
				buttonImage: "/case/style/images/calendar.gif",
				buttonImageOnly: true,
				changeMonth: true,
				changeYear: true,
				dateFormat: "yy-mm-dd",
				maxDate: "+0"
			});
		});
		</script>
	</head>

	<?php $backlev=$lev-1; ?>

	<body onload="SetBack('ICMS_<?php echo $lev;?>');">
	<div>
		<a href="/case/index.php">
			<img src="/case/icmslogo.jpg" alt="ICMS Logo" style="border: none">
		</a>
	</div>

	<div>
		<input type=button name=Back value=Back onClick=GoBack("ICMS_<?php echo $backlev;?>");>
		<div class="pagetitle" style="text-align: left; margin-top: 10px; font-weight: bold">
			Search Flagged Cases
		</div>

		<span style="color: blue">
			Select one or more flags.  If All is selected, the search will search for all flags,
			regardless of other flag selections.
		</span>
	</div>
		<?php
		if (!isset($dbh)) {
			echo "<div>There is a problem with the Case Notes / Flags database.  No connection can be made.  Please try later.</div>";
		} else {
?>
	<form id="flaggedcases" method="post" action="/cgi-bin/flagsearch.cgi">
		<div style="font-size: 150%; font-weight: bold">
			Show
			<select name="flagtype" id="flagtype"  multiple="multiple" size="<?php echo $showcnt;?>">
				<option value="all" selected="selected">
					All
				</option>
				<?php
				// build links for all flag types in the flagtypes table
				foreach ($flagtypes as $flagtype) {
					$flagnum = $flagtype['flagtype'];
					$dscr = $flagtype['dscr'];
					echo "<option value='$flagnum'>$dscr</option>\n";
				}
				?>
			</select>
			&nbsp;flagged cases for division&nbsp;
			<select name="division" id="division">
				<option value="all" selected="selected">
					All
				</option>
				<?php
				foreach ($arr as $line) {
					list($div,$casetype,$name)=explode('~',$line);
					$sdiv=$div;
					if(strlen($sdiv)==0){
						$sdiv="not assigned";
					}
					echo "<option value=\"$div\">$sdiv</option>";
				}
				?>
			</select>
		</div>

		<div>
			<div style="font-size: 150%; font-weight: bold; margin-bottom: 0px">
				Flagged Dates
			</div>

			<div style="margin-bottom: 0px">
				<input type="radio" name="flagdate" id="alldates" value="all" checked="checked">
					<span class="h3">
						All
					</span>
			</div>

			<div>
				<div style="float: left;">
					<input type="radio" name="flagdate" id="daterange" value="range">
					<span class="h3" style="margin-right: 20px";>
						Range
					</span>
				</div>

				<div>
					<!--<input class="datepicker" name="startdate" id="startdate" class="range">-->
					<input type="text" name="startDate" class="datepicker" class="range"
						   id="startDate" onchange="$('#daterange').attr('checked','checked')"
						   onfocus="$('#daterange').attr('checked','checked');">


				    through

					<input type="text" name="endDate" class="datepicker" class="range"
						   id="endDate" onchange="$('#daterange').attr('checked','checked')"
						   onfocus="$('#daterange').attr('checked','checked');">
				</div>
			</div>
			<input type="checkbox" name="active" id="active" checked="checked"><span class="h4"> Active Cases Only</span>
		</div>

		<div>
			<input type="button" name="gosearch" id="gosearch" value="Search" onclick="dosearch(<?php echo $lev;?>);"/>
		</div>

    </form>
<?php } ?>
</body>
</html>
