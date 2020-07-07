#!/bin/bash

# Parallel rsync wrapper - takes an input and creates the execution environment to facilitate parallelised data transfers
# PRDT = Parallel Rsync Data Transfer


#============================================================================================================================================================================================================================================================================================================================================================#
# USER-LEVEL VARIABLES

export PRDT_TARGET_ROOT_DIR="/path/to/target_root"                                                                      # In other words: where is the data going to be written to?
export PRDT_OUTPUT_DIR="/path/to/directory/to/store/temporary/file_lists"                                               # Should be in a shared filesystem location, as Slurm tasks will need to read these file lists
PRDT_RSYNC_EXECUTOR="/path/to/rsync/executor.sh"                                                                        # The path to the rsync execution script, which will run on each Slurm task
PRDT_CHECKSUM_AGGREGATOR="/path/to/checksum/aggregator.sh"                                                              # The path to the rsync aggregation script, which will run after the job array completes to aggregate checksums
PRDT_RANGE="50"                                                                                                         # Declaring the width of the parallelisation, i.e. how many separate processes will be spawned for data transfer, e.g. 100 will create a job array with indices of 0-99

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# FRAMEWORK-LEVEL VARIABLES

export PRDT_SOURCE_ROOT_DIR="/"                                                                                         # It's unlikely this will need to change, but if the input file list is not the fully qualified path you should prefix the root directory here
export PRDT_UUID="${RANDOM}_"                                                                                           # A unique number to differentiate the various runs
export PRDT_CHECKSUM="sha512sum"                                                                                        # To include integrity validation, checksums will be performed before and after transfer. The field determines the program used to calculate the checksums 

export PRDT_TEMP_RSYNC_FILE_LIST_NAMES="${PRDT_OUTPUT_DIR}/${PRDT_UUID}parallel_rsync_split_temp_file_list-"            # The name prefix of the temporary "splitted" file lists. Each splitted file list will be deleted after (or not, as per the executor script)
export PRDT_TEMP_CHECKSUM_LIST_NAME="${PRDT_OUTPUT_DIR}/${PRDT_UUID}parallel_rsync_checksum_temp_list-"                 # Checksum values will be persistently stored so as they can be reviewed by both this framework, and further analysis if necessary. The file path will not be included in the output for easier comparison
export PRDT_STDOUT="${PRDT_OUTPUT_DIR}/${PRDT_UUID}parallel_rsync_wrapper.out"                                          # Where the stdout of the wrapper will be written to, in addition to the terminal, and will have all job array elements' stdout appended to it during aggregation
export PRDT_JOB_ARRAY_OUTPUT="${PRDT_OUTPUT_DIR}/%x-%A_%a.out"                                                          # Where each job array element will write both stderr and stdout
export PRDT_CENTRAL_FILE_LIST_MAP="${PRDT_UUID}central_splitted_file_list_map.txt"                                      # Naming convention for an aggregated list of all splitted file lists, aka the central map for executor tasks to read from

PRDT_INPUT_LIST="${1}"                                                                                                  # Using the first positional argument, but it's perfectly acceptable to provide the path here instead
#PRDT_LOG_TO_FILE="| tee -a ${PRDT_STDOUT}"                                                                             # Log all output to the working log file, without needing separate tee commands

export PRDT_LARGE_ARRAY_SUPPORT="ENFORCING"                                                                             # Uncomment this variable if you are planning to run large-scale data transfers, or have constrained resources:


#============================================================================================================================================================================================================================================================================================================================================================#
# FUNCTIONS 

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
	    echo "INFO      : Target path does not exist - creating now..."
	    mkdir -p ${PRDT_TARGET_ROOT_DIR}
    fi

    # Checking the output directory exists:
    if [[ ! -d ${PRDT_OUTPUT_DIR} ]]
    then
        echo "INFO      : Output path does not exist - creating now..."
        mkdir -p ${PRDT_OUTPUT_DIR}
    fi

    # Removing a trailing slash on the directories (if placed):
    PRDT_DIR_SLASH=$(echo ${PRDT_TARGET_ROOT_DIR: -1})
    if [[ ${PRDT_DIR_SLASH} == '/' ]]
    then 
	    export PRDT_TARGET_ROOT_DIR=$(echo ${PRDT_TARGET_ROOT_DIR} | sed s'/.$//')
    fi

    # Checking Slurm packages exist on the machine:
    if [[ $(command -v sbatch) && $(command -v scontrol) ]]
    then
        echo "*** ERROR:    Slurm commands are not available on this machine"
        exit
    fi
    echo
}

prdt_file_list_split() {
    echo "INFO      : Initiating split of input file list ..."
    split --number=l/${PRDT_RANGE} --numeric=1 -d --suffix-length=6 ${PRDT_INPUT_LIST} ${PRDT_TEMP_RSYNC_FILE_LIST_NAMES}

    if [[ ${?} == "0" ]]
    then
        echo "INFO      : Complete"
    else
        echo "*** ERROR:    Non-zero exit code returned following file list split"
    fi

    if [[ ${PRDT_LARGE_ARRAY_SUPPORT} == "ENFORCING" ]]
    then
        echo "INFO:     Sleeping for ${PRDT_LAUNCHER_SLEEP} seconds to allow I/O to settle ..."
        echo
        sleep ${PRDT_LAUNCHER_SLEEP}
    fi
    echo "INFO      : Generating a list of the splitted segments ..."
    find $(dirname ${PRDT_TEMP_RSYNC_FILE_LIST_NAMES}) -name "$(basename ${PRDT_TEMP_RSYNC_FILE_LIST_NAMES})*" -type f | sort >> $(dirname ${PRDT_TEMP_RSYNC_FILE_LIST_NAMES})/${PRDT_CENTRAL_FILE_LIST_MAP}
    if [[ ${?} == "0" ]]
    then
        echo "INFO      : Complete"
        echo "INFO      : Central file list map ---> $(ls -lk $(dirname ${PRDT_TEMP_RSYNC_FILE_LIST_NAMES})/${PRDT_CENTRAL_FILE_LIST_MAP})"
    else
        echo "*** ERROR:    Non-zero exit code returned following creation of the central file list map"
    fi
    echo
}

prdt_submit_sbatch() {
    if [[ ${PRDT_LARGE_ARRAY_SUPPORT} == "ENFORCING" ]]
    then
        PRDT_ARRAY_THROTTLE="%500"
        PRDT_ARRAY_THROTTLE_INCREMENT=500
    fi

    # Submitting the main parallelised rsync as a job array:
    PRDT_PARALLEL_RSYNC_SUBMIT=$(sbatch --uid=root --array=1-${PRDT_RANGE}${PRDT_ARRAY_THROTTLE} --job-name=${PRDT_UUID}parallel_rsync --output=${PRDT_JOB_ARRAY_OUTPUT} --error=${PRDT_JOB_ARRAY_OUTPUT} ${PRDT_RSYNC_EXECUTOR})
    PRDT_PARALLEL_RSYNC_JOB_ID=$(echo ${PRDT_PARALLEL_RSYNC_SUBMIT} | awk '{print $4}')
    
    for PRDT_JOB_ID in $(scontrol show job ${PRDT_PARALLEL_RSYNC_JOB_ID} | grep JobId | awk '{print $1}' | cut -f2 -d '=')
    do  
        PRDT_ARRAY_JOB_IDS=${PRDT_ARRAY_JOB_IDS}:${PRDT_JOB_ID}
    done

    echo "Slurm submission - rsync        : ${PRDT_PARALLEL_RSYNC_SUBMIT}"

    # Submitting the checksum aggregator:
    #PRDT_AGGREGATOR_SUBMIT=$(sbatch --uid=root --dependency=afterany${PRDT_PARALLEL_RSYNC_JOB_ID} --job-name=${PRDT_UUID}aggregator --output=${PRDT_OUTPUT_DIR}/%x-%j.out ${PRDT_CHECKSUM_AGGREGATOR} ${PRDT_PARALLEL_RSYNC_JOB_ID})
    PRDT_AGGREGATOR_SUBMIT=$(sbatch --uid=root --dependency=afterany${PRDT_ARRAY_JOB_IDS} --job-name=${PRDT_UUID}aggregator --output=${PRDT_OUTPUT_DIR}/%x-%j.out ${PRDT_CHECKSUM_AGGREGATOR} ${PRDT_PARALLEL_RSYNC_JOB_ID})
    echo "Slurm submission - aggregator   : ${PRDT_AGGREGATOR_SUBMIT}"
    echo

    if [[ ${PRDT_LARGE_ARRAY_SUPPORT} == "ENFORCING" ]]
    then
        echo "INFO      : Staggered release of job array elements"
        # Removing the % symbol:
        PRDT_ARRAY_THROTTLE="${PRDT_ARRAY_THROTTLE:1}"
        # Releasing the array throttle gradually:
        while [[ ${PRDT_ARRAY_THROTTLE} -lt ${PRDT_RANGE} ]]
        do
            PRDT_ARRAY_THROTTLE=$(( ${PRDT_ARRAY_THROTTLE} + ${PRDT_ARRAY_THROTTLE_INCREMENT} ))
            scontrol update jobid=${PRDT_PARALLEL_RSYNC_JOB_ID} arraytaskthrottle=${PRDT_ARRAY_THROTTLE}
            echo "INFO      : Released another batch of jobs - new throttle for array job ID ${PRDT_PARALLEL_RSYNC_JOB_ID} is --->  ${PRDT_ARRAY_THROTTLE}"
            sleep 15
        done
    fi
}


#==========================================================================================================================================================================================================================================================================================================================================================#
# EXECUTION

if [[ ${PRDT_LARGE_ARRAY_SUPPORT} == "ENFORCING" ]]
then
    echo "INFO      : Large Array Support optimisations enabled" | tee -a ${PRDT_STDOUT}

    # Adding an arbitrary sleep after the file split:
    PRDT_LAUNCHER_SLEEP=30

    # Creating a separate directories for specific outputs:    
    mkdir ${PRDT_OUTPUT_DIR}/splitted_file_lists    2>/dev/null         # Suppressing stderr, if incurred
    mkdir ${PRDT_OUTPUT_DIR}/checksums              2>/dev/null         # Suppressing stderr, if incurred
    mkdir ${PRDT_OUTPUT_DIR}/job_array_stdout       2>/dev/null         # Suppressing stderr, if incurred

    # Modifying previously exported variables to separate out each output/log to its respective directory:
    export PRDT_JOB_ARRAY_OUTPUT="$(dirname ${PRDT_JOB_ARRAY_OUTPUT})/job_array_stdout/$(basename ${PRDT_JOB_ARRAY_OUTPUT})"
    export PRDT_TEMP_RSYNC_FILE_LIST_NAMES="$(dirname ${PRDT_TEMP_RSYNC_FILE_LIST_NAMES})/splitted_file_lists/$(basename ${PRDT_TEMP_RSYNC_FILE_LIST_NAMES})"
    export PRDT_TEMP_CHECKSUM_LIST_NAME="$(dirname ${PRDT_TEMP_CHECKSUM_LIST_NAME})/checksums/$(basename ${PRDT_TEMP_CHECKSUM_LIST_NAME})"
fi

echo "
Start time                      : $(date)
Operation                       : Setting up the parallel rsync execution environment
Rsync target directory          : ${PRDT_TARGET_ROOT_DIR}
Output directory		        : ${PRDT_OUTPUT_DIR}
Main input file list            : ${PRDT_INPUT_LIST}
Number of files			        : $(cat ${PRDT_INPUT_LIST} | wc -l)
Parallelisation range           : ${PRDT_RANGE}
Unique identifier               : ${PRDT_UUID}

Printing relevant environment   :
$(env | egrep 'SLURM|PRDT' | sort)
" | tee -a ${PRDT_STDOUT}

prdt_validation ${@} | tee -a ${PRDT_STDOUT}

prdt_file_list_split | tee -a ${PRDT_STDOUT}

prdt_submit_sbatch | tee -a ${PRDT_STDOUT}