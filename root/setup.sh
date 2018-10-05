#!/bin/bash

if [ -f /root/.ssh/known_hosts.rpmnew ]; then
        mv /root/.ssh/known_hosts.rpmnew /root/.ssh/known_hosts
fi

# Get the IP address of eth0
IP=`ifconfig eth0 | grep 'inet addr' | awk '{print $2}' | awk -F: '{print $2}'`

echo
echo
while [ -z "$hn" ]; do
	read -p "Please enter the full hostname:" hn
	echo
done

echo
echo "Setting hostname to '$hn'..."

sed -i '/^HOSTNAME=/d' /etc/sysconfig/network
echo "HOSTNAME=$hn" >> /etc/sysconfig/network

hostname $hn

sed -i "/^$IP/d" /etc/hosts
echo "$IP	$hn" >> /etc/hosts

echo "Copying reports files from 151.132.36.91 (this will take a bit)..."

rsync -aqz icms-dev.15thcircuit.com:/var/www/Palm /var/www

sed -i "s/icms-dev.15thcircuit.com/$hn/g" /usr/local/icms/etc/icms-apache.conf

service httpd restart

echo "Done!"
