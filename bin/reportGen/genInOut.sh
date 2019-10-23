#!/bin/bash

echo Civil
$ENV{'JVS_PERL5LIB'}/reportGen/civilInOut.pl
    
echo Family
$ENV{'JVS_PERL5LIB'}/reportGen/familyInOut.pl
   
echo Juvenile
$ENV{'JVS_PERL5LIB'}/reportGen/juvInOut.pl 
    
echo Probate
$ENV{'JVS_PERL5LIB'}/reportGen/probateInOut.pl
    
echo Criminal 
$ENV{'JVS_PERL5LIB'}/reportGen/crimInOut.pl
