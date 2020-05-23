#!/bin/bash

WORKING_DIR="/path/to/working/directory"

STATE=0
INDEX=0
COUNTER=0

INPUT_LIST=${1}

[[ ! -f ${1} ]]  &&  echo "No file list provided - exiting..."  &&  exit 1

split --number=l/$(nproc --all) ${INPUT_LIST} ${WORKING_DIR}/calcsize_split_file_list-

for SPLIT_FILE_LIST in $(ls ${WORKING_DIR}/calcsize_split_file_list-*)
do
	for FILE in $(cat ${SPLIT_FILE_LIST})
	do 
		STATE=$(stat -c %s ${FILE})
		if [[ ${?} == "0" ]]
		then
			INDEX=$(( ${INDEX} + ${STATE} ))
		else
			echo ${FILE} >> ${WORKING_DIR}/calcsize_failed_stats.txt
		fi

		STATE=0

		if [[ $(( ${COUNTER} % 1000 )) == "0" ]]
		then
			echo "${SPLIT_FILE_LIST}:  ${INDEX}" >> ${WORKING_DIR}/calcsize_stat_progress.txt
		fi
	done &
done

wait

rm ${WORKING_DIR}/calcsize_*