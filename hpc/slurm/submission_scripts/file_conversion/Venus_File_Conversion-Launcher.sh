#!/bin/bash
#
###------------------------------------------------------###
# A Slurm submission script to facilitate file conversion  #
###------------------------------------------------------###

set -e

if [[ "${*}" == "--help" ]]
then
        echo "Team <NAME>: File Conversions"
        echo "---------------------------------"
        echo "Help menu:"
        echo "  \__ This script launches a Job Array with a series of tasks intended to execute file input conversions"
        echo "  \__ The TEAM_Job_Parameters.input should be in the same working directory, otherwise the script will exit"
        echo "  \__ Please edit the the TEAM_Job_Parameters.input file to ensure correctly set values, paths etc. as these will be used during the job execution"
        echo "  \__ You can pass the Slurm \"--partition\" parameter using the first positional argument, e.g. \$ ./TEAM_Launcher.sh genericq will submit the job to the genericq partition"
        echo "  \__ You can pass a Job Array limiter to Slurm by providing an integer value as the second positional argument, e.g. ./TEAM_Launcher.sh genericq 50"
        echo
        exit 1
fi

# Setting the location for the TEAM_Job_Parameters.input file, and checking it exists:
TEAM_JOB_PARAMETERS="$(pwd)/TEAM_Job_Parameters_LOOP.input"
if [[ ! -f ${TEAM_JOB_PARAMETERS} ]]
then 
    echo "The TEAM_Job_Parameters.input file is not present in the current working directory." 
    echo "Without this, we cannot continue - exiting..."
    echo; exit 1
fi
# Reading parameters from the companion TEAM_Job_Parameters.input file that needs to be completed prior to launching this script:
read_parameters() {
    cat ${TEAM_JOB_PARAMETERS} | grep ${1} | awk '{print $2}'
}
# Listing the variables that will be read from the Job_Parameters.input file:
VARS_TO_SET=( 
    INPUT_FILE_ID_LIST
    OUTPUT_PATH_LIST
    JOB_NAME
    JOB_OUTPUT
    SECTION_SIZE
    PYTHON_VENV_PATH
    WORKING_PATH
    CONVERSION_SCRIPT
    UPDATE_DATABASE
    EXECUTOR_PATH
)
# Looping through and exporting the above variables taken from the TEAM_Job_Parameters.input file:
for VARIABLE in ${VARS_TO_SET[*]}
do
    export TEAM_${VARIABLE}="$(read_parameters ${VARIABLE})"
done

# First positional argument: Specifying a particular Slurm partition to which the job array will be submitted
if [[ -n ${1} ]]
then
        scontrol show partition ${1} > /dev/null
        if [[ $? == "0" ]]
        then    TEAM_SLURM_PARTITION="--partition=${1}"
        else    echo "Slurm partition ${1} not recognised on this cluster - ignoring this parameter..."
        fi
fi

# Second positional argument: Specifying a limit to the number of concurrent job array elements being released
if [[ -n ${2} ]]
then
        if ((${2})) 2> /dev/null
        then    TEAM_ARRAY_LIMITER="%${2}"
        else    echo "Number provided isn't an integer, and will be ignored"
        fi
fi

if [[ ! -f ${TEAM_EXECUTOR_PATH} ]]
then
    echo "The Executor script doesn't exist at the following location: ${TEAM_EXECUTOR} "
    echo "Without this, we cannot continue - please correct the path in the Job_Parameters.input file and re-run. Exiting..."
    echo; exit 1
elif [[ $(cat ${TEAM_INPUT_FILE_ID_LIST} | wc -l) != $(cat ${TEAM_OUTPUT_PATH_LIST} | wc -l) ]]
then
    echo "The input file ID file list and Output Path file list differ in length - this could represent an issue for some of the runs"
    echo "Until verified and/or resolved, we will be exiting from this script..."
    echo; exit 1
fi

export TEAM_ARRAY_MIN="1"
export TEAM_ARRAY_MAX=$(cat ${TEAM_INPUT_FILE_ID_LIST} | wc -l)
export TEAM_ARRAY_STEP=${TEAM_SECTION_SIZE}

echo; date; echo
env | egrep 'TEAM'
echo

set -x
# Launching the job array through Slurm:
sbatch --array=[${TEAM_ARRAY_MIN}-${TEAM_ARRAY_MAX}:${TEAM_ARRAY_STEP}]${TEAM_ARRAY_LIMITER} --job-name=${TEAM_JOB_NAME} --output=${TEAM_JOB_OUTPUT} --error=${TEAM_JOB_OUTPUT} ${TEAM_SLURM_PARTITION} ${TEAM_EXECUTOR_PATH} 
set +x

echo
echo "${TEAM_JOB_NAME} Launcher complete."
echo