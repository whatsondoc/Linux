#!/bin/bash

# A test/sample script to create resource utilisation:

IO_SPIKE() {
	taskset -c ${SLURM_PROCID} timeout ${WALL_TIME} bash -c "while true; do dd if=${IO_SRC_FILE} of=/dev/null bs=1M 2>/dev/null; done"
}

CPU_SPIKE() {
        taskset -c ${SLURM_PROCID} timeout ${WALL_TIME} yes \!spiking\!> /dev/null
}

TEST=$1
IO_SRC_FILE=$2
WALL_TIME=$3

if [[ ${TEST} == "IO" ]]
then
	IO_SPIKE &
	echo -e "Task ${SLURM_TASK_PID} from job ID ${SLURM_JOBID} on core ${SLURM_PROCID} on `hostname`: Submitted"

elif [[ ${TEST} == "CPU" ]]
then
	CPU_SPIKE &	
	echo -e "Task ${SLURM_TASK_PID} from job ID ${SLURM_JOBID} on core ${SLURM_PROCID} on `hostname`: Submitted"

elif [[ ${TEST} == "IO_and_CPU" ]]
then
	IO_SPIKE &
	CPU_SPIKE &
	echo -e "Task ${SLURM_TASK_PID} from job ID ${SLURM_JOBID} on core ${SLURM_PROCID} on `hostname`: Submitted"
fi

wait
echo -e "Task ${SLURM_TASK_PID} from job ID ${SLURM_JOBID} on core ${SLURM_PROCID} on `hostname`: Completed"