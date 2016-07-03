package HPC::Runner::Command::execute_job;

use MooseX::App::Command;

extends 'HPC::Runner::Command';

with 'HPC::Runner::App::Base';
with 'HPC::Runner::App::Log';
with 'HPC::Runner::App::MCE';

command_short_description 'Execute commands';
command_long_description 'Take the parsed files from hpcrunner.pl submit_jobs and executes the code';

sub execute {
    my $self = shift;
    $self->go;
}

1;
