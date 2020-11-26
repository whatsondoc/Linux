#!/bin/bash

info() { echo "${1}" ; }
verbose() { if [[ ${VERBOSE} == "TRUE" ]]; then echo "${1}"; fi ; }

term_usage() {
echo "
Term script usage : $(basename $0) [-p PARTITION_NAME] [-w NODE_NAME] [-t TIME_HOURS] [-e]

	[ -e ] = Exclusive ownership of node
	[ -v ] = Enable verbose mode
	[ -h ] = Print this help menu

   Example (0)     : $(basename $0)					<< Opening a terminal with all default settings: any available node in the default partition and the default 4 hour time window
   Example (1)     : $(basename $0) -p gpu_queue			<< Opening a terminal on any node in the genericq partition with the default 4 hour time window
   Example (2)     : $(basename $0) -p gpu_queue -t 2			<< Opening a terminal on any node in the genericq partition with a 2 hour time window
   Example (3)     : $(basename $0) -p gpu_queue -w node0001		<< Opening a terminal on the srlp01297 node in the genericq partition, with the default 4 hour time window
   Example (4)     : $(basename $0) -p gpu_queue -w node0001 -t 8	<< Opening a terminal on the srlp01297 node in the genericq partition, with an 8 hour time window
   Example (5)     : $(basename $0) -p gpu_queue -w node0001 -t 8 -e	<< Opening a terminal on the srlp01297 node in the genericq partition, with an 8 hour time window and exclusive ownership of the node
" >&2
}

#---------

while getopts "w:p:t:evh" OPTION
do
case ${OPTION} in
	w) NODELIST=${OPTARG}
      		if 	[[ -n ${NODELIST} ]]
		then
				if 	! scontrol show node ${NODELIST} > /dev/null
				then	echo "Node/Nodelist ${NODELIST} is not recognised - falling back to requesting a terminal on any available node"
					NODELIST="<any>"
				else	CMD_NODELIST="--nodelist=${NODELIST}"
				fi
		fi
		;;

	p) PARTITION=${OPTARG}
      		if	[[ -n ${PARTITION} ]]
		then
				if	! scontrol show partition ${PARTITION} > /dev/null
				then	echo "Requested partition ${PARTITION} is not recognised - falling back to requesting a terminal on the default partition"
					PARTITION="<default>"
				else	CMD_PARTITION="--partition=${PARTITION}"
				fi
		fi
		;;

	t) TIME=${OPTARG}
		if	[[ -n ${TIME} ]]
		then
			if	! ((${TIME})) 2> /dev/null
			then	echo "Number of hours requested \"${TIME}\" is not an integer - falling back to requesting the default time value of 4 hours"
				TIME="4"
			fi
			CMD_TIME="--time=0${TIME}:00:00"
		fi
		;;

	e) EXCLUSIVE="--exclusive"
		;;

	v) VERBOSE="TRUE"
		;;

    	h | *) term_usage && exit 1
      		;;
	esac
done

if      [[ ! -n ${TIME} ]]
then	TIME="4"
	CMD_TIME="--time=0${TIME}:00:00"
fi

if	[[ ! -n ${NODELIST} ]]
then	NODELIST="<any>"
fi

if	[[ ! -n ${PARTITION} ]]
then	PARTITION="<default>"
fi

if	[[ ! -n ${EXCLUSIVE} ]]
then	RESOURCES="Shared"
else	RESOURCES="Exclusive"
fi

echo "
#--------TERM---------#
    Opening a term  
    $(date +%y/%m/%d--%H:%M)"
verbose "
Partition : ${PARTITION}
Nodelist  : ${NODELIST}
Time      : ${TIME} hours
Shell     : ${SHELL}
Resources : ${RESOURCES}"
info "#----------------------#
"

if 	[[ -n ${VERBOSE} ]]
then 	set -x
fi

srun ${CMD_TIME} ${CMD_PARTITION} ${CMD_NODELIST} ${EXCLUSIVE} --pty ${SHELL}
