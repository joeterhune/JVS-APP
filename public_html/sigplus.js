<!-- javascript functions for sigplus

function OnClear() {
   theform.SigPlus1.ClearTablet(); //Clears the signature, in case of error or mistake
}
function OnCancel() {
   theform.SigPlus1.TabletState = 0; //Turns tablet off
}
function OnSign() {
    theform.SigPlus1.TabletState = 1; //Turns tablet on
}
function OnSave() {
   theform.SigPlus1.TabletState = 0; //Turns tablet off
   theform.SigPlus1.SigCompressionMode = 0; //Compresses the signature at a 2.5 to 1 ratio, making it smaller...to display the signature again later, you WILL HAVE TO set the SigCompressionMode of the new SigPlus object = 1, also
   //   retval=theform.SigPlus1.WriteImageFile('c:\\foox.bmp');
   // alert('retval='+retval);
   theform.esig.value=theform.SigPlus1.SigString;
   theform.SigPlus1.BitMapBufferWrite();
   //   var data:array of byte;
   numbytes=theform.SigPlus1.BitMapBufferSize;
   alert('buffer size='+numbytes);
   for (i=0;i<numbytes;i++) {
      d=theform.SigPlus1.BitMapBufferByte(i);
      h=d.toString(16);

      //      alert(h); // if (h.length==1) { h='0'+h; }
      //      data=data+h
      }
   alert("data length"+length(data)+", bitmap size "+theform.SigPlus1.BitMapBufferSize);
   //   alert("esig2 value="+theform.esig2.value+" buffer bytes="+theform.SigPlus1.BitMapBufferSize);
   // alert("The signature you have taken is the following data: " + theform.SigPlus1.SigString);
//The signature is now taken, and you may access it using the SigString property of SigPlus. This SigString is the actual signature, in ASCII format. You may pass this string value like you would any other String. To display the signature again, you simply pass this String back to the SigString property of SigPlus (BE SURE TO SET SigCompressionMode=1 PRIOR TO REASSIGNING THE SigString)
}

//-->

