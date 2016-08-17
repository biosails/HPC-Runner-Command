#!/bin/bash
#
#SBATCH --share
#SBATCH --get-user-env
#SBATCH --job-name=001_job01
#SBATCH --output=/home/jillian/Dropbox/projects/perl/HPC-Runner-Command/t/test002/hpc-runner/logs/2016-08-17-slurm_logs/001_job01.log
#SBATCH --cpus-per-task=12

cd /home/jillian/Dropbox/projects/perl/HPC-Runner-Command/t/test002
hpcrunner.pl execute_job \
	--procs 4 \
	--infile /home/jillian/Dropbox/projects/perl/HPC-Runner-Command/t/test002/logs/001_job01.in \
	--outdir /home/jillian/Dropbox/projects/perl/HPC-Runner-Command/t/test002/logs \
	--logname 001_job01 \
	--process_table /home/jillian/Dropbox/projects/perl/HPC-Runner-Command/t/test002/hpc-runner/logs/2016-08-17-slurm_logs/001-process_table.md \
	--metastr '{"jobname":"job01","total_processes":4,"tally_commands":"1-1/4","commands":1,"batch":"001","batch_index":"1/4","total_batches":4}'