#!/bin/bash
#SBATCH --job-name=Parallel_Find
#SBATCH --output=/path/to/output/%A_%a.out
#SBATCH --error=/path/to/error/%A_%a.out

# Parallel find:

ROOT_PATH="/path/to/root/dir"
MAX_DEPTH="4"

#---------------------------------------------------------------------------------------------------------------------------------------------#

PF_PARALLEL_DIRS=( $(find ${PF_ROOT_PATH} -maxdepth ${PF_PATH_DEPTH} -mindepth ${PF_PATH_DEPTH} -type d -not -path "*.*" 2> /dev/null) )

numactl --physcpubind=$(( ${SLURM_ARRAY_TASK_ID} % 32 )) --membind=$(( ${SLURM_ARRAY_TASK_ID} % 2 )) \
    find ${PF_PARALLEL_DIRS[${SLURM_ARRAY_TASK_ID}]} -type f \( -name "*<PATTERN_1>*" -o -name "*<PATTERN_2>*" \) 2> /dev/null
