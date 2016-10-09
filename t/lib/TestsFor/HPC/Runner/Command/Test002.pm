package TestsFor::HPC::Runner::Command::Test002;

use strict;
use warnings;

use Test::Class::Moose;
use HPC::Runner::Command;
use Cwd;
use FindBin qw($Bin);
use File::Path qw(make_path remove_tree);
use IPC::Cmd qw[can_run];
use Data::Dumper;
use Capture::Tiny ':all';
use Slurp;
use File::Slurp;
use JSON::XS;

extends 'TestMethods::Base';

#Tests the template
#Tests for linear dependency tree

sub write_test_file {
    my $test_dir = shift;

    open( my $fh, ">$test_dir/script/test002.1.sh" );
    print $fh <<EOF;
#HPC jobname=job01
#HPC cpus_per_task=12
#HPC commands_per_node=1

#NOTE job_tags=Sample1
echo "hello world from job 1" && sleep 5

#NOTE job_tags=Sample2
echo "hello again from job 2" && sleep 5

#HPC jobname=job02
#HPC deps=job01
#NOTE job_tags=Sample1
echo "goodbye from job 3"
#NOTE job_tags=Sample2
echo "hello again from job 3" && sleep 5
EOF

    close($fh);
}

sub construct {
    my $self = shift;

    my $test_methods = TestMethods::Base->new();
    my $test_dir     = $test_methods->make_test_dir();
    write_test_file($test_dir);

    my $t = "$test_dir/script/test002.1.sh";
    MooseX::App::ParsedArgv->new(
        argv => [
            "submit_jobs",    "--infile",
            $t,               "--outdir",
            "$test_dir/logs", "--hpc_plugins",
            "Dummy",
        ]
    );

    my $test = HPC::Runner::Command->new_with_command();
    $test->logname('slurm_logs');
    $test->log( $test->init_log );
    return $test;
}

sub test_003 : Tags(construction) {

    my $test     = construct();
    my $test_dir = getcwd();

    is( $test->outdir, "$test_dir/logs", "Outdir is logs" );
    is( $test->infile, "$test_dir/script/test002.1.sh", "Infile is ok" );

    isa_ok( $test, 'HPC::Runner::Command' );
}

sub test_005 : Tags(submit_jobs) {
    my $self = shift;

    my $test_dir = $self->make_test_dir;
    my $test     = construct();
    my $cwd      = getcwd();

    $test->parse_file_slurm();
    $test->iterate_schedule();

    my $logdir = $test->logdir;
    my $outdir = $test->outdir;

    #TODO Update this test after we finish with job_array
    my $got = read_file( $test->outdir . "/001_job01.sh" );

    chomp($got);

    $got =~ s/--metastr.*//g;
    $got =~ s/--version.*//g;

    my $expect1 = <<EOF;
#
#SBATCH --share
#SBATCH --get-user-env
#SBATCH --job-name=001_job01
#SBATCH --output=$logdir/001_job01.log
EOF

##SBATCH --cpus-per-task=1
    my $expect2 = "cd $cwd";
    my $expect3 = "hpcrunner.pl execute_array";
    my $expect4 = "\t--procs 4";
    my $expect5 = "\t--infile $outdir/001_job01.in";
    my $expect6 = "\t--outdir $outdir";
    my $expect7 = "\t--logname 001_job01";
    my $expect8 = "\t--process_table $logdir/001-process_table.md";

    like( $got, qr/$expect1/, 'Template matches' );
    like( $got, qr/$expect2/, 'Template matches' );
    like( $got, qr/$expect3/, 'Template matches' );
    like( $got, qr/$expect4/, 'Template matches' );

    #like( $got, qr/$expect5/, 'Template matches' );
    like( $got, qr/$expect6/, 'Template matches' );
    like( $got, qr/$expect7/, 'Template matches' );
    like( $got, qr/$expect8/, 'Template matches' );

    ok(1);
}

sub test_007 : Tags(check_hpc_meta) {

    my $test = construct();

    $test->jobname('job01');

    my $line = "#HPC module=thing1,thing2\n";
    $test->process_hpc_meta($line);

    is_deeply(
        [ 'thing1', 'thing2' ],
        $test->jobs->{ $test->jobname }->module,
        'Modules pass'
    );
}

sub test_008 : Tags(check_hpc_meta) {
    my $self = shift;

    my $test = construct();

    my $line = "#HPC jobname=job03\n";
    $test->process_hpc_meta($line);

    $line = "#HPC deps=job01,job02\n";
    $test->process_hpc_meta($line);

    is_deeply( [ 'job01', 'job02' ], $test->deps, 'Deps pass' );
    is_deeply( { job03 => [ 'job01', 'job02' ] },
        $test->graph_job_deps, 'Job Deps Pass' );
}

sub test_009 : Tags(check_hpc_meta) {
    my $self = shift;

    my $test = construct();

    my $line = "#HPC jobname=job01\n";
    $test->process_hpc_meta($line);

    is_deeply( 'job01', $test->jobname, 'Jobname pass' );
}

sub test_010 : Tags(check_note_meta) {
    my $self = shift;

    my $test = construct();

    my $line = "#HPC jobname=job01\n";
    $test->process_hpc_meta($line);

    $line = "#NOTE job_tags=SAMPLE_01\n";
    $test->check_note_meta($line);

    is_deeply( $line, $test->cmd, 'Note meta passes' );
}

#sub test_011 : Tags(check_hpc_meta) {
#my $self = shift;

#my $test = construct();

#my $line = "#HPC jobname=job01\n";
#$test->process_hpc_meta($line);

#ok(1);
#}

sub test_012 : Tags(job_stats) {
    my $self = shift;

    my $test = construct();

    $test->parse_file_slurm();
    $test->iterate_schedule();

    #Add in job_stats tests
    my $job_stats = {
        'batches'        => {
            '001_job01' => {
                'total_jobs' => 2,
                'jobname'  => 'job01',
                'batch'    => '001',
                'commands' => 1,
            },
            '002_job01' => {
                'jobname'  => 'job01',
                'batch'    => '002',
                'commands' => 1,
            },
            '004_job02' => {
                'batch'    => '004',
                'jobname'  => 'job02',
                'commands' => 1,
            },
            '003_job02' => {
                'commands' => 1,
                'batch'    => '003',
                'jobname'  => 'job02',
            }
        },
        'total_batches' => 4,
        'jobnames'      => {
            'job01' => [ '001_job01', '002_job01' ],
            'job02' => [ '003_job02', '004_job02' ]
        },
        'total_processes' => 4,
    };

    #WHERE DID MY TESTS GO!!!
    is_deeply( [ 'job01', 'job02' ], $test->schedule, 'Schedule passes' );

    ok(1);
}

sub test_013 : Tags(jobname) {
    my $self = shift;

    my $test = construct();

    is( 'hpcjob_001', $test->jobname, 'Jobname is ok' );
}

sub test_014 : Tags(job_stats) {
    my $self = shift;

    my $test = construct();

    $test->parse_file_slurm();
    $test->iterate_schedule();

    my $batch_job01_001 = {
        'cmds' => [
            '#NOTE job_tags=Sample1
echo "hello world from job 1" && sleep 5
'
        ],
        'job'        => 'job01',
        'batch_tags' => ['Sample1'],
        'job_deps'   => [],
        'batch_str'  => '#NOTE job_tags=Sample1
echo "hello world from job 1" && sleep 5
',
        'cmd_count'  => '1',
        'array_deps' => [],
    };

    is_deeply( $test->jobs->{job01}->batches->[0],
        $batch_job01_001, 'Job 01 Batch 001 matches' );

    my $batch_job01_002 = {
        'cmds' => [
            '#NOTE job_tags=Sample2
echo "hello again from job 2" && sleep 5
'
        ],
        'job'        => 'job01',
        'batch_tags' => ['Sample2'],
        'job_deps'   => [],
        'batch_str'  => '#NOTE job_tags=Sample2
echo "hello again from job 2" && sleep 5
',
        'cmd_count'  => '1',
        'array_deps' => [],
    };

    is_deeply( $test->jobs->{job01}->batches->[1],
        $batch_job01_002, 'Job 01 Batch 002 matches' );

    my $batch_job02_001 = {
        'cmds' => [
            '#NOTE job_tags=Sample1
echo "goodbye from job 3"
'
        ],
        'job'        => 'job02',
        'batch_tags' => ['Sample1'],
        'job_deps'   => ['job01'],
        'batch_str'  => '#NOTE job_tags=Sample1
echo "goodbye from job 3"
',
        'cmd_count'       => '1',
        'array_deps'      => ['1234_1'],
        'scheduler_index' => { 'job01' => [0] },
    };

    is_deeply( $test->jobs->{job02}->batches->[0],
        $batch_job02_001, 'Job 02 Batch 001 matches' );

    my $batch_job02_002 = {
        'cmds' => [
            '#NOTE job_tags=Sample2
echo "hello again from job 3" && sleep 5
'
        ],
        'job'        => 'job02',
        'batch_tags' => ['Sample2'],
        'job_deps'   => ['job01'],
        'batch_str'  => '#NOTE job_tags=Sample2
echo "hello again from job 3" && sleep 5
',
        'cmd_count'       => '1',
        'array_deps'      => ['1234_2'],
        'scheduler_index' => { 'job01' => [1] },
    };

    is_deeply( $test->jobs->{job02}->batches->[1],
        $batch_job02_002, 'Job 02 Batch 002 matches' );

    #Broke this test up into separate tests -> this is just here for reference
    my $expect = {
        'job01' => {
            'hpc_meta' =>
                [ '#HPC cpus_per_task=12', '#HPC commands_per_node=1' ],
            'cmds'          => [
                '#NOTE job_tags=Sample1
    echo "hello world from job 1" && sleep 5
    ',
                '#NOTE job_tags=Sample2
    echo "hello again from job 2" && sleep 5
    '
            ],
        },
        'job02' => {
            'submitted'     => '0',
            'deps'          => ['job01'],
            'cmds'          => [
                '#NOTE job_tags=Sample1
    echo "goodbye from job 3"
    ',
                'echo "hello again from job 3" && sleep 5
    '
            ],
        },
    };

    is_deeply( $test->jobs->{'job01'}->hpc_meta,
        [ '#HPC cpus_per_task=12', '#HPC commands_per_node=1' ] );
    is_deeply( $test->jobs->{'job01'}->scheduler_ids, ['1234'] );
    is_deeply( $test->jobs->{'job02'}->scheduler_ids, ['1235'] );
    is_deeply( $test->jobs->{'job01'}->deps,          [] );
    is_deeply( $test->jobs->{'job02'}->deps,          ['job01'] );
    is_deeply( $test->jobs->{'job01'}->batch_index_start, 1 );
    is_deeply( $test->jobs->{'job01'}->batch_index_end,   2 );
    is_deeply( $test->jobs->{'job02'}->batch_index_start, 3 );
    is_deeply( $test->jobs->{'job02'}->batch_index_end,   4 );
    is( $test->jobs->{'job01'}->count_scheduler_ids, 1 );
    is( $test->jobs->{'job02'}->count_scheduler_ids, 1 );
    is( $test->jobs->{'job01'}->submitted,           1 );
    is( $test->jobs->{'job02'}->submitted,           1 );
    ok(1);
}

sub test_015 : Tags(submit_jobs) {
    my $self = shift;

    my $test = construct();
    $test->parse_file_slurm();
    $test->iterate_schedule();

    my $graph_job_deps = {
        'job01' => [],
        'job02' => ['job01']
    };

    is_deeply( $graph_job_deps, $test->graph_job_deps,
        'Graph job dependency passes' );
}

sub test_016 : Tags(files) {
    my $self = shift;

    my $test = construct();

    $test->parse_file_slurm();
    $test->iterate_schedule();

    my $logdir = $test->logdir;
    my $outdir = $test->outdir;

    my @files = glob( $test->outdir . "/*" );

    #This did not work as well as expected
    #print "PARTITION IS ";
    #print Dumper($test->jobs->{job01}->partition);
    #TODO write tests for files
    #/tmp/hpcrunner/wwxYvxWy/logs/001_job01.sh
    #/tmp/hpcrunner/wwxYvxWy/logs/001_job01_001.in
    #/tmp/hpcrunner/wwxYvxWy/logs/001_job01_002.in
    #/tmp/hpcrunner/wwxYvxWy/logs/002_job02.sh
    #/tmp/hpcrunner/wwxYvxWy/logs/002_job02_003.in
    #/tmp/hpcrunner/wwxYvxWy/logs/002_job02_004.in

#my $ok;
#$ok = grep/$outdir."\/001_job01.sh"/, @files;
#ok($ok, 'Got the job01 submission file');
#is(grep/$test->outdir."/001_job01_001.in"/, @files, 'Got the job01 batch 001 input file');

    #print "Files are ".join("\n", @files)."\n";
    ok(1);
}

1;
