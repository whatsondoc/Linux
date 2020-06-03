#!/bin/bash

# Aggregating the checksum calculatuons from the parallel rsync executions:

IFS=$'\n'           # Setting the Internal Field Separator (IFS) to new line, so as to accommodate any files with spaces in the filenames

PRDT_PARALLEL_RSYNC_JOB_ID=${1}

PRDT_PRE_CHECKSUM_LIST_ARRAY=( $(find ${PRDT_OUTPUT_DIR} -mindepth 1 -maxdepth 1 -name "${PRDT_UUID}parallel_rsync_checksum_temp_list-pre*" -type f | sort) )
PRDT_POST_CHECKSUM_LIST_ARRAY=( $(find ${PRDT_OUTPUT_DIR} -mindepth 1 -maxdepth 1 -name "${PRDT_UUID}parallel_rsync_checksum_temp_list-post*" -type f | sort) )

prdt_aggregate_pre_checksum_lists() {
    for PRDT_PRE_CHECKSUM in ${PRDT_PRE_CHECKSUM_LIST_ARRAY[*]}
    do
        cat ${PRDT_PRE_CHECKSUM}
    done >> ${PRDT_TEMP_CHECKSUM_LIST_NAME}pre_total.txt

    echo "Pre checksum aggregated list: $(ls -lh ${PRDT_TEMP_CHECKSUM_LIST_NAME}pre_total.txt)"
    echo
}

prdt_aggregate_post_checksum_lists() {
    for PRDT_POST_CHECKSUM in ${PRDT_POST_CHECKSUM_LIST_ARRAY[*]}
    do
        cat ${PRDT_POST_CHECKSUM}
    done >> ${PRDT_TEMP_CHECKSUM_LIST_NAME}post_total.txt

    echo "Post checksum aggregated list: $(ls -lh ${PRDT_TEMP_CHECKSUM_LIST_NAME}post_total.txt)"
    echo
}

prdt_compare_checksum_lists() {
    echo "Comparing checksum lists:"
	diff --brief --report-identical-files  ${PRDT_TEMP_CHECKSUM_LIST_NAME}pre_total.txt ${PRDT_TEMP_CHECKSUM_LIST_NAME}post_total.txt
    echo
}

prdt_aggregate_rsync_stdout() {
    for PRDT_JOB_ARRAY_TASK_STDOUT in $(find ${PRDT_OUTPUT_DIR} -mindepth 1 -maxdepth 1 -name "${PRDT_UUID}parallel_rsync-${PRDT_PARALLEL_RSYNC_JOB_ID}*")
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

prdt_cleanup_temp_checksum_lists() {
    PRDT_ALL_CHECKSUM_LISTS=( "${PRDT_PRE_CHECKSUM_LIST_ARRAY[*]}" "${PRDT_POST_CHECKSUM_LIST_ARRAY[*]}" )

    for PRDT_DELETE_CHECKSUM_LIST in ${PRDT_ALL_CHECKSUM_LISTS[*]}
    do
        if [[ -f ${PRDT_DELETE_CHECKSUM_LIST} ]]
        then
            rm ${PRDT_DELETE_CHECKSUM_LIST}
        else
            echo "*** ERROR:    Checksum list cannot be enumerated (?)"
        fi
    done
}

echo "
Start time              	    : $(date)
Operation               	    : Aggregating checksum calculations (pre & post)
Slurm Array Job_Task ID		    : ${SLURM_JOB_ID}
Output directory                : ${PRDT_OUTPUT_DIR}
Number of checksum lists (pre)	: ${#PRDT_PRE_CHECKSUM_LIST_ARRAY[*]}
Number of checksum lists (post) : ${#PRDT_POST_CHECKSUM_LIST_ARRAY[*]}
"

prdt_aggregate_pre_checksum_lists

prdt_aggregate_post_checksum_lists

prdt_compare_checksum_lists

prdt_aggregate_rsync_stdout

prdt_cleanup_temp_checksum_lists

echo "
End time                	    : $(date)
"