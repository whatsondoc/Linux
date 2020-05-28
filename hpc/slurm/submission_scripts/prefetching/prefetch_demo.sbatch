#!/bin/bash
#SBATCH --job-name=Slurm_Prefetch_Demo
#SBATCH --output=
#SBATCH --error=
#
#SBATCH --ntasks=
#SBATCH --nodes=
#SBATCH --exclusive=user

set -e
set -o pipefail

[[ $# != "1" ]]  &&  echo -e "\nPlease pass a file list as the first positional argument.\v"  &&  exit 1

# Invoking the prefetch program as a background process:
srun -n1 /path/to/prefetch_program.sh -s 15 -i $1 > /path/to/outputs/${SLURM_JOB_NAME}_${SLURM_JOB_ID}.prefetch-output &

[[ $? != "0" ]]  &&  echo "Prefetch script failed to execute cleanly - exiting..."  &&  exit 1

# Sleeping to allow the prefetching to kick-in:
sleep 60
#SHM_FILE_LIST=$(cat ${SLURM_JOB_NAME}.pipe)

# Invoking the prefetch_companion.sh script to actually do the work:
srun -n1 /path/to/scripts/prefetch_companion-copy_to_dev_null.sh $(cat ~/${SLURM_JOB_NAME}.pipe)

echo -e "\nJob complete\v"
