#!/bin/bash

echo Civil
/usr/local/icms/bin/reportGen/civilInOut.pl
    
echo Family
/usr/local/icms/bin/reportGen/familyInOut.pl
   
echo Juvenile
/usr/local/icms/bin/reportGen/juvInOut.pl 
    
echo Probate
/usr/local/icms/bin/reportGen/probateInOut.pl
    
echo Criminal 
/usr/local/icms/bin/reportGen/crimInOut.pl
