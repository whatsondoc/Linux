#!/bin/bash

# List volume count and volume names per Volume Configuration
# INCOMPLETE: If a volume and Volume Configuration both have the same name, they will show up in the lists produced. Needs a fix.


function qb_set_variables() {
    QB_LOGIN_USERNAME=""            # Username to login to Quobyte management
    QB_LOGIN_PASSWORD=""            # Password to login to Quobyte management

    QB_VOLUME_CONFIG_SELECTION=( ${@} )
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
    if [[ -z ${QB_VOLUME_CONFIG_SELECTION[*]} ]]
    then
        QB_VOLUME_CONFIG_SELECTION=( $(qmgmt volume config list) )
    fi

    for QB_LIST_VOLUME_CONFIGS in ${QB_VOLUME_CONFIG_SELECTION[*]}
    do
        if [[ ! $(qmgmt volume config list | grep ${QB_LIST_VOLUME_CONFIGS}) ]]
        then
            echo
            echo "Unknown volume configuration  : ${QB_LIST_VOLUME_CONFIGS}"
            echo
        else

            QB_INDEX="0"
            echo
            echo "Volume configuration name     : ${QB_LIST_VOLUME_CONFIGS}" 
            echo "Volume count                  : $(qmgmt volume list --list-columns=Configuration | fgrep "${QB_LIST_VOLUME_CONFIGS}" | wc -l)"
            for QB_LIST_VOLUMES in $(qmgmt volume list --list-columns=Name,Configuration | fgrep "${QB_LIST_VOLUME_CONFIGS}" | awk '{print $1}')
            do
                if [[ ${QB_INDEX} == "0" ]]
                then
                    echo "Current volume list           : ${QB_LIST_VOLUMES}"
                else
                    echo "                              : ${QB_LIST_VOLUMES}"
                fi
                ((QB_INDEX++))
            done
            echo
        fi
    done
}

#===========================================================================================================================================#

# Calling the functions:
qb_set_variables ${@}
qb_logout
qb_main
qb_logout