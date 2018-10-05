<?php

################# CLASS GRAPH ###########################

class Graph {
  var $im,$x,$y,$bg,$blue,$black,$grey,$red,$white; 
  var $cx1,$cy1,$cx2,$cy2,$cy3,$tb,$low,$high,$numticks,$tickheight,
      $ticktenth,$stime,$etime,$syear,$eyear;


  #
  #  initialization function
  #
  function Graph($nx,$ny,$title) {
    $this->x=$nx;
    $this->y=$ny;
    $this->im=imagecreate($nx,$ny);
    $this->bg = imagecolorallocate($this->im, 255,255,255);
    $this->blue = imagecolorallocate($this->im, 0,0,255);
    $this->green = imagecolorallocate($this->im, 0,128,0);
    $this->black = imagecolorallocate($this->im, 0,0,0);
    $this->grey = imagecolorallocate($this->im, 200,255,200);
    $this->red= imagecolorallocate($this->im,255,0,0);
    $this->white=imagecolorallocate($this->im,0,128,0);
    imagefill($this->im,0,0,$this->bg);
    imagerectangle($this->im,0,0,$nx-1,$ny-1,$this->grey);
    imagestring($this->im, 3, 3, 3, $title, $this->green);
    $this->cx1=30;
    $this->cy1=30;
    $this->cx2=$nx-20;
    $this->cy2=$ny-20;
    $this->cy3=$ny-35;
    imagerectangle($this->im,$this->cx1-1,$this->cy1,$this->cx2,$this->cy2,$this->black);
    imageline($this->im,$this->cx1,$this->cy3,$this->cx2,$this->cy3,$this->black);
    imagefill($this->im,$this->cx1+1,$this->cy3+1,$this->grey);
    }

  #
  #  set the y axis range and label the graph
  #

  function setyaxis($nlow,$nhigh) {
    $this->low=$nlow;
    $this->high=$nhigh;
    $this->tb=floor(($nhigh-$nlow)/5);
    if ($this->tb==0) { $this->tb=1; }
    $this->low=floor($nlow/$this->tb)*$this->tb;
    $this->high=floor(floor($nhigh/$this->tb)*$this->tb+$this->tb);
    $this->numticks=($this->high-$this->low)/$this->tb+1;
    $this->tickheight=($this->cy3-$this->cy1)/($this->numticks-1);
    $this->ticktenth=$this->tickheight/10;
    #
    # now draw appropriately scaled ticks for y-axis
    #
    $ty=$this->cy3;
    $tval=$this->low;
    for ($i=0;$i<$this->numticks;$i++) {
       if ($ty!=$this->cy3 && $ty!=$this->cy1) {
          imageline($this->im,$this->cx1+1,$ty,$this->cx2-1,$ty,$this->grey);
          }
       if ($ty==$this->cy3) { $adj=-9; }
       elseif ($ty==$this->cy1) { $adj=-3; }
       else { $adj=-6; }
       imagestring($this->im,2,$this->cx1-20,$ty+$adj,$tval,$this->black);
       $ty-=$this->tickheight;
       $tval+=$this->tb;
       }
  }



   #
   #   internal function for graphing x ticks
   #

    function graphxtick($year,$month) {
       $ttime=strtotime("$year-$month-01");
       if ($ttime>=$this->stime && $ttime<=$this->etime) {
          $tx=(($ttime-$this->stime)/($this->etime-$this->stime)*($this->cx2-$this->cx1))+$this->cx1;
          imageline($this->im,$tx,$this->cy1+1,$tx,$this->cy3-1,$this->grey);
          $shortyear=substr($year,2,2);
          if ($month==1) { imagestring($this->im,3,$tx-15,$this->cy3,$year,$this->white); }
          if ($month==7) { imagestring($this->im,3,$tx-15,$this->cy3,"Jul$shortyear",$this->white); }
          if ($month==4) { imagestring($this->im,3,$tx-15,$this->cy3,"Apr$shortyear",$this->white); }
          if ($month==10) { imagestring($this->im,3,$tx-15,$this->cy3,"Oct$shortyear",$this->white); }
          }
   }




   #
   # set x axis range and label 
   #
  function setxaxis($startdate,$lastdate) {
     $this->stime=strtotime($startdate);
     $this->etime=strtotime($lastdate);
     $this->syear=substr($startdate,0,4);
     $this->eyear=substr($lastdate,0,4);
     #
     # now put in quarterly ticks for each year
     #
     for ($i=$this->syear;$i<=$this->eyear;$i++) {
        $this->graphxtick($i,"01");
#        $this->graphxtick($i,"04");
#       $this->graphxtick($i,"07");
#        $this->graphxtick($i,"10");
        }
     }


   #
   # graphpurchase displays purchases as red lines
   #

   function graphpurchase($myticker) {
     global $purchase;
      for ($i=0;$i<count($purchase);$i++) {
         list($date,$ticker,$shares,$cost,$val)=explode(";",$purchase[$i]);
         if ($ticker==$myticker && $cost>0) { # no dividends counted
            $ttime=strtotime($date);
            if ($ttime>=$this->stime && $ttime<=$this->etime) {
               $tx=(($ttime-$this->stime)/($this->etime-$this->stime)*($this->cx2-$this->cx1))+$this->cx1;
               imageline($this->im,$tx,$this->cy1+1,$tx,$this->cy3-1,$this->red);
               }
            }
         }
      }

  #
  # graphrel is supposed to draw a relative graph given data passed it.
  #
  function graphrel($ticker,$pricerel) {
     foreach ($pricerel as $key=>$val) {
        # scale value
        $sval=-($val-$this->low)/($this->high-$this->low)*($this->cy3-$this->cy1)+$this->cy3;
        # scale x axis
        if ($ticker=="FSMKX") { $color=$this->red; }
        else { $color=$this->green; }
        $valtime=strtotime($key);
        if ($valtime>=$this->stime) { # no prices before starting date please
           $sx=(($valtime-$this->stime)/($this->etime-$this->stime)*($this->cx2-$this->cx1))+$this->cx1;
           if ($ox!=0) {
              imageline($this->im,$ox,$oy,$sx,$sval,$color);
              }
           else {
             imagesetpixel($this->im,$sx,$sval,$color);
             }
           $ox=$sx;
           $oy=$sval;
           }
        }
     }


# Class
}


###############END OF GRAPH CLASS###################

# calling example:

#$newgraph=new Graph(320,200,"$ticker vs. FSMKX - since 1st purchase");
#$newgraph->setyaxis($minpct,$maxpct);
#$newgraph->setxaxis($firstbought[$ticker],$lastdate);
#$newgraph->graphpurchase($ticker);
#$newgraph->graphrel($ticker,$pricerel);
#$newgraph->graphrel("FSMKX",$pricefsk);

#imagegif($newgraph->im,"newgraph.gif");
#$now=time();
#echo "<img src=test.gif?x=$now><p>";
#echo "<img src=newgraph.gif?x=$now>";
?>
