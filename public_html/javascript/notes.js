//
// notes.js - JavaScript routines for casenotes
//

function GetFormattedDate(date) {
    var year = date.getFullYear();
    var month = (1 + date.getMonth()).toString();
    month = month.length > 1 ? month : '0' + month;
    var day = date.getDate().toString();
    day = day.length > 1 ? day : '0' + day;
    return month + '/' + day + '/' + year;
}


// DeleteNote removes an icms 2.5 note

function DeleteNote(e) {
   var tr=$(this).closest('tr');
   var entry=$(this).closest('td').prev('td').html();
   var ucn='';
   if (e.data.fromnotes) { // get ucn
       ucn=$(this).closest('tr').find('td').eq(1).html();
   } 
   $(tr).remove();
   $.post('notes/deletenote.php?seq='+entry); 
   // AND reload the notes tab...
   if (e.data.fromnotes) { // from the Notes page...
       $(".ui-tabs-anchor").each(function (index) {
           var x=$(this).html();
           if (x.indexOf(ucn)!=-1) {
               $(this).load($(this).attr("href"));
	   }
       });
   } else {
      var t=new Date().getTime();
      $("#Notes").load("notes/index.php?t="+t);
   }

}


// ShowNoteDialog shows the note add dialog box.

var NT_TABLE; // set by ShowNoteDialog, used by NoteFinishAdd


var NT_DIALOG; //  needed for IE9

function ShowNoteDialog(ntseq,ucn,docref,cvc) {
    NT_DIALOG=$("#nt_add_dialog").dialog({
        width:650,
        height:450,
        bgiframe:true,
        open: function(event){
            $(this).parents(".ui-dialog").first().shim();
        },
        close: function(event){
            $(this).dialog("close");
            $(this).parents(".ui-dialog").first().shim('close');
        },
        resize: function(event){
            $(this).parents(".ui-dialog").first().shim('resize');
        },
        drag: function(event){
            $(this).parents(".ui-dialog").first().shim('resize');
        }
    });
    NT_TABLE=$("#notetable-"+cvc); // $(event.target).closest('table');
    if (ntseq!='') { // this is an EDIT...
        alert('edit not yet supported!');
    } else {
        // setting hidden fields doesn't seem to work with #id notation...
        $("input[name=nt_seq]").val(ntseq);
        $("#nt_casenum_display").html(ucn);
        $("input[name=nt_casenum]").val(ucn);
        $("input[name=nt_docref]").val(docref);
        if (docref!='') {
           $("#nt_file_row").hide();
	} else {
            $("#nt_file_row").show();
	}
        $("#nt_private").removeAttr('checked');
        $("#nt_note").val('');
        $("input[name=nt_file]").val('');
    }
}


// a la WorkFlowFinishAdd, this is called after the item has been added

function NoteFinishAdd(data) {
    var seq=data;
    seq=seq.replace("\n","");
    $("#nt_add_dialog").dialog("close");
     var today=GetFormattedDate(new Date());
    var note=$("#nt_note").val();
    var isprivate=$("#nt_private").is(":checked");
    var bgcolor='';
    if (isprivate) { bgcolor="#F9A7B0"; }
    else { bgcolor="yellow"; }
    var file=$("#nt_file").val();
    var notesuff='';
    if (file!="") { 
       notesuff+=" <image src=icons/document.png onClick=NotesShowAttach("+seq+");>";
    }
    $(NT_TABLE).find("tbody").prepend("<tr><td>"+today+"</td><td>"+USER+"</td><td style='background-color:"+bgcolor+"'>"+note+"</td><td>"+notesuff+"</td><td style=display:none>"+seq+"<td><span class='ui-icon ui-icon-close noteclose' style='display:inline-block; cursor:pointer'></span></td></tr>");
   // enabling delete note on that liney
    var x=$(NT_TABLE).find("tbody tr:first .noteclose").click({fromnotes:0},DeleteNote);
   // AND reload the notes tab...
    var t=new Date().getTime();
    $("#Notes").load("notes/index.php?t="+t);
}


// NotesShow1Attachs pops up a window, handing off the filling to notes/showattach.php

function NotesShowAttach(seq) {
    PopUpURL("notes/showattach.php?seq="+seq,"Attachment");
}

// NotesShowAttachs pops up a window, handing off the filling to notes/showattach.php

function NotesShowDocRef(docref) {
    PopUpURL("notes/showdocref.php?docref="+docref,"Document");
}


// HandleAddFlag is invoked by the Add button on a case view screen. 
// It posts the flag to add and updates the Flags tables for that case.

function HandleAddFlag(ucn,cvc) {
// IE10 issues with event.target closet here...
//    var x=$(event.target).closest(":input").prev(":input").find('option:selected');
    var x=$('#flagchoice-'+cvc).find('option:selected');
    var t=$("#flags-"+cvc);
//    var t=$(event.target).closest("table");
    var val=$(x).val();
    var txt=$(x).text();
    if (txt=='') { return; } // no point adding a blank flag...
    $.post('notes/addflag.php?flagtype='+val+'&ucn='+ucn,function (data) {
        var resp=data.split(',');
        var today=GetFormattedDate(new Date());
        $(t).find("tbody").prepend("<tr><td>"+today+"</td><td>"+USER+"</td><td><div class=wfcircle style='background:"+resp[1]+"'></div></td><td>"+txt+"</td><td style=display:none>"+resp[0]+"<td><span class='ui-icon ui-icon-close flagclose' style='display:inline-block; cursor:pointer'></span></td></tr>");        
        // enabling delete note on that liney
        $(t).find("tbody tr:first .flagclose").click({from:"view"},DeleteFlag);
    }); 
   // AND reload the notes tab...
    var t2=new Date().getTime();
    $("#Notes").load("notes/index.php?t="+t2);
}


// DeleteFlag removes a case flag

function DeleteFlag(e) {
   var tr=$(this).closest('tr');
   var entry=$(this).closest('td').prev('td').html();
   var ucn='';
   if (e.data.from=="view") { // get ucn
       ucn=$(this).closest('tr').find('td').eq(1).html();
   } 
   $(tr).remove();
   $.post('notes/deleteflag.php?id='+entry); 
   // AND reload the notes tab...
   if (e.data.from=="notes") { // from the Notes page...
       $(".ui-tabs-anchor").each(function (index) {
           var x=$(this).html();
           if (x.indexOf(ucn)!=-1) {
               $(this).load($(this).attr("href"));
	   }
       });
   } else {
      var t=new Date().getTime();
      $("#Notes").load("notes/index.php?t="+t);
   }

}
