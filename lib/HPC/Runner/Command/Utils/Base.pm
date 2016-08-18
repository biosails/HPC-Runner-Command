package HPC::Runner::Command::Utils::Base;

use Cwd;
use File::Path qw(make_path remove_tree);
use List::Uniq ':all';

use Moose::Role;
use MooseX::App::Role;
use MooseX::Types::Path::Tiny qw/Path Paths AbsPath AbsFile/;

=head1 HPC::Runner::App::Base

=head2 Command Line Options

=head3 infile

File of commands separated by newline. The command 'wait' indicates all previous commands should finish before starting the next one.

=cut

option 'infile' => (
    is       => 'rw',
    required => 1,
    documentation =>
        q{File of commands separated by newline. The command 'wait' indicates all previous commands should finish before starting the next one.},
    isa    => AbsFile,
    coerce => 1,
);

=head3 outdir

Directory to write out files and optionally, logs.

=cut

option 'outdir' => (
    is            => 'rw',
    isa           => AbsPath,
    lazy          => 1,
    coerce        => 1,
    required      => 1,
    default       => \&set_outdir,
    documentation => q{Directory to write out files.},
    trigger       => \&_make_the_dirs,
    predicate     => 'has_outdir',
);

=head3 job_scheduler_id

Job Scheduler ID running the script. Passed to slurm for mail information

=cut

option 'job_scheduler_id' => (
    is       => 'rw',
    isa      => 'Str|Undef',
    default  => sub { return $ENV{SBATCH_JOB_ID} || $ENV{PBS_JOBID} || ''; },
    required => 1,
    documentation =>
        q{This defaults to your current Job Scheduler ID. Ignore this if running on a single node},
    predicate => 'has_job_scheduler_id',
    clearer   => 'clear_job_scheduler_id',
);

=head3 procs

Total number of running children allowed at any time. Defaults to 4. The command 'wait' can be used to have a variable number of children running. It is best to wrap this script in a slurm job to not overuse resources. This isn't used within this module, but passed off to mcerunner/parallelrunner.

=cut

option 'procs' => (
    is       => 'rw',
    isa      => 'Int',
    default  => 4,
    required => 0,
    documentation =>
        q{Total number of running jobs allowed at any time. The command 'wait' can be used to have a variable number of children running.}
);

=head2 Attributes

=cut

has 'cmd' => (
    traits   => ['String'],
    is       => 'rw',
    isa      => 'Str',
    required => 0,
    handles  => {
        add_cmd   => 'append',
        match_cmd => 'match',
    },
    predicate => 'has_cmd',
    clearer   => 'clear_cmd',
);

=head3 set_outdir

Internal variable

=cut

sub set_outdir {
    my $self = shift;

    if ( $self->has_outdir ) {
        $self->_make_the_dirs( $self->outdir );
        return;
    }

    my $outdir;

    if ( $self->has_version && $self->has_git ) {
        $outdir = "hpc-runner/" . $self->version . "/scratch";
    }
    else {
        $outdir = "hpc-runner/scratch";
    }

    $self->_make_the_dirs($outdir);

    return $outdir;
}

=head3 make_the_dirs

Make any necessary directories

=cut

sub _make_the_dirs {
    my ( $self, $outdir ) = @_;

    make_path($outdir) unless -d $outdir;
}

=head3 datetime_now

=cut

sub datetime_now {
    my $self = shift;

    my $dt = DateTime->now( time_zone => 'local' );

    my $ymd = $dt->ymd();
    my $hms = $dt->hms();

    return ( $dt, $ymd, $hms );
}

=head3 git_things

Git versioning

=cut

sub git_things {
    my $self = shift;

    $self->init_git;
    $self->dirty_run;
    $self->git_info;
    if ( $self->tags ) {
        push( @{ $self->tags }, "$self->{version}" );
    }
    else {
        $self->tags( [ $self->version ] );
    }
    my @tmp = uniq( @{ $self->tags } );
    $self->tags( \@tmp );
}

1;
