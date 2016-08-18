package HPC::Runner::Command::submit_jobs::Utils::Scheduler;

use File::Path qw(make_path remove_tree);
use File::Temp qw/ tempfile tempdir /;
use IO::File;
use IO::Select;
use Cwd;
use IPC::Open3;
use Symbol;
use Template;
use Log::Log4perl qw(:easy);
use DateTime;
use Data::Dumper;
use List::Util qw(shuffle);
use List::MoreUtils qw(firstidx);
use JSON;
use DBM::Deep;

use Algorithm::Dependency;
use Algorithm::Dependency::Source::HoA;

use Moose::Role;
use MooseX::App::Role;
use MooseX::Types::Path::Tiny qw/Path Paths AbsPath AbsFile/;
use Moose::Util::TypeConstraints;

with 'HPC::Runner::Command::submit_jobs::Utils::Scheduler::ParseInput';
use HPC::Runner::Command::submit_jobs::Utils::Scheduler::JobStats;
use HPC::Runner::Command::submit_jobs::Utils::Scheduler::JobDeps;

=head1 HPC::Runner::Command::submit_jobs::Utils::Scheduler

=head2 Utils

=cut

subtype 'ArrayRefOfStrs', as 'ArrayRef[Str]';

coerce 'ArrayRefOfStrs', from 'Str', via { [ split( ',', $_ ) ] };

=head2 Command Line Options

#TODO Move this over to docs

=head3 config

Config file to pass to command line as --config /path/to/file. It should be a yaml or other config supplied by L<Config::Any>
This is optional. Paramaters can be passed straight to the command line

Deprecated: configfile

=head3 example.yml

    ---
    infile: "/path/to/commands/testcommand.in"
    outdir: "path/to/testdir"
    module:
        - "R2"
        - "shared"

=cut

=head3 infile

infile of commands separated by newline. The usual bash convention of escaping a newline is also supported.

=head4 example.in

    cmd1
    #Multiline command
    cmd2 --input --input \
    --someotherinput
    wait
    #Wait tells slurm to make sure previous commands have exited with exit status 0.
    cmd3  ##very heavy job
    newnode
    #cmd3 is a very heavy job so lets start the next job on a new node

=cut

=head3 jobname

Specify a job name, and jobs will be 001_jobname, 002_jobname, 003_jobname

Separating this out from Base - submit_jobs and execute_job have different ways of dealing with this

=cut

option 'jobname' => (
    is        => 'rw',
    isa       => 'Str',
    required  => 0,
    traits    => ['String'],
    default   => 'hpcjob_001',
    predicate => 'has_jobname',
    handles   => {
        add_jobname     => 'append',
        clear_jobname   => 'clear',
        replace_jobname => 'replace',
        prepend_jobname => 'prepend',
        match_jobname   => 'match',
    },
    trigger => sub {
        my $self = shift;
        $self->check_add_to_jobs;
        $self->job_deps->{ $self->jobname } = [];
    },
    documentation =>
        q{Specify a job name, each job will be appended with its batch order},
);

=head3 module

modules to load with slurm
Should use the same names used in 'module load'

Example. R2 becomes 'module load R2'

=cut

option 'module' => (
    traits        => ['Array'],
    is            => 'rw',
    isa           => 'ArrayRefOfStrs',
    coerce        => 1,
    required      => 0,
    documentation => q{List of modules to load ex. R2, samtools, etc},
    default       => sub { [] },
    cmd_split     => qr/,/,
    handles       => { has_modules => 'count', },
);

=head3 afterok

The afterok switch in slurm. --afterok 123 will tell slurm to start this job after job 123 has completed successfully.

=cut

option afterok => (
    traits   => ['Array'],
    is       => 'rw',
    required => 0,
    isa      => 'ArrayRefOfStrs',
    default  => sub { [] },
    handles  => {
        all_afterok   => 'elements',
        has_afterok   => 'count',
        clear_afterok => 'clear',
    },
);

=head3 cpus_per_task

slurm item --cpus_per_task defaults to 4, which is probably fine

=cut

option 'cpus_per_task' => (
    is        => 'rw',
    isa       => 'Int',
    required  => 0,
    default   => 12,
    predicate => 'has_cpus_per_task',
    clearer   => 'clear_cpus_per_task'
);

=head3 commands_per_node

--commands_per_node defaults to 8, which is probably fine

=cut

has 'commands_per_node' => (
    is            => 'rw',
    isa           => 'Int',
    required      => 0,
    default       => 12,
    documentation => q{Commands to run on each node. },
    predicate     => 'has_commands_per_node',
    clearer       => 'clear_commands_per_node'
);

=head3 nodes_count

Number of nodes to use on a job. This is only useful for mpi jobs.

PBS:
#PBS -l nodes=nodes_count:ppn=16 this

Slurm:
#SBATCH --nodes nodes_count

=cut

option 'nodes_count' => (
    is       => 'rw',
    isa      => 'Int',
    required => 0,
    default  => 1,
    documentation =>
        q{Number of nodes requested. You should only use this if submitting parallel jobs.},
    predicate => 'has_nodes_count',
    clearer   => 'clear_nodes_count'
);

=head3 partition

Specify the partition. Defaults to the partition that has the most nodes.

In PBS this is called 'queue'

=cut

option 'partition' => (
    is       => 'rw',
    isa      => 'Str',
    required => 0,
    documentation =>
        q{Slurm partition to submit jobs to. Defaults to the partition with the most available nodes},
    predicate => 'has_partition',
    clearer   => 'clear_partition'
);

=head3 no_submit_to_slurm

Bool value whether or not to submit to slurm. If you are looking to debug your files, or this script you will want to set this to zero.
Don't submit to slurm with --no_submit_to_slurm from the command line or
$self->no_submit_to_slurm(0); within your code

=cut

option 'no_submit_to_slurm' => (
    is       => 'rw',
    isa      => 'Bool',
    default  => 0,
    required => 1,
    documentation =>
        q{Bool value whether or not to submit to slurm. If you are looking to debug your files, or this script you will want to set this to zero.},
);

=head3 template_file

actual template file

One is generated here for you, but you can always supply your own with --template_file /path/to/template

=cut

has 'template_file' => (
    is      => 'rw',
    isa     => 'Str',
    default => sub {
        my $self = shift;

        my ( $fh, $filename ) = tempfile();

        my $tt = <<EOF;
#!/bin/bash
#
#SBATCH --share
#SBATCH --get-user-env
#SBATCH --job-name=[% JOBNAME %]
#SBATCH --output=[% OUT %]
[% IF self.has_partition %]
#SBATCH --partition=[% self.partition %]
[% END %]
[% IF self.has_cpus_per_task %]
#SBATCH --cpus-per-task=[% self.cpus_per_task %]
[% END %]
[% IF AFTEROK %]
#SBATCH --dependency=afterok:[% AFTEROK %]
[% END %]

[% IF self.has_modules %]
[% FOR d = self.modules %]
module load [% d %]
[% END %]
[% END %]

[% COMMAND %]
EOF

        print $fh $tt;
        return $filename;
    },
    predicate => 'has_template_file',
    clearer   => 'clear_template_file',
    documentation =>
        q{Path to Slurm template file if you do not wish to use the default}
);

=head3 serial

Option to run all jobs serially, one after the other, no parallelism
The default is to use 4 procs

=cut

option serial => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
    documentation =>
        q{Use this if you wish to run each job run one after another, with each job starting only after the previous has completed successfully},
    predicate => 'has_serial',
    clearer   => 'clear_serial'
);

=head3 user

user running the script. Passed to slurm for mail information

=cut

option 'user' => (
    is       => 'rw',
    isa      => 'Str',
    default  => sub { return $ENV{USER} || $ENV{LOGNAME} || getpwuid($<); },
    required => 1,
    documentation =>
        q{This defaults to your current user ID. This can only be changed if running as an admin user}
);

=head3 use_custom

Supply your own command instead of mcerunner/threadsrunner/etc

=cut

option 'custom_command' => (
    is        => 'rw',
    isa       => 'Str',
    predicate => 'has_custom_command',
    clearer   => 'clear_custom_command',
    required  => 0
);

=head2 Internal Attributes

=head3 scheduler_ids

Our current scheduler job dependencies

=cut

#Keep this or afterok?

has 'scheduler_ids' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
    handles => {
        all_scheduler_ids    => 'elements',
        add_scheduler_id     => 'push',
        map_scheduler_ids    => 'map',
        filter_scheduler_ids => 'grep',
        find_scheduler_id    => 'first',
        get_scheduler_id     => 'get',
        join_scheduler_ids   => 'join',
        count_scheduler_ids  => 'count',
        has_scheduler_ids    => 'count',
        has_no_scheduler_ids => 'is_empty',
        sorted_scheduler_ids => 'sort',
        clear_scheduler_ids  => 'clear',
    },
);

=head3 schedule

Schedule our jobs

=cut

has 'schedule' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
    handles => {
        all_schedules    => 'elements',
        add_schedule     => 'push',
        has_schedules    => 'count',
        clear_schedule   => 'clear',
        has_no_schedules => 'is_empty',
    },
);

=head3 job_stats

Object describing the number of jobs, number of batches per job, etc

=cut

has 'job_stats' => (
    is      => 'rw',
    isa     => 'HPC::Runner::Command::submit_jobs::Utils::Scheduler::JobStats',
    default => sub {
        return HPC::Runner::Command::submit_jobs::Utils::Scheduler::JobStats->new();
    }
);

=head3 deps

Call as

    #HPC deps=job01,job02

=cut

has 'deps' => (
    is        => 'rw',
    isa       => 'ArrayRefOfStrs',
    coerce    => 1,
    predicate => 'has_deps',
    clearer   => 'clear_deps',
    required  => 0,
    trigger   => sub {
        my $self = shift;

        $self->job_deps->{ $self->jobname } = $self->deps;
        $self->jobs->{ $self->jobname }->{deps} = $self->deps;
    }
);

=head3 current_job

Keep track of our currently running job

=cut

has 'current_job' => (
    is       => 'rw',
    isa      => 'Str',
    default  => '',
    required => 0,
);

=head3 first_pass

Do a first pass of the file to get all the stats

=cut

has 'first_pass' => (
    is       => 'rw',
    isa      => 'Bool',
    default  => 1,
    required => 1,
);

=head3 template

template object for writing slurm batch submission script

=cut

has 'template' => (
    is       => 'rw',
    required => 0,
    default  => sub {
        return Template->new( ABSOLUTE => 1, PRE_CHOMP => 1, TRIM => 1 );
    },
);

=head3 cmd_counter

keep track of the number of commands - when we get to more than commands_per_node restart so we get submit to a new node.
This is the number of commands within a batch. Each new batch resets it.

=cut

has 'cmd_counter' => (
    traits   => ['Counter'],
    is       => 'ro',
    isa      => 'Num',
    required => 1,
    default  => 0,
    handles  => {
        inc_cmd_counter   => 'inc',
        dec_cmd_counter   => 'dec',
        reset_cmd_counter => 'reset',
    },
);

=head2 batch_counter

Keep track of how many batches we have submited to slurm

=cut

has 'batch_counter' => (
    traits   => ['Counter'],
    is       => 'ro',
    isa      => 'Num',
    required => 1,
    default  => 1,
    handles  => {
        inc_batch_counter   => 'inc',
        dec_batch_counter   => 'dec',
        reset_batch_counter => 'reset',
    },
);

=head3 batch

List of commands to submit to slurm

=cut

has 'batch' => (
    traits    => ['String'],
    is        => 'rw',
    isa       => 'Str',
    default   => q{},
    required  => 0,
    handles   => { add_batch => 'append', },
    clearer   => 'clear_batch',
    predicate => 'has_batch',
);

=head3 cmdfile

File of commands for mcerunner
Is cleared at the end of each slurm submission

=cut

has 'cmdfile' => (
    traits   => ['String'],
    default  => q{},
    is       => 'rw',
    isa      => 'Str',
    required => 0,
    handles  => { clear_cmdfile => 'clear', },
);

=head3 slurmfile

File generated from slurm template

Job submission file

=cut

has 'slurmfile' => (
    traits   => ['String'],
    default  => q{},
    is       => 'rw',
    isa      => 'Str',
    required => 0,
    handles  => { clear_slurmfile => 'clear', },
);

=head3 global_attr

Save the initial attributes

=cut

=head3 jobs

Contains all of our info for jobs

    {
        job03 => {
            deps => ['job01', 'job02'],
            schedulerIds => ['123.hpc.inst.edu'],
            submitted => 1/0,
            batch => 'String of whole commands',
            cmds => [
                'cmd1',
                'cmd2',
            ]
        },
        schedule => ['job01', 'job02', 'job03']
    }

=cut

#TODO This should be in its own package

has 'jobs' => (
    is      => 'rw',
    isa     => 'DBM::Deep',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $fh   = tempfile();
        my $db   = DBM::Deep->new( fh => $fh );
        return $db;
    },
);

=head2 job_counter

Keep track of how many jobs we have submited to slurm

=cut

has 'job_counter' => (
    traits   => ['Counter'],
    is       => 'ro',
    isa      => 'Num',
    required => 1,
    default  => 1,
    handles  => {
        inc_job_counter   => 'inc',
        dec_job_counter   => 'dec',
        reset_job_counter => 'reset',
    },
);

=head3 job_deps

Hashref of jobdeps to pass to Algorithm::Dependency

Job03 depends on job01 and job02

    { 'job03' => ['job01', 'job02'] }

=cut

has 'job_deps' => (
    traits  => ['Hash'],
    is      => 'rw',
    isa     => 'HashRef',
    lazy    => 1,
    handles => {
        set_job_deps    => 'set',
        get_job_deps    => 'get',
        exists_job_deps => 'exists',
        has_no_job_deps => 'is_empty',
        num_job_depss   => 'count',
        delete_job_deps => 'delete',
        job_deps_pairs  => 'kv',
    },
    default => sub { my $self = shift; return { $self->jobname => [] } },
);

=head2 Subroutines

=cut

=head3 run

=cut

sub run {
    my $self = shift;

    $self->logname('slurm_logs');
    #$self->log( $self->init_log );

    #TODO add back in support for serial workflows
    if ( $self->serial ) {
        $self->procs(1);
    }

    $self->check_files;
    $self->check_jobname;

    $self->parse_file_slurm;
    $self->schedule_jobs();

    $self->first_pass(1);
    $self->iterate_schedule;

    $self->reset_batch_counter;
    $self->first_pass(0);
    $self->iterate_schedule;

    #$DB::single = 2;
}

=head3 check_jobname

Check to see if we the user has chosen the default jobname, 'job'

=cut

sub check_jobname {
    my $self = shift;

    $self->increase_jobname if $self->match_jobname(qr/^hpcjob_/);
}

=head3 check_add_to_jobs

Make sure each jobname has an entry

=cut

sub check_add_to_jobs {
    my $self = shift;

    if ( !exists $self->jobs->{ $self->jobname } ) {
        $self->jobs->{ $self->jobname }
            = HPC::Runner::Command::submit_jobs::Utils::Scheduler::JobDeps->new();
    }
    if ( !exists $self->job_deps->{ $self->jobname } ) {
        $self->job_deps->{ $self->jobname } = [];
    }
}

=head3 increase_jobname

Increase jobname. job_001, job_002. Used for job_deps

=cut

sub increase_jobname {
    my $self = shift;

    $self->inc_job_counter;
    my $counter = $self->job_counter;
    $counter = sprintf( "%03d", $counter );

    $self->jobname( "hpcjob_" . $counter );
}

=head3 check_files()

Check to make sure the outdir exists.
If it doesn't exist the entire path will be created

=cut

sub check_files {
    my ($self) = @_;

    make_path( $self->outdir ) if !-d $self->outdir;
}

=head3 check_work

Check to see if its time to submit to the scheduler...

=cut

sub check_work {
    my $self = shift;

    if (   $self->cmd_counter > 0
        && 0 == $self->cmd_counter % ( $self->commands_per_node )
        && $self->batch )
    {
        $self->work;
    }
}

=head3 schedule_jobs

Use Algorithm::Dependency to schedule the jobs

=cut

sub schedule_jobs {
    my $self = shift;

    my $source = Algorithm::Dependency::Source::HoA->new( $self->job_deps );
    my $dep = Algorithm::Dependency->new( source => $source, selected => [] );

    $self->schedule($dep->schedule_all);

}

=head3 iterate_schedule

Iterate over the schedule generated by schedule_jobs

=cut

sub iterate_schedule {
    my $self = shift;

    return if $self->has_no_schedules;

    #my @jobs = @{ $self->jobs->{schedule} };

    $self->clear_scheduler_ids();

    foreach my $job ($self->all_schedules) {

        $self->current_job($job);

        $self->reset_cmd_counter;
        $self->iterate_deps();

        $self->process_jobs();
        $self->post_process_jobs();
    }
}

=head3 iterate_deps

Check to see if we are actually submitting

Make sure each dep has already been submitted

Return job schedulerIds

=cut

sub iterate_deps {
    my $self = shift;

    my $deps = $self->job_deps->{ $self->current_job };

    foreach my $dep ( @{$deps} ) {
        if ( $self->no_submit_to_slurm && $self->jobs->{$dep}->is_not_submitted )
        {
            die print "A cyclic dependencies found!!!\n";
        }
        else {
                map { $self->add_scheduler_id($_) } $self->jobs->{$dep}->all_scheduler_ids;
        }
    }
}

=head3 post_process_jobs

=cut

sub post_process_jobs {
    my $self = shift;

    $self->jobs->{ $self->current_job }->submitted(1) unless $self->first_pass;
    $self->clear_scheduler_ids();
}

=head3 process_jobs

=cut

sub process_jobs {
    my $self = shift;

    my $jobref = $self->jobs->{ $self->current_job };

    return if $jobref->submitted;

    map { $self->process_hpc_meta($_) } $jobref->all_hpc_meta;

    #TODO just split the cmds into batches and process that way
    map { $self->check_work; $self->process_cmd($_) } $jobref->all_cmds;

    $self->work if $self->has_batch;
}

=head3 process_cmd

Batch the jobs and submit

=cut

sub process_cmd {
    my $self = shift;
    my $cmd  = shift;

    return unless $cmd;

    $self->inc_cmd_counter;

    $self->add_batch($cmd);

}

sub process_hpc_meta {
    my $self = shift;
    my $line = shift;
    my ( @match, $t1, $t2 );

    return unless $line =~ m/^#HPC/;

    @match = $line =~ m/HPC (\w+)=(.+)$/;
    ( $t1, $t2 ) = ( $match[0], $match[1] );

    if ( !$self->can($t1) ) {
        print "Option $t1 is an invalid option!\n";
        return;
    }

    if ($t1) {
        $self->$t1($t2);
    }
    else {
        @match = $line =~ m/HPC (\w+)$/;
        $t1    = $match[0];
        return unless $t1;
        $t1 = "clear_$t1";
        $self->$t1;
    }
}

=head3 work

Process the batch
Submit to the scheduler slurm/pbs/etc
Take care of the counters

=cut

sub work {
    my $self = shift;

    $DB::single = 2;

    $self->job_stats->collect_stats( $self->batch_counter,
        $self->cmd_counter, $self->current_job )
        if $self->first_pass;

    $self->process_batch unless $self->first_pass;

    $self->inc_batch_counter;
    $self->clear_batch;

    $self->reset_cmd_counter;
}

=head3 process_batch()

Create the slurm submission script from the slurm template
Write out template, submission job, and infile for parallel runner

=cut

sub process_batch {
    my $self = shift;

    return if $self->no_submit_to_slurm;

    my ( $cmdfile, $slurmfile, $slurmsubmit, $fh, $command );

    my $counter = $self->batch_counter;
    $counter = sprintf( "%03d", $counter );

    make_path($self->outdir) unless -d $self->outdir;
    $self->cmdfile(
        $self->outdir . "/$counter" . "_" . $self->current_job . ".in" );
    $self->slurmfile(
        $self->outdir . "/$counter" . "_" . $self->current_job . ".sh" );

    $fh = IO::File->new( $self->cmdfile, q{>} )
        or die print "Error opening file  "
        . $self->cmdfile . "  "
        . $! . "\n";

    print $fh $self->batch if defined $fh && defined $self->batch;
    $fh->close;

    my $ok;
    if ( $self->has_scheduler_ids ) {
        $ok = $self->join_scheduler_ids(':');
    }

    $command    = $self->process_batch_command();
    $DB::single = 2;

    #TODO Rewrite this to only use self
    $self->template->process(
        $self->template_file,
        {   JOBNAME => $counter . "_" . $self->current_job,
            USER    => $self->user,
            AFTEROK => $ok,
            OUT     => $self->logdir
                . "/$counter" . "_"
                . $self->current_job . ".log",
            self    => $self,
            COMMAND => $command
        },
        $self->slurmfile
    ) || die $self->template->error;

    chmod 0777, $self->slurmfile;

    my $scheduler_id = $self->submit_jobs;

    $self->jobs->{$self->current_job}->add_scheduler_ids($scheduler_id);
}

=head3 process_batch_command

splitting this off from the main command

=cut

sub process_batch_command {
    my ($self) = @_;
    my $command;

#Removing support for multiple job runners. Either its MCERunner or a custom command

    my $counter = $self->batch_counter;
    $counter = sprintf( "%03d", $counter );

    $command = "cd " . getcwd() . "\n";
    if ( $self->has_custom_command ) {
        $command .= $self->custom_command . " \\\n";
    }
    else {
        $command .= "hpcrunner.pl execute_job \\\n";
    }
    $command
        .= "\t--procs "
        . $self->procs . " \\\n"
        . "\t--infile "
        . $self->cmdfile . " \\\n"
        . "\t--outdir "
        . $self->outdir . " \\\n"
        . "\t--logname "
        . "$counter" . "_"
        . $self->current_job . " \\\n"
        . "\t--process_table "
        . $self->process_table;

    my $metastr = $self->job_stats->create_meta_str( $counter, $self->batch_counter,
        $self->current_job );
    $command .= " \\\n\t" if $metastr;
    $command .= $metastr if $metastr;

    my $pluginstr = $self->create_plugin_str;
    $command .= $pluginstr if $pluginstr;

    my $version_str = $self->create_version_str;
    $command .= $version_str if $version_str;

    $command .= "\n";
    return $command;
}

=head3 create_version_str

If there is a version add it

=cut

sub create_version_str{
    my $self = shift;

    my $version_str = "";

    if($self->has_git && $self->has_version){
        $version_str .= " \\\n\t";
        $version_str .= "--version ".$self->version;
    }

    return $version_str;
}

=head3 create_plugin_str

Make sure to pass plugins to job runner

=cut

sub create_plugin_str{
    my $self = shift;

    my $plugin_str = "";

    if($self->job_plugins){
        $plugin_str .= " \\\n\t";
        $plugin_str .= "--job_plugins ".join(",", @{$self->job_plugins});
        $plugin_str .= " \\\n\t" if $self->job_plugins_opts;
        $plugin_str .= $self->unparse_plugin_opts($self->job_plugins_opts, 'job_plugins') if $self->job_plugins_opts;
    }

    if($self->plugins){
        $plugin_str .= " \\\n\t";
        $plugin_str .= "--plugins ".join(",", @{$self->plugins});
        $plugin_str .= " \\\n\t" if $self->plugins_opts;
        $plugin_str .= $self->unparse_plugin_opts($self->plugins_opts, 'plugins') if $self->plugins_opts;
    }

    return $plugin_str;
}

sub unparse_plugin_opts {
    my $self = shift;
    my $opt_href = shift;
    my $opt_opt = shift;

    my $opt_str = "";

    return unless $opt_href;

    #Get the opts

    while(my($k, $v) = each %{$opt_href}){
        next unless $k;
        $v = "" unless $v;
        $opt_str .= "--$opt_opt"."_opts ".$k."=".$v." ";
    }

    return $opt_str;
}

=head3 submit_to_scheduler

Submit the job to the scheduler.

Inputs: self, submit_command (sbatch, qsub, etc)

Returns: exitcode, stdout, stderr

This subroutine was just about 100% from the following perlmonks discussions. All that I did was add in some logging.

http://www.perlmonks.org/?node_id=151886

=cut

sub submit_to_scheduler{
    my $self = shift;
    my $submit_command = shift;

    my ($infh,$outfh,$errfh);
    $errfh = gensym(); # if you uncomment this line, $errfh will
    # never be initialized for you and you
    # will get a warning in the next print
    # line.
    my $cmdpid;
    eval{
        $cmdpid = open3($infh, $outfh, $errfh, "$submit_command ".$self->slurmfile);
    };
    die $@ if $@;

    my $sel = new IO::Select; # create a select object
    $sel->add($outfh,$errfh); # and add the fhs
    my($stdout, $stderr);

    while(my @ready = $sel->can_read) {
        foreach my $fh (@ready) { # loop through them
            my $line;
            # read up to 4096 bytes from this fh.
            my $len = sysread $fh, $line, 4096;
            if(not defined $len){
                # There was an error reading
                #$self->log->fatal("Error from child: $!");
                $self->log_main_messages('fatal', "Error from child: $!");
            } elsif ($len == 0){
                # Finished reading from this FH because we read
                # 0 bytes.  Remove this handle from $sel.
                $sel->remove($fh);
                next;
            } else { # we read data alright
                if($fh == $outfh) {
                    $stdout .= $line;
                    #$self->log->info($line);
                    $self->log_main_messages('debug', $line)
                } elsif($fh == $errfh) {
                    $stderr .= $line;
                    #$self->log->error($line);
                    $self->log_main_messages('error', $line);
                } else {
                    #$self->log->fatal("Shouldn't be here!\n");
                    $self->log_main_messages('fatal', "Shouldn't be here!");
                }
            }
        }
    }

    waitpid($cmdpid, 1);
    my $exitcode = $?;

    return ($exitcode, $stdout, $stderr);
}

1;
