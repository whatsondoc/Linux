#===================================================================================================================================================================================================

Directory contents:
	(1) 	SlurmAnalysisSubmission.sbatch
			--> The Slurm submission script (needs completing prior to execution)

	(2)	TEAM_ScenarioAnalysis_v2-1472737_19.out
			--> An example output file from a job array element

	(3)	README.md


Intended workflow:       

  START
       \	
	|__ Edit the SlurmAnalysisSubmission.sbatch script to ensure variables are set, and all necessary application flags are in place
	|
	|__ Prepare a file list for use with the sbatch submission script 
	|	\__ Calculate the length of this file list to use with the Slurm job array indices
	|	|	\__ For example: $ cat /path/to/input/file.list | wc -l
	|	|	\__ This will return a solitary number to the terminal, e.g. 148 
	|	\__ This file list will be passed as the first positional argument to the sbatch submission script (see example below)
	|
	|__ Submit the job array (with file list) via Slurm, as per the example below
	|
	|__ COMPLETE


Example submission:
	$ sbatch --array=0-147 SlurmAnalysisSubmission.sbatch /path/to/input/file.list

Notes/Caveats:
	- This has been written to be executed via Slurm
	- If the script will be executed on a different hardware platform, it may be necessary to review the numactl section to ensure computational resources are being used, and used effectively.
	– The sbatch submission script, as is, assumes a compute node hardware layout with 2 numa domains.
