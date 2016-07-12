#!/bin/bash
#
#SBATCH --share
#SBATCH --get-user-env
#SBATCH --job-name=003_job01
#SBATCH --output=/home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test001/logs/2016-06-19-hpcrunner_logs/003_job01.log
#SBATCH --cpus-per-task=12

cd /home/jillian/Dropbox/projects/perl/HPC-Runner-App
hpcrunner.pl execute_jobs \
	--procs 4 \
	--infile /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test001/logs/003_job01.in \
	--outdir /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test001/logs \
	--logname 003_job01 \
	--process_table /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test001/logs/2016-06-19-hpcrunner_logs/process_table.md --metastr '{"batch":"3","jobname":"job01","total_batches":3,"command_count":"3-3","batch_count":"3/3","job_batches":"3/3","total_processes":"3","commands":1}'