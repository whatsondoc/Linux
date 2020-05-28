#!/bin/bash
#SBATCH --job-name=parallel_find_file_list_aggregator

# APF = Aggregating Parallel Find
# To be submitted via Slurm by 'parallel_find_launcher.sh'

for APF_FILE in $(find ${PFCS_OUTPUT_DIR} -name "${PFCS_UUID}_parallel_find_unit*")
do 
    cat ${APF_FILE}
done | sort

find ${PFCS_OUTPUT_DIR} -name "${PFCS_UUID}_parallel_find_unit*" -delete