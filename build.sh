#!/bin/sh

BUILDDIR=$HOME/rpm/BUILD/jvs/trunk

REVISION="HEAD"

while getopts r: o
do
	case "$o" in
	r) 	REVISION="$OPTARG";;
	esac
done

echo "REVISION: $REVISION"

cd $BUILDDIR && svn update -r $REVISION 
./rpmbuild.sh
RES=$?

if [ $RES == 0 ]; then
	./publish.sh
fi
