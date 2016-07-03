#!/bin/bash
#
#SBATCH --share
#SBATCH --get-user-env
#SBATCH --job-name=001_job01
#SBATCH --output=/home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test002/logs/2016-06-22-slurm_logs/001_job01.log
#SBATCH --cpus-per-task=12

cd /home/jillian/Dropbox/projects/perl/HPC-Runner-App
hpcrunner.pl execute_jobs \
	--procs 4 \
	--infile /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test002/logs/001_job01.in \
	--outdir /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test002/logs \
	--logname 001_job01 \
	--process_table /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test002/logs/2016-06-22-slurm_logs/process_table.md --metastr 'null'