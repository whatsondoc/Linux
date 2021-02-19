#!/bin/bash

#TGT_DIR="/path/to/directory/on/target/filesystem"
TGT_DIR="${1}"
if      [[ ! -d ${1} ]]
then    echo "Cannot enumerate target directory [first positional argument to the script]: ${1}"
        exit 1
else    SOURCE_FILE="${TGT_DIR}/source_file.txt"
fi

for     LINE in {0..999}
do      echo "Split hey, split ho, it's off to work we go..." >> ${SOURCE_FILE}
done

cd ${TGT_DIR}
INDEX=0

echo
echo "Date:  $(date +%Y-%m-%d---%H-%M-%S)"
echo
echo "Starting creation ..."
echo

while true
do
    if      (( ${INDEX} % 50 ))
    then    echo "$(date +%Y-%m-%d---%H-%M-%S)   Files:  ${INDEX}"
    fi
    split --lines=1 ${SOURCE_FILE} ${TGT_DIR}/prefix_${RANDOM}
    ((INDEX++))
done

echo "Complete"     # This is, of course, fool's gold... 