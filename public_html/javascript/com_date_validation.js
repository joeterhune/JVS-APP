//
// Javascript function validating a date - date must be in the format mm/dd/yyyy
//
// This code was found on:  http://www.redips.net/javascript/date-validation/
// All code from www.redips.net is provided free of charge under a liberal BSD license.
//
//Copyright (c) 2009, www.redips.net
//All rights reserved.
//
//Redistribution and use in source and binary forms, with or without modification, 
//are permitted provided that the following conditions are met:
//
//Redistributions of source code must retain the above copyright notice, this list of 
//conditions and the following disclaimer. 
//Redistributions in binary form must reproduce the above copyright notice, this list 
//of conditions and the following disclaimer in the documentation and/or other materials 
//provided with the distribution.
//
//THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY 
//EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES 
//OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT 
//SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
//SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT 
//OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
//HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
//OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
//SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


// check date JavaScript function   
// if date is valid then function returns true, otherwise returns false   
function isDate(txtDate){   
  var objDate;  // date object initialized from the txtDate string   
  var mSeconds; // milliseconds from txtDate   
  
  // date length should be 10 characters - no more, no less   
  if (txtDate.length != 10) return false;   
  
  // extract day, month and year from the txtDate string   
  // expected format is mm/dd/yyyy   
  // subtraction will cast variables to integer implicitly   
  var day   = txtDate.substring(3,5)  - 0;   
  var month = txtDate.substring(0,2)  - 1; // because months in JS start with 0   
  var year  = txtDate.substring(6,10) - 0;   
  
  // third and sixth character should be /   
  if (txtDate.substring(2,3) != '/') return false;   
  if (txtDate.substring(5,6) != '/') return false;   
  
  // test year range   
  if (year < 999 || year > 3000) return false;   
  
  // convert txtDate to the milliseconds   
  mSeconds = (new Date(year, month, day)).getTime();   
  
  // set the date object from milliseconds   
  objDate = new Date();   
  objDate.setTime(mSeconds);   
  
  // if there exists difference then date isn't valid   
  if (objDate.getFullYear() != year)  return false;   
  if (objDate.getMonth()    != month) return false;   
  if (objDate.getDate()     != day)   return false;   
  
  // otherwise return true   
  return true;   
}  
