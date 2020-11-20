#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# Name      : El Padre
#             --> El[ectrically charged] Parallel Assisted Data Redistribution Engine
# Purpose   : A structured and disciplined parallel data transfer engine
#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
## RUN-TIME VARIABLES:
EP_RSYNC_PORT="22"
EP_USER=${USER}
EP_SSH_KEY="-i /path/to/ssh/private_key"
EP_SCRATCH_AREA="/path/to/scratch/directory"

#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
## HELPER FUNCTIONS:
WARN_START_O='\033[0;33m'   ; WARN_END_O='\033[0m'                                                                                          # Colour change to orange
ERR_START_R='\033[0;31m'    ; ERR_END_R='\033[0m'                                                                                           # Colour change to red
help()       { echo -e "$(date "+%Y/%m/%d   %H:%M:%S")\t[HELP]     ${1}"                                                                                                        ; }
info()       { echo -e "$(date "+%Y/%m/%d   %H:%M:%S")\t[INFO]     ${1}"                                                                                                        ; }
warning()    { echo -e "${WARN_START_O}$(date "+%Y/%m/%d   %H:%M:%S")\t[WARNING]  ${1} ${WARN_END_O}"                                                                           ; }
error()      { echo -e "${ERR_START_R}$(date "+%Y/%m/%d   %H:%M:%S")\t[ERROR]    ${1} ${ERR_END_R}"                                                                             ; }
verbose()    { if [[ ${EP_VERBOSE^^} == "--VERBOSE" ]]; then    info "${1}"; fi                                                                                                 ; }
fail_check() { ((EP_FAIL_INDEX++)); warning "File transfer proactively terminated - this has been logged (#${EP_FAIL_INDEX})"                                                   ; }
cleanup()    { error "Exit condition detected - cleaning up spawned processes ..."; pkill rsync; pkill split; ssh ${EP_SSH_KEY} ${EP_USER}@${EP_REMOTE_HOST} 'pkill el_nino.sh' ; }

#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
## FUNCTIONS
ep_remote_side_reconstitution() {
    EP_EL_NINO_SCRATCH="/dev/shm/el_nino"

    info "Starting workers on the remote side to reconstitute parallel data transfers"
    verbose "Step 1: Copying El Nino to ${EP_REMOTE_HOST}"
        if      [[ ! -f ${EP_EL_NINO_PATH} ]]
        then    warning "El Nino cannot be found at the path specified: ${EP_EL_NINO_PATH}"
                warning "File reconstitution will be handled by the sending server"
                EP_RECONSTITUTE_NODE="SENDER"
        else    EP_RECONSTITUTE_NODE="EL_NINO"
        fi
        scp ${EP_SSH_KEY} ${EP_EL_NINO_PATH} ${EP_USER}@${EP_REMOTE_HOST}:/dev/shm/el_nino.sh > /dev/null
    verbose "Step 2: Starting the El Nino process on ${EP_REMOTE_HOST}"
        nohup ssh ${EP_SSH_KEY} ${EP_USER}@${EP_REMOTE_HOST} "chmod +x /dev/shm/el_nino.sh; /dev/shm/el_nino.sh --dest=${EP_DEST} --scratch=${EP_EL_NINO_SCRATCH}" > /dev/shm/el_nino_output.txt &
        if      (( ${?} == "0" ))
        then    verbose "Step 3: El Nino is now waiting for instructions from El Padre"
        else    warning "An issue occurred copying El Nino to the ${EP_REMOTE_HOST} and running it ..."
        fi

    until   [[ ${EP_ALL_TASKS_STATUS} == "SUBMITTED" ]]
    do      for     EP_TRANSFER_TASK in $(env | grep 'EP_TRACK_')
            do      EP_TRANSFER_TASK_VARBL=${EP_TRANSFER_TASK%%=*}
                    EP_TRANSFER_TASK_VALUE=${EP_TRANSFER_TASK##*=}
                    if      [[ ${EP_RECONSTITUTE_NODE} == "EL_NINO" ]]
                    then    if      (( $(ps -e -o psr,cmd | awk -v aCPU=0 '$1==aCPU' | awk '$2=="ssh"' | wc -l) <= "32" ))
                            then    numactl --physcpubind=0 ssh ${EP_SSH_KEY} ${EP_USER}@${EP_REMOTE_HOST} "echo ${EP_TRANSFER_TASK_VALUE} > ${EP_EL_NINO_SCRATCH}/${EP_TRANSFER_TASK_VARBL}"
                            fi
                    elif    [[ ${EP_RECONSTITUTE_NODE} == "SENDER" ]]
                    then    if      (( $(ps -e -o psr,cmd | awk -v aCPU=0 '$1==aCPU' | awk '$2=="ssh"' | wc -l) <= "16" ))
                            then    nohup numactl --physcpubind=0 ssh ${EP_SSH_KEY} ${EP_USER}@${EP_REMOTE_HOST} "cat ${EP_DEST}/${EP_TRANSFER_TASK_VALUE}_segment* > ${EP_DEST}/${EP_TRANSFER_TASK_VALUE}; rm -f ${EP_DEST}/${EP_TRANSFER_TASK_VALUE}_segment*" >/dev/null 2>&1 &
                            fi
                    fi
                    verbose "Instruction sent for ${EP_TRANSFER_TASK_VALUE}"
                    unset ${EP_TRANSFER_TASK_VARBL}
            done
    done

    if      [[ ${EP_RECONSTITUTE_NODE} == "EL_NINO" ]]
    then    verbose "El Padre has sent all instructions for file segment reconstitution"
            numactl --physcpubind=0 ssh ${EP_SSH_KEY} ${EP_USER}@${EP_REMOTE_HOST} "touch ${EP_EL_NINO_SCRATCH}/EL_PADRE_COMPLETE"
    fi

    info "Waiting for El Nino processes to complete"
    while   [[ $(ssh ${EP_SSH_KEY} ${EP_USER}@${EP_REMOTE_HOST} "find ${EP_EL_NINO_SCRATCH}" 2>/dev/null) ]]
    do      sleep 15
    done
}

ep_data_transfer_loops() {
    info "--> Starting data transfer loops"
    info
        export EP_ALL_TASKS_STATUS="STARTING"
        for     EP_ARRAY_SIZE in {EP_HIGH,EP_LOW}
        do      if      (( ${EP_DIVIDE_INPUTS_COUNTER} == "1" ))
                then    EP_MAX_RUNNING_TRANSFERS=${EP_MAX_RUNNING_TRANSFERS_HIGH_ARRAY}
                        EP_TIMEOUT=${EP_TIMEOUT_HIGH}
                        EP_FILE_TASKS=( ${EP_HIGH_ARRAY[*]} )
                        EP_FILE_INDEX="0"
                        info "( Transferring larger files ... )"
                        info
                elif    (( ${EP_DIVIDE_INPUTS_COUNTER} == "2" ))
                then    EP_MAX_RUNNING_TRANSFERS=${EP_MAX_RUNNING_TRANSFERS_LOW_ARRAY}
                        EP_TIMEOUT=${EP_TIMEOUT_LOW}
                        EP_FILE_TASKS=( ${EP_LOW_ARRAY[*]} )
                        EP_FILE_INDEX="0"
                        info "( Transferring smaller files ... )"
                        info
                fi

                ep_remote_side_reconstitution &
                sleep 5

                while   (( ${EP_FILE_INDEX} < ${#EP_FILE_TASKS[*]} ))
                do
                        export EP_ALL_TASKS_STATUS="ONGOING"
                        for     EP_CORE in $(seq 1 ${EP_HOST_CORES})
                        do      EP_THREAD_CHECK=$(ps -e -o psr,cmd | awk -v aCPU=${EP_CORE} '$1==aCPU' | awk '$2=="rsync"' | wc -l)
                                if      (( ${EP_THREAD_CHECK} < ${EP_MAX_RUNNING_TRANSFERS} ))
                                then    if      (( ${EP_FILE_INDEX} < ${#EP_FILE_TASKS[*]} ))
                                        then    EP_TASK_INPUT=${EP_FILE_TASKS[${EP_FILE_INDEX}]}
                                                if      [[ ${EP_MULTI_STREAM_TRANSFERS} == "ENABLED" ]]
                                                then    if      (( ${EP_DIVIDE_INPUTS_COUNTER} == "1" ))
                                                        then    EP_SPLIT_SEGMENT_NAME="$(basename ${EP_TASK_INPUT})_segment"
                                                                verbose "Splitting source file: ${EP_TASK_INPUT}"
                                                                numactl --physcpubind=${EP_CORE} split -b ${EP_SPLIT_SEGMENT_SIZE} --numeric=1 -d --suffix-length=3 ${EP_TASK_INPUT} ${EP_SCRATCH_AREA}/${EP_SPLIT_SEGMENT_NAME} &
                                                                EP_TASK_INPUT_SPLIT_PID=${!}
                                                                while   [[ $(ps -e | grep ${EP_TASK_INPUT_SPLIT_PID}) ]]
                                                                do      for     EP_SEGMENT in $(find ${EP_SCRATCH_AREA}/ -name "${EP_SPLIT_SEGMENT_NAME}" -type f | sort)
                                                                        do      if      [[ ! $(ps -e -o cmd | grep ${EP_SEGMENT}) ]]
                                                                                then    verbose "Submitting segment transfer: ${EP_FILE_SEGMENT}"
                                                                                        numactl --physcpubind=${EP_CORE} ${EP_TIMEOUT} \
                                                                                            numactl --physcpubind=${EP_CORE} \
                                                                                                rsync -axAXElHWL --remove-source-files -e "ssh ${EP_SSH_KEY} -T -c aes128-ctr -o Compression=no -x" ${EP_FILE_SEGMENT} ${EP_USER}@${EP_REMOTE_HOST}:${EP_DEST} &
                                                                                fi
                                                                        done
                                                                done
                                                        fi
                                                else    numactl --physcpubind=${EP_CORE} ${EP_TIMEOUT} \
                                                            numactl --physcpubind=${EP_CORE} \
                                                                rsync -axAXElHWL -e "ssh ${EP_SSH_KEY} -T -c aes128-ctr -o Compression=no -x" ${EP_TASK_INPUT} ${EP_USER}@${EP_REMOTE_HOST}:${EP_DEST} &
                                                fi

                                                export EP_TRACK_${EP_FILE_INDEX}=$(basename ${EP_TASK_INPUT})

                                                if 	    (( ${?} != "0" ))
                                                then 	warning "There was an issue submitting the file transfer - immediate non-zero process exit code detected"
                                                        ((EP_FAIL_INDEX++))
                                                else 	((EP_FILE_INDEX++))
                                                fi

                                                verbose "Progress                       : ${EP_FILE_INDEX} / ${#EP_FILE_TASKS[*]}"
                                                verbose "Submitted transfer task for    : ${EP_TASK_INPUT}"
                                                verbose "Process running on core        : ${EP_CORE}"
                                                verbose

                                                sleep 0.05s
                                        else    break
                                        fi
                                else    continue
                                fi
                        done
                done
                EP_HOLISTIC_FILE_INDEX=$(( ${EP_HOLISTIC_FILE_INDEX} + ${EP_FILE_INDEX} ))
                ((EP_DIVIDE_INPUTS_COUNTER++))
        done
    info
    export EP_ALL_TASKS_STATUS="SUBMITTED"
    info "All tasks have been submitted - time to wait for bit redistribution to complete ..."
    info "Number of processes remaining to complete: $(ps -e -o cmd | grep rsync | wc -l)"
    #verbose "Pending rsync tasks:"
    #while   [[ $(ps -e -o psr,cmd | grep "rsync" | grep -v "--server") ]]
    #do      verbose "$(ps -e -o psr,cmd | grep "rsync" | grep -v "--server" | wc -l) remaining tasks"
    #done
    info
    wait
    info "All activated processes have terminated"
}

#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
## GETOPT:
EP_GETOPT_SHORT="s:d:h:x:v"
EP_GETOPT_LONG="source:,dest:,remote-host:,scratch:,verbose"
OPTS=$(getopt --options ${EP_GETOPT_SHORT} --long ${EP_GETOPT_LONG} --name "getopt-parse-options" -- "${@}")
    if      (( ${?} != "0" ))
    then    error "Failed to correctly parse the options provided - exiting ..." 
            exit 1
    fi
eval set -- "${OPTS}"
while true 
do 
    case "${1}" in
        -s | --source )         EP_SOURCE=${2}                  ;   shift 2 ;;
        -d | --dest )           EP_DEST=${2}                    ;   shift 2 ;;
        -h | --remote-host )    EP_REMOTE_HOST=${2}             ;   shift 2 ;;
        -x | --scratch )        EP_SCRATCH_AREA=${2}            ;   shift 2 ;;
        -v | --verbose )        EP_VERBOSE="--VERBOSE"; set +x  ;   shift   ;;

        -- )    break                   ;   shift   ;;
        *)      error "Invalid options" ;   exit 1  ;;
  esac
done

#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
## OPERATIONAL LOOPS:
#trap cleanup ERR SIGINT SIGTERM
trap cleanup SIGINT
trap fail_check SIGTERM
echo
info "#--------------------------#"
info "#         EL PADRE         #"
info "#      Data transfers      #"
info "#--------------------------#"
info
verbose "Binding the parent to core 0 ..."
    readarray -t EP_PARENT_BIND < <(taskset -cp 0 ${BASHPID})
    (( ${?} == "0" ))  &&  EP_BIND_EXIT="info "Complete""  ||  EP_BIND_EXIT="warning "Failed to reassign PID""
verbose "${EP_PARENT_BIND[0]}"
verbose "${EP_PARENT_BIND[1]}"
    eval ${EP_BIND_EXIT}
info
info "Provided options: ${OPTS}"
info
    EP_EL_NINO_PATH="$(pwd)/el_nino.sh"
    EP_MULTI_STREAM_TRANSFERS="ENABLED"
    EP_SPLIT_SEGMENT_SIZE="2G"
    EP_ALL_FILE_TASKS=( $(find -L ${EP_SOURCE} -type f 2>/dev/null) )
    EP_TIMEOUT_HIGH="timeout 900"
    EP_TIMEOUT_LOW="timeout 90"
    EP_HOST_CORES=$(( $(nproc --all) -1 ))
    EP_NUMA_DOMAINS=$(numactl -H | grep 'available' | cut -f '2,3,4' -d ' ')
    EP_HOLISTIC_FILE_INDEX="0"
    EP_FAIL_INDEX="0"
    EP_DIVIDE_INPUTS_MIN_SIZE="128"      # Specify the size difference for low & high files in MB
    EP_MAX_RUNNING_TRANSFERS_LOW_ARRAY="4"
    EP_MAX_RUNNING_TRANSFERS_HIGH_ARRAY="1"
    EP_DIVIDE_INPUTS_COUNTER="1"
    EP_LOW_ARRAY=()
    EP_HIGH_ARRAY=()
info "--> Validation"
    if      [[ ! -d ${EP_SOURCE} ]]
    then    error "Invalid source directory path: ${EP_SOURCE}" 
            error "Please double check and retry - exiting ..."
            exit 1
    else    verbose "Source directory           : ${EP_SOURCE}"
    fi
    if      [[ ! -d ${EP_SOURCE} ]]
    then    error "Invalid destination directory path: ${EP_SOURCE}" 
            error "Please double check and retry - exiting ..."
            exit 1
    else    verbose "Destination directory      : ${EP_DEST}"
    fi
    if      [[ ! $(timeout 3 nc ${EP_REMOTE_HOST} ${EP_RSYNC_PORT}) ]]
    then    error "This host has an issue connecting to ${EP_REMOTE_HOST} over port ${EP_RSYNC_PORT}"
            error "Please check connectivity and retry"
            exit 1
    else    verbose "Remote host                : ${EP_REMOTE_HOST}"
    fi

    verbose "Rsync port                 : ${EP_RSYNC_PORT}"
    verbose "User                       : ${EP_USER}"
    verbose "Large file thread count    : ${EP_MAX_RUNNING_TRANSFERS_HIGH_ARRAY}"
    verbose "Small file thread count    : ${EP_MAX_RUNNING_TRANSFERS_LOW_ARRAY}"
    verbose "Scratch area               : ${EP_SCRATCH_AREA}"
info "Complete"
info
info "Arranging file inputs & parameters ..."
    if      (( ${#EP_ALL_FILE_TASKS[*]} == "0" ))
    then    error "Zero files detected in the source directory: ${EP_SOURCE}"
            error "Nothing to do..."
            exit 0
    else    info "Number of files to transfer       : ${#EP_ALL_FILE_TASKS[*]}"
            for     EP_FILE in ${EP_ALL_FILE_TASKS[*]}
            do      if      (( $(stat -L -c %s ${EP_FILE}) < $(( ((${EP_DIVIDE_INPUTS_MIN_SIZE} * 1024) * 1024) )) ))
                    then    EP_LOW_ARRAY+=(${EP_FILE})
                    else    EP_HIGH_ARRAY+=(${EP_FILE})
                    fi
            done
            verbose "# of files below 10MB to transfer : ${#EP_LOW_ARRAY[*]}"
            verbose "# of files above 10MB to transfer : ${#EP_HIGH_ARRAY[*]}"

            if      (( ${#EP_HIGH_ARRAY[*]} > "0" ))
            then    if      [[ -z ${EP_SCRATCH_AREA} ]]
                    then    error "Multi-stream file transfers are enabled, but no value has been provided for the scratch area"
                            error "Please assign a path value to the \${EP_SCRATCH_AREA} variable, or provide it as an argument value to either '-x' or '--scratch' on the CLI"
                            error "Exiting ..."
                            exit 1
                    elif    [[ ! -d ${EP_SCRATCH_AREA} ]]
                    then    error "The path provided for the scratch area cannot be enumerated: ${EP_SCRATCH_AREA}"
                            error "Please verify the path and retry"
                            error "Exiting ..."
                            exit 1
                    fi
            fi
    fi
info

ep_data_transfer_loops

#ep_retry_data_transfer_loops

if      (( ${EP_FAIL_INDEX} > "0" ))
then    warning "${EP_FAIL_INDEX} files were not successfully transferred"
        warning "Please re-run El Padre to retry/complete failed file transfers"
        EP_FAIL_INDEX="0"
        ep_data_transfer_loops
fi

wait

info "El Padre has terminated after sending ${EP_HOLISTIC_FILE_INDEX} files"
#info "Number of failed transfers: ${EP_FAIL_INDEX}"
echo

#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#