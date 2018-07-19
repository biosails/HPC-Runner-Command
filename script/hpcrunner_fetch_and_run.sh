#!/usr/bin/env bash 

##This script is meant to be used with AWS cloud
mkdir -p $HPCRUNNER_LOCAL_LOGS
aws s3 sync $HPCRUNNER_S3_LOGS $HPCRUNNER_LOCAL_LOGS

chmod 777 $HPCRUNNER_JOB_FILE

## When I run this locally I need bash -c
## But on AWS I need exec
exec "${HPCRUNNER_JOB_FILE}"


