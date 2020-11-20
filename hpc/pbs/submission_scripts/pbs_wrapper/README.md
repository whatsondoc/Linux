#-- RELEASE NOTES:
#
#   --> Version 0.9: September 2020
#   * Options
#       - Supports arguments passed via CLI or via a Job Parameters file. Submitting commands at the CLI will overrule Job Parameters
#       - The wrapper simply requires the tool command & file list to be provided as options, either at the CLI or in the Job Parameters file
#       - The '-x' flag allows users to send extra arguments to the PBS scheduler, should they wish to specify a queue, e.g. "-q gpuq"
#       - Verbose mode prints extra information & enables 'set -x'
#       - Debug mode enables verbose mode, and also prefixes all commands with 'strace -d -t'
#   * Scheduler
#       - Only supports PBS as a job scheduler
#       - Creates job arrays to the length of each namespace input file
#       - One task per array element (linked to work required)
#   * Input
#       - Supports both file paths and IDs as input
#       - The wrapper will query a database to resolve file paths from IDs
#       - The resolved file paths will be separated out for submission to the specific firezones that are visible to the Launcher at that point 
#   * Execution
#       - The wrapper will validate all inputs to ensure obvious failure conditions are avoided by exiting gracefully
#       - Functional variables for the execution environment are set programmatically, and directory structure created for logs & artifacts
#       - Input is parsed, prepared and submitted along with the command to the scheduler
#       - Details printed to the terminal from the Launcher are stored with the remainder of the job logs
#       - The same script runs in Executor mode on the compute node as part of the job, executing the specific tool command on the file list
#
#   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   #
#
#-- REQUIRED WORK:
#   --> Add throttle toggle support for job array submissions
#   --> Develop the translation function to lookup paths from IDs
#   --> Additional error checking & validation (per function)
#   --> Add option to specify wall time, and adjust the number of executions per job array element based on this input
#   --> Detect double quote usage for '-a' command line or job parameters file
#
#-----------------------------------------------------------------------------------------------------------------------------------------------#
