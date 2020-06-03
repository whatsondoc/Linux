#!/bin/bash

# Parallel rsync wrapper - takes an input and creates the execution environment to facilitate parallelised data transfers
# PRDT = Parallel Rsync Data Transfer

export PRDT_TARGET_ROOT_DIR="/path/to/target_root"                                                                      # In other words: where is the data going to be written to?
export PRDT_OUTPUT_DIR="/path/to/directory/to/store/temporary/file_lists"                                               # Should be in a shared filesystem location, as Slurm tasks will need to read these file lists
PRDT_RSYNC_EXECUTOR="/path/to/rsync/executor.sh"                                                                        # The path to the rsync execution script, which will run on each Slurm task
PRDT_CHECKSUM_AGGREGATOR="/path/to/checksum/aggregator.sh"                                                              # The path to the rsync aggregation script, which will run after the job array completes to aggregate checksums
PRDT_RANGE="50"                                                                                                         # Declaring the width of the parallelisation, i.e. how many separate processes will be spawned for data transfer, e.g. 100 will create a job array with indices of 0-99

export PRDT_SOURCE_ROOT_DIR="/"                                                                                         # It's unlikely this will need to change, but if the input file list is not the fully qualified path you should prefix the root directory here
export PRDT_UUID="${RANDOM}_"                                                                                           # A unique number to differentiate the various runs
export PRDT_TEMP_RSYNC_FILE_LIST_NAMES="${PRDT_OUTPUT_DIR}/${PRDT_UUID}parallel_rsync_split_temp_file_list-"            # The name prefix of the temporary "splitted" file lists. Each splitted file list will be deleted after (or not, as per the executor script)
export PRDT_CHECKSUM="sha512sum"                                                                                        # To include integrity validation, checksums will be performed before and after transfer. The field determines the program used to calculate the checksums 
export PRDT_TEMP_CHECKSUM_LIST_NAME="${PRDT_OUTPUT_DIR}/${PRDT_UUID}parallel_rsync_checksum_temp_list-"                 # Checksum values will be persistently stored so as they can be reviewed by both this framework, and further analysis if necessary. The file path will not be included in the output for easier comparison
export PRDT_STDOUT="${PRDT_OUTPUT_DIR}/${PRDT_UUID}parallel_rsync_wrapper.out"                                          # Where the stdout of the wrapper will be written to, in addition to the terminal, and will have all job array elements' stdout appended to it during aggregation
PRDT_INPUT_LIST="${1}"                                                                                                  # Using the first positional argument, but it's perfectly acceptable to provide the path here instead


prdt_validation() {
    # Checking a single argument is provided, and that the file list exists:
    if      [[ ${#} != "1" ]]
    then
            echo "*** ERROR:    Invalid number of arguments passed to the launcher - exiting..."
            echo "Arguments provided: ${@}"
            exit 1
    elif    [[ ! -f ${PRDT_INPUT_LIST} ]]
    then
            echo "*** ERROR:    The launcher cannot continue as the file list provided cannot be enumerated"
            echo "File list provided: ${PRDT_INPUT_LIST}"
            exit 1
    fi

    # Checking the target root exists:
    if [[ ! -d ${PRDT_TARGET_ROOT_DIR} ]]
    then
	    echo -e "\nTarget path does not exist - creating now..."
	    mkdir -p ${PRDT_TARGET_ROOT_DIR}
    fi

    # Removing a trailing slash on the directories (if placed):
    PRDT_DIR_SLASH=$(echo ${PRDT_TARGET_ROOT_DIR: -1})
    if [[ ${PRDT_DIR_SLASH} == '/' ]]
    then 
	    export PRDT_TARGET_ROOT_DIR=$(echo ${PRDT_TARGET_ROOT_DIR} | sed s'/.$//')
    fi
}

prdt_file_list_split() {
    split --number=l/${PRDT_RANGE} -d --suffix-length=6 ${PRDT_INPUT_LIST} ${PRDT_TEMP_RSYNC_FILE_LIST_NAMES}
}

prdt_submit_sbatch() {
    # Submitting the main parallelised rsync as a job array:
    PRDT_PARALLEL_RSYNC_SUBMIT=$(sbatch --array=0-$(( ${PRDT_RANGE} - 1 )) --job-name=${PRDT_UUID}parallel_rsync --output=${PRDT_OUTPUT_DIR}/%x-%A_%a.out --error=${PRDT_OUTPUT_DIR}/%x-%A_%a.out ${PRDT_RSYNC_EXECUTOR})
    PRDT_PARALLEL_RSYNC_JOB_ID=$( echo ${PRDT_PARALLEL_RSYNC_SUBMIT} | awk '{print $4}')
    
    for PRDT_JOB_ID in $(scontrol show job ${PRDT_PARALLEL_RSYNC_JOB_ID} | grep JobId | awk '{print $1}' | cut -f2 -d '=')
    do  
        PRDT_ARRAY_JOB_IDS=${PRDT_ARRAY_JOB_IDS}:${PRDT_JOB_ID}
    done

    echo "${PRDT_PARALLEL_RSYNC_SUBMIT}"

    # Submitting the checksum aggregator:
    sbatch --dependency=afterany${PRDT_ARRAY_JOB_IDS} --job-name=${PRDT_UUID}aggregator --output=${PRDT_OUTPUT_DIR}/%x-%j.out ${PRDT_CHECKSUM_AGGREGATOR} ${PRDT_PARALLEL_RSYNC_JOB_ID}
}


echo "
Start time              : $(date)
Operation               : Setting up the parallel rsync execution
Target directory path   : ${PRDT_TARGET_ROOT_DIR}
Input file list         : ${PRDT_INPUT_LIST}
Number of files			: $( cat ${PRDT_INPUT_LIST} | wc -l)
Parallelisation range   : ${PRDT_RANGE}
Unique identifier       : ${PRDT_UUID}
" | tee -a ${PRDT_STDOUT}

prdt_validation ${@} | tee -a ${PRDT_STDOUT}

prdt_file_list_split

prdt_submit_sbatch | tee -a ${PRDT_STDOUT}

echo