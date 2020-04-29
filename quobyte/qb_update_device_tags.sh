#!/bin/bash

function qb_set_variables() {
    QB_LOGIN_USERNAME=""            # Username to login to Quobyte management
    QB_LOGIN_PASSWORD=""            # Password to login to Quobyte management
    
    QB_DEVICE_TYPE="ALL"            # <<< INCOMPLETE: Add a section to distinguish between specific device types
    QB_INDEX="0"
}

function qb_help_statement() {
    if [[ ${#} == "0" || ${1} == +('-h'|'--help'|'?') ]]
    then
        echo "    
        This script will do the following:
            1. Use the first argument to read in all hosts, for which their devices will have new tags added
            2. The second argument determines whether tags should be added or removed
            3. Use the remaining arguments to specify the tags that are to be added to the devices
            4. Then the script loops through all existing devices and add the tags, as specified
        
        Usage:
            ${0}  <HOST_LIST>  <ADD_OR_REMOVE>  <TAG_1>  <TAG_2>  ...  <TAG_N>
            ${0}  /path/to/host/list.txt  ADD  ROOM_AB  SECTION_14G
        
        The above example adds the 'ROOM_AB' and 'SECTION_14G' tags to all devices attached to the nodes listed in /path/to/host/list.txt.
        "

        exit 0
    fi
}

function qb_login() {
    if      [[ -n ${QB_LOGIN_USERNAME} && ${QB_LOGIN_PASSWORD} ]]
    then
        qmgmt user login ${QB_LOGIN_USERNAME} ${QB_LOGIN_PASSWORD}

        if [[ $? == "0" ]]
        then
            QB_LOGIN_USERNAME_SESSION="ACTIVE"
        fi
    fi
}

function qb_logout() {
    if [[ ${QB_LOGIN_USERNAME_SESSION} == "ACTIVE" ]]
    then
        qmgmt user logout
    fi
}

function qb_validation() {
    if [[ ! -f ${1} ]]
    then
        echo "Cannot enumerate a file at: ${1}"
        exit 1
    else
        QB_NODE_LIST=${1}
    fi
    
    if      [[ ${2} == +('ADD'|'Add'|'add') ]]
    then    QB_DEVICE_OPERATION="add-tags"

    elif    [[ ${2} == +('REMOVE'|'Remove'|'remove') ]]
    then    QB_DEVICE_OPERATION="remove-tags"

    else    echo "Invalid add/remove operation type - exiting..."
            exit 1
    fi

    QB_TAGS=( ${@:3} )
}

function qb_main() {
    echo
    echo "Date              : $(date)"
    echo "Operation         : ${QB_DEVICE_OPERATION}"
    echo "Tags              : $(echo ${QB_TAGS[*]})"
    for QB_LIST_NODES in $(cat ${QB_NODE_LIST})
    do
        echo "Nodes involved    : ${QB_LIST_NODES}"
        for QB_LIST_DEVICES in $(qmgmt device list | grep ${QB_LIST_NODES} | awk '{print $1}')
        do
            echo "       Device ID  : ${QB_LIST_DEVICES}"
        done
    done
    echo

    for QB_UPDATE_NODE in $(cat ${QB_NODE_LIST})
    do
        for QB_UPDATE_NODE_DEVICE in $(qmgmt device list | grep ${QB_UPDATE_NODE} | awk '{print $1}')
        do
            qmgmt device update ${QB_DEVICE_OPERATION} ${QB_UPDATE_NODE_DEVICE} ${QB_TAGS[*]}
        done
    done

    echo "All tags added"
}

#===========================================================================================================================================#

# Calling the functions:

if [[ ${#} < "3" || ${1} == +('-h'|'--help'|'?') ]]
then
    qb_help_statement
fi

qb_set_variables
qb_validation ${@}
qb_login
qb_main
qb_logout