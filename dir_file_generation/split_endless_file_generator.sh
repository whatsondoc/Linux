#!/bin/bash

TGT_DIR="/path/to/directory/on/target/filesystem"

SOURCE_FILE=$(for i in {0..999}; do echo "Split hey, split ho, it's off to work we go..." >> ${TGT_DIR}/source_file.txt)

cd ${TGT_DIR}

while true
do
    split --lines=1 ${TGT_DIR}/source_file.txt ${TGT_DIR}/prefix_${RANDOM}
done

echo "Complete"     # This is, of course, fool's gold... 