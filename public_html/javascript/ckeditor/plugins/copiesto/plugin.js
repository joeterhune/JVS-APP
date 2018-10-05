CKEDITOR.plugins.add('copiesto',
{
    init: function (editor) {
        var pluginName = 'copiesto';
        editor.ui.addButton('copiesto',
            {
                label: 'PropOrd CC:',
                command: 'CopiesTo',
                icon: CKEDITOR.plugins.getPath('copiesto') + '/images/address2.png'
            });
        
        	var cmd = editor.addCommand('CopiesTo', { exec: copiesTo });
    }
});

function copiesTo(e) {
	var editor = e;
	var copiesToList = $(".hidden_copies_to_list").html();
	e.insertHtml(copiesToList);
    return true;
}