#!/bin/bash
#
#SBATCH --share
#SBATCH --get-user-env
#SBATCH --job-name=002_hpcjob_002
#SBATCH --output=/home/jillian/Dropbox/projects/perl/HPC-Runner-Command/t/test003/hpc-runner/logs/2016-08-17-slurm_logs/002_hpcjob_002.log
#SBATCH --cpus-per-task=12
#SBATCH --dependency=afterok:1234

cd /home/jillian/Dropbox/projects/perl/HPC-Runner-Command/t/test003
hpcrunner.pl execute_job \
	--procs 4 \
	--infile /home/jillian/Dropbox/projects/perl/HPC-Runner-Command/t/test003/hpc-runner/scratch/002_hpcjob_002.in \
	--outdir /home/jillian/Dropbox/projects/perl/HPC-Runner-Command/t/test003/hpc-runner/scratch \
	--logname 002_hpcjob_002 \
	--process_table /home/jillian/Dropbox/projects/perl/HPC-Runner-Command/t/test003/hpc-runner/logs/2016-08-17-slurm_logs/001-process_table.md \
	--metastr '{"jobname":"hpcjob_002","total_processes":4,"commands":1,"tally_commands":"2-2/4","batch":"002","batch_index":"2/4","total_batches":4}'