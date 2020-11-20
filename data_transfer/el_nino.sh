#!/bin/bash
#
# El Nino
# --> El[ectrically charged] Nostalgically Innovative Network-based Optimisation
# 
# To be used in conjunction with El Padre
#----------------------------------------------------------------------------------------------------------------------------------------------------------#
## GETOPT:
EP_GETOPT_SHORT="d:s:"
EP_GETOPT_LONG="dest:,scratch:"
OPTS=$(getopt --options ${EP_GETOPT_SHORT} --long ${EP_GETOPT_LONG} --name "getopt-parse-options" -- "${@}")
    if      (( ${?} != "0" ))
    then    echo "Failed to correctly parse the options provided - exiting ..." 
            exit 1
    fi
eval set -- "${OPTS}"
while true 
do 
    case "${1}" in
        -d | --dest )       EN_DEST=${2}            ;   shift 2 ;;
        -s | --scratch )    EN_SCRATCH_DIR=${2}     ;   shift 2 ;;

        -- )    break                               ;   shift   ;;
        *)      error "Invalid options"             ;   exit 1  ;;
  esac
done

#----------------------------------------------------------------------------------------------------------------------------------------------------------#
## RUN_TIME
EN_HOST_CORES=$(( $(nproc --all) -1 ))
EN_CORE="0"
EN_SEGMENTS_PROCESSED=()
EN_SEGMENTS_RAW=()

mkdir ${EN_SCRATCH_DIR}

until   [[ -f ${EN_SCRATCH_DIR}/EL_PADRE_COMPLETE ]]
do      EN_SEGMENTS=( $(find ${EN_SCRATCH_DIR} -name "EP_TRACK_*") )
        for     EN_SEGMENT in ${EN_SEGMENTS[*]}
        do      if      (( ${EN_CORE} > ${EN_HOST_CORES} ))
                then    EN_CORE="0"
                fi
                
                if      (( $(ps -e -o psr,cmd | awk -v aCPU=${EN_CORE} '$1==aCPU' | awk '$2=="cat"' | wc -l) == "0" ))
                then    EN_SOURCE_SEGMENTS="${EN_DEST}/$(cat ${EN_SEGMENT})_segment*"
                        EN_FINAL_FILE="${EN_DEST}/$(cat ${EN_SEGMENT})"
                        numactl --physcpubind=${EN_CORE} cat ${EN_SOURCE_SEGMENTS} > ${EN_FINAL_FILE} &
                        rm -f ${EN_SEGMENT}
                        ((EN_CORE++))
                else    continue
                fi
        done
done

wait

rm -rf ${EN_SCRATCH_DIR}