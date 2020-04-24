#!/bin/bash
#
#SBATCH --ntasks=
#SBATCH --cpus-per-task=
#SBATCH --nodes=
#SBATCH --exclusive=user
#SBATCH --time=
#
###-----------------------------------------------------------------###
# An execution script launched by Slurm to facilitate file conversion #
###-----------------------------------------------------------------###

TEAM_SECTION_END=$(( (${SLURM_ARRAY_TASK_ID} + ${TEAM_SECTION_SIZE}) - 1 ))

# Calculating the total number of usable CPU cores on the system (allowing 2 cores for system operations):
TEAM_RESERVED_CORES="2"
TEAM_CPU_CORES_TOTAL=$(( $(nproc --all) - ${TEAM_RESERVED_CORES} ))
TEAM_CPU_CORES_HALF=$(( ${TEAM_CPU_CORES_TOTAL} / 2 ))

# Evaluating NUMA: Performing a quick modulo on the unique TASK identifier to produce an integer on which compute area to pin the parent process:
#TEAM_BIND_COMPUTE_TASK=$(( ${SLURM_ARRAY_TASK_ID} % ${TEAM_CPU_CORES_TOTAL} ))
#TEAM_BIND_COMPUTE_MEMORY=$(( ${SLURM_ARRAY_TASK_ID} % 2 ))
TEAM_BIND_COMPUTE=$(( ${SLURM_ARRAY_TASK_ID} % 2 ))
TEAM_BIND_SRUN_TASK=$(( ( ${SLURM_ARRAY_TASK_ID} % 2 ) + ${TEAM_CPU_CORES_TOTAL} ))
TEAM_BIND_SRUN_MEMORY=$(( ${SLURM_ARRAY_TASK_ID} % 2 ))

# Preparing standard job submission components:
TEAM_NUMA_SRUN="numactl --physcpubind=${TEAM_BIND_SRUN_TASK} --preferred=${TEAM_BIND_SRUN_MEMORY}"
TEAM_SLURM="srun --chdir=${TEAM_WORKING_PATH}"
TEAM_NUMA="numactl --cpunodebind=${TEAM_BIND_COMPUTE} --preferred=${TEAM_BIND_COMPUTE}"

# Sleeping for an arbitrary amount of time
#sleep ${TEAM_BIND_COMPUTE_TASK}

echo
date
echo "${TEAM_JOB_NAME} Job Array element starting: ${SLURM_ARRAY_TASK_ID}"
echo "Compute hostname      : $(hostname)"
echo "Input file section    : ${SLURM_ARRAY_TASK_ID} - ${TEAM_SECTION_END}"
echo
echo "Task CPU core binding : ${TEAM_BIND_COMPUTE_TASK}"
echo "Task memory binding   : ${TEAM_BIND_COMPUTE_MEMORY} (NUMA domain)"
echo "srun CPU core binding : ${TEAM_BIND_SRUN_TASK}"
echo "srun memory binding   : ${TEAM_BIND_SRUN_MEMORY} (NUMA domain)"
echo

echo "Printing the job runtime environment:"
echo
        env | egrep 'SLURM|TEAM' | sort
echo

TEAM_RESULT_SUCCESS_TRACKER="0"
TEAM_RESULT_FAILURE_TRACKER="0"

for TEAM_INPUT_FILE_INDEX in $(seq ${SLURM_ARRAY_TASK_ID} ${TEAM_SECTION_END} )
do
    if [[ ${TEAM_INPUT_FILE_INDEX} -gt $(cat ${TEAM_INPUT_FILE_ID_LIST} | wc -l) ]]
    then
        echo "No more input files left to process"
        break
    else
        # Preparing custom job submission components:
        TEAM_INPUT_FILE_ID=$(awk "NR==${TEAM_INPUT_FILE_INDEX}" ${TEAM_INPUT_FILE_ID_LIST})
        TEAM_OUTPUT_PATH=$(awk "NR==${TEAM_INPUT_FILE_INDEX}" ${TEAM_OUTPUT_PATH_LIST})

        TEAM_COMMAND="${TEAM_PYTHON_VENV_PATH} ${TEAM_CREATE_FLC_DAT_SCRIPT} ${TEAM_INPUT_FILE_ID} --result_path ${TEAM_OUTPUT_PATH} ${TEAM_UPDATE_DATABASE}"

        # Preparing full job submission command:
        TEAM_FULL_COMMAND="${TEAM_NUMA_SRUN} ${TEAM_SLURM} ${TEAM_NUMA} ${TEAM_COMMAND}"

        echo; echo "=============="; echo
        echo "Processing input file number: ${TEAM_INPUT_FILE_INDEX}"
        echo
        echo "Command being executed: 
        ${TEAM_FULL_COMMAND}"
        echo

        # Starting the timer:
        TEAM_TIMER_START=$(date +%s)

        # Launching the job array element and tracking the time taken to complete:
        time ${TEAM_FULL_COMMAND}

        # Error checking to see whether the process terminated successfully:
        if [[ $? == "0" ]]
        then
            echo;echo "The process terminated with a 0 exit code."
        else
            echo;echo "***ERROR:    The process terminated with a non-zero exit code - something erroneous may have occurred."
        fi

        TEAM_TIMER_END=$(date +%s)
        TEAM_TIMER_DIFF_SECONDS=$(( ${TEAM_TIMER_END} - ${TEAM_TIMER_START} ))
        TEAM_TIMER_READABLE=$(date +%H:%M:%S -ud @${TEAM_TIMER_DIFF_SECONDS})

        if [[ $(cat $(dirname ${TEAM_JOB_OUTPUT})/${TEAM_JOB_NAME}-${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.$(echo ${TEAM_JOB_OUTPUT} | cut -f2 -d ".") | grep "Done converting input file: ${TEAM_INPUT_FILE_ID}") ]]
        then
            echo;echo "${TEAM_JOB_NAME} Job Array element ${SLURM_ARRAY_TASK_ID} completed in: ${TEAM_TIMER_READABLE}  ===>>  RESULT: Conversion Succeeded"
            ((TEAM_RESULT_SUCCESS_TRACKER++))
        else
            echo;echo "***ERROR:    ${TEAM_JOB_NAME} Job Array element ${SLURM_ARRAY_TASK_ID} completed in: ${TEAM_TIMER_READABLE}  ===>>  RESULT: Conversion Failed"
            ((TEAM_RESULT_FAILURE_TRACKER++))
        fi
        echo;echo
    fi
done

echo
echo "${TEAM_JOB_NAME} ${SLURM_ARRAY_TASK_ID} complete ==> SUCCESSFUL: ${TEAM_RESULT_SUCCESS_TRACKER}      FAILED: ${TEAM_RESULT_FAILURE_TRACKER}"
echo