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

use Moose::Role;

=head1 HPC::Runner::Command::Plugin::Scheduler::Slurm;

=cut

=head2 Subroutines

=cut

=head3 submit_slurm()

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

1;
