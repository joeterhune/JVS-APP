// JavaScript Date Functions - com_dateValidationsFunctions.js


// -----------------------------------------------------------------------------------------
// these are more date validation type functions - work on html objects
// -----------------------------------------------------------------------------------------

// validate a date
//
// Pass the name of the html elements to process 
// and text that describes what's being validate.
// Reports problems to the user.
// 
// returns date in 'mm/dd/yyyy' string if all ok.  
// else false.
function validateDay(month,day,year,what){
	// make sure month is there
	var m = document.getElementById(month);		
	if(m.value == "") {
		alert("A month must be selected for " + what + ".");
		m.focus();
		return false;
	}
	var d = document.getElementById(day);
	var y = document.getElementById(year);
	var mm = m.value;
	if (mm.length == 1) mm = "0" + mm;
	var dd = d.value;
	if (dd.length == 1) dd = "0" + dd;
	var year = y.value;
	var FD = mm + "/" + dd + "/" + year;
	// validate the whole date
	if(!isDate(FD)) {
		alert("The date in " + what + " is not a valid date.");
		m.focus();
		return false;
	}
	return FD;
}


// validate a date range
//
// pass name of html elements to process 
//
// reports problems to the user
//
// returns string of valid date range in format of mm/dd/yyyy - mm/dd/yyyy if all ok.  
// else false.
function validateDateRange(sMonth,sDay,sYear,eMonth,eDay,eYear,what){
	// validate date range 1 
	// make sure month is there
	var sM = document.getElementById(sMonth);		
	if(sM.value == "") {
		alert("A starting month must be selected for " + what + ".");
		sM.focus();
		return false;
	}
	var sD = document.getElementById(sDay);
	var sY = document.getElementById(sYear);
	var mm = sM.value;
	if (mm.length == 1) mm = "0" + mm;
	var dd = sD.value;
	if (dd.length == 1) dd = "0" + dd;
	var year = sY.value;
	var sFD = mm + "/" + dd + "/" + year;
	// validate the whole date
	if(!isDate(sFD)) {
		alert("The starting date in " + what + " is not a valid date.");
		sM.focus();
		return false;
	}
	// 1st date in range is valid, try next
	var eM = document.getElementById(eMonth);		
	if(eM.value == "") {
		alert("An ending month must be selected for " + what + ".");
		eM.focus();			
		return false;
	}	
	var eD = document.getElementById(eDay);
	var eY = document.getElementById(eYear);				
	mm = eM.value;
	if (mm.length == 1) mm = "0" + mm;
	dd = eD.value;
	if (dd.length == 1) dd = "0" + dd;
	year = eY.value;
	var eFD = mm + "/" + dd + "/" + year;
	// validate the whole date
	if(!isDate(eFD)) {
		alert("The ending date in " + what + " is not a valid date.");
		eM.focus();
		return false;
	}
	// so far so good.  make sure the ending date falls on or after the starting date
	if(!compareDates(sFD,eFD)) {
		alert("The ending date in " + what + " must be the same or past the starting date.");
		eM.focus();
		return false;
	}
	return (sFD + " - " + eFD);
}

