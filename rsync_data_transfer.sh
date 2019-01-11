#!/bin/bash
#_______________________________________________________________#
# Project: Remote file transfer using CPU affinity				#
# Author: Ben Watson - @WhatsOnDoc								#
# Date: December 2018											#
# LEGEND:														#
# 		#### 	= Major section									#
# 		##		= Explanation									#
#		#		= Commenting line for exclusion (as per usual)	#
#_______________________________________________________________#

#-----------------#
#    VARIABLES    #
#-----------------#

USER=""																			## The username required to establish a secure shell (ssh) connection to the remote host:
#read -p "Username: " USER														## User prompts for interactive invocation. Commented out by default.

REMOTE_HOST=""																	## The remote host name or IP address
#read -p "Remote host: " REMOTE_HOST											## User prompts for interactive invocation. Commented out by default.

REMOTE_DIR=""																	## The directory on the remote server that the data will be transferred into:
#read -p "Remote directory: " REMOTE_DIR										## User prompts for interactive invocation. Commented out by default.


	#-------------------------------------------------------------------------------#
	## \																		 / ##
	### { –––-–––– YOU SHOULD NOT NEED TO CHANGE ANYTHING FROM HERE ON –––-–––– } ###
	## /																		 \ ##
	#-------------------------------------------------------------------------------#


#-----------------#
#    FUNCTIONS    #
#-----------------#

validation_checks() {
## Checking that both mandatory parameters - source directory & thread value - have been provided as arguments:
if [[ -z ${WORK_DIR} ]] || [[ -z ${THREADING} ]]
then 
    echo -e "\nMandatory arguments have not been specified:\n\tDirectory:\t${WORK_DIR}\n\tThread value:\t${THREADING}" 
	help
    exit 1
fi
## Validation that passwordless authentication is enabled between source and destination machines (e.g. using ssh keys):
ssh -o PasswordAuthentication=no -o BatchMode=yes ${USER}@${REMOTE_HOST} exit &> /dev/null
## An unsuccessful attempt will return a non-zero error code, which will fail the following check:
if [[ $? = 0 ]]
then 
	echo -e "VALIDATED:\tPasswordless authentication to the remote server is in place.\n"
else 
	echo -e "\nERROR:\tCannot connect to the remote server without the use of a password\n"
	exit 1
fi

## Checking for the existence of a trailing slash on the provided directory path:
DIR_SLASH=$(echo ${WORK_DIR: -1})
## If there is a trailing slash, let's remove it from the path as the rsync syntax below includes the slash (and we don't want duplicate slashes):
if [[ ${DIR_SLASH} == '/' ]]
then WORK_DIR=$(echo ${WORK_DIR} | sed s'/.$//')
fi
}

help() {
	echo -e "\nHELP STATEMENT\nPlease execute the script specifying the parameters for source directory '-d' and number of parallel threads '-t' as an integer (i.e. not a floating point number)."
	echo -e "\nExample usage:\n\n\t $ /path/to/script.sh -d /directory/with/files/to/send -t 32\n"
}

													
#--------------------#
#    SCRIPT BLOCK    #
#--------------------#

echo -e "\nBeginning validation...\n"

while getopts "hd:t:" OPTION
do
case "$OPTION"
in
    d) WORK_DIR=${OPTARG}														## The directory specified by the user from which to transfer files, parsed from the input value in the script argument
		if [[ -d ${WORK_DIR} ]]													## Checking that the directory provided by the user at script invocation exists
		then 
			echo -e "VALIDATED:\tSource directory provided exists."
		else 
			echo -e "\nERROR:\tPlease specify a valid directory in which the files exist. \n"
			help
			exit 1
		fi
	;;
    t) THREADING=${OPTARG}														## The number of parallel transfer tasks that will be assigned to each processor used by the script
		if ((${THREADING})) 2> /dev/null 										## Checking that the thread value provided is an integer (not a string nor a float)
		then 
			echo -e "VALIDATED:\tThread value provided is an integer."
		else
			echo -e "\nERROR:\tPlease specify an integer (whole number) for the number of parallel execution threads.\n"
			help
			exit 1
		fi 
	;;									
    h | *) help && exit 1														## Capturing all other input; providing the help() statement for non-ratified inputs
	;;
esac
done

validation_checks																## Calling the validation_checks function

## Creating the runtime variables:
TOTAL_TASKS=$(find ${WORK_DIR} -type f | wc -l)									## The total number of files in the supplied directory path to be transferred
FILE_QUEUE=( $(ls ${WORK_DIR}) )												## Creating a variable array that contains the file names that are to be transferred
NUM_CPUS=$(( $(nproc) - 1 ))													## The number of CPUs to be used for transfers on the source server, less 1 as we number from 0
FILE_INDEX="0"																	## A simple file counter used to measure the number of tasks being undertaken

## Sending table headings to stdout for transfer information:
echo -e "\nHOSTNAME\t\t\t\tCPU\t\tTASK\t\tTHREAD\t\tFILE"

while true
do
	## Cycling the available CPUs in the source system:
    for CPU in $(seq 0 ${NUM_CPUS})
    do
		## Tracking that we still have outstanding tasks to complete:
        if [ ${FILE_INDEX} -lt ${TOTAL_TASKS} ]
        then
			## Running a check to see whether any rsync processes are running on the specific processor:
            CHECK="$(ps -e -o psr,cmd | awk -v aCPU=${CPU} '$1==aCPU' | awk '$2=="rsync"')"

			## If the variable is empty (and thus no process running), bind an rsync operation to the specific processor for the next file in the FILE_QUEUE: 
            if [[ -z ${CHECK} ]]
            then
				## A loop to specify the number of tasks that should be bound to each processor during distribution:
				for THREAD in $(seq 1 ${THREADING})
				do
                	## Checking the FILE_INDEX against the TOTAL_TASKS again to make sure we don't create empty tasks:
					if [ ${FILE_INDEX} -lt ${TOTAL_TASKS} ]
        			then
						## Defining CPU affinity for the transfer tasks (preventing the Linux scheduler from moving tasks between processors):
						taskset -c ${CPU} rsync -a -e ssh ${WORK_DIR}/${FILE_QUEUE[${FILE_INDEX}]} ${USER}@${REMOTE_HOST}:${REMOTE_DIR} &
						## Adding a slight pause to allow for large creation of parallel tasks:
						sleep 0.2s

						## Echo the current operation performed to stdout: 
                		echo -e "${HOSTNAME}\t\t\t\t${CPU}\t\t${FILE_INDEX}\t\t${THREAD}\t\t${FILE_QUEUE[$FILE_INDEX]}"

						## Increment the file counter:
                		((FILE_INDEX++))
					else
						:
					fi
				done
            fi

		## The exit path, for when the FILE_INDEX counter exceeds the value in TOTAL_TASKS:
        else
            echo -e "\nAll transfer tasks have been assigned to CPU cores.\n"
			## Tracking the outstanding number of running processes:
			until [[ $(pidof rsync | wc -w) == 0 ]]
			do
  				## Overwriting the same line with updated output to prevent explosion to stdout:
				echo -n "Remaining processes: `pidof rsync | wc -w`"
  				echo -n -e "\e[0K\r"
			done
			echo -e "\n\nOPERATION COMPLETE: Transferred ${FILE_INDEX} files to ${REMOTE_HOST}:${REMOTE_DIR}\n\n"
			exit 0
        fi
    done
done