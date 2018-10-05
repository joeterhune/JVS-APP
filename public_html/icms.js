function GetCookie(x) {
    if (document.cookie) {
        var index=document.cookie.indexOf(x);
        if (index!=-1) {
            var pg = new RegExp("",'g');
            var oldpg=new RegExp("",'g');
            var countbegin=document.cookie.indexOf("=",index)+1;
            var countend=document.cookie.indexOf(";",index);
            if (countend==-1) {
                countend=document.cookie.length;
            }
            pg=document.cookie.substring(countbegin,countend);
            return unescape(pg);
        }
    }
    return "";
}


// SetBack sets the specified cookie to the current page

function SetBack(x) {
    // first, kill the old cookie, if any
    var oldcookie=GetCookie(x);
    if (oldcookie!="") {
        document.cookie=x+"="+oldcookie+"; path=/; expires='Fri, 13-Apr-1970 00:00:00 GMT'";
    }
    var curCookie=x+"="+escape(location.href)+"; path=/";
    document.cookie=curCookie;
}


// GoBack changes the current page to one set in a specified Cookie

function GoBack(x) {
    var cookie=GetCookie(x);
    cookie=unescape(cookie);
    document.location=cookie;
}



function PopUp(path,title,len) {
    var wx=screen.width;
    wx = wx-450;
    MyWindow=window.open(path,title,'toolbar=no,location=no,directories=no,status=no,menubar=no,scrollbars=yes,resizable=no,width=440,top=0,left='+wx);
    return false;
}

function checkAll(field) {
    for (i = 0; i < field.length; i++) {
        field[i].checked = true ;
    }
}

function unCheckAll(field) {
    for (i = 0; i < field.length; i++) {
        field[i].checked = false ;
    }
}


function toggleOpposite(checkboxID, toggleID) {
    var checkbox = document.getElementById(checkboxID);
    var toggle = document.getElementById(toggleID);
    updateToggle = checkbox.checked ? toggle.disabled=true : toggle.disabled=false;
    if (toggle.disabled == false) {
        document.getElementById(toggleID).focus();
        //document.getElementById(toggleID).value="";
    }
}

function open_win(url,windowname,height,width) {
    if (height == undefined) {
        height = 800;
    }
    if (width == undefined) {
        width = 1250;
    }
    window.open(url,windowname,"location=0,status=1,scrollbars=1,resizable=1,height="+height+", width="+width);
}
