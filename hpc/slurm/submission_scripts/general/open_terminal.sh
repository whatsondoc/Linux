#!/bin/bash

term_usage() {
echo "
Term script usage : $(basename $0) [-p PARTITION_NAME] [-w NODE_NAME] [-t TIME_HOURS] [-h HELP]

   Example (0)     : $(basename $0)					                << Opens a terminal with all default settings: any available node in the default partition with the default 4 hour time window
   Example (1)     : $(basename $0) -p firstq				        << Opens a terminal on any node in the firstq partition with the default 4 hour time window
   Example (2)     : $(basename $0) -p firstq -t 2			        << Opens a terminal on any node in the firstq partition with a 2 hour time window
   Example (3)     : $(basename $0) -p secondq -w node0001		    << Opens a terminal on node0001 in the secondq partition, with the default 4 hour time window
   Example (4)     : $(basename $0) -p secondq -w node0001 -t 8	    << Opens a terminal on node0001 in the secondq partition, with an 8 hour time window
" >&2
}

#---------

while getopts "w:p:t:h" OPTION
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

echo "
#---------TERM---------#
    Opening a Term  
    $(date +%y/%m/%d--%H:%M) 

Partition : ${PARTITION}
Nodelist  : ${NODELIST}
Time      : ${TIME} hours
Shell     : ${SHELL}
#----------------------#
"

set -x
srun ${CMD_TIME} ${CMD_PARTITION} ${CMD_NODELIST} --pty ${SHELL}