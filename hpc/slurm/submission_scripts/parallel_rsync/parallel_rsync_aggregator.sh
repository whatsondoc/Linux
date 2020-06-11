#!/bin/bash

# Aggregating the checksum calculatuons from the parallel rsync executions:

IFS=$'\n'           # Setting the Internal Field Separator (IFS) to new line, so as to accommodate any files with spaces in the filenames

PRDT_PARALLEL_RSYNC_JOB_ID=${1}


#=====================================================================================================================================================================================================================================================================
# FUNCTIONS

prdt_aggregate_pre_checksum_lists() {
    PRDT_PRE_CHECKSUM_LIST_ARRAY=( $(find $(dirname ${PRDT_TEMP_CHECKSUM_LIST_NAME}) -mindepth 1 -maxdepth 1 -name "$(basename ${PRDT_TEMP_CHECKSUM_LIST_NAME})pre*" -type f | sort) )
    
    for PRDT_PRE_CHECKSUM in ${PRDT_PRE_CHECKSUM_LIST_ARRAY[*]}
    do
        cat ${PRDT_PRE_CHECKSUM}
    done >> ${PRDT_TEMP_CHECKSUM_LIST_NAME}pre_total.txt

    echo "INFO      : Pre-checksum aggregated list ---> $(ls -lh ${PRDT_TEMP_CHECKSUM_LIST_NAME}pre_total.txt)"
    echo

    for PRDT_DELETE_PRE_CHECKSUM_LIST in ${PRDT_PRE_CHECKSUM_LIST_ARRAY[*]}
    do
        if [[ -f ${PRDT_DELETE_PRE_CHECKSUM_LIST} ]]
        then
            rm ${PRDT_DELETE_PRE_CHECKSUM_LIST}
        else
            echo "*** ERROR:    Checksum list cannot be enumerated (?) --> ${PRDT_DELETE_PRE_CHECKSUM_LIST}"
        fi
    done
}

prdt_aggregate_post_checksum_lists() {
    PRDT_POST_CHECKSUM_LIST_ARRAY=( $(find $(dirname ${PRDT_TEMP_CHECKSUM_LIST_NAME}) -mindepth 1 -maxdepth 1 -name "$(basename ${PRDT_TEMP_CHECKSUM_LIST_NAME})post*" -type f | sort) )

    for PRDT_POST_CHECKSUM in ${PRDT_POST_CHECKSUM_LIST_ARRAY[*]}
    do
        cat ${PRDT_POST_CHECKSUM}
    done >> ${PRDT_TEMP_CHECKSUM_LIST_NAME}post_total.txt

    echo "INFO      : Post-checksum aggregated list ---> $(ls -lh ${PRDT_TEMP_CHECKSUM_LIST_NAME}post_total.txt)"
    echo

    for PRDT_DELETE_POST_CHECKSUM_LIST in ${PRDT_POST_CHECKSUM_LIST_ARRAY[*]}
    do
        if [[ -f ${PRDT_DELETE_POST_CHECKSUM_LIST} ]]
        then
            rm ${PRDT_DELETE_POST_CHECKSUM_LIST}
        else
            echo "*** ERROR:    Checksum list cannot be enumerated (?) --> ${PRDT_DELETE_POST_CHECKSUM_LIST}"
        fi
    done
}

prdt_compare_checksum_lists() {
    echo "INFO      : Comparing checksum lists:"
	diff --brief --report-identical-files  ${PRDT_TEMP_CHECKSUM_LIST_NAME}pre_total.txt ${PRDT_TEMP_CHECKSUM_LIST_NAME}post_total.txt

    if [[ ! -s ${PRDT_TEMP_CHECKSUM_LIST_NAME}pre_total.txt ]]
    then
        echo "*** WARNING:      This file is empty: ${PRDT_TEMP_CHECKSUM_LIST_NAME}pre_total.txt"
    fi

    if [[ ! -s ${PRDT_TEMP_CHECKSUM_LIST_NAME}post_total.txt ]]
    then
        echo "*** WARNING:      This file is empty: ${PRDT_TEMP_CHECKSUM_LIST_NAME}post_total.txt"
    fi

    echo
}

prdt_aggregate_rsync_stdout() {
    for PRDT_JOB_ARRAY_TASK_STDOUT in $(find $(dirname ${PRDT_JOB_ARRAY_OUTPUT}) -mindepth 1 -maxdepth 1 -name "${PRDT_UUID}parallel_rsync-${PRDT_PARALLEL_RSYNC_JOB_ID}*")
    do
        if [[ -f ${PRDT_JOB_ARRAY_TASK_STDOUT} ]]
        then
            echo                                >> ${PRDT_STDOUT}
            echo "----------------------------" >> ${PRDT_STDOUT}
            cat ${PRDT_JOB_ARRAY_TASK_STDOUT}   >> ${PRDT_STDOUT}
            echo                                >> ${PRDT_STDOUT}

            rm ${PRDT_JOB_ARRAY_TASK_STDOUT}
        else
            echo "*** ERROR:    Parallel rsync stdout cannot be enumerated (?)"
        fi
    done
}


#=====================================================================================================================================================================================================================================================================
# EXECUTION

echo "
Start time              	    : $(date)
Operation               	    : Aggregating checksum calculations (pre & post)
Slurm Array Job_Task ID		    : ${SLURM_JOB_ID}
Output directory                : ${PRDT_OUTPUT_DIR}
Number of checksum lists (pre)	: ${#PRDT_PRE_CHECKSUM_LIST_ARRAY[*]}
Number of checksum lists (post) : ${#PRDT_POST_CHECKSUM_LIST_ARRAY[*]}

Printing related environment:
$(env | egrep 'SLURM|PRDT' | sort)
"

prdt_aggregate_pre_checksum_lists

prdt_aggregate_post_checksum_lists

prdt_compare_checksum_lists

prdt_aggregate_rsync_stdout

#prdt_cleanup_temp_checksum_lists

echo "
End time                	    : $(date)
"