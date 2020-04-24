#!/bin/bash
#SBATCH --job-name=                                                                         # Specify the name for the job
#SBATCH --output=                                                                           # Specify the file path where stdout will be written (can be the same as --error)
#SBATCH --error=                                                                            # Specify the file path where stderr will be written (can be the same as --output)
#
#SBATCH --time=1-00:00:00                                                                   # Maximum job duration - if this is exceeded, the job will be terminated. The value here represents 1 day (24 hours)

# The following will be executed as per job elements launched by the Launcher
# Written to be executed as a Job Array

# Defining functions for printing INFO and ERROR outputs
info() { 
	echo -e "`date "+%Y/%m/%d   %H:%M:%S"`\t[INFO]   $1" 
}

error() { 
	echo -e "`date "+%Y/%m/%d   %H:%M:%S"`\t[ERROR]  $1"
}

evaluate_numa() {
	NUMA_DOMAINS=$(lscpu | grep -w "NUMA node" | awk '{print $NF}')

	if (( ${SLURM_ARRAY_TASK_ID} % ${NUMA_DOMAINS} ))
	then    NODE_DOMAIN="1"
	else    NODE_DOMAIN="0"
	fi
info "This job element will prefer to use computational & memory resources from NUMA node: ${NODE_DOMAIN}"

info "Checking to see whether hyperthreading is enabled on this machine:"

	if [[ $(lscpu | awk '/Thread/ {print $NF}') > "1" ]]
	then	
		info "Hyperthreading appears to be enabled on this node - steps will be taken to avoid using hyperthreaded cores..."
		# Identifying the unique CPU cores, removing any sibling listings: 
		SYSTEM_PHYSICAL_CORES=$(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | sort | uniq | cut -f1 -d ',' | sort -n | paste -s -d, -)
		DOMAIN_PHYSICAL_CORES=$(cat /sys/devices/system/cpu/cpu*/node${NODE_DOMAIN}/cpulist | head -n1)
		info "Non-hyperthreaded core range for NUMA domain ${NODE_DOMAIN} is: ${DOMAIN_PHYSICAL_CORES}"

		# Building the execution command for a hyperthreaded scenario:
		BIND_PROCESS="numactl --physcpubind=${DOMAIN_PHYSICAL_CORES} --preferred=${NODE_DOMAIN}"
	else 	
		info "Hyperthreading appears to be disabled on this node - computational resources will be determined at a NUMA node level"	
		# Building the execution command for a non-hyperthreaded scenario:
		BIND_PROCESS="numactl --cpunodebind=${NODE_DOMAIN} --preferred=${NODE_DOMAIN}"
	fi
}

echo
echo "
#===============================================================================================#
                                   COMPANY: TEAM TEAM_NAME                                		
#===============================================================================================# 
"

info
info ">> Starting execution: ${SLURM_ARRAY_TASK_ID}"
info
info "Setting variables"
	export TEAM_JOB_ELEMENT="${SLURM_JOB_NAME}-${SLURM_ARRAY_TASK_ID}"                 
    
    	# Defining the location of the Matlab Component Runtime cache. Using system memory on each compute node for best cache performance
	export MCR_CACHE_ROOT="/dev/shm/${SLURM_JOB_NAME}"

    	# This script will take inputs from the Launcher. The first positional argument is the container path for this execution to use // The second positional argument is the segment input for this execution to use.
	export TEAM_CONTAINER_FULL_PATH=${1}                                                
	export TEAM_SEGMENT_INPUT=${2}

    	# Specify the file path where failed segments will be logged:
	export TEAM_FAILED_SEGMENT_LOG="${HOME}/${SLURM_JOB_NAME}/failed_segments.log"

info "Printing environment:"
echo
	env
echo

info "Checking if the directory provided in the MCR_CACHE_ROOT variable exists: ${MCR_CACHE_ROOT}"

	if [[ ! -d ${MCR_CACHE_ROOT} ]]
	then
		info "Negative --- Creating now..."
		mkdir -p ${MCR_CACHE_ROOT}
		
        	# Exit code check: Can we create a directory for the MCR_CACHE_ROOT in system memory?
		if [[ $? != "0" ]]
		then
			error "Non-zero exit code when trying to create the MCR_CACHE_ROOT directory."
			error "MCR_CACHE_ROOT will fallback to using a path in the executing user's home directory..."
		else
			info "Done"
		fi

	else
		info "Confirmed"
	fi

info
info "Evaluating segment to process"

	# Creating a variable array from the file list input, and identifying the specific segment to process based on the unique ${SLURM_ARRAY_TASK_ID}:
	TEAM_SEGMENT_ARRAY=( $(cat ${TEAM_SEGMENT_INPUT}) )
	TEAM_SEGMENT_INPUT=${TEAM_SEGMENT_ARRAY[${SLURM_ARRAY_TASK_ID}]}
info
info "Determining whether segment data should be read from networked storage or copied to local system memory"

    	# Set this variable to "YES" to have the segment copied to local memory before executing:
	RUN_FROM_LOCAL_MEMORY=""
	if [[ ${RUN_FROM_LOCAL_MEMORY} == "YES" ]]
	then
		info "Decision: Copying segment to system memory"

		sbcast ${TEAM_SEGMENT_INPUT} ${MCR_CACHE_ROOT}

        	# Exit code check: Can we use sbcast (Slurm broadcast) to copy the segment to the node?
		if [[ $? != "0" ]]
		then	
			error "There was an issue moving the segment to system memory."
			error "Reverting to reading from the network filesystem."
		else
			info "Segment copied"

			TEAM_SEGMENT_INPUT="${MCR_CACHE_ROOT}/$(basename ${TEAM_SEGMENT_INPUT})"
		fi
	else
		info "Decision: Reading data from the network filesystem"
	fi

info
info "Building execution commands"

	# Evaluating hardware resources::
	evaluate_numa

   	# Splitting the full command into sections, and spreading these sections over multiple lines to aid reading and ease modifications to different sections:
	TEAM_CMD_SRUN="srun --ntasks=1 --nodes=1"
	TEAM_CMD_BINDING=${BIND_PROCESS}
	TEAM_CMD_SINGULARITY="
		singularity run
		--bind /nfs/:/nfs
		${TEAM_CONTAINER_FULL_PATH}
		"
	TEAM_CMD_TEAM_NAME="
		-d ${TEAM_SEGMENT_INPUT}
		"

info
info "SLURM: $(echo ${TEAM_CMD_SRUN})"
info "BINDING: $(echo ${TEAM_CMD_BINDING})"
info "SINGULARITY: $(echo ${TEAM_CMD_SINGULARITY})"
info "TEAM_NAME: $(echo ${TEAM_CMD_TEAM_NAME})"

info
info "Starting timer"

	TEAM_TIMER_START=$(date +%s)

info "Executing command"
echo
	${TEAM_CMD_SRUN}  ${TEAM_CMD_BINDING}  ${TEAM_CMD_SINGULARITY}  ${TEAM_CMD_GT_VELODYNE}

   	# Exit code check: Were we able to successfully execute the command?
	if [[ $? != "0" ]]
	then
		echo
		error "Non-zero exit code returned following execution"
		error "This likely suggests an issue with either the container, data or the platform"
		info "HOST: ${SLURMD_NODENAME}\t\tJOB ID: ${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}\t\tSEGMENT: ${TEAM_SEGMENT_INPUT}" >> ${TEAM_FAILED_SEGMENT_LOG} 
		TEAM_RESULT="Failed"
	else
		echo
		info "Job element complete!"
		TEAM_RESULT="Successful"
	fi 

info
info "Stopping timer"

	TEAM_TIMER_END=$(date +%s)
	TEAM_TIMER_DIFF_SECONDS=$(( ${TEAM_TIMER_END} - ${TEAM_TIMER_START} ))
	TEAM_TIMER_READABLE=$(date +%H:%M:%S -ud @${TEAM_TIMER_DIFF_SECONDS})

info "Logging machine name for the Cleanup script to remove MCR_CACHE_ROOT directory after all elements have completed"

	hostname >> ${TEAM_NODELIST}

info
info "Computation wall time:\t${TEAM_TIMER_READABLE}"
info "Job Array element ${SLURM_ARRAY_TASK_ID} exit status: ${TEAM_RESULT}"
echo
