#!/bin/bash

#===================================================================================================================================================#
# This is the launcher script that should be invoked interactively from the invokees terminal.                                                      #
#                                                                                                                                                   #
# It's necessary to execute interactively as a password challenge is presented to satisfy a login to DOCKER_REPO to download the container image.   #
#                                                                                                                                                   #
# Please ensure the boxed variable section below is completed appropriately before invoking this script.                                            #
#===================================================================================================================================================#

# Defining functions for printing INFO and ERROR outputs
info() {
        echo -e "`date "+%Y/%m/%d   %H:%M:%S"`\t[INFO]   $1" 
}
error() {
        echo -e "`date "+%Y/%m/%d   %H:%M:%S"`\t[ERROR]  $1"
}

echo
echo "
#===============================================================================================#
                                    COMPANY: TEAM TEAM_NAME                                   
#===============================================================================================#
"
info
info ">> Starting"
info
info "Setting variables:"

    # Setting the location for the Job_Parameters.input file, and checking it exists:
    TEAM_JOB_PARAMETERS="$(pwd)/Job_Parameters.input"
    if [[ ! -f ${TEAM_JOB_PARAMETERS} ]]
    then 
        error "The Job_Parameters.input file is not present in the current working directory - exiting...\v"
        exit 1
    fi

    # Reading parameters from the companion Job_Parameters.input file that needs to be completed prior to launching this script:
    read_parameters() {
        cat ${TEAM_JOB_PARAMETERS} | grep ${1} | awk '{print $2}'
    }

    # Listing the variables that will be read from the Job_Parameters.input file:
    VARS_TO_SET=( 
        JOB_NAME
        FILE_LIST
        CONTAINER_PATH 
        DOCKER_REPO_USERNAME
        DOCKER_REPO_ADDRESS 
        DOCKER_REPO_PORT 
        DOCKER_REPO_OBJECT_PATH 
        DOCKER_REPO_OBJECT_NAME 
        DOCKER_REPO_OBJECT_REV
        SKIP_CONTAINER_PULL
        CONCURRENT_JOBS
        EXECUTOR_PATH
        CLEANUP_PATH
        ALL_VARS_SET
        )

    for VARIABLE in ${VARS_TO_SET[*]}
    do
        export TEAM_${VARIABLE}="$(read_parameters ${VARIABLE})"
    done

    export TEAM_CONTAINER_FORMAT="sif"
    export TEAM_DOCKER_REPO_FULL_PATH="${TEAM_DOCKER_REPO_ADDRESS}:${TEAM_DOCKER_REPO_PORT}/${TEAM_DOCKER_REPO_OBJECT_PATH}/${TEAM_DOCKER_REPO_OBJECT_NAME}:${TEAM_DOCKER_REPO_OBJECT_REV}"
    export TEAM_CONTAINER_NAME="${TEAM_DOCKER_REPO_OBJECT_NAME}_${TEAM_DOCKER_REPO_OBJECT_REV}"
    export TEAM_CONTAINER_FULL="${TEAM_CONTAINER_PATH}/${TEAM_CONTAINER_NAME}.${TEAM_CONTAINER_FORMAT}"

    export TEAM_DATE_PREFIX="$(date +%y%m%d-%H%M)"
    export TEAM_OUTPUT_PREFIX="${HOME}/${TEAM_JOB_NAME}/${TEAM_DATE_PREFIX}"
    export TEAM_EXEC_OUTPUT="${TEAM_OUTPUT_PREFIX}/JOB_LOGS/%x-%A_%a.out"
    export TEAM_CLEANUP_OUTPUT="${TEAM_OUTPUT_PREFIX}/%x-%j.out"
    export TEAM_NODELIST="${TEAM_OUTPUT_PREFIX}/nodelist.txt"

    export SINGULARITY_DOCKER_USERNAME="${TEAM_DOCKER_REPO_USERNAME}"

    # Printing the environment specific for TEAM to stdout:
	echo
	env | egrep 'TEAM|SINGULARITY' | sort
	echo

    # Checks to validate everything is in order:
    if [[ ! -f ${TEAM_EXECUTOR_PATH} || ! -f ${TEAM_CLEANUP_PATH} || ${TEAM_ALL_VARS_SET} != "YES" ]]   
    then
        error "Either the Executor.sh or Cleanup.sh file is not present in the current working directory, or the ALL_VARS_SET in Job_Parameters.input isn't set - exiting...\v"
        exit 1
    fi

    # Creating the directory for the output files:
    mkdir -p $(dirname ${TEAM_EXEC_OUTPUT})
    touch ${TEAM_NODELIST}

    # Interpreting the job name and output file paths, and placing into Executor & Cleanup scripts:
        # Executor.sh:
        sed -i "/#SBATCH --job-name=/c #SBATCH --job-name=${TEAM_JOB_NAME}_Executor" ${TEAM_EXECUTOR_PATH}
        sed -i "/#SBATCH --output=/c #SBATCH --output=${TEAM_EXEC_OUTPUT}" ${TEAM_EXECUTOR_PATH}
        sed -i "/#SBATCH --error=/c #SBATCH --error=${TEAM_EXEC_OUTPUT}" ${TEAM_EXECUTOR_PATH}
        # Cleanup.sh:
        sed -i "/#SBATCH --job-name=/c #SBATCH --job-name=${TEAM_JOB_NAME}_Cleanup" ${TEAM_CLEANUP_PATH}
        sed -i "/#SBATCH --output=/c #SBATCH --output=${TEAM_CLEANUP_OUTPUT}" ${TEAM_CLEANUP_PATH}
        sed -i "/#SBATCH --error=/c #SBATCH --error=${TEAM_CLEANUP_OUTPUT}" ${TEAM_CLEANUP_PATH}

info "Pulling DOCKER_REPO container to network path: ${TEAM_CONTAINER_FULL}"

	if [[ ${TEAM_SKIP_CONTAINER_PULL} == "YES" ]]
	then
		info "TEAM_SKIP_CONTAINER_PULL variable set - will not download the latest container image"
	else
        # Checking to see whether the image already exists at the specified location:
        if [[ -f ${TEAM_CONTAINER_FULL} ]]
        then
            info "Existing container image detected - prefixing the name with the current date & time (in numerical form): ${TEAM_DATE_PREFIX}"
            mv ${TEAM_CONTAINER_FULL} ${TEAM_CONTAINER_PATH}/${TEAM_DATE_PREFIX}-${TEAM_CONTAINER_NAME}.${TEAM_CONTAINER_FORMAT}

            # Exit code check: Unable to rename or move existing container image
			if [[ $? != "0" ]]
			then
				error "Unable to move existing container image - is it owned by another user/group, or perhaps explicit permissions have been set?"
				info "The downloaded image will be prefixed to allow the job to proceed"
				export TEAM_CONTAINER_FULL="${TEAM_CONTAINER_PATH}/${TEAM_DATE_PREFIX}-${TEAM_CONTAINER_NAME}.${TEAM_CONTAINER_FORMAT}"
			fi
        fi

echo
        # Initiating the Docker container pull from DOCKER_REPO:
        singularity pull --docker-login ${TEAM_CONTAINER_FULL} docker://${TEAM_DOCKER_REPO_FULL_PATH}

        # Exit code check: Are we able to pull the container image from DOCKER_REPO?
        if [[ $? != "0" ]]
        then
            error "Non-zero exit code returned following container pull from DOCKER_REPO."
            error "Exiting..."
            exit 1
        fi
	fi

echo
info "Preparing job elements for launch"
info "Building submission command"

    # Reducing by 1 as array indices start at 0:
	TEAM_ARRAY_HIGH=$(( $(cat ${TEAM_FILE_LIST} | wc -l)-1 ))
	TEAM_ARRAY_LOW=0

    # Splitting the command over multiple lines to improve visibility:
	TEAM_COMMAND_SLURM_JOB_ARRAY="
		sbatch
		--array=${TEAM_ARRAY_LOW}-${TEAM_ARRAY_HIGH}${TEAM_CONCURRENT_JOBS}
		${TEAM_EXECUTOR_PATH}  ${TEAM_CONTAINER_FULL}  ${TEAM_FILE_LIST}
		"

info "Slurm Job Array submission command: $(echo ${TEAM_COMMAND_SLURM_JOB_ARRAY})"

    # Submitting the sbatch job array:
	TEAM_JOB_SUBMIT=$(${TEAM_COMMAND_SLURM_JOB_ARRAY})

    # Exit code check: Did the sbatch job array submit successfully? 
	if [[ $? != "0" ]]
	then
		error "Non-zero exit code returned following sbatch job array submission"
	fi

    # Extracting the Slurm job ID:
	TEAM_JOB_ID=$(echo ${TEAM_JOB_SUBMIT} | awk '{print $4}')

info "${TEAM_JOB_SUBMIT}"
info
info "Job elements have been launched"
info
info "Submitting a job dependency to remove container once all job elements have completed"

    TEAM_CLEANUP_COMMAND="sbatch --dependency=afterany:${TEAM_JOB_ID} ${TEAM_CLEANUP_PATH} ${TEAM_CONTAINER_FULL} ${TEAM_JOB_ID} ${TEAM_NODES}"

info "Slurm Cleanup submission command: $(echo ${TEAM_CLEANUP_COMMAND})"

	TEAM_CLEANUP_SUBMIT=$(${TEAM_CLEANUP_COMMAND})

info "${TEAM_CLEANUP_SUBMIT}"
info
info "Closing the Launcher element"
echo
