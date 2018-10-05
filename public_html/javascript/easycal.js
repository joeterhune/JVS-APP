var daysOfWeek = new Array("Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday");

var caseTypes = new Object();

// AA, AB, etc.
caseTypes["As"] = new Array ("CA","AP");
// FA, FZ, etc. Not FU ;).
caseTypes["Fs"] = new Array ("DA","DR");
caseTypes["Is"] = new Array ("CP","MH","GA","WO");
caseTypes["Js"] = new Array ("CJ","DP","DR");
caseTypes["Rs"] = new Array ("CC","SC");


function updateCaseTypes (courtdiv,div) {
	if (courtdiv.length > 1) {
		var target = courtdiv.substring(0,1);
		target = target + 's';
		var divs = caseTypes[target];
		var outstring = '';
		if (divs.length > 1) {
			outstring += '<select name="casetype" id="casetype" disabled="disabled"' +
				'onchange="document.getElementById(\'caseseq\').disabled=0;">\n' +
				'<option value="" selected="selected">Type</option>\n';
			$.each(divs,function() {
				var option = '<option value="' + this + '">' + this + '</option>\n';
				outstring += option;
			})
			outstring += '</select>'
		} else {
			outstring = divs[0];
		}
		document.getElementById(div).innerHTML = outstring;
	}
}

function getStyle (seq,year,casetype,courtdiv) {
	var casenum;
	var strlen = seq.length;
	if (strlen < 6) {
		// Pad sequence with leading zeroes if needed
		var pad = 6 - strlen;
		var prepend = '';
		for (var count = 1; count <= pad; count++) {
			prepend = prepend + '0';
		}
		seq = prepend + seq;
	}

	casenum = year + casetype + seq;
	var xmlhttp = doAjax("getCaseStyle.cgi",{ id : casenum, division : courtdiv });
		
	var xmlDoc = xmlhttp.responseXML;
	var status = $(xmlDoc).find('status').text();
	var response = $(xmlDoc).find('response').text();
	
	if (status == "Not Found") {
		document.getElementById('casestylesel').style.color = "red";
		document.getElementById('casestylesel').innerHTML = response;
		// Don't enable law firm without a valid case style
		document.getElementById('lf_name').disabled=1;
		return false;
	}
	
	document.getElementById('casestylesel').style.color = "black";
	document.getElementById('casestylesel').innerHTML = response;
	// Enable law orm and move focus to it
	document.getElementById('lf_name').disabled=0;
	document.getElementById('lf_name').focus();
	// Also add the hidden element to the form
	var form = document.forms['eventForm'];
	var el = document.createElement("input");
	el.type = "hidden";
	el.name = "casestyle";
	el.value = response;
	form.appendChild(el);

	return true;
}

function doAjax(script,querydata,async) {
    // Calls the JQuery Ajax 'post' method, and returns the xmlhttp object.
    // Default async to false
    async = typeof async !== 'undefined' ? async : false;
    
    $.ajaxSetup({async:async});
    var xmlhttp = $.post(script, querydata,
        function(data) {
        })
    .done(function() {})
    .fail(function() { alert ("Failure performing lookup");})
    .always(function() {});
    
    return xmlhttp;
}


function doLookup(str,div,script) {
    debugger;
    var xmlhttp = doAjax(script+".cgi",{ id : str });
    
    var xmlDoc = xmlhttp.responseText;
    document.getElementById(div).innerHTML = xmlDoc;
}

function showDays(div,month,year) {
	var thirties = new Array(4,6,9,11);
	
	var days = 31;
	if (month == 2) {
		// February.
		days = 28;
		if ((year % 4) == 0) {
			// It's divisible by 4.  Is it a century year?
			if ((year % 100) == 0) {
				// Yes, it's a century year.  Only a leap year if it's a millenium year.
				if ((year % 1000) == 0) {
					days = 29;
				}
			} else {
				days = 29;
			}
		}
	} else if ($.inArray(month,thirties) >= 0) {
		days = 30;
	} 
	
	//var string = '<select name="day" id="day" onchange="document.getElementById(\'starthour\').disabled=0;">';
	var string = '<select name="day" id="day" onchange="validateDate(' + year + ',' + month + ',this.value);">';
	string = string + '<option value="" selected="selected">Select Day</option>\n';
	for (var i = 1; i <= days; i = i+1) {
		var addition = '<option value="' + i + '">' + i + '</option>\n';
		string = string + addition;
	}
	string = string + '</select>';
	
	document.getElementById(div).innerHTML = string;
	
	return false;
}


function disableEnterKey(e) {
    var key;
    
    if(window.event) {
        key = window.event.keyCode;     //IE
    } else {
        key = e.which;     //firefox
    }
    
    if(key == 13) {
        return false;
    } else {
        return true;
    }
}

function validateDate (year, month, day) {
	if (day == undefined) {
		if (checkDate(year, month, undefined)) {
			showDays('daydiv',month,document.getElementById('year').value);
			return true;
		} else {
			document.getElementById('day').disabled = 1;
			return false;
		}
	} else {
		if (checkDate(year, month, day)) {
			document.getElementById('starthour').disabled = 0;
			return true;
		} else {
			document.getElementById('starthour').disabled = 1;
			return false;
		}
	}
	return true;
}

function checkDate (year, month, day) {
	var today = new Date();

	if (day != undefined) {
		// No sense continuing if the user selected a weekend day
		// Need to use "month-1" because the months are indexed from 0-11.
		var targetDate = new Date(year,month-1,day);
		var targetWeekDay = targetDate.getDay();
		if ((targetWeekDay==0) || (targetWeekDay==6)) {
			alert ("The selected date is on a weekend.");
			return false;
		} else {
			var weekdaydiv = document.getElementById('weekday');
			weekdaydiv.innerHTML = daysOfWeek[targetWeekDay];
		}
	}
	
	var thisMonth = today.getMonth() + 1;
	var thisYear = today.getFullYear();
	var thisDay = today.getDate();
	
	if (year <= thisYear) {
		if (month < thisMonth) {
			alert("You have selected a month that is in the past.");
			return false;
		} else {
			if ((month == thisMonth) && (day != undefined) && (day < thisDay)) {
				alert("You have selected a date that is in the past.");
				return false;
			}
		}
	}
	return true;
}


function checkTime (startHour,endHour,startMin,endMin) {
	if (endHour < startHour) {
		// Obvious - the ending hour is earlier than the starting hour
		alert ("You have selected an ending time that is before the starting time.");
		return false;
	} else {
		if ((endMin != undefined) && (startMin > endMin)) {
			if (endHour == startHour) {
				// Same hour, but the starting minute is after the ending minute
				alert ("You have selected an ending time that is before the starting time.");
				return false;
			}
		}
	}
	
	// It's all good.  Enable endmin (we must be to that point if we're in this routine)
	document.getElementById('endmin').disabled = 0;
	return true;
}


function setMonth () {
	document.getElementById('month').disabled=0;
	document.getElementById('month').value='';
	document.getElementById('day').disabled=1;
}

function validateForm (formname) {
	// Most of this validation has already been done, but this is a final check to ensure that
	// the user didn't change something out of order that would have made the previous validation
	// all hairy
	var form=document.forms[formname];
	
	var year = form.elements['year'].value;
	var month = form.elements['month'].value;
	var day = form.elements['day'].value;
	
	if (!validateDate(year,month,day)) {
		return false;
	}
	
	var starthour = form.elements['starthour'].value;
	var endhour = form.elements['endhour'].value;
	var startmin = form.elements['startmin'].value;
	var endmin = form.elements['endmin'].value;
	
	if (!checkTime(starthour, endhour, startmin, endmin)) {
		return false;
	}
	
	var caseStyle = form.elements['casestyle'].value;
	
	if (caseStyle == undefined) {
		alert ("No case style specified.  Please ensure that your entered case number is valid");
		return false;
	}
	
	// Trim leading and trailing whitespace from the law firm name
	var lawfirm = $.trim(form.elements['lf_name'].value);
	if (lawfirm == '') {
		alert ("No law firm name specified.");
		return false;
	}
	
	// Add the court division, which is not part of the form.
	var el = document.createElement("input");
	el.type = "hidden";
	el.name = "division";
	el.value = document.getElementById('division').value;
	form.appendChild(el);

	form.submit();
	return true;
}


function checkUniqueTime (formname) {
	// Check to see if there is already a haring scheduled for the specified time.  Still allow it
	// if there is, but alert the user.
	var form=document.forms[formname];
	
	var year = form.elements['year'].value;
	var month = form.elements['month'].value;
	var day = form.elements['day'].value;
	var starthour = form.elements['starthour'].value;
	var startmin = form.elements['startmin'].value;
	var endhour = form.elements['endhour'].value;
	var endmin = form.elements['endmin'].value;
	
	// This element is outside of the form.
	var courtdiv = document.getElementById('division').value;
	
	var date = year + '-' + month + '-' + day;
	var starttime = starthour + ':' + startmin + ':00';
	var endtime = endhour + ':' + endmin + ':00';
	
	// Don't consider it an error - allow the user to schedule multiple hearings in the same time
	// block, but let them know they're doing it.
	var xmlhttp = doAjax("checkDate.cgi",{ date: date, starttime: starttime, endtime: endtime, division: courtdiv });
	
	var existCount = xmlhttp.responseText;
	
	if (existCount > 0) {
		var word = (existCount == 1) ? 'hearing' : 'hearings';
		alert ("NOTE: You already have " + existCount + " " + word + " scheduled in this time block.");
	}
	
	return true;
}