#!/bin/bash

## Functions:
func_help() {
    echo -e "\v----------------------------------\n| HELP: FILE PREFETCHING PROGRAM |\n----------------------------------"
    echo -e "\vThis program is intended to work in conjunction with an application performing some type of I/O bound computation, possibly/probably invoked as part of the same batch submission script."
    echo -e "It is expected that this program will be invoked as a background process before the application is due to run, and have the application look to system memory to read files instead of an external storage system.\n"
    echo -e "This program will create a file list based on the input file list, containing the relevant file names pointing to a full path within shared memory. The produced file list will be located in /dev/shm/prefetch/file_lists\n"
    echo -e "A minimum of 2 prefetch slots should be used, otherwise your application will need to wait for the file to be copied from external storage to system memory before being processed (which is seemingly pointless...)."
    echo -e "The application should assume responsibility of deleting files once they have been processed, to clear the slot allowing the program to prefetch the next file in the sequence. This program can't currently reliably know when the application has finished processing."
    echo -e "\vUsage of this program:
    \n  $ ./path/to/prefetch-program -s {NUMBER_OF_PREFETCH_SLOTS} -i /path/to/input/file.list
    \n  $ ./path/to/prefetch-program -s 4 -i /home/cluster_user/input_files/complete_file.list   \v"
}

func_catching_errors_first() {
! [[ -n ${PREFETCH_SLOTS} && -n ${PROCESS_FILE_LIST} ]]  && echo -e "\v*** ERROR:\tNot all mandatory arguments given."  &&  func_help  &&  exit 1
}

## System Resources:
func_collect_system_info() {
SYSTEM_CORES=$(nproc --all)
USABLE_CORES=$(( ${SYSTEM_CORES} - 2 ))
FREE_MEMORY=$(( $(cat /proc/meminfo | grep MemAvailable | awk '{print $2}') / 2 ))              # Free memory caluclated in Megabytes to mitigate lack of floating point number support in bash
PREFETCH_BASE="/dev/shm/prefetch"
PREFETCH_DIR="${PREFETCH_BASE}/${SLURM_JOB_NAME}-${SLURM_JOBID}"
PREFETCH_FILE_LIST_DIR="${PREFETCH_BASE}/file_lists"
SHM_FILE_LIST="${PREFETCH_FILE_LIST_DIR}/`basename ${PROCESS_FILE_LIST}`"
PROCESS_FILE_ARRAY=( $(cat ${PROCESS_FILE_LIST}) )
PROCESS_FILE_ARRAY_LEN=$(( ${#PROCESS_FILE_ARRAY[*]} - 1 ))                                     # Reducing the count by 1 as the array index begins at 0, and this length variable is used to count up to in the prefetching loop
PROCESS_SLOTS="1"                                                                               # ((Fixing the number of distinct processes to 1 for now per invocation))
echo -e "\n--------------------------| Prefetching configuration |--------------------------
Job Name:\t\t${SLURM_JOB_NAME}   \nJob ID:\t\t\t${SLURM_JOBID}\nHostname:\t\t`hostname`   \nSystem Cores:\t\t${SYSTEM_CORES}   \nFree System Memory:\t$(( (${FREE_MEMORY}/1024)/1024 ))GB
Cache Directory:\t${PREFETCH_DIR}   \nPrefetch File List:\t${SHM_FILE_LIST}   \nProcess File List:\t${PROCESS_FILE_LIST}
\nProcess Slots: ${PROCESS_SLOTS}  (*)  Prefetch Slots: ${PREFETCH_SLOTS}  (=)  Total Prefetch Slots: ${TOTAL_PREFETCH_SLOTS}
---------------------------------------------------------------------------------\n"
}

func_memory_calculation() {
TOTAL_PREFETCH_SLOTS=$(( ${PROCESS_SLOTS} * ${PREFETCH_SLOTS} ))                                # Creating the total number of prefetch slots across processes
declare -a SFS SMC                                                                              # Declaring variable arrays: SMC = State (of) Memory Calculation  ||  SFS = State (of) File Sizes
for FSF in $(cat ${PROCESS_FILE_LIST}); do SFS+=( $(du -a $FSF | awk '{print $1}') ); done      # FSF = File Size, Files: Looping through the files in the file list to catch their size and put the values into an array
SFS=( $(echo ${SFS[*]} | tr " " "\n" | sort -nr | head -n ${TOTAL_PREFETCH_SLOTS}) )            # Sorting the array into size order, and limiting to the total number of files that will exist in the prefetch slots at one time (picking the largest files)
MEMORY_CALC="0"                                                                                 # Setting initial variable to a value of "0" in preparation for iterative capacity calculations
for FSC in ${SFS[*]}; do MEMORY_CALC=$(( ${MEMORY_CALC} + ${FSC} )); done                       # FSC = File Size, Calculation: Loop through the values stored in the SFS array and combine them into MEMORY_CALC, to get a single accumulative figure 
}

func_catching_errors_second() {
echo -e "\nFunction invoked to catch errors:"
(( (${SYSTEM_CORES} % 2) != 0 ))         &&  echo -e "*** ERROR:\tOdd number of cores detected (we need even): ${SYSTEM CORES}"                                                                                        &&  TERMINATE="true"
[[ ${USABLE_CORES} -lt "2" ]]            &&  echo -e "*** ERROR:\tLess than 2 CPU cores detected (we need more): ${USABLE_CORES}"                                                                                      &&  TERMINATE="true"
[[ ${FREE_MEMORY} -lt ${MEMORY_CALC} ]]  &&  echo -e "*** ERROR:\tNot enough memory to prefetch files:\n\t\t\tAvailable:\t$(( (${FREE_MEMORY}/1024)/1024 ))GB\n\t\t\tRequired:\t$(( (${MEMORY_CALC}/1024)/1024 ))GB"   &&  TERMINATE="true"
[[ ! -f ${PROCESS_FILE_LIST} ]]          &&  echo -e "*** ERROR:\tInput file path provided cannot be enumerated: ${PROCESS_FILE_LIST}"                                                                                 &&  TERMINATE="true"
[[ ! -x $(command -v rsync) ]]           &&  echo -e "*** ERROR:\trsync is not installed or binary accesible in '$PATH' contents."                                                                                     &&  TERMINATE="true"
[[ ${PREFETCH_SLOTS} -lt "1" ]]          &&  echo -e "*** ERROR:\tNumber of prefetch slots should be 2 or more (only 1 specified)."                                                                                    &&  TERMINATE="true"
#-------------------------------------------------------------------------------------------------------------------------------------------------------#
[[ ${TERMINATE} == "true" ]]             &&  echo -e "Errors detected --- exiting...\v"  &&  exit 1  ||  echo -e "No errors detected --- continuing...\v"
}

func_create_prefetch_directories() {
[[ ! -d ${PREFETCH_DIR} ]]               &&  mkdir -p ${PREFETCH_DIR}
[[ ! -d ${PREFETCH_FILE_LIST_DIR} ]]     &&  mkdir -p ${PREFETCH_FILE_LIST_DIR}
[[ -f ${SHM_FILE_LIST} ]]                &&  \
    [[ $(cat ${SHM_FILE_LIST} | wc -l) -gt "0" ]]  &&  echo -n > ${SHM_FILE_LIST}  &&  echo -e "Contents erased from ${SHM_FILE_LIST} to create a new file list."
for CREATE_SHM_FILE_PATH in $(cat ${PROCESS_FILE_LIST})
do  
    echo ${PREFETCH_DIR}/`basename ${CREATE_SHM_FILE_PATH}` >> ${SHM_FILE_LIST}
    [[ $? != "0" ]]  &&  echo -e "\nCould not add an entry to the file list at ${SHM_FILE_LIST} - exiting..."  &&  exit 1
done
[[ -f ${SHM_FILE_LIST} ]]  &&  echo -e "File list created reflecting paths echoed into the ${SLURM_SUBMIT_DIR}/${SLURM_JOB_NAME}-${SLURM_JOBID} pipe: `echo ${SHM_FILE_LIST}`\n"
#[[ ! -p ${SLURM_SUBMIT_DIR}/${SLURM_JOB_NAME}-${SLURM_JOBID}.pipe ]]  &&  mkfifo ${SLURM_SUBMIT_DIR}/${SLURM_JOB_NAME}-${SLURM_JOBID}.pipe; echo ${SHM_FILE_LIST} > ${SLURM_SUBMIT_DIR}/${SLURM_JOB_NAME}-${SLURM_JOBID}.pipe &
}

func_prefetching() {
TIMER_START=$(date +%s)                             ## Capturing the starting second count to be used to calculate the wall time:
PROCESS_FILE_ARRAY_COUNTER="0"
while [[ ${PROCESS_FILE_ARRAY_COUNTER} -le ${PROCESS_FILE_ARRAY_LEN} ]]
do 
    PREFETCH_DIR_CONTENTS=$(find ${PREFETCH_DIR} -mindepth 1 -maxdepth 1 -not -path "*/\.*" -type f | wc -l)
    if [[ ${PREFETCH_DIR_CONTENTS} -lt ${TOTAL_PREFETCH_SLOTS} ]]
    then  
        echo -e "Prefetching file [${PROCESS_FILE_ARRAY_COUNTER}]:\t${PROCESS_FILE_ARRAY[${PROCESS_FILE_ARRAY_COUNTER}]}\t<< into >>\t${PREFETCH_DIR}/`basename ${PROCESS_FILE_ARRAY[${PROCESS_FILE_ARRAY_COUNTER}]}`"
        taskset -c 0,1 rsync -az ${PROCESS_FILE_ARRAY[${PROCESS_FILE_ARRAY_COUNTER}]} ${PREFETCH_DIR}
        ((PROCESS_FILE_ARRAY_COUNTER++))
    fi
done
TIMER_END=$(date +%s)
}

func_closure() {
TIMER_DIFF_SECONDS=$(( ${TIMER_END} - ${TIMER_START} ))
TIMER_READABLE=$(date +%H:%M:%S -ud @${TIMER_DIFF_SECONDS})	
#rm ${SLURM_SUBMIT_DIR}/${SLURM_JOB_NAME}-${SLURM_JOBID}.pipe
echo -e "\v${SLURM_JOB_NAME}-${SLURM_JOBID} prefetching complete: ${PROCESS_FILE_ARRAY_COUNTER} files were proactively brought into system memory on $(hostname).\v"
echo -e "Date:\t\t\t`date "+%a %d %b %Y"`\nTransfer wall time:\t${TIMER_READABLE}\n"
}

## Collecting specified execution parameters:
while getopts ":hn:s:i:" OPTION
do case "$OPTION"
in
#   n)  JOB_NAME=${OPTARG} ;;                       ## ((Removing custom name for prefetch job --- instead taking the overall Slurm job name from the env variable))
#   p)  PROCESS_SLOTS=${OPTARG} ;;                  ## ((Configurable number of process slots is omitted for now))
    s)  PREFETCH_SLOTS=${OPTARG} ;;
	i)  PROCESS_FILE_LIST=${OPTARG} ;;
    h | *)  func_help  &&  exit 1 ;;			    ## Capturing all other input; providing the func_help() statement for non-ratified inputs
esac
done

## Running the program:
func_catching_errors_first           # First step:      Checks that necessary options have been provided at the command line. ((Could look at moving these checks to within getopts?))
func_collect_system_info             # Second step:     Capture system information and state allowing for the error catching to run. Also creates a new file list to reflect the file paths in shared memory.
func_memory_calculation              # Third step:      Evaluate whether the system has sufficient system memory to prefetch and store the 'n' largest files in the file list. This evaluation feeds into the following function.
func_catching_errors_second          # Fourth step:     Run a series of checks to ensure that the program can run and conditions allow for its execution to complete successfully. If not, the function will trigger an exit from the program.
func_create_prefetch_directories     # Fifth step:      Assuming no errors are detected, the program will create the prefetch cache directory structure in system memory. 
func_prefetching                     # Sixth step:      Invoking the loop to check the number of files in the prefetch cache '${PREFETCH_DIR}', and copy files into it if it falls beneath the '${PREFETCH SLOTS}' value.
func_closure                         # Seventh step:    The above loop will run until the number of files transferred exceeds the number of elements in the ${PROCESS_FILE_LIST}, and print this program completion statement.