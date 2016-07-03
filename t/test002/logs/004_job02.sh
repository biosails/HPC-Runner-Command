#!/bin/bash
#
#SBATCH --share
#SBATCH --get-user-env
#SBATCH --job-name=004_job02
#SBATCH --output=/home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test002/logs/2016-06-22-slurm_logs/004_job02.log
#SBATCH --cpus-per-task=12
#SBATCH --dependency=afterok:66396641172126970633095785335727:47210697906437452990385217842068

cd /home/jillian/Dropbox/projects/perl/HPC-Runner-App
hpcrunner.pl execute_jobs \
	--procs 4 \
	--infile /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test002/logs/004_job02.in \
	--outdir /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test002/logs \
	--logname 004_job02 \
	--process_table /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test002/logs/2016-06-22-slurm_logs/process_table.md --metastr 'null'