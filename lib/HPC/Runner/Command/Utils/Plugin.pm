package HPC::Runner::Command::Utils::Plugin;

use Moose::Role;
use IO::File;
use File::Path qw(make_path remove_tree);

=head1 HPC::Runner::Command::Utils::Plugin

Take care of all file operations

=cut

=head2 Attributes

=cut

=head2 Subroutines

=cut

=head3 create_plugin_str

Make sure to pass plugins to job runner

=cut

sub create_plugin_str {
    my $self = shift;

    my $plugin_str = "";

    if ( $self->job_plugins ) {
        $plugin_str .= " \\\n\t";
        $plugin_str
            .= "--job_plugins " . join( ",", @{ $self->job_plugins } );
        $plugin_str .= " \\\n\t" if $self->job_plugins_opts;
        $plugin_str
            .= $self->unparse_plugin_opts( $self->job_plugins_opts,
            'job_plugins' )
            if $self->job_plugins_opts;
    }

    if ( $self->plugins ) {
        $plugin_str .= " \\\n\t";
        $plugin_str .= "--plugins " . join( ",", @{ $self->plugins } );
        $plugin_str .= " \\\n\t" if $self->plugins_opts;
        $plugin_str
            .= $self->unparse_plugin_opts( $self->plugins_opts, 'plugins' )
            if $self->plugins_opts;
    }

    return $plugin_str;
}

sub unparse_plugin_opts {
    my $self     = shift;
    my $opt_href = shift;
    my $opt_opt  = shift;

    my $opt_str = "";

    return unless $opt_href;

    #Get the opts

    while ( my ( $k, $v ) = each %{$opt_href} ) {
        next unless $k;
        $v = "" unless $v;
        $opt_str .= "--$opt_opt" . "_opts " . $k . "=" . $v . " ";
    }

    return $opt_str;
}
1;
