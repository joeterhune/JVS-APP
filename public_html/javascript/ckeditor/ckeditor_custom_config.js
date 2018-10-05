CKEDITOR.editorConfig = function( config ) {
    config.language = 'en';
    config.uiColor = '#428bca';
	config.htmlEncodeOutput = false;
    //config.fullPage = true;
    config.allowedContent =  true;
    /*config.allowedContent = {
		$1: {
			// Use the ability to specify elements as an object.
	        elements: CKEDITOR.dtd,
	        attributes: true,
	        styles: true,
	        classes: true
	    }
	};
	config.disallowedContent = 'p{margin-left*,text-indent*}';*/
    config.entries = false;
    config.width = '8.5in'; // 8.5 inches wide
    config.height = '11in'; // 11 inches tall
    //config.extraPlugins = 'wysiwygarea,liststyle,dialog,dialogui,contextmenu,menu,floatpanel,panel';
    config.extraPlugins = 'signature,dispostamp,lineheight,tab,lineutils,widget,widgetselection,footnotes,createsignature,copiesto';
    //config.removePlugins = 'save,newpage,print,templates,preview,iframe,flash,image,language';
    //config.removeButtons = "signature,Smiley,SpecialChar,PageBreak,HorizontalRule,Link,Unlink,Anchor,Table,HiddenField,Button,Select,Textarea,TextField,Form,Checkbox,Radio,DocProps";
    config.removeButtons = "Source,Footnotes,About,Format,Save,NewPage,Preview,Templates,Language,Flash,IFrame,Image,Subscript,Superscript,Smiley,Font,ShowBlocks,SpecialChar,HorizontalRule,Link,Unlink,Anchor,Table,HiddenField,Button,Select,Textarea,TextField,Form,Checkbox,Radio,DocProps,Print";
    config.fillEmptyBlocks = true;
    config.entities  = false;
    config.basicEntities = false;
    config.entities_greek = false;
    config.entities_latin = false;
	config.contentsCss = ['/orders/forms.css?2.2', '/style/font-awesome.min.css'];
	config.enterMode = CKEDITOR.ENTER_BR; 
	config.shiftEnterMode = CKEDITOR.ENTER_BR;
	config.disableObjectResizing = true;
	config.line_height="1;1.1;1.2;1.3;1.4;1.5;1.6;1.7;1.8;1.9;2.0";
	config.disableNativeSpellChecker = false;
	config.tabSpaces = 10;
};

CKEDITOR.config.toolbar = [
			//{ name: 'print', items: [ 'Print'] },
			{ name: 'clipboard', groups: [ 'clipboard', 'undo' ], items: [ 'Cut', 'Copy', 'Paste', 'PasteText', 'PasteFromWord', '-', 'Undo', 'Redo', 'Find', 'Replace', 'SelectAll' ] },
			{ name: 'editing', groups: [ 'find', 'selection', 'spellchecker' ], items: [ 'Scayt' ] },
			{ name: 'links', items: [ 'Link', 'Unlink', 'Anchor' ] },
  			{ name: 'tools', items: [ 'Maximize' ] },
			{ name: 'document', groups: [ 'mode', 'document', 'doctools' ], items: [ 'Source' ] },
			{ name: 'others', items: [ '-' ] },
			{ name: 'basicstyles', groups: [ 'basicstyles', 'cleanup' ], items: [ 'Bold', 'Italic', 'Underline', 'Strike', '-', 'RemoveFormat', '-', 'createsignature', '-', 'copiesto' ] },
			{ name: 'paragraph', groups: [ 'list', 'indent', 'blocks' ], items: [ 'NumberedList', 'BulletedList', '-', 'Outdent', 'Indent', '-', 'Blockquote', 'JustifyLeft', 'JustifyCenter', 'JustifyRight', 'JustifyBlock', 'PageBreak'] },
			{ name: 'styles', items: [ 'Format', 'lineheight', 'TextColor', 'BGColor', 'FontSize' ] },
			{ name: 'about', items: [ 'About' ] },
			{ name: 'dispostamp', items: [ 'dispostamp', 'Footnotes' ] }
		];

CKEDITOR.plugins.add('liTab', {
    init: function(editor) {
        editor.on('key', function(ev) {
            if( ev.data.keyCode == 9 || ev.data.keyCode == CKEDITOR.SHIFT + 9) {
                if ( editor.focusManager.hasFocus )
                {
                    var sel = editor.getSelection(),
                    ancestor = sel.getCommonAncestor();
                    li = ancestor.getAscendant({li:1, td:1, th:1}, true);
                    if(li && li.$.nodeName == 'LI') {
                        editor.execCommand(ev.data.keyCode == 9 ? 'indent' : 'outdent');
                        ev.cancel();
                    }
                    // else we've found a td/th first, so let's not break the
                    // existing tab functionality in table cells.
                }
                
            }
        }, null, null, 5); // high priority (before the tab plugin)
    }
});