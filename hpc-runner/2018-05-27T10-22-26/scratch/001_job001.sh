#!/usr/bin/env bash

set -x -e

echo "HELLO FROM HPCRUNNER"


sleep 20
hpcrunner.pl execute_array \
	--infile hpc-runner/2018-05-27T10-22-26/scratch/000_job001.in \
	--basedir hpc-runner/2018-05-27T10-22-26 \
	--commands 1 \
	--batch_index_start 1 \
	--procs 1 \
	--logname 001_job001 \
	--data_dir hpc-runner/2018-05-27T10-22-26/logs/000_hpcrunner_logs/stats \
	--process_table hpc-runner/2018-05-27T10-22-26/logs/000_hpcrunner_logs/001-task_table.md \
	--metastr '{"jobname":"job001","total_batches":9,"job_tasks":"5","job_counter":"001","array_start":"1","task_index_start":"0","array_end":"5","total_processes":16,"commands":1,"batch":"001","total_jobs":3,"task_index_end":4,"job_cmd_start":"0"}' \
	--version hpcrunner-0.05