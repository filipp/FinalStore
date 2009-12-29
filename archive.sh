#!/usr/bin/env bash
# Collect archive asset to a text file
DST="/tmp/finalstore/archive"
if [ ! -d $DST ]; then
	mkdir -p $DST
fi
echo $1 >> "${DST}/$(date +'%s').txt"
exit 0
