#!/bin/sh

RECIP=rhaney@jud12.flcourts.org
DATE=`/bin/date +%Y%m%d`
RESULTDIR=/var/jvs/icms/bin/results

for SCRIPT in sccrim
do
	FILE=$RESULTDIR/$SCRIPT-done.$DATE
	if [ ! -e $FILE ]
	then
		echo "NO SUCCESSFUL COMPLETION FILE FOR $FILE" | /bin/mail -s "REPORT SCRIPT ALERT" $RECIP
	fi
done