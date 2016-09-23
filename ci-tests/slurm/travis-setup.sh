#!/usr/bin/env bash

set -e

if [[ $TRAVIS_OS_NAME = "linux" ]]
then
    docker pull jerowe/nyuad-cgsb-slurm
else

    exit 0
fi
