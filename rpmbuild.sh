#!/bin/sh
_APP='jvs'
_REVISION=`svn info . | grep -m 1 'Revision:' | grep -o '[0-9]*$'`
_URL=`svn info . | grep URL:`
_ARCH=noarch
_BASEDIR=`pwd`
_VERSION=1.0

cd $_BASEDIR
sed "s/^%define name .*$/%define name $_APP/" $_APP.spec.template > $_APP.spec
sed -i "s/^%define version .*$/%define version $_VERSION/" $_APP.spec
sed -i "s/^%define buildnumber .*$/%define buildnumber $_REVISION/" $_APP.spec
sed -i "s/^%define arch .*$/%define arch $_ARCH/" $_APP.spec

rpmbuild -ba $_APP.spec
