#!/bin/bash

# Parallel rsync - should be run as a job array, with the array indices being the total number of file lists

PRDT_FILE_LIST_ARRAY=( $(find ${PRDT_OUTPUT_DIR} -mindepth 1 -maxdepth 1 -name "${PRDT_UUID}parallel_rsync_split_temp*" -type f | sort) )

prdt_validation() {
	# Checking rsync exists:
	if [[ ! -d ${PRDT_TARGET_ROOT_DIR} ]]
	then
		echo "*** ERROR:	Target directory doesn't exist"
		exit 1
	fi
}

prdt_pre_transfer_checksums() {
	PRDT_OIFS=${IFS}
	IFS=$'\n'          		 # Setting the Internal Field Separator (IFS) to new line, so as to accommodate any files with spaces in the filenames

	# Cycling through all files in the splitted file list to calculate checksums prior to transfer:
	echo "Calculating checksums at source:"
	for PRDT_CHECKSUM_FILE_PRE in $(cat ${PRDT_FILE_LIST_ARRAY[${SLURM_ARRAY_TASK_ID}]})
	do
		${PRDT_CHECKSUM} ${PRDT_CHECKSUM_FILE_PRE} | awk '{print $1}' >> ${PRDT_TEMP_CHECKSUM_LIST_NAME}pre_${SLURM_ARRAY_TASK_ID}.txt
	done
	echo "Complete: 	$(ls -lh ${PRDT_TEMP_CHECKSUM_LIST_NAME}pre_${SLURM_ARRAY_TASK_ID}.txt)"
	echo

	IFS=${PRDT_OIFS}
}

prdt_execution() {
	PRDT_NUMA="numactl --cpunodebind=$(( ${SLURM_ARRAY_TASK_ID} % 2 )) --membind=$(( ${SLURM_ARRAY_TASK_ID} % 2 ))"
	PRDT_RSYNC="rsync --archive --progress --files-from=${PRDT_FILE_LIST_ARRAY[${SLURM_ARRAY_TASK_ID}]} ${PRDT_SOURCE_ROOT_DIR} ${PRDT_TARGET_ROOT_DIR}"
	#PRDT_COMMAND="${PRDT_NUMA} ${PRDT_RSYNC}"

	#echo "Execution command			: ${PRDT_COMMAND}"
	echo "Execution command - NUMA	: ${PRDT_NUMA}"
	echo "Execution command - rsync	: ${PRDT_RSYNC}"
	echo

	#${PRDT_COMMAND}

	# A temporary workaround for the IFS:
	numactl --cpunodebind=$(( ${SLURM_ARRAY_TASK_ID} % 2 )) --membind=$(( ${SLURM_ARRAY_TASK_ID} % 2 )) \
		rsync --archive --progress --files-from=${PRDT_FILE_LIST_ARRAY[${SLURM_ARRAY_TASK_ID}]} ${PRDT_SOURCE_ROOT_DIR} ${PRDT_TARGET_ROOT_DIR}

	if [[ $? != "0" ]]
	then
		echo "*** ERROR: 	Non-zero exit code from rsync operation"
	fi
	echo;echo
}

prdt_post_transfer_checksums() {
	PRDT_OIFS=${IFS}
	IFS=$'\n'          		 # Setting the Internal Field Separator (IFS) to new line, so as to accommodate any files with spaces in the filenames
	
	# Cycling through all files in the splitted file list to calculate checksums prior to transfer:
	echo "Calculating checksums at target:"
	for PRDT_CHECKSUM_FILE_POST in $(cat ${PRDT_FILE_LIST_ARRAY[${SLURM_ARRAY_TASK_ID}]})
	do
		${PRDT_CHECKSUM} ${PRDT_TARGET_ROOT_DIR}${PRDT_CHECKSUM_FILE_POST} | awk '{print $1}'  >> ${PRDT_TEMP_CHECKSUM_LIST_NAME}post_${SLURM_ARRAY_TASK_ID}.txt
	done
	echo "Complete:		$(ls -lh ${PRDT_TEMP_CHECKSUM_LIST_NAME}post_${SLURM_ARRAY_TASK_ID}.txt)"
	
	echo
	
	echo "Comparing checksums:"
	diff --brief --report-identical-files  ${PRDT_TEMP_CHECKSUM_LIST_NAME}pre_${SLURM_ARRAY_TASK_ID}.txt ${PRDT_TEMP_CHECKSUM_LIST_NAME}post_${SLURM_ARRAY_TASK_ID}.txt
	echo

	IFS=${PRDT_OIFS}
}

prdt_cleanup() {
	echo "Removing file list			: ${PRDT_FILE_LIST_ARRAY[${SLURM_ARRAY_TASK_ID}]}"

	if [[ -f ${PRDT_FILE_LIST_ARRAY[${SLURM_ARRAY_TASK_ID}]} ]]
	then
		rm ${PRDT_FILE_LIST_ARRAY[${SLURM_ARRAY_TASK_ID}]}
	else
		echo "*** ERROR: 	Unable to enumerate file list - though I guess that's obvious by now?"
	fi
	echo
}

echo "
Start time              	: $(date)
Operation               	: Parallel rsync
Compute node				: $(hostname)
Target root directory		: ${PRDT_TARGET_ROOT_DIR}
Slurm Array Job_Task ID		: ${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}
Unique file list path		: ${PRDT_FILE_LIST_ARRAY[${SLURM_ARRAY_TASK_ID}]}
Number of files (in list)	: $( cat ${PRDT_FILE_LIST_ARRAY[${SLURM_ARRAY_TASK_ID}]} | wc -l)
"

prdt_validation

prdt_pre_transfer_checksums

prdt_execution

prdt_post_transfer_checksums

prdt_cleanup

echo "
End time                	: $(date)
"