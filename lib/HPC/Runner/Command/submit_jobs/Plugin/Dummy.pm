package HPC::Runner::Command::submit_jobs::Plugin::Dummy;

use Moose::Role;

=head1 HPC::Runner::Command::submit_jobs::Plugin::Dummy;

This is just a dummy to use for testing

=cut

=head2 Subroutines

=cut

=head3 submit_jobs()

This is a dummy for testing - just return a value as a placeholder in job_stats

=cut

sub submit_jobs{
    my $self = shift;

    my $jobid = "1234";

    $self->app_log->info("Submitting dummy job ".$self->slurmfile."\n\tWith dummy jobid $jobid");

    return $jobid;
}


1;
