#!/bin/bash
#
#SBATCH --share
#SBATCH --get-user-env
#SBATCH --job-name=001_hpcjob_001
#SBATCH --output=/home/jillian/Dropbox/projects/perl/HPC-Runner-Command/t/test003/hpc-runner/logs/2016-08-17-slurm_logs/001_hpcjob_001.log
#SBATCH --cpus-per-task=12

cd /home/jillian/Dropbox/projects/perl/HPC-Runner-Command/t/test003
hpcrunner.pl execute_job \
	--procs 4 \
	--infile /home/jillian/Dropbox/projects/perl/HPC-Runner-Command/t/test003/hpc-runner/scratch/001_hpcjob_001.in \
	--outdir /home/jillian/Dropbox/projects/perl/HPC-Runner-Command/t/test003/hpc-runner/scratch \
	--logname 001_hpcjob_001 \
	--process_table /home/jillian/Dropbox/projects/perl/HPC-Runner-Command/t/test003/hpc-runner/logs/2016-08-17-slurm_logs/001-process_table.md \
	--metastr '{"total_processes":4,"jobname":"hpcjob_001","batch_index":"1/4","total_batches":4,"tally_commands":"1-1/4","commands":1,"batch":"001"}'