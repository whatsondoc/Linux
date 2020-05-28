#!/bin/bash

# Parallel find array submission
# To be submitted as part of a job array from 'parallel_find_launcher.sh'

PFCS_PARALLEL_DIRS=( $(find ${PFCS_ROOT_PATH} -maxdepth ${PFCS_PATH_DEPTH} -mindepth ${PFCS_PATH_DEPTH} -type d -not -path "*.Trash*" 2> /dev/null) )

numactl --physcpubind=$(( ${SLURM_ARRAY_TASK_ID} % 32 )) --membind=$(( ${SLURM_ARRAY_TASK_ID} % 2 )) \
    find ${PFCS_PARALLEL_DIRS[${SLURM_ARRAY_TASK_ID}]} -type f \( -name "*<PATTERN_1>*" -or -iname "*<PATTERN_2>*" -and -iname "*<PATTERN_3>*" \) \( -not -name "*<PATTERN_4>*" \) 2> /dev/null