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

    open( my $fh, ">$test_dir/script/test002.1.sh" );
    print $fh <<EOF;
#HPC jobname=pyfasta

#TASK tags=Sample1
pyfasta split -n 20 Sample1.fasta

#TASK tags=Sample2
pyfasta split -n 20 Sample2.fasta

#TASK tags=Sample3
pyfasta split -n 20 Sample3.fasta

#HPC jobname=blastx_scratch

#TASK tags=Sample1
blastx -db  env_nr -query Sample1

#TASK tags=Sample2
blastx -db  env_nr -query Sample2

#TASK tags=Sample3
blastx -db  env_nr -query Sample3

#HPC jobname=blastx_postprocess
#HPC deps=blastx_scratch

#TASK tags=Sample1
postprocess -db  env_nr -query Sample1

#TASK tags=Sample2
postprocess -db  env_nr -query Sample2

#TASK tags=Sample3
postprocess -db  env_nr -query Sample3

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

sub test_001 : Tags(job_stats) {

    my ( $source, $dep );
    my $test = construct();

    $test->parse_file_slurm();
    $test->iterate_schedule();

    is_deeply( [  'blastx_scratch', 'pyfasta', 'blastx_postprocess' ],
	$test->schedule, 'Schedule passes' );

    my $logdir = $test->logdir;
    my $outdir = $test->outdir;

    #my @files = glob( $test->outdir . "/*" );


    #diag(Dumper($test->jobs->{'blastx_postprocess'}->batches->[0]->array_deps));
    #diag(Dumper($test->jobs->{'blastx_postprocess'}));
    #ok(1);

}

1;
