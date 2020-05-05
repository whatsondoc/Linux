#!/bin/bash

SOURCE_DIR="/path/to/source/directory"

TARGET_DIR="/path/to/target/directory"

THREAD_COUNT="8"

COPY_COMMAND="rsync -a ${ALL_FILES[${FILE_INDEX}]} ${TARGET_DIR}"

#=============================================================

ALL_FILES=( $(find ${SOURCE_DIR} -mindepth 1) )
CPU_CORES=$(( $(nproc --all) - 1 ))
FILE_INDEX="0"

while true
do
    for CORE in $(seq 0 ${CPU_CORES} )
    do
        if [[ ${FILE_INDEX} -le ${#ALL_FILES[*]} ]]
        then
            if [[ $(ps -e -o psr,cmd | awk -v aCPU=${CORE} '$1==aCPU' | awk '$2=="rsync"' | wc -l) -lt ${THREAD_COUNT} ]]
            then
                taskset -c ${CORE} ${COPY_COMMAND} &
                ((FILE_INDEX++))
                #sleep 0.1s
            fi
        else
            echo "Finished: ${FILE_INDEX} files transferred"
            exit 0
        fi
    done
done