package TestsFor::HPC::Runner::Command::Test001;

use Test::Class::Moose;
use HPC::Runner::Command;
use Cwd;
use FindBin qw($Bin);
use File::Path qw(make_path remove_tree);
use IPC::Cmd qw[can_run];
use Data::Dumper;
use Capture::Tiny ':all';

sub make_test_dir{
    my $test_dir;

    if(exists $ENV{'TMP'}){
        $test_dir = $ENV{TMP}."/hpcrunner/test001";
    }
    else{
        $test_dir = "/tmp/hpcrunner/test001";
    }

    make_path($test_dir);
    make_path("$test_dir/script");

    chdir($test_dir);
    if(can_run('git') && !-d $test_dir."/.git"){
        system('git init');
    }

    open( my $fh, ">$test_dir/script/test001.1.sh" );
    print $fh <<EOF;
#HPC jobname=job01
#HPC cpus_per_task=12
#HPC commands_per_node=1

#NOTE job_tags=Sample1
echo "hello world from job 1" && sleep 5

#NOTE job_tags=Sample2
echo "hello again from job 2" && sleep 5

#NOTE job_tags=Sample3
echo "goodbye from job 3"
EOF

    close($fh);

    return $test_dir;
}

sub test_shutdown {

    my $test_dir = make_test_dir;
    chdir("$Bin");
    remove_tree($test_dir);
}

sub test_001 : Tags(new) {

    MooseX::App::ParsedArgv->new( argv => [qw(new ProjectName)] );
    my $test = HPC::Runner::Command->new_with_command();
    isa_ok( $test, 'HPC::Runner::Command' );

    ok(1);
}

#sub test_002 : Tags(prep) {
    #my $test = shift;

    #my $test_dir = make_test_dir();

    #ok(1);
#}

sub test_003 : Tags(construction) {

    my $test_dir = make_test_dir();
    my $cwd = getcwd();

    my $t = "$test_dir/script/test001.1.sh";
    MooseX::App::ParsedArgv->new(
        argv => [
            "submit_jobs", "--infile",
            $t,            "--outdir",
            "$test_dir/logs",
        ]
    );
    my $test = HPC::Runner::Command->new_with_command();

    is( $test->outdir, "$test_dir/logs", "Outdir is logs" );
    is( $test->infile, "$t", "Infile is ok" );
    isa_ok( $test, 'HPC::Runner::Command' );
}

1;
