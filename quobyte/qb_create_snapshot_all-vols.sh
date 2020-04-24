#!/bin/bash

# Creating Quobyte snapshots for all volumes on a system, except for those named 'scratch' (case insensitive)
# This script could be used as part of a crontab entry, to allow snapshots outside of the hourly or daily schedule options

qb_command() {
    # Explanations:
        # ${1} = Quobyte tenant UUID
        # ${2} = Quobyte volume name    
    qmgmt snapshot create ${1}/${2} snapshot_${QB_TENANT_VOLUME}_$(date +%y%m%d-%H%M%S)
}

QB_USER=""
QB_PASS=""

if      [[ -n ${QB_USER} && ${QB_PASS} ]]
then
    qmgmt user login ${QB_USER} ${QB_PASS}

    if [[ $? == "0" ]]
    then
        QB_USER_SESSION="ACTIVE"
    fi
fi

if [[ $(qmgmt tenant list | egrep -i 'scratch') ]]
then
    QB_IDENTIFY_SCRATCH=$(qmgmt tenant resolve $(qmgmt tenant list | egrep -i 'scratch' | awk '{print $1}'))
fi

QB_TENANT_ARRAY=$( (qmgmt tenant list --list-column=UUID | grep -v ${QB_IDENTIFY_SCRATCH} | tail -n +2) )

for QB_TENANT in ${QB_TENANT_ARRAY[*]}
do
    QB_TENANT_VOLUMES_ARRAY=$( (qmgmt volume list ${QB_TENANT} --list-column=Name | egrep -iv 'scratch' | tail -n +2) )

    for QB_TENANT_VOLUME in ${QB_TENANT_VOLUMES_ARRAY[*]}
    do
        if [[ $(qmgmt volume list ${QB_TENANT} --list-columns='Name,Mirrored From' | grep ${QB_TENANT_VOLUME} | awk '{print $NF}') != "-" ]]
        then
            echo "Skipping snapshot creation for ${QB_TENANT}/${QB_TENANT_VOLUME} as it's a mirrored volume"
        else
            qb_command ${QB_TENANT} ${QB_TENANT_VOLUME} &
        fi
    done
    sleep 5
done

if [[ ${QB_USER_SESSION} == "ACTIVE" ]]
then
    qmgmt user logout
fi