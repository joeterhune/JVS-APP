// settings.js - used by /var/www/icms/settings/index.cgi

function checkall(event) {
    // Toggles all of the checkboxes in the <tr> to match the "all" box.
    $(this).parentsUntil('tbody').find('input[type=checkbox]').prop('checked',$(this).prop('checked'));
}


function SettingsUpdateTabs() {
    // Update these tabs, since settings change can affect them
    var t=(new Date()).getTime();
    $("#Reports").load('reports/tab.php?t='+t);
    if (HASWORKQUEUE) {
        $("#Workflow").load('workflow/wfshow.php?t='+t);
    }
    // $("#CalendarTab").load("calendar/calview.cgi?t="+t);
    
    //$('#calendar').fullCalendar('refetchEvents');
    window.location.href="/settings/index.cgi";
}



function SaveSettings() {
    // look thru all the divs...see what is checked..
    var calendars;
    var reports;
    var queues;;
    var alerts;
    var cals = new Array();
    var rpts = new Array();
    var ques = new Array();
    var alrts = new Array();
    $(".allck").each(function(index,obj) {
        var div = $(this).siblings('.subDiv').val();
        if ($('#cal'+div).prop('checked')) {
            cals.push(div);
        }
        if ($('#rpt'+div).prop('checked')) {
            rpts.push(div);
        }
        if ($('#que'+div).prop('checked')) {
            queues+=div+',';
            ques.push(div);
        }
        if ($('#alrt'+div).prop('checked')) {
            alrts.push(div);
        }
    });
    
    calendars = cals.join(",");
    reports = rpts.join(",");
    queues = ques.join(",");
    alerts = alrts.join(",");

    var shared_with=$("#shared_with").val();
    var priv_notes_shared_with=$('#priv_notes_shared_with').val();
    var transfer_to=$('#transfer_to').val();
    var email=$('#email').val();
    var opt_cal_dragdrop = 0;
    if ($('#opt_cal_dragdrop').attr('checked')) {
        opt_cal_dragdrop = 1;
    }
    var docviewer = $("#docviewer").val();
    var pdf_toolbar = $("#pdf_toolbar").val();
    var pdf_scrollbar = $("#pdf_scrollbar").val();
    var pdf_statusbar = $("#pdf_statusbar").val();
    var pdf_navpanes = $("#pdf_navpanes").val();
    var pdf_view = $("#pdf_view").val();
    var pdf_viewer = $("#pdf_viewer").val();
    var pdf_zoom = $("#pdf_zoom").val();

    if(pdf_view != "Zoom"){
        pdf_zoom = "";
    } else if(pdf_zoom == ""){
        pdf_zoom = "100";
    }
    
    $.post("/settings/savesettings.cgi", {
        calendars:          calendars,
        reports:             reports,
        queues:              queues,
        alerts:              alerts,
        email:               email,
        opt_cal_dragdrop:    opt_cal_dragdrop,
        docviewer:          docviewer,
        pdf_toolbar:     pdf_toolbar,
        pdf_scrollbar:   pdf_scrollbar,
        pdf_statusbar:   pdf_statusbar,
        pdf_navpanes:    pdf_navpanes,
        pdf_view:        pdf_view,
        pdf_viewer:        pdf_viewer,
        pdf_zoom:        pdf_zoom,
        shared_with:     shared_with,
        priv_notes_shared_with: priv_notes_shared_with,
        transfer_to: 	transfer_to
    }).done(function(){
        // Refresh settings
        LoadSettings();
    });
}


// WorkFlowNewDivAdd adds a division to the list of subscriptions for Workflow

function SettingsNewDivAdd() {
    var newdiv=$('#newDivSel option:selected').val();
    if (newdiv == "") {
        alert("You must select a division to add.");
        return false;
    }
    $.ajax({
        url: "/settings/newdiv.cgi",
        data: {div: newdiv },
        async: true,
        success: SettingsUpdateTabs
    });
    return true;
    //var t=(new Date()).getTime();
}

function SettingsDivRemove() {
    var newdiv=$('#stnewdiv option:selected').val();
    $.post("/icms/settings/removediv.cgi",{ div: newdiv },SettingUpdateTabs);
    var t=(new Date()).getTime();
    $("#Settings").load('/icms/settings/index.cgi?t='+t);
}

function UpdatePDFOptions(){
  if($("#pdf_viewer").val() == "pdfjs"){
    $(".acrobat-opt").hide();
  } else {
    $(".acrobat-opt").show();
  }

  if($("#pdf_view").val() == "Zoom"){
    if($("#pdf_zoom").val() == ""){
      $("#pdf_zoom").val("100");
    }

    $("#opt_zoom").show();
  } else {
    $("#opt_zoom").hide();
  }
}