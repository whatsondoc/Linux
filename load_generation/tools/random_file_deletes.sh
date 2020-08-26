#!/bin/bash

## Enter 'YES_I_AM' below to confirm you are ready for data to be deleted from the specified directory ##
ARE_YOU_SURE="NO_I_AM_NOT"                      
## Enter 'YES_I_AM' above to confirm you are ready for data to be deleted from the specified directory ##

## User-defined variables:
DELETION_SOURCE=$1                              # Directory path from where data will be deleted from
PERCENTAGE_DELETE=$2                            # Specify a figure between 1-100 to define the 
DELETION_TYPE="random"                          # Enter 'sequential' or 'random' to define the method of deleting files

#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
#                                                                               SCRIPT BLOCK                                                                                #
#                                           YOU SHOULD NOT NEED TO CHANGE ANYTHING FROM HERE-ON IN (UNLESS YOU PARTICULARLY WANT TO)                                        #
#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------#

## // A function to capture errors, containing 8 steps:
error_captures() {
## 1.) Checking that 2 arguments have been passed to the script:
if [[ ${NUMBER_ARGS} != 2 ]]
then 
    echo -e "\nERROR:\tIncorrect number of arguments provided.\n\n\tPlease execute the script with a directory path to the files and a (whole) percentage number of those files to be deleted (in that order):"
    echo -e "\n\t\t$ /path/to/script.sh /path/to/deletion/source 60\v"
    exit 1
fi

## 2.) Checking the target directory path from the first argument exists/is accessible:
if [[ ! -d ${DELETION_SOURCE} ]]
then
    echo -e "\nERROR:\tDeletion source directory does not exist."
    TERMINATE="true"
fi

## 3.) Checking to see whether the input included a percentage symbol:
PCT_SYMBOL=$(echo ${PERCENTAGE_DELETE: -1})
## If so, let's remove the symbol and just leave the integer:
if [[ ${PERCENTAGE_DELETE} == '%' ]]
then 
	PERCENTAGE_DELETE=$(echo ${PERCENTAGE_DELETE:0:-1})
fi

## 4.) Checking the input number is an integer:
if ! ((${PERCENTAGE_DELETE})) 2> /dev/null 
then
    echo -e "\nERROR:\tThe value set for the Percentage Delete figure is not an integer."
    TERMINATE="true"
fi

## 5.) Checking to see whether the user has specified a percentage delete value greater than 100:
if (( ${PERCENTAGE_DELETE} > 100 ))
then
    ## If so, we will adjust the value set to be 100%:
    PERCENTAGE_DELETE="100"
    echo -e "\nINFO:\tSpecified percentage figure is above 100% - setting this value to 100%."
fi

## 6.) Checking the packages required for this script to call certain commands exist on the local machine:
REQUIRED_COMMANDS=( find shuf rm )
## Looping through the array above to check that the commands can be called:
for CHECK_COMMAND in ${REQUIRED_COMMANDS[*]}
do
    if [[ ! -x $(command -v ${CHECK_COMMAND}) ]]
    then
        echo -e "ERROR:\tThe command ${CHECK_COMMAND} is either not installed or within \$PATH."
        TERMINATE="true"
    fi
done

## 7.) Making sure users are certain they are ready to proceed with the deletion script:
if [[ ${ARE_YOU_SURE} != "YES_I_AM" ]]
then
    echo -e "\vERROR:\tDeletion state is not confirmed (this needs to be set in the script) - exiting..."
    TERMINATE="true"
fi

## 8.) If any checks above have failed, we will have set the TERMINATE variable which will now trigger an exit from the script runtime:
if [[ ${TERMINATE} == "true" ]]
then
    echo -e "\vErrors detected - the script cannot execute.\v"
    exit 1
fi
}

## // A function to collect the information needed for the script to, well, function:
collect_information() {
ARRAY_ALL_FILES=( $(find ${DELETION_SOURCE} -type f) )
NUMBER_FILES=$(echo ${ARRAY_ALL_FILES[*]} | wc -w)
DELETABLE_NUMBER=$(( (${NUMBER_FILES} * ${PERCENTAGE_DELETE}) / 100 ))

echo -e "Execution information:

DATE & TIME:\t\t\t`date`
SOURCE DIRECTORY:\t\t${DELETION_SOURCE}
SOURCE FILE COUNT:\t\t${NUMBER_FILES}
PERCENTAGE DELETE:\t\t${PERCENTAGE_DELETE}
DELETE FILE COUNT:\t\t${DELETABLE_NUMBER}
DELETION METHOD:\t\t${DELETION_TYPE}

${USER} has provided confirmation for this script to go ahead: ${ARE_YOU_SURE}"
}

## // A function to initiate deletes using a random deletion method:
random_deletion() {
## Creating a variable array to keep track of the randomly generated nunbers, and the counter from which we will... 
## ...count down from (the number of files that are to be deleted):
declare -a DELETE_LOG
DELETABLE_TRACKER=${DELETABLE_NUMBER}
LAST_ELEMENT=$(( ${NUMBER_FILES} - 1 ))

## Looping back from top of the downward-counter:
until [[ ${DELETABLE_TRACKER} == "0" ]]
do
    ## Generate a random number between the first and last element in the array: 
    DELETE_STATE=$(shuf -i 0-${LAST_ELEMENT} -n 1)
    ## If this number hasn't already been generated: 
    if ! $(echo ${DELETE_LOG[*]} | grep ${DELETE_STATE} > /dev/null)
    then
        ## Trigger a deletion of the file at that element position as a background process:
            ## >> (Add a check to verify the deletion was successful?)
        rm ${ARRAY_ALL_FILES[${DELETE_STATE}]} &
        ## Add the element number to the delete log:
        DELETE_LOG[${#DELETE_LOG[@]}]="${DELETE_STATE}"
        ## Reduce the tracker by one:
        ((DELETABLE_TRACKER--))
    fi
done
}

## // A function to initiate deletes in a sequential fashion:
sequential_deletion() {
## Simply running through the eligible number of files to be deleted in sequence, starting from 0.
    ## >> (Add support for starting position through the file array?)
for SEQ_DEL_FILE in $(seq 0 ${DELETABLE_NUMBER})
do
    ## Trigger the deletion as a background process:
        ## >> (Add a check to verify the deletion was successful?)
    rm ${ARRAY_ALL_FILES[$SEQ_DEL_FILE]} &
    ## Holding briefly, given the number of processes that could be created in quick succession:
    sleep 0.05
done
}

## Collecting the number of arguments passed to the script:
NUMBER_ARGS=$#
echo
## Calling the functions:
error_captures
collect_information
${DELETION_TYPE}_deletion

## Prevent the script from terminating unfinished background processes:
echo -e "\nAll delete operation requests submitted: waiting for completion..."
wait

echo -e "\nDeletion job complete.\v"