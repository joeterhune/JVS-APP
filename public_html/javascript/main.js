function popup(x,y) {
    var wx=screen.width
    wx=wx-450;
    MyWindow=window.open('/'+x,y,'toolbar=no,location=no,directories=no,status=no,menubar=no,scrollbars=yes,resizable=yes,width=500,top=0,left='+wx);
    return false;
}

function loadcty() {
	var theform=document.forms['mainSearchForm'];
    var x=theform.countyxx.options[theform.countyxx.selectedIndex].value;
    window.location=x+"/index.php";
    return false;
}

function gojudge() {
	var theform=document.forms['mainSearchForm'];
    var x;
    x=theform.judgexx.options[theform.judgexx.selectedIndex].value;
    window.location="/cgi-bin/judgepage.cgi?num="+x
    return false;
}

function gojudge2() {
	var theform=document.forms['mainSearchForm'];
    var x;
	x=theform.judgexy.options[theform.judgexy.selectedIndex].value;
    window.location="/gensumm.php?rpath=case/Sarasota/crim/div"+x+"/index.txt"
    return false;
}

function gojudge3() {
	var theform=document.forms['mainSearchForm'];
    var x;
	x=theform.judgexy.options[theform.judgexy.selectedIndex].value;
    window.location="/judge.php?val="+x;
    return false;
}

function gomag() {
	var theform=document.forms['mainSearchForm'];
    var x=theform.magistratexy.options[theform.magistratexy.selectedIndex].value;
    window.location="/mag.php?val="+x;
    return false;
}

function godiv(type) {
	var theform=document.forms['mainSearchForm'];
	var x = $("select[name=divxy_" + type + "] option:selected").val();
    var arr=x.split("~");
    window.location="/gensumm.php?rpath=/Sarasota/"+arr[1]+"/div"+arr[0]+"/index.txt&divName=" + arr[0];
    return false;
}

function go_civ_traffic() {
	/*var theform=document.forms['mainSearchForm'];
	var x = $("select[name=divxy_" + type + "] option:selected").val();
    var arr=x.split("~");
    window.location="/gensumm.php?rpath=/Sarasota/"+arr[1]+"/div"+arr[0]+"/index.txt&divName=" + arr[0];
    return false;*/
	window.location="/cgi-bin/calendars/trafficDocket.cgi";
    return false;
}

function goflag() {
	var theform=document.forms['mainSearchForm'];
    var x=theform.flagxy.options[theform.flagxy.selectedIndex].value;
    var arr=x.split("~");
    window.location="/gensumm.php?rpath=case/Sarasota/flags/"+arr[0]+
	"/index.txt&older=no";
    return false;
}

function showDialog (header,text) {
    $('#dialogSpan').html(text);
    $('#dialogDiv').dialog({
        resizable: false,
        minheight: 150,
        width: 500,
        modal: true,
        title: header,
        buttons: {
            "OK": function() {
                $(this).dialog( "close" );
                return false;
            }
        }
    });
}

$(document).ready(function () {
	$(document).on('click','.listCheck',function() {
        //debugger;
        var targetClass = $(this).attr('data-targetClass');
        var checkProp = parseInt($(this).attr('data-checkProp'));
        $(this).parent().find('.' + targetClass).prop('checked',checkProp);
        return true;
    });
});


// GetTimeStamp returns a current timestamp as a string...
function GetTimeStamp() {
    var t=new Date();
    var hour=t.getHours();
    var min=t.getMinutes().toString();
    if (min.length==1) {
        min='0' + min;
    }
    var sec=t.getSeconds().toString();
    if (sec.length==1) {
        sec='0' + sec;
    }
    var mon=t.getMonth()+1;
    var day=t.getDate();
    var year=t.getFullYear();
    var ampm=' AM';
    if (hour>=12) {
        ampm=' PM'
    };
    if (hour>12) {
        hour-=12;
    }
    return(mon+'/'+day+'/'+year+' '+hour+':'+min+':'+sec+ampm)
}

function isIE () {
    if((navigator.appName.indexOf("Internet Explorer")!=-1) || (navigator.userAgent.indexOf("Trident") != -1)) {
        return 1;
    } else {
        return 0;
    }
}

function setAutoSave(form) {
    if (isIE()) {
        window.external.AutoCompleteSaveForm(form);
    }
}


