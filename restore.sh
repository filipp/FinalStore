#!/usr/bin/env bash
# Collect restore asset to a text file
DST="/tmp/finalstore/restore"
if [ ! -d $DST ]; then
	mkdir -p $DST
fi
echo $1 >> "${DST}/$(date +'%s').txt"
exit 0
