#!/bin/bash

#------------------------------------------------------------
## A sample script to work with the prefetch_caching program:
## -- We loop through the newly produced file list performing a SHA512 checksum
## -- We sleep for a short period after the checksum calculates (to simulate a longer processing time)
## -- We remove the file that's just been processed
## -- We then work on the next file in sequence (which has already been prefetched)

[[ $# != "1" ]]   &&   echo "Argument required - please provide a file list as input"  &&   exit 1

#SHM_FILE_LIST=$(cat ${SLURM_JOB_NAME}.pipe)

echo
echo ----
echo "Beginning the processing loop: "

SHM_FILE_LEN=$(cat ${1} | wc -l)

for FILE in $(cat ${1})
do
    echo "Copying the contents of ${FILE} to /dev/null:"
	dd if=${FILE} of=/dev/null bs=4k
   	sleep 10
   	rm ${FILE}
done

rm ${1}

echo -e "\vTask complete - ${SHM_FILE_LEN} files processed.\n"
