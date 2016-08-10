#!/bin/bash
#
#SBATCH --share
#SBATCH --get-user-env
#SBATCH --job-name=003_hpcjob_003
#SBATCH --output=/home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test003/logs/2016-08-10-slurm_logs/003_hpcjob_003.log
#SBATCH --cpus-per-task=12
#SBATCH --dependency=afterok:1234

cd /home/jillian/Dropbox/projects/perl/HPC-Runner-App
hpcrunner.pl execute_job \
	--procs 4 \
	--infile /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test003/logs/003_hpcjob_003.in \
	--outdir /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test003/logs \
	--logname 003_hpcjob_003 \
	--process_table /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test003/logs/2016-08-10-slurm_logs/process_table.md \
	--metastr '{"tally_commands":"3-3/4","jobname":"hpcjob_003","commands":1,"total_processes":4,"batch":"003","total_batches":4,"batch_index":"3/4"}'