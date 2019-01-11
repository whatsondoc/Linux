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
if [[ -z ${USER} ]] || [[ -z ${REMOTE_HOST} ]] || [[ -z ${REMOTE_DIR} ]]
then
	echo -e "\nERROR:\tThe following variables have not been defined within the script:\n\tUser:\t\t${USER}\n\tRemote Host:\t${REMOTE_HOST}\n\tRemote Directory:\t${REMOTE_DIR}"
	echo -e "\nPlease use your favourite text editor to edit the script and populate the above variables."
	TERMINATE="true"
fi

## Checking that both mandatory parameters - source directory & thread value - have been provided as arguments:
if [[ -z ${SOURCE_DIR} ]] || [[ -z ${THREADING} ]]
then 
    echo -e "\nERROR:\tMandatory arguments have not been specified:\n\tDirectory:\t${SOURCE_DIR}\n\tThread value:\t${THREADING}" 
    TERMINATE="true"
fi

## Checking for the existence of a trailing slash on the provided directory path:
DIR_SLASH=$(echo ${SOURCE_DIR: -1})
## If there is a trailing slash, let's remove it from the path as the rsync syntax below includes the slash (and we don't want duplicate slashes):
if [[ ${DIR_SLASH} == '/' ]]
then 
	SOURCE_DIR=$(echo ${SOURCE_DIR} | sed s'/.$//')
fi

## Validation that passwordless authentication is enabled between source and destination servers (e.g. using ssh keys):
ssh -o PasswordAuthentication=no -o BatchMode=yes ${USER}@${REMOTE_HOST} exit 2> /dev/null
## An unsuccessful attempt will return a non-zero error code, which will fail the following check:
if [[ $? == 0 ]]
then 
	echo -e "\nVALIDATED:\tPasswordless authentication to the remote server is in place.\n"
else 
	echo -e "\nERROR:\tCannot connect to the remote server without the use of a password.\n"
	TERMINATE="true"
fi

## Checking that rsync is installed on the local server:
if [[ -x $(command -v rsync) ]]
then
	echo -e "\nVALIDATED:\trsync is present on the local server.\n"
else
	echo -e "\nERROR:\trsync is not present on the local server (or, at least, not included in '$PATH').\n"
	TERMINATE="true"
fi

## Checking rsync is installed on the remote server:
ssh ${USER}@${REMOTE_HOST} 'command -v rsync' 2&>1 /dev/null
## An unsuccessful attempt will return a non-zero error code, which will fail the following check:
if [[ $? == 0 ]]
then
	echo -e "\nVALIDATED:\trsync is present on the remote server.\n"
else
	echo -e "\nERROR:\trsync is not present on the remote server (or, at least, not included in '$PATH').\n"
	TERMINATE="true"
fi

## Checking the taskset command exists on the local server (as this is used to bind processes to CPUs):
if ! [[ -x $(command -v taskset) ]]
then 
	echo -e "\nERROR: taskset is not present on this server (or, at least, not included in '$PATH'). It is typically available in the util-linux package in Linux.\n"
	TERMINATE="true"
fi

## If any of the prior validation checks fail, then the help() function will be called and the script will exit: 
if [[ ${TERMINATE} == "true" ]]
then
	help
	exit 1
fi
}

help() {
	echo -e "\nHELP STATEMENT\nPlease execute the script specifying the parameters for source directory '-d' and number of parallel threads '-t' as an integer (i.e. not a floating point number)."
	echo -e "\nExample usage:\n\n\t $ /path/to/script.sh -d /directory/with/files/to/send -t 32\n"
	echo -e "\nPackages & commands required:\tssh; nproc; ps; awk; sed; rsync (on local server); rsync (on remote server); taskset; comm\n"
}

													
#--------------------#
#    SCRIPT BLOCK    #
#--------------------#

TIMER_START=$(date +%s)															## Capturing the starting second count to be used to calculate the wall time

echo -e "\nBeginning validation...\n"

while getopts "hd:t:" OPTION
do
case "$OPTION"
in
    d) SOURCE_DIR=${OPTARG}														## The directory specified by the user from which to transfer files, parsed from the input value in the script argument
		if [[ -d ${SOURCE_DIR} ]]												## Checking that the directory provided by the user at script invocation exists
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
TOTAL_TASKS=$(find ${SOURCE_DIR} -type f | wc -l)								## The total number of files in the supplied directory path to be transferred
FILE_QUEUE=( $(ls ${SOURCE_DIR}) )												## Creating a variable array that contains the file names that are to be transferred
NUM_CPUS=$(( $(nproc) - 1 ))													## The number of CPUs to be used for transfers on the source server, less 1 as we number from 0
FILE_INDEX="0"																	## A simple file counter used to measure the number of tasks being undertaken

echo -e "\nSource directory:\t\t${SOURCE_DIR}\nRemote directory:\t\t${REMOTE_DIR}\nNumber of tasks:\t\t${TOTAL_TASKS}\nNumber of processors:\t\t${NUM_CPUS}\nThread count:\t\t${THREADING}\n"

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
						taskset -c ${CPU} rsync -a -e ssh ${SOURCE_DIR}/${FILE_QUEUE[${FILE_INDEX}]} ${USER}@${REMOTE_HOST}:${REMOTE_DIR} &
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

			## Checking for differences between source target directories:
			echo -e "\n\nChecking for the differences between source & remote directories..."
			FILE_LISTS="/dev/shm/data-transfer-file-list"
			find ${SOURCE_DIR} -type f | sort > ${FILE_LISTS}.source														## Capturing the contents of the source directory and storing in a temp file on local memory
			ssh ${USER}@${REMOTE_HOST} "find ${REMOTE_DIR} -type f | sort" > ${FILE_LISTS}.remote							## Capturing the contents of the remote directory and storing in a temp file on local memory
			DIR_COMPARISON=( $(comm -23 ${FILE_LISTS}.source ${FILE_LISTS}.remote) )										## Comparing the source & remote directories from the temp files just created, and storing any differences in a variable array
			
			if [[ -n ${DIR_COMPARISON} ]]																					## A query on the variable with '-n' sees whether there is a value set. If there is, follow the loop... 
			then
				if [[ $(ls ${SOURCE_DIR} | wc -l) == ${TOTAL_TASKS} ]]														## Checking to see whether the current number of files in the source directory matches $TOTAL_TASKS, generated earlier in the script
				then
					echo -e "\nNot all files have been transferred during this operation."
				else
					echo -e "\nThere is a difference in the number of files present than when the transfer was initiated."
				fi
				echo -e "\nThe following files exist on the source but not on the destination:"
				for DIFF_FILE in ${DIR_COMPARISON}																			## Looping through the variable array and printing the contents to stdout
				do 
					echo -e "\t${DIFF_FILE}"
				done	
				echo -e "\nYou can re-run the script and rsync will send only those files that do not exist on the remote directory."
			
			else																											## The alternative, assuming there is no value stored in $DIR_COMPARISON 
				echo -e "\nThe source and remote directories are in sync - all files were successfully transferred."
			fi
			rm ${FILE_LISTS}.source ${FILE_LISTS}.remote																	## Being good citizens and tidying up after ourselves

			echo -e "\n\nOPERATION COMPLETE: Submitted ${FILE_INDEX} files for transfer to ${REMOTE_HOST}:${REMOTE_DIR}\n\n"

			TIMER_END=$(date +%s)																							## Capturing the end second count
			TIMER_DIFF_SECONDS=$(( ${TIMER_END} - ${TIMER_START} ))															## Calculating the difference
			TIMER_READABLE=$(date +%H:%M:%S -ud @${TIMER_DIFF_SECONDS})														## Converting the second delta into a human readable time format (HH:MM:SS)
			echo -e "\n\nWall time: ${TIMER_READABLE}\n"																	## And printing it to stdout

			exit 0
        fi
    done
done