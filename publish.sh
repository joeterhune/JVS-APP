#!/bin/sh
_APP='jvs'
_REVISION=`svn info . | grep -m 1 'Revision:' | grep -o '[0-9]*$'`
_URL=`svn info . | grep URL:`
_ARCH=noarch
_BASEDIR=`pwd`
_VERSION=1.0

rsync -avz $HOME/rpm/RPMS/$_ARCH/$_APP-$_VERSION-$_REVISION.$_ARCH.rpm root@mrepo:/var/mrepo/cto-local-$_ARCH/local
ssh root@mrepo "chown -R root:root /var/mrepo/cto-local-$_ARCH/local/; mrepo -g cto-local"

