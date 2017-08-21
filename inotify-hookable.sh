#!/usr/bin/env bash

export DEV='DEV'
RSYNC="rsync -avz ../HPC-Runner-Command gencore@dalma.abudhabi.nyu.edu:/home/gencore/hpcrunner-test/"
inotify-hookable \
    --watch-directories /home/jillian/Dropbox/projects/HPC-Runner-Libs/New/BioSAILs/lib \
    --watch-directories lib \
    --watch-directories t \
    --watch-files t/test_class_tests.t \
    --on-modify-command "prove -l -v t/test_class_tests.t"
