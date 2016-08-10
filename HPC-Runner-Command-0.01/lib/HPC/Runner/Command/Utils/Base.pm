package HPC::Runner::Command::Utils::Base;

use Cwd;
use File::Path qw(make_path remove_tree);

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
    coerce        => 1,
    required      => 1,
    default       => sub { return "logs" },
    documentation => q{Directory to write out files.},
    trigger       => \&_set_outdir,
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


=head3 _set_outdir

Internal variable

=cut

sub _set_outdir {
    my ( $self, $outdir ) = @_;

    make_path($outdir) if -d $outdir;
}

1;
