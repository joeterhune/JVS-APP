#!/bin/bash

DATE=`/bin/date +%Y%m%d`
cd /var/jvs/icms/bin

if [ ! -e /var/jvs/icms/bin/results/sccrim-done.$DATE ]; then
	./sccrim.pl > results/crimresults&
fi