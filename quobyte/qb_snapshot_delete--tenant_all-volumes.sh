#!/bin/bash

function qb_set_variables() {
    QB_LOGIN_USERNAME=""            # Username to login to Quobyte management
    QB_LOGIN_PASSWORD=""            # Password to login to Quobyte management

    QB_VOLUMES="ALL"                # <<< INCOMPLETE: Adjust to support specific inclusion/exclusion of volumes
    QB_VOLUME_LIST_INDEX="0"
}

function qb_help_statement() {
    echo "    
    This script will do the following:
        1. Identify all volumes that exist within a tenant (from the tenant ID)
        2. Delete all snapshots associated with each identified volume
    
    Usage:
        ${0}  <TENANT_ID_OR_NAME>  <CONFIRM_DELETION>
        ${0}  tenant_abc  --delete-volume-snapshots
        ${0}  1234abcd-1234-ab12-cd34-fedcba654321  --delete-volume-snapshots
    
    The above example deletes all snapshots for volumes located in the specified tenant ID.
    "

    exit 0
}

function qb_validation() {
    if [[ $(qmgmt volume list ${1}) ]]
    then
        QB_TENANT=${1}
    else
        echo "Tenant Name or ID could not be found"
        exit 1
    fi

    if [[ ${2} != "--delete-volume-snapshots" ]]
    then
        echo "Please execute the script and pass the '--delete-volume-snapshots' argument to invoke snapshot creation"
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

function qb_main() {
    echo
    echo "Date              : $(date)"
    echo "Operation         : Deleting all snapshots from volumes"
    echo "Tenant ID         : ${QB_TENANT}"
    for QB_LIST_TENANT_VOLUME in $(qmgmt volume list --list-columns=Name ${QB_TENANT} | tail -n +2)
    do
        if [[ ${QB_VOLUME_LIST_INDEX} == "0" ]]
        then
            echo "Volumes involved  : ${QB_LIST_TENANT_VOLUME}"
        else
            echo "                  : ${QB_LIST_TENANT_VOLUME}"
        fi
        ((QB_VOLUME_LIST_INDEX++))
    done
    echo

    for QB_TENANT_VOLUME in $(qmgmt volume list --list-columns=Name ${QB_TENANT} | tail -n +2)
    do
        if [[ $(qmgmt volume list ${QB_TENANT} --list-columns='Name,Mirrored From' | grep "${QB_TENANT_VOLUME}" | awk '{print $NF}') != "-" ]]
        then
            echo "Skipping snapshot creation for ${QB_TENANT}/"${QB_TENANT_VOLUME}" as it's a mirrored volume"
        else
            #export QB_SNAPSHOT_COUNTER_${QB_TENANT_VOLUME}="0"
            for QB_TENANT_VOLUME_SNAPSHOT in $(qmgmt snapshot list ${QB_TENANT}/"${QB_TENANT_VOLUME}" | awk '{print $2}' | tail -n +2)
            do
                qmgmt snapshot delete -f ${QB_TENANT}/"${QB_TENANT_VOLUME}" ${QB_TENANT_VOLUME_SNAPSHOT}
                #if [[ ${?} == "0" ]]
                #then
                    #((QB_SNAPSHOT_COUNTER_${QB_TENANT_VOLUME}++))
                #fi
            done &       # Puts each volume's snapshot deletion into the background
        fi        
    done

    wait

    # INCOMPLETE: Prepare/Fix snapshot number collections 
    #QB_ALL_SNAPSHOT_COUNTERS=( $(env | grep QB_SNAPSHOT_COUNTER_) )
    #for QB_SNAPSHOT_COUNTER in ${QB_ALL_SNAPSHOT_COUNTERS[*]}
    #do
    #    echo "Total number of snapshots deleted for $(echo ${QB_SNAPSHOT_COUNTER} | cut -f4 -d '_' | cut -f1 -d '='): $(echo ${QB_SNAPSHOT_COUNTER} | cut -f2 -d '=')"
    #done

    echo
    echo "All snapshots deleted from tenant: ${QB_TENANT}"
    echo
}

#===========================================================================================================================================#

# Calling the functions:
if [[ ${#} != "2" || ${1} == +('-h'|'--help'|'?') ]]
then
    qb_help_statement
fi

qb_set_variables
qb_validation ${@}
qb_login
qb_main
qb_logout