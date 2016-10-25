package HPC::Runner::Command::submit_jobs;

use MooseX::App::Command;
extends 'HPC::Runner::Command';

#use HPC::Runner::Command qw(ConfigHome);

with 'HPC::Runner::Command::Utils::Base';
with 'HPC::Runner::Command::Utils::Log';
with 'HPC::Runner::Command::Utils::Git';
with 'HPC::Runner::Command::submit_jobs::Utils::Scheduler';

command_short_description 'Submit jobs to the HPC system';
command_long_description 'This job parses your input file and writes out one or
more templates to submit to the scheduler of your choice (SLURM, PBS, etc)';

sub BUILD {
    my $self = shift;

    $self->git_things;
    $self->gen_load_plugins;
    $self->hpc_load_plugins;
}

sub execute {
    my $self = shift;

    $self->parse_file_slurm();
    $self->iterate_schedule();
}

1;
