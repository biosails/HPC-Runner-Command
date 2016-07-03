package HPC::Runner::Command;

use MooseX::App qw(Color Config);
#use MooseX::App qw(Config);

our $VERSION = '0.01';

use IPC::Cmd;
use Data::Dumper;
use Cwd qw(getcwd);

with 'MooseX::Object::Pluggable';

app_strict 0;


=head1 HPC::Runner::Command

=head2 Command Line Opts

=head3 plugins

Load plugins. PBS, Slurm, Web, etc.

=cut

option 'plugins' => (
    is                 => 'rw',
    isa                => 'ArrayRef[Str]',
    documentation      => 'Load plugins',
    cmd_split          => qr/,/,
    required => 0,
);

=head2 Subroutines

=head3 hpc_load_plugins

=cut

sub hpc_load_plugins {
    my $self = shift;

    return unless $self->plugins;

    $self->load_plugins(@{$self->plugins});
}

1;

__END__

=encoding utf-8

=head1 NAME

HPC::Runner::Command - A complete rewrite of the HPC::Runner libraries to incorporate project creation, DAG inspection, and job execution.

=head1 SYNOPSIS
To create a new project

    hpcrunner.pl new

To submit jobs to a cluster

    hpcrunner.pl submit_jobs

To run jobs on an interactive queue or workstation

    hpcrunner.pl execute_jobs

=head1 DESCRIPTION

HPC::Runner::App is a set of libraries for scaffolding data analysis projects, submitting and executing jobs on an HPC cluster or workstation, and obsessively logging results.

=head1 AUTHOR

Jillian Rowe E<lt>jillian.e.rowe@gmail.comE<gt>

=head1 COPYRIGHT

Copyright 2016- Jillian Rowe

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
