#!/usr/bin/env bash

export DEV='DEV'
RSYNC="rsync -avz ../HPC-Runner-Command gencore@dalma.abudhabi.nyu.edu:/home/gencore/hpcrunner-test/"
inotify-hookable \
    --watch-directories lib \
    --watch-directories t \
    --watch-files t/test_class_tests.t \
    --on-modify-command "${RSYNC}; prove -l -v t/test_class_tests.t"
