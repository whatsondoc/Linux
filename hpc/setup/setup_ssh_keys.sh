#!/bin/bash

NODE_LIST="/path/to/node/list.txt"

SSH_DIR="${HOME}/.ssh"
SSH_KEY_NAME="ssh_keys"

# Checking whether the node list and ssh directory paths exist:
[[ ! -f ${NODE_LIST} ]]  &&  echo "The file path in \${NODE_LIST} cannot be enumerated - does a file exist there?"  &&  exit 1
[[ ! -d ${SSH_DIR} ]]  &&  echo "The directory path in \${SSH_DIR} cannot be enumerated - does a directory exist there?"  &&  exit 1

# Checking the required packages exist on this system:
GENERAL_SCRIPT_COMMANDS=( sshpass scp tar )
for CHECK_COMMAND in ${GENERAL_SCRIPT_COMMANDS[*]}
    do
        which ${CHECK_COMMAND} 2> /dev/null  1> /dev/null
        if [[ $? != "0" ]]
        then
            echo "Package not present: ${CHECK_COMMAND}"
            export PACKAGE_NOT_PRESENT="TRUE"
        fi
    done

if [[ -n ${PACKAGE_NOT_PRESENT} ]]
then
    echo
    echo "Please ensure the above packages are available on the system and accessible via \${PATH}"
    exit 1
fi

echo "
Node    :  ${HOSTNAME}
Date    :  $(date)
"

# Prompt user to supply (silently) the password needed to connect to remote machines:
read -s -p "Password to connect to remote nodes: " SETUP_SSH_NODE_PASSWORD
echo
if [[ -n ${SETUP_SSH_NODE_PASSWORD} ]]
then
    read -p "Password stored. Press enter to continue: [ENTER]"
    echo
else
    echo "Password was not stored as required..."
    exit 1
fi

# Generate a ssh keypair, and compress into a tarball:
ssh-keygen -q -t rsa -N "" -f ${SSH_DIR}/${SSH_KEY_NAME}

# Loop through the nodes contained in the node list, copy the ssh keypair tarball and extract it into the user's .ssh (in their home directory):
for SHARE_SSH_KEYS_TO_NODE in $(cat ${NODE_LIST})
do
    # Copying the tarball to the remote host using scp:
    sshpass -p ${SETUP_SSH_NODE_PASSWORD} scp -q -o StrictHostKeyChecking=No ${SSH_DIR}/${SSH_KEY_NAME}* ${USER}@${SHARE_SSH_KEYS_TO_NODE}:${SSH_DIR}
    [[ ${?} != "0" ]]  &&  echo "** Error copying the ssh keys to                   :  ${SHARE_SSH_KEYS_TO_NODE}"

    # Extracting the ssh keys on the remote host, copying into the local authorized_keys file, and removing the tarball:
    sshpass -p ${SETUP_SSH_NODE_PASSWORD} ssh -q ${USER}@${SHARE_SSH_KEYS_TO_NODE} \
        "cat ${SSH_DIR}/${SSH_KEY_NAME}.pub >> ${SSH_DIR}/authorized_keys"
    [[ ${?} != "0" ]]  &&  echo "** Error adding the ssh key to authorized_keys     :  ${SHARE_SSH_KEYS_TO_NODE}"

    # Testing the connection using the new key:
    echo ">> Successful connection via ssh to [host]     :  $(ssh -o StrictHostKeyChecking=No -i ${SSH_DIR}/${SSH_KEY_NAME} ${USER}@${SHARE_SSH_KEYS_TO_NODE} 'hostname')"
done

# Overwriting and unsetting the variable that's stored the password (multiple times):
for CYCLE_PASS in {0..9}
do
    SETUP_SSH_NODE_PASSWORD="OVERWRITING-${CYCLE_PASS}-${RANDOM}"
    export SETUP_SSH_NODE_PASSWORD="OVERWRITING-${CYCLE_PASS}-${RANDOM}"
    unset SETUP_SSH_NODE_PASSWORD
done

echo
# All done