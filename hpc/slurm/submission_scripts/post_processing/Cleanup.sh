#!/bin/bash
#SBATCH --job-name=                                                    	# Specify the name for the job
#SBATCH --output=        	                                       		# Specify the file path where stdout will be written (can be the same as --error)
#SBATCH --error=		                                       			# Specify the file path where stderr will be written (can be the same as --output)

# The cleanup script that will run following completion of all job elements

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

info "Setting variables passed from Launcher"
	
	export TEAM_CONTAINER_FULL=${1}
	export TEAM_JOB_ID=${2}

	export TEAM_MATLAB_CACHE="/dev/shm/${TEAM_JOB_NAME}"

echo
	env | egrep 'TEAM'
echo

info "Printing a list of the computation wall time for each job:"
echo
    	# Splitting the find command over multiple lines to ease reading:
	for LOG in $(find \
			$(dirname \
				$(scontrol show jobid ${TEAM_JOB_ID} | grep StdOut | head -n1 | cut -f2 -d '=') \
			) \
  		   -name "*${TEAM_JOB_ID}*") 
	do
		echo -e "`cat ${LOG} | grep 'Computation'`\t ${LOG}"
	done | sort
echo

info "Starting the cleanup"
info
info "Deleting the MCR_CACHE_ROOT directory on each compute node involved in the job" 

	for TEAM_CLEANUP_MCR in $(cat ${HOME}/${TEAM_JOB_NAME}/nodelist.txt | sort | uniq)
	do
		srun --ntasks=1 --nodes=1 -w ${TEAM_CLEANUP_MCR} rm -rf ${TEAM_MATLAB_CACHE}
	done

wait

	if [[ -f ${TEAM_NODELIST} ]]
	then	
		rm ${TEAM_NODELIST}
	fi	

# Set to "YES" to have the cleanup script remove the contianer image from the filesystem path:
REMOVE_CONTAINER="YES"

	if [[ ${REMOVE_CONTAINER} == "YES" ]]
	then
		info
		info "REMOVE_CONTAINER variable has been set in the cleanup script"
		info "Removing container image: ${TEAM_CONTAINER_FULL}"

		if [[ -f ${TEAM_CONTAINER_FULL} ]]
		then
			rm -f ${TEAM_CONTAINER_FULL}
		
            		# Exit code check: Was it possible to delete the container image?
			if [[ $? != "0" ]]
			then
				error "A non-zero exit code was returned when trying to remove the container image"
				info "You may want to manually remove the container image to avoid having data unnecessarily lurking about"
			else
				info "Done"
			fi
		else
			error "Container image doesn't exist in the specified location - perhaps it's been renamed, moved or deleted already?"
		fi
	else
		info "REMOVE_CONTAINER variable has not been set"
		info "Will not remove the container image: ${TEAM_CONTAINER_FULL}"
	fi

info
info "Closing cleanup"
echo
