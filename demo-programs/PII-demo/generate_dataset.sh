#!/bin/bash

DATASET_BASE="/mnt/nfs/rockyheights"
NAME_FILE="/home/${USER}/PII-Demo/.NAME"

if	[[ ! -f "${NAME_FILE}" ]]
then	echo "Hidden PII .NAME file not present in this directory - exiting..."
        exit 1
fi

if 	[[ ! -d "${DATASET_BASE}" ]]
then 	echo "Base directory cannot be enumerated: ${DATASET_BASE}"
        echo "Exiting ..."
        exit 1
else    if      [[ ! -d "${DATASET_BASE}/dataset" ]]
        then    mkdir ${DATASET_BASE}/dataset
                DATASET_PATH="${DATASET_BASE}/dataset"
        fi
fi

for 	DIR in {1..59}
do	RANDSTR=$(openssl rand -hex 6)
	mkdir ${DATASET_PATH}/${RANDSTR}
        mkdir ${DATASET_PATH}/${RANDSTR}/subdir_{1..39}
        touch ${DATASET_PATH}/${RANDSTR}/subdir_{1..39}/file_{1..99}.txt
    
        for     FILE in {1..100}
        do      if	(( ${RANDOM} % 25 < 5 ))
                then	SUB_DIR_NUM=$(shuf -i 1-39 -n 1)
                        FILE_NUM=$(shuf -i 1-99 -n 1)
                        PII_NAME=$(sed -n "$(shuf -i 1-500 -n 1)p" .NAME)
                        echo "${PII_NAME}" >> ${DATASET_PATH}/${RANDSTR}/subdir_${SUB_DIR_NUM}/file_${FILE_NUM}.txt
                fi
        done
done