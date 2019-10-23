#!/bin/bash

DATE=`/bin/date +%Y%m%d`
cd $ENV{'JVS_PERL5LIB'}

if [ ! -e $ENV{'JVS_PERL5LIB'}/results/sccrim-done.$DATE ]; then
	./sccrim.pl > results/crimresults&
fi