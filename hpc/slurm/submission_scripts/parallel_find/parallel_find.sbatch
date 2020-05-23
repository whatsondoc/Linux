#!/bin/bash
#SBATCH --job-name=Parallel_Find
#SBATCH --output=/home/bwats/parallel_find/outputs/%A_%a.out
#SBATCH --error=/home/bwats/parallel_find/outputs/%A_%a.out

# Parallel find:

ROOT_PATH="/dms/z1"
DESIRED_NAME="SOD|DMS"        # Separate specific search terms with a pipe: '|'
MAX_DEPTH="4"

PARALLEL_DIRS=( $(find ${ROOT_PATH} -maxdepth ${MAX_DEPTH} -mindepth 1 -type d 2>/dev/null) )

find ${PARALLEL_DIRS[${SLURM_ARRAY_TASK_ID}]} -type f | egrep +(${DESIRED_NAME}) 2>/dev/null