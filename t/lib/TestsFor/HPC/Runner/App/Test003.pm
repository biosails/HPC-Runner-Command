package TestsFor::HPC::Runner::Command::Test003;

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

sub make_test_dir{

    my $test_dir;

    my @chars = ('a'..'z', 'A'..'Z', 0..9);
    my $string = join '', map { @chars[rand @chars]  } 1 .. 8;

    if(exists $ENV{'TMP'}){
        $test_dir = $ENV{TMP}."/hpcrunner/$string";
    }
    else{
        $test_dir = "/tmp/hpcrunner/$string";
    }

    make_path($test_dir);
    make_path("$test_dir/script");

    chdir($test_dir);

    if(can_run('git') && !-d $test_dir."/.git"){
        system('git init');
    }

    open( my $fh, ">$test_dir/script/test003.1.sh" );
    print $fh <<EOF;
echo "hello world from job 1" && sleep 5

wait

echo "hello again from job 2" && sleep 5

wait

echo "goodbye from job 3"

wait

echo "hello again from job 3" && sleep 5
EOF

    close($fh);

    return $test_dir;
}

sub test_shutdown {

    chdir("$Bin");
    if ( exists $ENV{'TMP'} ) {
        remove_tree( $ENV{TMP} . "/hpcrunner" );
    }
    else {
        remove_tree("/tmp/hpcrunner");
    }
}

sub construct {

    my $test_dir = make_test_dir();
    my $cwd = getcwd();

    my $t = "$test_dir/script/test003.1.sh";

    MooseX::App::ParsedArgv->new(
        argv => [ "submit_jobs", "--infile", $t, "--hpc_plugins", "Dummy", ]
    );

    my $test = HPC::Runner::Command->new_with_command();
    $test->logname('slurm_logs');
    $test->log( $test->init_log );

    return $test;
}

sub test_003 : Tags(construct) {
    my $self = shift;

    my $test = construct();

    $test->first_pass(1);
    $test->parse_file_slurm();
    $test->schedule_jobs();
    $test->iterate_schedule();

    my $href = {
        'hpcjob_001' => {
            'submitted'     => '0',
            'hpc_meta'      => [],
            'deps'          => [],
            'scheduler_ids' => [],
            'cmds'          => [
                'echo "hello world from job 1" && sleep 5
'
            ],
        },
        'hpcjob_002' => {
            'submitted' => '0',
            'hpc_meta'  => [],
            'deps'      => ['hpcjob_001'],
            'cmds'      => [
                'echo "hello again from job 2" && sleep 5
'
            ],
            'scheduler_ids' => []
        },
        'hpcjob_003' => {
            'cmds' => [
                'echo "goodbye from job 3"
'
            ],
            'scheduler_ids' => [],
            'deps'          => ['hpcjob_002'],
            'hpc_meta'      => [],
            'submitted'     => '0'
        },
        'hpcjob_004' => {
            'submitted'     => '0',
            'hpc_meta'      => [],
            'deps'          => ['hpcjob_003'],
            'scheduler_ids' => [],
            'cmds'          => [
                'echo "hello again from job 3" && sleep 5
'
            ],
        },
    };

    is_deeply( $href, $test->jobs, 'JobRef passes' );
    is_deeply( [ 'hpcjob_001', 'hpcjob_002', 'hpcjob_003', 'hpcjob_004' ],
        $test->schedule, 'Schedule passes' );
    ok(1);
}

sub test_004 : Tags(submit_jobs) {
    my $self = shift;

    my $test = construct();

    $test->first_pass(1);
    $test->parse_file_slurm();
    $test->schedule_jobs();
    $test->iterate_schedule();

    $test->reset_batch_counter;
    $test->first_pass(0);
    $test->iterate_schedule();

    ok(1);
}

sub test_005 : Tags(submit_jobs) {
    my $test = construct();

    $test->execute();

    ok(1);
}

1;
