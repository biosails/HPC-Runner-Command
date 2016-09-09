# NAME

HPC::Runner::Command - A complete rewrite of the HPC::Runner libraries to incorporate project creation, DAG inspection, and job execution.

# SYNOPSIS

To create a new project

    hpcrunner.pl new

To submit jobs to a cluster

    hpcrunner.pl submit_jobs

To run jobs on an interactive queue or workstation

    hpcrunner.pl execute_job

# DESCRIPTION

HPC::Runner::App is a set of libraries for scaffolding data analysis projects, submitting and executing jobs on an HPC cluster or workstation, and obsessively logging results.

# HPC::Runner::Command In Line Code Documentation

## Command Line Opts

### plugins

Load plugins that are used both by the submitter and executor such as logging pluggins

### hpc\_plugins

Load hpc\_plugins. PBS, Slurm, Web, etc.

### job\_plugins

Load job execution plugins

### tags

Submission tags

## Subroutines

### gen\_load\_plugins

### hpc\_load\_plugins

## Subroutines

### hpc\_load\_plugins

### app\_load\_plugin

### parse\_plugin\_opts

parse the opts from --plugin\_opts

# AUTHOR

Jillian Rowe <jillian.e.rowe@gmail.com>

# COPYRIGHT

Copyright 2016- Jillian Rowe

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# SEE ALSO
