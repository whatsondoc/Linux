#!/bin/bash

# Wrapper script to launch parallel Find, file list aggregation & calculate total size from file list input
# Intended to be used with Slurm, leveraging job arrays
# This launcher script will submit Slurm job array for the parllel find execution, and dependencies for the aggregation and size calculation tasks 

export PFCS_SEARCH_STRING_INCLUDE=" -name "*<PATTERN_1>*" -or -iname "*<PATTERN_2>*" -and -iname "*<PATTERN_3>*" "
export PFCS_SEARCH_STRING_EXCLUDE=" -not -name "*<PATTERN_4>*" "

export PFCS_UUID="${RANDOM}_"       # The underscore '_' is intentional, as it separates the random integer generated from other characters in names. Comment this variable out to not use a unique identifier.

PFCS_PAR_FIND_SCRIPT="/path/to/parallel_find_executor.sh"
PFCS_AGGREGATOR_SCRIPT="/path/to/parallel_find_aggregator.sh"
PFCS_CALC_SIZE_SCRIPT="/path/to/calculate_size.sh"

export PFCS_OUTPUT_DIR="/path/to/output/directory"
export PFCS_WORKING_LOG="${PFCS_OUTPUT_DIR}/${PFCS_UUID}stdout_output.log"

export PFCS_ROOT_PATH="/path/to/root/from/where/to/find"
export PFCS_PATH_DEPTH="4"

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

pfcs_slurm_submit() {
    PFCS_PAR_FIND_TOP_SUBMIT=$(sbatch --job-name=${PFCS_UUID}parallel_find_unit_top --output=${PFCS_OUTPUT_DIR}/%x-%A_%a.out ${PFCS_PAR_FIND_SCRIPT} TOP)
    PFCS_PAR_FIND_TOP_JOB_ID=$( echo ${PFCS_PAR_FIND_TOP_SUBMIT} | awk '{print $4}')

    echo "Parallel Find - Top     : ${PFCS_PAR_FIND_TOP_SUBMIT}"

    for PFCS_TOP_JOB_ID in $(scontrol show job ${PFCS_PAR_FIND_TOP_JOB_ID} | grep JobId | awk '{print $1}' | cut -f2 -d '=')
    do  
        PFCS_ARRAY_JOB_IDS=${PFCS_ARRAY_JOB_IDS}:${PFCS_TOP_JOB_ID}
    done

    PFCS_PAR_FIND_LOW_SUBMIT=$(sbatch --array=0-$(( ${PFCS_NUM_DIRS} - 1 )) --job-name=${PFCS_UUID}parallel_find_unit_low --output=${PFCS_OUTPUT_DIR}/%x-%A_%a.out ${PFCS_PAR_FIND_SCRIPT} LOW)
    PFCS_PAR_FIND_LOW_JOB_ID=$( echo ${PFCS_PAR_FIND_LOW_SUBMIT} | awk '{print $4}')

    echo "Parallel Find - Low     : ${PFCS_PAR_FIND_LOW_SUBMIT}"

    for PFCS_LOW_JOB_ID in $(scontrol show job ${PFCS_PAR_FIND_LOW_JOB_ID} | grep JobId | awk '{print $1}' | cut -f2 -d '=')
    do  
        PFCS_ARRAY_JOB_IDS=${PFCS_ARRAY_JOB_IDS}:${PFCS_LOW_JOB_ID}
    done

    PFCS_AGGREGATOR_SUBMIT=$(sbatch --dependency=afterany${PFCS_ARRAY_JOB_IDS} --job-name=${PFCS_UUID}parallel_find_aggregation --output=${PFCS_OUTPUT_DIR}/%x-%j.out ${PFCS_AGGREGATOR_SCRIPT})
    PFCS_AGGREGATOR_JOB_ID=$( echo ${PFCS_AGGREGATOR_SUBMIT} | awk '{print $4}')

    echo "Aggregator              : ${PFCS_AGGREGATOR_SUBMIT}"

    PFCS_CALC_SIZE_SUBMIT=$(sbatch --exclusive --dependency=afterany:${PFCS_AGGREGATOR_JOB_ID} --job-name=${PFCS_UUID}calculate_size --output=${PFCS_OUTPUT_DIR}/%x-%j.out ${PFCS_CALC_SIZE_SCRIPT} ${PFCS_OUTPUT_DIR}/${PFCS_UUID}parallel_find_aggregation-${PFCS_AGGREGATOR_JOB_ID}.out)

    echo "Calculate Size          : ${PFCS_CALC_SIZE_SUBMIT}"

    echo
}

echo "
Date                    : $(date)
Operation               : Parallel find to create file list
Root path               : ${PFCS_ROOT_PATH}
Path depth              : ${PFCS_PATH_DEPTH}
Output file path        : ${PFCS_OUTPUT_DIR}
Unique identifier       : ${PFCS_UUID}

Calculating directory count ..." | tee -a ${PFCS_WORKING_LOG}

PFCS_NUM_DIRS=$(find ${PFCS_ROOT_PATH} -mindepth ${PFCS_PATH_DEPTH} -maxdepth ${PFCS_PATH_DEPTH} -type d -not -path "*.Trash*" 2> /dev/null | wc -l)

echo "Number of directories   : ${PFCS_NUM_DIRS}
" | tee -a ${PFCS_WORKING_LOG}

pfcs_slurm_submit | tee -a ${PFCS_WORKING_LOG}

echo | tee -a ${PFCS_WORKING_LOG}