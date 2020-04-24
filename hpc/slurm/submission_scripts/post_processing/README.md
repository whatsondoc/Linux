#=============================================================================================================================================================================

Directory contents:
	(1)		Job_Parameters.input
			--> Parameters file which contains details of the job being undetaken

	(2) 	Launcher.sh
			--> Shell script to setup the job framework

	(3) 	Executor.sh
			--> Slurm sbatch submission script to run on a core on the executing node

	(4) 	Cleanup.sh
			--> Shell script to tidy up after all job elements have terminated

	(5)		README.md


Intended workflow:       

START
   \
	|__ Edit and complete the Job_Parameters.input (1) file to provide necessary details for the job	
	|
	|__ Invoke Launcher.sh (2) from terminal, ensuring that the Job_Parameters.input (1) is fully edited and in the same working directory
	| 	\_ The script will export variables (as set by the user prior to invocation) and perform a login to Docker_Repo
	|	\_ User enters COMPANY password to login to Docker_Repo on the terminal (do not submit this as a background task)
	|
	|__ Launcher.sh (2) will build and submit a Slurm job array
	|	\_ A job dependency is submitted for execution after all job array elements complete, which will call Cleanup.sh (4)
	|
	|__ The job array elements will call the Executor.sh (3) and perform the processing on the segment(s) specified in the file list (as defined in the Job_Parameters.input file)
	|	\_ Each array element processes one segment
	|
	|__ Once all job array elements have completed, the Cleanup job dependency will run to tidy up (removing scratch directories
	|
	|___ COMPLETE


Example submission:
	$ vi /path/to/Job_Parameters.input			#<< Edit and complete the sections in this parameters file

	$ chmod +x /path/to/Launcher.sh				#<< Add executable permissions to the script

	$ /path/to/Launcher.sh						#<< Execute the script


Notes/Caveats:
	- This has been written to be executed via Slurm
	- Some validation will need to be made to ensure the Launcher.sh, Execution.sh and Cleanup.sh scripts are correctly calling the application(s)/program(s)/script(s)

	- These scripts should be run on machines that use English as the operating language
