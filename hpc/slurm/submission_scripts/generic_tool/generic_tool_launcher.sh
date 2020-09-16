#!/bin/bash
#
#------------------------------------------------------------------------------------------------------------------------------------------------------#
# README
    # Glossary:
    #   GTL = Generic Tool Launcher
    #   SFL = Splitted File List
    #
    # Notes:
    #   1) Please amend & set the variables contained in gtl_set_variables() function
    #   2) Please specify the exact syntax required for the tool to operate in the gtl_execution() function
    #
    # Tool Syntax:
    #   numactl --cpunodebind=${GTL_NUMA_NODE} --membind=${GTL_NUMA_NODE} \
    #       ${GTL_TOOL} \
    #           --input             ${GTL_INPUT} \
    #           --output            ${GTL_OUTPUT}
    #           --output-log        ${GTL_OUTPUT_LOG} \
    #           --custom-port       ${GTL_PORT}
    #           --custom-flag       update_database
    #
    # Sample command:
    #   numactl --cpunodebind=${GTL_NUMA_NODE} --membind=${GTL_NUMA_NODE} \
    #       ${GTL_TOOL} \
    #           --input             /path/to/input/file.dat \
    #           --output            /path/to/output/processed_file.dat \
    #           --output-log        /path/to/log/directory/file_output.log \
    #           --custom-port       12345 \
    #           --custom-flag       update_database
#
#------------------------------------------------------------------------------------------------------------------------------------------------------#
# USER-DEFINED FUNCTIONS
gtl_launcher_set_custom_variables() {
        export GTL_TOOL="/full/path/to/location/to/invoke_tool.bin"             # Path to the tool being used

        export GTL_WORKING_DIR="/path/to/shared/working/output/directory"       # Where artifacts will be created and stored during the job execution

        export GTL_RANGE="4"                                                    # How wide should the jobs be parallelised? Take into account the wall time per individual process.

        export GTL_EXTRA_SLURM_ARGS="--chdir=$(dirname ${GTL_TOOL})"            # If particular Slurm flags are needed, such as working in a specific directory (to save setting library paths)

        #export GTL_ANY_OTHER_NECESSARY_ENV_VAR_A="ABC123"
        #export GTL_ANY_OTHER_NECESSARY_ENV_VAR_B="DEF456"
        #export GTL_ANY_OTHER_NECESSARY_ENV_VAR_C="GHI789"
}

gtl_tool_command() {
        # Associated variables used in this section are:
        #    GTL_INPUT_FILE    <--- Used in for loop to cycle through individual lines in a job's individual file list

        # Add additional variables, substitutions etc. to this function to specifically manipulate strings to work with the tool being used

        GTL_OUTPUT="$(dirname ${GTL_INPUT_FILE})/$(basename ${GTL_INPUT_FILE} | cut -f1 -d '.')_OUTPUT.dat"
        GTL_OUTPUT_LOG="${GTL_TEMP_LOG}/$(basename ${GTL_INPUT_FILE} | cut -f1 -d '.').log"

        numactl --cpunodebind=${GTL_NUMA_NODE} --membind=${GTL_NUMA_NODE} \
        ${GTL_TOOL} \
                    --input         ${GTL_INPUT_FILE} \
                    --output        ${GTL_OUTPUT} \
                    --output-log    ${GTL_OUTPUT_LOG} \
                    --custom-port   12345 \
                    --custom-flag   update_database
}

#------------------------------------------------------------------------------------------------------------------------------------------------------#
# MAIN FUNCTIONS

help() {
        echo -e "`date "+%Y/%m/%d   %H:%M:%S"`\t[HELP]   ${1}" 
}
info() {
        echo -e "`date "+%Y/%m/%d   %H:%M:%S"`\t[INFO]   ${1}" 
}
error() {
        echo -e "`date "+%Y/%m/%d   %H:%M:%S"`\t[ERROR]  ${1}"
}

gtl_help_statement() {
        help "Operation         --> Printing the help menu"
        help "Overview          --> A wrapper script to support the massively parallel execution of _TOOL_"
        help
        help "Usage: ${0} [-l | -e] [-f /path/to/file/list.txt] [-v] [-h]"
        help "  -l     Sets the script mode to launch execution jobs via Slurm                              : Mandatory argument 1/2  --  mutually exclusive with '-e' flag"
        help "  -e     Sets the script mode to execute tool processing                                      : Mandatory argument 1/2  --  mutually exclusive with '-l' flag"
        help "  -f     Requires the path (absolute or relative) to the input file list or file list map     : Mandatory argument 2/2"
        help "  -v     Enables verbose mode                                                                 : Optional argument"
        help "  -h     Show this help message                                                               : Optional argument"
        help
        help "Example commands:"
        help "  ${0} -l -f /path/to/file/list.txt       --> Runs the script in 'Launcher' mode, specifying the full file list at the absolute path : /path/to/file/list.txt"
        help "  ${0} -e -f dir/with/file/list_map.txt   --> Runs the script in 'Executor' mode, specifying the file list map at the relative path  : dir/with/file/list_map.txt"
        echo
}

gtl_validation() {
        info "Running validation:"
        if      (( ${OPTIND} == 1 ))
        then    gtl_help_statement
                exit 1
        fi

        if      [[ ! $(command -v split)  &&  ! $(command -v sbatch) ]]
        then    error "Required packages are not available and we cannnot continue:  split  |  sbatch"
                error "Exiting ..."
                exit 1    
        elif    [[ -z ${GTL_FILE_LIST} ]]
        then    error "A path to the input file list has not been provided - exiting ..."
                exit 1
        elif    [[ ${GTL_MODE} != "Launcher"  &&  ${GTL_MODE} != "Executor" ]]
        then    error "Neither Launcher nor Executor mode specified for this script - exiting ..."
                exit 1
        else    info "Complete"
        fi

        info
}

gtl_launcher_set_programmatic_variables() {
        export GTL_UUID="$(date +%Y%m%d_%H%M%S)_${RANDOM}"
        export GTL_RANGE="4"    # How wide should the jobs be parallelised? Take into account the wall time per individual process.

        export GTL_WORKING_DIR_LOG="${GTL_WORKING_DIR}/process_logs"
        export GTL_WORKING_DIR_SFL="${GTL_WORKING_DIR}/splitted_file_lists"
        export GTL_WORKING_DIR_SLURM="${GTL_WORKING_DIR}/slurm_logs"

        export GTL_SFL_PREFIX="${GTL_WORKING_DIR_SFL}/${GTL_UUID}-split_fragment-$(basename ${GTL_FILE_LIST})-"
        export GTL_SFL_MAP="${GTL_WORKING_DIR_SFL}/${GTL_UUID}_central_file_list_map.txt"

        export GTL_SLURM_OUTPUT="${GTL_WORKING_DIR_SLURM}/%x-%A_%a.out"
        export GTL_SLURM_ERROR="${GTL_WORKING_DIR_SLURM}/%x-%A_%a.out"

        export GTL_TEMP_LOG_DIR="/dev/shm"

        info "Tool path         --> ${GTL_TOOL}"
        info "Output path       --> ${GTL_WORKING_DIR}"
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
                if      [[ ${?} == "0" ]]
                then    info "Complete"
                else    error "Unable to create directory - exiting ..."
                        exit 1
                fi
        fi

        if      [[ ! -d ${GTL_WORKING_DIR_SFL} ]] 
        then    info "Creating split file list directory:"
                mkdir -p ${GTL_WORKING_DIR_SFL}
                if      [[ ${?} == "0" ]]
                then    info "Complete"
                else    error "Unable to create directory - exiting ..."
                        exit 1
                fi
        fi

        if      [[ ! -d ${GTL_WORKING_DIR_SLURM} ]] 
        then    info "Creating Slurm log directory:"
                mkdir -p ${GTL_WORKING_DIR_SLURM}
                if      [[ ${?} == "0" ]]
                then    info "Complete"
                else    error "Unable to create directory - exiting ..."
                        exit 1
                fi
        fi

        if      [[ ! -d ${GTL_WORKING_DIR_LOG} ]] 
        then    info "Creating process log directory:"
                mkdir -p ${GTL_WORKING_DIR_LOG}
                if      [[ ${?} == "0" ]]
                then    info "Complete"
                else    error "Unable to create directory - exiting ..."
                        exit 1
                fi
        fi

        info
}

gtl_split_file_list() {    
        info "Initiating split of input file list:"
        split --number=l/${GTL_RANGE} --numeric=1 -d --suffix-length=6 ${GTL_FILE_LIST} ${GTL_SFL_PREFIX}
                if      [[ ${?} == "0" ]]
                then    info "Complete"
                else    error "Unable to split the input file list - exiting ..."
                        exit 1
                fi

        find ${GTL_WORKING_DIR_SFL} -name "$(basename ${GTL_SFL_PREFIX})*" -type f | sort > ${GTL_SFL_MAP}

        info
}

gtl_slurm_submit() {    
        info "Submitting job array to Slurm:"

        #GTL_RANGE_THROTTLE="%1000"
        GTL_SLURM_SUBMIT=$(sbatch  \
                --partition=default --array=1-${GTL_RANGE}${GTL_RANGE_THROTTLE} \
                --job-name=generic_tool_launcher --output=${GTL_SLURM_OUTPUT} --error=${GTL_SLURM_ERROR} \
                ${GTL_EXTRA_SLURM_ARGS} ${0} -e -f ${GTL_SFL_MAP})

        if      [[ ${?} == "0" ]]
        then    info "${GTL_SLURM_SUBMIT}"
        else    error "${GTL_SLURM_SUBMIT}"
                error "Failed to successfully submit job array to Slurm - exiting ..."
                exit 1
        fi

        info
}

gtl_execution() {
        GTL_FILE_LIST_SEGMENT=$(sed -n "${SLURM_ARRAY_TASK_ID}p" ${GTL_FILE_LIST})
        GTL_TEMP_LOG="${GTL_TEMP_LOG_DIR}/${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}"

        GTL_NUMA_DOMAINS="2"
        GTL_NUMA_NODE=$(( ${SLURM_ARRAY_TASK_ID} % ${GTL_NUMA_DOMAINS} ))

        info "File list         --> ${GTL_FILE_LIST_SEGMENT}"
        info
        info "Executing processing:"

        if [[ -f ${GTL_FILE_LIST_SEGMENT} ]]
        then
                mkdir ${GTL_TEMP_LOG}

                for GTL_INPUT_FILE in $(cat ${GTL_FILE_LIST_SEGMENT})
                do      gtl_tool_command

                        if      [[ ${?} == "0" ]]
                        then    info "Processing successfully completed     : ${GTL_INPUT_FILE}"
                        else    error "*** Processing failed                 : ${GTL_INPUT_FILE}"
                        fi
                done
                info
                info "All segments processed from file list : ${GTL_FILE_LIST_SEGMENT}"
                info
                if      find ${GTL_TEMP_LOG} -mindepth 1 | read
                then    info "Moving log files from scratch to persistent storage:"
                        mv ${GTL_TEMP_LOG}/* ${GTL_WORKING_DIR_LOG}
                        if      [[ ${?} == "0" ]]
                        then    info "Complete"
                                info "Cleaning up other remnants ..."
                                rmdir ${GTL_TEMP_LOG}
                                rm ${GTL_FILE_LIST_SEGMENT}
                        else    error "Unable to move log files"
                        fi
                else    info "Scratch directory is empty -- will clean up ..."
                        rmdir ${GTL_TEMP_LOG}
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
unset GTL_VERBOSE

while getopts "f::levh" OPTION
do  case ${OPTION} in
        l )     if      [[ -n ${GTL_MODE} ]]
                then    error "Multiple execution modes specified: ${*}" 
                        error "Please invoke the script again and specify either '-l' (for Launcher) or -e (for Executor)"
                        error "Exiting ..."
                        exit 1
                else    GTL_MODE="Launcher"
                fi     
                    ;;
        e )     if      [[ -n ${GTL_MODE} ]]
                then    error "Multiple execution modes specified: ${*}" 
                        error "Please invoke the script again and specify either '-l' (for Launcher) or -e (for Executor)"
                        error "Exiting ..."
                        exit 1
                else    GTL_MODE="Executor"
                fi     
                    ;;
        f )     if      [[ ! -f ${OPTARG} ]]
                then    error "File list can not be enumerated: ${OPTARG}"
                        error "Exiting ..."
                        exit 1
                else    GTL_FILE_LIST=${OPTARG}
                fi
                    ;;
        v )     export GTL_VERBOSE="TRUE"
                set -x
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

info "Operation         --> Run a generic tool against an input dataset"
info "Script mode       --> ${GTL_MODE}"

if      [[ ${GTL_MODE} == "Launcher" ]]
then    info "File list         --> ${GTL_FILE_LIST}"
        gtl_launcher_set_custom_variables
        gtl_launcher_set_programmatic_variables
        gtl_create_log_dirs
        gtl_split_file_list
        gtl_slurm_submit
elif    [[ ${GTL_MODE} == "Executor" ]]
then    gtl_execution
fi

if      [[ ${GTL_VERBOSE} == "TRUE" || ${GTL_MODE} == "Executor" ]]
then    info "Printing relevant environment..."
        echo -e "\n$(env | egrep 'SLURM|GTL' | sort)\n"
fi

info "${GTL_MODE} complete"
echo