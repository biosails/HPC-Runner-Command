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
    my $expect3 = "hpcrunner.pl execute_job";
    my $expect4 = "\t--procs 4";
    my $expect5 = "\t--infile $outdir/001_job01.in";
    my $expect6 = "\t--outdir $outdir";
    my $expect7 = "\t--logname 001_job01";
    my $expect8 = "\t--process_table $logdir/001-process_table.md";

    like( $got, qr/$expect1/, 'Template matches' );
    like( $got, qr/$expect2/, 'Template matches' );
    like( $got, qr/$expect3/, 'Template matches' );
    like( $got, qr/$expect4/, 'Template matches' );
    like( $got, qr/$expect5/, 'Template matches' );
    like( $got, qr/$expect6/, 'Template matches' );
    like( $got, qr/$expect7/, 'Template matches' );
    like( $got, qr/$expect8/, 'Template matches' );

    ok(1);
}

sub test_007 : Tags(check_hpc_meta) {

    my $test = construct();

    my $line = "#HPC module=thing1,thing2\n";
    $test->process_hpc_meta($line);

    is_deeply( [ 'thing1', 'thing2' ], $test->module, 'Modules pass' );
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
        $test->job_deps, 'Job Deps Pass' );
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

    my $line = "#NOTE job_tags=SAMPLE_01\n";
    $test->check_note_meta($line);

    is_deeply( $line, $test->cmd, 'Note meta passes' );
}

sub test_011 : Tags(check_hpc_meta) {
    my $self = shift;

    my $test = construct();

    my $line = "#HPC jobname=job01\n";
    $test->process_hpc_meta($line);
    $test->check_add_to_jobs();

    ok(1);
}

sub test_012 : Tags(job_stats) {
    my $self = shift;

    my $test = construct();

    $test->parse_file_slurm();
    $test->iterate_schedule();

    my $job_stats = {
        'batches'        => {
            '001_job01' => {
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

    is($test->job_stats->{batches}->{'001_job01'}->{'commands'}, 1);
    is($test->job_stats->{batches}->{'001_job01'}->{'batch'}, '001');
    is($test->job_stats->{batches}->{'001_job01'}->{'jobname'}, 'job01');

    is($test->job_stats->{batches}->{'002_job01'}->{'jobname'}, 'job01');
    is($test->job_stats->{batches}->{'002_job01'}->{'batch'}, '002');

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

    #TODO
    #Split this test into several different tests

    my $test = construct();

    $test->parse_file_slurm();
    $test->iterate_schedule();

    my $expect = {
        'job01' => {
            'hpc_meta' =>
                [ '#HPC cpus_per_task=12', '#HPC commands_per_node=1' ],
            'scheduler_ids' => [],
            'submitted'     => '0',
            'deps'          => [],
            'cmds'          => [
                '#NOTE job_tags=Sample1
echo "hello world from job 1" && sleep 5
',
                '#NOTE job_tags=Sample2
echo "hello again from job 2" && sleep 5
'
            ],
            batch_tags => [ 'Sample1', 'Sample2' ],
        },
        'job02' => {
            'scheduler_ids' => [],
            'hpc_meta'      => [],
            'submitted'     => '0',
            'deps'          => ['job01'],
            'cmds'          => [
                '#NOTE job_tags=Sample1
echo "goodbye from job 3"
',
                '#NOTE job_tags=Sample2
echo "hello again from job 3" && sleep 5
'
            ],
            batch_tags => ['Sample1'],
        },
    };

    #TODO Update this test
    #is_deeply( $expect, $test->jobs, 'Test jobs passes' );

    is( $test->jobs->{'job01'}->count_scheduler_ids, 2 );
    is( $test->jobs->{'job02'}->count_scheduler_ids, 2 );
    is( $test->jobs->{'job01'}->submitted,           1 );
    is( $test->jobs->{'job02'}->submitted,           1 );
    ok(1);
}

sub print_diff {
    my $got    = shift;
    my $expect = shift;

    use Text::Diff;

    my $diff = diff \$got, \$expect;
    diag("Diff is\n\n$diff\n\n");

    my $fh;
    open( $fh, ">got.diff" ) or die print "Couldn't open $!\n";
    print $fh $got;
    close($fh);

    open( $fh, ">expect.diff" ) or die print "Couldn't open $!\n";
    print $fh $expect;
    close($fh);

    open( $fh, ">diff.diff" ) or die print "Couldn't open $!\n";
    print $fh $diff;
    close($fh);

    ok(1);
}

1;
