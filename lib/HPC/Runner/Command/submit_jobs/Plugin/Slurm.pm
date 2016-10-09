package HPC::Runner::Command::submit_jobs::Plugin::Slurm;

use File::Path qw(make_path remove_tree);
use File::Temp qw/ tempfile tempdir /;
use IO::File;
use IO::Select;
use Cwd;
use IPC::Open3;
use Symbol;
use Template;
use Log::Log4perl qw(:easy);
use DateTime;
use Data::Dumper;
use List::Util qw/shuffle/;
use IPC::Cmd qw[can_run];

use Moose::Role;

=head1 HPC::Runner::Command::Plugin::Scheduler::Slurm;

=cut

=head2 Subroutines

=cut

=head3 submit_jobs

Submit jobs to slurm queue using sbatch.

=cut

sub submit_jobs{
    my $self = shift;

    my($exitcode, $stdout, $stderr) = $self->submit_to_scheduler("sbatch");

    my($jobid) = $stdout =~ m/(\d.*)$/ if $stdout;
    if(!$jobid){
        $self->app_log->error("No job was submitted! \nFull error is:\t$stderr\n$stdout");
        $self->app_log->warn("Submit scripts will be written, but will not be submitted to the queue.");
        $self->app_log->warn("Please look at your submission scripts in ".$self->outdir);
        $self->app_log->warn("And your logs in ".$self->logdir."\nfor more information");
        $self->no_submit_to_slurm(0);
    }
    else{
        $self->app_log->info("Submitting job ".$self->slurmfile."\n\tWith Slurm jobid $jobid");
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
        $self->app_log->info("Updating job with cmd $cmd");
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
        $self->app_log->info($buffer);
    }
    else{
        $self->app_log->warn($buffer);
    }
}

1;
