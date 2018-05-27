#!/usr/bin/env bash

set -x -e

echo "HELLO FROM HPCRUNNER"


sleep 20
hpcrunner.pl execute_array \
	--infile hpc-runner/2018-05-27T11-58-48/scratch/000_job001.in \
	--basedir hpc-runner/2018-05-27T11-58-48 \
	--commands 1 \
	--batch_index_start 1 \
	--procs 1 \
	--logname 001_job001 \
	--data_dir hpc-runner/2018-05-27T11-58-48/logs/000_hpcrunner_logs/stats \
	--process_table hpc-runner/2018-05-27T11-58-48/logs/000_hpcrunner_logs/001-task_table.md \
	--metastr '{"commands":1,"array_end":"5","job_cmd_start":"0","total_jobs":3,"batch":"001","task_index_end":4,"total_processes":16,"task_index_start":"0","job_tasks":"5","total_batches":9,"array_start":"1","job_counter":"001","jobname":"job001"}' \
	--version hpcrunner-0.10