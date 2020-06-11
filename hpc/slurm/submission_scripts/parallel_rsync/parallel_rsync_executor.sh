#!/bin/bash

set -e					# Setting exit on error to prevent data from being sent if checksums cannot be calculated at source, or continuation if unable to validate at the target

# Parallel rsync - should be run as a job array, with the array indices being the total number of file lists

IFS=$'\n'				# Setting the Internal Field Separator (IFS) to new line, so as to accommodate any files with spaces in the filenames


#==============================================================================================================================================================================
# FUNCTIONS

prdt_large_array_support_executor() {
	echo
	echo "INFO:		Large Array Support is enforcing ---> sleeping for $(( ${SLURM_ARRAY_TASK_ID} % 60 )) seconds to smooth I/O"
	sleep $(( ${SLURM_ARRAY_TASK_ID} % 60 ))
	
	# Other customised settings to tune/optimise for back-end storage
	#STRIPE_WIDTH=abc
	#OFFSET=def
	#BUFFER=ghi
	#...
}

prdt_validation() {
	# Checking the target directory exists:
	if [[ ! -d ${PRDT_TARGET_ROOT_DIR} ]]
	then
		echo "*** ERROR:	Target directory doesn't exist"
		exit 1
	fi
}

prdt_pre_transfer_checksums() {
	# Cycling through all files in the splitted file list to calculate checksums prior to transfer:
	echo "INFO		: Calculating checksums at source ..."

	PRDT_MEM_FILE_PRE="/dev/shm/$(basename ${PRDT_TEMP_CHECKSUM_LIST_NAME})pre_${SLURM_ARRAY_TASK_ID}.txt"

	for PRDT_CHECKSUM_FILE_PRE in $(cat ${PRDT_FILE_LIST})
	do
		${PRDT_CHECKSUM} ${PRDT_CHECKSUM_FILE_PRE} | awk '{print $1}' >> ${PRDT_MEM_FILE_PRE}
		#${PRDT_CHECKSUM} ${PRDT_CHECKSUM_FILE_PRE} | awk '{print $1}' >> ${PRDT_TEMP_CHECKSUM_LIST_NAME}pre_${SLURM_ARRAY_TASK_ID}.txt
	done
	echo "INFO		: Complete ---> $(ls -lk ${PRDT_MEM_FILE_PRE})"
	echo
}

prdt_execution() {
	PRDT_NUMA="numactl --cpunodebind=$(( ${SLURM_ARRAY_TASK_ID} % 2 )) --membind=$(( ${SLURM_ARRAY_TASK_ID} % 2 ))"
	PRDT_RSYNC="rsync --archive --progress --files-from=${PRDT_FILE_LIST} ${PRDT_SOURCE_ROOT_DIR} ${PRDT_TARGET_ROOT_DIR}"
	#PRDT_COMMAND="${PRDT_NUMA} ${PRDT_RSYNC}"

	#echo "Execution command			: ${PRDT_COMMAND}"
	echo "Execution command - NUMA	: ${PRDT_NUMA}"
	echo "Execution command - rsync	: ${PRDT_RSYNC}"
	echo

	#${PRDT_COMMAND}

	# A temporary workaround for the IFS:
	numactl --cpunodebind=$(( ${SLURM_ARRAY_TASK_ID} % 2 )) --membind=$(( ${SLURM_ARRAY_TASK_ID} % 2 )) \
		rsync --archive --progress --files-from=${PRDT_FILE_LIST} ${PRDT_SOURCE_ROOT_DIR} ${PRDT_TARGET_ROOT_DIR}

	if [[ $? != "0" ]]
	then
		echo "*** ERROR: 	Non-zero exit code from rsync operation"
	fi
	echo;echo
}

prdt_post_transfer_checksums() {
	# Cycling through all files in the splitted file list to calculate checksums prior to transfer:
	echo "INFO		: Calculating checksums at target ..."

	PRDT_MEM_FILE_POST="/dev/shm/$(basename ${PRDT_TEMP_CHECKSUM_LIST_NAME})post_${SLURM_ARRAY_TASK_ID}.txt"

	for PRDT_CHECKSUM_FILE_POST in $(cat ${PRDT_FILE_LIST})
	do
		${PRDT_CHECKSUM} ${PRDT_TARGET_ROOT_DIR}${PRDT_CHECKSUM_FILE_POST} | awk '{print $1}'  >> ${PRDT_MEM_FILE_POST}
		#${PRDT_CHECKSUM} ${PRDT_TARGET_ROOT_DIR}${PRDT_CHECKSUM_FILE_POST} | awk '{print $1}'  >> ${PRDT_TEMP_CHECKSUM_LIST_NAME}post_${SLURM_ARRAY_TASK_ID}.txt
	done
	echo "INFO		: Complete ---> $(ls -lk ${PRDT_MEM_FILE_POST})"
	echo
	
	echo "INFO		: Comparing checksums:"
	diff --brief --report-identical-files ${PRDT_MEM_FILE_PRE} ${PRDT_MEM_FILE_POST}
	echo
}

prdt_cleanup() {
	echo "INFO		: Moving checksum files to: $(dirname ${PRDT_TEMP_CHECKSUM_LIST_NAME})"
	mv ${PRDT_MEM_FILE_PRE} $(dirname ${PRDT_TEMP_CHECKSUM_LIST_NAME})
	mv ${PRDT_MEM_FILE_POST} $(dirname ${PRDT_TEMP_CHECKSUM_LIST_NAME})

	echo "INFO		: Removing file list ---> ${PRDT_FILE_LIST}"
	if [[ -f ${PRDT_FILE_LIST} ]]
	then
		rm ${PRDT_FILE_LIST}
	else
		echo "*** ERROR: 	Unable to enumerate file list - though I guess that's obvious by now?"
	fi
	echo
}


#==============================================================================================================================================================================
# EXECUTION

# Checking whether Large Array Support is enabled:
if [[ ${PRDT_LARGE_ARRAY_SUPPORT} == "ENFORCING" ]]
then
	prdt_large_array_support_executor
fi

PRDT_FILE_LIST=$(sed -n ${SLURM_ARRAY_TASK_ID}p $(dirname ${PRDT_TEMP_RSYNC_FILE_LIST_NAMES})/${PRDT_CENTRAL_FILE_LIST_MAP})
#PRDT_FILE_LIST_ARRAY=( $(find $(dirname ${PRDT_TEMP_RSYNC_FILE_LIST_NAMES}) -mindepth 1 -maxdepth 1 -name "$(basename ${PRDT_TEMP_RSYNC_FILE_LIST_NAMES})*" -type f | sort) )
#PRDT_FILE_LIST_ARRAY=( $(find ${PRDT_OUTPUT_DIR} -mindepth 1 -maxdepth 1 -name "${PRDT_UUID}parallel_rsync_split_temp*" -type f | sort) )

echo "
Start time              		: $(date)
Operation               		: Parallel rsync execution
Compute node					: $(hostname)
Target root directory			: ${PRDT_TARGET_ROOT_DIR}
Slurm Array Job_Task ID			: ${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}
Unique file list path			: ${PRDT_FILE_LIST}
Number of files (in list)		: $(cat ${PRDT_FILE_LIST} | wc -l)

Printing relevant environment	:
$(env | egrep 'SLURM|PRDT' | sort)
"

prdt_validation

prdt_pre_transfer_checksums

prdt_execution

prdt_post_transfer_checksums

prdt_cleanup

echo "
End time                	: $(date)
"