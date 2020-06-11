#!/bin/bash

# Parallel find array submission
# To be submitted as part of a job array from 'parallel_find_launcher.sh'
# Edit the <PATTERN_n> strings to set the desired match criteria (or edit the syntax as necessary)

# If launching independently from 'parallel_find_launcher.sh', set & uncomment the following variables:
#PFCS_ROOT_PATH="/path/to/root/dir"
#PFCS_PATH_DEPTH="4"
PFCS_NUMA_DOMAINS=2
PFCS_NODE_CORES=32

#------------------------------------------------------------------------

pfcs_top_level_directory_find() {
    numactl --physcpubind=$(( ${SLURM_JOB_ID} % ${PFCS_NODE_CORES} )) --membind=$(( ${SLURM_JOB_ID} % ${PFCS_NUMA_DOMAINS} )) \
        find ${PFCS_ROOT_PATH} -mindepth 1 -maxdepth $(( ${PFCS_PATH_DEPTH} - 1 )) -type f \( ${PFCS_SEARCH_STRING_INCLUDE} \) \( ${PFCS_SEARCH_STRING_EXCLUDE} \) 2> /dev/null
}

pfcs_low_level_directory_find() {
    PFCS_PARALLEL_DIRS=( $(find ${PFCS_ROOT_PATH} -maxdepth ${PFCS_PATH_DEPTH} -mindepth ${PFCS_PATH_DEPTH} -type d -not -path "*.Trash*" 2> /dev/null) )

    numactl --physcpubind=$(( ${SLURM_ARRAY_TASK_ID} % ${PFCS_NODE_CORES} )) --membind=$(( ${SLURM_ARRAY_TASK_ID} % ${PFCS_NUMA_DOMAINS} )) \
        find ${PFCS_PARALLEL_DIRS[${SLURM_ARRAY_TASK_ID}]} -type f \( ${PFCS_SEARCH_STRING_INCLUDE} \) \( ${PFCS_SEARCH_STRING_EXCLUDE} \) 2> /dev/null
}


if      [[ ${1} == "TOP" ]]
then
    pfcs_top_level_directory_find

elif    [[ ${1} == "LOW" ]]
then
    pfcs_low_level_directory_find

else
    echo "*** ERROR:    Incorrect parameter passed to the script: ${1}"
fi

echo