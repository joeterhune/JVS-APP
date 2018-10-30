#!/bin/bash

echo Civil
$ENV{'PERL5LIB'}/reportGen/civilInOut.pl
    
echo Family
$ENV{'PERL5LIB'}/reportGen/familyInOut.pl
   
echo Juvenile
$ENV{'PERL5LIB'}/reportGen/juvInOut.pl 
    
echo Probate
$ENV{'PERL5LIB'}/reportGen/probateInOut.pl
    
echo Criminal 
$ENV{'PERL5LIB'}/reportGen/crimInOut.pl
