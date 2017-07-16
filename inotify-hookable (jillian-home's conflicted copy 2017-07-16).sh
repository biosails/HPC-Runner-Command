#!/usr/bin/env bash

export DEV='DEV'



inotify-hookable \
    --watch-directories lib \
    --watch-directories t \
    --watch-files t/test_class_tests.t \
    --on-modify-command "rsync -avz './' 'gencore@dalma.abudhabi.nyu.edu:/home/gencore/hpcrunner-test/HPC-Runner-Command/';   prove -l -v t/test_class_tests.t"
