package TestsFor::HPC::Runner::Command::Test009;

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

=head2 Purpose

Test for failing schedule

=cut

sub write_test_file {
  my $test_dir = shift;

  my $t = "$test_dir/script/test002.1.sh";
  open( my $fh, ">$t" );
  print $fh <<EOF;

#HPC jobname=raw_fastqc
#HPC module=gencore/1 gencore_dev gencore_qc

#TASK tags=Sample_KO-H3K4Me3_1_R1
fastqc Sample_KO-H3K4Me3_1_R1 Sample_KO-H3K4Me3_1_R1

#HPC jobname=remove_tmp
#HPC deps=raw_fastc

#TASK tags=Sample_KO-H3K4Me3_1
remove_tmp Sample_KO-H3K4Me3_2_R1

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

sub test_001 : Tags(execute_array) {

    my ( $source, $dep );
    my $test = construct();

    $test->parse_file_slurm();
    # $test->iterate_schedule();

    diag(Dumper($test->graph_job_deps));
    diag(Dumper($test->schedule));

    ok(1);
}

1;
