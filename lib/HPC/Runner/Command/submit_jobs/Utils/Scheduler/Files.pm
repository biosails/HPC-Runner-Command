package HPC::Runner::Command::submit_jobs::Utils::Scheduler::Files;

use Moose::Role;
use IO::File;
use File::Path qw(make_path remove_tree);

=head1 HPC::Runner::Command::submit_jobs::Utils::Scheduler::Files

Take care of all file operations

=cut

=head2 Attributes

=cut


=head3 cmdfile

File of commands for mcerunner
Is cleared at the end of each slurm submission

=cut

has 'cmdfile' => (
    traits   => ['String'],
    default  => q{},
    is       => 'rw',
    isa      => 'Str',
    required => 0,
    handles  => { clear_cmdfile => 'clear', },
);

=head3 slurmfile

File generated from slurm template

Job submission file

=cut

has 'slurmfile' => (
    traits   => ['String'],
    default  => q{},
    is       => 'rw',
    isa      => 'Str',
    required => 0,
    handles  => { clear_slurmfile => 'clear', },
);

=head2 Subroutines

=cut

=head3 prepare_files

=cut

#TODO I think we will get rid of this

sub prepare_files {
    my $self = shift;

    make_path( $self->outdir ) unless -d $self->outdir;

    $self->prepare_sched_file;
}

=head3 prepare_counter

Prepare the counter. It is 001, 002, etc instead of 1, 2 etc

=cut


sub prepare_counter {
    my $self = shift;

    my $batch_counter = $self->batch_counter;
    $batch_counter = sprintf( "%03d", $batch_counter );

    my $job_counter = $self->job_counter;
    $job_counter = sprintf( "%03d", $job_counter );

    return ($batch_counter, $job_counter);
}

=head3 prepare_sched_files

=cut

sub prepare_sched_file {
    my $self    = shift;

    my($batch_counter, $job_counter) = $self->prepare_counter;

    make_path( $self->outdir ) unless -d $self->outdir;

    #If we are using job arrays there will only be one per batch

    if($self->use_batches){
        $self->slurmfile(
            $self->outdir . "/$job_counter" . "_" . $self->current_job ."_".$batch_counter.".sh" );
    }
    else{
        $self->slurmfile(
            $self->outdir . "/$job_counter" . "_" . $self->current_job . ".sh" );
    }

}

=head3 prepare_batch_files

=cut

sub prepare_batch_files {
    my $self  = shift;

    my($batch_counter, $job_counter) = $self->prepare_counter;

    $self->batch($self->current_batch->{batch_str});

    make_path( $self->outdir ) unless -d $self->outdir;

    $self->cmdfile(
        $self->outdir . "/$job_counter" . "_" . $self->current_job . "_".$batch_counter.".in" );

    my $fh = IO::File->new( $self->cmdfile, q{>} )
        or die print "Error opening file  "
        . $self->cmdfile . "  "
        . $! . "\n";

    print $fh $self->batch if defined $fh && defined $self->batch;
    $fh->close;
}

1;
