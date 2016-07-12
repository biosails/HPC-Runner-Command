#!/bin/bash
#
#SBATCH --share
#SBATCH --get-user-env
#SBATCH --job-name=001_job01
#SBATCH --output=/home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test001/logs/2016-06-18-hpcrunner_logs/001_job01.log
#SBATCH --cpus-per-task=12

cd /home/jillian/Dropbox/projects/perl/HPC-Runner-App
hpcrunner.pl execute_jobs \
	--procs 4 \
	--infile /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test001/logs/001_job01.in \
	--outdir /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test001/logs \
	--logname 001_job01 \
	--process_table /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test001/logs/2016-06-18-hpcrunner_logs/process_table.md --metastr '{"job_batches":"1/3","total_batches":3,"commands":1,"batch_count":"1/3","batch":"1","jobname":"job01","total_processes":"3","command_count":"1-1"}'