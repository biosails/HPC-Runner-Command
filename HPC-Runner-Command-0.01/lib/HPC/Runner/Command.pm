package HPC::Runner::Command;

use MooseX::App qw(Color Config);

our $VERSION = '0.01';

use IPC::Cmd;
use Data::Dumper;
use Cwd qw(getcwd);

with 'MooseX::Object::Pluggable';

app_strict 0;


=head1 HPC::Runner::Command

=head2 Command Line Opts

=head3 plugins

Load plugins that are used both by the submitter and executor such as logging pluggins

=cut

option 'plugins' => (
    is                 => 'rw',
    isa                => 'ArrayRef[Str]',
    documentation      => 'Load aplication plugins',
    cmd_split          => qr/,/,
    required => 0,
);

option 'plugins_opts' => (
    is => 'rw',
    isa => 'HashRef',
    documentation => 'Options for application plugins',
    required => 0,
);


=head3 hpc_plugins

Load hpc_plugins. PBS, Slurm, Web, etc.

=cut

option 'hpc_plugins' => (
    is                 => 'rw',
    isa                => 'ArrayRef[Str]',
    documentation      => 'Load hpc_plugins',
    cmd_split          => qr/,/,
    required => 0,
);

option 'hpc_plugins_opts' => (
    is => 'rw',
    isa => 'HashRef',
    documentation => 'Options for hpc_plugins',
    required => 0,
);

=head3 job_plugins

Load job execution plugins

=cut

option 'job_plugins' => (
    is                 => 'rw',
    isa                => 'ArrayRef[Str]',
    documentation      => 'Load job execution plugins',
    cmd_split          => qr/,/,
    required => 0,
);

option 'job_plugins_opts' => (
    is => 'rw',
    isa => 'HashRef',
    documentation => 'Options for job_plugins',
    required => 0,
);

=head3 tags

Submission tags

=cut

option 'tags' => (
    is                 => 'rw',
    isa                => 'ArrayRef[Str]',
    documentation      => 'Tags for the whole submission',
    cmd_split          => qr/,/,
    required => 0,
);

=head2 Subroutines

=cut

=head3 gen_load_plugins

=cut

sub gen_load_plugins {
    my $self = shift;

    return unless $self->plugins;

    $self->load_plugins(@{$self->plugins});
    $self->parse_plugin_opts($self->plugins_opts);
}

=head3 hpc_load_plugins

=cut

sub hpc_load_plugins {
    my $self = shift;

    return unless $self->hpc_plugins;

    $self->load_plugins(@{$self->hpc_plugins});
    $self->parse_plugin_opts($self->hpc_plugins_opts);
}

=head2 Subroutines

=head3 hpc_load_plugins

=cut

sub job_load_plugins {
    my $self = shift;

    return unless $self->job_plugins;

    $self->load_plugins(@{$self->job_plugins});

    $self->parse_plugin_opts($self->job_plugins_opts);
}

=head3 parse_plugin_opts

parse the opts from --plugin_opts

=cut

sub parse_plugin_opts {
    my $self = shift;
    my $opt_href = shift;

    return unless $opt_href;
    while(my($k, $v) = each %{$opt_href}){
        $self->$k($v) if $self->can($k);
    }
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

    hpcrunner.pl execute_job

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
