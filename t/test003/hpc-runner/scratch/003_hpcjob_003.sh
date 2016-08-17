#!/bin/bash
#
#SBATCH --share
#SBATCH --get-user-env
#SBATCH --job-name=003_hpcjob_003
#SBATCH --output=/home/jillian/Dropbox/projects/perl/HPC-Runner-Command/t/test003/hpc-runner/logs/2016-08-17-slurm_logs/003_hpcjob_003.log
#SBATCH --cpus-per-task=12
#SBATCH --dependency=afterok:1234

cd /home/jillian/Dropbox/projects/perl/HPC-Runner-Command/t/test003
hpcrunner.pl execute_job \
	--procs 4 \
	--infile /home/jillian/Dropbox/projects/perl/HPC-Runner-Command/t/test003/hpc-runner/scratch/003_hpcjob_003.in \
	--outdir /home/jillian/Dropbox/projects/perl/HPC-Runner-Command/t/test003/hpc-runner/scratch \
	--logname 003_hpcjob_003 \
	--process_table /home/jillian/Dropbox/projects/perl/HPC-Runner-Command/t/test003/hpc-runner/logs/2016-08-17-slurm_logs/001-process_table.md \
	--metastr '{"batch_index":"3/4","total_batches":4,"tally_commands":"3-3/4","commands":1,"batch":"003","total_processes":4,"jobname":"hpcjob_003"}'