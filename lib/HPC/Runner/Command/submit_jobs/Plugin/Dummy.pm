use strict;
use warnings;
package HPC::Runner::Command::submit_jobs::Plugin::Dummy;

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

=head1 HPC::Runner::Command::Plugin::Scheduler::Dummy;

This is just a dummy to use for testing

=cut

=head2 Subroutines

=cut

=head3 submit_slurm()

Submit jobs to slurm queue using sbatch.


=cut

sub submit_job{
    my $self = shift;

    my $jobid = "1234";

    print "Submitting dummy job ".$self->slurmfile."\n\tWith dummy jobid $jobid\n";

    return $jobid;
}



1;

1;
