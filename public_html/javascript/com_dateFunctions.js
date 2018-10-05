// JavaScript Date Functions - com_dateFunctions.js

// Javascript function comparing two dates - dates must be in the format mm/dd/yyyy
//
// comparing that the 1st date is less than or equal to the 2nd date
//
// returns true if 1st date <= 2nd date 

function compareDates(str1,str2) 
{ 
    //alert("str1: " + str1 + ", str2: " + str2);
    var mon1 = parseInt(str1.substring(0,2),10); 
    var dt1  = parseInt(str1.substring(3,5),10); 
    var yr1  = parseInt(str1.substring(6),10); 
    var mon2  = parseInt(str2.substring(0,2),10); 
    var dt2 = parseInt(str2.substring(3,5),10); 
    var yr2  = parseInt(str2.substring(6),10); 
    var date1 = new Date(yr1, mon1-1, dt1); 
    var date2 = new Date(yr2, mon2-1, dt2); 
	//alert("comparing " + date1 +  " to " + date2);
    if(date2 < date1) return false;
    else return true;    
} 

// Javascript function comparing two dates - dates must be in the format mm/dd/yyyy
//
// comparing that the dates are equal
//
// returns true if equal, otherwise false.

function compareDatesEqual(str1,str2) 
{ 
    var mon1 = parseInt(str1.substring(0,2),10); 
    var dt1  = parseInt(str1.substring(3,5),10); 
    var yr1  = parseInt(str1.substring(6),10); 
    var mon2  = parseInt(str2.substring(0,2),10); 
    var dt2 = parseInt(str2.substring(3,5),10); 
    var yr2  = parseInt(str2.substring(6),10); 
    var date1 = new Date(yr1, mon1-1, dt1); 
    var date2 = new Date(yr2, mon2-1, dt2); 
	// just comparing for == doesn't work
    if(date1 > date2 || date1 < date2) return false; 
    else return true;    
} 

// Javascript date function - dates must be in the format mm/dd/yyyy
//
// check if a date is within a date range, inclusive.
//
// returns true if within the range, otherwise false.

function withinDateRange(date1,drbeg,drend) 
{ 
   return (compareDates(drbeg,date1) && compareDates(date1,drend));
} 


// get the day of week from a date that's in the format of mm/dd/yyyy
//
// returns a number between 0 and 6. Sunday is 0, Monday is 1, etc...
function getDOW(str){
    var m= parseInt(str.substring(0,2),10); 
    var d  = parseInt(str.substring(3,5),10); 
    var y  = parseInt(str.substring(6),10); 
	var date = new Date(y, m-1, d);
	return date.getDay();
}

// get the short string form of the day of the week - pass the day number
function getShortDay(d){
	var daysOfWeek = ["Sun", "Mon", "Tues", "Wed", "Thurs", "Fri", "Sat"];
	return daysOfWeek[d];	
}

// get the long string form of the day of the week - pass the day number
function getLongDay(d){
	var daysOfWeek = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
	return daysOfWeek[d];	
}


// return today's date as mm/dd/yyyy string
function getToday(){
	var t = new Date();
	var m = (t.getMonth()+1).toString();
	if(m.length == 1) m = "0" + m;
	var d = (t.getDate()).toString();
	if(d.length == 1) d = "0" + d;
	var y = (t.getFullYear()).toString();
	return m + "/" + d + "/" + y;	
}


// add a number of months to a date string that's in the format of mm/dd/yyyy
//
// returns a mm/dd/yyyy string that is the passed date plus months months.
function addMonthsToDate(months,str){
    var mon = parseInt(str.substring(0,2),10); 
    var dt  = parseInt(str.substring(3,5),10); 
    var yr  = parseInt(str.substring(6),10); 
    var date = new Date(yr, (mon-1) + parseInt(months), dt); 
	var m = date.getMonth()+1;
	if(m < 10) m = "0" + m;
	var d = date.getDate();
	if(d < 10) d = "0" + d;
	var y = date.getFullYear();
	return m + "/" + d + "/" + y;	
}

// add a number of days to a date string that's in the format of mm/dd/yyyy
//
// returns a mm/dd/yyyy string that is the passed date plus days days.
function addDaysToDate(days,str){
    var mon = parseInt(str.substring(0,2),10); 
    var dt  = parseInt(str.substring(3,5),10); 
    var yr  = parseInt(str.substring(6),10); 
    var date = new Date(yr, (mon-1), dt + parseInt(days)); 
	var m = date.getMonth()+1;
	if(m < 10) m = "0" + m;
	var d = date.getDate();
	if(d < 10) d = "0" + d;
	var y = date.getFullYear();
	return m + "/" + d + "/" + y;	
}

// get the number of days in a specific month/year combination
// d is date object with a year and month specified, day set to zero.
// month should be 0 based (i.e. jan is 0, etc...)
function getDaysInMonth(y, m){
   return new Date(y, m+1, 0).getDate()
}

// generate a date array using a date range, inclusive
//
// start and end dates are in the format of mm/dd/yyyy.
//
// assumes all dates are valid.
//
// returns an array of dates that fall within the range, inclusive.
function generateDatesArray(start, end){
	var dates = new Array();
	var i = 0;
	var thisd = start;;
	while (compareDates(thisd,end) == true) {
		dates[i] = thisd;
		thisd = addDaysToDate(1, thisd);
		i++;
	}
	// show dates
	//var sdates="";
	//for(var i=0; i < dates.length; i++){
	//	sdates = sdates + dates[i] + " ";
	//}
	//alert("generated " + dates.length + " dates: " + sdates);
	return dates;
}


// check if all the dates in an array are unique
//
// dates must be in the format of mm/dd/yyyy - not checked
// 
// returns 0 if all unique
// else returns index position of the 1st same date
function checkUniqueDates(dA){
	var flag = 0;
	for(var d = 0; d < dA.length; d++) {
		for(var n = d + 1; n < dA.length; n++) {
			// compare two dates.  if same, set flag and leave.
			if(compareDatesEqual(dA[d],dA[n])){
			   flag = n;
			   break;
			}
		}
		if(flag > 0) break;
	}
	return flag;
}

// pass mm/dd/yyyy string, return yyyy-mm-dd string
// 
// must be exact format to work and there's no testing!
function convertToSQLDate(mmddyyyy) {
	return mmddyyyy.substring(6,10) + "-" + mmddyyyy.substring(0,2) + "-" + mmddyyyy.substring(3,5);
}
