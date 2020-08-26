#!/bin/bash

## Variables:
ourlog="/tmp/FileGenerator.output"          # The directory path of the log file for this script operation
tgtdir="/path/to/dir/for/file/creation"     # In which directory path should we create the directories & files
num_dirs="160"                              # How many directories will be created?
min_file_count="15"                         # Min number of files
max_file_count="1000"                       # Max number of files
small_file_size="1"                         # Smallest file size
large_file_size="102400"                    # Largest file size
block_size="64k"                            # Block size
compressability="urandom"                   # Either 'urandom' or 'zero'

## Logging input options:
/bin/echo "
________________________________________________________________________
 VARIABLE                               | VALUE
----------------------------------------|-------------------------------
 Target Mount Point                     | ${tgtdir}
 Number of directories                  | ${num_dirs}
 Minimum # of files per directory       | ${min_file_count}
 Maximum # of files per directory       | ${max_file_count}
 Smallest file to be created (in KB)    | ${small_file_size}
 Largest file to be created (in KB)     | ${large_file_size}
 Compressability                        | ${compressability}
 Block size set for dd command          | ${block_size}
________________________________________________________________________

"

## Directory & file creation starts here:
dir_count="1"
file_count="1"
random="$RANDOM"
procs=$(( $(nproc) - 1 ))
proc_count="0"

TIMER_START=$(date +%s)

while [[ ${dir_count} -le ${num_dirs} ]]
do
    /bin/mkdir -p ${tgtdir}/${random}-directory-${dir_count}
    num_files=$(/usr/bin/shuf -i ${min_file_count}-${max_file_count} -n 1)
    echo -e "${tgtdir}/${random}-directory-${dir_count} will be populated with ${num_files} (files of varying sizes)."

    for (( c=1; c<=${num_files}; c++ ))
    do 
        if (( $(ps -C dd --noheader | wc -l) > "100" ))
        then
            sleep 30
        fi
        
        if (( ${proc_count} == ${procs} ))
        then
            proc_count="0"
        fi

        size=$(( $(/usr/bin/shuf -i ${small_file_size}-${large_file_size} -n 1) / 64 ))
        taskset -c ${proc_count} /bin/dd if=/dev/${compressability} of=${tgtdir}/${random}-directory-${dir_count}/file-${file_count} bs=${block_size} count=${size} >> /dev/null 2>&1 &
        (( file_count ++ ))
        (( proc_count ++ ))
    done

    echo -e "Finished.\v"

(( dir_count ++ ))
done 

wait

TIMER_END=$(date +%s)
TIMER_DIFF_SECONDS=$(( ${TIMER_END} - ${TIMER_START} ))
TIMER_READABLE=$(date +%H:%M:%S -ud @${TIMER_DIFF_SECONDS})
echo
echo -e "Date:\t\t\t\t`date "+%a %d %b %Y"`\nFile creation wall time:\t\t${TIMER_READABLE}\n"

/bin/echo -e "\vJob complete."