#!/bin/bash
#
#SBATCH --share
#SBATCH --get-user-env
#SBATCH --job-name=002_job01
#SBATCH --output=/home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test001/logs/2016-06-18-hpcrunner_logs/002_job01.log
#SBATCH --cpus-per-task=12

cd /home/jillian/Dropbox/projects/perl/HPC-Runner-App
hpcrunner.pl execute_jobs \
	--procs 4 \
	--infile /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test001/logs/002_job01.in \
	--outdir /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test001/logs \
	--logname 002_job01 \
	--process_table /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test001/logs/2016-06-18-hpcrunner_logs/process_table.md --metastr '{"command_count":"2-2","total_processes":"3","total_batches":"3","batch_count":"2/3","batch":"2","job_batches":"2/3","commands":1,"jobname":"job01"}'