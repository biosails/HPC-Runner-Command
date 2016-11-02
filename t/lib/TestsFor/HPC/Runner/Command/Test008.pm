package TestsFor::HPC::Runner::Command::Test008;

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

sub write_test_file {
    my $test_dir = shift;

    open( my $fh, ">$test_dir/logs/slurm_logs_000.in" );
    print $fh <<EOF;
#TASK tags=Sample1
pyfasta split -n 20 Sample1.fasta
EOF

    close($fh);
}

sub construct {
    my $self = shift;

    my $test_methods = TestMethods::Base->new();
    my $test_dir     = $test_methods->make_test_dir();
    write_test_file($test_dir);

    my $t = "$test_dir/logs/slurm_logs_000.in";
    MooseX::App::ParsedArgv->new(
        argv => [
            "execute_array",    "--infile",
            $t,               "--outdir",
            "$test_dir/logs"        ]
    );

    my $test = HPC::Runner::Command->new_with_command();
    $test->logname('slurm_logs');
    $test->log( $test->init_log );
    return $test;
}

##TODO Add in tests for executing jobs

sub test_001 : Tags(execute_array) {

    my ( $source, $dep );
    #my $test = construct();

    #diag($test->infile);
    #$test->execute();

    ok(1);

}

1;
