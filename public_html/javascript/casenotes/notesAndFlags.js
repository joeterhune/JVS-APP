// $Id: notesAndFlags.js 2241 2015-09-04 18:34:04Z rhaney $

$(document).ready(function () {
    $(document).on('click','.notesAttach',function(e) {
        e.preventDefault;
        
        var noteid = $(this).data('noteid');
		
        var postData = {};
        
        var pane;
        var ucn;
        var url = "/casenotes/displayAttachment.php";
        if (noteid != undefined) {
            noteid = noteid;
            filename = $(this).data('filename');
            pane = $(this).closest('.caseTab');
            ucn = $(pane).find('.ucn').val();
            url += "?noteid=" + noteid + "&filename=" + filename;
        } else {
            ucn = $(this).data('casenum');
            docid = $(this).data('docid');
            // No noteid?  Came from a workflow link.
            docid = docid;
            casenum = ucn;
            noteid = docid;
            url += "?docid=" + docid + "&casenum=" + casenum;
        }
        
        window.open(url);        
        return false;
    })
    
    
    $(document).on('click','.addFlag', function() {
        var pane = $(this).closest('.caseTab');
        // Create a click event on the add button
        var addBtn = $(pane).find('.flagsnotes').first();
        $(addBtn).trigger('click');
        
        return true;
    });
    
    $(document).on('click','.delFlag', function() {
        var flagID = $(this).data('flagid');
        var flagDesc = $(this).closest('tr.caseflag').find('.flagDesc').text();
        var ucn = $(this).data('ucn');
        
        $('#dialogSpan').html('Are you sure you wish to delete the flag "' + flagDesc + '"?');
        $('#dialogDiv').dialog({
            resizable: false,
            minheight: 150,
            width: 500,
            modal: true,
            title: 'Delete Flag',
            buttons: {
                "Yes": function() {
                    $(this).dialog( "close" );
                    $.ajax({
                        url: "/casenotes/delFlag.php",
                        data: {flagid : flagID},
                        async: false,
                        success: function(data) {
                            getFlags(ucn);
                            return true;
                        }
                    });
                    
                    return true;
                },
                "No": function () {
                    $(this).dialog( "close" );
                    return false;
                }
            }
        });
    });
    
    $(document).on('click','.delNote', function() {
        var noteID = $(this).data('noteid');
        var noteDesc = $(this).closest('tr.casenote').find('.noteDesc').text();
        var ucn = $(this).data('ucn');
        
        $('#dialogSpan').html('<p>Are you sure you wish to delete this note?</p><p style="font-style: italic">' + noteDesc + '</p>');
        $('#dialogDiv').dialog({
            resizable: false,
            minheight: 150,
            width: 500,
            modal: true,
            title: 'Delete Flag',
            buttons: {
                "Yes": function() {
                    $(this).dialog( "close" );
                    $.ajax({
                        url: "/casenotes/delNote.php",
                        data: {noteid : noteID},
                        async: false,
                        success: function(data) {
                            getNotes(ucn);
                            return true;
                        }
                    });
                    
                    return true;
                },
                "No": function () {
                    $(this).dialog( "close" );
                    return false;
                }
            }
        });
    });
    
    
    $(document).on('click','.flagsnotes',function () {
        var pane = $(this).closest('.caseTab');
        var div = $(pane).find('.division').val();
        var ucn = $(pane).find('.ucn').val();
        
        var url = '/casenotes/index.cgi';
        var tabName = ucn + "_notesflags";
        var tabTitle = "Flags and Notes";
        
        createTab(tabName,tabTitle,$(pane).attr('id'),'innerPane');
        
        var postData = {div: div, ucn: ucn, tab: tabName, show: 1};
        $.ajax({
            url: url,
            data: postData,
            async: false,
            success: showTab
        });
    });
    
    $(document).on('click','a.flagnotelink', function() {
        var pane = $(this).closest('.caseTab');
        var ucn = $(pane).find('.ucn').val();
        var div = $(pane).find('.division').val();
        var caseType = $(pane).find('.caseType').val();
        var type = $(this).data('type');
        var url = $(this).data('url');
        var tabTitle = $(this).data('title');
        var tabName = $(pane).attr('id') + type;
        
        var postData = {ucn: ucn, caseType: caseType, div: div, tab: tabName, show: 1};
        
        $.ajax({
            url: url,
            data: postData,
            async: false,
            success: function(data) {
                var targetDiv = $(pane).find('.flagNotesOperation')
                $(targetDiv).html(data.html);
                $(targetDiv).show();
            }
        });
        
        return true;
    });
    
    // Handle the submission of new notes.
    $(document).on('click','.noteSubmit',function() {
        $(".theform").submit();
        return false;
    });
    
    
    // Handle the submission of new flags
    $(document).on('click','.flagSubmit',function () {
        var pane = $(this).closest('.theform');
        var checkCount = $(pane).find(".flagCheck:checked").length;
        var dis = $(pane).find(".flagCheck:disabled").length;
        
        if ((checkCount - dis) == 0) {
            $('#dialogSpan').html("Please select new flags to be created.");
            $('#dialogDiv').dialog({
                resizable: false,
                minheight: 150,
                width: 500,
                modal: true,
                title: 'No new flags selected',
                buttons: {
                    "OK": function() {
                        $(this).dialog( "close" );
                        return false;
                    }
                }
            });
            return false;
        }

        // Ok, there are new flags.  Are there expiration dates?
        var exptype = $(pane).find('input[name=exptype]:radio:checked').val();
        switch(exptype) {
            case 'never':
                break;
            case 'xtime':
                var timecount = $(pane).find('.timecount').val();
                var timetype = $(pane).find('select[name=timetype]').val();
                if ((timecount == '') || (timetype == '')) {
                    $('#dialogSpan').html("Please select a number of days, weeks, or months for the expiration.");
                    $('#dialogDiv').dialog({
                        resizable: false,
                        minheight: 150,
                        width: 500,
                        modal: true,
                        title: 'No range entered',
                        buttons: {
                            "OK": function() {
                                $(this).dialog( "close" );
                                return false;
                            }
                        }
                    });
                    return false;
                }
                break;
            case 'ondate':
                var expdate = $(pane).find('.localexpdate').val();
                if (expdate == '') {
                    $('#dialogSpan').html("Please select an expiration date for the selected flags.");
                    $('#dialogDiv').dialog({
                        resizable: false,
                        minheight: 150,
                        width: 500,
                        modal: true,
                        title: 'No date selected',
                        buttons: {
                            "OK": function() {
                                $(this).dialog( "close" );
                                return false;
                            }
                        }
                    });
                }
                break;
        }

        $(pane).submit();
        
    });
    
    $(document).on('click','.showHiddenFlagTypes',function () {
        var pane = $(this).closest('.theform');
        $(pane).find('.hideflag').toggle();
        return false;
    });
    
    
    $(document).on('focus','.expval',function () {
        $(this).parent().find('.expradio').attr('checked','checked');
    });
})



function getFlags (ucn) {
    $.ajax({
        url: "/casenotes/getFlags.php",
        data: {ucn : ucn},
        async: true,
        success: showFlags
    });
}

function getNotes (ucn) {
    $.ajax({
        url: "/casenotes/getNotes.php",
        data: {ucn : ucn},
        async: true,
        success: showNotes
    });
}


function showFlags(data){
    var json = data
    var flaglist;
    
    var ucn = json.ucn;
    var casenum = json.casenum;
    
    if (json.flags.length == 0) {
        flaglist = $('<td>').html('No flags are set for this case.');
    } else {
        flaglist = $('<td>').addClass('tableholder');
        fhtable = $('<table>');
        head = $('<thead>');
        headerRow = $('<tr>').addClass('title');
        
        $(headerRow).append(
            $('<th>'),
            $('<th>').html('Date'),
            $('<th>').html('Flag'),
            $('<th>').html('User'),
            $('<th>').html('Expires'),
            $('<th>').html('Delete')
        )
        
        $(head).append($(headerRow));
        $(fhtable).append($(head));
        $(flaglist).append($(fhtable));
        
        body = $('<tbody>');
        
        $.each(json.flags, function(i,e) {
            newRow = $('<tr>').addClass('caseflag').addClass('note').append(
                $('<td>').html('<img src="/images/' + e.Image + '"/>'),
                $('<td>').html(e.FlagDate),
                $('<td>').html(e.FlagDesc).addClass('flagDesc'),
                $('<td>').html(e.User),
                $('<td>').html(e.Expires),
                $('<td>').html('<button class="delFlag" type="button" data-ucn="' + ucn + '" data-flagid="' + e.FlagID + '">X</button>').css('text-align','center')
            );
            $(body).append($(newRow));
        });
        $(fhtable).append($(body));
    }
    
    $('#flaglist_' + ucn).html($(flaglist)); // replaced casenum with ucn
    
    return true;
}


function showNotes(data){
    var json = data;
    var noteslist;
    
    var ucn = json.ucn;
    var casenum = json.casenum;
    
    if (json.notes.length == 0) {
        noteslist = $('<td>').html('No notes are set for this case.');
    } else {
        noteslist = $('<td>').addClass('tableholder');
        fhtable = $('<table>');
        head = $('<thead>');
        headerRow = $('<tr>').addClass('title');
        
        $(headerRow).append(
            $('<th>').html('Date'),
            $('<th>').html('User'),
            $('<th>').html('Note'),
            $('<th>').html('Private'),
            $('<th>').html('Attachment'),
            $('<th>').html('Delete')
        )
        
        $(head).append($(headerRow));
        $(fhtable).append($(head));
        $(noteslist).append($(fhtable));
        
        body = $('<tbody>');
        
        $.each(json.notes, function(i,e) {
            if (e.Attachment != "") {
                var attachLink = $('<a>').addClass('notesAttach').data('noteid', e.NoteID).data('filename',e.Attachment).html(e.Attachment);
            } else {
                attachLink = $('<span>').html('&nbsp;');
            }
            newRow = $('<tr>').addClass('casenote').addClass('note').append(
                $('<td>').html(e.NoteDate),
                $('<td>').html(e.User),
                $('<td>').html(e.Note).addClass('noteDesc'),
                $('<td>').html(e.Private).css('text-align','center'),
                $('<td>').html($(attachLink)),
                $('<td>').html('<button class="delNote" type="button" data-ucn="' + ucn + '" data-noteid="' + e.NoteID + '">X</button>').css('text-align','center')
            );
            $(body).append($(newRow));
        });
        $(fhtable).append($(body));
    }
    
    $('#casenotes_' + ucn).html($(noteslist)); // replaced casenum with ucn
    
    return true;
}


