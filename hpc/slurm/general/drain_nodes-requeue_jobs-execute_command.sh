#!/bin/bash

# Draining nodes:
function drain_nodes() {
    NODE_LIST="naming_prefix[0001-9999]"
    scontrol update NodeList=${NODE_LIST} State=DRAIN

    if [[ ${?} != "0" ]]
    then
        echo "Non-exit code received following drain command"
        exit 1
    fi
}

# Requeueing all jobs: 
function requeue_jobs() {
    JOB_IDS=( $(for i in $(sinfo -Nl | grep drain | awk '{print $1}'); do squeue -w ${i} --noheader | awk '{print $1}'; done) )
    scontrol requeue ${JOB_IDS[*]}

    if [[ ${?} != "0" ]]
    then
        echo "Non-exit code received following job requeue command"
    fi
}

# Command to be executed (if necessary) on compute nodes:
function post_drain_command() {
    if [[ ${1} == "execute" ]]
    then
        /path/to/script.sh
            ...Or...
        command -arg 1 -arg 2
    fi
}

drain_nodes

requeue_jobs

post_drain_command          # Requires the 'execute' argument to trigger the function