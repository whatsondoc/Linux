#!/bin/bash

NODES=( localhost localhost localhost )

print_help() {
	echo
	echo "Syntax		${0}	[command|file]  [command_to_be_executed|file_to_be_transferred]"
	echo
	echo "Example		${0}	command ls -lh /home/${USER}"
	echo "Example		${0}	transfer /etc/slurm/slurm.conf"
	echo
	echo "Remote commands will be sent over ssh using the default port"
	echo "Files will be transferred (copied) to the same location on the remote node using 'scp'"
	echo "Nodes can be defined within this tool in the 'NODES' variable array"
	echo
	echo "N.B. Using ssh keys makes this process significantly more streamlined (otherwise, passwords every time)"
	echo
	exit 1
}

if 		[[ ${1,,} == "command" ]]
then 	EXECUTE="${1}"
		shift
		INPUT="${@}"
elif 	[[ ${1,,} == "transfer" ]]
then 	EXECUTE="${1}"
		INPUT=${2}
		if 	[[ ! -f ${INPUT} ]]
		then 	echo "File cannot be enumerated at source: ${INPUT}"
			echo "Exiting..."
			exit 1
		fi
elif    [[ ${#} == "0" ]]
then    print_help
else 	echo "Unrecognised option 	${1}"
		print_help
		exit 1
fi

for NODE in ${NODES[*]}
do 	echo "Connecting to: ${NODE}"
	CHECK_NAME=$(ssh -o ConnectTimeout=4 ${NODE} 'hostname')
	CHECK_CODE=${?}
	
	if 	[[ ${CHECK_CODE} != 0 ]]
	then	echo "${NODE} is unreachable - skipping ${EXECUTE}"
	else 	if	[[ ${EXECUTE} == "command" ]]
		then	ssh ${USER}@${NODE} "${INPUT}"
		elif	[[ ${EXECUTE} == "transfer" ]]
		then	scp ${INPUT} ${USER}@${NODE}:${INPUT}
		fi
	fi
	echo
done
