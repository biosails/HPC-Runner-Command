package HPC::Runner::Command::Logger::JSON::Archive;

use Moose;
use MooseX::NonMoose;

use File::Spec;
use File::Slurp;
use Try::Tiny;
use Path::Tiny;
use Data::Dumper;
use Capture::Tiny ':all';
use File::Temp qw/ tempfile tempdir /;
use File::Path qw(make_path remove_tree);
use Cwd;

extends 'Archive::Tar::Wrapper';

sub contains_file {
    my $self = shift;
    my $file = shift;

    my $found = 0;
    $self->list_reset();

    while ( my $entry = $self->list_next() ) {
        my ( $tar_path, $phys_path ) = @$entry;
        if ( $tar_path eq $file ) {
            $found = 1;
            last;
        }
    }

    $self->list_reset();
    return $found;
}

sub add_data {
    my $self   = shift;
    my $file   = shift;
    my $data   = shift;
    my $append = shift;

    $append = 0 if !$append;

    return unless $file;
    $data = '' unless $data;

    my $cwd = getcwd();
    my $tmpdir = tempdir( CLEANUP => 0 );
    chdir $tmpdir;

    my $rel_path = File::Spec->abs2rel($file);
    path($rel_path)->touchpath;
    path($rel_path)->touch;

    try {
        write_file( $rel_path, { append => $append }, $data );
    }
    catch {
        warn "We were not able to write data to file $file $_\n";
    };

    $self->add( $rel_path, $rel_path );

    chdir $cwd;
    remove_tree($tmpdir);
}

sub replace_content {
    my $self = shift;
    my $file = shift;
    my $data = shift;

    $self->add_data( $file, $data, 0 );
}

sub get_content {
    my $self = shift;
    my $file = shift;

    $self->list_reset();
    my $data = '{}';

    while ( my $entry = $self->list_next() ) {
        my ( $tar_path, $phys_path ) = @$entry;
        if ( $tar_path eq $file ) {
            try {
                $data = read_file( $entry->[1] );
            };
            last;
        }
    }
    $self->list_reset();
    return $data;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
