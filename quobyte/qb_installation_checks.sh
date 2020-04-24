#!/bin/bash

# A quick set of pre-flight checks for the Quobyte installation:

echo

info() { 
	echo -e "`date "+%Y/%m/%d   %H:%M:%S"`\t[INFO]   $1" 
}
error() { 
	echo -e "`date "+%Y/%m/%d   %H:%M:%S"`\t[ERROR]  $1"
}
trap() {
    error "Error occured - possibly not being run as root/under sudo?"
    rm -rf ${QB_PIPE}
}

while getopts "eh" opt
do
    case ${opt} in
        e )     export QB_WIPE_DRIVES="QB_SET_VAR_WIPE_DRIVES"
                    ;;
        h )     info "Usage: $0 [-e] [-h]"
                info "  -e: Executes wipefs on attached drives from /dev/sdb onwards. Otherwise, the script will run in dry (or test) mode"
                info "  -h: Show this help message"
                exit 0
                    ;;
        /? )    info "Invalid arguments passed to the script: ${opt}"
		exit 1
                    ;;
    esac
done

qb_check_packages() {
    export QB_NODE_DIST=$(cat /etc/os-release | grep PRETTY_NAME | cut -f 2 -d '=' | sed 's/"//g' | awk '{print $1}')
    info "OS Distribution  : ${QB_NODE_DIST}"
    info "Hostname         : ${HOSTNAME}"

    declare -a QB_GENERAL_SCRIPT_COMMANDS=( cat grep awk nc ping lsblk echo wipefs systemctl swapon )
        declare -a QB_CENTOS_SCRIPT_COMMANDS=( yum firewall-cmd )
        declare -a QB_UBUNTU_SCRIPT_COMMANDS=( apt-get ufw )
        declare -a QB_XYZ_SCRIPT_COMMANDS=( ... )

    if [[ ${QB_NODE_DIST} == "CentOS" ]]
    then
            QB_GENERAL_SCRIPT_COMMANDS=( ${QB_GENERAL_SCRIPT_COMMANDS[@]} ${QB_CENTOS_SCRIPT_COMMANDS[@]} )

    elif [[ ${QB_NODE_DIST} = "Ubuntu" ]]
    then
            QB_GENERAL_SCRIPT_COMMANDS=( ${QB_GENERAL_SCRIPT_COMMANDS[@]} ${QB_UBUNTU_SCRIPT_COMMANDS[@]} )
    fi

    for QB_CHECK_COMMAND in ${QB_GENERAL_SCRIPT_COMMANDS[*]}
    do
        which ${QB_CHECK_COMMAND} 2> /dev/null  1> /dev/null
        if [[ $? != "0" ]]
        then
            error "Package not present: ${QB_CHECK_COMMAND}"
            export QB_PACKAGE_NOT_PRESENT="TRUE"
        fi
    done

    if [[ -n ${QB_PACKAGE_NOT_PRESENT} ]]
    then
        error
        error "Please ensure the above packages are available on the system and accessible via \${PATH}"
        exit 1
    fi
}

qb_check_specs() {
    info "Checking node specifications..."
    ## Minimums:
    QB_MIN_CPU_CORES="4"                # Integer; Will read from /proc/cpuinfo
    QB_MIN_MEMORY="31"                  # Integer; Size in GB; Will read from /proc/meminfo and calculate using base-2
    QB_MIN_DRIVES="2"                   # Integer; Will parse full drives from /dev/sdb onwards using lsblk
    QB_MIN_DRIVE_SIZE="50"              # Integer; Size in GB; Will parse drive size from lsblk and calculate using base-2
    #-----------

    QB_FAILURE_ARRAY=()

    # CPU cores:
    if [[ $(cat /proc/cpuinfo | grep processor | wc -l) -lt ${QB_MIN_CPU_CORES} ]]
    then    
        QB_FAILURE_ARRAY+=('--  CPU_CORES  --')
    fi

    # Memory:
    QB_SYSTEM_MEMORY=$(cat /proc/meminfo | grep 'MemTotal' | awk '{print $2}')
    
    if [[ ${QB_SYSTEM_MEMORY} -lt $((  ((${QB_MIN_MEMORY} * 1024) * 1024)  )) ]]         # Raising the QB_MIN_MEMORY variable from GiB > MiB > KiB
    then
        QB_FAILURE_ARRAY+=('--  MEMORY  --')
    fi

    # Number of drives:
    QB_DRIVE_NUMBER=$(lsblk --bytes --output NAME,SIZE --paths | grep '^/dev/sd[b-z]' | wc -l)

    if [[ ${QB_DRIVE_NUMBER} -lt ${QB_MIN_DRIVES} ]]
    then
        QB_FAILURE_ARRAY+=('--  NUMBER_OF_DRIVES  --')
    fi

    # Drive size:
    QB_DRIVE_COUNT="0"

    for QB_DRIVE in $(lsblk --bytes --output NAME,SIZE --paths | grep '^/dev/sd[b-z]' | awk '{print $NF}')
    do 
        if [[ ${QB_DRIVE} -ge $((  (((${QB_MIN_DRIVE_SIZE} * 1024) * 1024) * 1024)  )) ]]
        then
            ((QB_DRIVE_COUNT++))
        fi
    done

    # Comparing the number of suitably sized drives to the total number of drives:
    if [[ ${QB_DRIVE_COUNT} != ${QB_DRIVE_NUMBER} ]]
    then    
        QB_FAILURE_ARRAY+=('--  SIZE_OF_DRIVES  --')
    fi

    # Listing whether any checks have failed:
    if [[ -n ${QB_FAILURE_ARRAY} ]]
    then    
        error "Quobyte pre-flight checks failed:\t$(echo ${QB_FAILURE_ARRAY[*]})"
        error "Please resolve these issues and re-run the validation script."
    else
        info "Minimum requirements are met"
    fi
}

qb_node_config() {
    if [[ ${QB_NODE_DIST} = "CentOS" ]]
    then
        yum update --downloadonly --quiet 2> /dev/null
        if [[ $? != "0" ]]
        then
            error "Package manager  : Non-zero exit code when running: yum update --downloadonly --quiet"
        fi

        info "Firewall status  : $(systemctl is-active firewalld)"

    elif [[ ${QB_NODE_DIST} = "Ubuntu" ]]
    then
        apt-get update -qq 2> /dev/null
        if [[ $? != "0" ]]
        then
            error "Package manager  : Non-zero exit code when running: apt-get update -qq"
        fi

        info "Firewall status  : $(systemctl is-active ufw)"
    fi

    info "iptables status  : $(systemctl is-active iptables)        (Consider whether iptables needs to be flushed)"
    if [[ $(systemctl is-active iptables) == "active" ]]
    then
        info "Printing iptables rules:"
        echo
        iptables --list
        echo
    fi

    # Is swap on/off:
    if [[ $(swapon --show) ]]
    then 
        error "Node swap        : swap needs to be disabled on all machines running Quobyte services" 
    fi

    ping -c 2 ${HOSTNAME} > /dev/null
    if [[ $? != "0" ]]
    then
        error "Name resolution  : Non-zero exit code when pinging the machine itself by name"
    fi

    nc -zw3 packages.quobyte.com 443 2> /dev/null
    if [[ $? != "0" ]]
    then
        error "Quobyte repo     : Non-zero exit code when scanning packages.quobyte.com - can this machine reach this internet endpoint?"
    fi 

    QB_AUTH_KEY_PATH="${HOME}/.ssh/authorized_keys"
    if [[ ! -f ${QB_AUTH_KEY_PATH} ]]
    then
        error "SSH key pair     : There is no authorized_keys file on the target server at ${QB_AUTH_KEY_PATH} - has an SSH key pair been shared?"
    else
        info "SSH key pair     : An authorized_hosts file exists at ${QB_AUTH_KEY_PATH} (which suggests a key pair has been shared with this node)"
    fi
}

qb_wipe_drives() {
    if [[ ${QB_WIPE_DRIVES} == "QB_SET_VAR_WIPE_DRIVES" ]]
    then
        info "Wiping drives:"
        # Looping through drives and calling wipefs to prepare:
        if [[ ${QB_DRIVE_COUNT} == "0" ]]
        then
            info "No drives to wipe"
        else
            for QB_WIPE_DRIVE in $(lsblk --output NAME --paths | grep '^/dev/sd[b-z]')
            do
                QB_DRIVE_STATE=$((wipefs -a ${QB_WIPE_DRIVE}) 2>&1)

                if [[ $? == "0" ]]
                then
                    info "  ${QB_DRIVE_STATE}"
                    info "  ${QB_WIPE_DRIVE}: Successful"
                else
                    error "  ${QB_DRIVE_STATE}"
                    error "  ${QB_WIPE_DRIVE}: Failed"
                fi
            done
        fi
    else
        info "Disks present on this server (no action being taken apart from listing):"
        for QB_DRIVE_LIST in $(lsblk --output NAME --paths | grep '^/dev/sd[b-z]')
        do
            info "  ${QB_DRIVE_LIST}"
        done
    fi  
}

info "Performing a set of pre-flight checks prior to Quobyte installation"
info
    qb_check_packages
info
info ">>> Starting"
    if (( ${EUID} != "0" ))
    then
        info "This preflight check script is not running under a root/sudo context, which could introduce issues during installation/configuration"
    fi
info
    qb_check_specs
info
    qb_node_config
info
    qb_wipe_drives
info    
info
info ">>> Preflight checks complete"
echo
