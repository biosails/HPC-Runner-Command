use strict;
use warnings;

package HPC::Runner::Command::execute_job::Base;

use MooseX::App::Role;
use MooseX::Types::Path::Tiny qw/Path Paths AbsPath AbsFile/;
use Archive::Tar;

with 'HPC::Runner::Command::execute_job::Utils::Log';
with 'HPC::Runner::Command::execute_job::Logger::JSON';
use Sys::Hostname;

=head2 Command Line Options

=cut

option 'poll_time' => (
    is  => 'rw',
    isa => 'Num',
    documentation =>
      'Time in seconds to poll the process for memory profiling.',
    default     => 100,
    cmd_aliases => ['pt'],
);

option 'memory_difference' => (
    is            => 'rw',
    isa           => 'Num',
    documentation => 'Difference from last memory profile in order to record.',
    default       => 0.10,
    cmd_aliases   => ['md'],
);


=head2 Internal Attriutes

=cut

=head3 job_scheduler_id

Job Scheduler ID running the script. Passed to slurm for mail information

=cut

has 'job_scheduler_id' => (
    is      => 'rw',
    isa     => 'Str|Undef',
    default => sub {
        my $self = shift;
        my $scheduler_id =
             $ENV{SLURM_ARRAY_JOB_ID}
          || $ENV{SLURM_JOB_ID}
          || $ENV{SBATCH_JOB_ID}
          || $ENV{PBS_JOBID}
          || $ENV{JOB_ID}
          || '';
        if ( $self->can('task_id') && $self->task_id ) {
            $scheduler_id = $scheduler_id . '_' . $self->task_id;
        }
        return $scheduler_id;
    },
    lazy => 1,
    documentation =>
q{This defaults to your current Job Scheduler ID. Ignore this if running on a single node},
    predicate => 'has_job_scheduler_id',
    clearer   => 'clear_job_scheduler_id',
);

has 'hostname' => (
    is      => 'rw',
    isa     => 'Str|Undef',
    default => sub {
        return hostname;
    },
);

has 'wait' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

=head3 counter

This is task_id counter. Batch index start and/or array_id get passed in on the command line
But for instances where we are creating a threadpool of more than 1 task
The counter keeps track

=cut

has 'counter' => (
    traits   => ['Counter'],
    is       => 'rw',
    isa      => 'Num',
    required => 1,
    default  => 1,
    handles  => {
        inc_counter   => 'inc',
        dec_counter   => 'dec',
        reset_counter => 'reset',
    },
);

has 'jobref' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [ [] ] },
);

1;
