CKEDITOR.plugins.add('signature',
{
    init: function (editor) {
        var pluginName = 'signature';
        editor.ui.addButton('signature',
            {
                label: 'Add Signature',
                command: 'AddSignature',
                icon: CKEDITOR.plugins.getPath('signature') + '/images/sig.png'
            });
        
        	var cmd = editor.addCommand('AddSignature', { exec: addSignature });
    }
});

function addSignature(e) {
	var editor = e;
	var sigDiv = $(".signaturediv").html();
	e.insertHtml(sigDiv);
    return true;
}