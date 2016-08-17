package TestsFor::HPC::Runner::Command::Test001;

use Test::Class::Moose;
use HPC::Runner::Command;
use Cwd;
use FindBin qw($Bin);
use File::Path qw(make_path remove_tree);
use Data::Dumper;
use Capture::Tiny ':all';

sub test_001 : Tags(prep) {
    my $test = shift;

    remove_tree("$Bin/test001");
    make_path("$Bin/test001/script");
    make_path("$Bin/test001/scratch");

    ok(1);
}

sub test_002 : Tags(prep) {
    my $test = shift;

    open( my $fh, ">$Bin/test001/script/test001.1.sh" );
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

    ok(1);
}

sub test_003 : Tags(construction) {
    my $test = shift;

    my $cwd = getcwd();

    #Worst test ever
    MooseX::App::ParsedArgv->new( argv => [qw(new ProjectName)] );
    my $test01 = HPC::Runner::Command->new_with_command();
    isa_ok( $test01, 'HPC::Runner::Command' );

    chdir("$Bin/test001");
    my $t = "$Bin/test001/script/test001.1.sh";
    MooseX::App::ParsedArgv->new(
        argv => [
            "submit_jobs", "--infile",
            $t,            "--outdir",
            "$Bin/test001/logs",
        ]
    );
    my $test03 = HPC::Runner::Command->new_with_command();

    is( $test03->outdir, "$Bin/test001/logs", "Outdir is logs" );
    is( $test03->infile, "$t", "Infile is ok" );
    isa_ok( $test03, 'HPC::Runner::Command' );
}

1;
