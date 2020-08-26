#!/bin/bash
# A script to automate the repetitive testing towards an NFS filesystem using standard Linux tooling

info() { 
	echo -e "`date "+%Y/%m/%d   %H:%M:%S"`\t[INFO]   $1" 
}
error() { 
	echo -e "`date "+%Y/%m/%d   %H:%M:%S"`\t[ERROR]  $1"
}

DD_INPUT="/dev/zero"
FILE_SIZE_GB="10"
MOUNT_TARGET_BASE="/path/to/target/mount"
FILER="filer.address.com"
EXPORT="/path/to/export/on/filer"

##################

echo
info "The mounted NFS filesystems on this node:"
echo
	df --human-readable --type=nfs
echo
info "The target base directory for this performance test is	: ${MOUNT_TARGET_BASE}"
info "Filer being mounted					: ${FILER}"
info "Export being mounted					: ${EXPORT}"
info "Size of the files being created			: ${FILE_SIZE_GB}GB"
info "dd input source					: ${DD_INPUT}"
info
info

for FS_BLOCK_SIZE in {1,65536,131072,262144,524288,1048576,2097152,4194304}
do
	info "######"
	if [[ ${FS_BLOCK_SIZE} == "1" ]]
	then
		export MOUNT="${MOUNT_TARGET_BASE}-DEFAULT"
		mkdir -p ${MOUNT}
		mount --types nfs ${FILER}:${EXPORT} ${MOUNT}
			if [[ $? != "0" ]]
			then error "The filesystem appears not to have mounted correctly - exiting..."; exit 1
			else info "Mounted ${FILER}:${EXPORT} on ${MOUNT} with default mount options"
			fi
	else
		export MOUNT="${MOUNT_TARGET_BASE}-${FS_BLOCK_SIZE}"
		mkdir -p ${MOUNT}
		mount --types nfs ${FILER}:${EXPORT} ${MOUNT} --options wsize=${FS_BLOCK_SIZE},rsize=${FS_BLOCK_SIZE}
			if [[ $? != "0" ]]
                        then error "The filesystem appears not to have mounted correctly - exiting..."; exit 1
			else info "Mounted ${FILER}:${EXPORT} on ${MOUNT} with rsize & wsize set to $(( ${FS_BLOCK_SIZE} / 1024))KB (${FS_BLOCK_SIZE} bytes)"
			fi
	fi

	for DD_BLOCK_SIZE_KB in {1,2,4,8,16,32,64,128,256,512,1024,2048,4096,8192}
	do
		BLOCK_COUNT=$(( ((${FILE_SIZE_GB} * 1024) * 1024) / ${DD_BLOCK_SIZE_KB} ))
		info "Block size (KB)	: ${DD_BLOCK_SIZE_KB}"
		info "Block count		: ${BLOCK_COUNT}"

		INDEX="0"
		REPEAT="0"
		while [[ ${REPEAT} -lt 10 ]]
		do
			TARGET_FILE="${MOUNT}/dd-FS_BS-${FS_BLOCK_SIZE}---${FILE_SIZE_GB}GB_dd-BS-${DD_BLOCK_SIZE_KB}.out.${INDEX}"
			COMMAND="time dd if=${DD_INPUT} of=${TARGET_FILE} bs=${DD_BLOCK_SIZE_KB}K count=${BLOCK_COUNT}"
			info "Command		: ${COMMAND}"
			time ${COMMAND}
			echo
			((INDEX++))
			((REPEAT++))
		done

		info "Removing test files created by dd"
		time find ${MOUNT}/ -mindepth 1 -maxdepth 1 -name "dd-FS_BS*" | xargs rm
		echo
	done
        sleep 15
		info "Unmounting ${FILER}:${EXPORT} from ${MOUNT}"
		umount ${MOUNT}
			if [[ ${?} != "0" ]]
			then error "There was an issue unmounting the filesystem"
			fi
		rmdir ${MOUNT}
		info
done
