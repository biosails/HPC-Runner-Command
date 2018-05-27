#!/usr/bin/env bash
#
#SBATCH --share
#SBATCH --job-name=001_job001
#SBATCH --output=/Users/jillian/Dropbox/projects/HPC-Runner-Libs/New/HPC-Runner-Command/hpc-runner/2018-05-13T13-28-31/logs/000_hpcrunner_logs/001_job001.log
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --ntasks-per-node=1
#SBATCH --mem=10GB
#SBATCH --time=00:20:00
#SBATCH --array=1-5:1


hpcrunner.pl execute_array \
	--infile /Users/jillian/Dropbox/projects/HPC-Runner-Libs/New/HPC-Runner-Command/hpc-runner/2018-05-13T13-28-31/scratch/000_job001.in \
	--basedir /Users/jillian/Dropbox/projects/HPC-Runner-Libs/New/HPC-Runner-Command/hpc-runner/2018-05-13T13-28-31 \
	--commands 1 \
	--batch_index_start 1 \
	--procs 1 \
	--logname 001_job001 \
	--data_dir /Users/jillian/Dropbox/projects/HPC-Runner-Libs/New/HPC-Runner-Command/hpc-runner/2018-05-13T13-28-31/logs/000_hpcrunner_logs/stats \
	--process_table /Users/jillian/Dropbox/projects/HPC-Runner-Libs/New/HPC-Runner-Command/hpc-runner/2018-05-13T13-28-31/logs/000_hpcrunner_logs/001-task_table.md \
	--metastr '{"jobname":"job001","commands":1,"job_tasks":"5","task_index_start":"0","job_cmd_start":"0","array_end":"5","batch":"001","total_jobs":3,"array_start":"1","task_index_end":4,"total_processes":16,"job_counter":"001","total_batches":9}' \
	--version hpcrunner-0.01