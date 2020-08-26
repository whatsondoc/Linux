#!/bin/bash
#SBATCH --job-name=Multi-Threaded_directory_copy
#SBATCH --ntasks-per-node=30
#SBATCH --ntasks=65
#SBATCH --exclusive

SOURCE=$1
TARGET_BASE_DIR=$2
SOURCE_BASENAME=$(basename ${SOURCE})
TARGET="${TARGET_BASE_DIR}/${SOURCE_BASENAME}"
NPROC_MAX=$(( $(nproc) - 1 ))
NPROC_INDEX="0"

if [[ $# != 2 ]]
then
	echo -e "\v2 arguments required: source path & destination path.\n"
	exit 1
fi

DIR_SLASH=$(echo ${TARGET_BASE_DIR: -1})
if [[ ${DIR_SLASH} == '/' ]]
then 
	TARGET_BASE_DIR=$(echo ${TARGET_BASE_DIR} | sed s'/.$//')
fi

if [[ ! -d $1 ]]
then
	echo -e "\vSource path does not exist.\n"
	exit 1
fi

if [[ ! -d $2 ]]
then
	echo -e "\nTarget path does not exist - creating now..."
	mkdir -p $2
fi

if ! command -v rsync > /dev/null
then
	echo -e "\nrsync is not available on this system, or at least $PATH doesn't point to it - exiting...\n"
	exit 1
fi

TIMER_START=$(date +%s)	

echo -e "
Job Name:\t${SLURM_JOB_NAME}
Job ID:\t\t${SLURM_JOB_ID}
Hostname:\t$`hostname`
Number of tasks:\t${SLURM_NTASKS}
Number of cores:\t${SLURM_NPROCS}
Number of nodes:\t${SLURM_NNODES}
"

SRC_LV1_DIRS=( $(find ${SOURCE} -mindepth 1 -maxdepth 1 -type d) )

mkdir ${TARGET}

for LV1_DIRS in ${SRC_LV1_DIRS[*]}
do
	if [[ ${NPROC_INDEX} -gt ${NPROC_MAX} ]]
	then
		NPROC_INDEX="0"
	fi

	echo -e "Copying level 1 directory: ${LV1_DIRS}"
	srun -n1 taskset -c ${NPROC_INDEX} rsync -a ${LV1_DIRS} ${TARGET} &
	sleep 0.2
	((NPROC_BASE++))
done

echo -e "\nAll level 1 directory copy tasks submitted."

echo -e "\nCopying the files from the base directory:"
SRC_LV1_FILES=( $(find ${SOURCE} -mindepth 1 -maxdepth 1 -type f) )
for LV1_FILES in ${SRC_LV1_FILES[*]}
do
	rsync -a ${SOURCE} ${TARGET}
done

wait

echo -e "\nBase directory copied from:\t${SOURCE}"
echo -e "Target directory copied to:\t${TARGET_BASE_DIR}"
TIMER_END=$(date +%s)
TIMER_DIFF_SECONDS=$(( ${TIMER_END} - ${TIMER_START} ))
TIMER_READABLE=$(date +%H:%M:%S -ud @${TIMER_DIFF_SECONDS})
echo -e "Date:\t\t\t\t`date "+%a %d %b %Y"`\nTransfer wall time:\t\t${TIMER_READABLE}\n"
echo -e "\nJob complete. Goodbye!\v"