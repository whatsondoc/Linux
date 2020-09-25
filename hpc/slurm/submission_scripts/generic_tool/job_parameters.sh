#-----------------------------------------#
#  Generic Tool Launcher: Parameter File  #
#-----------------------------------------#

## CUSTOM_VARIABLES:

    export GTL_TOOL="/full/path/to/location/to/invoke_tool.bin"             # Path to the tool being used

    export GTL_FILE_LIST="/full/path/to/location/of/input/file_list.txt"    # Path to the file list that will be used as input

    export GTL_WORKING_DIR="/path/to/shared/working/output/directory"       # Where artifacts will be created and stored during the job execution

    export GTL_RANGE="100"                                                  # How wide should the jobs be parallelised? i.e. how many individual processing loops should be launched. Take into account the wall time per individual process.

    export GTL_SCHEDULER="Slurm|PBS"                                        # Specify either 'Slurm' or 'PBS' (case insensitive) to ensure the script creates the relevant job submission command
    export GTL_SCHEDULER_EXTRA_ARGS=""                                      # If particular scheduler flags are needed, such as working in a specific directory (to save setting library paths) or choosing a specific queue/partition

    #export GTL_ANY_OTHER_NECESSARY_ENV_VAR_A="ABC123"
    #export GTL_ANY_OTHER_NECESSARY_ENV_VAR_B="DEF456"
    #export GTL_ANY_OTHER_NECESSARY_ENV_VAR_C="GHI789"

    # Used to create affinity between the process being invoked and the underlying hardware resources (processor and memory NUMA nodes):
    export GTL_NUMA_ENABLED="ENABLED"                                       # Omit this variable (commenting out, or leaving blank), or edit the value to anything other than "ENABLED" to disable resource affinity via numactl.

## TOOL_COMMAND:

    # Associated elements used in this section are:
    #   ${GTL_INPUT_FILE}               <--- Used in for loop to cycle through individual lines in a job's individual file list
    #   ${GTL_WORKING_DIR_BASE_LOG}     <--- A storage location where tool/process log files can be written
    #   ${GTL_SCRATCH_TASK_DIR}         <--- A scratch storage location where temporary files used for/by each specific task can be stored - will be deleted after the task terminates

    # Add additional variables, substitutions etc. to this function to specifically manipulate strings to work with the tool being used:

    GTL_OUTPUT="$(dirname ${GTL_INPUT_FILE})/$(basename ${GTL_INPUT_FILE} | cut -f1 -d '.')_OUTPUT.dat"
    GTL_OUTPUT_LOG="${GTL_TEMP_LOG}/$(basename ${GTL_INPUT_FILE} | cut -f1 -d '.').log"

    export GTL_TOOL_COMMAND="
        ${GTL_TOOL}
                --input         ${GTL_INPUT_FILE}
                --output        ${GTL_OUTPUT}
                --output-log    ${GTL_OUTPUT_LOG}
                --custom-port   12345 \
                --custom-flag   update_database
        "                                                                   # The double quote (") on this line determines the closure of the GTL_TOOL_COMMAND, and should be left in tact.