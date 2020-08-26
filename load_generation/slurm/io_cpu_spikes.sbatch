#!/bin/bash
#SBATCH --job-name=IO_CPU_spiking
#SBATCH --output=<__OUTPUT_FILE_PATH__>/%x-%j.stdout
#SBATCH --error=<__OUTPUT_FILE_PATH__>/%x-%j.stderr
#
#SBATCH --ntasks=30
#SBATCH --nodes=1
#SBATCH --exclusive

IO_SRC_FILE="<__SOURCE_FILE_PATH__>"
WALL_TIME="10m"
TEST=$1

if [[ ${TEST} == "BOTH" ]]
then
	TEST="IO_and_CPU"
fi

if [[ $# != 1 ]]
then
	echo "***ERROR: Please specify an argument of either IO,  CPU or BOTH to the script. Exiting..."
	exit 1
fi

if [[ "${TEST}" != "IO" && "${TEST}" != "CPU" && "${TEST}" != "IO_and_CPU" ]]
then
	echo "***ERROR: Please specify an argument of either IO,  CPU or BOTH to the script. Exiting..."
	exit 1
fi 

echo -e "\nJob details:
-- Wall time:\t\t\t${WALL_TIME}
-- Performing spikes:\t\t${TEST}"
if [[ ${TEST} != "CPU" ]]
then
    echo -e "-- IO Source file:\t\t${IO_SRC_FILE}"
fi

echo
echo "Unleashing the spikes:"
echo

srun ./io_cpu_spikes.sh ${TEST} ${IO_SRC_FILE} ${WALL_TIME}

wait

echo -e "\nJob finished\n"