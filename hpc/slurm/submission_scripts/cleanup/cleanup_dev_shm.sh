#!/bin/bash

# Cleaning up all items a user owns from shared memory

function setup_env() {
	SELECT_DIRECTORY="/dev/shm"
	SELECT_USER="${USER}"

	echo "Date	: $(date)"
	echo "Path	: ${SELECT_DIRECTORY}"
        echo "Owner	: ${SELECT_USER}"
        echo "Total	: $(find ${SELECT_DIRECTORY} -user ${SELECT_USER} | wc -l)"
}

function delete_contents() {
	echo ">>> Deleting items"
	find ${SELECT_DIRECTORY} -user ${SELECT_USER} -delete
	
	echo
	echo "Remaining items	: $(find ${SELECT_DIRECTORY} -user ${SELECT_USER} | wc -l)"
}

#-----------------------------------------------------------------------------------------

echo
	setup_env           2> /dev/null
echo
	delete_contents     2> /dev/null
echo