#!/bin/bash

DATASET_PATH="/mnt/nfs/rockyheights"
NAME_FILE="/home/${USER}/PII-Demo/.NAME"

OUTPUT="/home/${USER}/PII-Demo/PII-output.txt"

echo ""
echo "--------------------"
echo "PII Scan: [Starting]"
echo "--------------------"
echo ""
echo "Dataset path              :  ${DATASET_PATH}"
echo ""

FILE_COUNT=0
BREACH_COUNT=0

for     SCAN_FILE in $(find ${DATASET_PATH} -type f)
do      STATE=$(egrep "$(cat ${NAME_FILE})" ${SCAN_FILE})
        if      [[ -n ${STATE} ]]
        then    echo -e "*** PII Match: ${STATE}\t\t|\t\t${SCAN_FILE}"
                echo -e "*** PII Match: ${STATE}\t\t|\t\t${SCAN_FILE}" >> ${OUTPUT}
                ## <METADATA_FUNCTION_ADD> PII_BREACH ${SCAN_FILE}
                ((BREACH_COUNT++))
        fi
        ((FILE_COUNT++))
done

echo ""
echo "Total Files scanned       :  ${FILE_COUNT}"
echo "Detected PII Breaches     :  ${BREACH_COUNT}"
echo ""
echo "--------------------"
echo "PII Scan: [Complete]"
echo "--------------------"
echo ""