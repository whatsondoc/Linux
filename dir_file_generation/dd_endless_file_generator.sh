#!/bin/bash

## Variables:
ourlog="/tmp/FileGenerator.output"          # The directory path of the log file for this script operation
tgtdir="/path/to/target/directory"          # In which directory path should we create the directories & files
small_file_size="1"                         # Smallest file size
large_file_size="1024"                      # Largest file size
block_size="4k"                             # Block size
compressability="zero"                      # Either 'urandom' or 'zero'

if [[ $(command -v shuf) ]]
then
    echo "We need shuf - exiting..."
    exit 1
fi

## Logging input options:
echo "
________________________________________________________________________
 VARIABLE                               | VALUE
----------------------------------------|-------------------------------
 Target Mount Point directory           | ${tgtdir}
 Smallest file to be created (in KB)    | ${small_file_size}
 Largest file to be created (in KB)     | ${large_file_size}
 Compressability                        | ${compressability}
 Block size set for dd command          | ${block_size}
________________________________________________________________________

"

## Endless file creation starts here:

USE_DIR="${tgtdir}/file_black_hole_directory-${RANDOM}"
mkdir -p ${USE_DIR} 

while true
    do 
    size=$(( $(shuf -i ${small_file_size}-${large_file_size} -n 1) / 64 ))
    for i in {0..24}
    do
            dd if=/dev/${compressability} of=${USE_DIR}/${RANDOM}-file_gen-${file_count} bs=${block_size} count=${size} status=none &
    done

	wait
done

echo -e "\vJob complete...........Have we really managed to create all the potential files in the entire realm of possibility?!?!?"