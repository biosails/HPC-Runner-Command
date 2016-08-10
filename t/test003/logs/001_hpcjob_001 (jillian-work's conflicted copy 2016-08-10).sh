#!/bin/bash
#
#SBATCH --share
#SBATCH --get-user-env
#SBATCH --job-name=001_hpcjob_001
#SBATCH --output=/home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test003/logs/2016-08-10-slurm_logs/001_hpcjob_001.log
#SBATCH --cpus-per-task=12

cd /home/jillian/Dropbox/projects/perl/HPC-Runner-App
hpcrunner.pl execute_job \
	--procs 4 \
	--infile /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test003/logs/001_hpcjob_001.in \
	--outdir /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test003/logs \
	--logname 001_hpcjob_001 \
	--process_table /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test003/logs/2016-08-10-slurm_logs/process_table.md \
	--metastr '{"tally_commands":"1-1/4","total_processes":4,"commands":1,"batch":"001","total_batches":4,"jobname":"hpcjob_001","batch_index":"1/4"}'