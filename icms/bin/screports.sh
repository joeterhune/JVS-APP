#!/bin/bash

DATE=`/bin/date +%Y%m%d`
cd $ENV{'PERL5LIB'}

if [ ! -e $ENV{'PERL5LIB'}/results/sccrim-done.$DATE ]; then
	./sccrim.pl > results/crimresults&
fi
