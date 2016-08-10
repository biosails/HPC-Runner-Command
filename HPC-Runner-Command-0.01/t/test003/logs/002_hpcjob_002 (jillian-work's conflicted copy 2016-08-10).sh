#!/bin/bash
#
#SBATCH --share
#SBATCH --get-user-env
#SBATCH --job-name=002_hpcjob_002
#SBATCH --output=/home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test003/logs/2016-08-10-slurm_logs/002_hpcjob_002.log
#SBATCH --cpus-per-task=12
#SBATCH --dependency=afterok:1234

cd /home/jillian/Dropbox/projects/perl/HPC-Runner-App
hpcrunner.pl execute_job \
	--procs 4 \
	--infile /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test003/logs/002_hpcjob_002.in \
	--outdir /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test003/logs \
	--logname 002_hpcjob_002 \
	--process_table /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test003/logs/2016-08-10-slurm_logs/process_table.md \
	--metastr '{"batch_index":"2/4","jobname":"hpcjob_002","total_batches":4,"batch":"002","commands":1,"total_processes":4,"tally_commands":"2-2/4"}'