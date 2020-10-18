#!/bin/bash
#
#------------------------------------------------------------------------------------------------------------------------------------------------------------#
# README
# Glossary:
#   GTL = Generic Tool Launcher
#   SFL = Splitted File List
#
#       1) Users should create a copy of the Job Parameters file, and make changes accordingly to it which will represent the work that will be undertaken
#       2) The generic_tool_launcher.sh script should, under normal circumstances, not need to be modified to facilitate job submission & execution
#       3) Slurm and PBS are supported schedulers, but do have some differences, though for the most part just use the defaults, unless otherwise adapted
#       4) A new log directory will be created for every invocation of the Generic Tool Launcher, to simplify interrogation of specific runs
#
#------------------------------------------------------------------------------------------------------------------------------------------------------------#
# MAIN FUNCTIONS

help() { 
        echo -e "`date "+%Y/%m/%d   %H:%M:%S"`\t[HELP]    ${1}" 
}
info() { 
        echo -e "`date "+%Y/%m/%d   %H:%M:%S"`\t[INFO]    ${1}" 
}
warning() { 
        echo -e "`date "+%Y/%m/%d   %H:%M:%S"`\t[WARNING] ${1}" 
}
error() { 
        echo -e "`date "+%Y/%m/%d   %H:%M:%S"`\t[ERROR]   ${1}" 
}

gtl_help_statement() {
        help "Operation         --> Printing the help menu"
        help "Overview          --> A wrapper script to support the massively parallel execution of _TOOL_"
        help
        help "Usage: ${0} [-l | -e] [-p /path/to/job_parameters.sh | -f /path/to/file/list.txt] [-v] [-d] [-h]"
        help "  -l     Sets the script mode to launch execution jobs via the scheduler                          : Mandatory argument 1/2 (a)   --  mutually exclusive with '-e' flag"
        help "  -e     Sets the script mode to execute tool processing                                          : Mandatory argument 1/2 (b)   --  mutually exclusive with '-l' flag"
        help "  -p     Requires the path (absolute or relative) to the job parameters file                      : Mandatory argument 2/2 (a)   --  exclusively used by the Launcher mode"
        help "  -f     Requires the path (absolute or relative) to the input file list or file list map         : Mandatory argument 2/2 (b)   --  exclusively used by the Executor mode"
        help "  -v     Enables verbose mode                                                                     : Optional argument"
        help "  -d     Enables debug mode (also enables verbose mode)                                           : Optional argument"
        help "  -h     Show this help message                                                                   : Optional argument"
        help
        help "Example commands:"
        help "  ${0} -l -p /path/to/job_params.sh       --> Runs the script in 'Launcher' mode, specifying the job parameters file at the absolute path :  /path/to/job_parameters.sh"
        help "  ${0} -e -f dir/with/file/list_map.txt   --> Runs the script in 'Executor' mode, specifying the file list map at the relative path :  dir/with/file/list_map.txt"
        help "  ${0} -l -p /path/to/job_params.sh -d    --> Runs the script in 'Launcher' mode with debug enabled, specifying the job parameters file at the absolute path :  /path/to/Decode_JobParams.sh"
        echo
}

gtl_validation() {
        info "Running validation:"
        if      (( ${OPTIND} == 1 ))
        then    gtl_help_statement
                exit 1
        fi

        if [[ ${GTL_MODE} == "Launcher" ]]
        then    if      [[ ${GTL_SCHEDULER^^} == "SLURM" ]]
                then    if      [[ ! $(command -v split)  &&  ! $(command -v sed)  &&  ! $(command -v sbatch) ]]
                        then    error "Required packages are not available in \$PATH and we cannnot continue:  split  |  sed  |  sbatch"
                                error "Exiting ..."
                                exit 1
                        fi
                elif    [[ ${GTL_SCHEDULER^^} == "PBS" ]]
                then    if      [[ ! $(command -v split)  &&  ! $(command -v sed)  &&  ! $(command -v qsub) ]]
                        then    error "Required packages are not available in \$PATH and we cannnot continue:  split  |  sed  |  qsub"
                                error "Exiting ..."
                                exit 1
                        fi
                else    error "Invalid scheduler choice: ${GTL_SCHEDULER}"
                        error "Slurm and PBS are currently the supported scheduler options"
                        error "Exiting ..."
                        exit 1
                fi

                if      [[ ! -f ${GTL_TOOL} ]]
                then    warning "The Launcher cannot find the tool (as a file) at the specified location:  ${GTL_TOOL}"
                        warning "As the Executor will also check to verify it can reach the specified tool, the Launcher will continue ..."
                fi

                if      [[ ! -f ${GTL_FILE_LIST} ]]
                then    error "File list can not be enumerated: ${GTL_FILE_LIST}"
                        error "Exiting ..."
                        exit 1
                elif    (( $(cat ${GTL_FILE_LIST} | wc -l) == "0" ))
                then    error "The file list specified appears to have 0 lines, i.e. an empty file - thus, no work can be done here"
                        error "Exiting ..."
                        exit 1
                elif    [[ -z ${GTL_FILE_LIST} ]]
                then    error "A path to the input file list has not been provided - exiting ..."
                        exit 1
                fi

                if      (( ${GTL_RANGE} > $(cat ${GTL_FILE_LIST} | wc -l) ))
                then    info "The specified parallelisation range of '${GTL_RANGE}' is greater than the number of lines in the specified file list: '$(cat ${GTL_FILE_LIST} | wc -l)'"
                        info "The Launcher will reduce the parallelisation range to the length of the file list, and continue to execute ..."
                        export GTL_RANGE=$(cat ${GTL_FILE_LIST} | wc -l)
                fi

        elif    [[ ${GTL_MODE} == "Executor" ]]
        then    if      [[ ${GTL_NUMA_ENABLED} == "ENABLED" ]]
                then    if      [[ ! $(command -v numactl)  &&  ! $(command -v lscpu) ]]
                        then    error "NUMA is enabled in the Job Parameters file, but the required packages are not available in \$PATH and we cannot continue:  numactl  |  lscpu"
                        error "Exiting ..."
                        exit 1
                        fi
                fi

                if      [[ ! -f ${GTL_TOOL} ]]
                then    error "The tool cannot be found (as a file) at the specified location:  ${GTL_TOOL}"
                        error "Exiting ..."
                        exit 1
                fi

                if      [[ ! -f ${GTL_FILE_LIST} ]]
                then    error "File list can not be enumerated: ${GTL_FILE_LIST}"
                        error "Exiting ..."
                        exit 1
                elif    [[ -z ${GTL_FILE_LIST} ]]
                then    error "A path to the input file list has not been provided - exiting ..."
                        exit 1
                fi

        elif    [[ ${GTL_MODE} != "Launcher"  &&  ${GTL_MODE} != "Executor" ]]
        then    error "Neither Launcher nor Executor mode specified for this script - exiting ..."
                exit 1
        else    info "Complete"
        fi

        if      [[ ${GTL_DEBUG} == "Debug" ]]
        then    if      [[ ! $(command -v strace) ]]
                then    info "Debug mode is enabled, but the required package is not available in \$PATH:  strace"
                        info "The job will continue to run, although debug mode will be disabled (verbose mode remains enabled)"
                        unset GTL_DEBUG
                        unset GTL_RUN_DEBUG
                fi
        fi
        info
}

gtl_launcher_set_programmatic_variables() {
        export GTL_JOB_NAME="run_$(basename ${GTL_TOOL})"
        export GTL_UUID="${GTL_JOB_NAME%.*}_D$(date +%Y%m%d)_T$(date +%H%M%S)_R${RANDOM}"

        export GTL_WORKING_DIR_BASE="${GTL_WORKING_DIR}/${GTL_UUID}"
        export GTL_WORKING_DIR_BASE_LOG="${GTL_WORKING_DIR_BASE}/process_logs"
        export GTL_WORKING_DIR_BASE_SFL="${GTL_WORKING_DIR_BASE}/splitted_file_lists"
        export GTL_WORKING_DIR_BASE_SFL_FINISHED="${GTL_WORKING_DIR_BASE_SFL}/finished_maps"
        export GTL_WORKING_DIR_BASE_SCHEDULER="${GTL_WORKING_DIR_BASE}/scheduler_logs"

        export GTL_SFL_PREFIX="${GTL_WORKING_DIR_BASE_SFL}/${GTL_UUID}-split_fragment-$(basename ${GTL_FILE_LIST})-"
        export GTL_SFL_MAP="${GTL_WORKING_DIR_BASE_SFL}/${GTL_UUID}_central_file_list_map.txt"

        export GTL_SCRATCH_BASE="/dev/shm/${GTL_UUID}"

        info "Tool path         --> ${GTL_TOOL}"
        info "Output path       --> ${GTL_WORKING_DIR_BASE}"
        info "UUID              --> ${GTL_UUID}"
        info
        info "Setting launcher variables:"
        info "Complete"
        info
}

gtl_create_log_dirs() {
        if      [[ ! -d ${GTL_WORKING_DIR} ]] 
        then    info "Creating job working directory:"
                mkdir -p ${GTL_WORKING_DIR}
                if      (( ${?} == "0" ))
                then    info "Complete"
                else    error "Unable to create directory - exiting ..."
                        exit 1
                fi
        fi

        info "Creating unique base working directory for the job:"
        mkdir -p ${GTL_WORKING_DIR_BASE}
        if      (( ${?} == "0" ))
        then    info "Complete"
        else    error "Unable to create directory - exiting ..."
                exit 1
        fi

        info "Creating split file list directory:"
        mkdir -p ${GTL_WORKING_DIR_BASE_SFL}
        if      (( ${?} == "0" ))
        then    info "Complete"
        else    error "Unable to create directory - exiting ..."
                exit 1
        fi

        info "Creating split file list sub-directory for finished maps:"
        mkdir -p ${GTL_WORKING_DIR_BASE_SFL_FINISHED}
        if      (( ${?} == "0" ))
        then    info "Complete"
        else    error "Unable to create directory - exiting ..."
                exit 1
        fi

        info "Creating scheduler log directory:"
        mkdir -p ${GTL_WORKING_DIR_BASE_SCHEDULER}
        if      (( ${?} == "0" ))
        then    info "Complete"
        else    error "Unable to create directory - exiting ..."
                exit 1
        fi

        info "Creating process log directory:"
        mkdir -p ${GTL_WORKING_DIR_BASE_LOG}
        if      (( ${?} == "0" ))
        then    info "Complete"
        else    error "Unable to create directory - exiting ..."
                exit 1
        fi

        info
}

gtl_split_file_list() {    
        info "Initiating split of input file list:"
        ${GTL_RUN_DEBUG} split --number=l/${GTL_RANGE} --numeric=1 -d --suffix-length=6 ${GTL_FILE_LIST} ${GTL_SFL_PREFIX}
                if      (( ${?} == "0" ))
                then    info "Complete"
                else    error "Unable to split the input file list - exiting ..."
                        exit 1
                fi

        find ${GTL_WORKING_DIR_BASE_SFL} -name "$(basename ${GTL_SFL_PREFIX})*" -type f | sort > ${GTL_SFL_MAP}

        info
}

gtl_scheduler_submit() {    
        info "Submitting job array to the scheduler:"

        #GTL_RANGE_THROTTLE="%1000"
        
        if      [[ ${GTL_SCHEDULER^^} == "SLURM" ]]
        then    export GTL_SCHEDULER_OUTPUT="${GTL_WORKING_DIR_BASE_SCHEDULER}/%x-%A_%a.out"
                export GTL_SCHEDULER_ERROR="${GTL_WORKING_DIR_BASE_SCHEDULER}/%x-%A_%a.out"
                
                GTL_SCHEDULER_COMMAND="sbatch
                        --array=1-${GTL_RANGE}${GTL_RANGE_THROTTLE}
                        --job-name=${GTL_JOB_NAME} --output=${GTL_SCHEDULER_OUTPUT} --error=${GTL_SCHEDULER_ERROR}
                        ${GTL_SCHEDULER_EXTRA_ARGS} ${0} ${GTL_VERBOSE_FLAG} ${GTL_DEBUG_FLAG} -e -f ${GTL_SFL_MAP}"

        elif    [[ ${GTL_SCHEDULER^^} == "PBS" ]]
        then    export GTL_SCHEDULER_OUTPUT="${GTL_WORKING_DIR_BASE_SCHEDULER}/"
                export GTL_SCHEDULER_ERROR="${GTL_WORKING_DIR_BASE_SCHEDULER}/"
                
                GTL_SCHEDULER_COMMAND="echo ${0} ${GTL_VERBOSE_FLAG} ${GTL_DEBUG_FLAG} -e -f ${GTL_SFL_MAP} | qsub
                        -J 1-${GTL_RANGE}
                        -N ${GTL_JOB_NAME} -j oe -o ${GTL_SCHEDULER_OUTPUT} -e ${GTL_SCHEDULER_ERROR}
                        -V ${GTL_SCHEDULER_EXTRA_ARGS}"
        fi

        GTL_SCHEDULER_SUBMIT=$(eval ${GTL_RUN_DEBUG} ${GTL_SCHEDULER_COMMAND})

        if      (( ${?} == "0" ))
        then    info "${GTL_SCHEDULER_SUBMIT}"
        else    error "${GTL_SCHEDULER_SUBMIT}"
                error "Failed to successfully submit job array to the scheduler - exiting ..."
                if      [[ ${GTL_SCHEDULER} == "PBS" ]]
                then    error "PBS strongly prefers full paths to files - consider this when defining the path to files or scripts"
                fi
                exit 1
        fi

        info
}

gtl_execution() {
        if      [[ ${GTL_SCHEDULER^^} == "SLURM" ]]
        then    SCHEDULER_ARRAY_JOB_ID="${SLURM_ARRAY_JOB_ID}"
                SCHEDULER_ARRAY_TASK_ID="${SLURM_ARRAY_TASK_ID}"
        elif    [[ ${GTL_SCHEDULER^^} == "PBS" ]]
        then    SCHEDULER_ARRAY_JOB_ID="${PBS_JOBID%[*}"
                SCHEDULER_ARRAY_TASK_ID="${PBS_ARRAY_INDEX}"
                export PBS_NODE_NAME=$(hostname -f)
        fi

        GTL_FILE_LIST_SEGMENT=$(sed -n "${SCHEDULER_ARRAY_TASK_ID}p" ${GTL_SFL_MAP})
        
        GTL_SCRATCH_TASK_DIR="${GTL_SCRATCH_BASE}/${SCHEDULER_ARRAY_JOB_ID}_${SCHEDULER_ARRAY_TASK_ID}"
        GTL_SCRATCH_TASK_LOG_FILE="${GTL_SCRATCH_TASK_DIR}/$(basename ${GTL_FILE_LIST_SEGMENT})"

        if      [[ ${GTL_NUMA_ENABLED} == "ENABLED" ]]
        then    GTL_NUMA_DOMAINS=$(lscpu | grep 'NUMA node(s)' | awk '{print $3}')
                GTL_NUMA_NODE=$(( ${SCHEDULER_ARRAY_TASK_ID} % ${GTL_NUMA_DOMAINS} ))
                GTL_NUMA_BIND="numactl --cpunodebind=${GTL_NUMA_NODE} --membind=${GTL_NUMA_NODE}"
        fi

        info "File list         --> ${GTL_FILE_LIST_SEGMENT}"
        info
        info "Executing processing:"

        if [[ -f ${GTL_FILE_LIST_SEGMENT} ]]
        then
                mkdir -p ${GTL_SCRATCH_TASK_DIR}
                mv ${GTL_FILE_LIST_SEGMENT} ${GTL_SCRATCH_TASK_LOG_FILE}

                for GTL_INPUT_FILE in $(cat ${GTL_SCRATCH_TASK_LOG_FILE})
                do      source ${GTL_JOB_PARAMETERS}
                        ${GTL_RUN_DEBUG} ${GTL_NUMA_BIND} ${GTL_TOOL_COMMAND}

                        if      (( ${?} == "0" ))
                        then    info "Processing successfully completed     : ${GTL_INPUT_FILE}"
                        else    error "*** Processing failed                 : ${GTL_INPUT_FILE}"
                        fi
                done
                info
                info "All segments processed from file list : $(basename ${GTL_SCRATCH_TASK_LOG_FILE})"
                info
                if      find ${GTL_SCRATCH_TASK_DIR} -mindepth 1 | read
                then    if      [[ -f ${GTL_SCRATCH_TASK_LOG_FILE} ]]
                        then    info "Moving input file map from scratch to persistent storage:"
                                mv ${GTL_SCRATCH_TASK_LOG_FILE} ${GTL_WORKING_DIR_BASE_SFL_FINISHED} 2>/dev/null
                                if      (( ${?} == "0" ))
                                then    info "Complete"
                                else    error "Error moving input file map"
                                fi
                        fi
                        info "Cleaning up task remnants ..."
                        rm -rf ${GTL_SCRATCH_TASK_DIR}
                else    info "Scratch directory is empty - will clean up ..."
                        rmdir ${GTL_SCRATCH_TASK_DIR}
                fi
        else    error "Unable to enumerate file list: ${GTL_FILE_LIST_SEGMENT}"
                error "Exiting ..."
                exit 1
        fi

        info
}

#------------------------------------------------------------------------------------------------------------------------------------------------------#
# EXECUTION

echo
info "#---------------------------------------#"
info "#        GENERIC  TOOL  LAUNCHER        #"
info "#---------------------------------------#"
info

unset GTL_MODE

while getopts "f:p::levdh" OPTION
do  case ${OPTION} in
        l )     if      [[ -n ${GTL_MODE} ]]
                then    error "Multiple execution modes specified: ${*}" 
                        error "Please invoke the script again and specify either '-l' (for Launcher) or '-e' (for Executor)"
                        error "Exiting ..."
                        exit 1
                else    GTL_MODE="Launcher"
                fi     
                    ;;
        e )     if      [[ -n ${GTL_MODE} ]]
                then    error "Multiple execution modes specified: ${*}" 
                        error "Please invoke the script again and specify either '-l' (for Launcher) or '-e' (for Executor)"
                        error "Exiting ..."
                        exit 1
                else    GTL_MODE="Executor"
                fi     
                    ;;
        p )     if      [[ ! -f ${OPTARG} ]]
                then    error "Job parameters file cannot be enumerated: ${OPTARG}"
                        error "Exiting ..."
                        exit 1
                else    export GTL_JOB_PARAMETERS=${OPTARG}
                        source ${GTL_JOB_PARAMETERS}
                fi
                    ;;
        f )     if      [[ ! -f ${OPTARG} ]]
                then    error "File list can not be enumerated: ${OPTARG}"
                        error "Exiting ..."
                        exit 1
                else    GTL_FILE_LIST=${OPTARG}
                fi
                    ;;
        v )     set -x
                export GTL_VERBOSE="Verbose"
                export GTL_VERBOSE_FLAG="-v"
                    ;;
        d )     set -x
                export GTL_VERBOSE="Verbose"
                export GTL_DEBUG="Debug"
                export GTL_DEBUG_FLAG="-d"
                export GTL_RUN_DEBUG="strace -d -t"
                    ;;
        h )     gtl_help_statement
                exit 0
                    ;;
        * )     error "Invalid arguments passed to the script: -${OPTARG}"
                error "Exiting ..."
                gtl_help_statement
                exit 1
                    ;;
    esac
done
shift $((OPTIND-1))

gtl_validation

info "Operation         --> Run $(basename ${GTL_TOOL}) against an input dataset"
info "Job Parameters    --> ${GTL_JOB_PARAMETERS}"
info "Script mode       --> ${GTL_MODE}"
if      [[ -n ${GTL_VERBOSE} || -n ${GTL_DEBUG} ]] 
then    info "Verbosity         --> ${GTL_VERBOSE}  ${GTL_DEBUG}"
fi

if      [[ ${GTL_MODE} == "Launcher" ]]
then    info "File list         --> ${GTL_FILE_LIST}"
        gtl_launcher_set_programmatic_variables
        gtl_create_log_dirs
        gtl_split_file_list
        gtl_scheduler_submit
elif    [[ ${GTL_MODE} == "Executor" ]]
then    gtl_execution
fi

if      [[ ${GTL_VERBOSE^^} == "VERBOSE" || ${GTL_MODE} == "Executor" ]]
then    info "Printing relevant environment..."
        echo -e "\n$(env | egrep "${GTL_SCHEDULER^^}|GTL|PATH" | sort)\n"
fi

info "${GTL_MODE} complete"
echo