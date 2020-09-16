#!/bin/bash

#set -x
IFS=$'\n'				# Setting the Internal Field Separator (IFS) to new line, so as to accommodate any files with spaces in the filenames

help_statement() {
	echo
	echo "* Incorrect options provided Required syntax & examples are as follows:"
        echo
	echo "	${0} <number_of_days_as_integer> <comma_separated_excluded_user_accounts>"
	echo
        echo "	${0} 14								<--- Checks for all processes running longer than 14 days for all users (including root)"
	echo "	${0} 14 root,messagebus,rpc,statd,chrony			<--- Checks for processes running longer than 14 days for all users except the specified users (comma separated)"
	echo
	exit 1
}

if 	[[ ${#} != "2" ]]
then	help_statement
elif 	! (( ${1} )) 2>/dev/null
then	help_statement
fi

MAX_PID_DAYS=${1}
MAX_PID_TTL=$(( ( ( (60 * 60) * 24) * ${MAX_PID_DAYS}) ))	# 60 seconds * 60 minutes * 24 hours * 14 days = Max number of seconds a process can live for

#USER_EXCLUSIONS="root,messagebus,rpc,statd,chrony"
USER_EXCLUSIONS="${2}"

INFO_PADDING="       "
PROC_PADDING="      "
echo
printf "%s %s %s  (days)\n" "Max process duration	:" ${MAX_PID_DAYS} "${INFO_PADDING:${#MAX_PID_DAYS}}"
printf "%s %s %s  (seconds)\n" "Max process TTL		:" ${MAX_PID_TTL} "${INFO_PADDING:${#MAX_PID_TTL}}"
echo -e "Excluded user accounts:\t: ${USER_EXCLUSIONS}"
echo
echo "Starting process monitor ..."
echo

for USER_PROCESS in $(ps -N -u ${USER_EXCLUSIONS} -o pid,cmd,user --noheader)
do
	#echo
	#echo "Line:	${USER_PROCESS}"
	USER_PID=$(echo ${USER_PROCESS} | awk '{print $1}')
	
	PID_TTL=$(ps -o etimes= -p ${USER_PID})
	
	if (( ${PID_TTL} )) 2>/dev/null
	then	
		if 	(( ${PID_TTL} > ${MAX_PID_TTL} ))
		#then	< Place process_killing_code here - not included in this sample script >
		then	printf "%s %s %s %s\n" "[KILL] Process ID" ${USER_PID} "${PROC_PADDING:${#USER_PID}}" "is running longer than permitted   --->   ${USER_PROCESS}"
		fi
	fi
done

echo
#set +x