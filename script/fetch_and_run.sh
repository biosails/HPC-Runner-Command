#!/usr/bin/env bash 

set -x -e
env

export SLURM_ARRAY_TASK_ID=$AWS_BATCH_JOB_ARRAY_INDEX
echo "ARGS PASSED"
echo "$@"

SYNC_DIR=$1
RUN=$2

mkdir -p hpc-runner/`basename $1`
aws s3 sync $1 hpc-runner/`basename $1`

chmod 777 $RUN
#bash -c $RUN
exec "${RUN}"

echo "DONE"

aws s3 sync hpc-runner/`basename $1` $1
