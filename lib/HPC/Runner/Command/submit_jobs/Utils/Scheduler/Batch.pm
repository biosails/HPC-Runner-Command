package HPC::Runner::Command::submit_jobs::Utils::Scheduler::Batch;

use Moose;
use Moose::Util::TypeConstraints;

#cmd_count = Int
#job_deps  = ArrayRef
#batch_str = Str
#job       = Str
#cmds      = ArrayRef
#batch_tags = ArrayRef
#scheduler_index = Hashref[ArrayRef]
#array_deps = ArrayRef <- Do I need this?

#TODO batch_tags is going to be batch_tags and batch_dep_tags

#Begin Example
#my $href = {
    #'cmds' => [
        #'#TASK tags=Sample1
##TASK deps=Sample1
#blastx -db  env_nr -query Sample1
#'
    #],
    #'cmd_count'  => '1',
    #'job_deps'   => ['pyfasta'],
    #'batch_tags' => ['Sample1'],
    #'batch_str'  => '#TASK tags=Sample1
##TASK deps=Sample1
#blastx -db  env_nr -query Sample1
#',
    #'job'             => 'blastx_scratch',
    #'scheduler_index' => { 'pyfasta' => ['0'], },
    #'array_deps'      => [ [ '1237_7', '1234_1' ], ],
#};
#End Example


has cmds => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
    handles => {
        all_cmds   => 'elements',
        add_cmds   => 'push',
        join_cmds  => 'join',
        has_cmds   => 'count',
        clear_cmds => 'clear',
    },
);

has cmd_count => (
    is      => 'rw',
    isa     => 'Int',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return $self->has_cmds;
    },
);

has batch_tags => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
    handles => {
        all_batch_tags   => 'elements',
        add_batch_tags   => 'push',
        join_batch_tags  => 'join',
        has_batch_tags   => 'count',
        clear_batch_tags => 'clear',
    },
);

has batch_deps => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
    handles => {
        all_batch_deps   => 'elements',
        add_batch_deps   => 'push',
        join_batch_deps  => 'join',
        has_batch_deps   => 'count',
        clear_batch_deps => 'clear',
    },
);

has batch_str => (
    isa     => 'Str',
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return $self->join_cmds("\n");
    }
);

has 'job' => (
    is       => 'rw',
    isa      => 'Str',
    required => 0,
);

has 'scheduler_id' => (
    is       => 'rw',
    isa      => 'Str',
    required => 0,
);

has 'scheduler_index' => (
    isa     => 'HashRef',
    is      => 'rw',
    default => sub { return {} },
    documentation => q(Get the job dependency, and the index of the job scheduler id that corresponds to that batch),
);

has 'array_deps' => (
    traits  => ['Array'],
    isa => 'ArrayRef',
    is => 'rw',
    default => sub { return [] },
    handles => {
        all_array_deps   => 'elements',
        add_array_deps   => 'push',
        join_array_deps  => 'join',
        has_array_deps   => 'count',
        clear_array_deps => 'clear',
    },
);

1;
