#!/bin/bash
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# README:
# CVC = Cluster Validation Checks
# Invoke the script with either 'LAUNCH' or 'EXECUTE'
#
# Caution: Line buffering may result in timestamps being identical
# Caution: dd sends some output to stderr for xfer statistics - this can be seen as erroneous and can be ignored (or silenced with the 'noxfer' flag)
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# FUNCTIONS

# Enabling functions:
stdout() { /bin/echo "${@}" ; }
stderr() { /bin/echo "${@}" 1>&2 ; }
exitcheck() {
    if      [[ ${?} == "0" ]]
    then    stdout "CHECK: PASS   --->  ${1}"; ((CVC_PASS_COUNTER++))
    else    stderr "CHECK: FAIL     ${1}"; ((CVC_FAIL_COUNTER++))
            if [[ ${@} =~ "CRITICAL" ]]
            then exit 1
            fi
    fi
}

# Execution functions:
cvc_set_local_variables() {
    export CVC_USER="<_USER_>"                                                  # The username that will be used to connect to the remote host (to be used in conjunction with the ssh key pair, as below)
    export CVC_LOGIN_TARGET="<_LOGIN_TARGET_>"                                  # Name (Fully Qualified or otherwise) of the remote host to connect to, and use to perform the tests, e.g. 'login-server.mycompany.com' or 'loginserver'
    export CVC_SSH_KEY_PATH="/path/to/ssh/key_pair"                             # Specifying the path to an ssh key pair on the local host to simplify and make remote connectivity silent

    export CVC_LOCAL_SLEEP="1"
}

cvc_set_remote_variables() {
    export CVC_SCHEDULER_NAME="<_SCHEDULER_NAME_>"                              # For example: 'Slurm', 'PBS_Pro', 'HTCondor' etc.
    export CVC_SCHEDULER_BIN_PATH="/path/to/scheduler/bin/directory"            # To allow scheduler binaries to be called directly, without needing to rely on paths being set
    export CVC_SCHEDULER_QUEUE_STATUS="<_QUERY_QUEUE_STATUS_CMD_>"              # For example: 'sinfo' (for Slurm) or 'qstat -q' (for PBS)
    export CVC_SCHEDULER_SUBMIT_JOB="<_SAMPLE_CLUSTER_JOB_CMD_>"                # For example: 'srun hostname' (for Slurm) or 'qsub -I hostname' (for PBS)

    export CVC_TEMP_DIR_PATH="/path/to/where/dir/and/file/can_be_written"       # Recommended to specify a path on a shared filesystem, e.g. parallel file system, scratch space, archive store or other (specifying a local path on the remote host limits the effectiveness of the tests)

    #---------------------------------------------------------------------------# It should not be necessary to modify the below variables
    export CVC_REMOTE_SCRIPT_PATH="/home/${CVC_USER}/$(basename ${0})"          # The path to which the script will be copied to, and executed from. Should be reachable by compute nodes, too.
    export CVC_TEMP_FILE_NAME="cvc_temp_file.dat"
    export CVC_REMOTE_SLEEP="1"
    export CVC_PASS_COUNTER="0"                                             
    export CVC_FAIL_COUNTER="0"
    #export PATH=${PATH}:${CVC_SCHEDULER_BIN_PATH}
}

cvc_copy_script() {
    /usr/bin/scp -qi ${CVC_SSH_KEY_PATH} ${0} ${CVC_USER}@${CVC_LOGIN_TARGET}:${CVC_REMOTE_SCRIPT_PATH}
}

cvc_ssh_remote_host() {
    /usr/bin/ssh -i ${CVC_SSH_KEY_PATH} ${CVC_USER}@${CVC_LOGIN_TARGET} "${1}"
}

cvc_scheduler_check() {
    stdout "Checking ${CVC_SCHEDULER_NAME} queue status: ${CVC_SCHEDULER_QUEUE_STATUS}"
    stdout
        ${CVC_SCHEDULER_BIN_PATH}/${CVC_SCHEDULER_QUEUE_STATUS}
        exitcheck "$(/bin/echo ${CVC_SCHEDULER_QUEUE_STATUS})"
    stdout
    stdout "Submitting a test job: ${CVC_SCHEDULER_SUBMIT_JOB}"
        ${CVC_SCHEDULER_BIN_PATH}/${CVC_SCHEDULER_SUBMIT_JOB}
        exitcheck "$(/bin/echo ${CVC_SCHEDULER_SUBMIT_JOB})"
    stdout
}

cvc_create_dir_file() {
    stdout "Creating temporary directory: ${CVC_TEMP_DIR_PATH}"
        /bin/mkdir -p ${CVC_TEMP_DIR_PATH}
        exitcheck "Create temporary directory"
    stdout
    stdout "Creating temporary file: ${CVC_TEMP_DIR_PATH}/${CVC_TEMP_FILE_NAME}"
        /bin/dd if=/dev/urandom of=${CVC_TEMP_DIR_PATH}/${CVC_TEMP_FILE_NAME} bs=1M count=1024  
        exitcheck "Create temporary file"
    stdout
    stdout "Reading temporary file: ${CVC_TEMP_DIR_PATH}/${CVC_TEMP_FILE_NAME}"
        /bin/dd if=${CVC_TEMP_DIR_PATH}/${CVC_TEMP_FILE_NAME} of=/dev/null bs=1M
        exitcheck "Reading the temporary file"
    stdout
}

cvc_delete_file_dir() {
    stdout "Deleting temporary file: ${CVC_TEMP_DIR_PATH}/${CVC_TEMP_FILE_NAME}"
        /bin/rm ${CVC_TEMP_DIR_PATH}/${CVC_TEMP_FILE_NAME}
        exitcheck "Delete temporary file"
    stdout
    stdout "Deleting temporary directory: ${CVC_TEMP_DIR_PATH}"
        /bin/rmdir ${CVC_TEMP_DIR_PATH}
        exitcheck "Delete temporary directory"
    stdout
}

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# RUNTIME:
if      [[ ${#} != "1" ]]
then    stderr
        stderr "Insufficient options (${#}) provided to the script - invoke with either:"
        stderr "    1)      ${0} LAUNCH     <-- Local host"
        stderr "    2)      ${0} EXECUTE    <-- Target host"
        stderr
        exit 1
elif    [[ ${1} == "LAUNCH" ]]
then    exec > >(CVC_TIME=$(date "+%Y/%m/%d   %H:%M:%S"); sed "s|^|${CVC_TIME}  [INFO]    |")
        exec 2> >(CVC_TIME=$(date "+%Y/%m/%d   %H:%M:%S"); sed "s|^|${CVC_TIME}  [ERROR]   |" >&2)
        stdout
        stdout "$(date)"
        
        cvc_set_local_variables
        exitcheck "Set variables on local host    [CRITICAL]"
            sleep ${CVC_LOCAL_SLEEP}

        cvc_copy_script
        exitcheck "Copy CVC script to the remote host    [CRITICAL]"
            sleep ${CVC_LOCAL_SLEEP}

        cvc_ssh_remote_host "${CVC_REMOTE_SCRIPT_PATH} EXECUTE"
        exitcheck "Trigger CVC script execution    [CRITICAL]"
            sleep ${CVC_LOCAL_SLEEP}

        cvc_ssh_remote_host "/bin/rm ${CVC_REMOTE_SCRIPT_PATH}"
        exitcheck "Remove CVC script from the remote host"
            sleep ${CVC_LOCAL_SLEEP}

elif    [[ ${1} == "EXECUTE" ]]
then    stdout
        stdout "______________________________________________________________"
        stdout "|    _   _ ____   ____      ____ _           _               |"
        stdout "|   | | | |  _ \ / ___|    / ___| |_   _ ___| |_ ___ _ __    |"
        stdout "|   | |_| | |_) | |       | |   | | | | / __| __/ _ \ '__|   |"
        stdout "|   |  _  |  __/| |___    | |___| | |_| \__ \ ||  __/ |      |"
        stdout "|   |_| |_|_|    \____|    \____|_|\__,_|___/\__\___|_|      |"
        stdout "|____________________________________________________________|"
        stdout
        stdout "---> Starting validation checks"
        stdout
        
        cvc_set_local_variables
        cvc_set_remote_variables
        exitcheck "Set variables on the remote host"
            sleep ${CVC_REMOTE_SLEEP}
        
        stdout
        stdout "User                 : ${CVC_USER}"
        stdout "Login target         : ${CVC_LOGIN_TARGET}"
        stdout "SSH key pair         : ${CVC_SSH_KEY_PATH}"
        stdout "Remote script path   : ${CVC_REMOTE_SCRIPT_PATH}"
        stdout "Scheduler            : ${CVC_SCHEDULER_NAME}"
        stdout
        
        cvc_scheduler_check
            sleep ${CVC_REMOTE_SLEEP}
        
        cvc_create_dir_file
            sleep ${CVC_REMOTE_SLEEP}
            
        cvc_delete_file_dir
            sleep ${CVC_REMOTE_SLEEP}

        stdout
        stdout "Successful checks   : ${CVC_PASS_COUNTER}"
        stdout "Failed checks       : ${CVC_FAIL_COUNTER}"
        stdout
        stdout "---> Validation checks completed"
else    stderr
        stderr "Incorrect options provided to the script - invoke with either:"
        stderr "    1)      ${0} LAUNCH     <-- Local host"
        stderr "    2)      ${0} EXECUTE    <-- Target host"
        stderr
        exit 1
fi