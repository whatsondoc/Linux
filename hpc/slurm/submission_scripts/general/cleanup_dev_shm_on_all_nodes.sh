#!/bin/bash

CLEANUP_SCRIPT="/path/to/cleanup/script.sh"
OUTPUT_DIR="${HOME}/cleanup_shm_outputs"
SELECT_DIRECTORY="/dev/shm/"
SELECT_USER="${USER}"

function help_statement() {
	echo
	echo "Execute the script with '--all' to run cleanup on all nodes in all partitions. Optionally, specify a partition as an argument on which to specifically run the cleanup script on."
    echo
	echo "	An example:   ${0} --all"
    echo "	An example:   ${0} defq"
	echo
}

if 		[[ ${#} != "1" ]]
then
		echo
		echo "An invalid number of arguments passed. Arguments provided:  ${@}"
		help_statement
		exit 1

elif 	[[ ${1} == +('-h'|'--help'|'?') ]]  
then 
		help_statement
		exit 0

elif 	[[ ${1} == "--all" ]]
then
		PARTITIONS=( $(scontrol show partition | grep PartitionName | cut -f2 -d '=') )

else 	
		if [[ $(scontrol show partition | grep PartitionName | cut -f2 -d '=' | grep ${1}) ]]
		then
			PARTITIONS=( ${1} )
		else
			echo "Invalid partition specified:  ${1}"
			echo "Exiting..."
			echo
			exit 1
	fi
fi

[[ ! -d ${OUTPUT_DIR} ]]  &&  mkdir ${OUTPUT_DIR}

for PARTITION in ${PARTITIONS[*]}
do
	NODES=( $(sinfo -Nl --noheader | egrep -vi 'drain|down' | grep ${PARTITION} | awk '{print $1}') )

	for NODE in ${NODES[*]}
	do
		sbatch --job-name="cleanup_dev_shm" --output="${OUTPUT_DIR}/cleanup_dev_shm--%j-%x.out" --error="${OUTPUT_DIR}/cleanup_dev_shm--%j-%x.out" --partition=${PARTITION} --nodelist=${NODE} ${CLEANUP_SCRIPT}
	done
done