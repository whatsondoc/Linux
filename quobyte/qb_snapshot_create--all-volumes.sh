#!/bin/bash

# Creating Quobyte snapshots for all volumes on a system, except for those named 'scratch' (case insensitive)
# This script could be used as part of a crontab entry, to allow snapshots outside of the hourly or daily schedule options

function qb_set_variables() {
    QB_LOGIN_USERNAME=""            # Username to login to Quobyte management
    QB_LOGIN_PASSWORD=""            # Password to login to Quobyte management
}

function qb_help_statement() {
        echo "    
        This script will do the following:
            1. Capture all tenants in an array, eliminating anything named 'scratch'
            2. Cycle through all tenant IDs and capture volumes
            3. Loop through the list and trigger a snapshot creation for each volume (mirrored volumes are skipped)
        
        Usage:
            ${0}  --create
        
        The above command triggers a snapshot creation for all volumes that do not have 'scratch' in the name. 
                
        Calling the script without the '--create' will print this help menu and exit.
        "

        exit 0
}

function qb_validation() {
    if [[ ${1} != "--create" ]]
    then
        echo "Please execute the script and pass the '--create' argument to invoke snapshot creation"
        qb_help_statement
        exit 1
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

function qb_create_snapshot() {
    # Explanations:
        # ${1} = Quobyte tenant UUID
        # ${2} = Quobyte volume name    
    qmgmt snapshot create ${1}/${2} "snapshot_${QB_TENANT_VOLUME}_$(date +%y%m%d-%H%M%S)"
}

function qb_main() {
    echo
    echo "Date              : $(date)"
    echo "Operation         : Creating a snapshot for all volumes (excluding scratch volumes)"
    echo

    if [[ $(qmgmt tenant list | egrep -i 'scratch') ]]
    then
        QB_IDENTIFY_SCRATCH_TENANT=( $(qmgmt tenant list --list-columns=Name,UUID | egrep -i +"scratch|axaxaxaxabybybybybczczczczc" | awk '{print $2}') )
        QB_IDENTIFY_SCRATCH_VOLUME="scratch"
    fi

    QB_TENANT_ARRAY=( $(qmgmt tenant list --list-columns=UUID ${QB_EXCLUDE_SCRATCH} | tail -n +2) )

    for QB_TENANT in ${QB_TENANT_ARRAY[*]}
    do
        QB_TENANT_VOLUMES_ARRAY=( $(qmgmt volume list ${QB_TENANT} --list-columns=Name | egrep -iv +"${QB_IDENTIFY_SCRATCH_VOLUME}|axaxaxaxabybybybybczczczczc" | tail -n +2) )

        for QB_TENANT_VOLUME in ${QB_TENANT_VOLUMES_ARRAY[*]}
        do
            if [[ $(qmgmt volume list ${QB_TENANT} --list-columns='Name,Mirrored From' | grep "${QB_TENANT_VOLUME}" | awk '{print $NF}') != "-" ]]
            then
                echo "Skipping snapshot creation for ${QB_TENANT}/"${QB_TENANT_VOLUME}" as it's a mirrored volume"
            else
                qb_create_snapshot ${QB_TENANT} "${QB_TENANT_VOLUME}" &
            fi
        done
        sleep 5
    done
}

#===========================================================================================================================================#

# Calling the functions:
if [[ ${#} != "1" || ${1} == +('-h'|'--help'|'?') ]]
then
    qb_help_statement
fi

qb_set_variables
qb_validation ${1}
qb_login
qb_main
qb_logout