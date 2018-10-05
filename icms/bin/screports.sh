#!/bin/bash

DATE=`/bin/date +%Y%m%d`
cd /usr/local/icms/bin

if [ ! -e /usr/local/icms/bin/results/sccrim-done.$DATE ]; then
	./sccrim.pl > results/crimresults&
fi