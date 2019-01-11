#!/bin/bash

## Checking the POSIX permissions scheme on storage clusters

## Invoke this script after completing the global variables, then issue with:
## user$node:/dir> ./general-test-posix.sh directory1 directory2 directory3

test_posix() 
{

# Global function variables:
BDIR="<BASE_MOUNT_DIR>"         # Base DIRectory of the mounted remote filesystem.  
TFN="TEST_FILE.NULL"            # Test File Name
STORAGE="<STORAGE_NAME>"        # Name of the storage cluster. Also used to limit mounted filesystems report

# Capturing number of user defined inputs:
INPUT_NUM="${#}"
INPUT_VAL="${@}"

# Start date:
echo -e "\n\nStarting script at: `date`\n\n"

# Listing mounted $STORAGE directories:
echo -e "Listing mounted ${STORAGE} directories:\n"
df -h | grep "Filesystem" | head -1; df -h | grep "${STORAGE}"

# Local user:
echo -e "\n\n**********"
echo -e "\n\nLocal user is: `whoami`\n\n"

for FS in {1..4}                # Modify the parameter range if needed, else set the BDIR variable correctly and possibly remove this outer loop. It's purpose is to test multiple filesystems for the same directory structures.
do
	echo -e "\n\n-----------------------------------------------------------------"
	echo -e "Testing access to ${INPUT_VAL} on: ${BDIR}$FS\n"
	
	for dir in ${INPUT_VAL}
	do
		echo -e "Working directory: $dir"
		echo -e "\nListing: "
		ls ${BDIR}$FS/$dir
	
		echo -e "\nChanging to: "
		cd ${BDIR}$FS/$dir
		if [ $? -eq 0 ]
		then
			pwd
		fi
	
		cd - # Returning home to avoid issues if cd is denied due to permissions...
	
		echo -e "\nWriting to: "
		touch ${BDIR}$FS/$dir/${TFN}
	
		if [ -f ${BDIR}$FS/$dir/${TFN} ]
		then
			echo "Writing a test file to this directory succeeded"
			rm ${BDIR}$FS/$dir/${TFN}
		fi
	done
done

# Returning to local user:
exit

# End date:
echo -e "\n\nEnding script at: `date`\n\n"

}

test_posix 2>&1 | tee -a test-posix.output