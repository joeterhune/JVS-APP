#!/bin/sh

rm -f /etc/httpd/conf.d/icms.conf
ln -s /usr/local/icms/etc/icms-apache.conf /etc/httpd/conf.d/icms.conf
/etc/init.d/httpd restart
