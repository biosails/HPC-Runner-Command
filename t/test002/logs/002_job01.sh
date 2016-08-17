#!/bin/bash
#
#SBATCH --share
#SBATCH --get-user-env
#SBATCH --job-name=002_job01
#SBATCH --output=/home/jillian/Dropbox/projects/perl/HPC-Runner-Command/t/test002/hpc-runner/logs/2016-08-17-slurm_logs/002_job01.log
#SBATCH --cpus-per-task=12

cd /home/jillian/Dropbox/projects/perl/HPC-Runner-Command/t/test002
hpcrunner.pl execute_job \
	--procs 4 \
	--infile /home/jillian/Dropbox/projects/perl/HPC-Runner-Command/t/test002/logs/002_job01.in \
	--outdir /home/jillian/Dropbox/projects/perl/HPC-Runner-Command/t/test002/logs \
	--logname 002_job01 \
	--process_table /home/jillian/Dropbox/projects/perl/HPC-Runner-Command/t/test002/hpc-runner/logs/2016-08-17-slurm_logs/001-process_table.md \
	--metastr '{"batch":"002","commands":1,"tally_commands":"2-2/4","total_batches":4,"batch_index":"2/4","jobname":"job01","total_processes":4}'