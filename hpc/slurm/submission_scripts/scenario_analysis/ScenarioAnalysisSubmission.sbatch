#!/bin/bash
#SBATCH --job-name=                                                                         # Specify the name for the job
#SBATCH --output=                                                                           # Specify the file path where stdout will be written (can be the same as --error)
#SBATCH --error=                                                                            # Specify the file path where stderr will be written (can be the same as --output)
#
#SBATCH --time=1-00:00:00                                                                   # Maximum job duration - if this is exceeded, the job will be terminated. The value here represents 1 day (24 hours)#
#
#SBATCH --ntasks=1                                                                          # Specifying that Slurm shall only spawn a single instance of this execution
#SBATCH --nodes=1                                                                           # This execution will be submitted for execution on a single node (ntasks being set to 1 makes this a logical setting)
#
#SBATCH --exclusive=user                                                                    # Reserving the node in its entirety given resources are being specifically seletected (and to stop Slurm from placing other tasks on otherwise available resources on the node)

# Defining functions for printing INFO and ERROR outputs
info() { 
	echo -e "`date "+%Y/%m/%d   %H:%M:%S"`\t[INFO]   $1" 
}
error() { 
	echo -e "`date "+%Y/%m/%d   %H:%M:%S"`\t[ERROR]  $1"
}
gap() {
	echo
}

echo -e "
#==============================================================================================#
\t\t\t\t\tCOMPANY: <_TEAM_NAME_>\t\t\t\t
#==============================================================================================#
"
gap
info "Starting: ${SLURM_JOB_NAME}"
info
info "Setting paths & variables..."
    # Specify: The directory path for the Matlab runtime that will be used with this execution // The directory path for the Matlab Component Runtime cache
	export MATLAB_RUNTIME_PATH="/path/to/matlab/runtime"                           
	export MCR_CACHE_ROOT=/dev/shm/${SLURM_JOB_NAME}

    # Specify: The file path of the executable to invoke as part of this script // The directory path where the output data shall be written
	export TEAM_EXECUTABLE=""
	export TEAM_OUTPUT=""

    # Creates: A bash variable array with the contents from the file list (provided at the first positional argument) // A variable with the length of the array, i.e. number of elements
	export TEAM_FILE_ARRAY=( $(cat ${1}) )                                             
	export TEAM_FILE_ARRAY_LEN=$(( ${#TEAM_FILE_ARRAY[*]} - 1 ))

    # How many tasks shall be run within a loop for each job array element:
	export TEAM_TASKS_PER_JOB=30  

    # Creating zero-value variables to track the number of failed and successful executions:
	TEAM_LOG_FAILED="0"
	TEAM_LOG_SUCCESS="0"

    # Checks to check whether the file list path provided exists:
    if [[ ! -f ${1} ]]; then error "The file list path provided to the script doesn't exist - please re-run with the correct path to the file list"; exit 1; fi

    # Printing the environment variables specific for this job to stdout (and sorted, for easier reading):
gap	
    env | egrep 'SLURM|TEAM_|MCR|MATLAB' | sort
gap

info "Checking MCR_CACHE_ROOT directory..."
	[[ ! -d ${MCR_CACHE_ROOT} ]]  &&  mkdir -p ${MCR_CACHE_ROOT}  &&  info "Directory created"  ||  info "Directory already exists"  &&  EXISTING_MCR_CACHE_ROOT="TRUE"
info

# Evaluating which points in the ${TEAM_FILE_ARRAY} variable array the for loop should start and finish (remembering that we start counting at 0, hence the offset is being decreased by 1):
info "Setting START and END points..."
	OFFSET=$(( ${TEAM_TASKS_PER_JOB} - 1 ))
	START=$(( ${SLURM_ARRAY_TASK_ID} * ${TEAM_TASKS_PER_JOB} ))
	END=$(( ${START} + ${OFFSET} ))
info "Starting point:\t${START}"
	if [[ ${END} -gt ${TEAM_FILE_ARRAY_LEN} ]]
	then	info "Ending point:\t\t${TEAM_FILE_ARRAY_LEN}"
	else	info "Ending point:\t\t${END}"
	fi
info

# Evaluating the computational components to use for the execution of this task:
info "Evaluating processor core range to use for execution..."
	PHYS_CORES=$(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | sort | uniq | cut -f1 -d ',' | sort -n | paste -s -d, -)
info "Non-hyperthreaded core range is: ${PHYS_CORES}"
info
	if (( ${SLURM_ARRAY_TASK_ID} % 2 ))
	then 	NODE_DOMAIN="1"
	else	NODE_DOMAIN="0"
	fi
info "This Job Array element will use computational resources from node domain ${NODE_DOMAIN} on the host"
info "Printing the hosts' hardware layout:"
gap
	numactl --hardware
gap
info

# Capturing the run time for all tasks included within the loop from within the script (will print the total wall time as we close the job array element):
info "Starting timer"
	TIMER_START=$(date +%s)
info

# Preparing and submitting tasks via Slurm, binding the spawned process(es) to the computational resources identified in the previous stage:
info "Executing tasks:"
	for LOG in $(seq ${START} ${END})
	do
		if [[ ${LOG} -gt ${TEAM_FILE_ARRAY_LEN} ]]
		then
			info "Reached the end of the logs to process."
			break
		else
            # numactl will allow us to bind the invoked process to a specific computational resource - we are using any available CPU core from within a numa domain: 
			EXECUTION_SRUN="srun numactl --cpunodebind=${NODE_DOMAIN} --membind=${NODE_DOMAIN}"
			EXECUTION_TEAM="${TEAM_EXECUTABLE} ${MATLAB_RUNTIME_PATH} ${TEAM_FILE_ARRAY[${LOG}]} ${TEAM_OUTPUT}"

			info "${LOG}\tCommand:  ${EXECUTION_SRUN} ${EXECUTION_TEAM}"
			gap
			${EXECUTION_SRUN} ${EXECUTION_TEAM}

            # Exit code check: If the process fails to exit cleanly, it will be appended to a text file which is printed to stdout at the close of the scripts execution:
			[[ $? != "0" ]]  &&  ((TEAM_LOG_FAILED++))  &&  echo ${LOG} >> ${MCR_CACHE_ROOT}/${SLURM_ARRAY_TASK_ID}-failed_log.txt  ||  ((TEAM_LOG_SUCCESS++))
			gap;gap
		fi
	done	

info "Tasks completed"

info "Stopping timer"
	TIMER_END=$(date +%s)
	TIMER_DIFF_SECONDS=$(( ${TIMER_END} - ${TIMER_START} ))
	TIMER_READABLE=$(date +%H:%M:%S -ud @${TIMER_DIFF_SECONDS})
info

    # Tidying up after all tasks have terminated by removing the MCR cache (unless pre-existing):
	if [[ ${EXISTING_MCR_CACHE_ROOT} != "TRUE" ]]
	then
        	info "Deleting ${MCR_CACHE_ROOT}"
        	rm -rf ${MCR_CACHE_ROOT}
	fi
info

info "Successful executions:\t${TEAM_LOG_SUCCESS}"
info "Failed executions:\t${TEAM_LOG_FAILED}"
    if [[ ${FAILED} -gt "0" ]]
    then
	    error "Failed logs:"
	    cat ${MCR_CACHE_ROOT}/${SLURM_ARRAY_TASK_ID}-failed_log.txt
	    rm ${MCR_CACHE_ROOT}/${SLURM_ARRAY_TASK_ID}-failed_log.txt
	    gap
    fi
info

info "Node: ${SLURMD_NODENAME}\t|\tArray-JobID_TaskID: ${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}\t\t|\tWall_Time: ${TIMER_READABLE}"
info
info "Complete"
gap
