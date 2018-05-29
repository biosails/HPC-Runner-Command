#!/usr/bin/env bash 

##This script is meant to be used with AWS cloud
set -x -e
env

#echo "ARGS PASSED"
#echo "$@"
#
#SYNC_DIR=$1
#RUN=$2

#         {
#            "value" : "hpcrunner-bucket/2018-05-29T11-45-16",
#            "name" : "HPCRUNNER_S3_LOGS"
#         },
#         {
#            "value" : "hpc-runner/2018-05-29T11-45-16",
#            "name" : "HPCRUNNER_LOCAL_LOGS"
#         },
#         {
#            "value" : "hpc-runner/2018-05-29T11-45-16/scratch/001_job001.sh",
#            "name" : "HPCRUNNER_JOB_FILE"
#            }

#mkdir -p hpc-runner/`basename $1`
mkdir -p $HPCRUNNER_LOCAL_LOGS
#aws s3 sync $1 hpc-runner/`basename $1`
aws s3 sync $HPCRUNNER_S3_LOGS $HPCRUNNER_LOCAL_LOGS

#chmod 777 $RUN
chmod 777 $HPCRUNNER_JOB_FILE

#exec "${RUN}"

exec "${HPCRUNNER_JOB_FILE}"

echo "DONE"

##This has to go in the hpcrunner
aws s3 sync hpc-runner/`basename $1` $1
