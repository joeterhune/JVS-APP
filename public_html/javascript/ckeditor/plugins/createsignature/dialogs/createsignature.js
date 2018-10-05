//this was defined in the init function of our plugin file
CKEDITOR.dialog.add( 'sigDialog', function( editor ) {
	
  return {
    title: 'Sign Here',
    minWidth: 600, //window minimum width
    minHeight: 200,//window minimum height
    //now we need to define the content of the page
    contents: [
      //the page will have 2 tabs.
      //this is the first tab.
      {
        id: 'general',//identify the tab with a unique ID
        label: 'Signature',//label text for tab
        //define the fields that will be on this tab.
        elements: [
          //define a text input field
          {
            type: 'html',
            html: ' <div id="signature-pad" class="signature-pad"><div class="signature-pad--body"><canvas style="border:1px solid black; width:100%; height:100%;"></canvas></div>',
            id: 'signature_field', //use to identify this field and get value during processing
            label: 'Signature',
            validate: CKEDITOR.dialog.validate.notEmpty("Signature required.")
          },
        ]
      },
    ],
    onOk: function() {
    	var dialog = this;
    	//specify the tab and the field.
    	
    	var canvas = document.querySelector("canvas");
    	var dataURL = canvas.toDataURL();

    	//we could insert the text into the editor at the current cursor position
    	editor.insertHtml('<img class="sigpad-signature" src="' + dataURL +'"/>');
    },
    onShow : function(){
    	var canvas = document.querySelector("canvas");
    	var signaturePad = new SignaturePad(canvas);
    	
    	// When zoomed out to less than 100%, for some very strange reason,
		// some browsers report devicePixelRatio as less than 1
		// and only part of the canvas is cleared then.
		var ratio =  Math.max(window.devicePixelRatio || 1, 1);

		// This part causes the canvas to be cleared
		canvas.width = canvas.offsetWidth * ratio;
		canvas.height = canvas.offsetHeight * ratio;
		canvas.getContext("2d").scale(ratio, ratio);

		// This library does not listen for canvas changes, so after the canvas is automatically
		// cleared by the browser, SignaturePad#isEmpty might still return false, even though the
		// canvas looks empty, because the internal data of this library wasn't cleared. To make sure
		// that the state of this library is consistent with visual state of the canvas, you
		// have to clear it manually.
		signaturePad.clear();
    }
  };
});