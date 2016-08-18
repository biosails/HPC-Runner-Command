#!/usr/bin/env bash

inotify-hookable \
    --watch-directories lib \
    --watch-directories t/lib/TestsFor/ \
    --on-modify-command "prove -v t/test_class_tests.t"
