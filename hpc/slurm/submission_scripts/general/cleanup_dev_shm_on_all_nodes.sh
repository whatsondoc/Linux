#!/bin/bash

CLEANUP_SCRIPT="/path/to/cleanup/script.sh"
OUTPUT_DIR="${HOME}/cleanup_shm_outputs"
SELECT_DIRECTORY="/dev/shm/"
SELECT_USER="${USER}"

[[ ! -d ${OUTPUT_DIR} ]]  &&  mkdir ${OUTPUT_DIR}

for PARTITION in $(scontrol show partition | grep PartitionName | cut -f2 -d '=')
do
	NODES=( $(sinfo -Nl --noheader | egrep -vi 'drain|down' | grep ${PARTITION} | awk '{print $1}') )

	for NODE in ${NODES[*]}
	do
		sbatch --job-name="cleanup_shm" --output="${OUTPUT_DIR}/cleanup-%j-%x.out" --error="${OUTPUT_DIR}/cleanup-%j-%x.out" --partition=${PARTITION} --nodelist=${NODE} ${CLEANUP_SCRIPT}
	done
done