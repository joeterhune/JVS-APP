<?php
# signpdf - convert an pdf to a series of pngs, and allow signing and annotation
#
# with help from 
#   http://www.html5canvastutorials.com/advanced/html5-canvas-mouse-coordinates/

# BUGS: may have an issue with cancelled annotations & fragments...


# ok, first create the pngs... (may check for pre-existence later on...

include "../icmslib.php";


#
#  MAIN PROGRAM (php)
#
$docid=$_REQUEST[id];
$role=$_REQUEST[role];
$ucn=$_REQUEST[ucn];
#if (preg_match("/$role/i",$ROLE) { # user's role doesn't match role we're trying to sign by...
#  echo "Error: you have not been assigned role $role!";
#  exit;
#}
if ($docid=="") { 
   echo "Error: document ID not supplied!";
   exit;
}
#if ($ucn=="") { 
#   echo "Error: Please specify a Case # for this order!";
#   exit;
#}
if (file_exists("$DOCPATH/$docid.pdf")) { 
    $infile="$DOCPATH/$docid.pdf"; # already signed by at least one party.
} else if (file_exists("$DOCPATH/$docid.dist.pdf")) {
    $infile="$DOCPATH/$docid.dist.pdf"; # use the original
} else { # gen an original
     if (file_exists("$DOCPATH/$docid.dist.docx")) { $docfile="$DOCPATH/$docid.dist.docx"; }
     else if (file_exists("$DOCPATH/$docid.dist.doc")) { $docfile="$DOCPATH/$docid.dist.doc"; }
     else {
         echo "Error: can't find original document for $docid<p>";
         exit;
    }
     `/usr/bin/libreoffice --headless -convert-to pdf $docfile -outdir $DOCPATH`;
    $infile="$DOCPATH/$docid.dist.pdf"; # use the original
}

# MAKE PNG FILES of each page of this document
# density 144, resize 50 gives better results than just a density 72...but is slower...
`/usr/bin/convert -density 144 -quality 100 -resize 50% $infile /var/www/icmsdata/tmp/$docid.png`;
# was -scale 612x792 -quality 85 $infile /var/www/icmsdata/tmp/$docid.png`;

# WHILE I'M AT IT, make a new sig file with a watermark...
# need a timestamp (just for show here...the right one gets affixed on a save)
$ts=date("m/d/Y h:i:sa");
if (preg_match("/county/i",$FULLROLE) && preg_match("/judge/i",$FULLROLE)) {
    if (preg_match("/CA|CF/",$ucn)) { $FULLROLE="Acting Circuit Judge"; }
}
$sigpath=`/var/icms/web/workflow/stampimage.php $ucn $USER "$ts" "$FULLNAME" "$FULLROLE"`;
if (file_exists("/var/www/icmsdata/tmp/$docid.png")) { # only one page
   $numpages=1;
} else {
   for ($i=0;$i<1000;$i++) {
     if (file_exists("/var/www/icmsdata/tmp/$docid-$i.png")) {
        $numpages=$i+1;
     } else { break; }
   }
}
if (!$numpages) {
  echo "what's numpages! ($numpages,$docid)";
}

# we need to scale the 300dpi image to 72dpi equivalent for PDF sizing...
list($x,$y)=getres("/var/www/$sigpath"); # icms/conf/signatures/$USER.sig.png");
$xsize=intval($x/4.166666);
$ysize=intval($y/4.166666);
$topsize=0; #25;  # size of top nav strip...
# css below via: http://stackoverflow.com/questions/256811/how-do-you-create-non-scrolling-div-at-the-top-of-an-html-page-without-two-sets

?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<head>
<link rel="stylesheet" href="/icms/css/custom-theme/jquery-ui.css" />
<style type="text/css">
body,
div {
    margin: 0;
    padding: 0;
}
body {
  /* Disable scrollbars and ensure that the body fills the window */
  overflow: hidden;
  width: 100%;
  height: 100%;
}
input.btn {
   font-size: 8pt;
   }
.ui-datepicker{ z-index: 9999 !important;}
#header {
   /* Provide scrollbars if needed and fix the header dimensions */
   overflow: auto;
   position: absolute;
   width: 100%;
   height: 25px;
   }
#main {
   /* Provide scrollbars if needed, position below header, 
      and derive height from top/bottom */
   overflow: auto;
   position: absolute;
   width: 100%;
   top: 25px;
   bottom: 0;
}
</style>

<!--[if lt IE 9]>
<script type="text/javascript" src="/icms/javascript/excanvas.js" ></script>
<![endif]-->

<script type="text/javascript" src="/icms/javascript/jquery/jquery.min.js" ></script>
<script src="/icms/javascript/jquery/ui/js/jquery-ui.js"></script>
<script language=javascript>

var numpages=<?php echo $numpages;?>;
var docid=<?php echo $docid;?>;
var ucn='<?php echo $ucn;?>';
var role='<?php echo $role;?>';
var userid='<?php echo $USER;?>';
var sigxsize=<?php echo $xsize;?>;
var sigysize=<?php echo $ysize;?>;
var mode=0; // 1=sign, 2=annotate
var today='<?php echo $TODAY;?>';
var annotloc=new Array();
var fragtxt=''; // text of current text fragment
var fragcnt=0;  // number of fragments
var fragarr=new Array(); // array of all fragments
var fragx=new Array(); // x coord of fragments
var fragy=new Array(); // y coord of fragments
var fragpage=new Array(); // page # of fragments (0..n)
var currfrag=0;

// getMousePos returns the position of the mouse RELATIVE to the current canvas..

function getMousePos(canvas, evt) {
   var rect = canvas[0].getBoundingClientRect();
   return {
      x: evt.clientX - rect.left,
      y: evt.clientY - rect.top
   };
}


function writeMessage(canvas, message) {
   var context = canvas[0].getContext('2d');
   context.clearRect(10, 30, 250,20);
   context.font = '10pt Calibri';
   context.fillStyle = 'black';
   context.fillText(message, 10, 40);
}


var maxx=612;
var maxy=792;
var topsize=<?php echo $topsize;?>; // size of top nav bar...
var oldx;
var oldy;
var fixx;
var fixy;
var fixxpct;
var fixypct;
var isfixed=0; // one if a signature is affixed
var sig=new Image();
var fixpage;

// Text Annotation stuff

var textsx;
var textsy;
var textcx;
var textcy;
var textstr='';
var textcontext;
var currentcanvas; 


// kup handles the kup events; depending on mode, it may cancel a 
// current positioning event

function kup(evt) {
   if (evt.keyCode==27) {
      if (mode==3) { // fragment position: cancel!
         if (currentcanvas) {
            var canvas=currentcanvas; 
            var ctx=canvas[0].getContext('2d');
            ctx.clearRect(oldx-59,oldy-50,200,100);
         }
         fragarr[currfrag]='';
         fragtxt='';
         $('#fragment-'+currfrag).html('');
         mode=0;
      }
   }
}


// handleKeys handles keyboard events for the add text function
// it lets escape with Esc, and save the text with Enter


function handleKeys(evt) {
    evt = evt || window.event;
    var target = evt.target || evt.srcElement;
    if (evt.keyCode==27) { 
      var an=target.id;
      an=an.replace('input','annot');
      $(target).remove(); // get rid of the input box..
      $('#'+an).remove(); // get rid of this annotation...
      an_count--;
      return true;
    }
    if (evt.keyCode==13) {
      var x=$(target).val();
      // find matching annotation div
      var an=target.id;
      an=an.replace('input','annot');
      $(target).remove(); // get rid of the input box
      var y=$('#'+an).css('top');
      y=y.replace('px','');
      var ny=parseInt(y)+7; // shift text down a few pixels
      ny=ny+'px';
      $('#'+an).css('top',ny); 
      $('#'+an).html(x); // set the annotation to the value
      mode=0; // and get out of add text mode!
      an_start=0;
    }
    return true;
}


var an_count=0;
var an_started=0;


function startaddtext(evt) {
   var canvas=$(evt.target); // $(this);
   var mousePos = getMousePos(canvas, evt); // RELATIVE TO CANVAS, useful, but not what we want for displaying on screen...
   var relx=mousePos.x;
   var rely=mousePos.y;
   var pagenum=canvas[0].id;
   pagenum=pagenum.replace('ov','');
   // set relative x,y, and pagenum in annotloc
   annotloc[an_count]=relx+'~'+rely+'~'+pagenum;
   var x=evt.clientX;
   var y=evt.clientY;
   y+=$('#main').scrollTop()-45; 
   if (an_started==0) {  // first mouse-up on this annotation
      an_started=1;
      // -25 for top of page nav, plus windage for browser elements
      var textarea= "<div id='annot"+an_count+"' style='position:absolute; left: "+x+"px; top: "+y+"px;z-index:30; font-family: Times; font-size:10pt;'><input type=text id='input"+an_count+"' size=40/></div>";
      $("#main").append(textarea);
      $("#input"+an_count).keypress(handleKeys);
      $("#input"+an_count).focus();
      an_count++;
   } else { // already have a box; need to move it.
      var ann=an_count-1;
      var ad=$('#annot'+ann);
      ad.css('left',x+'px');
      ad.css('top',y+'px');
   }
}

// end Text Annotation Stuff




// mup handles a mouseup event on a canvas
// it does whatever housekeeping is required to store the info so
// it can be saved later


function mup(evt) {
   if (mode==0) { return true; } // ignore the mouse click...
   else if (mode==1) {    // Signatures (mode 1)
      if (isfixed) { // already fixed; un-fix it...
         var canvas=$(this);
         var ovcon=canvas[0].getContext('2d');
         ovcon.clearRect(fixx,fixy,sigxsize,sigysize);
         isfixed=0;
      } else { // wasn't fixed, but it is now
         isfixed=1;
         fixx=oldx;
         fixy=oldy;
         fixypct=792-fixy-sigysize;
         fixxpct=fixx;
         fixpage=this.id.substr(2,255);
      }
   }
   else if (mode==2) { // Text Annotation
      return startaddtext(evt); 
      }
   else if (mode==3) { // finalize the position this text fragment
      // but hey, let's put it on the main canvas so it can't get wiped..
      var cid=this.id;
      // erase it on the overlay...
      var canvas=$(this);
      var ovcon=canvas[0].getContext('2d');
      ovcon.clearRect(oldx-59,oldy-50,200,100);
      // and draw it on the page below...
      var pid=cid.replace('ov','p');
      var canvasp=$("#"+pid);      
      var ovconp=canvasp[0].getContext('2d');
      ovconp.font="12px Times";
      ovconp.fillText(fragtxt,oldx,oldy);
      var pagenum=cid.replace('ov','');
      fragx[currfrag]=oldx;
      fragy[currfrag]=oldy;
      fragpage[currfrag]=pagenum;
      // now clear text fragment mode...
      mode=0; // just like that!
      return true;
   } else {
      alert('unknown mode '+mode);
   }
}




// mousemove handles the moving and position on the canvas,
// so whatever document element is currently being positioned
// is moved properly

function mmove(evt) {
   if (mode!=1 && mode!=3) { return true; }
   var canvas=$(this); // document.getElementById(this.id);
   currentcanvas=canvas;
   var mousePos = getMousePos(canvas, evt);
   var message = mousePos.x + ',' + mousePos.y+ ': canvas '+this.id+' isfixed='+isfixed+' mode='+mode+' '+sigxsize+'x'+sigysize;
//   writeMessage(canvas, message);
   if (mode==1) {  // draw a signature
      if (isfixed==0) {
          var ovcon=canvas[0].getContext('2d');
         if (oldx) {
            ovcon.clearRect(oldx,oldy,sigxsize,sigysize);
         }
         ovcon.drawImage(sig,mousePos.x,mousePos.y,sigxsize,sigysize);
      }
   } else { // let's try positioning a div
// this works great on page 1; not so much on page 2...in multiple browsers.
//      $('#fragment-'+currfrag).css('left',mousePos.x);
//      $('#fragment-'+currfrag).css('top',mousePos.y);
      var ctx=canvas[0].getContext('2d');
      if (oldx) {
         ctx.clearRect(oldx-59,oldy-50,200,100);
      }
      ctx.font="12px Times";
      ctx.fillText(fragtxt,mousePos.x,mousePos.y);
   }
   oldx=mousePos.x;
   oldy=mousePos.y;
}


function mouseout(evt) {
   if (mode!=1) { return true; }
   var canvas=$(this);
   if (fixpage!=this.id.substr(2,255) && oldx) { // not the signing page, but something drawn
      var ovcon=canvas[0].getContext('2d');
      ovcon.clearRect(oldx,oldy,sigxsize,sigysize);
   }
}


function SignSave() {
  // NOTE: this builds the data to post in a crude way...
  // a javascript object post, followed by PHP parse, would be
  // "better", but it turned to to be difficult in practice.

  // first, we add the text annotations from the annotN divs...
  var pval="ucn="+ucn+"&docid="+docid+"&ancount="+an_count;
  for (i=0;i<an_count;i++) {
     var oid='annot'+i;
     var obj=$('#'+oid);
     var textval=encodeURI(obj.html());
     var annotdata=annotloc[i].split('~');
     var x=annotdata[0];
     var y=annotdata[1];
     var page=annotdata[2]
     y=792-parseInt(y)+12; // from bottom, PDF style..
     // y needs adjustment from absolute to page-relative positioning.
     // example: &annot1=TEXT~Hello%20World~100~200~0
     pval+="&"+oid+"=TEXT~"+textval+"~"+x+"~"+y+"~"+page;
  }
  // now add fragments (hopefully will be merged into annotation list above
  // in the near future...
  pval+='&fragcnt='+fragcnt;
  for (i=0;i<fragcnt;i++) {
     x=fragx[i];
     y=792-fragy[i]; // make y relative to bottom of document
     page=fragpage[i]
     var fragtext=encodeURI(fragarr[i]);
     pval+="&frag"+i+"=TEXT~"+fragtext+'~'+x+'~'+y+'~'+page;
  }
  // now check to see if a signature's attached...
  if (isfixed) {
     pval+="&sig0=ESIG~"+userid+'~'+fixxpct+'~'+fixypct+'~'+fixpage+'~'+role;
  }
//   alert('posting: '+pval);
   $.post("/icms/workflow/signsave.php",pval, function(data) { window.opener.$("#Workflow").load('workflow/wfshow.php', function () { window.close();}); });

// alert('received: '+data); });
// { x: fixxpct, y: fixypct,page: fixpage,docid: docid,role: '<?php echo $role;?>'});
}



// FragAdd allows the user to position a specified fragment of text
// on a document. 

function FragAdd(x) {
   var txt=$(x).val();
   mode=3; // Fragment-positioning mode...
   fragtxt=txt;
   currfrag=fragcnt;
   fragarr[currfrag]=fragtxt;
   fragcnt++;
}


function OrdinalSuffix(val) {
   var mod = val % 10;
   if (mod === 1 && val !== 11) {
      return 'st';
   } else if (mod === 2 && val !== 12) {
      return 'nd';
   } else if (mod === 3 && val !== 13) {
      return 'rd';
   } else {
      return 'th';
   }
}

function ChangeDates() {
   var dt=$("#datepickerX").val(); 
   var d=$.datepicker.parseDate("mm/dd/yy",dt);
   $("#year4").val($.datepicker.formatDate("yy",d));
   $("#year2").val($.datepicker.formatDate("y",d));
   $("#monthname").val($.datepicker.formatDate("MM",d));
   var day=parseInt($.datepicker.formatDate("d",d));
   $("#day").val(day);
   $("#dayord").val(day+OrdinalSuffix(day));
   $("#fulldate").val($.datepicker.formatDate("DD, MM d, yy",d));
}


var img=new Array();

$(document).ready(function() {
   var numpages=<?php echo $numpages;?>;
   var t=new Date().getTime();
   if (numpages==1) {
      img[0]=new Image();
      // for timing's sake, do this stuff after I fill the background.
      img[0].onload=function() {
         var c=$("#p0"); 
         var ctx=c[0].getContext("2d");
         ctx.drawImage(img[0],0,0);
      }
      img[0].src='/icmsdata/tmp/'+docid+'.png?t='+t;
   } else {
<?php
     # crude, but it works..hard difficulties doing this in
     # straight JavaScript...
     for ($i=0;$i<$numpages;$i++) {
        echo "img[$i]=new Image();\n";
        echo "img[$i].onload=function() {\n";
        echo "var c=\$(\"#p$i\");\n";
        echo "var ctx=c[0].getContext('2d');\n";
        echo "ctx.drawImage(img[$i],0,0);\n";
        echo "}\n";
        echo "img[$i].src='/icmsdata/tmp/$docid-$i.png?t='+t;\n";
    }
?>
   }
   $('.overlay').mousemove(mmove);
   $('.overlay').mouseup(mup);
   $('.overlay').mouseout(mouseout);
   $('body').keyup(kup);
   sig.src='<?php echo $sigpath;?>';
   $("#datepickerX").val(today);
   $("#datepickerX").datepicker({showOn: "button",buttonImage: "/icms/calendar_icon.gif",buttonImageOnly: true});
   $("#datepickerX").change(ChangeDates);
   ChangeDates();
});


</script>

</head>
<body>
<font face=arial>
<div id=header>
<input type=button class=btn value=Save onClick=SignSave();>
<input type=button value=E-Sig class=btn onClick="mode=1;" title='Add an electronic signature'>
<input type=button class=btn value="T" onClick="mode=2;" class=btn style="font-weight:bold" title='Add text to document'>
<input type=button id=fulldate class=btn value='' onClick="FragAdd(this);"><input type=button id=year4 class=btn value='' onClick=FragAdd(this);>
<input type=button id=year2 class=btn value='' onClick=FragAdd(this);>
<input type=button id=monthname class=btn value='' onClick=FragAdd(this);>
<input type=button id=day class=btn value='' onClick=FragAdd(this);>
<input type=button id=dayord class=btn value='' onClick=FragAdd(this);>
<input type="hidden" size=10 id="datepickerX" />
</div>
<div id=main>
<?php
#
# create a canvas and overlay for each page found
#
if ($numpages==1) { # only one page
   echo "<canvas id='p0' width=612 height=792 style='position:absolute; left:0px;top:'+topsize+'px;z-index:1;border:1px solid #000000;'>Your browser does not support the canvas element.</canvas>";
   echo "<canvas id='ov0' width=612 height=792 class='overlay' style='position:absolute; left:0px; top:'+topsize+'px; z-index : 2'></canvas>";
} else {
  $top=0;
  for ($i=0;$i<$numpages;$i++) {
    echo "<canvas id='p$i' width=612 height=792 style='position:absolute; left:0px;top:${top}px;z-index:1;border:1px solid #000000;'></canvas>\n";
    echo "<canvas id='ov$i' class='overlay' width=612 height=792 style='position:absolute; left:0px; top:${top}px; z-index : 2'></canvas>\n";
    $top+=792;
 }
}
?>
</div>
</body>