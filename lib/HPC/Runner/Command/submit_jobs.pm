package HPC::Runner::Command::submit_jobs;

=head1 HPC::Runner::Command::submit_jobs

Call the hpcrunner.pl submit_jobs command

=cut

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

=head2 Attributes

=head3 project

When submitting jobs we will prepend the jobname with the project name

=cut

option 'project' => (
    is            => 'rw',
    isa           => 'Str',
    documentation => 'Give your jobnames an additional project name. #HPC jobname=gzip will be submitted as 001_project_gzip',
    required      => 0,
    predicate => 'has_project',
);


=head2 Subroutines

=cut

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
