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

    open( my $fh, ">$test_dir/script/test001.1.sh" );

    print $fh <<EOF;
echo "hello world from job 1" && sleep 5

echo "hello again from job 2" && sleep 5

echo "goodbye from job 3"

#NOTE job_tags=hello,world
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

sub test_001 : Tags(new) {

    MooseX::App::ParsedArgv->new( argv => [qw(new ProjectName)] );
    my $test = HPC::Runner::Command->new_with_command();
    isa_ok( $test, 'HPC::Runner::Command' );

    ok(1);
}

sub test_002 : Tags(construction) {

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

    remove_tree($test_dir);
}

1;
