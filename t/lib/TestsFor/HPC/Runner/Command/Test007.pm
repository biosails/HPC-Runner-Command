package TestsFor::HPC::Runner::Command::Test007;

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
#
# Starting raw_fastqc
#

#
#HPC module=gencore/1 gencore_dev gencore_qc
#HPC ntasks=1
#HPC procs=1
#HPC commands_per_node=1
#HPC jobname=raw_fastqc

#TASK tags=Sample_1
raw_fastqc sample1

#TASK tags=Sample_1
raw_fastqc sample1

#TASK tags=Sample_2
raw_fastqc sample2

#TASK tags=Sample_2
raw_fastqc sample2

#TASK tags=Sample_5
raw_fastqc sample5

#TASK tags=Sample_5
raw_fastqc sample5

#
#HPC module=gencore/1 gencore_dev gencore_qc
#HPC jobname=trimmomatic
#

#TASK tags=Sample_1
trimmomatic sample1

#TASK tags=Sample_2
trimmomatic sample2

#TASK tags=Sample_5
trimmomatic sample5

#
#HPC module=gencore/1 gencore_dev gencore_qc
#HPC jobname=trimmomatic_fastqc
#HPC deps=trimmomatic

#TASK tags=Sample_1
trimmomatic_fastqc sample1_read1

#TASK tags=Sample_1
trimmomatic_fastqc sample1_read2


#TASK tags=Sample_2
trimmomatic_fastqc sample2_read1

#TASK tags=Sample_2
trimmomatic_fastqc sample2_read2

#TASK tags=Sample_5
trimmomatic_fastqc sample5_read1

#TASK tags=Sample_5
trimmomatic_fastqc sample5_read2

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

    is_deeply( [ 'raw_fastqc', 'trimmomatic', 'trimmomatic_fastqc' ],
        $test->schedule, 'Schedule passes' );

    my $logdir = $test->logdir;
    my $outdir = $test->outdir;

    my @files = glob( $test->outdir . "/*" );

    #is( scalar @files, 18, "Got the right number of files" );

    #diag(Dumper($test->jobs->{'blastx_scratch'}));
    #diag(Dumper($test->jobs->{'trimmomatic'}->batches->[0]));
    #diag(Dumper($test->jobs->{'trimmomatic_fastqc'}->deps));
    #diag(Dumper($test->jobs->{'trimmomatic_fastqc'}->all_batch_indexes));
    #diag(Dumper($test->jobs->{'trimmomatic'}->all_batch_indexes));
    #diag(Dumper($test->jobs->{'blastx_scratch'}->batches->[0]->array_deps));

    diag('Ending Test007');
}

1;