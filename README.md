### project

When submitting jobs we will prepend the jobname with the project name

# NAME

HPC::Runner::Command - Create composable bioinformatics hpc analyses.

# SYNOPSIS

To create a new project

    hpcrunner.pl new MyNewProject

To submit jobs to a cluster

    hpcrunner.pl submit_jobs --infile my_submission.sh

To run jobs on an interactive queue or workstation

    hpcrunner.pl single_node --infile my_submission.sh

# DESCRIPTION

HPC::Runner::Command is a set of libraries for scaffolding data analysis projects,
submitting and executing jobs on an HPC cluster or workstation, and obsessively
logging results.

Get help by heading on over to github and raising an issue. [GitHub ](https://metacpan.org/pod/
https:#github.com-biosails-HPC-Runner-Command-issues).

Please see the complete documentation at [HPC::Runner::Command GitBooks ](https://metacpan.org/pod/
https:#jerowe.gitbooks.io-hpc-runner-command-docs-content).

# Quick Start - Create a New Project

You can create a new project, with a sane directory structure by using

        hpcrunner.pl new MyNewProject

# Quick Start - Submit Workflows

## Simple Example

Our simplest example is a single job type with no dependencies - each task is
independent of all other tasks.

### Workflow file

        #preprocess.sh

        echo "preprocess" && sleep 10;
        echo "preprocess" && sleep 10;
        echo "preprocess" && sleep 10;

### Submit to the scheduler

        hpcrunner.pl submit_jobs --infile preprocess.sh

### Look at results!

        tree hpc-runner

## Job Type Dependencency Declaration

Most of the time we have jobs that depend upon other jobs.

### Workflow file

        #blastx.sh

        #HPC jobname=unzip
        unzip Sample1.zip
        unzip Sample2.zip
        unzip Sample3.zip

        #HPC jobname=blastx
        #HPC deps=unzip
        blastx --db env_nr --sample Sample1.fasta
        blastx --db env_nr --sample Sample2.fasta
        blastx --db env_nr --sample Sample3.fasta

### Submit to the scheduler

        hpcrunner.pl submit_jobs --infile preprocess.sh

### Look at results!

        tree hpc-runner

## Task Dependencency Declaration

Within a job type we can declare dependencies on particular tasks.

### Workflow file

        #blastx.sh

        #HPC jobname=unzip
        #TASK tags=Sample1
        unzip Sample1.zip
        #TASK tags=Sample2
        unzip Sample2.zip
        #TASK tags=Sample3
        unzip Sample3.zip

        #HPC jobname=blastx
        #HPC deps=unzip
        #TASK tags=Sample1
        blastx --db env_nr --sample Sample1.fasta
        #TASK tags=Sample2
        blastx --db env_nr --sample Sample2.fasta
        #TASK tags=Sample3
        blastx --db env_nr --sample Sample3.fasta

### Submit to the scheduler

        hpcrunner.pl submit_jobs --infile preprocess.sh

### Look at results!

        tree hpc-runner

## Declare Scheduler Variables

Each scheduler has its own set of variables. HPC::Runner::Command has a set of
generalized variables for declaring types across templates. For more information
please see [ Job Scheduler
Comparison](https://metacpan.org/pod/https:#jerowe.gitbooks.io-hpc-runner-command-docs-content-job_submission-comparison.html)

Additionally, for workflows with a large number of tasks, please see [
Considerations for Workflows with a Large Number of
Tasks](https://metacpan.org/pod/https:#jerowe.gitbooks.io-hpc-runner-command-docs-content-design_workflow.html-considerations-for-workflows-with-a-large-number-of-tasks)
for information on how to group tasks together.

### Workflow file

          #blastx.sh

          #HPC jobname=unzip
          #HPC cpus_per_task=1
          #HPC partition=serial
          #HPC commands_per_node=1
    #HPC mem=4GB
          #TASK tags=Sample1
          unzip Sample1.zip
          #TASK tags=Sample2
          unzip Sample2.zip
          #TASK tags=Sample3
          unzip Sample3.zip

          #HPC jobname=blastx
          #HPC cpus_per_task=6
          #HPC deps=unzip
          #TASK tags=Sample1
          blastx --threads 6 --db env_nr --sample Sample1.fasta
          #TASK tags=Sample2
          blastx --threads 6 --db env_nr --sample Sample2.fasta
          #TASK tags=Sample3
          blastx --threads 6 --db env_nr --sample Sample3.fasta

### Submit to the scheduler

        hpcrunner.pl submit_jobs --infile preprocess.sh

### Look at results!

        tree hpc-runner

# AUTHOR

Jillian Rowe <jillian.e.rowe@gmail.com>

# Previous Release

This software was previously released under [HPC::Runner](https://metacpan.org/pod/HPC::Runner).
[HPC::Runner::Command](https://metacpan.org/pod/HPC::Runner::Command) is a complete rewrite of the existing library. While it
is meant to have much of the same functionality, it is not backwords compatible.

# Acknowledgements

As of Version 2.41:

This modules continuing development is supported by NYU Abu Dhabi in the Center
for Genomics and Systems Biology. With approval from NYUAD, this information was
generalized and put on bitbucket, for which the authors would like to express
their gratitude.

Before Version 2.41

This module was originally developed at and for Weill Cornell Medical College in
Qatar within ITS Advanced Computing Team. With approval from WCMC-Q, this
information was generalized and put on github, for which the authors would like
to express their gratitude.

# COPYRIGHT

Copyright 2016- Jillian Rowe

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# SEE ALSO

# POD ERRORS

Hey! **The above document had some coding errors, which are explained below:**

- Around line 138:

    L<> starts or ends with whitespace

- Around line 143:

    L<> starts or ends with whitespace
