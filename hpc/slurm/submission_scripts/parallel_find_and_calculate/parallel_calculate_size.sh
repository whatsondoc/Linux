#!/bin/bash
#SBATCH --exclusive

# CS = Calculate Size
# EO = Evaluate Output

CS_OUTPUT_PATH="/path/to/output/directory"

CS_ALL_PROCS=$(nproc --all)

IFS=$'\n'           # Setting the Internal Field Separator (IFS) to new line, so as to accommodate any files with spaces in the filenames

if [[ -n ${PFCS_UUID} ]]
then
    PFCS_PREFIX="${PFCS_UUID}_"
else
	PFCS_PREFIX="${RANDOM}_"
fi

CS_NAMES_TEMP_FILE_LIST="${PFCS_PREFIX}calculate_size_temp_split_file_list-"
CS_NAMES_FAILED_STATS="${PFCS_PREFIX}calculate_size_perm_failed_stats.txt"
CS_NAMES_STAT_NUMBERS="${PFCS_PREFIX}calculate_size_perm_stat_numbers.txt"

CS_INPUT_LIST=${1}

cs_validation() {
	if 	[[ ! -f ${1} ]]
	then	
		echo "No file list provided - exiting..." 
		exit 1
	elif 	[[ ${#} != "1" ]]
	then
		echo "One positional argument required for the file list"
		exit 1
	elif 	[[ -f ${CS_OUTPUT_PATH}/${CS_NAMES_STAT_NUMBERS} ]]
	then
		if 	[[ -s ${CS_OUTPUT_PATH}/${CS_NAMES_STAT_NUMBERS} ]]
		then 
			echo "Non-empty file exists at: ${CS_OUTPUT_PATH}/${CS_NAMES_STAT_NUMBERS}"
			echo "Exiting at this will likely causes issues or miscalculations."
			exit 1
		fi
	fi
}

cs_split_file_list() {
	split --number=l/${CS_ALL_PROCS} -d ${CS_INPUT_LIST} ${CS_OUTPUT_PATH}/${CS_NAMES_TEMP_FILE_LIST}
}

cs_cycle_files() {
	CS_STATE=0
    CS_INDEX=0
    CS_COUNTER=0

    for CS_FILE in $(cat ${1})
    do
        CS_STATE=$(stat -c %s ${CS_FILE} 2>/dev/null)
        if [[ ${?} == "0" ]]
        then
            CS_INDEX=$(( ${CS_INDEX} + ${CS_STATE} ))
        else
            echo ${CS_FILE} >> ${CS_OUTPUT_PATH}/${CS_NAMES_FAILED_STATS}
        fi

        CS_STATE=0
    done

	CS_TOTAL_GB=$(( (((${CS_INDEX} / 1024) / 1024) / 1024) ))
	echo "${1}:  ${CS_TOTAL_GB}" >> ${CS_OUTPUT_PATH}/${CS_NAMES_STAT_NUMBERS}
}

cs_evaluate_output() {
	EO_TOTAL_FILES=$(cat ${CS_INPUT_LIST} | wc -l)
    EO_TOTAL_GB="0"

	for EO_INDIV_TOTAL in $(cat ${CS_OUTPUT_PATH}/${CS_NAMES_STAT_NUMBERS} | awk '{print $2}')
	do
		EO_TOTAL_GB=$(( ${EO_TOTAL_GB} + ${EO_INDIV_TOTAL} ))
	done

	echo  >> ${CS_OUTPUT_PATH}/${CS_NAMES_STAT_NUMBERS}
	echo ">>>> Total capacity (GB)      : ${EO_TOTAL_GB}" >> ${CS_OUTPUT_PATH}/${CS_NAMES_STAT_NUMBERS}
	echo ">>>> Total number of files    : ${EO_TOTAL_FILES}" >> ${CS_OUTPUT_PATH}/${CS_NAMES_STAT_NUMBERS}
    
    echo "Total capacity (GB)      : ${EO_TOTAL_GB} GB"
    echo "Total number of files    : ${EO_TOTAL_FILES}"
}

cs_cleanup() {
    if [[ $(find ${CS_OUTPUT_PATH} -mindepth 1 -maxdepth 1 -type f -name "${CS_NAMES_TEMP_FILE_LIST}*") ]]
	then
        rm ${CS_OUTPUT_PATH}/${CS_NAMES_TEMP_FILE_LIST}*
    fi
	
    #rm ${CS_OUTPUT_PATH}/${PFCS_PREFIX}calculate_size_temp*
}

echo "
Start time              : $(date)
Operation               : Calculate size of dataset
File list               : ${CS_INPUT_LIST}
Submit directory        : $(dirname ${0})
Number of processes     : ${CS_ALL_PROCS}
"

cs_validation ${@}

cs_split_file_list

for CS_SPLITTED_FILE_LIST in $(ls ${CS_OUTPUT_PATH}/${CS_NAMES_TEMP_FILE_LIST}*)
do
    cs_cycle_files ${CS_SPLITTED_FILE_LIST} &
done

wait

cs_evaluate_output

cs_cleanup

echo "
End time                : $(date)
"