package HPC::Runner::Command::submit_jobs;

use MooseX::App::Command;
extends 'HPC::Runner::Command';

with 'HPC::Runner::Command::Utils::Base';
with 'HPC::Runner::Command::Utils::Log';
with 'HPC::Runner::Command::submit_jobs::Utils::Scheduler';

command_short_description 'Submit jobs to the HPC system';
command_long_description 'This job parses your input file and writes out one or
more templates to submit to the scheduler of your choice (SLURM, PBS, etc)';

sub BUILD {
    my $self = shift;

    $self->gen_load_plugins;
    $self->hpc_load_plugins;
}

sub execute {
    my $self = shift;

    $self->first_pass(1);
    $self->parse_file_slurm();
    $self->schedule_jobs();
    $self->iterate_schedule();

    $self->reset_batch_counter;
    $self->first_pass(0);
    $self->iterate_schedule();
}

1;
