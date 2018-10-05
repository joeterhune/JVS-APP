#!/bin/sh

set -x

DATE=`date +%Y%m%d`
TARGETDIR=/root/olsdumps
USER=dbuser
PASS=mobile1
FTPHOST=151.132.51.168

if [ ! -d $TARGETDIR ];
then
	mkdir -p $TARGETDIR
fi

# We don't need old versions - we only want the most recent
rm -f $TARGETDIR/*.sql

# Get all of the *event databases from the host
cd $TARGETDIR && /usr/bin/lftp -e "set ftp:passive-mode false; set net:timeout 30; mget /*event/*event.$DATE.sql; mget /olschedule/olscheduling.$DATE.sql; bye" -u $USER,$PASS $FTPHOST

for FILE in `ls $TARGETDIR/*event.$DATE.sql $TARGETDIR/olscheduling.$DATE.sql`
do
	DB=`echo $FILE | /bin/awk -F/ '{print $4}' | awk -F\. '{print $1}'`
	echo "Loading database $DB... (file $FILE)"
	/usr/bin/mysql --password=mobile1 $DB < $FILE > $DB.log 2>&1
done

NOW=`date`
echo "Database load completed at $NOW." | /usr/lib/sendmail rhaney@pbcgov.org
