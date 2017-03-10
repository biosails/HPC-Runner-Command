package HPC::Runner::Command::Plugin::Configs;

use MooseX::App::Role;
use File::HomeDir qw();
use Config::Any;
use File::Spec;
use Cwd;

has 'no_configs' => (
    is            => 'rw',
    isa           => 'Bool',
    default       => 0,
    documentation => '--no_configs tells HPC::Runner not to load any configs',
);

#TODO Add search dirs

sub BUILD { }

after 'BUILD' => sub {
    my $self = shift;

    return if $self->no_configs;

    my $config_base = '.hpc-runner.';

    my $home_dir = File::Spec->catdir( File::HomeDir->my_home );
    my $cwd = getcwd();

    my @dirs = ($home_dir, $cwd);
    my @configs = ();

    foreach my $extension ( Config::Any->extensions ) {
      foreach my $dir (@dirs){

        my $check_file =
          File::Spec->catdir( $dir . '.hpc-runner.' . $extension );
      }
    }
};

1;
