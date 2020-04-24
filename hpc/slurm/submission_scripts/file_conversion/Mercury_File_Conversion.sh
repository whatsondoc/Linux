#!/bin/bash
#SBATCH --job-name=                                                                         # Specify the name for the job
#SBATCH --output=                                                                           # Specify the file path where stdout will be written (can be the same as --error)
#SBATCH --error=                                                                            # Specify the file path where stderr will be written (can be the same as --output)
#
#SBATCH --time=1-00:00:00                                                                   # Maximum job duration - if this is exceeded, the job will be terminated. The value here represents 1 day (24 hours)##
#
#SBATCH --ntasks=30
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=30
#
#SBATCH --exclusive

# Defining functions for printing INFO and ERROR outputs
info() { 
	echo -e "`date "+%Y/%m/%d   %H:%M:%S"`\t[INFO]   $1" 
}
error() { 
	echo -e "`date "+%Y/%m/%d   %H:%M:%S"`\t[ERROR]  $1"
}

#===================================================================================================================================================================#
# USER DEFINED VARIABLES:

# Specify the conversion command that will be used:
# e.g. CONVERSION_CMD="/path/to/python3 /path/to/directory/with/script.py -i ${INPUT_FILE} -o ${OUTPUT_FILE}"
CONVERSION_CMD=""

# What naming convention shall the output file (created during the conversion process) follow:
# e.g. OUTPUT_FILE="$(echo ${FILE_LIST_ARRAY[${FILE}]} | cut -d. -f1).FILE-${FILE}.mp4"
OUTPUT_FILE_NAME=""

# Specify the DOCKER_REPO API key (used to authenticate to the service) and the path to the container image being downloaded:
DOCKER_REPO_API_HEADER=""
DOCKER_REPO_API_KEY=""
CONTAINER_PATH=""
# (There is no necessity for a container image to be used - you can comment out the above variables and modify the command between lines 142-149 should you wish)

# (THANK YOU!)
#===================================================================================================================================================================#


echo
echo
info "---> Start"
info "Job Array ID - Parent  : ${SLURM_JOB_ID}"
info "Job Array ID - Task    : ${SLURM_ARRAY_TASK_ID}" 
info "Slurm node name        : ${SLURMD_NODENAME}"


info 
info "---> Stage 0: Error capture"
    [[ $# != "1" ]]  \
        &&  error "File List required as the first positional argument when calling this script."  \
        &&  error "Exiting..."  \
        &&  exit 1  \
        ||  info "All clear"
    
    info "Stage complete"


info 
info "---> Stage 1: Set variables"

    # Checking to ensure the variables above have been set:
    [[ -z ${DOCKER_REPO_API_KEY} || -z ${CONTAINER_PATH} || -z ${CONVERSION_CMD} || -z ${OUTPUT_FILE_NAME} ]] \
	    && error "Some variables have not been set - please edit the USER DEFINED VARIABLES section at the top of the script and execute again." \
	    && error "Exiting..." \
	    && exit 1

    # Creating a Bash variable array with the contents of the provided file list:
    FILE_LIST_ARRAY=( $(cat $1) )
    FILE_LIST_ARRAY_LEN=${#FILE_LIST_ARRAY[*]}
    
    CONTAINER_PATH="/dev/shm/${SLURM_JOB_NAME}"
    CONTAINER_NAME=$(basename ${CONTAINER_PATH})
    info "Done"
    
    info "Stage complete"


info 
info "---> Stage 2: Configure environment"
    START=$(( ${SLURM_ARRAY_TASK_ID} * ${SLURM_NTASKS} ))
    END=$(( ${START} + (${SLURM_NTASKS} - 1) ))

    info "Starting file list position  : ${START}"
    info "Ending file list position    : ${END}"

    [[ ${START} -gt $(( ${FILE_LIST_ARRAY_LEN} - 1)) ]] \
        && error "Starting job element \"${START}\" is higher than the total number of job elements \"$(( ${FILE_LIST_ARRAY_LEN} -1 ))\" (job elements start from 0)" \
        && error "Exiting..." \
        && exit 1

    info "Creating local scratch directory: ${CONTAINER_PATH}"
        [[ ! -d ${CONTAINER_PATH} ]]  \
            &&  mkdir -p ${CONTAINER_PATH}  \
            &&  info "Done"  \
            ||  info "Directory already exists"
    
    info "Stage complete"


info 
info "---> Stage 3: Pull the Singularity image from DOCKER_REPO to local scratch space"
    curl \
        -H "${DOCKER_REPO_API_HEADER}: ${DOCKER_REPO_API_KEY}" \
        -o ${CONTAINER_PATH}/${CONTAINER_NAME} \
        -O ${CONTAINER_PATH}

    [[ $? != "0" ]]  \
        &&  error "The curl command to download the container image returned a non-zero exit code"  \
        &&  error "Cannot continue without the Singularity image"  \
        &&  error "Exiting..."  \
        &&  exit 1  \
        ||  info "Done"

    info "Stage complete"


info 
info "---> Stage 4: Execute the workflow"

    info "Starting timer"
    TIMER_START=$(date +%s)
    
    for FILE in $(seq ${START} ${END})
    do
        # Identifying whether the job element goes beyond the maximum number of elements in the array (as derived from the input file list):
        [[ ${FILE} -gt ${#FILE_LIST_ARRAY[*]} ]] \
            && error "Requested job element ${FILE} is higher than the total number of elements in the provided File List" \
            && break
        
        # Evaluating which segment needs to be processed // Taking the OUTPUT_FILE_NAME from the USER DEFINED VARIABLES section:
        INPUT_FILE=${FILE_LIST_ARRAY[${FILE}]}
        OUTPUT_FILE=${OUTPUT_FILE_NAME}

        # Evaluating whether to bind the process to computational resources on either numa domain 0 or 1 on the host, based on the unique SLURM_ARRAY_TASK_ID:
        NUMA_DOMAIN=$(( ${SLURM_ARRAY_TASK_ID} % 2 ))

        # Building the execution command (split over multiple lines to aid reading):
        COMMAND="
        srun --label --ntasks=1 --nodes=1

        numactl --cpunodebind=${NUMA_DOMAIN} --membind=${NUMA_DOMAIN} 
        
        singularity exec ${CONTAINER_PATH}/${CONTAINER_NAME} 
        
        ${CONVERSION_CMD}
        "

        # Launching the pre-built command, placing it in the background and immediately performing an exit code check to see whether it launched successfully:
        ${COMMAND} &
        [[ $? == "0" ]]  \
            && info "${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}.${FILE}: Command successfully issued: ${COMMAND}" \
            || error "${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}.${FILE}: There was an issue with this command: ${COMMAND}"

        sleep 1
    done

    info "All srun tasks spawned - waiting for processes to terminated" 
    wait
    info "All processes have terminated"
    info
    info "Stopping timer"
    TIMER_END=$(date +%s)
    TIMER_DIFF_SECONDS=$(( ${TIMER_END} - ${TIMER_START} ))
    TIMER_READABLE=$(date +%H:%M:%S -ud @${TIMER_DIFF_SECONDS})

    info "Stage complete"


info 
info "---> Stage 5: Close"
    info "Deleting scratch space directory: ${CONTAINER_PATH}"
    rm -rf ${CONTAINER_PATH}
    [[ ! -d ${CONTAINER_PATH} ]] \
        && info "Done" \
        || error "Unable to delete local scratch directory on ${SLURMD_NODENAME}"
    
    info "Computation wall time:\t${TIMER_READABLE}"
    info
    info "Job Array ${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID} completed on ${SLURMD_NODENAME}"
    
    info "Stage complete"
    echo
