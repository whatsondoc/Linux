#!/bin/bash
#
# Creation date : September 2020
# Purpose       : Enabling seamless job submission within a multi-zoned PBS cluster
#
#-----------------------------------------------------------------------------------------------------------------------------------------------#
## FUNCTIONS:
help() { echo -e "`date "+%Y/%m/%d   %H:%M:%S"`\t[HELP]     ${1}" ; }
info() { echo -e "`date "+%Y/%m/%d   %H:%M:%S"`\t[INFO]     ${1}" ; }

warning() { 
        WARN_START_O='\033[0;33m'   # Colour change to orange
        WARN_END_O='\033[0m'        # Reverting to no colour
        echo -e "${WARN_START_O}`date "+%Y/%m/%d   %H:%M:%S"`\t[WARNING]  ${1} ${WARN_END_O}" 
}

error() { 
        ERR_START_R='\033[0;31m'    # Colour output change to red
        ERR_END_R='\033[0m'         # Reverting to no colour
        echo -e "${ERR_START_R}`date "+%Y/%m/%d   %H:%M:%S"`\t[ERROR]    ${1} ${ERR_END_R}" 
}

verbose() {
        if      [[ ${WRAPPER_VERBOSE^^} == "VERBOSE" ]]
        then    info "${1}"
        fi
}

cleanup_error() {
        error "*** Error condition detected at the following junction: exit ${?}"
        error "Proceeding to cleanup ..."

        if      [[ -n ${WRAPPER_SCHEDULER_SUBMIT} ]]
        then    warning "Cancelling submitted job: ${WRAPPER_SCHEDULER_SUBMIT}"
                qdel ${WRAPPER_SCHEDULER_SUBMIT%.*}
                if      [[ ${?} != "0" ]]
                then    error "Failed"
                else    warning "Complete"
                fi
        else    warning "No job(s) have been submitted to the scheduler yet - skipping ..."
        fi

        if      [[ -d ${WRAPPER_OUTPUT_DIR_BASE} ]]
        then    warning "Removing base directory and it's contents: ${WRAPPER_OUTPUT_DIR_BASE}"
                rm -rf ${WRAPPER_OUTPUT_DIR_BASE}
                if      [[ ${?} != "0" ]]
                then    error "Failed"
                else    warning "Complete"
                fi
        else    warning "No base directory created yet - skipping ..."
        fi

        if      [[ -f ${RUN_UUID} ]]
        then    warning "Removing temporary output file: ${RUN_UUID}"
                rm ${RUN_UUID}
                if      [[ ${?} != "0" ]]
                then    error "Failed"
                else    warning "Complete"
                fi
        else    warning "No temporary output file created yet - skipping ..."
        fi
}

cleanup_clean() {
        if      [[ ${WRAPPER_MODE} == "LAUNCHER"  &&  ${WRAPPER_COMPLETION_STATUS^^} == "COMPLETE" ]]
        then    if      [[ -f ${RUN_UUID} ]]
                then    mv ${RUN_UUID} ${WRAPPER_OUTPUT_DIR_BASE}/${WRAPPER_UUID}_launcher_output.txt
                fi
        else    rm ${RUN_UUID}
        fi
}

wrapper_help_statement() {
        help "Operation         --> Printing the help menu"
        help "Overview          --> A wrapper script to support the massively parallel execution of custom tools"
        help
        help "Usage     : ${0} [ -a '/path/to/tool.bin -input \${INPUT} -arg1 A -arg2 B' ]  [ -i /path/to/file_list.txt ]  |  [ -p /path/to/job_parameters.sh ]  [ -d ]  [ -v ]  [ -h ]"
        help
        help "  [ -a ]      The command used to execute the tool, inclusive of the path (assumed to be the first part) and all necessary arguments and values to run"
        help "              Should be surrounded by single quotes '...' to avoid variable interpretation when the Launcher runs"
        help "              Mutually exclusive with the '-p' flag"
        help "              Requires the '-i' flag"
        help "  [ -i ]      The full/absolute path to the file list with either IDs or file paths"
        help "              To be used in conjunction with the '-a' flag"
        help "  [ -x ]      <Advanced> To be used when specifying additional arguments to the scheduler, e.g. specific queues, resource requirements, email notifications etc."
        help
        help "  [ -p ]      The full/absolute path to the job parameters file, which specifies the values for the tool and file list path"
        help "              Mutually exclusive with the '-a' flag (and renders the '-i' redundant)"
        help
        help "  [ -v ]      Enables verbose mode"
        help "  [ -d ]      Enables debug mode"
        help "  [ -h ]      Prints this help menu"
        help
        help "Examples  : Specifying all details at the command line: "
        help "            $ ${0} -a '/shared/pbs_wrapper/Team_ABC/tools/process_input.bin -input \${INPUT} -output ${INPUT//raw/output} -update-db' -i /shared/pbs_wrapper/Team_ABC/file_lists/golden_dataset_1.txt"
        help 
        help "          : Providing inputs at the command line, specifying a specific PBS flag to use the 'gpuq' queue: "
        help "            $ ${0} -a '/shared/pbs_wrapper/Team_ABC/tools/process_input.bin -input \${INPUT} -output ${INPUT//raw/output} -update-db' -i '/shared/pbs_wrapper/Team_ABC/file_lists/golden_dataset_1.txt' -x '-q gpuq'"
        help
        help "          : Providing inputs via the Job Parameters file: "
        help "            $ ${0} -p /shared/pbs_wrapper/Team_ABC/Job_Parameters/job_params-process_input.sh "
        help
        help "          : Providing inputs via the Job Parameters file, and enabling debug mode: "
        help "            $ ${0} -p /shared/pbs_wrapper/Team_ABC/Job_Parameters/job_params-process_input.sh -d "
        echo
}

wrapper_validation() {
        verbose "Running validation:"
        if      [[ ${WRAPPER_LAUNCHER_MODE^^} == "COMMAND_LINE"  ||  ${WRAPPER_LAUNCHER_MODE^^} == "JOB_PARAMETERS" ]]
        then    if      [[ ${WRAPPER_MODE^^} == "LAUNCHER" ]]
                then    verbose "Launcher mode enabled"
                        if      [[ ${WRAPPER_LAUNCHER_MODE^^} == "COMMAND_LINE" ]]
                        then    verbose "Arguments provided at the command line"
                                if      [[ -z ${WRAPPER_FILE_LIST} ]]
                                then    error "Main input file list not provided - this is required to proceed"
                                        error "Exiting ..."
                                        exit 10
                                elif    [[ ! -f ${WRAPPER_FILE_LIST} ]]
                                then    error "Main input file list cannot be enumerated at the specified location: ${WRAPPER_FILE_LIST}"
                                        error "Exiting ..."
                                        exit 11
                                elif    (( $(cat ${WRAPPER_FILE_LIST} | wc -l) == "0" ))
                                then    error "The main input file list specified appears to have 0 lines, i.e. an empty file - thus, no work can be done here"
                                        error "Exiting ..."
                                        exit 12
                                else    verbose "File list checks passed:  File list path provided  |  File list exists at the specified path  |  File list has some contents"
                                fi
                
                                if      [[ ! $(command -v qsub) ]]
                                then    error "Required packages are not available in \$PATH and we cannnot continue:  qsub"
                                        error "Exiting ..."
                                        exit 13
                                fi

                                if      [[ ! -f ${WRAPPER_TOOL}  &&  ! $(command -v ${WRAPPER_TOOL}) ]]
                                then    warning "The Launcher cannot find the tool (as a file) or call it (as a package) at the specified location: ${WRAPPER_TOOL}"
                                        warning "This does not necessarily represent a critical error as the compute nodes may be able to locate it, and so the Launcher will continue"
                                fi

                        elif    [[ ${WRAPPER_LAUNCHER_MODE^^} == "JOB_PARAMETERS" ]]
                        then    verbose "Arguments provided via the Job Parameters file"
                                if      [[ -f ${WRAPPER_JOB_PARAMETERS} ]]
                                then    if      [[ $(cat ${WRAPPER_JOB_PARAMETERS} | egrep -w 'WRAPPER_VALIDATE_JOB_PARAMETERS:CONFIRMED') ]]
                                        then    verbose "Job Parameters file verified: specific string is present"
                                        else    error "A search for the specific string 'WRAPPER_VALIDATE_JOB_PARAMETERS:CONFIRMED' yielded no returns. Is the Job Parameters file valid?"
                                                error "Exiting ..."
                                                exit 14
                                        fi
                                        source ${WRAPPER_JOB_PARAMETERS}
                                        export WRAPPER_TOOL=${WRAPPER_TOOL_COMMAND%% *}
                                        verbose "Job Parameters file exists and has been sourced"
                                else    error "Job Parameters file cannot be enumerated at the specified location: ${WRAPPER_JOB_PARAMETERS}"
                                        error "Exiting ..."
                                        exit 15
                                fi

                                if      [[ -z ${WRAPPER_TOOL_COMMAND}  ||  -z ${WRAPPER_TOOL} ]]
                                then    error "There was an issue detecting the value for the Tool Command after sourcing the Job Parameters file"
                                        verbose "  Wrapper Tool Command : ${WRAPPER_TOOL_COMMAND}"
                                        verbose "  Wrapper Tool         : ${WRAPPER_TOOL}"
                                        error "Exiting ..."
                                        exit 16
                                else    verbose "Job Parameters have been successfully sourced:  Tool  |  Tool Command"
                                fi
                        else    error "Error parsing arguments in Launcher mode - exiting ..."
                                exit 17
                        fi

                elif    [[ ${WRAPPER_MODE^^} == "EXECUTOR" ]]
                then    verbose "Executor mode enabled"
                        if      [[ ${WRAPPER_NUMA_ENABLED^^} == "ENABLED" ]]
                        then    if      [[ ! $(command -v numactl)  &&  ! $(command -v lscpu) ]]
                                then    warning "NUMA is enabled in the wrapper (function: 'wrapper_set_programmatic_variables'), but the required packages are not available in \$PATH:  numactl  |  lscpu"
                                        warning "Process binding to NUMA resources is being disabled"
                                        unset WRAPPER_NUMA_ENABLED
                                else    verbose "NUMA is enabled, and the required packages are in place to support it:  numactl  |  lscpu"
                                fi
                        fi

                        if      [[ -z ${WRAPPER_TOOL_WITH_ARGS} ]]
                        then    if      [[ ! -f ${WRAPPER_TOOL}  &&  ! $(command -v ${WRAPPER_TOOL}) ]]
                                then    error "The tool cannot be found (as a file) or called (as a package) at the specified location: ${WRAPPER_TOOL}"
                                        error "Exiting ..."
                                        exit 18
                                elif    [[ -z ${WRAPPER_TOOL_COMMAND} ]]
                                then    error "Command not provided for the tool - this is needed to be able to proceed with the job"
                                        error "Exiting ..."
                                        exit 19
                                else    verbose "The tool exists at the specified location, and the command needed to execute it is supplied"
                                fi
                        fi

                        if      [[ ! -f ${WRAPPER_FILE_LIST} ]]
                        then    error "File list can not be enumerated: ${WRAPPER_FILE_LIST}"
                                error "Exiting ..."
                                exit 20
                        elif    [[ -z ${WRAPPER_FILE_LIST} ]]
                        then    error "A path to the input file list has not been provided"
                                error "Exiting ..."
                                exit 21
                        else    verbose "The file list path is specified, and the file list exists at that path"
                        fi
                else    error "Invalid options provided - exiting ..."
                        exit 22
                fi

                if      [[ ${WRAPPER_DEBUG} == "Debug" ]]
                then    verbose "Debug mode is enabled"
                        if      [[ ! $(command -v strace) ]]
                        then    warning "Debug mode is enabled, but the required package is not available in \$PATH:  strace"
                                warning "The job will continue to run, although debug mode will be disabled (verbose mode remains enabled)"
                                unset WRAPPER_DEBUG
                                unset WRAPPER_RUN_DEBUG
                        else    verbose "The package required to debug the invocation is available:  strace"
                        fi
                fi
                verbose "Complete"
        else    wrapper_help_statement
                exit 23
        fi
        verbose
}

wrapper_set_programmatic_variables() {
        export WRAPPER_JOB_NAME="run_$(basename ${WRAPPER_TOOL})"
        export WRAPPER_UUID_DATE="$(date +%Y%m%d)"
        export WRAPPER_UUID_TIME="$(date +%H%M%S)"
        export WRAPPER_UUID_RAND="${RANDOM}"
        export WRAPPER_UUID="${WRAPPER_JOB_NAME%.*}_T${WRAPPER_UUID_TIME}_R${WRAPPER_UUID_RAND}"

        export WRAPPER_OUTPUT_DIR="/path/to/persistent/storage_location"
        export WRAPPER_OUTPUT_DIR_BASE="${WRAPPER_OUTPUT_DIR}/${WRAPPER_UUID_DATE}/${WRAPPER_UUID}"
        export WRAPPER_OUTPUT_DIR_BASE_LOG="${WRAPPER_OUTPUT_DIR_BASE}/process_logs"
        export WRAPPER_OUTPUT_DIR_BASE_SCHEDULER="${WRAPPER_OUTPUT_DIR_BASE}/scheduler_logs"
        export WRAPPER_OUTPUT_DIR_BASE_NS_FILE_LISTS="${WRAPPER_OUTPUT_DIR_BASE}/namespace_file_lists"

        export WRAPPER_SCHEDULER_OUTPUT="${WRAPPER_OUTPUT_DIR_BASE_SCHEDULER}/"
        export WRAPPER_SCHEDULER_ERROR="${WRAPPER_OUTPUT_DIR_BASE_SCHEDULER}/"

        export WRAPPER_SCRATCH_BASE="/dev/shm/${WRAPPER_UUID}"

        export WRAPPER_NUMA_ENABLED="ENABLED"
        export WRAPPER_FILESYSTEM_TYPE="lustre"

        verbose "Job name          --> ${WRAPPER_JOB_NAME}"
        info    "UUID              --> ${WRAPPER_UUID}"
        info    "Output path       --> ${WRAPPER_OUTPUT_DIR_BASE}"
        verbose "Process logs      --> ${WRAPPER_OUTPUT_DIR_BASE_LOG}"
        verbose "Scheduler logs    --> ${WRAPPER_OUTPUT_DIR_BASE_SCHEDULER}"
        verbose "Namespace lists   --> ${WRAPPER_OUTPUT_DIR_BASE_NS_FILE_LISTS}"
        verbose "Scratch directory --> ${WRAPPER_SCRATCH_BASE}"
        verbose "NUMA node binding --> ${WRAPPER_NUMA_ENABLED}"
        info
        verbose "Setting launcher variables:"
        verbose "Complete"
        verbose

        if      [[ ${WRAPPER_OUTPUT_DIR} == "/path/to/persistent/storage_location" ]]
        then    if      [[ ! -d ${WRAPPER_OUTPUT_DIR} ]]
                then    error "Please edit the \${WRAPPER_OUTPUT_DIR} variable in the 'wrapper_set_programmatic_variables' function of the pbs_wrapper script"
                        error "The Launcher requires this path to be set to a real path to be able to run cleanly"
                        error "Exiting ..."
                        exit 1
                fi
        fi
}

wrapper_create_log_dirs() {
        if      [[ ! -d ${WRAPPER_OUTPUT_DIR} ]] 
        then    verbose "Creating job working directory:"
                mkdir -p ${WRAPPER_OUTPUT_DIR}
                if      (( ${?} == "0" ))
                then    verbose "Complete"
                else    error "Unable to create directory - exiting ..."
                        exit 24
                fi
        fi

        verbose "Creating unique base working directory for the job:"
        mkdir -p ${WRAPPER_OUTPUT_DIR_BASE}
        if      (( ${?} == "0" ))
        then    verbose "Complete"
        else    error "Unable to create directory - exiting ..."
                exit 25
        fi

        verbose "Creating scheduler log directory:"
        mkdir -p ${WRAPPER_OUTPUT_DIR_BASE_SCHEDULER}
        if      (( ${?} == "0" ))
        then    verbose "Complete"
        else    error "Unable to create directory - exiting ..."
                return 26
        fi

        verbose "Creating process log directory:"
        mkdir -p ${WRAPPER_OUTPUT_DIR_BASE_LOG}
        if      (( ${?} == "0" ))
        then    verbose "Complete"
        else    error "Unable to create directory - exiting ..."
                return 27
        fi

        verbose "Creating namespace-specific file list directory:"
        mkdir -p ${WRAPPER_OUTPUT_DIR_BASE_NS_FILE_LISTS}
        if      (( ${?} == "0" ))
        then    verbose "Complete"
        else    error "Unable to create directory - exiting ..."
                return 28
        fi

        verbose
}   

wrapper_parse_main_input() {
        verbose "Parsing the file list to determine input type ..."

        for     LINE in $(cat ${WRAPPER_FILE_LIST} | head -n 10)            # Depending on the file list length, 
        do      if      [[ -f ${LINE} ]]
                then    WRAPPER_INPUT_PATH="FILE_PATH"
                else    WRAPPER_INPUT_ID="<ID>"
                fi

                if      [[ -n ${WRAPPER_INPUT_PATH}  &&  -n ${WRAPPER_INPUT_ID} ]]
                then    error "Input sources of both file paths and IDs - cannot handle both simultaneously"
                        error "Exiting ..."
                        return 29
                fi
        done

        if      [[ ${WRAPPER_INPUT_ID} == "<ID>" ]]
        then    verbose "Querying <DATABASE> to translate <IDs>:"
                wrapper_query_database
                export WRAPPER_PARSED_INPUT="<Output_from_database_query>"
        elif    [[ ${WRAPPER_INPUT_PATH} == "FILE_PATH" ]]
        then    verbose "File list uses valid file paths – passing this directly to the tool execution function"
                export WRAPPER_PARSED_INPUT=${WRAPPER_FILE_LIST}
        else    error "An issue has occurred when trying to understand the result of the input parsing function - exiting ..."
                return 30
        fi

        WRAPPER_OBSERVED_FIREZONES=( $(df -t ${WRAPPER_FILESYSTEM_TYPE} | egrep '/fz[1-6][a-b]' | awk '{print $NF}' | sed 's|/||;s|[a-b]||' | uniq) )

        for     FIREZONE in ${WRAPPER_OBSERVED_FIREZONES[*]}
        do      egrep "${FIREZONE}" ${WRAPPER_PARSED_INPUT} > ${WRAPPER_OUTPUT_DIR_BASE_NS_FILE_LISTS}/wrapper_firezone_input-${FIREZONE}
        done

        verbose
}

wrapper_query_database() {
    # <...TO_BE_COMPLETED...>
    echo "Time to query the <DATABASE> ..."
    # exit under failure conditions
}

wrapper_scheduler_submit() {
        WRAPPER_OBSERVED_FIREZONES=( $(df -t ${WRAPPER_FILESYSTEM_TYPE} | egrep '/fz[1-6][a-b]' | awk '{print $NF}' | sed 's|/||;s|[a-b]||' | uniq) )

        for     FIREZONE in ${WRAPPER_OBSERVED_FIREZONES[*]}
        do      FIREZONE_INPUT="${WRAPPER_OUTPUT_DIR_BASE_NS_FILE_LISTS}/wrapper_firezone_input-${FIREZONE}"
                egrep "${FIREZONE}" ${WRAPPER_PARSED_INPUT} > ${FIREZONE_INPUT}

                WRAPPER_ARRAY_LENGTH=$(cat ${FIREZONE_INPUT} | wc -l)

                info "Submitting job array to the scheduler for ${FIREZONE} ..."
                        
                WRAPPER_SCHEDULER_COMMAND="qsub 
                                        -l select=1:ncpus=1:firezone=${FIREZONE}
                                        -J 1-${WRAPPER_ARRAY_LENGTH} 
                                        -j oe -o ${WRAPPER_SCHEDULER_OUTPUT} -e ${WRAPPER_SCHEDULER_ERROR}
                                        -V -v WRAPPER_MODE=Executor,EXECUTOR_FILE_LIST=${FIREZONE_INPUT},WRAPPER_FIREZONE=${FIREZONE}
                                        ${WRAPPER_SCHEDULER_EXTRA_ARGS}
                                        ${0}"

                verbose "Scheduler command: "
                verbose "${WRAPPER_RUN_DEBUG} ${WRAPPER_SCHEDULER_COMMAND}"

                WRAPPER_SCHEDULER_SUBMIT=$(eval ${WRAPPER_RUN_DEBUG} ${WRAPPER_SCHEDULER_COMMAND})

                if      (( ${?} == "0" ))
                then    info "Job submitted : ${WRAPPER_SCHEDULER_SUBMIT}"
                        info "Array length  : ${WRAPPER_ARRAY_LENGTH}"
                        info
                else    error "Scheduler command:"
                        error "${WRAPPER_RUN_DEBUG} ${WRAPPER_SCHEDULER_COMMAND}"
                        error "Failed to successfully submit job array to the scheduler - exiting ..."
                        warning "Note: PBS strongly prefers full paths to files - consider this when defining the path to files or scripts"
                        if      [[ -n ${WRAPPER_SCHEDULER_EXTRA_ARGS} ]]
                        then    warning "Note: Did you specify additional scheduler arguments? If so, it may be worth reviewing to ensure they can be correctly understood by PBS"
                        fi
                        return 31
                fi
        done
}

wrapper_execute_tool() {
        info "Firezone          --> ${WRAPPER_FIREZONE}"

        if      [[ ${WRAPPER_NUMA_ENABLED^^} == "ENABLED" ]]
        then    NUMA_DOMAINS=$(numactl -H | grep 'available' | cut -f '2,3,4' -d ' ')
                NUMA_NODE=$(( ${PBS_ARRAY_INDEX} % ${NUMA_DOMAINS:0:1} ))
                NUMA_BIND="numactl --cpunodebind=${NUMA_NODE} --membind=${NUMA_NODE}"
                verbose "NUMA enabled - details of usage: "
                verbose "  Number of NUMA domains    --> ${NUMA_DOMAINS}"
                verbose "  NUMA node selected        --> ${NUMA_NODE}"
                verbose "  NUMA binding command      --> ${NUMA_BIND}"
        fi

        INPUT=$(sed -n "${PBS_ARRAY_INDEX}p" ${EXECUTOR_FILE_LIST})
        verbose "Input file: ${INPUT}"

        if      [[ ! -f ${INPUT} ]]
        then    error "The specific input file for this execution cannot be enumerated at the following location: ${INPUT}"
                error "Skipping processing ..."
        else    verbose "Input file existence validated - proceeding to processing"
                if      [[ ${WRAPPER_LAUNCHER_MODE^^} == "COMMAND_LINE" ]]
                then    verbose "Command to be executed: ${NUMA_BIND} ${WRAPPER_RUN_DEBUG} ${WRAPPER_TOOL_WITH_ARGS}"
                        echo
                        eval ${NUMA_BIND} ${WRAPPER_RUN_DEBUG} ${WRAPPER_TOOL_WITH_ARGS}
                        EXECUTOR_EXIT_CODE=${?}
                elif    [[ ${WRAPPER_LAUNCHER_MODE^^} == "JOB_PARAMETERS" ]]
                then    verbose "${NUMA_BIND} ${WRAPPER_RUN_DEBUG} ${WRAPPER_TOOL_COMMAND}"
                        echo
                        eval ${NUMA_BIND} ${WRAPPER_RUN_DEBUG} ${WRAPPER_TOOL_COMMAND}
                        EXECUTOR_EXIT_CODE=${?}
                else    error "An issue occurred parsing the Launcher Mode (CLI or Job Parameters) to be able to trigger task execution"
                fi

                echo
                
                if      (( ${EXECUTOR_EXIT_CODE} == "0" ))
                then    info "Task successfully executed"
                else    error "*** FAILED:  Task ${PBS_ARRAY_INDEX} returned a non-zero exit code"
                fi
        fi
}

#-----------------------------------------------------------------------------------------------------------------------------------------------#
## RUN_TIME:
RUN_UUID="/dev/shm/${RANDOM}${RANDOM}"
{
trap cleanup_clean EXIT
echo
info "#-------------------------------------------#"
info "#        PBS: JOB SUBMISSION WRAPPER        #"
info "#-------------------------------------------#"
info

while getopts "a:i:x:p:dvh" OPTION
do  case ${OPTION} in
        a )     export WRAPPER_TOOL_WITH_ARGS=${OPTARG}
                export WRAPPER_TOOL=${WRAPPER_TOOL_WITH_ARGS%% *}
                export WRAPPER_LAUNCHER_MODE="COMMAND_LINE"
                export WRAPPER_JOB_PARAMETERS="(Not set)"
                WRAPPER_MODE="Launcher"
                trap cleanup_error ERR SIGINT SIGTERM
                    ;;
        i )     if      [[ ${WRAPPER_LAUNCHER_MODE^^} == "COMMAND_LINE" ]]
                then    export WRAPPER_FILE_LIST=${OPTARG}
                else    warning "File list input provided, however an argument was not passed to the '-a' flag"
                        warning "Ignoring this input, and falling back to reading from the Job Parameters file"
                fi
                    ;;
        x )     export WRAPPER_SCHEDULER_EXTRA_ARGS=${OPTARG}
                    ;;
        p )     if      [[ ${WRAPPER_LAUNCHER_MODE^^} == "COMMAND_LINE" ]]
                then    warning "An argument has been provided to the '-a' flag, which trumps other flags"
                        warning "The Launcher will continue, but ignoring the '-p' flag to specify the Job Parameters"
                else    export WRAPPER_JOB_PARAMETERS=${OPTARG}
                        export WRAPPER_LAUNCHER_MODE="JOB_PARAMETERS"
                        WRAPPER_MODE="Launcher"
                        trap cleanup_error ERR SIGINT SIGTERM
                fi
                    ;;
        d )     set -x
                export WRAPPER_VERBOSE="Verbose"
                export WRAPPER_DEBUG="Debug"
                export WRAPPER_RUN_DEBUG="strace -d -t"
                    ;;
        v )     export WRAPPER_VERBOSE="Verbose"
                    ;;
        h )     wrapper_help_statement
                exit 0
                    ;;
        * )     error "Invalid arguments passed to the script: -${OPTARG}"
                error "If you are passing the '-a' flag, please make sure to put a single quote around the string. For example: -a '/path/to/tool.bin -arg A -arg B -port 12345'"
                error "Exiting ..."
                wrapper_help_statement
                exit 1
                    ;;
    esac
done
shift $((OPTIND-1))

wrapper_validation

info    "Operation         --> Run $(basename ${WRAPPER_TOOL}) against an input dataset"
info    "Job Parameters    --> ${WRAPPER_JOB_PARAMETERS}"
info    "Script mode       --> ${WRAPPER_MODE}"
info    "Tool/Package path --> ${WRAPPER_TOOL}"
info    "Tool Command      --> ${WRAPPER_TOOL_WITH_ARGS}${WRAPPER_TOOL_COMMAND}"
info    "File list         --> ${WRAPPER_FILE_LIST}"
verbose "Verbosity         --> ${WRAPPER_VERBOSE}  ${WRAPPER_DEBUG}"

if      [[ ${WRAPPER_MODE^^} == "LAUNCHER" ]]
then    wrapper_set_programmatic_variables
        wrapper_create_log_dirs
        wrapper_parse_main_input
        wrapper_scheduler_submit
elif    [[ ${WRAPPER_MODE^^} == "EXECUTOR" ]]
then    wrapper_execute_tool
fi

if      [[ ${WRAPPER_VERBOSE^^} == "VERBOSE"  ||  ${WRAPPER_MODE^^} == "EXECUTOR" ]]
then    info "Printing relevant environment ..."
        echo -e "\n$(env | sort)\n"
fi

WRAPPER_COMPLETION_STATUS="Complete"
info "${WRAPPER_MODE} status: ${WRAPPER_COMPLETION_STATUS}"
echo
} | tee -a ${RUN_UUID}
