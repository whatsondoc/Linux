#!/bin/bash

#TGT_DIR="/path/to/directory/on/target/filesystem"
TGT_DIR="${1}"
if      [[ ! -d ${1} ]]
then    echo "Cannot enumerate target directory [first positional argument to the script]: ${1}"
        exit 1
else    SOURCE_FILE="${TGT_DIR}/source_file.txt"
fi

for i in {0..999}; do echo "Split hey, split ho, it's off to work we go..." >> ${SOURCE_FILE}

cd ${TGT_DIR}

while true
do
    split --lines=1 ${SOURCE_FILE} ${TGT_DIR}/prefix_${RANDOM}
done

echo "Complete"     # This is, of course, fool's gold... 