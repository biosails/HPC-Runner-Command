package TestsFor::HPC::Runner::Command::Test005;

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
use JSON::XS;
use Algorithm::Dependency::Ordered;

extends 'TestMethods::Base';

#Tests the template
#Tests for linear dependency tree

sub write_test_file {
    my $test_dir = shift;

    open( my $fh, ">$test_dir/script/test002.1.sh" );
    print $fh <<EOF;
# Starting pyfasta
#

#
# Variables
# Indir: /scratch/gencore/yv8/MetaGjoined-NCB-106/data/raw
# Outdir: /scratch/gencore/yv8/MetaGjoined-NCB-106/data/processed/pyfasta
# Local Variables:
#       create_outdir: 0
#       before_meta:

#HPC jobname=pyfasta
#HPC module=gencore_dev gencore_metagenomics_dev
#HPC commands_per_node=1
#HPC cpus_per_task=1
#HPC procs=1
#HPC partition=ser_std
#HPC mem=4GB
#HPC walltime=00:15:00

#       outdir: /scratch/gencore/yv8/MetaGjoined-NCB-106/data/processed/pyfasta
#       indir: /scratch/gencore/yv8/MetaGjoined-NCB-106/data/raw
#

#NOTE job_tags=MWG01
cd /scratch/gencore/yv8/MetaGjoined-NCB-106/data/processed/MWG01/fastx && \
    rm -rf MWG01.*.fasta && \
    pyfasta split -n 20 MWG01.fasta


#NOTE job_tags=MWG02
cd /scratch/gencore/yv8/MetaGjoined-NCB-106/data/processed/MWG02/fastx && \
    rm -rf MWG02.*.fasta && \
    pyfasta split -n 20 MWG02.fasta

#HPC jobname=blastx_scratch
#HPC deps=pyfasta
#HPC module=gencore_dev gencore_metagenomics
#HPC commands_per_node=1
#HPC cpus_per_task=7
#HPC procs=1
#HPC partition=ser_std
#HPC mem=20GB
#HPC walltime=06:00:00

#NOTE job_tags=MWG01
mkdir -p /scratch/gencore/yv8/MetaGjoined-NCB-106/data/processed/MWG01/blast_env_nr && \
blastx -db  /scratch/gencore/Databases/NCBI_env_nr/env_nr \
    -outfmt 6 -query /scratch/gencore/yv8/MetaGjoined-NCB-106/data/processed/MWG01/fastx/MWG01.001.fasta \
    -num_threads 7 \
    -out /scratch/gencore/yv8/MetaGjoined-NCB-106/data/processed/MWG01/blast_env_nr/MWG01.001.blastout

#NOTE job_tags=MWG01
mkdir -p /scratch/gencore/yv8/MetaGjoined-NCB-106/data/processed/MWG01/blast_env_nr && \
blastx -db  /scratch/gencore/Databases/NCBI_env_nr/env_nr \
    -outfmt 6 -query /scratch/gencore/yv8/MetaGjoined-NCB-106/data/processed/MWG01/fastx/MWG01.002.fasta \
    -num_threads 7 \
    -out /scratch/gencore/yv8/MetaGjoined-NCB-106/data/processed/MWG01/blast_env_nr/MWG01.002.blastout
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
    my $self = shift;

    my($source, $dep);
    my $test = construct();

    $test->parse_file_slurm();
    $test->iterate_schedule();

    is_deeply( [ 'pyfasta', 'blastx_scratch' ], $test->schedule, 'Schedule passes' );

    ok(1);
}

1;
