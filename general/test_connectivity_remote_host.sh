#!/bin/bash

TIMEOUT="timeout 5"
SSH_KEYPAIR="-i ~/.ssh/private_key_portion"

if 	[[ ${#} != "1" ]]
then	echo "Please provide a hosts list"
	exit 1
elif 	[[ ! -f ${1} ]]
then	echo "Cannot locate a hosts list at this location: ${1}"
	exit 1
fi

echo
echo "$(date)"
echo "Source machine name		:	$(hostname)"
echo "Source IPv4 details		: "
  ifconfig | grep inet | grep -v inet6
echo
  route -n
echo
echo "-----------------------------------------------------------------------------------------------------"
echo
echo "Number of remote hosts involved	:	$(cat ${1} | wc -l)"
echo
echo

for HOST in $(cat ${1})
do 
	echo "Remote hostname (from file)	:	${HOST}"

	REMOTE_HOST=$(${TIMEOUT} ssh -o "StrictHostKeyChecking no" -q ${SSH_KEYPAIR} ${USER}@${HOST} 'hostname')

	if      [[ ${?} != "0" ]]
        then    REMOTE_HOST="*** ERROR: Unreachable host ***"
        fi

	echo "Remote hostname (from target)	:	${REMOTE_HOST}"

	echo
done

echo "Test complete"
echo
