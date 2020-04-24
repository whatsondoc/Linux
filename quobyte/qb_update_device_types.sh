#!/bin/bash

# Credentials for creating an authenticated Quobyte user session:
QB_USER=""
QB_PASS=""

### Quick walkthrough:

# Either ADD or REMOVE:
QB_DEVICE_OPERATION="${1}"

# The following device type:
QB_NEW_DEVICE_TYPE="${2}"                   # M[ETADATA], D[ATA] or R[EGISTRY]

# To all existing devices with this type:
QB_EXISTING_DEVICE_TYPE="${3}"              # M[ETADATA], D[ATA] or R[EGISTRY]

#===========================================================================================================================================#

if [[ ${#} == "0" || ${1} == +('-h'|'--help'|'?') ]]
then
    echo "    
    This script will do the following:
        1. Use the first argument to determine whether to add or remove a device type (either ADD or REMOVE)
        2. Use the second argument to specify a new device type, e.g. DATA or METADATA
        3. Loop through all existing devices with the type as specified in the third agument
        4. ...Adding the desired additional device type
    
    Usage:
        ${0}  <ADD_OR_REMOVE>  <NEW_DEVICE_TYPE>  <EXISTING_DEVICE_TYPE>
        ${0}  ADD  DATA  METADATA
    
    The above example adds the DATA device type to all devices that currently have the METADATA type.
    "
fi

if      [[ ${1} == "ADD" ]]
then    QB_DEVICE_OPERATION="add-type"

elif    [[ ${1} == "REMOVE" ]]
then    QB_DEVICE_OPERATION="remove-type"

else    echo "Invalid operation type - exiting..."
        exit 1
fi

if      [[ ${QB_NEW_DEVICE_TYPE}  !=  +(METADATA|DATA|REGISTRY)  ]]
then    echo "Please specify a valid new device type - exiting..."
        exit 1
fi

if      [[ ${QB_EXISTING_DEVICE_TYPE} == "REGISTRY" ]]
then    QB_DEVICES_TO_UPDATE=$(qmgmt device list | grep 'REGISTRY ' | awk '{print $1}')

elif    [[ ${QB_EXISTING_DEVICE_TYPE} == "METADATA" ]]
then    QB_DEVICES_TO_UPDATE=$(qmgmt device list | grep 'METADATA ' | awk '{print $1}')

elif    [[ ${QB_EXISTING_DEVICE_TYPE} == "DATA" ]]
then    QB_DEVICES_TO_UPDATE=$(qmgmt device list | grep 'DATA ' | awk '{print $1}')

else    echo "Please specify a valid existing device type - exiting..."
        exit 1
fi

if      [[ -n ${QB_USER} && ${QB_PASS} ]]
then
    qmgmt user login ${QB_USER} ${QB_PASS}

    if [[ $? == "0" ]]
    then
        QB_USER_SESSION="ACTIVE"
    fi
fi

for QB_UPDATE_DEVICE_TYPE in ${QB_DEVICES_TO_UPDATE}
do
    qmgmt device update  ${QB_DEVICE_OPERATION}  ${QB_UPDATE_DEVICE_TYPE}  ${QB_NEW_DEVICE_TYPE}
done

if [[ ${QB_USER_SESSION} == "ACTIVE" ]]
then
    qmgmt user logout
fi