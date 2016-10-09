package HPC::Runner::Command::submit_jobs::Plugin::Slurm;

use Data::Dumper;
use IPC::Cmd qw[can_run];
use Log::Log4perl;

use Moose::Role;

=head1 HPC::Runner::Command::Plugin::Scheduler::Slurm;

=cut

##Application log
##There is a bug in here somewhere - this be named anything ...
has 'log' => (
    is      => 'rw',
    default => sub {
        my $self = shift;

        my $log_conf = q(
log4perl.rootLogger = DEBUG, Screen
log4perl.appender.Screen = \
  Log::Log4perl::Appender::ScreenColoredLevels
log4perl.appender.Screen.layout = \
  Log::Log4perl::Layout::PatternLayout
log4perl.appender.Screen.layout.ConversionPattern = \
  [%d] %m %n
      );
        Log::Log4perl::init(\$log_conf);
        return Log::Log4perl->get_logger();
        }

);

=head2 Subroutines

=cut

=head3 submit_jobs

Submit jobs to slurm queue using sbatch.

=cut

sub submit_jobs{
    my $self = shift;

    my($exitcode, $stdout, $stderr) = $self->submit_to_scheduler("sbatch");

    if($exitcode != 0){
        $self->log->fatal("Job was not submitted successfully");
        $self->log->warn("STDERR: ".$stderr) if $stderr;
        $self->log->warn("STDOUT: ".$stdout) if $stdout;
    }

    my($jobid) = $stdout =~ m/(\d.*)$/ if $stdout;

    if(!$jobid){
        $self->log->warn("Submit scripts will be written, but will not be submitted to the queue.");
        $self->log->warn("Please look at your submission scripts in ".$self->outdir);
        $self->log->warn("And your logs in ".$self->logdir."\nfor more information");
        $self->no_submit_to_slurm(0);
    }
    else{
        $self->log->debug("Submited job ".$self->slurmfile."\n\tWith Slurm jobid $jobid");
    }

    return $jobid;
}

=head3 update_job_deps

Update the job dependencies if using job_array (not batches)

=cut

sub update_job_deps{
    my $self = shift;

    return if $self->use_batches;

    return unless exists $self->current_batch->{array_deps};

    my $scheduler_ids = $self->current_batch->{array_deps};

    return unless $scheduler_ids;
    return unless scalar @{$scheduler_ids};

    foreach my $array_id (@{$scheduler_ids}){
        next unless $array_id;
        my $cmd =  "scontrol update job=".$self->jobs->{$self->current_job}->scheduler_ids->[0]."_".$self->batch_counter." Dependency=afterok:$array_id";
        $self->log->info("Updating job with cmd $cmd");
        $self->change_deps($cmd);
    }

}

sub change_deps {
    my $self = shift;
    my $cmd = shift;

    my $buffer = "";
    if( scalar IPC::Cmd::run( command => $cmd,
            verbose => 0,
            buffer  => \$buffer )
    ) {
        $self->log->info($buffer) if $buffer;
    }
    else{
        $self->log->warn($buffer) if $buffer;
    }
}

1;
