// shared.js -- functions for handling sharing things with other users
// used by editformsettings.js, settings/index.cgi
// requires global "users" array set up externally

function FixSharedList() {
     // now fix the sharedlist (visible list)
     // to match shared_with...in case it's wrong
    var str='';
    var sty='<span style="background-color:lightgrey;padding: 0px 4px 0px 4px">';
    var x=$("#shared_with").val().split(',');
    for (i=0;i<x.length;i++) {
        for (j=0;j<users.length;j++) {
            if (users[j].userid==x[i]) {
                if (str!="") {
                    str+=" "+sty+users[j].fullname+'</span>';
                } else {
                    str=sty+users[j].fullname+'</span>';
                }
            }
        }
    }
    $("#sharedlist").html(str);
}

function AddUserToShared() {
    var newval=$("#sharedselect").val();
    if (newval=='') { return; }
    var x=$("#shared_with").val();
    if (x!="") {
	if (x.search(newval)==-1) { // keeps you from adding twice
            x+=","+newval;
	}
    } else {
	x=newval;
    }
    $("#shared_with").val(x);
    FixSharedList();
}


function DelUserFromShared() {
    var todelete=$("#sharedselect").val();
    if (todelete=='') { return; }
    var x=$("#shared_with").val();
    var xarr=x.split(',');
    var str='';
    for (i=0;i<xarr.length;i++) {
	if (xarr[i]!=todelete) {
            if (str!="") {
		str+=","+xarr[i];
            } else {
		str=xarr[i];
            }
	}
    }
    $("#shared_with").val(str);
    FixSharedList();
}

