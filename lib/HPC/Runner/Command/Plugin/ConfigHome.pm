package HPC::Runner::Command::Plugin::ConfigHome;

use namespace::autoclean;
use Moose::Role;
with qw(MooseX::App::Plugin::Config);

sub plugin_metaroles {
    my ( $self, $class ) = @_;

    return {
        class => [
            'MooseX::App::Plugin::Config::Meta::Class',
            'HPC::Runner::Command::Plugin::ConfigHome::Meta::Class'
        ],
    };
}

1;
