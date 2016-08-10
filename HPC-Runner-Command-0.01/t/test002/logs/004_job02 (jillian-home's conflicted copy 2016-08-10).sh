#!/bin/bash
#
#SBATCH --share
#SBATCH --get-user-env
#SBATCH --job-name=004_job02
#SBATCH --output=/home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test002/logs/2016-08-10-slurm_logs/004_job02.log
#SBATCH --cpus-per-task=12
#SBATCH --dependency=afterok:1234:1234

cd /home/jillian/Dropbox/projects/perl/HPC-Runner-App
hpcrunner.pl execute_job \
	--procs 4 \
	--infile /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test002/logs/004_job02.in \
	--outdir /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test002/logs \
	--logname 004_job02 \
	--process_table /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test002/logs/2016-08-10-slurm_logs/process_table.md \
	--metastr '{"tally_commands":"4-4/4","jobname":"job02","commands":1,"total_batches":4,"batch_index":"4/4","total_processes":4,"batch":"004"}'