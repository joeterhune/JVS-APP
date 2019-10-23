#!/bin/bash

if [ -e /tmp/.imagetimeout ]
then
    /bin/umount -f /mnt/images
    /bin/mount /mnt/images
    rm -f /tmp/.imagetimeout
    DATE=`/bin/date`
    echo "Fixed image mount at $DATE" >> /tmp/imagefix.out
fi
