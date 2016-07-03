package HPC::Runner::Command::submit_jobs;

use MooseX::App::Command;
extends 'HPC::Runner::Command';

with 'HPC::Runner::App::Base';
with 'HPC::Runner::App::Log';
with 'HPC::Runner::App::Scheduler';

command_short_description 'Submit jobs to the HPC system';
command_long_description 'This job parses your input file and writes out one or more templates to submit to the scheduler of your choice (SLURM, PBS, etc)';

sub execute {
    my $self = shift;

    $self->hpc_load_plugins;
}

1;
