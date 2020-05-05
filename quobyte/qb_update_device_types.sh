#!/bin/bash

function qb_set_variables() {
    QB_LOGIN_USERNAME=""            # Username to login to Quobyte management
    QB_LOGIN_PASSWORD=""            # Password to login to Quobyte management

    QB_ADD_OR_REMOVE=${1}
    QB_MODIFIED_DEVICE_TYPE=${2}
    QB_EXISTING_DEVICE_TYPE=${3}
    QB_EXPLICIT_DEVICE_LIST=( ${@:4} )

    QB_INDEX="0"

    QB_UPDATE_DEVICE_HOST_LIST="0"  # <<< INCOMPLETE: Add capability to restrict device update to sepcific hosts

    QB_UPDATE_SUCCESS="0"
    QB_UPDATE_FAILED="0"
}

function qb_help_statement() {
    if [[ ${#} == "0" || ${1} == +('-h'|'--help'|'?') ]]
    then
        echo "    
        This script will do the following:
            1. Use the first argument to determine whether to add or remove a device type (either ADD or REMOVE)
            2. Use the second argument to specify a new device type, e.g. DATA or METADATA
            3. Loop through all existing devices with the type as specified in the third agument
            4. ...Adding the desired additional device type
        
        Usage:
            Syntax)     ${0}  <ADD_OR_REMOVE>  <NEW_DEVICE_TYPE>  <EXISTING_DEVICE_TYPE>  (<DEVICE_ID>  <DEVICE_ID>  ...  <DEVICE_ID>)
            A)          ${0}  ADD  DATA  METADATA
            B)          ${0}  ADD  METADATA  DATA  1  4  9  18  39
            C)          ${0}  REMOVE  METADATA  DATA  10  11  42
        
        The above examples: 
            A) Adds the DATA device type to all devices that currently have the METADATA type
            B) Adds the METADATA device type to device IDs 1, 4, 9, 18 and 39 which have the DATA type
            C) Removes the METADATA device type from device IDs 10, 11 and 42
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
    # Validating add/remove:
    if      [[ ${QB_ADD_OR_REMOVE} == +('ADD'|'Add'|'add') ]]
    then    QB_DEVICE_OPERATION="add-type"

    elif    [[ ${QB_ADD_OR_REMOVE} == +('REMOVE'|'Remove'|'remove') ]]
    then    QB_DEVICE_OPERATION="remove-type"

    else    echo "Invalid operation type"
            qb_help_statement
            exit 1
    fi

    # Validate new device type:
    if      [[ ${QB_MODIFIED_DEVICE_TYPE}  !=  +('METADATA'|'Metadata'|'metadata'|'DATA'|'Data'|'data'|'REGISTRY'|'Registry'|'registry')  ]]
    then    echo "Please specify a valid new device type"
            qb_help_statement
            exit 1
    fi

    # Validate existing device type, and identifying devices to work with:
    if      [[ ${QB_EXISTING_DEVICE_TYPE} == +('REGISTRY'|'Registry'|'registry') ]]
    then    QB_ALL_DEVICES_TO_UPDATE=( $(qmgmt device list | grep ' REGISTRY ' | awk '{print $1}') )

    elif    [[ ${QB_EXISTING_DEVICE_TYPE} == +('METADATA'|'Metadata'|'metadata') ]]
    then    QB_ALL_DEVICES_TO_UPDATE=( $(qmgmt device list | grep ' METADATA ' | awk '{print $1}') )

    elif    [[ ${QB_EXISTING_DEVICE_TYPE} == +('DATA'|'Data'|'data') ]]
    then    QB_ALL_DEVICES_TO_UPDATE=( $(qmgmt device list | grep ' DATA ' | awk '{print $1}') )

    elif      [[ -n ${@:4} ]]
    then    QB_ALL_DEVICES_TO_UPDATE=( ${@:4} )
    
    else    echo "Please specify a valid existing device type"
            qb_help_statement
            exit 1

    fi
}

function qb_main() {
    echo
    echo "Date              : $(date)"
    echo "Operation         : ${QB_ADD_OR_REMOVE} device type"
    echo "Modified type     : ${QB_MODIFIED_DEVICE_TYPE}"
    echo "Existing type     : ${QB_EXISTING_DEVICE_TYPE}"
    for QB_LIST_DEVICES in ${QB_ALL_DEVICES_TO_UPDATE[*]}
    do
        if [[ ${QB_INDEX} == "0" ]]
        then
            echo "Devices involved  : ${QB_LIST_DEVICES}"
        else
            echo "                  : ${QB_LIST_DEVICES}"
        fi
        ((QB_INDEX++))
    done
    echo
    
    for QB_UPDATE_DEVICE_TYPE in ${QB_ALL_DEVICES_TO_UPDATE[*]}
    do
        qmgmt device update  ${QB_DEVICE_OPERATION}  ${QB_UPDATE_DEVICE_TYPE}  ${QB_MODIFIED_DEVICE_TYPE}
        if [[ ${?} == "0" ]]
        then
            ((QB_UPDATE_SUCCESS++))
        else
            ((QB_UPDATE_FAILED++))
        fi
    done

    echo
    echo "Number of successful device updates   : ${QB_UPDATE_SUCCESS}"
    echo "Number of failed device updates       : ${QB_UPDATE_FAILED}"
    echo "Device type update complete"
    echo
}

#===========================================================================================================================================#

# Calling the functions:
if [[ ${#} -lt "3" || ${1} == +('-h'|'--help'|'?') ]]
then
    qb_help_statement
fi

qb_set_variables ${@}
qb_login
qb_validation
qb_main
qb_logout