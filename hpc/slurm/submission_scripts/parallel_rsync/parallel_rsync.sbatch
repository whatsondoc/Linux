#!/bin/bash
#SBATCH --job-name=Parallel_rsync
#SBATCH --output=/path/to/output/%A_%a.out

# Parallel rsync - should be run as a job array, with the array indices being the total number of file lists

PR_TARGET_ROOT_DIR="/path/to/target_root"
PR_SOURCE_ROOT_DIR="/"
PR_FILE_LISTS="/path/to/directory/with/file_lists"

PR_FILE_LIST_ARRAY=( $(find ${PR_FILE_LISTS} -mindepth 1 -maxdepth 1 -name "*parallel_rsync_split*" -type f) )

if [[ ! -d ${PR_TARGET_ROOT_DIR} ]]
then
	echo "Target directory doesn't exist"
	exit 1
fi

echo "
Start time              : $(date)
Operation               : Parallel rsync
File list               : ${PR_FILE_LIST_ARRAY[${SLURM_ARRAY_TASK_ID}]}
Submit directory        : $(pwd)
Number of files			: $( cat ${PR_FILE_LIST_ARRAY[${SLURM_ARRAY_TASK_ID}]} | wc -l)
"

numactl --physcpubind=$(( ${SLURM_ARRAY_TASK_ID} % 32 )) --membind=$(( ${SLURM_ARRAY_TASK_ID} % 2 )) \
    rsync --archive --quiet --files-from=${PR_FILE_LIST_ARRAY[${SLURM_ARRAY_TASK_ID}]} ${PR_SOURCE_ROOT_DIR} ${PR_TARGET_ROOT_DIR}

echo "
End time                : $(date)
"