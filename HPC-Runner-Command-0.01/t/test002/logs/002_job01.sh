#!/bin/bash
#
#SBATCH --share
#SBATCH --get-user-env
#SBATCH --job-name=002_job01
#SBATCH --output=/home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test002/logs/2016-08-10-slurm_logs/002_job01.log
#SBATCH --cpus-per-task=12

cd /home/jillian/Dropbox/projects/perl/HPC-Runner-App
hpcrunner.pl execute_job \
	--procs 4 \
	--infile /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test002/logs/002_job01.in \
	--outdir /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test002/logs \
	--logname 002_job01 \
	--process_table /home/jillian/Dropbox/projects/perl/HPC-Runner-App/t/test002/logs/2016-08-10-slurm_logs/process_table.md \
	--metastr '{"jobname":"job01","batch_index":"2/4","batch":"002","total_batches":4,"total_processes":4,"commands":1,"tally_commands":"2-2/4"}'