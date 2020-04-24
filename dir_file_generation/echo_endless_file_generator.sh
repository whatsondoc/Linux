#!/bin/bash

TGT_DIR="/path/to/directory/on/target/filesystem"
INDEX=0

while true
do
	echo "Echoing to a file to with some bytes, bytes, bytes, bytes...." >> ${TGT_DIR}/echo_${RANDOM}_file_${RANDOM}-${INDEX}.txt
	((INDEX++))
done

echo "Complete"