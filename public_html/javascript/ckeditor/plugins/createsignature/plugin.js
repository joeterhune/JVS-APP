CKEDITOR.plugins.add( 'createsignature', {
  icons: 'createsignature',
  init: function( editor ) {

    //create a command for our plugin called
    //when the command is executed it will open a dialog window.
    //we gave this new window the identifier of "sigDialog"
    //"sigDialog" can be use to identify the window
    editor.addCommand('createSignature', new CKEDITOR.dialogCommand('sigDialog'));

    //add a button to the toolbar.
    //when the button is clicked it will execute the "abbr" command
    //which will open the dialog window
    editor.ui.addButton( 'createsignature', {
      label: 'Sign Document',
      command: 'createSignature',
      icon: CKEDITOR.plugins.getPath('createsignature') + '/images/sig_icon.png'
    });

    //the specific code to run when the dialog opens can be defined in
    //another file. "sigDialog" is the dialog we registered above.
    //we also pass the path to the file to run. 
    //most examples I've found uses "this.path" to get the plugin directory
    //but i was getting an error with this approach
    //therefore i used CKEDITOR.plugins.getPath() to get the path to the plugin dir
    CKEDITOR.dialog.add( 'sigDialog', CKEDITOR.plugins.getPath( 'createsignature' ) + 'dialogs/createsignature.js?1.1' );
    
  }
});