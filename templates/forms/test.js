function LoadNewForm() {
    var formid=$("#formselect option:selected").val();
    if (formid!="") {
        $.post("formtext.php?form_id="+formid,function(data) {
            CKEDITOR.instances['editwindow'].setData(data);
            $("#form_id").val(formid);
        });
    } else {
        data='';
        CKEDITOR.instances['editwindow'].setData(data);
        $("#form_id").val(formid);
    }
}

$(document).ready(function () {
    $("#formselect").change(LoadNewForm);
    // custom configuration for the toolbar here...
    CKEDITOR.replace("editwindow", {
        height: '80%',
        resize_enabled: "true",
        contentsCss:'forms.css',
        extraPlugins: 'tokens',
        // NOTE: taking out Insert Image makes image links fail for some reason...
        toolbar : [
                   { name: 'document', groups: [ 'mode', 'document', 'doctools' ], items: [ 'Save', '-', 'Source' ] },
                   { name: 'clipboard', groups: [ 'clipboard', 'undo' ], items: [ 'Cut', 'Copy', 'Paste', 'PasteText', 'PasteFromWord', '-', 'Undo', 'Redo' ] },
                   { name: 'editing', groups: [ 'find', 'selection', 'spellchecker' ], items: [ 'Find', 'Replace', '-', 'SelectAll', '-', 'Scayt' ] },
                   '/',
                   { name: 'basicstyles', groups: [ 'basicstyles', 'cleanup' ], items: [ 'Bold', 'Italic', 'Underline', 'Strike', 'Subscript', 'Superscript', '-', 'RemoveFormat' ] },
                   { name: 'paragraph', groups: [ 'list', 'indent', 'blocks', 'align', 'bidi' ], items: [ 'NumberedList', 'BulletedList', '-', 'Outdent', 'Indent', '-', 'CreateDiv', '-', 'JustifyLeft', 'JustifyCenter', 'JustifyRight', 'JustifyBlock' ] },
                   '/',
                   { name: 'styles', items: [ 'Styles', 'Format', 'Font', 'FontSize' ] },
                   { name: 'tools', items: [ 'Maximize', 'ShowBlocks' ] },
                   { name: 'insert', items: [ 'Image'] },
                   { name: 'others', items: [ '-' ] },
                   { name: 'about', items: [ 'About' ] },
                   { name: 'tokens', items: [ 'tokens' ] }
                   ]
    });
    
    // plugins for dropdown (eventually)
    CKEDITOR.plugins.add('tokens', {
        requires : ['richcombo'],
        init : function( editor ) {
            var config = editor.config,
            lang = editor.lang.format;
            var tags = [
                        ["[% ada_phone %]", "ADA phone", "The phone number to request ADA assistance."],
                        ["[% additional_matter %]", "Additional Matter", "Any other matter added to the order; usually in a section for this sorts of adds."],
            ];
            
            editor.ui.addRichCombo( 'tokens', {
                label : "Fields",
                title :"",
                voiceLabel : "Insert field in document",
                className : 'cke_format',
                multiSelect : false,
                panel : {
                    css : [ config.contentsCss,'richcombo.css' ],
                    voiceLabel : lang.panelVoiceLabel
                },
                init : function() {
                    for (var this_tag in tags){
                        this.add(tags[this_tag][0], tags[this_tag][1], tags[this_tag][2]);
                    }
                },
                onClick : function( value ) {
                    editor.focus();
                    editor.fire( 'saveSnapshot' );
                    editor.insertHtml(value);
                    editor.fire( 'saveSnapshot' );
                }
            });
        }});
});