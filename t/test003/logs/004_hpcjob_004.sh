#!/bin/bash
#
#SBATCH --share
#SBATCH --get-user-env
#SBATCH --job-name=004_hpcjob_004
#SBATCH --output=/home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test003/logs/2016-07-13-slurm_logs/004_hpcjob_004.log
#SBATCH --cpus-per-task=12
#SBATCH --dependency=afterok:1234

cd /home/jillian/Dropbox/projects/perl/HPC-Runner-App
hpcrunner.pl execute_job \
	--procs 4 \
	--infile /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test003/logs/004_hpcjob_004.in \
	--outdir /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test003/logs \
	--logname 004_hpcjob_004 \
	--process_table /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test003/logs/2016-07-13-slurm_logs/process_table.md --metastr '{"commands":1,"tally_commands":"4-4/4","total_batches":4,"total_processes":4,"batch":"004","jobname":"hpcjob_004","batch_index":"4/4"}'