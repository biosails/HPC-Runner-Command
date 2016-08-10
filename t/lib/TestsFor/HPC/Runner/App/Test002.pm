package TestsFor::HPC::Runner::Command::Test002;

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

sub test_000 : Tags(require) {
    my $self = shift;

    require_ok('HPC::Runner::Command');
    require_ok('HPC::Runner::Command::Utils::Base');
    require_ok('HPC::Runner::Command::submit_jobs::Utils::Scheduler');
    ok(1);
}

sub test_001 : Tags(prep) {
    my $test = shift;

    remove_tree("$Bin/test002");
    make_path("$Bin/test002/script");
    make_path("$Bin/test002/scratch");

    ok(1);
}

sub test_002 : Tags(prep) {
    my $test = shift;

    open( my $fh, ">$Bin/test002/script/test002.1.sh" );
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
#NOTE job_tags=Sample3
echo "goodbye from job 3"
echo "hello again from job 3" && sleep 5
EOF

    close($fh);

    ok(1);
}

sub construct {

    my $t = "$Bin/test002/script/test002.1.sh";
    MooseX::App::ParsedArgv->new(
        argv => [
            "submit_jobs",       "--infile",
            $t,                  "--outdir",
            "$Bin/test002/logs", "--hpc_plugins",
            "Dummy",
        ]
    );

    my $test = HPC::Runner::Command->new_with_command();
    $test->logname('slurm_logs');
    $test->log( $test->init_log );
    return $test;
}

sub test_003 : Tags(construction) {
    my $test = shift;

    my $cwd = getcwd();

    MooseX::App::ParsedArgv->new( argv => [qw(new ProjectName)] );
    my $test01 = HPC::Runner::Command->new_with_command();
    isa_ok( $test01, 'HPC::Runner::Command' );

    my $t      = "$Bin/test002/script/test002.1.sh";
    my $test03 = construct();

    is( $test03->outdir, "$Bin/test002/logs", "Outdir is logs" );
    is( $test03->infile, "$t", "Infile is ok" );
    isa_ok( $test03, 'HPC::Runner::Command' );
}

sub test_005 : Tags(submit_jobs) {
    my $self = shift;

    my $test05 = construct();

    $test05->first_pass(1);
    $test05->parse_file_slurm();
    $test05->schedule_jobs();
    $test05->iterate_schedule();

    $test05->reset_batch_counter;
    $test05->first_pass(0);
    $test05->iterate_schedule();

    my $logdir = $test05->logdir;
    diag( 'logdir is ', $logdir );
    my $cwd = getcwd();

    my $expect = <<EOF;
#!/bin/bash
#
#SBATCH --share
#SBATCH --get-user-env
#SBATCH --job-name=001_job01
#SBATCH --output=$logdir/001_job01.log
#SBATCH --cpus-per-task=12

cd $cwd
hpcrunner.pl execute_job \\
EOF
    $expect .= "\t--procs 4 \\\n";
    $expect .= "\t--infile $cwd/t/test002/logs/001_job01.in \\\n";
    $expect .= "\t--outdir $cwd/t/test002/logs \\\n";
    $expect .= "\t--logname 001_job01 \\\n";
    $expect .= "\t--process_table $logdir/process_table.md \\\n\t";

    my $got = read_file( $cwd . "/t/test002/logs/001_job01.sh" );

    $got =~ s/--metastr.*//g;

    is_deeply( $got, $expect);

    ok(1);
}

sub test_007 : Tags(check_hpc_meta) {
    my $self = shift;

    my $test07 = construct();

    my $line = "#HPC module=thing1,thing2\n";
    $test07->process_hpc_meta($line);

    is_deeply( [ 'thing1', 'thing2' ], $test07->module, 'Modules pass' );
}

sub test_008 : Tags(check_hpc_meta) {
    my $self = shift;

    my $test08 = construct();

    my $line = "#HPC jobname=job03\n";
    $test08->process_hpc_meta($line);

    $line = "#HPC deps=job01,job02\n";
    $test08->process_hpc_meta($line);

    is_deeply( [ 'job01', 'job02' ], $test08->deps, 'Deps pass');
    is_deeply( { job03 => [ 'job01', 'job02' ] },
        $test08->job_deps, 'Job Deps Pass' );
}

sub test_009 : Tags(check_hpc_meta) {
    my $self = shift;

    my $test09 = construct();

    my $line = "#HPC jobname=job01\n";
    $test09->process_hpc_meta($line);

    is_deeply( 'job01', $test09->jobname, 'Jobname pass' );
}

sub test_010 : Tags(check_note_meta) {
    my $self = shift;

    my $test09 = construct();

    my $line = "#NOTE job_tags=SAMPLE_01\n";
    $test09->check_note_meta($line);

    is_deeply( $line, $test09->cmd, 'Note meta passes' );
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


    $test->first_pass(1);
    $test->parse_file_slurm();
    $test->schedule_jobs();
    $test->iterate_schedule();

    my $job_stats = {
        'tally_commands' => 1,
        'batches' => {
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


    is_deeply( $job_stats, $test->job_stats, 'Job stats pass' );
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

    $test->first_pass(1);
    $test->parse_file_slurm();
    $test->schedule_jobs();
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
        },
        'job02' => {
            'scheduler_ids' => [],
            'hpc_meta'      => [],
            'submitted'     => '0',
            'deps'          => ['job01'],
            'cmds'          => [
                '#NOTE job_tags=Sample3
echo "goodbye from job 3"
',
                'echo "hello again from job 3" && sleep 5
'
            ],
        },
    };

    is_deeply( $expect, $test->jobs, 'Test jobs passes' );

    $test->reset_batch_counter;
    $test->first_pass(0);
    $test->schedule_jobs();
    $test->iterate_schedule();

    is($test->jobs->{'job01'}->count_scheduler_ids, 2);
    is($test->jobs->{'job02'}->count_scheduler_ids, 2);
    is($test->jobs->{'job01'}->submitted, 1);
    is($test->jobs->{'job02'}->submitted, 1);
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
